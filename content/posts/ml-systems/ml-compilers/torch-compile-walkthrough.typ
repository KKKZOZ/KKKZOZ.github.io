#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": hint, xref
#import "/utils/figures/torch-compile.typ" as fig

#tola-meta((
  title: "torch.compile Walkthrough",
  date: "2026-10-20",
  summary: "用 ((a + b) * c.relu()).sum(dim=-1) 跟踪 torch.compile 的每个阶段：Dynamo FX Graph、AOT ATen Graph、TorchInductor IR（TensorBox / StorageBox / Pointwise / Reduction / realize）、Scheduler 与生成的 kernel。",
  tags: ("ML Compilers", "torch.compile"),
  weight: 10,
))

#hint[各阶段的职责和它们在 IR 分层中的位置见 #xref("/posts/ml-systems/ml-compilers/overview/")。本文只跟踪一个具体例子在每个阶段的产物。]

下面各阶段的产物来自同一次编译：PyTorch `2.11.0+cu130`，运行设备为 NVIDIA RTX A6000，`a`、`b`、`c` 都是连续的 `float32[4, 128]`，输出 shape 为 `[4]`：

```python
def fn(a, b, c):
    return ((a + b) * c.relu()).sum(dim=-1)

a, b, c = (torch.randn(4, 128, device="cuda") for _ in range(3))
out = torch.compile(fn)(a, b, c)
```

这个函数里既有 elementwise（`+`、`relu`、`*`），也有 reduction（`sum`），正好覆盖 Inductor IR 中 `Pointwise` 和 `Reduction` 两类节点。

#hint[日志来自 `TORCH_LOGS` 中的 `guards`、`aot_graphs`、`post_grad_graphs`、`ir_pre_fusion`、`ir_post_fusion`、`output_code`，以及 `TORCH_COMPILE_DEBUG=1` 生成的 debug 目录。]

= Graph Capture：TorchDynamo

在 Dynamo 与 Inductor 的边界放一个 backend wrapper，打印它收到的 `GraphModule`。`gm.code` 是这张图对应的 Python 代码（`l_a_ = l_b_ = None` 一类语句是 FX 插入的引用释放）：

```python
def forward(self, L_a_ : torch.Tensor, L_b_ : torch.Tensor, L_c_ : torch.Tensor):
    l_a_ = L_a_
    l_b_ = L_b_
    l_c_ = L_c_
    add = l_a_ + l_b_;  l_a_ = l_b_ = None
    relu = l_c_.relu();  l_c_ = None
    mul = add * relu;  add = relu = None
    sum_1 = mul.sum(dim = -1);  mul = None
    return (sum_1,)
```

`gm.graph` 是同一张图的 node-level 表示：

```text
graph():
    %l_a_ : torch.Tensor [num_users=1] = placeholder[target=L_a_]
    %l_b_ : torch.Tensor [num_users=1] = placeholder[target=L_b_]
    %l_c_ : torch.Tensor [num_users=1] = placeholder[target=L_c_]
    %add : [num_users=1] = call_function[target=operator.add](args = (%l_a_, %l_b_), kwargs = {})
    %relu : [num_users=1] = call_method[target=relu](args = (%l_c_,), kwargs = {})
    %mul : [num_users=1] = call_function[target=operator.mul](args = (%add, %relu), kwargs = {})
    %sum_1 : [num_users=1] = call_method[target=sum](args = (%mul,), kwargs = {dim: -1})
    return (sum_1,)
```

每一行是一个 `torch.fx.Node`：

- 三个 `placeholder` 是三个参数。Dynamo 用 `L_a_` 这样的名字指代 frame 里的局部变量 `a`。
- `a + b` 和 `add * relu` 是 Python 运算符，记录为 `call_function`，target 是 `operator.add` / `operator.mul`。
- `c.relu()` 和 `.sum(dim=-1)` 是 Tensor 方法，记录为 `call_method`；`dim=-1` 原样留在 `kwargs` 里。
- `num_users` 都是 `1`：每个中间结果只被下一个 node 使用一次。
- `return (sum_1,)` 是 FX Graph 的 `output` node。

