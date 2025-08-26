---
title: "paper-reviews"
tags:
  - TOBETAGGED
date: 2025-08-26
showtoc: true
draft: true
---



## Reviews

- [STI Turbocharge NLP Inference at the Edge via Elastic Pipelining](posts/papers/llm/sti-turbocharge-nlp-inference-at-the-edge-via-elastic-pipelining.md)
  - 把一个 NLP Model 划分为 N 层，每层 M 块，共计 N x M 个 shard，每个 shard 给出 K 个不同的量化精度，通过数学建模来构建出最优的组合计划
  - 选择量化级别时，根据分片重要性排名，越重要的分片分配到的位宽越高
  - 不同分片的量化容忍度不同，所以可以采用差异化量化：高容忍度的分片采用更激进的量化，低容忍度的分片采用更保守的量化
- [EdgeMoE Empowering Sparse Large Language Models on Mobile Devices](posts/papers/llm/edgemoe-empowering-sparse-large-language-models-on-mobile-devices.md)
  - 不同专家对量化的容忍度不同，容忍度高的专家可以使用更高级别的量化
  - 对于同一个 Token，跨所有层被激活的专家序列呈现幂律分布: 可以通过 predict-and-prefetch 来优化流水线
- [LLM as a System Service on Mobile Devices](posts/papers/llm/llm-as-a-system-service-on-mobile-devices.md)
  - 持久化 KV Cache 来加速对话
  - 不同 KV chunk 的信息密度不一样，因此对量化的容忍度不同，可以根据信息密度分配不同的压缩比例
  - KV Chunk 除了能够从硬盘加载，还能被重计算，因此在加载时可以 I/O 和计算资源共同利用来降低延迟
- [H2O Heavy-Hitter Oracle for Efficient Generative Inference of Large Language Models](posts/papers/llm/h2o-heavy-hitter-oracle-for-efficient-generative-inference-of-large-language-models.md)
  - 不是所有的历史信息都同等重要，可以保留那些最关键的信息，从而在有限的显存中实现高效推理
  - 注意力累积得分越高的词元越重要
  - 最近生成的几个词元对维护局部语义连贯性也很重要
- [HeteroLLM Accelerating Large Language Model Inference on Mobile SoCs with Heterogeneous AI Accelerators](posts/papers/llm/heterollm-accelerating-large-language-model-inference-on-mobile-socs-with-heterogeneous-ai-accelerators.md)
  - NPU + GPU 协同计算，NPU 作为主力
  - 统一内存架构，由推理系统管理内存，NPU/GPU 可以直接访问同一片内存，不需要内存拷贝
  - 充分考虑 SoC 中各种硬件的特性，以 NPU 的特性优先，不适合的 NPU 计算的形状/算子类型再分配给 GPU 计算
- [SmallThinker A Family of Efficient Large Language Models Natively Trained for Local Deployment](posts/papers/llm/smallthinker-a-family-of-efficient-large-language-models-natively-trained-for-local-deployment.md)
  - 通过两级稀疏结构（MoE 稀疏 + ReGLU 神经元稀疏）解决了计算能力有限的问题
  - 通过预注意力路由器形成自然的 predict-and-prefetch 流水线
  - ReGLU 部分使用了选择性计算并开发了高度优化的融合稀疏 ReGLU FNN Kernels
- [Ring Attention with Blockwise Transformers for Near-Infinite Context](posts/papers/llm/ring-attention-with-blockwise-transformers-for-near-infinite-context.md)
  - 自注意力机制的内存消耗随着输入长度序列的增加而呈现二次方增长
  - 在分布式环境下，将输入序列分块，每张显卡只维护自己的 Q, 在每一轮中向邻居发送和接收 K,V, 以此降低显存占用 (底层使用了 FlashAttention)
- [Striped Attention Faster Ring Attention for Causal Transformers](posts/papers/llm/striped-attention-faster-ring-attention-for-causal-transformers.md)
  - Ring Attention 的直接改进
  - 考虑到 Attention 计算中的因果掩码，Ring Attention 中的设备存在空转的情况 (比如持有 Q1 的显卡接收了 K3，V3)，工作提出了纸带式划分，平衡了不同显卡之间的有效工作量
- [TPI-LLM Serving 70B-scale LLMs Efficiently on Low-resource Mobile Devices](posts/papers/llm/tpi-llm-serving-70b-scale-llms-efficiently-on-low-resource-mobile-devices.md)
  - 在低资源设备协同的环境下，使用 Tensor Parallelism
  - 使用滑动窗口内存调度器来异步加载和卸载权重 (prefetch)
- [LLM.int8() 8-bit Matrix Multiplication for Transformers at Scale](papers/llm/LLM.int8()%208-bit%20Matrix%20Multiplication%20for%20Transformers%20at%20Scale.md)
  - 识别出离群列，进行混合精度分解计算
  - 离群路径采用 FP16 格式矩阵乘法，常规路径采用 INT8 格式矩阵乘法，最后把两者结果以 FP16 精度相加（类似于矩阵乘法的外积展开形式）
