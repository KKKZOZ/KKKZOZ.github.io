---
title: "SpecAttn Speculating Sparse Attention"
tags:
  - LLM-Inference
  - sparse-attention
date: 2026-01-30
showtoc: true
draft: true
---

> Extensive Reading

## Author Info

## Background

- Computational bottleneck of Large Language Models (LLMs) — specifically the quadratic complexity of self-attention

## Insights

The attention patterns computed by a draft model can serve as accurate predictors for the attention patterns of the larger "verifier" model.

By using the draft model’s attention weights to identify important tokens, SpecAttn prunes the key-value (KV) cache for the verifier model without requiring additional predictor networks or model retraining.

简单分析这个 insight, 论文中应该对以下几点问题做出解决：

- 为了防止出现在 Long Document QA 场景下掉太多的准确率，是不是显存中还是维护了全量的 KV Cache，然后通过传 Index 的方式在大模型注意力计算之前组装一个 pruned KV Cache tensor?

- 大小模型的网络结构不同，是怎么做映射的
  - 具体来说，Layer 数量不同，每一层的 Attention Head 数量也不同
  - 每个 Attention Head 的 Attention Weights 是不一样的，比如 [H2O](posts/papers/llm/h2o-heavy-hitter-oracle-for-efficient-generative-inference-of-large-language-models.md) 就是按照 Head 为单位进行驱逐的，因为单个 Head 在计算时，shape 为 `(batch_size, num_heads, q_len, head_dim) @ (batch_size, num_heads, k_len, head_dim)^T = (batch_size, num_heads, q_len, k_len)`, 也就是每个 Head 都有自己的 Attention weight map, 并且大小模型的 Attention Head 的数量还不同，这之间是怎么做映射的
- 是不是无法采用 FlashAttention?
  - 如果采用 Attention Weights 的方式，就不能使用 FlashAttention 这种加速方式，因为 FlashAttention 在计算过程中是不会维护 `(q_len, k_len)` 这个 softmax 矩阵的，如果是通过返回的 `lse` 重建，那么额外开销应该会比较大

## Challenges

## Approaches

## Evaluation

## Thoughts

### When Reading

## Related Works
