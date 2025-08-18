---
title: "KV-Runahead Scalable Causal LLM Inference by Parallel Key-Value Cache Generation"
tags:
  - ICML-224
  - Tensor-Parallelism
date: 2025-08-17
showtoc: true
---

> Skimming

## Author Info

## Background

## Challenges

## Insights

## Approaches

> 看了好几遍都没看懂，我大概的理解是
>
> 1. 利用了 casual mask 的特性以链式的方式在不同设备之间传递 KV，避免了传统 TSP 的大量重复计算和冗余传输
> 2. 为了平衡整个流水线采用了 context-level load balancing，靠前的设备多算一些 KV, 靠后的设备少算一些，因为靠后的设备注意力计算会更长

这里的关键点是：每个设备不仅传递KV缓存，也要利用收到的缓存，完成自己那部分词元的注意力计算。

+ 在 D1 上:
  + 计算T1-T4的Q_0, K_0, V_0。
  + 立刻进行自己部分的注意力计算：用Q_0与K_0计算一个4x4的注意力矩阵，得到输出A_0。
  + 然后，它将K_0, V_0（尺寸为4的缓存）发送给D2。
+ 在 D2 上:
  + 在等待D1数据的同时，它可以并行计算T5-T7的本地Q_1, K_1, V_1。
  + 当它收到D1发来的K_0, V_0后，它将自己本地的K_1, V_1追加上去，形成一个包含T1-T7信息的、尺寸为7的KV缓存。
  + 立刻进行自己部分的注意力计算：用自己的Q_1（来自T5-T7）与这个尺寸为7的完整缓存进行计算（一个3x7的注意力计算），得到输出A_1。
  + 然后，它将这个尺寸为7的KV缓存发送给D3。
+ 在 D3 上:
  + 并行计算T8-T9的本地Q_2, K_2, V_2。
  + 收到D2发来的尺寸为7的缓存后，追加自己的K_2, V_2，形成包含全部9个词元信息的最终KV缓存。
  + 它进行自己部分的注意力计算：用Q_2与这个尺寸为9的完整缓存进行计算（一个2x9的注意力计算），得到输出A_2。
  + 作为最后一个设备，它最终生成第一个令牌。

### TSP

![pasted-image-20250818105741](/images/pasted-image-20250818105741.png)

TSP方案旨在并行化标准的单设备注意力计算流程。其标准工作流程如图4所示：

+ **执行流程**:
    1. 将输入上下文在多个处理器（进程）间**均匀划分**。
    2. 每个进程独立计算其对应部分的Q, K, V向量。
    3. 通过一次**`all-gather`**集体通信操作，所有进程交换并获得完整的K和V向量。
    4. 每个进程使用其本地的Q和全局的K, V来计算均等分配的注意力输出部分。

+ **技术瓶颈**:
  + **计算冗余**: TSP忠实地并行化了通用的注意力计算方法，即先计算一个完整的稠密$QK^T$矩阵，然后再通过掩码（mask）忽略掉上三角部分。这个过程没有利用LLM的因果性，导致了大量的无效计算，造成了计算资源的浪费。
  + **通信瓶颈**: `all-gather`操作是一个**全局同步点**，要求所有进程必须互相等待，这会成为性能瓶颈。同时，它导致了很高的网络流量；在论文的示例中，TSP需要交换36个(K, V)条目。

### KVR

![pasted-image-20250818105844](/images/pasted-image-20250818105844.png)

+ **执行流程**:
    1. 对输入上下文进行**非均匀划分**以实现负载均衡。
    2. 每个进程独立计算其对应部分的Q, K, V向量。
    3. 进程间形成一个计算链，通过**点对点（point-to-point）的`send`操作**，将本地计算并拼接后的KV缓存逐级传递给下一个进程。
    4. 每个进程利用接收到的KV缓存和自己本地的QKV，计算出自己负责部分的注意力输出。只有最后一个进程会拥有完整的KV缓存。

+ **技术优化**:
  + **计算优化**: KVR的链式构建过程天然遵循了因果关系，因此它能**自动避免**对$QK^T$矩阵上三角部分的无效计算。论文的例子显示，TSP在所有进程上都需要27次点积运算，而KVR的计算瓶颈（最繁忙的进程）仅需21次。
  + **通信优化**: KVR用点对点通信取代了全局同步的`all-gather`，消除了全局等待瓶颈。同时，总通信量也显著降低；在同一示例中，KVR仅需交换22个(K, V)条目，远少于TSP的36个。

> 即使TSP通过定制的BLAS内核来避免无效计算，其 `all-gather` 通信模式仍然是低效的，而KVR通过复用KV缓存机制，无缝地同时解决了计算和通信两个瓶颈。

## Evaluation

## Thoughts

### When Reading

## Related Works

+ [Ring Attention with Blockwise Transformers for Near-Infinite Context](papers/llm/Ring%20Attention%20with%20Blockwise%20Transformers%20for%20Near-Infinite%20Context.md)
+ [Striped Attention Faster Ring Attention for Causal Transformers](papers/llm/Striped%20Attention%20Faster%20Ring%20Attention%20for%20Causal%20Transformers.md)
