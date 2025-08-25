---
title: "Ring Attention with Blockwise Transformers for Near-Infinite Context"
tags:
  - arXiv-23
  - Sequence-Parallelism
date: 2025-08-17
showtoc: true
---

> Extensive Reading

## Author Info

- [Hao Liu](https://www.haoliu.ai/): A research scientist at Google DeepMind.
- [Matei Zaharia](https://people.eecs.berkeley.edu/~matei/): An associate professor at UC Berkeley (previously Stanford), where he works on computer systems and AI in the Sky Lab.

## Related Blogs

- [Ring Attention Explained | Coconut Mode](https://coconut-mode.com/posts/ring-attention/)

## Background

Transformer 的 核心组件“自注意力机制”的内存消耗会**随着输入序列长度的增加而呈二次方增长**。这导致即便是最先进的 GPU/TPU，其有限的显存（通常小于 100GB）也无法处理超长序列，例如处理百万甚至千万级别的 token.

> [!note] 注意力模块的显存占用分析
>
> - $B$: Batch size
> - $N$: Sequence length
> - $H$: Number of attention heads
> - $D$: Hidden Dimension
>
> - Weights：
>   - $W_q, W_k, W_v, W_o$: $4 \times D \times D = 4D^2$
> - Activations:
>   - Standard Attention
>     - Attention score matrix($QK^T$): $B \cdot H \cdot N^2$
>   - Memory-Efficient Attention
>     - $B \cdot N \cdot D$
> - KV Cache:
>   - $2 \cdot B \cdot N \cdot D$

---

Blockwise Parallel Transformer (BPT) 本身也是为了解决 Transformer 模型处理长序列时的内存瓶颈而提出的。

### 核心洞察 (Core Insight)

传统 Transformer 模型在计算时，内存消耗主要有两个大头：

1. **自注意力层 (Self-Attention)**：计算注意力分数时会产生一个与序列长度的平方 ($s^2$) 成正比的中间矩阵。虽然像 FlashAttention 这样的技术通过分块计算（tiling）避免了实例化这个巨大矩阵，从而将显存占用降低到与序列长度 $s$ 线性相关，但这引出了第二个问题。
2. **前馈网络层 (Feed-Forward Network, FFN)**：在注意力计算之后，数据会流经一个 FFN 层。这个 FFN 层的中间激活值（activations）大小通常是输入大小的数倍（例如4倍或8倍），其内存占用与序列长度 $s$ 和隐藏层维度 $h$ 的乘积 ($b \times s \times h$) 成正比。当序列 $s$ 变得极长时，这个激活值会占据海量的内存，成为新的瓶颈。

BPT 的**核心洞察**是：既然自注意力层可以被分块计算以节省内存，那么**前馈网络层（FFN）同样也可以采用分块的方式进行计算**。通过将 FFN 的计算也分解成一小块一小块地处理，就可以避免在内存中同时保留整个序列的巨大中间激活值，从而将峰值内存占用再次大幅降低。

### BPT 的方法与原理

BPT 的方法是将 Transformer 的整个计算层都重构成**“分块并行”**的模式。

1. **分块注意力 (Blockwise Attention)**：
    BPT 沿用了内存高效注意力（如 FlashAttention）的方法。它将输入序列 Q, K, V 切分成块，然后以迭代的方式计算注意力输出，这个过程避免了生成完整的 $s \times s$ 注意力矩阵，将注意力层的激活内存从 $O(s^2)$ 降低到 $O(s)$。

2. **分块前馈网络 (Blockwise Feed-Forward)**：
    这是 BPT 的关键创新。一个标准的前馈网络包含两个线性变换和一个非线性激活函数（如 ReLU 或 GeLU），可以表示为 $FFN(x) = ReLU(xW_1 + b_1)W_2 + b_2$。
    - 在标准计算中，输入 $x$ (维度为 $s \times h$) 首先经过第一个线性层 $W_1$ 变成一个巨大的中间激活值 (维度为 $s \times 4h$)。当 $s$ 很大时，这个激活值会耗尽内存。
    - BPT 的做法是将输入 $x$ 沿着序列维度 $s$ 切分成多个小块。然后，让这些小块**逐一**通过 FFN 网络。
    - 对于每一个小块，它会独立完成两个线性变换和激活函数的全过程，得到该块的最终输出。由于一次只处理一小块数据，FFN 产生的中间激活值大小就从 $O(s \cdot h)$ 降低到 $O(c \cdot h)$，其中 $c$ 是远小于 $s$ 的块大小 (block size)。
    - 所有块的输出最终会被拼接起来，形成与标准计算完全等价的最终结果。

3. **整合与效果**：
    BPT 将分块注意力和分块 FFN 结合起来，使得 Transformer 的每一层计算都可以在不保留整个序列激活的情况下完成。这带来的直接好处是，整个 Transformer 层的峰值激活内存占用被显著降低了。根据论文中的分析，BPT 可以将 Transformer 层激活值的峰值内存从 $8bsh$ 字节降低到 $2bsh$ 字节（$b$ 为批大小，s 为序列长度，h 为隐藏维度）。

### 总结

总的来说，BPT 的原理可以概括为：

- **洞察**：意识到 FFN 层的激活值是继注意力矩阵之后处理长序列的又一内存瓶颈。
- **方法**：将分块计算的思想从自注意力层扩展到前馈网络层，将输入序列切片后逐块送入 FFN 进行计算。
- **优势**：这种方法在不改变模型数学计算结果（即无近似）的前提下，极大地降低了 Transformer 层的峰值内存占用，使得在单台设备上能够处理更长的序列。

正是因为 BPT 提供了这种对整个 Transformer 层进行分块计算的能力，"Ring Attention" 才能在此基础上进一步将这些独立的“块”分配到不同的设备上，并通过环形通信机制将它们连接起来，最终实现上下文长度随设备数量线性扩展的宏伟目标。可以说，**BPT 是实现 Ring Attention 的单设备计算基础**。

## Challenges

- The primary challenge is the **immense memory demand** of the self-attention mechanism, which scales quadratically with the input sequence length, making it difficult to process long sequences.
- There is a significant gap between the memory required for very long sequences (e.g., over 1000GB for 100 million tokens) and the **hardware limitations** of modern GPUs and TPUs, which typically have less than 100GB of high-bandwidth memory (HBM).
- Even with memory-efficient techniques, storing the **layer activations** (the output of each Transformer layer) becomes a major bottleneck for the next layer, as the full output is required for subsequent self-attention calculations.

## Insights

分布式注意力计算的根本原因是 **permutation invariance property**

- **计算的本质是累加**：对于一个查询块 Q2 来说，它的最终注意力输出，是它与所有合法的键值块（K1,V1, K2,V2 等）分别计算结果的加权总和。
- **加法顺序不影响结果**：就像 A + B 和 B + A 的结果一样，Q2 先与 K1,V1 计算，再累加与 K2,V2 计算的结果，同先与 K2,V2 计算，再累加与 K1,V1 计算的结果，在数学上是完全等价的。
- Ring Attention 设计了一种高效的环形通信，来利用这个数学上的“置换不变性”。

以下面这个代码做具体说明：

> 以最简单的注意力计算做说明，简单感受一下，这其中最大的问题就是：key 在不完整时，怎么计算对应的 `softmax` 的值？ -- 应该涉及到 flashattention 的机制了

```python
def scaled_dot_product_attention_simple(
    query: mx.array,
    key: mx.array,
    value: mx.array,
    scale: float | None = None,
    mask: mx.array | str | None = None,
) -> mx.array:
    # query, key, value: N x H x L x D
    attn_scores = query @ key.swapaxes(-2, -1)  # N x H x L x L
    if scale is not None:
        attn_scores *= scale
    else:
        attn_scores /= key.shape[-1] ** 0.5

    if mask is not None:
        if isinstance(mask, str):
            assert mask == "causal", "mask must be 'causal' or a tensor"
            mask = create_causal_mask(query.shape[2])
            mask = mx.where(mask, 0.0, -mx.inf)

        attn_scores += mask

    # N x H x L x L
    # softmax 只对最后一个维度进行归一化
    # attn_scores[i, j, k, :] 表示
    # 第 i 个样本, 第 j 个注意力头, 第 k 个查询位置, 对所有键位置的注意力分数
    # attn_weights[i, j, k, l] 表示
    # 第 k 个查询位置对第 l 个键位置的注意力权重, 所有权重构成一个概率分布
    attn_weights = mx.softmax(attn_scores, axis=-1)
    # N x H x L x D
    return attn_weights @ value
```

计算的本质是累加在代码中的最直接体现是 `scaled_dot_product_attention_simple` 函数的最后一行：

```python
# N x H x L x L     N x H x L x D
#  attn_weights   @    value
return attn_weights @ value
```

让我们把这个矩阵乘法 (`@`) 拆解开来看，特别是对于某一个查询（Query），比如序列中的第 `i` 个词（token）。

- `attn_weights` 是一个 `L x L` 的权重矩阵（我们暂时忽略 N 和 H）。`attn_weights` 的第 `i` 行，`attn_weights[i, :]`，包含了第 `i` 个查询词对于序列中**所有** `L` 个词的注意力权重。例如 `[0.1, 0.6, 0.1, ...]`，所有这些权重加起来等于 1。
- `value` 是一个 `L x D` 的矩阵。它的每一行 `value[j, :]` 代表了序列中第 `j` 个词的 Value 向量。

当计算第 `i` 个词的最终输出向量 `output[i]` 时，矩阵乘法的定义告诉我们，它实际上在执行一个**加权求和（Weighted Sum）**，也就是**累加**：

```python
output[i] = attn_weights[i, 0] * value[0] +
   attn_weights[i, 1] * value[1] +
   attn_weights[i, 2] * value[2] +
   ...
   attn_weights[i, L-1] * value[L-1]

```

第 `i` 个词的输出，是通过将其注意力权重作为“系数”，对序列中**所有词**的 Value 向量进行加权求和得到的。

**与 Q2, K1, V1, K2, V2 的关系:**

`Q2` 就是 `query` 矩阵的第2行，`K1, V1, K2, V2` 分别是 `key` 和 `value` 矩阵的第1、1、2、2行。代码通过 `query @ key.swapaxes(-2, -1)` 一次性计算出了 `Q2` 对 `K1`, `K2` 等所有 Key 的注意力分数，并通过 Softmax 转换成权重，最后在 `attn_weights @ value` 这一步，将 `V1`, `V2` 等所有 Value 向量根据权重累加起来，得到 `Q2` 的最终输出。

## Approaches

考虑单层 attention:

- 设备 D1, D2, D3
- 把序列拆分为 S1, S2, S3
- 每个设备持有 Q_i
- 每轮每个设备只计算 (K_j, V_j)

![pasted-image-20250817194437](/images/pasted-image-20250817194437.png)

- **As we compute attention, each host sends key-value blocks to the next host while receives key-value blocks from the preceding host.**

### Ascii-illustrated Example

简单地理解一下 Ring Attention 的运行过程示例

- **Time t=0: Initialization**

在这一步，长序列被切分并分配给每个设备。每个设备根据自己的数据块计算出初始的 Q, K, V 块。

```ascii
    +-------------------------+
          |        Device 1         |
          |-------------------------|
          | My Q: Q1 (fixed)        |
          | Current KV: (K1, V1)    |
          +-------------------------+
                   /            \
                  /              \
                 /                \
+-------------------------+   +-------------------------+
|        Device 2         |   |        Device 3         |
|-------------------------|   |-------------------------|
| My Q: Q2 (fixed)        |   | My Q: Q3 (fixed)        |
| Current KV: (K2, V2)    |   | Current KV: (K3, V3)    |
+-------------------------+   +-------------------------+
```

- **Time t=1: First Computation & Rotation**

每个设备使用自己的 Q 和当前持有的 KV 进行计算。与此同时，它们将自己用完的 KV 块发送给下一个设备。

```ascii
    +--------------------------------------+
          |               Device 1               |
          |--------------------------------------|
          | My Q: Q1                             |
          | Current KV: (K1, V1)                 |
          | Action: Compute(Q1, K1, V1)          |
          | Send -> (K1,V1) to D2                |
          | Recv <- (K3,V3) from D3              |
          +--------------------------------------+
                   /                    ^      
                  /                      \      
                 /                        \      
                /                          \      
               /                            \      
              v                              \
+--------------------------------------+   +--------------------------------------+
|               Device 2               |   |               Device 3               |
|--------------------------------------|   |--------------------------------------|
| My Q: Q2                             |   | My Q: Q3                             |
| Current KV: (K2, V2)                 |   | Current KV: (K3, V3)                 |
| Action: Compute(Q2, K2, V2)          |   | Action: Compute(Q3, K3, V3)          |
| Send -> (K2,V2) to D3                |   | Send -> (K3,V3) to D1                |
| Recv <- (K1,V1) from D1              |   | Recv <- (K2,V2) from D2              |
+--------------------------------------+   +--------------------------------------+
```

- **Time t=1: First Computation & Rotation**

```ascii
    +--------------------------------------+
          |               Device 1               |
          |--------------------------------------|
          | My Q: Q1                             |
          | Current KV: (K3, V3) <-- from D3     |
          | Action: Compute(Q1, K3, V3)          |
          | Send -> (K3,V3) to D2                |
          | Recv <- (K2,V2) from D3              |
          +--------------------------------------+
                   /                     ^      
                  /                       \      
                 /                         \      
                /                           \      
               /                             \      
              v                               \
+--------------------------------------+   +--------------------------------------+
|               Device 2               |   |               Device 3               |
|--------------------------------------|   |--------------------------------------|
| My Q: Q2                             |   | My Q: Q3                             |
| Current KV: (K1, V1) <-- from D1     |   | Current KV: (K2, V2) <-- from D2     |
| Action: Compute(Q2, K1, V1)          |   | Action: Compute(Q3, K2, V2)          |
| Send -> (K1,V1) to D3                |   | Send -> (K2,V2) to D1                |
| Recv <- (K3,V3) from D1              |   | Recv <- (K1,V1) from D2              |
+--------------------------------------+   +--------------------------------------+
```

- **Time t=3: Final Computation**

```ascii
    +--------------------------------------+
          |               Device 1               |
          |--------------------------------------|
          | My Q: Q1                             |
          | Current KV: (K2, V2) <-- from D3     |
          | Action: Compute(Q1, K2, V2)          |
          | (Communication can stop now)         |
          +--------------------------------------+
                   /                           \
                  /                             \
                 /                               \
+--------------------------------------+   +--------------------------------------+
|               Device 2               |   |               Device 3               |
|--------------------------------------|   |--------------------------------------|
| My Q: Q2                             |   | My Q: Q3                             |
| Current KV: (K3, V3) <-- from D1     |   | Current KV: (K1, V1) <-- from D2     |
| Action: Compute(Q2, K3, V3)          |   | Action: Compute(Q3, K1, V1)          |
| (Communication can stop now)         |   | (Communication can stop now)         |
+--------------------------------------+   +--------------------------------------+
```

Devices accumulate partial outputs across iterations using the *lazy softmax* strategy introduced by <<Self-attention does not need o(n2) memory>>.

> [!NOTE]
>
> 简单模拟之后可以发现 Ring Attention 没有考虑因果掩码
>
> - Q1 并不需要对 K1, V1, K2, V2 进行计算
> - Q2 并不需要对 K1, V1 进行计算

[Striped Attention Faster Ring Attention for Causal Transformers](posts/papers/llm/striped-attention-faster-ring-attention-for-causal-transformers.md) 在这个观察上进行了改进。

## Evaluation

## Thoughts

### When Reading

完全看懂这篇文章需要的前置知识：

- Hao Liu and Pieter Abbeel. Blockwise parallel transformer for large context models. Advances in neural information processing systems, 2023.
- FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness

## Related Works

- [Striped Attention Faster Ring Attention for Causal Transformers](posts/papers/llm/striped-attention-faster-ring-attention-for-causal-transformers.md)
- [KV-Runahead Scalable Causal LLM Inference by Parallel Key-Value Cache Generation](posts/papers/llm/kv-runahead-scalable-causal-llm-inference-by-parallel-key-value-cache-generation.md)