- [Fast On-device LLM Inference with NPUs](posts/papers/llm/fast-on-device-llm-inference-with-npus.md)
  - NPU + CPU/GPU: 量化后 INT8 类型的计算在 NPU 上，outliers 在 CPU/GPU 上以浮点精度进行计算，并非所有离群点都同等重要，大部分离群点可以被安全地忽略或者剪枝，以此降低同步开销 (offline profile, online predict)
  - 把 sequence 分割为多个固定大小的块来适配 NPU 的计算特性，为了降低 memory footprint，把算子分为动态和静态，静态算子在整个计算图中共享
- [Deja Vu Contextual Sparsity for Efficient LLMs at Inference Time](posts/papers/llm/deja-vu-contextual-sparsity-for-efficient-llms-at-inference-time.md)
  - MLP blocks 和 attention heads 都存在上下文稀疏性: 不同的输入会激活模型中不同的、小范围的计算路径，这个被激活的参数子集会根据当前输入（即上下文）动态变化
  - 在线并行预测下一层的稀疏模式，然后利用稀疏模式进行计算，提升模型运算速度和效率 (offline profile, online predict)
  - 注意力模块只计算一部分注意力头，MLP 模块只计算一部分神经元索引(Rows of W_up and Cols of W_down)
- [LLM in a flash Efficient Large Language Model Inference with Limited Memory](posts/papers/llm/llm-in-a-flash-efficient-large-language-model-inference-with-limited-memory.md)
  - 直接利用了上下文稀疏性，
- [PowerInfer Fast Large Language Model Serving with a Consumer-grade GPU](posts/papers/llm/powerinfer-fast-large-language-model-serving-with-a-consumer-grade-gpu.md)
  - 小部分热神经元在不同输入中持续激活，而大部分冷神经元则根据特定输入而变化; 热神经元预加载到 GPU 中实现快速访问，冷神经元则在 CPU 上计算
  - offline profile: 基于冷热神经元的统计洞察，决定哪些权重该放在 GPU，哪些放在 CPU; online predict: 基于上下文稀疏性，在运行时动态预测并只计算被激活的神经元
  - 激活的主体是热神经元 (70%)，所以放在 GPU 上计算

- [PowerInfer-2 Fast Large Language Model Inference on a Smartphone](posts/papers/llm/powerinfer-2-fast-large-language-model-inference-on-a-smartphone.md)
-

## Patterns

- Ultimate Goal
  - 加快端侧大模型推理
    - Prefill: Computation-bound
      - Use suitable hardware
    - Decode: Memory-bound
      - Pipeline

Pipeline

- Reduce bubbles
- hide I/O from serial computation

- **Sparsity is all you need**
- **offline profile and online predict is all you need**
- **Predict-and-prefetch is all you need**

## Drafts

DEJAVU and PowerInfer:

PowerInfer的“冷热神经元”洞察，是建立在DejaVu“上下文稀疏性”基础之上，并对其进行统计分析后得出的一个更深层次的、关于“局部性”的结论。

下面是详细的分析和总结：

1. 共同的基础：动态的激活稀疏性
两篇论文都认可一个最基本的前提：对于任何单个输入，在推理时只有一小部分神经元会被激活。这部分被激活的神经元是根据当前输入动态变化的。

DejaVu 将这个现象命名为 上下文稀疏性 (Contextual Sparsity)。它的核心关注点在于“动态变化”：输入A激活集合A'，输入B激活集合B'，这两个集合都很小，而且内容不同。DejaVu的目标是快速预测出这个动态集合，从而在GPU内部用稀疏计算代替稠密计算来加速。

2. PowerInfer的延伸：从动态中发现静态规律
PowerInfer的研究在DejaVu的基础上更进了一步。它不仅观察单次输入的动态稀疏性，还通过离线分析（Offline Profiling）大量不同输入的激活情况，从宏观上、统计学上对这种动态变化进行了规律总结。

PowerInfer 发现，虽然每次激活的神经元集合都不同，但这些集合的并集里，各个神经元的激活频率遵循幂律分布 (Power-law Distribution)。

热神经元 (Hot Neurons)：一小部分神经元，尽管每次激活的集合不同，但它们在几乎所有不同的集合中都频繁出现。这部分神经元构成了计算的“主干”或“高速公路”，具有全局的重要性。

冷神经元 (Cold Neurons)：大部分神经元，它们只在非常特定的、与输入高度相关的上下文中才会被激活，激活频率很低。

可以将两者的关系理解为：

- DejaVu 关注的是 “每一次” 推理的动态性。它回答了问题：“对于当前这个输入，我应该计算哪些神经元？”
- PowerInfer 关注的是 “所有次” 推理的统计共性。它回答了问题：“在所有可能的输入中，哪些神经元是普遍更重要的？”
