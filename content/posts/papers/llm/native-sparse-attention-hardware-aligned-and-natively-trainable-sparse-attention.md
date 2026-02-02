---
title: "Native Sparse Attention Hardware-Aligned and Natively Trainable Sparse Attention"
tags:
  - deepseek
date: 2026-01-29
showtoc: true
draft: true
---

> Extensive Reading

## Author Info

## Background

## Insights

## Challenges

## Approaches

![pasted-image-20260129220930](/images/pasted-image-20260129220930.png)

### Token Compression

为什么是 $0 \le i \le ceil{\dfrac{t-l}{d}}$?

第 i 个 Block 起点为 id+1, 终点为 id+l，$id+l \le t$，移项后可得

### Token Selection

还是以 Block 为单位，需要考虑的是重要性分数如何计算

选择的时候比较简单，就是选择重要性分数 Top-n 的 Block

### Sliding Window

### Kernel Design

![pasted-image-20260129223528](/images/pasted-image-20260129223528.png)

## Evaluation

## Thoughts

### When Reading

## Related Works
