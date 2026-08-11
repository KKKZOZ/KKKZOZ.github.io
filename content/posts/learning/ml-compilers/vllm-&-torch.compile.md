---
title: "vllm & torch.compile"
tags:
  - ML Compilers
  - torch.compile
  - vLLM
date: 2026-08-11
showtoc: true
weight: 10
---

vLLM 中同时存在多条与 FX 和 `torch.compile` 相关的执行路径，它们虽然共享 PyTorch 的 graph infrastructure，但解决的问题并不相同。理解这些路径的边界，是区分“模型结构改写”“Inductor 编译优化”和“CUDA Graph replay”的前提。

进入正文前，可以先区分三类用法：

- **HF Transformers modeling backend**：直接使用 `fx.Tracer` 分析 Hugging Face `forward`，识别可融合结构并通过 AST 改写模型源码
- **vLLM 自定义 `torch.compile` 主路径**：由 Dynamo 产生完整 FX `GraphModule`，再由 vLLM 控制 graph partition、shape specialization、custom passes、cache 和 CUDA Graph integration
- **普通 `@torch.compile` 小函数**：FX 主要作为 Dynamo、AOTAutograd 和 Inductor 的内部 IR，vLLM 通常不直接处理这些 graph

Piecewise CUDA Graph 不是第四条独立的 tracing 路径，而是建立在 vLLM Piecewise Compilation 之上的运行时优化：编译阶段先拆分并编译 graph regions，随后只对兼容区域执行 CUDA Graph capture/replay。

> 这篇文章的核心问题是：vLLM 如何围绕标准 `torch.compile` 增加一层 LLM-serving-aware 的 graph processing、compilation policy 和 runtime integration。

## HF Transformers modeling backend

> 这里是指 vLLM 的 Transformers modeling backend

它使用经典的 `torch.fx` symbolic tracing：

- 自定义 `_AllLeafTracer(fx.Tracer)`，将所有子模块视作 leaf
- 用 `_SizedProxy` 处理 shape 解包
- 即使 trace 中途失败，也保留 partial FX graph
- FX 图仅用于结构匹配
- 真正的修改通过 AST 重写原始 forward 源码完成

调用链大致是：

```ascii
HF nn.Module
-> custom fx.Tracer
-> fx.Graph
-> pattern matching
-> AST rewrite / module replacement
```

get_fuser() 对每种 module class trace 一次，然后匹配 vllm 中对应的 fuser：

- GLU：gate_proj + up_proj
- QKV：q_proj + k_proj + v_proj
- RMSNorm：根据 tensor dataflow 识别
- MoE：识别 router、expert 和 shared expert 结构

匹配完成后执行 module replacement

这个 FX 用途和 torch.compile 相互独立。即使模型最终 eager 执行，Transformers backend 的模型结构融合仍然可以使用 FX

## torch.compile with vLLM backend

### Overview

vLLM 没有替换 TorchDynamo 或 TorchInductor，而是在标准 `torch.compile` pipeline 上增加面向 LLM serving 的编译控制

官方将 `VLLM_COMPILE` 定义为带有 caching、piecewise compilation、shape specialization 和 custom passes 的 Inductor-based backend。([vLLM torch.compile][1])

因此，`vllm_backend` 的主要价值不是提供另一套 GPU codegen，而是决定什么 graph 交给 Inductor、以什么 shape 编译、何时编译，以及如何在 serving runtime 中复用编译结果。

| 增强方向 | vLLM 解决的问题 |
| --- | --- |
| graph capture、主动分区与 stitching | 隔离复杂 serving logic，并以低开销 Python function 调度拆分后的 regions |
| shape 管理 | 用 general dynamic path 覆盖动态请求，并为高频 shape 生成 specialized kernel |
| custom Inductor passes | 加入 LLM-specific fusion 和 graph transformation |
| cache 与编译生命周期 | 复用 serving configuration 对应的 artifact，并将编译移出请求路径 |
| CUDA Graph 协同 | 根据 graph region 和 runtime batch 选择 capture/replay 策略 |

### Graph Capture 与主动分区

vLLM 首先在模型实现层面构造 compiler-friendly graph。

Attention 需要处理 KV Cache、block table、variable sequence length、attention metadata 和 backend selection；如果 Dynamo 继续追踪这些内部逻辑，容易遇到复杂 control flow 或 graph break。

vLLM 将整个 Attention 封装为 `torch.ops.vllm.unified_attention_with_output` custom op。Dynamo 将其视为 opaque FX node，不检查内部操作；由于该 op 的 output 与 query 具有相同的外部 shape，模型 `forward` 仍可从 Dynamo 视角形成 full graph。([vLLM torch.compile][1]) 这也是以下配置能够用于复杂 serving workload 的前提：