#fig.fig-fx-graph()

这一层还是 Python 语义：记录的是 `operator.add` 和 `Tensor.sum`，还没有对应到具体的 ATen overload。

Dynamo 同时为每个输入建立 guard。下面是 `a` 的 guard，`b`、`c` 的 `TENSOR_MATCH` 相同：

```python
TENSOR_MATCH: check_tensor(
    L['a'], Tensor,
    DispatchKeySet(
        CUDA,            # 数据位于 CUDA，operator dispatch 到 CUDA kernel
        BackendSelect,   # Dispatcher 用它参与选择具体 backend
        ADInplaceOrView, # autograd 的 inplace / view bookkeeping
        AutogradCUDA,    # autograd 层；普通 dense tensor 都带这个 key，与 requires_grad 无关
    ),
    torch.float32, device=0, requires_grad=False,
    size=[4, 128], stride=[128, 1]
)
NO_TENSOR_ALIASING: check_no_aliasing(L['a'], L['b'], L['c'])
```

`TENSOR_MATCH` 约束 shape、stride、dtype、device 和 `requires_grad`；`device=0` 是 GPU 编号，换到 `cuda:1` 上调用也会重新编译。`NO_TENSOR_ALIASING` 要求三个输入互不 alias：编译结果假设 `a`、`b`、`c` 指向不同的内存，如果之后调用 `fn(x, x, y)`，guard 失败，Dynamo 会重新编译。

= Graph Normalize: AOTAutograd

AOTAutograd 把 Dynamo 的图规范化为 ATen FX Graph（`fx_graph_readable.py`，省略了引用释放语句和源码注释）：

```python
def forward(self, arg0_1: "f32[4, 128]", arg1_1: "f32[4, 128]", arg2_1: "f32[4, 128]"):
    add: "f32[4, 128]" = torch.ops.aten.add.Tensor(arg0_1, arg1_1)
    relu: "f32[4, 128]" = torch.ops.aten.relu.default(arg2_1)
    mul: "f32[4, 128]" = torch.ops.aten.mul.Tensor(add, relu)
    sum_1: "f32[4]" = torch.ops.aten.sum.dim_IntList(mul, [-1])
    return (sum_1,)
```

- 输入改名为 `arg0_1`、`arg1_1`、`arg2_1`，每个值都带上了 shape 和 dtype。
- 每个 Dynamo node 对应一个具体的 ATen overload。`mul.sum(dim=-1)` 选中的是 `aten.sum.dim_IntList`，`dim` 变成位置参数 `[-1]`。
- 这四个 op 本身就是 Inductor 能直接 lower 的 ATen op，没有被继续 decompose；全程是 `float32`，也没有插入 dtype 转换。
- 这是 inference 编译，没有 backward graph；函数里没有 mutation，functionalization 也没有改动任何东西。

#fig.fig-aot-map()

= Graph Optimization：TorchInductor Graph Passes

这次运行中，Inductor 的 pre-grad 和 post-grad FX passes 都执行了，但 `fx_graph_readable.py` 与 `fx_graph_transformed.py` 完全相同，operation sequence 保持不变：

```text
aten.add.Tensor
aten.relu.default
aten.mul.Tensor
aten.sum.dim_IntList
```

也就是说，`remove_noop_ops`、pattern rewrite 和 reorder 都没有找到适用于这张图的 FX-level transformation。本例的主要变化出现在后续 lowering、scheduling 和 codegen。

= Lowering + Scheduling: TorchInductor IR

== Inductor IR 的核心对象

`GraphLowering` 是一个 `torch.fx.Interpreter`：它按顺序执行 ATen FX Graph 中的每个 node，对每个 node 调用对应的 lowering 函数。lowering 函数的输入和输出都不是真实 tensor，而是一组通过 `.data` 串起来的 IR 对象。下图取本例的三个 FX node，画出 lowering 结束时它们各自的 `.data` 链，字段值都是实际打印出来的：

