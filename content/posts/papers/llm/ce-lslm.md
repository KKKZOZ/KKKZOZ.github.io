---
title: "CE-LSLM"
tags:
  - TOBETAGGED
date: 2025-12-04
showtoc: true
draft: true
---

> Extensive Reading

## Author Info

## Background

- **Cloud-only LLM inference**
  - Requires sending all user data to cloud → high latency + privacy risk.
  - Long system prompts and long histories make KV cache heavy and expensive over the network.
- **Edge-only SLM inference**
  - Fits edge hardware, but lacks deep semantic capability for hard tasks.
  - Simply compressing/pruning models can hurt accuracy.
- **Existing cloud–edge LLM work**
  - Either splits layers across cloud/edge (still lots of state transfer & fragile to network problems) or uses edge models only for prompt engineering / pre-processing.

## Insights

## Challenges

## Approaches

关于 System Prompt（系统提示词/背景上下文）：

- 深层（Deep Layers）：由 云端大模型（LLM） 负责计算。它生成这部分的 KV Cache，经过压缩后发送给边缘。
- 浅层（Shallow Layers）：由 边缘小模型（SLM） 负责计算（或者从附近的边缘节点获取）。SLM 不依赖云端来获取这一部分的特征。

关于 User Prompt（用户提示词/隐私数据）：

- 完全由 SLM 负责：当用户输入具体问题时，只有边缘 SLM 会对这些内容进行计算。
- 大模型不参与：云端 LLM 看不到 用户的 User Prompt，也不参与 User Prompt 的注意力计算或后续的 Token 预测。这意味着用户隐私数据不需要上传到云端。
关于 Token 生成（解码阶段）：
- 完全由 SLM 负责：最终的输出结果（Inference result）是由边缘设备在加载完深层 Cache 并结合本地计算后，独立解码生成的。

这篇文章比较有意思的一个点是，在大小模型之间实现了 KV Cache 的复用

为了实现复用，需要解决两个问题：

1. 大小模型层数不同，无法直接对应，所以需要通过 计算 CKA 和 RSA 来确定 layer 之间的映射关系，并且这种映射关系是离线 profile 出来的，也就是说，映射关系是静态的
2. 在确定 layer 之间的映射关系后，大小模型的 hidden feature 也不同，所以还需要对 KV tensor 的维度进行降维，来匹配小模型的维度，降维策略的核心逻辑就是：保留那些决定注意力分布（Attention Pattern）的关键特征维度，对于降维操作来说，是动态的，也就是说，和当前序列的注意力分布有关系，每次都要重新计算，并没有一个固定的映射关系

这和我最近的思路非常像，有时间复现一下试试

文章提出，在复用 KV Cache 时，不能全部都复用，最好是浅层的自己算，深层的用大模型转移过来的，因为浅层的是一些关于语义的捕捉，不容易做对齐

文章还提出，复用大模型的 KV Cache，能够实现语义增强的效果，我怀疑是否真的有效果，毕竟大小模型 hidden feature，层数完全不一样，怎么会语义相同，有一种可能是在长文本的情况下，大模型能够捕捉更细的上下文关联？

之前查资料时好像看过，Base 模型和 Instruct 模型不同，Instruct 模型被蒸馏过，效果会更好？复现时需要注意一下

### Optimize Communication Transmission Latency

LLM has $N$ layers and SLM has $M$ layers, CE-LSLM selects n out of N layers from LLM and transmits to SLM

## Evaluation

## Thoughts

### When Reading

文章写得挺烂的，图也画得挺烂的，非要和 6G 扯上关系

可能唯一有价值的一点就是告诉我 KV 迁移这条路走得通吧

不如看看它引用的那几篇关键文章

- CacheGen: Prior studies have shown that KV caches from structurally similar layers can be interchangeable without significantly affecting the final hidden state outputs
  - UPDATE: 感觉被骗了，CacheGen 中也完全没说 interchangeable 的事情，但是整体上对在 network 上传输 KV Cache 的优化还是可以借鉴的
- Think Thinner key cache by query-driven pruning: To further reduce the computational and transmission overhead of attention heads during collaborative inference, we introduce a dimensionality reduction strategy inspired by the pruning objective proposed in "Think"

## Related Works
