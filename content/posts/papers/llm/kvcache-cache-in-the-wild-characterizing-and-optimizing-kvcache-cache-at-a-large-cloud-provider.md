---
title: "KVCache Cache in the Wild Characterizing and Optimizing KVCache Cache at a Large Cloud Provider"
tags:
  - ATC-25
  - KVCache
date: 2025-12-06
showtoc: true
---

> Extensive Reading

## Author Info

- IPADS
- Alibaba Group

## Background

Large-scale services go further and maintain a KV cache cache (prefix/prompt cache) that reuses KV blocks across different requests that share prefixes.

Most deployed KV eviction strategies reuse general-purpose cache policies:

- Recency-based (LRU, FIFO) and frequency-based (LFU) policies, sometimes combined (e.g., GDFS-style recency–frequency–size heuristics).

These methods are workload-agnostic and overlook several KV-specific realities:

- KV blocks often have short, bursty lifespans; past frequency is a poor predictor of future reuse.
- Different request categories (API vs chat, first turn vs later turns) have very different reuse patterns that generic policies cannot distinguish.
- Spatial locality is highly asymmetric: early “head” blocks of prompts are far more valuable than late “tail” blocks, but standard policies treat all blocks similarly.

## Observations

Trace A: To-C workload, a consumer-facing trace including:

- Web/app chatbots,
- File understanding,
- Multimodal interactions,
- Search-enhanced scenarios.
- Human users are in the loop, so interactions are slower and more varied.

Trace B: To-B workload, a business-facing trace accessed through an OpenAI-compatible API:

- Mostly single-turn, programmatic requests,
- High QPS, low per-request latency,
- Heavy use of templates and fixed prompts.

### 1 Ideal hit rate is lower than synthetic benchmarks

Using an idealized infinite cache (no capacity limit, perfect future knowledge), the authors ask: if KV were never evicted, what fraction of accesses would hit?

The answer is surprisingly modest:

- Around 62% in the consumer trace (Trace A),
- Around 54% in the enterprise API trace (Trace B).

The work also shows a heavy skew:

- A small fraction of KV blocks account for the majority of reuses.
- Around 10% of blocks can be responsible for ~80% of reuse.

### 2 Who is reusing KV

> A natural intuition is that multi-turn chat should dominate KV reuse, since later turns in a conversation reuse the previous context. But the reality is slightly different.

- In the API-heavy Trace B, single-turn requests account for the vast majority of KV hits—roughly 97% in the paper’s measurements.
  - This happens because many API calls **share long, identical system prompts or templates** across calls.

- In the consumer setting, multi-turn chats do contribute significantly to reuse, but **cross-user reuse is extremely rare**. Most reuse happens within the same user.

### 3 Temporal locality: reuse time and lifespan

The authors then study when KV blocks tend to be reused.

They define:

- Reuse time: time between a block’s creation and its next reuse.
- Lifespan: time from creation until its last reuse (after which it is effectively dead).

The results are striking:

- In the consumer trace, most reuses happen within minutes. About 80% of reuses **occur within 10 minutes**.
- In the API trace, reuse times are dramatically shorter: many reuses **happen within seconds** due to bursty, programmatic calls.

Looking at lifespan:

- In the consumer setting, 90% of **blocks** die within about 10 minutes.
- In the API setting, 90% die in under a second.

> [!SUMMARY]
>
> KV blocks are **ephemeral**: they either get reused quickly or not at all, with a long tail of a few “evergreen” blocks (like popular system prompts) living much longer.

Crucially, the authors also observe that for each request category (e.g., type + turn index), the reuse time distribution:

- Is **well-approximated by an exponential distribution**,
- Remains stable across neighboring time windows (e.g., 9–10am vs. 10–11am),
- Shows similar shape across days with similar traffic patterns.

This means that **reuse behavior is predictable per category**, and can be modeled and updated from recent history.

### 4 Spatial locality: where in the prompt is reuse concentrated?

KV caching operates at the block level, and each block corresponds to a specific position in the sequence: earlier blocks store the head of the prompt, later blocks the tail.

The answer is clear about spatial locality:

- Reuse is heavily concentrated at the **beginning of the prompt**.
- Early blocks (system prompts, templates, previous turns) are far more likely to be reused than later blocks.

> Blocks with smaller offsets (closer to the start) should be treated as more **valuable**.

### 5 KV Size and required capacity

- For modern GQA models (like many Qwen or LLaMA variants), the median KV memory per request is a tiny fraction of the available KV HBM on a serving instance.
- Even at the 99th percentile, a single request often uses only a few percent of KV memory.

**On-GPU KV capacity alone can often support near-ideal reuse**, potentially reducing the need for complex multi-tier hierarchies in some settings.

## Approaches

**Core idea: prioritize blocks by estimated reuse probability**

Each KV block is tagged with its workload category, For each category, the system:

- Uses recent runtime logs (e.g., last hour) to fit or update an exponential distribution for reuse times.
- For a block that was last accessed at time $t_0$, and is being considered at current time $t$, the age is $t - t_0$.
- The system estimates the probability that this block will be reused in the near future, based on:
  - The exponential CDF for that category,
  - A notion of remaining lifespan horizon (how long it is still reasonable to expect reuse).

## Evaluation

## Thoughts

### When Reading

## Related Works