#fig.fig-ir-model()

从左往右读：

- *`TensorBox`* 回答"这个值是谁"。每个 FX node 的 lowering 结果都是一个 `TensorBox`，lowering 函数之间传递的也是它。
- *View* 回答"怎么索引"：它不拥有内存，只描述如何用新的 index 访问底层 storage。本例的输入都是连续 tensor，也没有 view 操作，所以这一列是空的，`TensorBox.data` 直接就是 `StorageBox`。如果像 SiluAndMul 那样对输入做 `chunk`，lowering 会得到带 `FixedLayout(size, stride, offset)` 的 `ReinterpretView`，它指向输入原来的 `StorageBox`，不复制数据。
- *`StorageBox`* 回答"数据在哪"。它是可变的 box，`.data` 在三行里分别是三种状态：
  - `arg0_1`：graph 输入本来就有内存，`.data` 一开始就是 `InputBuffer`，带 name 和 `FixedLayout`。
  - `add`：`.data` 是一个未 realize 的 `Pointwise`。它只有 `ranges = [4, 128]` 和一个 `inner_fn`：给定 `(i0, i1)`，从 `arg0_1`、`arg1_1` 各 load 一个元素再相加。它还没有决定结果写到哪里，也没有任何内存。
  - `sum_1`：lowering 先得到一个 `Reduction`，随即 realize。`StorageBox.data` 被就地替换成 `ComputedBuffer buf0`，原来的 `Reduction` 成为 `buf0.data`。
- *数据是什么*：`Pointwise` / `Reduction` 都继承自 `Loops`，只描述"每个输出元素怎么算"；`Buffer` 是有名字、有 layout 的真实内存。注意 `buf0.data` 中 `Reduction` 的 `inner_fn` 已经包含了 `add`、`relu`、`mul`：它直接从三个输入 load，而不是去读 `add` 的结果。这就是下一节要讲的内联。

这几类对象与 #xref("/posts/ml-systems/ml-compilers/overview/", body: [ML Compilers Overview]) 中 Tensor IR 的三类抽象一一对应：`Pointwise` 对应 Elementwise，`Reduction` 对应 Reduction，View 对应 IndexMap。

== Lowering 结果

在 `GraphLowering.run_node` 外面包一层，就能看到每个 FX node 的 lowering 结果：

```python
from torch._inductor.graph import GraphLowering

orig_run_node = GraphLowering.run_node

def run_node(self, n):
    result = orig_run_node(self, n)  # 执行该 node 的 lowering
    print(n.name, chain(result))     # chain()：沿 .data 逐层展开，并打印 layout
    return result

GraphLowering.run_node = run_node
```

输出如下（整理了格式）：

```text
arg0_1  TensorBox → StorageBox → InputBuffer(arg0_1, size=[4, 128], stride=[128, 1])
arg1_1  TensorBox → StorageBox → InputBuffer(arg1_1, size=[4, 128], stride=[128, 1])
arg2_1  TensorBox → StorageBox → InputBuffer(arg2_1, size=[4, 128], stride=[128, 1])
add     TensorBox → StorageBox → Pointwise(ranges=[4, 128])
relu    TensorBox → StorageBox → Pointwise(ranges=[4, 128])
mul     TensorBox → StorageBox → Pointwise(ranges=[4, 128])
sum_1   TensorBox → StorageBox → ComputedBuffer(buf0, size=[4], stride=[1]) → Reduction
```

下图中的每一行对应上面输出的一行：

#fig.fig-inductor-objects()

