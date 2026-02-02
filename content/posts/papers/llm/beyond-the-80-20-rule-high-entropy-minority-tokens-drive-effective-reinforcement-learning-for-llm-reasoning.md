---
title: "Beyond the 80 20 Rule High-Entropy Minority Tokens Drive Effective Reinforcement Learning for LLM Reasoning"
tags:
  - NeurIPS-25
date: 2026-01-07
showtoc: true
---

> InExtensive Reading

## Author Info

## Background

目前，带验证奖励的强化学习（RLVR，如用于训练 DeepSeek-R1 或 OpenAI o1 的技术）显著提升了 LLM 的推理能力。然而，现有方法通常对生成的所有 Token 进行训练，缺乏对“哪些 Token 真正推动了推理能力提升”的细粒度理解。

## Insights

论文首先对思维链（CoT）中的 Token 熵模式进行了定性和定量分析：

CoT 中的熵分布模式：

低熵多数派（Low-Entropy Majority）： 大部分 Token 的生成熵很低。这些 Token 主要负责语法结构的补全或按部就班的叙述（例如 "The answer is", "implies that"），它们倾向于“遵循路径（Follow the path）”。

高熵少数派（High-Entropy Minority）： 只有少部分 Token 具有高熵。这些 Token 通常出现在逻辑推理的关键转折点、假设提出或步骤选择上（例如 "However", "Suppose", "Thus"），被称为**“分叉 Token”（Forking Tokens）**。它们负责“决定路径（Fork the path）”。

RLVR 训练在很大程度上保留了基座模型（Base Model）的熵模式。

训练过程主要调整的是那些原本就是高熵的 Token 的概率分布，而低熵 Token 的变化非常微小。

基于上述观察，作者提出了一种改进的 RLVR 算法策略，即只针对高熵 Token 计算梯度。

## Challenges

## Approaches

## Evaluation

作者在 Qwen3-8B、14B 和 32B 模型上进行了广泛的实验，主要结论如下：

+ 超越 80/20 法则（Beyond the 80/20 Rule）：
  + 仅使用 Top 20% 高熵 Token 进行训练，在 Qwen3-32B 模型上，其数学推理基准（AIME '24/'25）的分数显著高于使用 100% 所有 Token 进行训练的结果（+7.71 / +11.04 分）。
  + 在 Qwen3-8B 上，性能与全量训练持平；在 14B 上，性能有明显提升。这表明该方法具有良好的Scaling（缩放）特性——模型越大，专注于高熵 Token 的收益越高。
+ 反面验证： 如果仅使用 Bottom 80% 的低熵 Token 进行训练，模型性能会大幅下降。这证明了低熵 Token 对推理能力的贡献微乎其微。
+ 泛化能力： 在非数学领域的代码基准测试（LiveCodeBench）中，仅训练高熵 Token 的模型也表现出了比全量训练更好的泛化性。

## Thoughts

### When Reading

## Related Works
