---
title: "Fast On-device LLM Inference with NPUs"
tags:
  - ASPLOS-25
  - LLM-Inference
  - Serving-on-Edge
date: 2025-08-04
showtoc: true
---

> Intensive Reading

## Author Info

- [Daliang Xu （徐大亮） - Daliang Xu’s Website](https://daliangxu.github.io/): An incoming Assistant Professor at BUPT.
- [‪Hao Zhang‬ - ‪Google Scholar‬](https://scholar.google.com/citations?user=qwtp9CkAAAAJ&hl=en): Author of Edgellm.
- [Mengwei Xu](https://xumengwei.github.io/): An associate professor in BUPT.
- [Professor Xuanzhe Liu @ Peking University](http://www.liuxuanzhe.com/): an Endowed Boya Distinguished Professor at the School of Computer Science in Peking University.

## Background

![pasted-image-20250804165510](/images/pasted-image-20250804165510.png)

The prefill stage is often the bottleneck in typical mobile applications.

> 论文设定的背景限制，但大部分情况下应该还是 decoding 阶段是瓶颈？

Modern mobile SoCs ubiquitously include mobile neural processing units (NPUs) that are well-suited for integer operations, such as INT8-based matrix multiplication.

![pasted-image-20250804165701](/images/pasted-image-20250804165701.png)

![pasted-image-20250804165809](/images/pasted-image-20250804165809.png)

## Challenges

Directly employing mobile NPUs for LLM inference does not offer performance benefits due to the following challenges:

- **Costly preparation for variable-length prompts**: NPU 通常只支持静态形状的计算图，而 LLM 的输入提示长度是动态变化的。为每种长度的提示重新构建和优化 NPU 计算图非常耗时。
- **Mismatch between LLM quantization algorithms and mobile NPU design**: 先进的 LLM 量化算法（如 K-Quant, AWQ）常使用“按组量化”。但移动端的 NPU 无法直接高效执行这种操作。
- **Floating point (FP) operations cannot be eliminated**: 当前的量化 LLM 仍然依赖于一些浮点（FP）运算（如 LayerNorm 和 Attention）来保证准确性。而 NPU 处理浮点运算的性能非常差，这会严重拖慢推理速度。

![pasted-image-20250804200315](/images/pasted-image-20250804200315.png)

## Insights

The key idea is to maximize prefill execution on mobile NPUs to accelerate integer computation while keeping essential float operations on the CPU/GPU to maintain accuracy.

`llm.npu` proposes corresponding novel techniques to solve the challenges:

- **Chunk-sharing graphs**: 将任意长度的可变提示分割成多个固定大小的“块”。同时将计算图中的算子分为了静态算子和动态算子，静态算子可以在所有块之间共享。
- **Shadow outlier execution**: 大部分计算使用 NPU 友好的 per-tensor quantization 在 NPU 上以 INT8 格式高速执行。对于那些在量化后会产生较大误差的 outliers，系统会将其提取出来在 CPU/GPU 上以浮点精度并行计算。
- **Out-of-order subgraph execution**: 系统将整个计算流分解为许多独立的子图。调度器不再严格按照原始顺序执行这些子图，而是在满足数据依赖关系的前提下，进行乱序调度。

## Approaches

![pasted-image-20250804170743](/images/pasted-image-20250804170743.png)

整体的 workflow 可以分为两个阶段：

- **Preparation stage**
  - 使用一个增强的量化技术将 LLM 量化为 W8A8 格式，并将 outliers 单独抽离出来。
  - 生成 fixed-length chunk-sharing graphs.
- **Execution Stage**
  - 将 prompt 拆分为固定大小的 chunks 并处理。
  - 大部分计算在 NPU 上执行，将 outliers 调度到 CPU/GPU 上以 FP16 精度并行执行。
  - 采用乱序子图执行的方式提高执行效率。

### Chunk-sharing graph execution

这部分方法分为两部分：

- **Chunk-wise prefill**: 由于 prompt 长度是可变的，而 NPU 需要的计算图是静态的，单纯地以最大长度做 padding 太浪费了，不如把计算图设置为处理单个 chunk 的大小，然后把 prompt 分为多个 chunk，依次输入到计算图中执行计算。（Figure 7(a) -> Figure 7(b)）
- 单纯这么优化的话，由于每个 chunk 的 attention operator 形状都不一样，需要在内存中单独维护。`llm.npu` 采用了 **chunk-sharing graph**，将算子分为动态和静态，静态算子可以在整个计算图中共享以降低内存占用。（Figure 7(b) -> Figure 7(c)）

> Experiments show that 120 out of 144 subgraphs can be shared in Qwen1.5-1.8B models, reducing memory consumption by up to 75% (7.2GB) for a prompt length as 1024 and a chunk length as 256.

![pasted-image-20250804173851](/images/pasted-image-20250804173851.png)

### Shadow outlier execution

> [!important]
>
> - `llm.npu` 采用的是 Weight-Activation Quantization
> - outliers 也指的是 activation outliers

`llm.npu` 采用了对 NPU 友好的 per-tensor activation[^1], 但是为了保证 outliers 的精度，把其拆分出来单独在 CPU 中进行浮点矩阵乘法，最后再将结果与 NPU 上的执行结果进行合并。

> 基础思想和 `llm.int8()`[^2] 类似

细节上，`llm.npu` 也基于两个观察进行了优化：

1. **outliers 的出现不是均匀分布，而是高度集中的 (Figure 11)**

- `llm.npu` 通过预加载热点权重（提前加载到内存），动态加载冷权重（运行时从磁盘加载）来降低内存占用，整个过程可以和 NPU 上的矩阵乘法并行执行。

2. **并非所有离群点都同等重要，大部分离群点可以被安全地忽略或者剪枝 (Figure 12)**

- `llm.npu` 通过使用大型语料库在离线阶段运行模型，计算出模型每一层 outliers 的重要性得分，剪除那些重要性得分最低的层的 outliers, **禁用这些 outliers 的影子执行机制**，从而消除了这部分机制带来的同步开销。

> 第二个观察和 [AWQ](posts/papers/llm/awq-activation-aware-weight-quantization-for-llm-compression-and-acceleration.md) 工作的观察类似。

在推理过程中，系统会根据离线分析的结果来执行操作：

- 如果当前层被标记为“不重要层”，则**完全跳过**“影子执行”机制，所有计算都在NPU上高效完成。
- 如果当前层是“重要层”，则**启用**“影子执行”，分离出离群点在 CPU/GPU 上计算，以保证精度。

> [!todo]
> 观察二我理解起来有点迷糊，可能是对 Weight-Activation Quantization 不是很了解。

![pasted-image-20250804174400](/images/pasted-image-20250804174400.png)

![pasted-image-20250804192059](/images/pasted-image-20250804192059.png)

### Out-of-order subgraph execution

- LayerNorm, Attention, as well as the shadow outlier computation are placed on the CPU/GPU.
- while the other linear layers are processed on the NPU.

朴素的重叠执行会带来许多气泡 (Figure 13)：

- 比如 NPU 需要**等待** CPU 把 `C1-Graph2` 计算完成之后，才能开始计算 `C1-Graph3`.

核心洞察是**计算任务的子图不必严格按照它们在原始提示中的顺序来执行，只要满足数据依赖关系，就可以乱序执行**。

- 在 Figure 13 中，NPU 在计算完 `C1-Graph1` 后可以直接开始计算 `C2-Graph1`.

![pasted-image-20250804201433](/images/pasted-image-20250804201433.png)

为了保证计算结果的正确性，乱序执行必须遵守两种依赖关系 ：

- **Cross-chunk dependency**：某些操作（如 Attention）需要依赖**之前所有块**的计算结果。例如，第 `i` 个块的某个子图可能依赖于第 `0` 到 `i-1` 个块的相应子图的输出。
- **Intra-chunk dependency**：在一个数据块内部，某些操作（如 LayerNorm）只依赖于**同一个块内**前一个子图的计算结果。

找到最优的乱序执行顺序是一个 NP 难问题，无法实时计算 。因此，`llm.npu` 采用了一种高效的**在线启发式算法**来做决策, 目的**不是最大化并行处理能力，而是优先减少NPU的空闲时间，因为 NPU 是整个计算过程中的关键路径和性能瓶颈**。

> [!important]
> 两种依赖关系可以构建出一个 DAG，这里需要区分"找出一个合法的执行顺序"和"找到总执行时间最短的合法执行顺序"
>
> - 前者只需要简单的拓扑排序
> - 后者是一个 NP 难问题，论文使用了一个在线启发式算法

## Evaluation

### 消融实验

![pasted-image-20250804203813](/images/pasted-image-20250804203813.png)

- 朴素使用 NPU 反而比直接使用 CPU 更慢，因为手机端的 LLM 都涉及到量化，而 NPU 计算 FP16 非常慢，而且 NPU 需要动态编译计算图
- 加入 Chunk-sharing graph execution 后，直接使用静态的共享计算图，性能有提升
- 加入 Shadow outlier execution 后性能得到进一步提升，主要来自于第二个观察，即通过离线 profiling 统计之后，只对部分 outlier offload 到 CPU 上进行计算。
  - 个人感觉提升这么大的原因，应该是朴素的 NPU 计算跑 FP16, Shadow outlier execution 跑 INT8?
- 最后加入 Out-of-order subgraph execution, 最大程度地降低了执行时的气泡。

### 专项分析

- Trade-offs between accuracy and performance

![pasted-image-20250804203957](/images/pasted-image-20250804203957.png)

剪枝率可以动态调整，为了不让准确率太低，50% 比较合适。

- CPU-NPU/GPU-NPU Analysis

![pasted-image-20250804204245](/images/pasted-image-20250804204245.png)

- Prefill 阶段，计算瓶颈在 NPU 上，所以无论是使用 GPU 还是 CPU，都不会影响总时长。
- GPU-NPU 协同**可以**有效降低总的端到端延迟，主要是加速了 Decode 阶段。

## Thoughts

### When Reading

和 [PowerInfer](posts/papers/llm/powerinfer-fast-large-language-model-serving-with-a-consumer-grade-gpu.md) 以及 [PowerInfer-2](posts/papers/llm/powerinfer-2-fast-large-language-model-inference-on-a-smartphone.md) 关注的点不同，这项工作主要旨在提高设备端 LLM 的预填充速度，也就是说 `llm.npu` 的工作和这些工作是正交的。

移动端的 NPU 有这么多限制，是因为设计的时候就没考虑到大模型相关的计算？后续各厂商会不会补齐这一方面的短板？

由于主要目标是研究 prefill 阶段，所以不能像 decode 阶段那样很好地利用稀疏性来优化计算。

Shadow outlier execution 完全可以看做是 [LLM.int8()](papers/llm/LLM.int8()%208-bit%20Matrix%20Multiplication%20for%20Transformers%20at%20Scale.md) 在异构芯片上的合理外推。

在实现时，可以参考 vLLM 的早期开发流程（具体在哪里看过搞忘了，知乎？），先实现一套自动化的性能测试和分析工具，每次 commit 之后都会自动执行，对系统性能进行分析，记录本次 commit 在性能上优化了多少，这样就能把许多较大的优化划分为多个子任务（无论是从粒度上还是直接分解），明确当前的工作进展是否符合预期。

## Related Works

- [LLM.int8() 8-bit Matrix Multiplication for Transformers at Scale](papers/llm/LLM.int8()%208-bit%20Matrix%20Multiplication%20for%20Transformers%20at%20Scale.md)

- [^1]: [Per-tensor && Per-group Quantization](papers/llm/LLM%20Preliminaries.md#Per-tensor%20&&%20Per-group%20Quantization)
- [^2]: [A Gentle Introduction to 8-bit Matrix Multiplication for transformers at scale using transformers, accelerate and bitsandbytes](https://huggingface.co/blog/hf-bitsandbytes-integration#is-it-faster-than-native-models)
