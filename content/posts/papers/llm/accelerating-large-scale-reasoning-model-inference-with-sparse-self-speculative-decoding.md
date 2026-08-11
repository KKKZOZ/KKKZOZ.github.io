---
title: "Accelerating Large-Scale Reasoning Model Inference with Sparse Self-Speculative Decoding"
tags:
  - LLM-Inference
  - Speculative-Decoding
date: 2025-12-17
showtoc: true
draft: true
---

> Extensive Reading

## Author Info

## Background

对 Attention 还有 FFN 的计算分析有参考性

## Insights

论文的核心 idea 很清晰：

Self-speculative decoding + Sparse Attention

具体的方法是：

+ Draft 阶段使用 Sparse Attention，只计算由上一轮 Verification 给出的 Top-K 个 critical token
  + 更细一点来说，可以将 KV Cache 分为两部分：
    + Sparse Cache: 包含 Top-K 个 Token
    + Recent Cache: Draft 阶段会生成多个 Token, 这些 token 依次放入 recent cache 中
+ Verification 阶段利用完整的注意力进行验证，并得到 Top-K 个注意力分数最大的 Token

具体如下图所示：

![pasted-image-20251217112013](/images/pasted-image-20251217112013.png)

## Challenges

## Approaches

## Evaluation

## Thoughts

### When Reading

局限性是必须在长生成任务下：长生成（long-generation）导致 KV-cache 很大，从而 attention 变成内存带宽瓶颈

也就是说 KV Cache 要足够大才行

## Related Works