- *Pointwise 内联*：`add`、`relu`、`mul` 的 lowering 各创建一个 `Pointwise`，它的 `inner_fn` 通过输入的 loader 读取输入。输入如果也是未 realize 的 `Pointwise`，读取就是直接调用对方的 `inner_fn`。所以这三个 `StorageBox` 从未 realize：`[4, 128]` 的中间结果既没有 buffer，也没有内存读写。
- *Reduction*：`sum_1` 的 lowering 创建一个 `Reduction`，它的 `inner_fn` 读取 `mul`，也就是把 `(a + b) * relu(c)` 整个内联进了 reduction 的循环体。输出 ranges 是 `[4]`，reduction ranges 是 `[128]`，`reduction_type` 是 `sum`。
- *Buffer*：`Reduction` 创建后会立即 realize（`sum_1` 同时也是 graph output），得到整张图唯一的 `ComputedBuffer` `buf0`，shape 是 `[4]`。

== realize：StorageBox 什么时候变成 Buffer

`StorageBox.realize()` 的核心逻辑如下（节选自 `torch/_inductor/ir.py`）：

```python
class StorageBox(MutableBox):
    def realize(self):
        if IRNode.is_realized_node(self.data):
            return self.data.get_name()
        self.data = ComputedBuffer(          # 原来的 Pointwise / Reduction
            name=None,                       # 成为 ComputedBuffer.data
            layout=FlexibleLayout(device=..., dtype=..., size=self.data.get_size()),
            data=self.data,
        )
        self.data.name = V.graph.register_buffer(self.data)  # 分配名字 buf0、buf1 ...
        V.graph.register_operation(self.data)                # 之后成为一个 SchedulerNode
        return self.data.name
```

#fig.fig-realize()

`FlexibleLayout` 表示 stride 还可以由后续决定；`buf0` 最终被固定为 `FixedLayout(size=[4], stride=[1])`，也就是 Scheduler 日志中的 `buf0.layout`。

realize 是一个取舍：不 realize 就要在每个使用者里重算一遍（内联），realize 就要多一次写和读。Inductor 在以下情况 realize：

#table(
  columns: 3,
  table.header([触发条件], [位置], [本文的例子]),
  [graph output], [`GraphLowering.run_node`], [`sum_1` → `buf0`],
  [`Reduction`], [`make_reduction()` 创建后立即 `realize()`], [`sum_1` → `buf0`],
  [被多次使用，且读次数超过 `realize_reads_threshold`（4）、`inner_fn` 过大，或在 CPU 上包含 `exp` / `sigmoid`], [`StorageBox.mark_reuse()`], [——],
  [读次数累积超过 `realize_acc_reads_threshold`（8）], [`has_exceeded_max_reads()`], [——],
  [被 extern kernel（如 `mm`）或 fallback op 使用，它们只能读真实内存], [`realize_hint()` / `ExternKernel.realize_input()`], [——],
)

每个 realize 出来的 `ComputedBuffer` 都会成为一个 `SchedulerNode`。本例只有 `buf0`，所以后面只有一个 `op0`。

== Pointwise 与 Reduction：loop body

`op0` 的 loop body 如下（来自 `TORCH_LOGS=ir_pre_fusion`，把 `self.get_index(...)` 直接替换成了 index 名）：

```python
class op0_loop_body:
    var_ranges = {p0: 4, p1: 128}
    index0 = 128*p0 + p1
    index1 = p0
    def body(self, ops):
        load = ops.load('arg0_1', index0)
        load_1 = ops.load('arg1_1', index0)
        add = ops.add(load, load_1)
        load_2 = ops.load('arg2_1', index0)
        relu = ops.relu(load_2)
        mul = ops.mul(add, relu)
        reduction = ops.reduction(torch.float32, torch.float32, 'sum', mul)
        ops.store_reduction('buf0', index1, reduction)
```

`p0` 是输出轴，`p1` 是 reduction 轴。`add`、`relu`、`mul` 三个 `Pointwise` 在这里变成了三条 `ops` 调用；`ops.reduction` 沿 `p1` 累加 `mul`，`ops.store_reduction` 对每个 `p0` 只写一次。

下图画出 `p0 = 1` 这一行，以及其中 `p1 = 5` 这个元素；图中的 index 与上面 loop body 中的 index 相同：

#fig.fig-reduction-index()

