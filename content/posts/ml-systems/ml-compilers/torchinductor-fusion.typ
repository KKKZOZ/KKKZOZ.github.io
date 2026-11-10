#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, fold, hint, xref
#import "/figures/torchinductor-fusion.typ" as fig

#tola-meta((
  title: "TorchInductor Pipeline 与算子融合",
  date: "2026-11-04",
  summary: "跟着一个 10 个算子的例子走完 TorchInductor 的四个阶段：Graph Preprocessing、Lowering、Scheduling、Codegen，重点是 Scheduler 怎么用 can_fuse、score_fusion 和 fuse_nodes 决定融合，并与 TVM 的 FuseOps 对比。",
  tags: ("ML Compilers", "torch.compile"),
  weight: 10,
))

#xref("/posts/ml-systems/ml-compilers/torch-compile-walkthrough/") 用 `((a + b) * c.relu()).sum(dim=-1)` 走了一遍 `torch.compile` 的各个阶段，`add`、`relu`、`mul`、`sum` 四个算子最后变成一个 kernel。那个例子太小，看不出 Inductor 是怎么决定融合的：哪些节点能放进同一个 kernel，有冲突时先合并哪一对。这篇换一个稍大的例子，专门看这个决定的过程。

例子有 10 个 ATen 算子，有分支，也有 reduction。`x` 是 `f32[1024, 1024]`，`bias`、`gamma`、`beta` 是 `f32[1024]`：

```python
def model(x, bias, gamma, beta):
    t = x * 1.1 + bias                # broadcasting + pointwise
    a = torch.relu(t)
    p = a * a                         # two branches
    q = a * 0.1
    s = p + q                         # merge branches
    m = s.mean(dim=1, keepdim=True)   # reduction
    y = (s - m) * gamma + beta        # pointwise epilogue
    return y
```

#figure(fig.fig-model-graph(), caption: [例子的计算图：两个分支汇合成 `s`，`s` 既进 `mean`，又进后面的 epilogue。]) <fig-model-graph>

Eager 模式下它是 10 个 kernel。`torch.compile` 之后只剩一个：

```text
triton_per_fused_add_mean_mul_relu_sub_0
```

*这个 kernel 不是在某一步生成的，四个阶段各做了一部分决定。* 下文按 TorchInductor 的流水线顺序讲，篇幅主要给 Scheduler：`can_fuse` 判断两个节点能不能融合，`score_fusion` 决定有冲突时先融合哪一对，`fuse_nodes` 是外层的融合循环。最后把同一个例子交给 TVM 的融合策略，比较两者的结果。

#hint[源码引用对应 PyTorch main 分支（2026 年 11 月）；示例的日志来自一次 CUDA 上的实际编译。]

= Prerequisites

这些背景在别的文章里讲过：

