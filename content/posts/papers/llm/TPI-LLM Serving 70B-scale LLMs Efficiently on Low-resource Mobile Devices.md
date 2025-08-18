---
title: "TPI-LLM Serving 70B-scale LLMs Efficiently on Low-resource Mobile Devices"
tags:
  - TSC-24
  - LLM-Inference
  - Tensor-Parallelism
date: 2025-08-17
showtoc: true
---

> Extensive Reading

> A similar paper is found: [arxiv.org/pdf/2504.08791?](https://arxiv.org/pdf/2504.08791?)

## Author Info

- [‪Zonghang Li‬ - ‪Google 学术搜索‬](https://scholar.google.com/citations?hl=zh-CN&user=1IA-XokAAAAJ&view_op=list_works&sortby=pubdate)

## Background

LLM serving is shifting from the cloud to edge devices like smartphones and laptops. This trend is driven by growing privacy concerns, as users want to avoid sending their sensitive interaction data to cloud providers. The goal is to process user requests locally on their own devices.

### Preliminaries

-
- [TP 场景下 KV Cache 的维护](papers/llm/LLM%20Preliminaries.md#TP%20场景下%20KV%20Cache%20的维护)

## Challenges

- **Hardware Limitations**: Mobile devices have very limited memory (typically 4-16 GiB) and computing power, often lacking GPUs. Running a 70B-scale model can require over 40 GiB of memory, which far exceeds the capacity of a single device.
- **Inefficient Parallelism**: The standard solution for distributed systems, pipeline parallelism, is inefficient for home scenarios where only one request is processed at a time. This leads to many devices being idle most of the time, wasting resources.
- **Slow Memory Offloading**: Existing on-device solutions like llama.cpp and Accelerate offload model data to disk to save RAM. However, their blocking disk I/O operations significantly slow down the inference speed.

## Insights

- 在低资源设备协同的环境下，应该选择 Tensor Parallelism
  - 用户的请求一次性只有一条，并行的目的应该是降低延迟而不是增加吞吐量
- Tensor Parallelism 依赖 allreduce 操作来同步和聚合计算结果，在低资源设备协同的环境下，通信瓶颈并非网络带宽而是链路延迟
  - 使用 star-based allreduce 来降低网络跳数进而降低延迟
- 使用滑动窗口内存调度器来异步加载和卸载权重
  - 由一个独立的线程后台进行
  - 将权重的加载隐藏在计算和同步的过程中

## Approaches

![pasted-image-20250817152232](/images/pasted-image-20250817152232.png)

TPI-LLM 采用 master-worker 架构。

- 初始化：master 将预训练好的模型权重分割，并分发给各个 worker。
- 推理开始：用户输入（prompt）在主节点上被处理和编码成嵌入向量，然后广播给所有工作节点 。
  - 用户的原始输入和模型的最终输出始终保留在主设备本地，确保了隐私安全。
- 并行计算：所有设备接收到嵌入向量后，开始逐层进行张量并行计算。每一层都包含 attention 计算和 FFN（前馈网络）计算，每次计算后都通过 star allreduce 同步结果。
- 内存调度：在整个计算过程中，每个设备上的滑动窗口内存调度器都在后台持续工作，按需从磁盘加载和卸载权重。
- 生成下一个词元：所有层计算完毕后，最终结果被传回主节点，由主节点进行解码，生成下一个词元。该过程循环往复，直到生成完整的序列。

## Tensor Parallelism

- Attention Block 按照 attention head 拆分到不同的设备上，因为 head 之间是相互独立互不影响的，KV Cache 也能根据不同的 head 独立维护
- FFN Block 就是纯数学拆分, 可以参考 [FFN 的并行化](papers/llm/LLM%20Preliminaries.md#FFN%20的并行化)

## Evaluation

- 没有给出 70B 模型具体的生成速度
- B. TPI-LLM vs. On-device Systems with Memory Scheduling 实验中
  - TPI-LLM 使用了 4 台设备
  - llama.cpp 使用了 1 台设备
  - 为什么不和 [b4rtaz/distributed-llama](https://github.com/b4rtaz/distributed-llama) 对比？

## Thoughts

### When Reading

论文中的一些 references 挺有意义的，后续可以研究一下

论文中很多地方都是不必要的，个人感觉是在凑篇幅：

- Algorithm3, Algorithm4: 基础原理非常简单，还需要用两个伪代码块？
- 把 Sliding Window Memory Scheduling 建模为 finite-capacity birth-death Markov chain
  - 有必要吗？这技术一点也不复杂，说白了就是小学数学的的泳池进水和放水问题
  - 进水速度 (memory scheduler 加载权重的速度) > 放水速度 (main thread 消耗权重的速度)，那泳池就能装满
- Figure 8: 很少见到这种原生态的照片，有什么意义，上次看到还是在另一篇水文 [EdgeShard](papers/llm/EdgeShard%20Efficient%20LLM%20Inference%20via%20%20Collaborative%20Edge%20Computing.md) 中

实验设置也比较疑惑：

- Testbed 1: 两台 Macbook，GPU 也不用，在那里用 FP32 硬算
- Testbed 2: 1ms 的延迟是故意设置的，真实环境下没这么高，1ms 意味着任意两台设备之间的 RTT 来到了 8ms
  - 北京到青岛/沈阳/威海的 RTT 也才 8ms 左右
  - 合理猜测是有一个导师原来是搞网络的，对这个网络跳数比较敏感
  - 如果在正常环境下，star-based allreduce 可能效果并不会好多少

滑动窗口调度器效果这么好，为什么 llama.cpp 不使用呢？

- 我猜测这个方法的性能根本没有这么好，属于典型的 "seems to work"
- 这个方法要起作用，前提是 计算 + 同步的时间 > 异步加载的时间
- 然而**可能计算的时间没这么长(decoding phase is memory-bounded)**，TPI-LLM 只能变相延长同步时间 (RTT: 8ms)，手动地让 计算+ 同步的时间 > 异步加载的时间

> [!SUMMARY] Final Summary
>
> 水

## Related Works

- [EdgeShard Efficient LLM Inference via  Collaborative Edge Computing](papers/llm/EdgeShard%20Efficient%20LLM%20Inference%20via%20%20Collaborative%20Edge%20Computing.md)
