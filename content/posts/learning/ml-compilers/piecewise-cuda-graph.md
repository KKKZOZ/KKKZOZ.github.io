---
title: "Piecewise CUDA Graph"
tags:
  - ML Compilers
date: 2026-08-09
showtoc: true
weight: 10
---

## 核心结论

Piecewise CUDA Graph 的核心思想是：不要求整个 Transformer `forward` 都满足 CUDA Graph capture 条件，而是将 CUDA Graph 不兼容的算子作为边界，只 capture 其余 CUDA-Graph-safe 区域。

在 vLLM 中，最典型的边界是 Attention。因此，`PIECEWISE` 模式并不是“把一个 CUDA Graph 切开执行”，而是将模型划分为多个独立的 CUDA Graph，并在它们之间以 eager 模式执行 CUDA-Graph-unsafe 操作：

```text
CUDA Graph -> Attention (eager) -> CUDA Graph -> Attention (eager) -> CUDA Graph
```

CUDA Graph 会提前 capture 一组 GPU operations，后续通过 graph replay 一次性提交，从而降低 CPU 逐个启动 kernel 的开销。Transformer 中的 RMSNorm、Linear/GEMM、activation、FFN 和 residual 等计算，在 capture size 确定时通常具有稳定的执行结构；Attention 则需要处理 KV Cache、动态 shape 和运行时 metadata，对 CUDA Graph 的兼容要求更高。

Piecewise CUDA Graph 要解决的问题因此不是“如何加速 Attention”，而是：

> 当 Attention 无法安全进入 CUDA Graph 时，仍让模型其余计算获得 graph replay 的收益。

vLLM 当前将 `PIECEWISE` 定义为：Attention 或其他 CUDA Graph 不兼容操作保持 eager，其余部分进入 CUDA Graph。常用的默认模式是 `FULL_AND_PIECEWISE`，即 uniform decode 尽量使用 Full CUDA Graph，而 prefill 或 mixed batch 使用 Piecewise CUDA Graph。实际选择仍取决于 Attention backend 的兼容能力。([vLLM][1])

## 分区机制

传统 vLLM Piecewise Compilation 使用 `splitting_ops` 指定分区边界，默认边界主要是 Attention custom op。Attention 自身成为独立 submodule，相邻 Attention 之间的计算则组成 CUDA Graph candidate。([vLLM][3])

假设简化后的 Transformer 包含三个 Attention：

```text
Embedding
  -> Attn0
  -> MLP0 / Norm / Projection
  -> Attn1
  -> MLP1 / Norm / Projection
  -> Attn2
  -> MLP2 / FinalNorm
```

以 `vllm::unified_attention_with_output` 为 `splitting_ops` 时，逻辑分区结果为：

- `Attn0`、`Attn1` 和 `Attn2` 分别作为 eager boundary；
- `Embedding`、两个 Attention 之间的计算以及末尾计算分别成为 CUDA-Graph-safe region；
- 对于包含 `N` 个 Attention 的典型串行 Transformer，概念上会形成 `N` 个 eager boundaries 和 `N + 1` 个 safe regions。新的 Inductor partition 也遵循这一数量关系。([vLLM][5])

### `split_graph()` 的职责

传统实现中的 `split_graph()` 遍历 FX nodes，遇到 `splitting_ops` 时建立新的 subgraph boundary。其核心逻辑可以简化为：

```python
for node in graph.graph.nodes:
    if should_split(node, splitting_ops):
        # splitting op 单独进入一个 partition
        ...
    else:
        # 普通 op 留在当前 partition
        ...
```

随后，`torch.fx.passes.split_module.split_module(...)` 将完整 FX Graph 转换为多个 `GraphModule`。实现还通过 `is_splitting_graph` 区分 boundary operation 和普通 piece；`submod_names_to_compile` 会过滤 splitting graph，因此二者进入不同的后续编译路径。([GitHub][4])

### 为什么以 Attention 为边界

分区依据是 CUDA Graph compatibility，而不是 Transformer 的 layer 或 module hierarchy。

如果按照 layer 切分，一个 graph 会同时包含 Attention 和 FFN。只要 Attention 不兼容 CUDA Graph，同一 layer 中原本稳定的 FFN、RMSNorm、GEMM、residual 和 QKV projection 也无法独立 capture。按照 unsafe op 切分，则可以将这些计算保留在相邻的 safe region 中。

Attention 适合作为边界还有两个原因：

- 它需要处理 KV Cache block mapping、sequence length、slot mapping、PagedAttention、kernel selection 和 attention metadata 等动态状态；
- 它对外仍可暴露规则的 Tensor interface。vLLM 将 Attention 包装为 `torch.ops.vllm.unified_attention_with_output` custom op，且其 output 与 query 具有相同的外部 shape，因此 Dynamo 不必追踪内部实现。([vLLM][3])

具体哪些算子位于 Attention custom op 内外，会随模型、fusion 策略和 vLLM 版本变化。这里的分区描述表达的是通用原则，而不是某个模型的精确 FX Graph。

## 性能收益与成本

Piecewise CUDA Graph 不会消除 eager Attention 的 launch，但能把 Attention 之间的一串 token-wise kernels 压缩为一次 graph replay。原本需要 CPU 逐个 dispatch 的 RMSNorm、GEMM、activation、residual 和 projection 等操作，可以作为整体重复提交。CUDA Graph 的主要收益正是减少逐 kernel launch 的 CPU 开销。([NVIDIA Docs][6])

这一模式仍然不是完全动态的。vLLM 会针对一组 `cudagraph_capture_sizes` 分别 capture，例如：