```python
torch.compile(
    self.forward,
    fullgraph=True,
    backend=vllm_backend,
)
```

获得完整 FX Graph 后，vLLM 再根据 operator 和 runtime 特性主动设置 compilation boundary：

- 传统路径使用 `splitting_ops` 将 Attention 与相邻计算区域分开
- 较新的 `use_inductor_graph_partition` 路径则在 Inductor passes 和 fusion 完成后，根据 `cudagraph_unsafe` op 建立边界。([CompilationConfig][2])

这种主动分区不同于 Dynamo graph break：graph break 是 tracing 中断形成的边界，而 piecewise partition 是在已有完整 graph 上做出的编译策略。它允许 Attention 继续使用 custom kernel 和 runtime，同时让 Linear、Norm、activation 等区域进入 Inductor。具体的 Piecewise CUDA Graph 执行方式将在下一节说明。

#### Stitching codegen

Graph 被拆分后，各个 region 可以分别交给 Inductor，但系统仍需要恢复原始 `forward` 的调用顺序和 Tensor 数据依赖。当前实现中的 `vllm/compilation/codegen.py` 为此生成一个 straight-line Python function：它负责调用 compiled region 和 custom op、传递中间结果并返回最终输出，不负责生成 Tensor kernel。([vLLM codegen.py][3])

整个过程可以概括为：

```text
                    split GraphModule
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
          subgraph 0    Attention    subgraph 1
              │        custom op         │
              ▼                          ▼
           Inductor                   Inductor
              │                          │
       compiled callable 0       compiled callable 1
              │                          │
              └──────────┬───────────────┘
                         ▼
              vLLM stitching codegen
                         │
                         ▼
                Python execution_fn
```

最终执行：

```python
execution_fn(...)
```

实际上只是：

```text
Python dispatcher
   │
   ├─ call compiled region 0
   ├─ call Attention custom op
   └─ call compiled region 1
```

下面的代码是对生成结果的概念化简化：

```python
def execution_fn(x, positions, *, __vllm_submods__):
    x = __vllm_submods__[0](x)
    x = torch.ops.vllm.unified_attention_with_output(x, positions, ...)
    x = __vllm_submods__[1](x)
    return x
```

`__vllm_submods__` 中的元素是已经完成 compilation 的 callable，其内部计算仍由 Inductor 生成的 Triton/CUDA kernel 或 vLLM custom op 执行。当前 codegen 还会将普通 `torch.fx.GraphModule` 直接 inline 到生成代码中，并根据 value 的最后使用位置插入 `del`，尽早释放 Python reference。

生成的 source 随后通过 `exec()` 转换为 `execution_fn`，再由 `partial()` 绑定 compiled submodules 和必要常量。与在运行时逐节点解释 split graph 相比，这种 stitching function 避免了 FX interpreter、`nn.Module.__call__` 和 `__getattr__` 的额外调度开销。

因此，这里有两种不同层次的 codegen：

- Inductor codegen 决定 Tensor 如何在 GPU 上计算
- vLLM stitching codegen 则决定 compiled callable 和 custom op 以什么顺序执行

后者不会将 pieces 重新合并为 FX Graph，也不会重新生成 Tensor computation。

### Shape 管理

vLLM 在 shape 层面的增强，不是重新实现 dynamic shape 或 specialization，而是把 dynamic-shape policy 从 PyTorch 自动控制改为 vLLM 显式控制。vLLM scheduler 已经知道 `num_tokens`、batch size 等维度会如何变化，因此可以主动决定哪些维度保持动态、哪些高频值值得单独编译。

从当前 wrapper 中可以看到：

```python
torch.compile(
    self.forward,
    fullgraph=True,
    dynamic=False,
    backend=vllm_backend,
)
```

这里的 `dynamic=False` 很容易被误解为“vLLM 只做 static-shape compilation”，但实际含义是：不让 PyTorch 自动判断哪些维度需要动态化。第一次 compilation 之前，`support_torch_compile` 会根据模型声明的 `dynamic_arg_dims` 显式调用 `torch._dynamo.mark_dynamic()`；当前版本还可以根据 dynamic-shape configuration 调用 `torch._dynamo.decorators.mark_unbacked()`。([vLLM decorators.py][5])

整个策略可以概括为：

```text
dynamic=False
     │
     └── 不让 PyTorch 自动决定哪些 shape 动态化
                       +
        vLLM 显式 mark_dynamic / mark_unbacked
                       +
        vLLM 自己管理 compile ranges / specialization
```

因此，`dynamic=False` 关闭的是 PyTorch 的自动 dynamic-shape inference，而不是 vLLM 所有输入维度的动态性。哪些 argument 的哪些 dimension 需要动态处理，由 `support_torch_compile` 的 metadata 和 vLLM compilation configuration 明确指定。([vLLM wrapper.py][6])

