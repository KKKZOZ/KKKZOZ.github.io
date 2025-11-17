---
title: "DuoAttention Efficient Long-Context LLM Inference with Retrieval and Streaming Heads"
tags:
  - arXiv-24
  - Long-Context
date: 2025-11-13
showtoc: true
---

> Extensive Reading

## Author Info

- [MIT HAN Lab](https://hanlab.mit.edu/)

## Background

- **Long-context LLMs strain attention and KV caches.** As sequence length grows, prefill cost scales quadratically and decoding linearly, while KV cache memory grows linearly, making naive full-attention inference impractical in real-world long-context applications.

- **Existing architectural and approximate-attention methods trade accuracy or require retraining.** Linear-attention and specialized long-context architectures reduce complexity but often underperform standard Transformers on long-range reasoning, while methods like H2O, StreamingLLM, TOVA, and FastGen drop or sparsify tokens uniformly across heads, which can severely damage long-context retrieval accuracy and are difficult to apply safely in settings with KV-sharing schemes such as GQA.

- **KV cache quantization and system-level optimizations are helpful but incomplete.** Quantizing KV caches (e.g., to 4–8 bits) and using optimized kernels (FlashAttention, PagedAttention, chunked prefill) reduce memory and compute overhead, yet they do not fundamentally change the fact that all heads still maintain full-length KV caches, leaving substantial redundancy and head-level inefficiency unexploited.

## Insights

Only a fraction of attention heads, a.k.a, **Retrieval Heads**, are critical for processing long contexts and require full attention across all tokens. In contrast, all other heads, which primarily focus on recent tokens and attention sinks–referred to as **Streaming Heads** – do not require full attention.

> Not all attention heads are equal important to the entire context. Do not force them all to store and compute over every token.

## Challenges

- How to precisely identify the retrieval heads?
- How to get wall-time speed up?

## Approaches

### How to identify retrieval heads?

This paper defines "retrieval heads" as the attention heads that **significantly alter model outputs when restricted to recent tokens and attention sinks**.

For each KV head (or KV group, in GQA models), they introduce a **trainable scalar gate** ( \alpha_{i,j} \in [0, 1] ).

At training time, the output of that head is:

$$
\text{attn}*{i,j} = \alpha*{i,j} \cdot \text{full\_attn} + (1 - \alpha\_{i,j}) \cdot \text{streaming\_attn}
$$

- **full_attn**: standard causal attention over all previous tokens
- **streaming_attn**: attention over only:

  - attention sinks (head positions at the start), plus
  - a fixed window of recent tokens

All **model weights are frozen**. Only the ( $\alpha$ )’s are trained.

The data set is synthetic passkey retrieval dataset.

They want to minimize:

- A **distillation loss**: L2 distance between the hidden states of the full-attention model and the gated model on the passkey output positions
- Plus an **L1 regularization** term on all ( $\alpha_{i,j}$ ) to encourage sparsity (many gates → small)

> [!NOTE]
>
> - **L2 distance**: penalty for being different
>   - $L_{\text{distill}} = \frac{1}{N} \sum_{i=1}^{N} \sum_{j=T-l+1}^{T} \left( H^{(i)}_{\text{full}}[j] - H^{(i)}_{\text{mixed}}[j] \right)^2$
>   - N -> the number of training samples
>   - T -> the sequence length in tokens for that sample
> - **L1 regulariztion**: encourage to use a smaller $\alpha_{i,j}$
>   - $L_{\text{reg}} = \sum_{i=1}^{L} \sum_{j=1}^{H} |\alpha_{i,j}|$

$$
L = L_{\text{distill}} + \lambda L_{\text{reg}}
$$

The result:

- Heads that **must** access the full context (otherwise outputs diverge) end up with **high α** → retrieval heads
- Heads that can get away with streaming attention end up with **low α** → streaming heads

After training, they **binarize** using a threshold τ: above τ = retrieval head, below τ = streaming head.

![pasted-image-20251114151752](/images/pasted-image-20251114151752.png)

### How to get speed up?

By dropping middle tokens for streaming heads while keeping full attention for retrieval heads, we reduce the memory demands of streaming heads to $O(1)$, thereby improving the efficiency of processing long contexts.

Each Transformer layer has two KV caches — a full KV cache for crucial retrieval heads and a constant KV cache for streaming heads, which stores only attention sinks and recent tokens.

![pasted-image-20251114151702](/images/pasted-image-20251114151702.png)

## Evaluation

## Thoughts

### When Reading

DuoAttention handles attention heads at the unit of KV heads/group, maybe in the profiling of ELMS, we can reference this method -- measure single query heads is meaningless.

## Related Works
