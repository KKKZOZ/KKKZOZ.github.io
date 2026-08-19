---
title: "[Sequence Modeling 02] LSTM"
series:
  - Sequence Modeling
date: 2026-03-16
showtoc: true
weight: 10
---

## Vanilla RNN 的缺陷：为什么我们需要 LSTM？

在上一篇中我们提到，RNN 的核心公式是 $h_t = \tanh(W_{xh} x_t + W_{hh} h_{t-1} + b_h)$。这种设计在处理长序列时会遇到两个工程上的致命问题：

- 梯度消失与梯度爆炸（Vanishing/Exploding Gradients）
  - 在反向传播计算梯度时，误差需要沿着时间步反向传递。这会导致权重矩阵 $W_{hh}$ 被连乘 $t$ 次。根据线性代数原理，如果 $W_{hh}$ 的最大特征值小于 1，连乘后梯度会呈指数级衰减趋近于 0（梯度消失）；如果大于 1，则会指数级放大（梯度爆炸）。梯度消失意味着网络根本无法学习到长距离的依赖关系。
- 信息覆盖（Information Overwrite）
  - RNN 只有一个隐藏状态 $h_t$。在每一个时间步，新的输入 $x_t$ 都会强制与历史信息 $h_{t-1}$ 混合。没有任何机制能够保护早期非常重要但最近没有出现的信息。这就好比一个容量有限的栈，新数据不断涌入，旧数据很快就被冲刷掉了。

## LSTM 的核心思想：分离状态与引入门控机制

为了解决上述问题，LSTM 对架构进行了大改，其核心创新在于：**将内部状态拆分为两个，并引入了“门（Gates）”来进行精确的信息路由**。

- 细胞状态 $c_t$ (Cell State)： 这是 LSTM 的“主干道”或“长期记忆”。它在整个链条上贯穿运行，只有一些少量的线性交互。这种设计使得梯度可以通过 $c_t$ 顺畅地无损反向传播，直接解决了梯度消失问题。
- 隐藏状态 $h_t$ (Hidden State)： 类似于 Vanilla RNN 的 $h_t$，作为“短期记忆”或当前时间步的输出。
- 门控机制 (Gating Mechanism)： 门本质上是经过 Sigmoid 激活的全连接层。Sigmoid 的输出在 $[0, 1]$ 之间，用于控制信息的保留比例（0 代表完全丢弃，1 代表完全保留）。

## 数学工作流：LSTM 的四个核心步骤

对于第 $t$ 个 token，LSTM 内部执行以下运算。为了方便，我们通常将前一个隐藏状态 $h_{t-1}$ 和当前输入 $x_t$ 拼接在一起计算。

**第一步：遗忘门 (Forget Gate) —— 决定丢弃什么历史信息**

$$f_t = \sigma(W_f \cdot [h_{t-1}, x_t] + b_f)$$

$f_t$ 是一个与 $c_{t-1}$ 维度相同的向量。它的值在 0 到 1 之间，决定了长期记忆 $c_{t-1}$ 中哪些维度的数据应该被清空。

**第二步：输入门 (Input Gate) —— 决定写入什么新信息**
我们需要计算两部分：哪些维度需要更新（$i_t$），以及新的候选内容是什么（$\tilde{c}_t$）。

$$i_t = \sigma(W_i \cdot [h_{t-1}, x_t] + b_i)$$

$$\tilde{c}_t = \tanh(W_c \cdot [h_{t-1}, x_t] + b_c)$$

$i_t$ 充当开关，$\tilde{c}_t$ 是当前时刻提取出的新特征。

**第三步：更新细胞状态 (Update Cell State)**

$$c_t = f_t * c_{t-1} + i_t * \tilde{c}_t$$

> 这里的 $*$ 表示逐元素乘法，即 Hadamard Product

这是 LSTM 最精妙的一步：旧记忆 $c_{t-1}$ 乘以遗忘门（按比例遗忘），然后加上新特征 $\tilde{c}_t$ 乘以输入门（按比例写入）。这是一个纯线性的加法过程，梯度可以完美地沿着加号回传。