在这套显式策略之上，vLLM 同时保留 general symbolic compilation 和特定 shape specialization：general kernel 覆盖 scheduler 允许的 token-count range，specialized kernel 则优化 decode 等场景中频繁出现的固定尺寸。

`compile_sizes` 用于指定需要额外编译的 token 数量：

```shell
vllm serve model \
  --compilation-config '{"compile_sizes": [1, 2, 4, 8]}'
```

例如，将 `compile_sizes` 设置为 `[1, 2, 4, 8]` 后，`num_tokens=1` 或 `8` 可以使用对应的 specialized kernel，而 `num_tokens=3` 或 `37` 仍由 general kernel 覆盖。这样不需要为每一种请求尺寸生成独立 kernel，同时保留对高频 shape 的优化机会。

当 shape 完全静态时，Inductor 可以比较更多 Triton configuration，并通过 autotuning 选择更合适的 kernel。首次 tuning 可能需要数秒到数分钟，但结果可以进入 compilation cache；vLLM 会在开始 serving 前完成这些 specialization，避免在线请求承担编译延迟。([vLLM torch.compile][1])

> vLLM 增强的不是底层 shape compilation 能力，而是 shape policy：显式标记动态维度、管理 compile ranges、选择高频 specialization，并决定何时完成这些 compilation。

### Custom Inductor Passes

vLLM 利用 Inductor 的 pass infrastructure，在通用优化之外加入 LLM-specific pattern matching、fusion 和 graph transformation。当前实现中的代表性优化包括：

- AllReduce 与 RMSNorm fusion
- Attention 与 Quantization fusion
- RoPE 与 KV Cache fusion
- QK Norm 与 RoPE fusion

**这些 passes 利用了 vLLM 对模型结构、量化方式和推理 operator 的额外认识**，但最终仍进入 Inductor lowering 和 codegen。

换言之，vLLM 扩展的是 Inductor 的优化 pipeline，而不是重新实现一套 compiler stack。具体 pass 会随 vLLM、PyTorch 版本和硬件 backend 演进，不应视为稳定 API。([vLLM torch.compile][1])

### Cache 与编译生命周期

vLLM 没有替代 Inductor 自带的 kernel cache，而是在它外面增加了一层 vLLM-aware artifact/cache management。Inductor cache 负责复用编译后的 kernel；vLLM cache 则从完整 serving configuration 出发，管理 Dynamo transformed code、FX computation graph、Inductor artifact 及相关 compilation metadata。([vLLM torch.compile][1])

当前实现确定 cache identity 时会综合考虑：

- execution environment 和 PyTorch configuration
- `VllmConfig` 及 compiler configuration
- 模型 `forward` 和 Dynamo tracing 涉及的相关 Python source files
- parallel/global rank 与 data-parallel rank 等进程身份

因此，模型实现、相关配置或 traced source 发生变化时会产生 cache miss；不同 rank 的 artifact 则存放在各自目录中。目录结构大致如下：

```text
~/.cache/vllm/torch_compile_cache/
└── <config-hash>/
    └── rank_0_0/
        ├── transformed_code.py
        ├── computation_graph.py
        └── inductor_cache/
```

Cache hit 时，vLLM 可以加载已有 Inductor artifact，直接绕过对应的 Inductor compilation。Cache miss 时则重新执行 tracing、graph processing 和 compilation，并将结果写入当前 serving configuration 对应的目录。

Cache 之外，vLLM 还改变了 compilation 的生命周期。普通 `torch.compile` 常见的使用方式是：

```python
compiled_model = torch.compile(model)
output = compiled_model(x)  # 首次调用或 guard miss 时可能触发 compilation
```

这种 execution-driven JIT 对普通应用是合理的，但不适合 online serving：如果某个请求触发编译，engine 会在该请求上阻塞并产生明显的 latency spike。

vLLM 的明确设计目标是：

> 所有需要的 compilation 都在真正开始 serving 之前完成，正常请求不触发新的 compilation。([vLLM torch.compile][1])

因此，vLLM 会在模型初始化和 warmup 阶段完成 general shape compilation、`compile_sizes` 对应的 specialization，以及所需的 CUDA Graph capture，随后才开始处理请求。Cache 解决重复启动时的 artifact 复用问题；提前 compilation 则解决单次 serving 生命周期中编译进入请求路径的问题。

### CUDA Graph 协同

Piecewise CUDA Graph 不是独立于 compilation 的另一项优化，而是直接建立在 Piecewise Compilation 的输出之上。Piecewise Compilation 先决定 graph boundary，并将 Attention 与相邻的稳定计算拆开；Inductor 再编译这些 safe regions；初始化阶段则对 compiled callable 进行 CUDA Graph capture。([vLLM torch.compile][1])