#table(
  columns: 2,
  table.header([背景], [在哪里]),
  [GPU 的内存层次（HBM、shared memory、寄存器），SM 和 warp，Triton 的 program / block 模型], [#xref("/posts/ml-systems/gpu-kernels/triton-builtin-tutorial/") 的 Background],
  [memory-bound 与 compute-bound，arithmetic intensity], [#xref("/posts/ml-systems/nvlink-vs-pcie-inference/") 的 Roofline],
  [`torch.compile` 的分层：Dynamo、FX Graph、AOTAutograd、ATen op], [#xref("/posts/ml-systems/ml-compilers/overview/")],
  [Inductor IR（`TensorBox` / `StorageBox` / `Pointwise` / `Reduction`）、realize、`MemoryDep`、persistent reduction], [#xref("/posts/ml-systems/ml-compilers/torch-compile-walkthrough/")],
)

== Tensor Layout

一个 tensor 是一块一维内存加上 size 和 stride。元素 $[i_0, i_1, ...]$ 的位置是

$ "offset" = sum_k i_k dot "stride"_k $

连续的 `[1024, 1024]` 张量 stride 是 `[1024, 1]`，offset 就是 `1024·i + j`。Inductor 日志里的 index 表达式都是这个式子：loop body 里的 `index0 = 1024*p0 + p1`，`MemoryDep('arg0_1', 1024*d0 + d1, {d0: 1024, d1: 1024})`，后面的字典是每个循环变量的范围。

广播不复制数据。`x + bias` 里，`bias` 被当成 stride 为 `[0, 1]` 的 `[1024, 1024]` 张量：每一行读同样的 1024 个元素，index 里没有行号，日志写成 `MemoryDep('arg1_1', d1, ...)`。

#figure(fig.fig-stride(), caption: [上：连续张量的 offset 是 `4·i + j`。下：广播后的 `bias` 第 0 维 stride 为 0，所有行读同一段内存。]) <fig-stride>

两个推论在后文会用到：

- `view` 只改 size 和 stride，不复制，所以要求新形状能用 stride 表达出来。`transpose` 之后的张量不连续，再 `view` 可能报错；`reshape` 在不能 view 时会复制。
- 长度为 1 的维度，stride 取什么值都指向同一个元素。`buf0` 的 `size=[1024, 1], stride=[1, 1024]` 和 `stride=[1, 1]` 是同一个布局。

== Iteration Space

Inductor 生成的每个 kernel 是一个循环嵌套，Scheduler 用 `group.iteration = (numel, rnumel)` 描述它：

```python
# Pointwise，例如 op1：group.iteration = (1048576, 1)
for x in range(1048576):        # numel：输出元素个数
    buf1[x] = ...

# Reduction，例如 op0：group.iteration = (1024, 1024)
for x in range(1024):           # numel：输出元素个数
    acc = 0
    for r in range(1024):       # rnumel：每个输出要归约的元素个数
        acc += ...
    buf0[x] = acc
```

两个节点要合进一个 kernel，就要能放进同一个循环嵌套。`numel`、`rnumel` 都相同的节点可以直接合并；pointwise `(N, 1)` 和 reduction `(M, R)` 要求 `N = M × R`，并且 pointwise 的循环能拆成 `(M, R)` 两层，这是后文后端检查的内容。生成 Triton 代码时，`x` 维分给各个 program（`tl.program_id(0)` 和 `XBLOCK`），`r` 维在 program 内部用 `R0_BLOCK` 遍历；一行能一次放进 block 时就是 persistent reduction。

== Functionalization

原地修改和 view 会让依赖关系变得隐蔽：`y = x.view(-1); y.add_(1)` 改的是 `x`，但图里看不出 `x` 被写过。AOTAutograd 的 functionalization 把这类程序改写成没有 mutation 的形式（示意）：

```python
# 原程序                        # functionalize 之后
def f(x):                       def f(x):
    x.add_(1)                       x1 = aten.add.Tensor(x, 1)
    return x * 2                    out = aten.mul.Tensor(x1, 2)
                                    aten.copy_.default(x, x1)   # 对输入的修改最后写回
                                    return out
```

之后每个节点都是纯函数，节点之间的依赖就是图里的边。Inductor 的 post-grad pass 在这样的图上改写、重排、删除节点，不用担心漏掉隐藏的写；最后再由 `reinplace_inplaceable_ops` 把能原地做的操作改回原地。

同一阶段还会用到 *FakeTensor*：只有 shape、dtype、stride、device 等元信息、没有数据的 tensor。在它上面执行算子只推导输出的元信息，不做计算，Inductor 靠它在编译时知道每个中间结果的形状。

== Dependency Graph

Scheduler 把节点和它们之间的读写依赖看成一张有向无环图（DAG）。几个概念：

- *拓扑序*：每个节点都排在它依赖的节点之后。执行顺序必须是一个拓扑序。
- *祖先*：沿依赖边往回能走到的所有节点。`node1` 是 `node2` 的祖先，说明 `node2` 直接或间接用了 `node1` 的结果。
- *DCE*（dead code elimination）：删掉结果没人用的节点。
- *CSE*（common subexpression elimination）：相同的表达式只算一次。`t0 = load(x[i])` 之后再出现 `load(x[i])`，直接复用 `t0`。Inductor 生成 kernel 代码时做 CSE。

融合两个节点，等于要求它们在同一个 kernel 里一起执行。如果两者之间隔着第三个节点，就可能形成环：

#figure(fig.fig-fusion-cycle(), caption: [A 和 C 之间隔着 B：融合后的 kernel 既要在 B 之前（B 读 A 的结果），又要在 B 之后（C 读 B 的结果），没有合法的执行顺序。]) <fig-fusion-cycle>

所以 `can_fuse` 和融合循环都要检查中间节点和环。

== Extern Kernel and Template

Inductor 自己生成的主要是 pointwise 和 reduction kernel。矩阵乘、卷积默认调用外部库（cuBLAS、cuDNN），在 IR 里是 `ExternKernel`。外部 kernel 是黑盒，Inductor 不能往里面加代码，所以*融合在它的两侧断开*：它的输入必须先写进内存，它的输出也是一个真实的 buffer。

`max_autotune` 打开后，Inductor 会为 `mm` 等算子测量多个候选实现，其中包括用 Triton 模板生成的 kernel（IR 里是 `TemplateBuffer`）。模板 kernel 是 Inductor 生成的代码，可以继续往里加东西：

- *Epilogue fusion*：在模板写回结果之前，接上后续的 pointwise，例如 `mm` 之后的 `+ bias` 和 `relu`。
- *Prologue fusion*：在模板读输入时，先做前置的 pointwise，例如对输入做 dtype 转换。

= Operator Fusion

算子融合用一个更大、更复杂的 kernel，换更少的 kernel launch 和更少的中间数据读写。三个算子 `A → B → C` 顺序执行时，每个中间结果都要写回 HBM 再读出来；融合后，中间结果留在寄存器里：

#figure(fig.fig-fusion-traffic(), caption: [三个算子分开执行时，`t1`、`t2` 各经过 HBM 一次往返；融合成一个 kernel 后，只读输入、只写输出。]) <fig-fusion-traffic>

收益有三项：

- *Global memory 读写减少*，通常是最大的一项。
- *Kernel launch 减少*，每次 launch 都有固定的 CPU 和调度开销。`mode="reduce-overhead"` 用 CUDA Graph 解决的也是这个问题，只是从另一个方向入手。
- *数据局部性更好*：上一步的结果在寄存器里直接给下一步用。

在本例上估算一下第一项。一个 `[1024, 1024]` 的 `f32` 张量是 4 MiB。Eager 模式下，10 个 kernel 里有 9 个读一个完整张量，`p + q` 读两个，除 `mean` 外每个都写一个完整张量：

#table(
  columns: 3,
  table.header([], [Eager], [融合后]),
  [kernel 数], [10], [1],
  [读 HBM], [9 × 4 + 8 = 44 MiB], [`x` 4 MiB（另有 12 KiB 的 `bias`、`gamma`、`beta`）],
  [写 HBM], [9 × 4 = 36 MiB], [`y` 4 MiB],
  [合计], [约 80 MiB], [约 8 MiB],
)

*访存量差了 10 倍*，这是 pointwise 和 reduction 这类 memory-bound 算子值得融合的原因。

代价也有三项：

- *寄存器压力*：融合后的 kernel 要同时保存多个算子的中间值。需要的寄存器超过可用的数量时会发生 register spill，溢出的值进 local memory，省下的访存又加回来一部分。
- *代码变大*：instruction cache 压力更大，编译时间也更长。
- *并行配置只能选一套*：分开执行时，每个 kernel 可以各自选 block size、num_warps、tile size；融合后一套参数要同时服务多个算子，不一定对每个都最优。

所以融合不是"能融就融"。编译器要回答三个问题：*能不能融*（合法性），*值不值得融*（收益估计），*候选冲突时先融哪个*（顺序）。Inductor 分别用 `can_fuse`、`score_fusion` 的分数和 `fuse_nodes` 的贪心循环回答它们。

= torch.compile

#figure(fig.fig-compile-stack(), caption: [`torch.compile` 的完整路径：Dynamo 捕获 FX Graph，AOTAutograd 得到 ATen 图，Inductor 生成 Triton 代码，Triton JIT 再编译到 PTX。]) <fig-compile-stack>

Inductor 是 `torch.compile` 的默认 backend。`torch.compiler.list_backends()` 列出可用的 backend：`inductor`、`cudagraphs`、`openxla`、`tvm`。它们都接收 Dynamo 捕获的 FX Graph；`cudagraphs` 是一种 GPU 执行机制，用 CUDA Graph 降低重复执行的调度开销，另外三个是面向不同硬件的深度学习编译器。调试用的 `eager`（只做 Dynamo 捕获）和 `aot_eager`（再经过 AOTAutograd）不出现在列表里，它们不生成优化后的 kernel，用来定位问题出在哪一层。

#fold(title: [`torch.compile` 的几种 mode 对应的 Inductor 配置])[
  `torch._inductor.list_mode_options()` 列出每种 mode 打开的 config：

  #table(
    columns: 3,
    table.header([mode], [含义], [config]),
    [`default`], [平衡编译开销与运行性能], [`{}`],
    [`lite`], [少做优化，编译更轻], [`fallback_by_default`、`selective_decompose` 打开；`use_pre_grad_passes`、`use_joint_graph_passes`、`use_post_grad_passes`、`use_dce`、`allow_buffer_reuse`、几个 reorder 选项关闭],
    [`reduce-overhead`], [用 CUDA Graph 降低 launch 开销], [`triton.cudagraphs`],
    [`max-autotune`], [自动调优，编译最久], [`max_autotune`、`triton.cudagraphs`、`coordinate_descent_tuning`],
    [`max-autotune-no-cudagraphs`], [同上但不开 CUDA Graph], [`max_autotune`、`coordinate_descent_tuning`],
  )

  和融合有关的是 `max_autotune`：打开后，`mm` 一类算子可能选 Triton template 实现，才会出现下文的 epilogue / prologue fusion。
]

Inductor 的入口是 `_compile_fx_inner`：

```python
@time_and_log(attr="compilation time (in seconds)")
def _compile_fx_inner(
    gm: GraphModule,                          # FX 图和执行它需要的模块属性
    example_inputs: Sequence[InputType],      # 示例输入：推导 shape、dtype、device
    compile_region_name: str | None = None,
    **graph_kwargs: Unpack[_CompileFxKwargs], # 是否 CUDA Graph、是否 backward、是否 C++ wrapper 等
) -> OutputCode:
```

它收到的 `gm` 已经经过 Dynamo 捕获和 AOTAutograd 处理，节点都是 `aten.*` 算子。上层的 `compile_fx()` 和 `fx_codegen_and_compile()` 根据配置选编译策略，默认用 `_InProcessFxCompile`，实际工作在它的 `codegen_and_compile()` 里。

= TorchInductor Pipeline

Inductor 的主流程分为四个阶段，每个阶段回答一个问题：

