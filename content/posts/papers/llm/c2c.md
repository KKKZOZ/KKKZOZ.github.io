---
title: "C2C"
tags:
  - LLM-Inference
  - KVCache
  - Collaborative-Inference
date: 2025-12-06
showtoc: true
draft: true
---

> Extensive Reading

## Author Info

## Background

## Insights

The author conducts two oracle experiments to answer:

+ Can a model’s capabilities be improved through KV-Cache semantic enrichment without extending sequence length?
+ Can the KV-Cache of one model be effectively utilized by another model?

### Cache Enrichment Oracle

The author sets up three methods with $X$(the question) and $E$(the examples) to test accuracy:

1. Direct: Only use $X$
2. Few-shot: Use $E+X$
3. Oracle: Use $E+X$ for prefill and use $X$ for decoding

+ The KV Cache of $X$ now contains richer semantics including the examples($E$)

![pasted-image-20251206155952](/images/pasted-image-20251206155952.png)

TODO: "while some layers benefit from cache enrichment, others experience performance degradation" --> Does this experiment include all layers?

### Cache Transformation Oracle

Train a 3-layer MLP to map the KV-Cache from a source LLM

![pasted-image-20251206160151](/images/pasted-image-20251206160151.png)

These results demonstrate that KV-Caches from different models are, in general, convertible as the transformed cache in the representation space of the target model.

> [!NOTE]
>
> + The transformed cache occupies only a smaller subset of the target’s space.
> + The correct-answer sets of different models exhibit limited overlap (Figure 7), despite the comparable aggregated accuracy of respective models.

![pasted-image-20251206160858](/images/pasted-image-20251206160858.png)

TODO: How does this MLP being trained? Can we reproduce it?

## Challenges

## Approaches

### Overall

In general, the C2C paradigm contains a set of key/value cache fusers $\mathcal{F}$ and a layer mapping strategy $\mathcal{G}$.

During the prefill stage, fuser $\mathcal{F}_n$ takes the $n$-th layer cache of the Receiver Model $\mathcal{C}_n(X)$ and the corresponding $\mathcal{G}(n)$-th layer cache of the Sharer Model $\mathcal{C}_{\mathcal{G}(n)}^{\mathcal{S}}(X)$ and generates the corresponding fused cache:

$$
\mathcal{C}^{\mathcal{F}}=\{\mathcal{F}_{n}(\mathcal{C}_{n}(X),\mathcal{C}_{\mathcal{G}(n)}^{\mathcal{S}}(X))\}_{n=1}^{N}
$$

During decoding, with the current token $y_{i}$ and caches from the input and the generated prefix, the next token is predicted as:

$$
y_{i+1}=\mathcal{P}(y_{i}|\mathcal{C}^{\mathcal{F}}(X)\oplus\mathcal{C}(Y_{[0:i]}))$$

### Fuser

it contains three key modules:  
- **Projection module** concatenates the Receiver’s KV-Cache with the Sharer’s KV-Cache, then processes the concatenated feature through a projection layer followed by a feature fusion layer.
- **Dynamic weighting module** applies an input-aware head modulation layer to dynamically re-weight the projected information.
- **Learnable gate** introduces a trainable per-layer gate value that decides whether to inject the Sharer’s context. The value applies a Gumbel-sigmoid with temperature annealing to smoothly transition from differentiable during training to binary at inference.

![pasted-image-20251206161148](/images/pasted-image-20251206161148.png)

## Evaluation

## Thoughts

### When Reading

## Related Works
