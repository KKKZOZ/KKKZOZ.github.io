---
title: "H2O Heavy-Hitter Oracle for Efficient Generative Inference of Large Language Models"
tags:
  - NIPS-23
date: 2025-08-21
showtoc: true
---

> Skimming

## Author Info

- [Zhenyu "Allen" Zhang](https://zhenyu.gallery/):  A final-year Ph.D. student at the Electrical and Computer Engineering Department of UT Austin.
- [Ying Sheng](https://sites.google.com/view/yingsheng/home)

## Insights

- **Inherent Sparsity of Attention**
  - 推理过程中，其注意力矩阵表现出极高的稀疏性，超过95%的注意力值都非常小。这意味着在生成下一个 token 时，模型实际上只关注了过去所有词元中的一小部分。这为减少 KV Cache 的大小提供了可能性，因为大部分缓存的键值对实际上很少被用到
- **Existence of "Heavy Hitters"**
  - 通过分析词元在注意力计算中的累积得分，作者发现这些得分遵循 Power-law distribution, 这意味着只有一小部分词元 (Heavy Hitters) 贡献了绝大部分的注意力价值。这些 H₂ 词元对于维持模型的性能至关重要，如果将它们从缓存中移除，模型的准确率会急剧下降
- **Effectiveness of Local Statistics**
  - 理论上，要识别出真正的 Heavy Hitters 需要知道未来所有词元的注意力信息，这在自回归生成中是不现实的。
  - 论文通过实验发现，仅使用局部信息——即在每个解码步骤中，根据已经生成的词元来计算和累积注意力分数——来动态确定 H₂，其效果与使用全局信息几乎一样好。

> [!SUMMARY]
>
> 既然不是所有的历史信息都同等重要，那么就可以设计一种智能的缓存管理策略，只保留那些最关键的信息，从而在有限的显存中实现高效推理。

## Approaches

论文提出了 H₂O (Heavy-Hitter Oracle) 缓存驱逐策略。其核心是在有限的缓存空间里，动态地保留两类最重要的信息：

- Heavy Hitters (H₂) Tokens：那些被证明对全局上下文理解至关重要的词元。
- Recent Tokens：最近生成的几个词元，它们对维持局部语义的连贯性至关重要。

算法流程：

1. 初始化与填充：在推理开始阶段，KV缓存尚未满时，所有生成词元的键值对（KVs）都会被存入缓存。
2. 分数累积：在每一个解码步骤，模型都会计算新生成的词元对缓存中所有历史词元的注意力分数。这些分数会被累加到对应历史词元的累积注意力分数上。
3. 驱逐决策：当缓存已满，需要为新的词元腾出空间时，H₂O 策略会启动：

- 它会保留一个固定大小的窗口用于存放最近生成的词元，确保局部上下文的完整性。
- 在余下的缓存空间中，它会根据所有“非最近”词元的累积注意力分数进行排序。
- 分数最低的那个词元被认为是“最不重要”的，其对应的 KV 将被从缓存中驱逐。