- *Graph Preprocessing：What to compute？* 规范化 FX Graph、补全元信息、做图级优化：哪些计算保留、删除、替换或组合。输出是预处理后的 FX Graph。
- *Lowering：How to represent？* 决定算子怎么表示、是否分解、是否 fallback、何时物化结果。输出是 Inductor IR，包含 IR 操作、buffer、布局和依赖信息。
- *Scheduling：How to organize？* 决定执行顺序、算子融合、部分重排。输出是 `SchedulerNode` / `FusedSchedulerNode`。
- *Code Generation：How to emit？* 决定循环与索引表达式、tile 大小、warp 配置、模板实现和调用方式。输出是 kernel 代码和调用它们的 wrapper。

最后编译、封装成 `CompiledFxGraph`（AOTInductor 是 `CompiledAOTI`）。

#figure(fig.fig-pipeline(), caption: [Inductor 的四个阶段、本例在每个阶段之后的样子，以及每个阶段里"融合"的含义。]) <fig-pipeline>

*"融合"在四个阶段里是四件不同的事*：Preprocessing 里是 pattern matching 把一个子图换成另一个子图；Lowering 里是把 `Pointwise` 内联进使用者的表达式；Scheduling 里才是把多个调度节点合成一个 kernel；Codegen 里是 kernel 内的公共子表达式消除和删掉只在 kernel 内部使用的 buffer。本例的 10 个算子到 1 个 kernel，后三件都用上了。

= Graph Preprocessing

在创建 `GraphLowering` 之前，`codegen_and_compile()` 依次做了这些处理：

#table(
  columns: 3,
  table.header([操作], [源码], [作用]),
  [规范化], [`view_to_reshape(gm)`], [把 `view` 换成 `reshape`],
  [补全张量元信息], [`fake_tensor_prop(gm, example_inputs)`], [用 FakeTensor 传播 shape、dtype、stride],
  [保存输出布局], [`_recursive_record_original_output_strides(gm)`], [记下原图输出的 stride],
  [图级优化], [`_recursive_post_grad_passes(gm, ...)`], [执行 post-grad pass],
  [常量折叠（可选）], [`split_const_gm(...)`], [AOTInductor 下把可折叠的常量子图分离出来],
)

- *`view_to_reshape`*：把 `aten.view.default` 节点的 target 改成 `aten.reshape.default`。`view` 要求输入的 stride 能直接表达新形状，否则报错；Inductor 之后可能改变中间结果的布局（padding、channels-last 等），原来合法的 `view` 可能不再合法。`reshape` 在不能 view 时会退回到 copy，所以更安全。
- *`fake_tensor_prop`*：如果能从输入里检测到已有的 `FakeTensorMode` 就复用，否则新建一个；然后用 `FakeTensorProp(gm, mode).propagate(*example_inputs)` 沿图执行每个算子，把结果的元信息挂到节点上。这一步不做真实计算。
- *`_recursive_record_original_output_strides`*：先递归处理 `invoke_subgraph` 高阶算子里的子图，再记录当前图输出的 stride。Inductor 内部可以给中间结果选别的布局，但图的输出必须和 eager 的 stride 一致。

== `post_grad_passes`

`_recursive_post_grad_passes` 先递归处理子图，再对当前图调用 `post_grad_passes(gm, is_inference)`。它对 forward 图和 backward 图各调用一次，此时的图已经规范化、functionalize 过。和融合有关的有两类：*模式匹配*（`pass_patterns` 等）在图里找到预定义的算子组合，换成等价的实现；`_remove_profiler_ops` 删掉 `record_function` 等 profiler 节点，*避免它们挡住后面的融合*。其余是死代码消除、CPU 专用优化、分布式通信优化和收尾的分解。

#fold(title: [`post_grad_passes` 按执行顺序的完整列表])[
  + *FSDP2*：`remove_fsdp2_unsharded_param_graph_input_usage`，处理 FSDP2 中未分片参数作为图输入的用法。
  + *死代码消除*：`config.dce` 打开时调用 `gm.graph.eliminate_dead_code()`。
  + *局部性重排*：只对推理图，`reorder_for_locality` 调整节点顺序，让使用者靠近生产者。
  + *用户自定义 pass*：`post_grad_custom_pre_pass`，在标准优化之前插入。
  + *CPU 专用*：有 MKLDNN 且满足 grouped GEMM 模板、`max_autotune` 等条件时做 `grouped_gemm_pass`；`concat_linear_woq_int4` 处理 WOQ INT4 量化的 Linear；`_remove_profiler_ops` 删掉 `record_function` 等 profiler 节点，*避免它们挡住后面的融合*。
  + *模式匹配*（`config.pattern_matcher`）：

    #table(
      columns: 2,
      table.header([Pass], [作用]),
      [`group_batch_fusion_passes`], [把多个同类小算子合成 batch 版本],
      [`remove_noop_ops`], [删除无操作或冗余操作],
      [`remove_assert_ops`], [删除满足条件的断言节点],
      [`pass_patterns`], [逐个应用预定义的模式：在图里找到某个算子组合，替换成等价的实现],
      [`partitioned_scatter_optimization_pass`], [开启时做分区 scatter 优化],
      [`POST_GRAD_PATTERNS`], [配置选定的 post-grad 模式],
      [`B2B_GEMM_PASS`], [开启时做 back-to-back GEMM 变换],
    )
  + *分布式通信*：

    #table(
      columns: 2,
      table.header([函数], [作用]),
      [`bucket_reduce_scatter`、`bucket_all_reduce`、`bucket_all_gather`], [把多个通信合成更大的批次，减少调用次数],
      [`schedule_overlap_bucketing_from_inductor_configs`], [调整通信和计算的顺序，让它们重叠],
      [`replace_collectives_with_low_contention`], [开启时换成低竞争的 collective 实现],
      [`fuse_ddp_communication`、`micro_pipeline_tp_pass`], [数据并行通信融合和张量并行的微流水线],
    )
  + *收尾*：`reinplace_inplaceable_ops` 把能原地做的操作改回原地，减少内存分配和复制；`decompose_triton_kernel_wrapper_functional`、`decompose_auto_functionalized` 分解函数式包装节点；`reinplace_fsdp_all_gather`；`decompose_scan_to_while_loop`、`decompose_map_to_while_loop` 把 `scan` / `map` 高阶算子展开成 while loop。最后 `gm.recompile()` 重新生成 Python forward 代码，`gm.graph.lint()` 检查图的一致性。
]

`reinplace` 放在最后有原因：*前面所有 pass 都在 functional 图上工作*，没有 mutation 和 alias，改写更容易保证正确；改完之后再把能原地的操作恢复成原地。

本例里这些 pass 都没有改动图：`fx_graph_transformed.py` 和 `fx_graph_runnable.py` 的算子序列相同，只多了 shape 标注和源码行注释。

回到 `codegen_and_compile()`，post-grad pass 之后它记录优化后的图、新旧节点的对应关系和编译指标，然后为 lowering 设置环境：`V.set_fake_mode(fake_mode)` 让后面的 shape 推导都走 FakeTensor；`maybe_disable_comprehensive_padding` 和 `maybe_disable_graph_partition` 按条件关掉 padding（给张量补元素来调整布局）和图分区（把一张图拆成多个子图）。

= Lowering

`torch.ops.aten.relu.default(x)` 只说了"对张量做 ReLU"，没有说由哪个 kernel 执行、每个线程负责哪些元素、数据怎么分块和存取。*Lowering 把这样的节点转换成 Inductor 能分析的表示*：每个输出元素怎么算，读哪些 buffer，结果要不要写进内存。

