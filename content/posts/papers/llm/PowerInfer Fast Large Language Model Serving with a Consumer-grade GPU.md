---
title: "PowerInfer Fast Large Language Model Serving with a Consumer-grade GPU"
tags:
  - SOSP-24
  - LLM-Inference
  - Commodity-GPU
date: 2025-07-28
showtoc: true
draft: true
---

> Extensive Reading

## Background

## Challenges

## Insights

## Approaches

## Evaluation

## Thoughts

### When Reading

许多 MLSys 工作都遵循 observation-insight-method 范式。

Insight-2 的数据指导性很强 - 当我们在讨论大模型在 CPU 和 GPU 上的执行速度差异时 (小批次)，计算能力本身不是瓶颈，数据 I/O 的时间占了很大一部分，权重数据通过 PCIe 总线传输到 GPU 所需的时间，**超过了** GPU 本身能节约的计算时间。

无论是这篇文章中提到的 neuron-aware 还是 [AWQ](papers/llm/AWQ%20Activation-aware%20Weight%20Quantization%20for%20LLM%20Compression%20and%20Acceleration.md) 中的 activation-aware，这都说明 MLSys 的研究与 ML 本身结合越来越紧密，不再是简单地将 System 领域的 cache, batch, pipeline, parallelism 等概念直接移植到 ML 中就可以了，要求研究者在 ML 领域也要有极其扎实的功底。

从写作风格上来说，core insights 和 core idea 必须反复在文章不同位置中强调，值得学习。

Predictors 需要额外的训练。