Attention 往往需要处理 KV Cache、sequence metadata 和 backend-specific runtime state，执行行为更动态；两个 Attention 之间的 Linear、Norm、FFN 和 residual 等计算通常更稳定。因此，Piecewise 模式可以让这些 Inductor regions 使用 CUDA Graph replay，同时让 Attention 保持 normal/custom execution：

```text
Inductor Region
      │
      │ CUDA Graph
      ▼
    replay

Attention
      │
      │ normal/custom execution
      ▼

Inductor Region
      │
      │ CUDA Graph
      ▼
    replay
```

这里的关键是，vLLM backend 不只生成 compiled regions，还保留 region boundary、capture artifact 和 runtime dispatch 所需的 metadata。运行时再把三类信息连接起来：

```text
compiler decision
        +
runtime batch information
        +
CUDA Graph availability
        │
        ▼
CudagraphDispatcher
        │
        ├─ FULL
        ├─ PIECEWISE
        └─ eager fallback
```

三类信息分别回答不同问题：

- compiler decision 决定哪些 operations 属于 CUDA-Graph-safe region，哪些是 unsafe boundary；
- runtime batch information 描述当前 batch 的组成、token 数量和 execution mode；
- CUDA Graph availability 表示对应 batch descriptor、capture size 和 Attention backend 是否存在可 replay 的 graph。

在 `PIECEWISE` 模式下，dispatcher replay safe regions，并在边界处执行 Attention；在 `FULL` 模式下，如果当前 batch 和 Attention backend 均支持完整 capture，则 replay 包含 Attention 的模型级 graph；`FULL_AND_PIECEWISE` 则同时准备两条路径，在运行时根据 batch characteristics 选择。没有匹配的 graph artifact 时，系统还需要回退到普通执行。([vLLM CUDA Graphs][4])

因此，vLLM 的增强不只是“先用 Inductor，再单独打开 CUDA Graph”，而是把 compilation boundary、runtime batch state 与 CUDA Graph capture/replay 纳入同一套 serving policy。Stock `backend="inductor"` 可以生成 kernel，但不会提供这套跨 compiler 和 runtime 的 graph dispatch 机制。

### Summary

`vllm_backend` 可以理解为 LLM-serving-aware 的 `torch.compile` control plane：TorchInductor 决定一个 graph 如何优化和生成代码，vLLM 则进一步管理 graph boundary 与 stitching、shape 策略、custom passes、cache、编译时机及 CUDA Graph runtime。

| `torch.compile` 已有能力 | vLLM 增强 |
| --- | --- |
| Dynamo graph capture | 用 custom op 隔离复杂 Attention 内部实现 |
| FX Graph | 根据 serving operator 特性主动 partition，并生成 stitching function |
| Dynamic shape | 管理 symbolic shape、guard 和高频 shape specialization |
| Inductor optimization | 插入 LLM-specific compiler passes |
| JIT 与 Inductor cache | 增加 configuration-aware cache，并将编译前移到初始化阶段 |
| GPU execution | 与 CUDA Graph capture/replay 及 runtime dispatch 协同 |

> vLLM 没有用 `vllm_backend` 替换 Inductor，而是在 Inductor 周围增加一层 serving-aware 编译策略。

## Piecewise CUDA Graph

Piecewise CUDA Graph 不要求整个 Transformer `forward` 都满足 CUDA Graph capture 条件，而是以 CUDA-Graph-unsafe operation 为边界，将其余稳定的计算区域分别 capture。

vLLM 中最典型的边界是 Attention：Attention 保持 eager execution，相邻 Attention 之间的 RMSNorm、GEMM、FFN 和 residual 等计算则通过 CUDA Graph replay 执行。

```text
CUDA Graph -> Attention (eager) -> CUDA Graph -> Attention (eager) -> CUDA Graph
```

具体的分区方式、FX-level 与 Inductor-level 两种实现，以及 `PIECEWISE` 和 `FULL` 模式的区别，可参考 [Piecewise CUDA Graph](<Piecewise CUDA Graph.md>)。

[1]: https://docs.vllm.ai/en/latest/design/torch_compile/ "torch.compile integration - vLLM"
[2]: https://docs.vllm.ai/en/latest/api/vllm/config/compilation/ "CompilationConfig - vLLM"
[3]: https://github.com/vllm-project/vllm/blob/main/vllm/compilation/codegen.py "vLLM stitching codegen source"
[4]: https://docs.vllm.ai/en/stable/design/cuda_graphs/ "CUDA Graphs - vLLM"
[5]: https://github.com/vllm-project/vllm/blob/main/vllm/compilation/decorators.py "vLLM torch.compile decorators source"
[6]: https://github.com/vllm-project/vllm/blob/main/vllm/compilation/wrapper.py "vLLM torch.compile wrapper source"