== `GraphLowering.run_node`

`GraphLowering` 是 `torch.fx.Interpreter` 的子类。`GraphLowering.run()` 只在父类的 `run()` 外面加了计时，遍历节点的逻辑来自父类；每个节点的 lowering 由子类重写的 `run_node()` 完成：

#figure(fig.fig-lowering-dispatch(), caption: [`GraphLowering` 对一个 FX node 的分派：`Interpreter` 负责遍历和取参数，`GraphLowering` 负责每类节点怎么变成 IR。]) <fig-lowering-dispatch>

`Interpreter.run_node()` 用 `fetch_args_kwargs_from_env(n)` 把 FX 节点的输入引用解析成之前的 lowering 结果，再用 `getattr(self, n.op)(n.target, args, kwargs)` 分派。对 `b = torch.relu(a)`，FX 图里 `b` 的节点只引用节点 `a`；Inductor 在 `env` 里查到的是处理 `a` 时返回的对象，它不一定是已经物化的 Tensor，可以是一个延迟计算的 `TensorBox`。

`GraphLowering` 只支持 `placeholder`、`call_function`、`get_attr`、`output` 四种节点，`call_method` 和 `call_module` 直接 `raise AssertionError`。这不会造成问题：AOTAutograd 已经把方法调用和模块调用都展开成了 `aten.*` 的 `call_function`。

以 `placeholder` 为例，它从 `self.args_iter` 取得当前输入，对 Tensor 做三件事：

```python
tensor = TensorBox.create(
    DonatedBuffer(                     # 1. 表示图输入的 buffer
        name=target,
        layout=FixedLayout(example.device, example.dtype, sizes, strides),  # 2. 设备、类型、形状、stride
    )
)                                      # 3. 包装成 Inductor 的 Tensor 表示
```

`GraphLowering.run_node()` 在进入父类分派之前还做了几件事：

- 记录 origins：当前 FX 节点，以及参数来自哪些节点。之后生成的 kernel 名（`fused_add_mean_...`）和源码注释都从这里来。
- `_realize_inputs_at_stream_boundaries(n)`：如果输入和当前节点在不同的 CUDA stream 上，*提前把输入物化*，防止跨 stream 的计算被内联到一起，让 Scheduler 能把它们拆成不同的 kernel。
- 检查几种特殊情况，见下面的折叠块。

#fold(title: [`run_node` 先处理的特殊情况])[
  #table(
    columns: 2,
    table.header([条件], [处理]),
    [`fallback_node_due_to_unsupported_type(n)` 等成立], [对特定内置算子使用 `fallback_handler`],
    [`should_fallback_by_default(n)`], [对配置为默认 fallback 的算子走 fallback],
    [用户定义的 Triton kernel 有 layout 约束], [先约束输入的 stride / layout，再 `self.call_function(...)`],
    [`is_magic_method(n.target)`], [对部分 Python magic method 专门处理],
  )
]

== `call_function`

大部分节点走 `call_function`。去掉日志和少数特例后，它的逻辑是：

```python
def call_function(self, target, args, kwargs):
    if target not in lowerings:                       # 算子还没有 lowering
        if base_name in FALLBACK_ALLOW_LIST:
            make_fallback(target)                     # 注册一个 fallback lowering
        elif config.implicit_fallbacks:
            make_fallback(target, layout_constraint=...)   # 隐式 fallback
        elif get_decompositions([target]):
            raise MissingOperatorWithDecomp(...)      # 有分解规则，但没有 lowering
        else:
            raise MissingOperatorWithoutDecomp(...)

    layout_constraints = maybe_layout_constraints(target)
    if layout_constraints:                            # 有些算子要求连续布局或特定 stride
        old_args, old_kwargs = args, kwargs
        args, kwargs = layout_constraints(n, *args, **kwargs)   # 必要时复制输入

    out = None
    if target in user_lowerings and target not in V.active_user_lowering_ops:
        out = user_lowerings[target](*args, **kwargs)  # 用户注册的 lowering 优先
    if out is None:                                    # 没有，或者返回了 None
        out = lowerings[target](*args, **kwargs)       # 标准 lowering

    if layout_constraints:
        self.propagate_mutation(n, old_args, old_kwargs, args, kwargs)  # 把 mutation 写回原始输入
    return out
```

`lowerings` 是 Inductor 的 lowering 注册表，每一项是一个算子的 lowering 函数，用 `@register_lowering` 注册。分享时的版本里有 1811 项：

```python
>>> from torch._inductor.lowering import lowerings
>>> len(lowerings)
1811
>>> lowerings.get(torch.ops.aten.add.Tensor)
<function make_pointwise.<locals>.inner at 0x79070c01ae50>
```

`aten.add` 的 lowering 是 `make_pointwise` 生成的闭包，返回一个 `Pointwise`；view 类算子返回 View，比如 `permute`：

```python
@register_lowering(aten.permute, type_promotion_kind=None)
def permute(x, dims):
    assert isinstance(x, TensorBox)
    assert isinstance(dims, (list, tuple))
    return TensorBox(PermuteView.create(x.data, tuple(dims)))
```

*Fallback 对融合有直接影响*：`make_fallback` 注册的 lowering 直接调用 ATen kernel，生成 `ExternKernel`。它只能读写真实内存，所以输入要 realize，输出是一个 buffer，它在 Scheduler 里成为 `ExternKernelSchedulerNode`，一般的融合在它两侧断开。一个模型里如果有算子掉进 fallback，融合的机会也随之减少。

Lowering 返回后，`run_node()` 还要处理结果：

- *约束输出的 layout 和 stride*：根据输出是否对用户可见、是否涉及 `as_strided` 等条件，调用 `ir.ExternKernel.require_stride_order(...)` 或 `require_exact_strides(...)`。
- *决定是否 realize*。realize 不表示立刻执行 GPU 计算，而是让编译器明确"这个结果要存下来"，具体代码在后面生成。例如：

  ```python
  # Realize if the IRNode already has accumulated lots of reads
  if isinstance(result, TensorBox) and result.has_exceeded_max_reads():
      # Prevent excessive accumulation in a computed buffer, when
      # there are multiple branches each with small number of memory
      # reads, but they converge to a user.
      result = maybe_apply_channels_last_stride_order(result, n)
      result.realize_hint()
  ```
- *记录复用信息和符号形状信息*。

最终，`GraphLowering` 把 FX 节点都转换成 Inductor IR，生成的 IR 操作记录在 `self.operations` 里。

== Inductor IR

Inductor IR 有五类核心对象：

- *`TensorBox`*：对应一个上层的 tensor，`.data` 指向一个 `StorageBox`（中间可能隔着 View）。
- *`StorageBox`*：代表一块存储，所有别名指向同一个 `StorageBox`。`realize()` 时把里面的延迟节点替换成 `ComputedBuffer`，分配内存。
- *View*：`StorageBox` 外的坐标变换层，处理上层的 view 操作。
- *Buffer*：一块已分配内存的计算结果，有名字、有 layout，是 Scheduler 调度的基本单元。
- *`Pointwise` / `Reduction`*：纯粹的延迟计算描述，只有一个 `inner_fn`，没有内存，不参与调度。

