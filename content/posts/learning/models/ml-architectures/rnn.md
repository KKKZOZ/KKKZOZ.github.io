---
title: "[Sequence Modeling 01] RNN"
series:
  - Sequence Modeling
date: 2026-03-16
showtoc: true
weight: 10
---

Transformer 是基于全局视角处理序列的，它通过 Self-Attention 一次性让所有 token 互相交互。而 RNN（Recurrent Neural Network，循环神经网络）的本质是基于时间步的顺序迭代。

> 如果把 Transformer 比作同时看到整段句子的“上帝视角”，RNN 则像是按照从左到右的顺序逐字阅读，并在脑海中维护一个不断更新的“记忆向量”。

RNN 的核心结构是一个循环单元。它在处理序列时，并不是一次性输入整个序列（如 `[batch, seq_len, dim]`），而是将序列沿着 seq_len 维度切开，在每一个时间步 $t$ 输入一个 token。

为了保留历史上下文，RNN 引入了隐藏状态 $h_t$。

+ $h_t$ 是一个固定维度的向量，它包含了从时间步 $0$ 到 $t$ 的所有历史信息压缩。
+ 在每一个时间步，RNN 接收两个输入：当前时刻的输入 $x_t$ 和 上一时刻的隐藏状态 $h_{t-1}$。
+ RNN 会使用同一套权重矩阵（参数共享）来融合这两个输入，生成新的 $h_t$。

对于序列中的第 $t$ 个 token，RNN 内部只做两步基本的线性变换和一次非线性激活：

+ 更新隐藏状态：$$h_t = \tanh(W_{xh} x_t + W_{hh} h_{t-1} + b_h)$$这里 $W_{xh}$ 负责投影当前输入，$W_{hh}$ 负责投影历史记忆。两者的结果相加后，通过 $\tanh$ 激活函数将数值压缩到 $[-1, 1]$ 之间，防止在长序列迭代中数值爆炸。

+ 计算当前输出（可选）：$$y_t = W_{hy} h_t + b_y$$如果需要每个时间步都输出（比如序列标注），就用当前的 $h_t$ 映射出 $y_t$。如果只需要句向量（比如文本分类），则直接取最后一个时间步的 $h_n$ 即可。

## 伪代码实现

> 注意，这里的 for 循环是 RNN 架构的灵魂，也是它与 Transformer 最大的区别

```python
import torch
import torch.nn as nn

class VanillaRNN(nn.Module):
    def __init__(self, input_size: int, hidden_size: int, output_size: int):
        super().__init__()
        self.hidden_size = hidden_size
        
        # Linear layer for current input token
        self.W_xh = nn.Linear(input_size, hidden_size)
        
        # Linear layer for previous hidden state (the recurrence mechanism)
        self.W_hh = nn.Linear(hidden_size, hidden_size)
        
        # Linear layer to generate final output from hidden state
        self.W_hy = nn.Linear(hidden_size, output_size)
        
        # Non-linear activation to bound the hidden state values
        self.tanh = nn.Tanh()

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        # x shape: (batch_size, seq_len, input_size)
        batch_size, seq_len, _ = x.size()
        
        # Step 1: Initialize the first hidden state h_0 with zeros
        # Shape: (batch_size, hidden_size)
        h_t = torch.zeros(batch_size, self.hidden_size, device=x.device)
        
        outputs = []
        
        # Step 2: Unroll the sequence over the time dimension
        # THIS is the core of RNN. It forces sequential computation.
        for t in range(seq_len):
            # Extract the token embedding at time step t
            x_t = x[:, t, :]  # Shape: (batch_size, input_size)
            
            # Step 3: Compute new hidden state h_t
            # Combine current input and previous history
            h_t = self.tanh(self.W_xh(x_t) + self.W_hh(h_t))
            
            # Step 4: Compute output for the current time step
            y_t = self.W_hy(h_t)
            outputs.append(y_t)
            
        # Stack all outputs along the sequence dimension
        # final_outputs shape: (batch_size, seq_len, output_size)
        final_outputs = torch.stack(outputs, dim=1)
        
        # Return both the sequence of outputs and the final hidden state
        return final_outputs, h_t
```

## RNN vs Transformer

基于上述工作流，这两种架构在工程特性上有显著差异：

+ **计算图与并行性**
  + **Transformer**：输入序列可以一次性通过矩阵乘法完成 Attention 计算，极其适合 GPU 的高度并行计算。
  + **RNN**：必须等待 $h_{t-1}$ 计算完毕，才能计算 $h_t$。这种时序依赖导致它在训练时无法沿着序列维度并行，这也是它被 Transformer 取代的主要工程原因。
+ **上下文容量**：
  + **Transformer**：Attention 的复杂度是 $O(N^2)$，$N$ 个 token 两两交互，记忆是无损的（不考虑 KV Cache 容量）。
  + **RNN**：无论序列有多长，所有的历史信息都被强制压缩在一个固定维度大小的向量 $h_t$ 中。这会导致信息瓶颈（Information Bottleneck）和长距离依赖下的梯度消失（Vanishing Gradient）。
+ **推理成本**
  + **Transformer**：自回归生成时，随着序列变长，KV Cache 的显存占用线性增长，Attention 的计算量也在增加。
  + **RNN**：由于只维护一个固定大小的 $h_t$ 向量，它的推理复杂度是 $O(1)$，不需要缓存过去的 token，这在长文本生成的推理端是一个巨大优势。