**第四步：输出门 (Output Gate) —— 决定输出什么**

$$o_t = \sigma(W_o \cdot [h_{t-1}, x_t] + b_o)$$

$$h_t = o_t * \tanh(c_t)$$

根据当前输入和历史决定输出开关 $o_t$，然后将长期记忆 $c_t$ 通过 $\tanh$ 压缩到 $[-1, 1]$ 之间，乘以输出开关，得到当前时刻的隐藏状态 $h_t$。

---

## 代码与工作流解析

以下是标准 LSTM 单元的伪代码实现，展示了参数是如何定义以及前向传播是如何完成的。

```python
import torch
import torch.nn as nn

class LSTMCell(nn.Module):
    def __init__(self, input_size: int, hidden_size: int):
        super().__init__()
        self.hidden_size = hidden_size
        
        # In practice, PyTorch fuses all 4 linear transformations into one large matrix
        # for performance via parallel matrix multiplication.
        # W shape: (input_size + hidden_size, 4 * hidden_size)
        self.W_ih = nn.Linear(input_size, 4 * hidden_size)
        self.W_hh = nn.Linear(hidden_size, 4 * hidden_size)

    def forward(self, x_t: torch.Tensor, states: tuple[torch.Tensor, torch.Tensor]) -> tuple[torch.Tensor, torch.Tensor]:
        # x_t shape: (batch_size, input_size)
        # states = (h_{t-1}, c_{t-1}), each shape: (batch_size, hidden_size)
        h_prev, c_prev = states
        
        # Step 1: Compute all gate pre-activations simultaneously
        # gates shape: (batch_size, 4 * hidden_size)
        gates = self.W_ih(x_t) + self.W_hh(h_prev)
        
        # Split the fused tensor into 4 chunks for f, i, o, and c_candidate
        # Each chunk shape: (batch_size, hidden_size)
        forget_gate, input_gate, output_gate, cell_candidate = gates.chunk(4, dim=1)
        
        # Step 2: Apply non-linear activations
        f_t = torch.sigmoid(forget_gate)
        i_t = torch.sigmoid(input_gate)
        o_t = torch.sigmoid(output_gate)
        c_tilde = torch.tanh(cell_candidate)
        
        # Step 3: Update Cell State (The core gradient superhighway)
        # Element-wise operations
        c_t = (f_t * c_prev) + (i_t * c_tilde)
        
        # Step 4: Compute new Hidden State
        h_t = o_t * torch.tanh(c_t)
        
        # Return the updated states for the next time step or final output
        return h_t, c_t

class LSTM(nn.Module):
    def __init__(self, input_size: int, hidden_size: int):
        super().__init__()
        self.cell = LSTMCell(input_size, hidden_size)
        
    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, tuple[torch.Tensor, torch.Tensor]]:
        # x shape: (batch_size, seq_len, input_size)
        batch_size, seq_len, _ = x.size()
        
        # Initialize h_0 and c_0 with zeros
        h_t = torch.zeros(batch_size, self.cell.hidden_size, device=x.device)
        c_t = torch.zeros(batch_size, self.cell.hidden_size, device=x.device)
        
        outputs = []
        
        # Unroll over time (Sequential nature remains)
        for t in range(seq_len):
            x_t = x[:, t, :]
            h_t, c_t = self.cell(x_t, (h_t, c_t))
            outputs.append(h_t)
            
        final_outputs = torch.stack(outputs, dim=1)
        return final_outputs, (h_t, c_t)

```

## 总结

LSTM 通过引入复杂的门控机制和**跨越时间步的残差连接（即 $c_t = c_{t-1} + \dots$ 的加法结构）**，极大地缓解了 RNN 的梯度消失问题，使得模型能够捕获更长距离的依赖。但正如代码中 `for t in range(seq_len)` 所示，它的本质仍然是基于马尔可夫链的时序迭代，这意味着它依旧无法像 Transformer 那样在训练阶段实现高度的并行计算。