为什么要多一层 `StorageBox`？因为别名。`b = a` 之后 `a`、`b` 是两个 `TensorBox`，指向同一个 `StorageBox`；对 `a` 的原地修改替换的是 `StorageBox.data`，`b` 自然看到新值。`a.permute(1, 0)` 得到的 `c` 不复制数据，只在 `StorageBox` 外加一层重新索引：

#figure(fig.fig-storage-alias(), caption: [别名共用一个 `StorageBox`：`add_` 替换的是 `S.data`，`a`、`b` 都看到新值；`c` 通过 `PermuteView` 用 `[j, i]` 读同一块存储。]) <fig-storage-alias>

这是模型上的解释。AOTAutograd 的 functionalization 之后，图里一般只剩把结果写回输入的 `copy_`，很少再有 `add_` 这样的原地操作。

没有 realize 的 `Pointwise` 只是一个函数。使用者通过 loader 读它时，实际调用的是它的 `inner_fn`，所以一串 pointwise 会层层内联，直到遇到需要 realize 的节点：

#figure(fig.fig-inner-fn(), caption: [`c`、`d` 的 `inner_fn` 层层内联；`e` 是 reduction，输出 shape 变了，立即 realize 成 `buf0`；`f` 读 `buf0`，内联在这里停止。]) <fig-inner-fn>

`e = torch.sum(d)` 分两步：先调用 `d.make_loader()` 拿到 `relu_fn`，把它内联进 `Reduction` 的 `inner_fn`；然后 `make_reduction` 主动调用 `realize()`，因为 reduction 的输出 shape 和输入不同，必须写进内存才能被后续节点使用。realize 前后，同一个 `TensorBox` 的 `.data` 链是：

#table(
  columns: 3,
  table.header([表达式], [realize 前], [realize 后]),
  [`tb.data`], [`StorageBox`], [`StorageBox`],
  [`tb.data.data`], [`Pointwise` / `Reduction`], [`ComputedBuffer`],
  [`tb.data.data.data`], [不存在], [`Pointwise` / `Reduction`],
)

`StorageBox.realize()` 就地把 `self.data` 换成一个包着它的 `ComputedBuffer`，*这个 buffer 就是 Scheduler 可调度的计算单元*。除了 reduction，graph 输入、buffer mutation、CUDA stream 边界、特定的 stride / layout 约束、输出是 view、多个使用者导致重复计算的风险过大、`inner_fn` 过于复杂，也都会触发 realize。各个阈值见 #xref("/posts/ml-systems/ml-compilers/torch-compile-walkthrough/")。

== 示例

本例 lowering 之后只有两个 buffer：`mean` 的 reduction 产生 `buf0`，最后的 epilogue 产生图的输出 `buf1`。其余 8 个算子都没有 realize：

#figure(fig.fig-example-ir(), caption: [Lowering 之后的两个节点。`s` 有两个使用者，没有 realize，于是它的整条计算被内联进了两个节点。]) <fig-example-ir>

`ir_pre_fusion.txt` 里 `op0` 的 loop body 能看到内联的代价。下面把每串 `ops` 调用合成了一行：

```python
class op0_loop_body:
    var_ranges = {p0: 1024, p1: 1024}
    index0 = 1024*p0 + p1                  # x[p0, p1]
    index1 = p1                            # bias[p1]
    index2 = p0                            # buf0[p0]
    def body(self, ops):
        relu   = relu(load(arg0_1, index0) * 1.1 + load(arg1_1, index1))  # a，给 a*a 的左边
        relu_1 = relu(load(arg0_1, index0) * 1.1 + load(arg1_1, index1))  # a，给 a*a 的右边
        mul_2  = relu * relu_1                                            # p = a * a
        relu_2 = relu(load(arg0_1, index0) * 1.1 + load(arg1_1, index1))  # a，给 a * 0.1
        mul_4  = relu_2 * 0.1                                             # q = a * 0.1
        add_3  = mul_2 + mul_4                                            # s = p + q
        reduction = ops.reduction(torch.float32, torch.float32, 'sum', add_3)
        ops.store_reduction('buf0', index2, reduction)
```

- *`a` 被用了三次，就内联了三次*：`x * 1.1 + bias` 和 `relu` 在 loop body 里出现三遍，`x` 也 load 了三遍。`op1` 的 loop body 也是这样从 `load(arg0_1, index0)` 开始重算。这就是 realize 规则里"多个使用者导致重复计算"的风险。
- 在 IR 里这只是表达式被复制，不一定是真的多算：codegen 生成 Triton 代码时会做公共子表达式消除（CSE），同一个 kernel 里相同的 load 和相同的计算只生成一次。
- reduction 的类型是 `sum`：`buf0` 存的是每一行的和，除以 1024 的那一步留给了使用 `buf0` 的 `op1`。
- `buf0` 的 layout 是 `size=[1024, 1], stride=[1, 1024]`，`op1` 的输出 `buf1` 是 `size=[1024, 1024], stride=[1024, 1]`。

为什么 `a` 和 `s` 都有两个使用者，却没有 realize？`run_node` 在 lowering 之后对有多个使用者的结果调用 `mark_reuse(len(n.users))`，它是否 realize 由 `StorageBox.should_realize_on_reuse` 决定。GPU 上相关的部分是：

```python
def should_realize_on_reuse(self, users):
    if users > 1 and isinstance(self.data, (Pointwise, Reduction)):
        if self.has_large_inner_fn():        # inner_fn 的 op 数超过阈值（GPU 默认 30）
            return True
        return self.num_reads() > config.realize_reads_threshold   # 读的不同 buffer 数 > 4
    return False
```

`num_reads()` 数的是 `inner_fn` 读了几个*不同的* buffer，不是 load 了几次。`a` 和 `s` 都只读 `x` 和 `bias` 两个 buffer，2 ≤ 4；`s` 的 `inner_fn` 展开后大约 20 个 op，也低于 30。所以 Inductor 判断重算比存下来便宜，两个都内联。如果 `s` 读了 5 个以上的输入，或者表达式再长一些，它就会成为一个单独的 buffer，`op0` 和 `op1` 都改成读它。

到这里 `s` 有两份副本，各在一个节点里。*如果 Scheduler 不把 `op0` 和 `op1` 合起来，`x` 就要从 HBM 读两遍*。

= Scheduling

Lowering 完成后调用 `GraphLowering.codegen()`：

```python
def codegen(self):
    with dynamo_timed("GraphLowering.codegen", log_pt2_compile_event=True):
        self.init_wrapper_code()                          # 初始化 wrapper 代码生成环境
        self._update_scheduler()                          # 创建 Scheduler，处理 self.operations
        V.debug.draw_orig_fx_graph(self.orig_gm, self.scheduler.nodes)
        self.wrapper_code.push_codegened_graph(self)
        self.scheduler.codegen()                          # 调度 IR 节点，生成 kernel 代码
        result = self.wrapper_code.generate(self.is_inference)  # 生成最终的 wrapper 代码
        self.wrapper_code.pop_codegened_graph()
        return result
```

== `Scheduler._init`

Scheduler 初始化时用 `self.nodes = [self.create_scheduler_node(n) for n in nodes]` 把 `ir.Operation` 列表转成自己的节点，然后建立依赖：

#figure(fig.fig-scheduler-init(), caption: [左：每类 `ir.Operation` 变成哪种调度节点。右：`Scheduler._init()` 里建依赖、排序、删死节点的顺序，最后进入融合。]) <fig-scheduler-init>