```shell
vllm serve meta-llama/Llama-3.2-1B \
  --compilation-config '{"cudagraph_capture_sizes": [1, 2, 4, 8]}'
```

运行时，`CUDAGraphWrapper` 根据 runtime mode 和 `BatchDescriptor` 选择 capture、replay 或直接调用原 callable。replay 还要求相关输入地址保持一致。([vLLM][2])

相应的代价是 graph artifacts 数量增加。模型越深、safe region 越多、capture size 越多，需要维护的 CUDA Graph 就越多，其规模通常与以下乘积相关：

```text
safe region 数量 x capture size 数量
```

vLLM 社区也讨论过传统 Piecewise 模式可能产生约 `#layers × #capture_sizes` 量级的 graph artifacts。因此，当整个模型兼容 capture 时，Full CUDA Graph 通常能进一步减少 graph 数量和 replay 次数。([GitHub][7])

## 两种分区实现

当前 vLLM 同时存在 FX-level split 和 Inductor-level partition。两者的关键区别是分区发生在 compiler optimization 之前还是之后。

| 实现 | 分区时机 | 边界依据 | 主要影响 |
| --- | --- | --- | --- |
| FX-level split | Dynamo 生成 FX Graph 后、Inductor 优化前 | `splitting_ops` | 实现直接，但可能阻断跨分区优化 |
| Inductor-level partition | Inductor passes 和 fusion 后 | `torch._C.Tag.cudagraph_unsafe` | 保留 whole-graph optimization，再生成 safe partitions |

### FX-level split

传统路径先根据 `splitting_ops` 调用 `split_graph()`，再分别处理生成的 pieces：

```python
if self.compilation_config.use_inductor_graph_partition:
    fx_split_ops = []
else:
    fx_split_ops = self.compilation_config.splitting_ops or []

self.split_gm, self.piecewise_graphs = split_graph(
    graph,
    fx_split_ops,
)
```

这条路径的问题是分区发生得较早。Attention 与 Quantization fusion、Sequence Parallelism 等 pass 可能需要观察完整 graph，过早建立 boundary 会限制这类跨区域优化。([vLLM][1])

### Inductor-level partition

较新的实现通过以下配置启用：

```python
use_inductor_graph_partition = True
```

此时 `fx_split_ops` 为空，vLLM 不再预先按 Attention 切分 FX Graph，而是在 Inductor codegen 阶段识别带有 `torch._C.Tag.cudagraph_unsafe` 标记的 operation。若存在 `N` 个 unsafe operations，则生成 `N + 1` 个 CUDA-Graph-safe partitions，unsafe operations 留在 partition function 之外。([vLLM][5])

这种设计先在完整 graph 上执行 optimization 和 fusion，再确定 CUDA Graph boundaries，解决了 Piecewise boundary 与 compiler fusion boundary 之间的冲突。vLLM 文档截至 2026 年 6 月仍将其描述为基于较新 PyTorch/Inductor 能力的实现路径。([vLLM][1])

## 与其他模式的关系

Piecewise 与 Full CUDA Graph 的本质区别是 Attention 是否进入 capture 范围。

| 模式 | Attention | 其他计算 | Graph 数量 | 适用条件 |
| --- | --- | --- | ---: | --- |
| `NONE` | eager | eager | 0 | 兼容性最高，不使用 CUDA Graph |
| `PIECEWISE` | 通常 eager | CUDA Graph | 多个 | Attention 无法完整 capture |
| `FULL` | CUDA Graph | CUDA Graph | 模型级别 | Attention backend 支持对应 batch |
| `FULL_AND_PIECEWISE` | 根据 batch 决定 | CUDA Graph | 同时维护两种路径 | 在性能和兼容性之间动态选择 |

不同 Attention backend 的 Full CUDA Graph 支持范围并不相同：

| `AttentionCGSupport` | 支持范围 |
| --- | --- |
| `ALWAYS` | mixed、prefill 和 decode |
| `UNIFORM_BATCH` | uniform batch |
| `UNIFORM_SINGLE_TOKEN_DECODE` | uniform single-token decode batch |
| `NEVER` | 不支持 Full CUDA Graph |

因此，`FULL_AND_PIECEWISE` 可以在 backend 能力允许时让 uniform decode 使用 Full CUDA Graph，并在 prefill 或 mixed batch 中回退到 Piecewise CUDA Graph。([vLLM][1])

> Piecewise CUDA Graph 的设计原则可以概括为：以 CUDA-Graph-unsafe operation 为边界，在兼容性受限时保留尽可能大的 CUDA-Graph-safe regions。传统实现采用 `Dynamo -> FX split -> Inductor`，新实现则采用 `Dynamo -> Inductor optimization/fusion -> CUDA Graph partition`。

[1]: https://docs.vllm.ai/en/stable/design/cuda_graphs/ "CUDA Graphs - vLLM"
[2]: https://docs.vllm.ai/en/stable/api/vllm/compilation/cuda_graph/ "cuda_graph - vLLM"
[3]: https://docs.vllm.ai/en/latest/design/torch_compile/ "torch.compile integration - vLLM"
[4]: https://github.com/vllm-project/vllm/blob/main/vllm/compilation/backends.py "vllm/vllm/compilation/backends.py at main"
[5]: https://docs.vllm.ai/en/latest/api/vllm/config/compilation/ "compilation - vLLM"
[6]: https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cuda-graphs.html "4.2. CUDA Graphs - CUDA Programming Guide"
[7]: https://github.com/vllm-project/vllm/issues/20098 "[RFC]: Lazy CUDA Graph capture #20098"