- 三个输入的 layout 相同，所以三次 `ops.load` 共用同一个 `index0 = 128*p0 + p1`；写出只依赖输出轴，`index1 = p0`。
- 如果 reduction 的结果还要被后续 elementwise 使用（例如 RMSNorm 先求平方和再归一化），那个 elementwise 会成为第二个 `SchedulerNode`。它读取 `buf0`，所以它的 `unmet_dependencies` 里有 `buf0`，必须在 `op0` 之后执行。

== Scheduler：SchedulerNode 与 MemoryDep

Scheduler 看到的 `op0`（`TORCH_LOGS=ir_pre_fusion`，省略了 loop body）：

```python
op0: SchedulerNode(ComputedBuffer)
op0.writes = [MemoryDep('buf0', d0, {d0: 4})]
op0.unmet_dependencies = []
op0.met_dependencies = [
    MemoryDep('arg0_1', 128*d0 + d1, {d0: 4, d1: 128}),
    MemoryDep('arg1_1', 128*d0 + d1, {d0: 4, d1: 128}),
    MemoryDep('arg2_1', 128*d0 + d1, {d0: 4, d1: 128}),
]
op0.outputs = [buf0: ComputedBuffer]
buf0.layout = FixedLayout('cuda:0', torch.float32, size=[4], stride=[1])
op0.group.device = cuda:0
op0.group.iteration = (4, 128)
op0.sizes = ([4], [128])
```

下图把这些字段放回数据流里：左边是读依赖，右边是写依赖，`op0` 内部是 `sizes` 和 loop body：

#fig.fig-scheduler-node()

- `MemoryDep` 记录一次读或写访问哪个 buffer、用什么 index、在什么范围上。三个输入的读依赖就是 loop body 里的 `index0 = 128*p0 + p1`（变量换成了 `d0`、`d1`），范围 `{d0: 4, d1: 128}`；写出是 `buf0` 的 `d0`，即 `index1 = p0`。
- `met_dependencies` 里全是 graph 输入，`unmet_dependencies` 为空：`op0` 不依赖任何其他 `SchedulerNode`。
- `sizes` 的两个部分分别是普通的 iteration ranges 和 reduction ranges；纯 `Pointwise` 的第二部分为空。`group.iteration = (4, 128)` 是 Triton 后端对应的 `(xnumel, r0_numel)`，后面的 kernel 就按它划分。

pre-fusion 和 post-fusion 都只有这一个 `op0`。这并不表示没有发生 fusion：`add`、`relu`、`mul` 在 lowering 时就已经内联进了 `Reduction` 的 `inner_fn`，Scheduler 不需要再构造 `FusedSchedulerNode`。

两份日志唯一的区别在依赖的写法。post-fusion 中，`op0` 的依赖变成了：

```python
op0.writes = [MemoryDep('buf0', c0, {c0: 4})]
op0.met_dependencies = [
    MemoryDep('arg0_1', c0, {c0: 512}),
    MemoryDep('arg1_1', c0, {c0: 512}),
    MemoryDep('arg2_1', c0, {c0: 512}),
]
```

原因是 GPU 上默认开启了 `loop_ordering_after_fusion`。fusion 之前，Scheduler 不对依赖做 normalize，保留 `d0`、`d1` 两个维度，方便在融合时按依赖重新决定循环顺序；fusion 结束后，`Scheduler.merge_loops()` 合并可以合并的循环并重新计算依赖。`128*d0 + d1` 在 `{d0: 4, d1: 128}` 上恰好是 `0..511` 的连续访问，所以被合并成一维的 `c0, {c0: 512}`，也就是上图下半部分画的化简。

= Backend Codegen: Triton

`op0` 交给 `TritonScheduling`，生成一个 Triton kernel。下面是 kernel 本体（省略了 `rnumel`、`RBLOCK`、`roffset` 等几个未使用的别名变量）：