`SchedulerNode` 封装一个 `ComputedBuffer`（Inductor 计算表达式生成的结果）或 `TemplateBuffer`（模板代码生成的结果，例如某些专门的矩阵乘法实现）。和 IR 操作相比，*它多知道了每个操作读什么、写什么、产生哪些中间缓冲区*，这些信息记录在 `MemoryDep` 里：buffer 名、index 表达式、迭代范围。融合的所有判断都建立在 `MemoryDep` 上。

建依赖的几步：

+ *数据依赖分析*：两个操作之间没有数据依赖或其他必要的顺序依赖，就可以重排，甚至合进同一个 kernel。
+ *拓扑排序*：先算每个节点尚未满足的依赖数，再逐层取出依赖都已满足的节点。拓扑排序只保证执行顺序满足依赖，不做融合。
+ *死代码消除*：删除没有输出或不影响最终结果的节点。
+ *`compute_ancestors()`* 记录每个节点的祖先，供融合的合法性检查使用；`compute_input_distances()` 记录到图输入的距离。

== `fuse_nodes`

融合的核心是 `Scheduler.fuse_nodes()`。它最多做 10 轮 `fuse_nodes_once()`，节点数不再减少或只剩一个节点就提前停止：

```python
def fuse_nodes(self, nodes):
    for i in range(10):
        old_len = len(nodes)
        nodes = self.fuse_nodes_once(nodes, is_reorder_round=False)
        if len(nodes) == old_len or len(nodes) == 1:
            break
    if config.loop_ordering_after_fusion or config.loop_index_inversion_in_fusion:
        nodes = self.fuse_nodes_once(nodes, is_reorder_round=True)  # 允许重排循环的一轮
    return nodes
```

一轮 `fuse_nodes_once()` 分五步：

#figure(fig.fig-fuse-loop(), caption: [一轮 `fuse_nodes_once`：先找出所有合法的候选对并排序，再从高到低贪心合并；节点数还在减少就进入下一轮。]) <fig-fuse-loop>

+ *分组*：`get_possible_fusions()` 按节点用到的 buffer 名（`used_buffer_names()`）把节点分组。*只有共享至少一个 buffer 的节点才会成为候选*；`config.aggressive_fusion` 打开时，还会按 `group`（设备和迭代范围）再分一次组。
+ *配对*：组内两两配对，每个节点只和后面的 `max_fusion_buffer_group_pairwise_attempts`（64）个节点配对，避免平方级的开销。
+ *筛选*：每一对调用 `can_fuse(node1, node2)`。这一步跳过环检查，留到真正合并之前。
+ *排序*：按 `score_fusion` 的分数从高到低排序。
+ *贪心合并*：依次取出候选对，先用 `get_fused_node` 把两个节点换成它们当前所在的融合节点，*再检查一次* `can_fuse` 和 `will_fusion_create_cycle`，都通过就调用 `fuse_two_nodes` 合成 `FusedSchedulerNode`。

所以融合是*排好序的贪心*：分数高的先合并，合并后不撤销；分数低的候选如果和已合并的节点有关，用合并后的节点重新判断。

#figure(fig.fig-fusion-rounds(), caption: [`op1 → op2 → op3` 的融合：一轮里可以接连合并，开始时不是候选的组合要等下一轮。]) <fig-fusion-rounds>

== `can_fuse`

`Scheduler.can_fuse()` 的判断可以归成六类：

+ *执行合法性*：不能和自己融合，不能跨 CUDA stream 或 memory pool，device 必须相同，不能违反执行顺序。\
  例：`_fusion_blocked_by_placement`；`node2` 是 `node1` 的祖先时报 "node1 must go before node2"。
+ *节点类型*：`GroupedSchedulerNode` 不融合；`NopKernelSchedulerNode` 不做 `node1`；extern kernel、template、mixed-order / nested reduction 有专门的条件。\
  例：extern kernel 只有支持 epilogue 的用户 Triton kernel 可以，而且 `node2` 必须是只读它输出、读写 index 相同的 `Pointwise`。
+ *语义与依赖*：mutation、aliasing、`MemoryDep`、`WeakDep`、中间依赖。\
  例：`can_fuse_vertical` 要求 `node2` 对 `node1` 输出的每次读都和写匹配，两者之间不能夹着别的节点。
+ *图结构*：是否 single-use，是否有其他使用者，是否允许 prologue / epilogue。\
  例：template prologue 只能融合只有一个使用者的节点。
+ *内存与局部性*：`score_fusion_memory` 算出共享数据量，不够时尝试改变循环结构。\
  例：expand dimension、loop reorder、loop index inversion。
+ *策略与后端*：`V.choices` 的启发式和后端能力。\
  例：`V.choices.can_fuse`；`backend.can_fuse_vertical` / `can_fuse_horizontal`。

前四类决定*能不能*融合，后两类决定*值不值得*。第 5 类的流程是：

+ `shared_data_score = score_fusion_memory(node1, node2)`：两个节点完全相同的读写依赖（同一个 buffer、同一个 index）的字节数之和。没有完全相同的依赖时，非 reduction 的节点对再看读同一个 buffer 的不同部分（例如 `split` 出来的两半），算出 `buffer_overlap_score`。
+ 如果分数低于 `score_fusion_memory_threshold`（10），Inductor 会*尝试改变循环结构来制造共享*：expand dimension 把较小的 pointwise 节点扩展一个维度；loop reorder 重新排列循环，让两边的 index 一致；loop index inversion 把非连续写改写成对应的连续读。这些改动在判断最终失败时会回滚。
+ 交给 `V.choices.can_fuse`。这里的启发式不影响正确性：共享数据为 0 时拒绝（除非 `aggressive_fusion` 且两边都不是 reduction）；合并后超过 `max_fusion_size`（64）个节点时拒绝；融合会抬高峰值内存时拒绝；IO buffer 过多时拒绝。

最后一步是判断融合的类型：*`node1` 是 `node2` 的祖先就走 vertical，否则走 horizontal*。

#figure(fig.fig-fusion-kinds(), caption: [Vertical fusion 合并生产者和消费者；horizontal fusion 合并两个互不依赖、但读同一份数据的节点。]) <fig-fusion-kinds>

- *Vertical*：`can_fuse_vertical` 要求 `node2` 对 `node1` 输出的读，和 `node1` 的写是同一个位置。`MemoryDep("buf0", x)` 和 `MemoryDep("buf0", x + 1)` 读的是同一个 buffer，但不匹配：融合后 `node2` 要读的值在别的线程里，不能融合。
- *Horizontal*：没有生产者-消费者关系，靠共同的读获得收益。`V.choices.can_fuse_horizontal` 要求共享数据达到阈值，并且两个节点在原图中不能离得太远，否则可能抬高峰值内存。

`TORCH_LOGS="fusion"` 会打印每一轮的候选，以及每对节点不能融合的原因（就是源码里 `WhyNoFuse(...)("...")` 的那句话）。

== `score_fusion`

`score_fusion()` 的实现在 `torch/_inductor/choices.py` 的 `InductorChoices` 类里。它构造一个 `FusionScore`，决定存在冲突的候选按什么顺序执行：

```python
return FusionScore(
    template_score,
    node_type_score,
    memory_score,
    buffer_overlap_score,
    proximity_score,
)
```

#table(
  columns: 3,
  table.header([维度], [计算方式], [含义]),
  [`template_score`], [`node2` 是 template（prologue fusion）时为 0；否则为 `1 + (node1.is_template() == config.epilogue_fusion_first and memory_score > 0)`], [控制 template fusion 的优先级],
  [`node_type_score`], [`node1`、`node2` 同为 reduction 或同为非 reduction，且 `memory_score > 0` 时为 1，否则为 0；rnumel 不同的嵌套 reduction 为 −1], [优先融合同类节点],
  [`memory_score`], [`score_fusion_memory()`：完全相同的依赖的字节数], [估计融合省下的访存],
  [`buffer_overlap_score`], [同样来自 `score_fusion_memory()`，只在 `memory_score` 为 0 时计算], [同一 buffer 不同 index 的重叠],
  [`proximity_score`], [`-max(abs(node1.min_order - node2.max_order), abs(node2.min_order - node1.max_order))`], [原图中离得近的优先],
)

`template_score` 涉及两种融合：*epilogue fusion* 把后续计算融合进 template kernel（`node1` 是 template），*prologue fusion* 把前置计算融合进 template kernel（`node2` 是 template）。`epilogue_fusion_first` 默认是 `False`，代进公式：

- 普通融合（两边都不是 template，且有共享数据）：1 + (False == False) = *2*；
- epilogue fusion：1 + (True == False) = *1*；
- prologue fusion：*0*，源码注释是 "prologue fusion always last"。

也就是说，*默认先做普通融合，再做 epilogue，最后才是 prologue*。

`FusionScore` 不是按五个字段的字典序比较的。它的 `__lt__` 是：

```python
def __lt__(self, other):
    threshold = 16
    if self.template_score != other.template_score:
        return self.template_score < other.template_score
    if (max(self.memory_score, other.memory_score)
            > min(self.memory_score, other.memory_score) * threshold):
        return self.memory_score < other.memory_score
    return (self.node_type_score, self.memory_score,
            self.buffer_overlap_score, self.proximity_score) < (
            other.node_type_score, other.memory_score,
            other.buffer_overlap_score, other.proximity_score)
```

#figure(fig.fig-fusion-score(), caption: [两个融合候选的比较顺序：先比 template，再看省下的字节是否相差 16 倍以上，最后按四个字段依次比较。]) <fig-fusion-score>

`buffer_overlap_score` 排在 `memory_score` 后面，是为了让严格的访存节省（完全相同的依赖）优先于"读同一个 buffer、index 不同"的重叠。

== 示例

#figure(fig.fig-example-fusion(), caption: [`op0`（reduction）和 `op1`（pointwise）共享 `x` 的读，且 `op1` 读 `op0` 的输出：vertical fusion。合并后每个 program 处理一行。]) <fig-example-fusion>

按上面的流程走一遍：

+ *候选*：`op0` 和 `op1` 都读 `arg0_1`、`arg1_1`，`op1` 还读 `buf0`，它们落在同一个分组里，成为唯一的候选对。
+ *执行合法性*：都在 `cuda:0`，同一个 stream；`op1` 不是 `op0` 的祖先。
+ *Vertical*：`op1` 的 `unmet_dependencies` 是 `MemoryDep('buf0', d0, {d0: 1024})`，`op0` 是它的祖先。`op1` 对 `buf0` 的读和 `op0` 的写 `MemoryDep('buf0', d0, {d0: 1024})` 完全一致，`can_fuse_vertical` 通过。
+ *共享数据*：两边对 `arg0_1` 的依赖都是 `1024*d0 + d1`、范围 `{d0: 1024, d1: 1024}`，单这一项就是 4 MiB，加上 `arg1_1` 和 `buf0` 的小项，远超阈值 10。
+ *后端*：`op0` 的 `group.iteration` 是 `(1024, 1024)`（1024 行，每行归约 1024 个元素），`op1` 是 `(1048576, 1)`。Triton 后端允许 reduction 和 pointwise 融合的条件之一，是 pointwise 的元素数等于 reduction 的 `numel × rnumel`，并且循环范围能对齐：1048576 = 1024 × 1024，`op1` 的循环可以拆成 `op0` 的（行，列）两层。
+ *分数*：`(template 2, type 0, memory ≈ 4 MiB, overlap 0, proximity −1)`。`type` 为 0 是因为一个是 reduction、一个不是；只有一个候选，分数不影响结果。

合并结果出现在 `ir_post_fusion.txt` 里：

```python
op0_op1: FusedSchedulerNode(SchedulerNode,SchedulerNode)
op0_op1.writes = [
    MemoryDep('buf0', d0, {d0: 1024}),
    MemoryDep('buf1', 1024*d0 + d1, {d0: 1024, d1: 1024})]
op0_op1.met_dependencies = [
    MemoryDep('arg0_1', 1024*d0 + d1, {d0: 1024, d1: 1024}),
    MemoryDep('arg1_1', d1, {d0: 1024, d1: 1024}),
    MemoryDep('arg2_1', d1, {d0: 1024, d1: 1024}),
    MemoryDep('arg3_1', d1, {d0: 1024, d1: 1024})]
op0_op1.unmet_dependencies = []
```

`buf0` 不再是未满足的依赖，它在融合节点内部产生、内部使用。第一轮结束只剩一个节点，`fuse_nodes` 停止。

= Code Generation

`Scheduler.codegen()` 有两条路径：

```python
def codegen(self):
    with dynamo_timed("Scheduler.codegen"):
        return (
            self._codegen_partitions()
            if torch._inductor.config.graph_partition
            else self._codegen(self.nodes)
        )
```

没有开启 graph partition 时直接 `_codegen(self.nodes)`；开启时先划分调度图，再对每个分区生成代码。`_codegen()` 遍历融合后的节点，按类型分派：

#table(
  columns: 3,
  table.header([节点类型], [分派], [作用]),
  [Template 节点], [`backend.codegen_template(...)`], [生成模板 kernel，处理 prologue / epilogue],
  [Extern 节点], [`self.codegen_extern_call(node)`], [生成外部 kernel / 算子调用],
  [Foreach 节点], [`backend.codegen_combo_kernel(node)`], [生成组合 kernel],
  [`FusedSchedulerNode` 或 `SchedulerNode`], [`backend.codegen_node(node)`], [生成普通计算 kernel 或融合 kernel],
  [Nop 节点], [`node.mark_run()`], [只更新节点状态，不生成 kernel],
)

本例的 `op0_op1` 走 `codegen_node`，交给 Triton 后端，生成 `triton_per_fused_add_mean_mul_relu_sub_0`：

- `per` 是 persistent reduction：一行只有 1024 个元素，一个 program 把整行 load 进寄存器，不用沿归约轴循环。
- `fused_add_mean_mul_relu_sub` 来自 lowering 记录的 origins，列出了被融合的 ATen 算子。
- 两个节点的 loop body 生成在同一个 kernel 里。三份 `x` 的 load、三遍 `relu` 是同样的表达式，CSE 只保留一份。
- `buf0` 在这个 kernel 里产生，也在这个 kernel 里最后一次使用。`remove_kernel_local_buffers()` 会删掉这样的 buffer（源码注释："Any buffers that are both created and have a last use in the same kernel can be removed"），所以行和不写回 HBM，留在寄存器里。

最终这个 kernel 从 HBM 读一次 `x`，写一次 `y`，和第一节估算的 8 MiB 一致。`wrapper_code.generate()` 生成调用它的 Python wrapper：分配 `buf1`，launch 一次 kernel。

= TVM

TVM 在融合之前，先给每个算子标注一个 `OpPatternKind`，描述它的计算特征，而不是只看算子的名字：