```python
@triton_heuristics.persistent_reduction(
    size_hints={'x': 4, 'r0_': 128},
    reduction_hint=ReductionHint.INNER,
    ...
)
@triton.jit
def triton_per_fused_add_mul_relu_sum_0(in_ptr0, in_ptr1, in_ptr2, out_ptr0,
                                        xnumel, r0_numel, XBLOCK : tl.constexpr):
    xnumel = 4
    r0_numel = 128
    R0_BLOCK: tl.constexpr = 128
    xoffset = tl.program_id(0) * XBLOCK
    xindex = xoffset + tl.arange(0, XBLOCK)[:, None]
    xmask = xindex < xnumel
    r0_index = tl.arange(0, R0_BLOCK)[None, :]
    r0_1 = r0_index
    x0 = xindex
    tmp0 = tl.load(in_ptr0 + (r0_1 + 128*x0), xmask, other=0.0)
    tmp1 = tl.load(in_ptr1 + (r0_1 + 128*x0), xmask, other=0.0)
    tmp3 = tl.load(in_ptr2 + (r0_1 + 128*x0), xmask, other=0.0)
    tmp2 = tmp0 + tmp1
    tmp4 = tl.full([1, 1], 0, tl.int32)
    tmp5 = triton_helpers.maximum(tmp4, tmp3)
    tmp6 = tmp2 * tmp5
    tmp7 = tl.broadcast_to(tmp6, [XBLOCK, R0_BLOCK])
    tmp9 = tl.where(xmask, tmp7, 0)
    tmp10 = tl.sum(tmp9, 1)[:, None].to(tl.float32)
    tl.store(out_ptr0 + (x0), tmp10, xmask)
```

- kernel 名里的 `per` 表示 persistent reduction，`fused_add_mul_relu_sum` 列出了被融合的 ATen op。
- *两个维度*：`x` 是输出轴（`xnumel = 4`），`r0_` 是 reduction 轴（`r0_numel = 128`），对应 loop body 的 `p0`、`p1`。每个 program 处理一块 `[XBLOCK, R0_BLOCK]` 的 tile，`r0_1 + 128*x0` 就是 `index0`。
- *persistent reduction*：一行只有 128 个元素，`R0_BLOCK` 直接取 `128`，一个 program 一次就把整行 load 进寄存器，不需要沿 reduction 轴循环累加，也就没有 `r0_mask`。
- `relu` 被生成为 `maximum(0, x)`。`tl.where(xmask, …, 0)` 把越界行置零，再由 `tl.sum(…, 1)` 沿 reduction 轴求和，每行写出一个值，地址就是 `index1 = x0`。

这个 kernel 的启发式只给出一个候选配置，所以没有实际 benchmark，直接使用：

```text
XBLOCK: 1, num_warps: 2, num_stages: 1    (n_regs 19)
```

`XBLOCK = 1`，所以 grid 是 `xnumel / XBLOCK = 4` 个 program，每个 program 负责一行。`num_warps = 2` 即 64 个线程，一行 128 个元素平均每个线程分到 2 个：

#fig.fig-triton-programs()

Wrapper 中只有一次 output allocation 和一次 kernel launch（省略了 device guard 和释放输入的 `del`）：

```python
def call(self, args):
    arg0_1, arg1_1, arg2_1 = args
    args.clear()
    assert_size_stride(arg0_1, (4, 128), (128, 1))
    assert_size_stride(arg1_1, (4, 128), (128, 1))
    assert_size_stride(arg2_1, (4, 128), (128, 1))
    buf0 = empty_strided_cuda((4, ), (1, ), torch.float32)
    stream0 = get_raw_stream(0)
    triton_per_fused_add_mul_relu_sum_0.run(arg0_1, arg1_1, arg2_1, buf0, 4, 128, stream=stream0)
    return (buf0, )
```

记 `N = 4 × 128 = 512`。eager 模式下 `add`、`relu`、`mul`、`sum` 是四个独立的 kernel，三个 `[4, 128]` 的中间结果都要写回 HBM 再读出来：一共读 `6N`、写 `3N + 4` 个 `float`，launch 4 次。编译后的 kernel 只读三个输入（`3N`），只写 `4` 个结果，中间值都留在寄存器里，launch 1 次。