#table(
  columns: 3,
  table.header([Pattern Kind], [计算特征], [典型算子]),
  [`kElemWise`], [输入与输出逐元素对应], [Add、ReLU、Exp],
  [`kBroadcast`], [输入需要广播后参与计算], [BiasAdd],
  [`kInjective`], [输出元素与输入元素之间是单射关系], [Reshape、Transpose],
  [`kCommReduce`], [多个输入元素聚合成一个输出元素], [Sum、Max、Mean],
  [`kOutEWiseFusable`], [复杂计算，但允许融合后续的 elementwise], [Conv2D、MatMul],
  [`kTuple`], [Tuple 节点，有特殊的融合规则], [Tuple],
  [`kOpaque`], [不适合参与普通融合], [外部函数、有副作用的操作],
)

融合分三步（Relax 中的 pass）：

+ *`AnnotateTIROpPattern`*：分析每个 TIR 函数的计算模式，标注 `OpPatternKind`。
+ *`FuseOps`*：构建计算图（`IndexedForwardGraph`）和 *post-dominator tree*，根据 pattern 的兼容性划分融合组，用 union-find 管理组。
+ *`FuseTIR`*：把同一组的多个 TIR 函数合成一个，消除中间 buffer 的物化和读写。

节点 B *post-dominate* 节点 A，是指从 A 到图输出的每条路径都经过 B。`FuseOps` 对每个节点尝试把它并进它的直接 post-dominator 所在的组，条件是两者之间*所有路径上*的节点都满足一个和 pattern 有关的条件（源码里的 `CheckPath`）。规则是：

#table(
  columns: 2,
  table.header([Pattern], [规则]),
  [`OutEWiseFusable`], [可以和后面的 elementwise / broadcast 融合；两个复杂算子不能在同一组（`CombinePattern` 直接报错）],
  [`Injective`], [可以和 injective 或更简单的操作融合（推迟到 phase 1，保证 conv2d 先融合完）],
  [`ElemWise` / `Broadcast`], [可以融合进后面的 injective、reduction 等节点],
  [`CommReduce`], [只能作为融合组的 sink，不主动向后发起融合],
  [`Opaque`], [融合屏障],
)

把同一个模型套进这套规则（按规则推导，没有实际运行 TVM）：

#figure(fig.fig-tvm-groups(), caption: [按 TVM 的规则，本例分成 3 组：`s` 及之前的 elementwise、单独的 `mean`、最后的 epilogue。]) <fig-tvm-groups>

- `relu` 的直接 post-dominator 是 `p + q`，中间的 `a·a`、`a·0.1` 都是 elementwise，满足条件，*两个分支汇合的菱形被整个并进一组*。`·1.1`、`+bias` 也沿着链并进来。
- `s` 有两条出路：`s → mean → s − m` 和 `s → s − m`，它的直接 post-dominator 是 `s − m`。第一条路径经过 `mean`，它是 `CommReduce`，不满足"中间都是 injective 以下"的条件，*`s` 不能融合*。
- `mean` 是 `CommReduce`，不主动向后融合；`s − m`、`·γ`、`+β` 是一条 broadcast 链，合成第三组。

结果是 3 个 kernel，`s` 要写回 HBM，再被 `mean` 和 `s − m` 各读一遍。Inductor 得到 1 个 kernel，靠的是两件 TVM 这套规则里没有的东西：lowering 时允许重算 `s`，以及 reduction 和 numel 对得上的 pointwise 可以融合。

#table(
  columns: 3,
  table.header([], [TVM `FuseOps`], [Inductor Scheduler]),
  [决策依据], [算子的 pattern 类别和 post-dominator 结构], [循环级 IR 上的 `MemoryDep`：读写哪个 buffer、哪个 index],
  [决策时机], [在算子图上，生成融合后的 TIR 之前], [lowering 之后，codegen 之前],
  [收益估计], [没有显式打分，满足规则就融合], [`score_fusion`：省下的字节、节点类型、距离],
  [搜索方式], [按 post-DFS 顺序遍历，分 3 个 phase], [候选排序后贪心，最多 10 轮],
  [reduction 之后的算子], [reduction 只能做组的 sink], [元素数对得上时，pointwise 可以接在 reduction 后面],
  [多使用者的中间结果], [每个算子只属于一个组，组之间经过内存], [lowering 可以内联（重算），由 realize 规则控制],
)

= Open Questions

从上面的机制看，TorchInductor 的融合策略至少有三个方向可以追问：

- *Fusion legality：合法性判断是否充分。* `can_fuse` 里有大量针对特定节点类型的特例；Preprocessing 里的 `remove_noop_ops`、`remove_assert_ops`、`reorder_for_locality` 等 pass 也需要判断"什么情况下可以改"。这些判定会不会有遗漏或错误，可以构造触发它们的代码段，结合已有的有代表性的 issue，从代码的工作机制入手检查。
- *Fusion profitability：打分是否合理。* `score_fusion` 只看字节数、节点类型和距离，不看寄存器压力和并行配置的冲突，也就是第一节里的三项代价都没有进入分数。只有设置了 `TORCHINDUCTOR_BENCHMARK_FUSION=1`（`config.benchmark_fusion`），`speedup_by_fusion` 才会实际编译、测量融合前后的 kernel。
- *Fusion search：是否有更好的搜索策略。* 现在是排序后的贪心：候选只在共享 buffer 的节点之间产生，每个节点只配对后面 64 个，最多 10 轮。贪心的顺序会不会错过更好的分组，能不能用更全局的搜索。

另一条路是借鉴其他深度学习编译器：通用的算子融合可以参考 TVM、Ansor、Welder、Unity 的设计；针对模型结构的优化可以面向 Transformer、Attention、Normalization 这类典型计算结构设计专门策略，类似 GALA 针对 GNN 的做法。相关工作：

- GALA: A High Performance Graph Neural Network Acceleration LAnguage and Compiler（OOPSLA2）
- Understanding and Finding JIT Compiler Performance Bugs（OOPSLA1）
- CIPIHunter: Detecting Configuration-Induced Prediction Instability in Deep Learning Frameworks（ASE '26）
- Dynamic Co-Optimization Compiler: Leveraging Multi-Agent Reinforcement Learning for Enhanced DNN Accelerator Performance（ASPDAC '25）
- AutoPass: Evidence-Guided LLM Agents for Compiler Performance Tuning（2026）

= Summary

- *融合是交换*：用更大的 kernel 换更少的访存和 launch。本例从 10 个 kernel、约 80 MiB 访存变成 1 个 kernel、约 8 MiB。
- *Inductor 的"融合"分在三处*：lowering 把 `Pointwise` 内联进使用者，Scheduler 把 `SchedulerNode` 合成 `FusedSchedulerNode`，codegen 做 CSE 并删掉 kernel 内部的 buffer。
- *Scheduler 的融合是排好序的贪心*：`get_possible_fusions` 只在共享 buffer 的节点之间找候选，`can_fuse` 判断合法性和共享数据，`score_fusion` 排序，`fuse_nodes` 最多 10 轮。
- *`FusionScore` 不是字典序*：template 优先级最先比较；省下的字节相差 16 倍以上时直接决定；否则同类节点优先于字节数。
- *和 TVM 相比*，Inductor 基于 `MemoryDep` 而不是算子类别做决定，能重算中间结果、能把 pointwise 接在 reduction 后面，所以同一个模型 TVM 按规则是 3 组，Inductor 是 1 个 kernel。
