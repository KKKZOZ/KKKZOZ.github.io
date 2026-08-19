---
title: "[Sequence Modeling 03] Mamba"
series:
  - Sequence Modeling
date: 2026-03-16
showtoc: true
weight: 10
---

要理解 Mamba，我们需要将思维从 Transformer 的“全局注意力”切回到 RNN 的“时序状态机”，但这次，我们要解决 Vanilla RNN 和 LSTM 共同的工程死穴：**训练阶段无法并行**。

Mamba 的核心目标非常明确：**既要拥有 Transformer 级别的高效并行训练能力，又要保持 RNN $O(1)$ 的推理复杂度和无限上下文潜力。**

它主要通过整合**状态空间模型（State Space Model, SSM）**、**选择性机制（Selective Mechanism）**和**底层硬件优化（Hardware-aware Algorithm）**来实现这一目标。

以下从数学和工程的视角详细拆解 Mamba 架构。

---

## 数学基础：从连续到离散的状态空间模型 (SSM)

Mamba 的前身是 S4 等状态空间模型。SSM 的思想源于控制论，它假设系统的状态演化可以用一组连续的微分方程来描述：

$$h'(t) = A h(t) + B x(t)$$

$$y(t) = C h(t)$$

* $x(t)$ 是输入。
* $h(t)$ 是隐藏状态（类比 RNN 的 $h_t$ 或 LSTM 的 $c_t$）。
* $A$ 是状态转移矩阵，描述系统本身的演化规律。
* $B$ 和 $C$ 是输入输出投影矩阵。

为了在深度学习中使用（处理离散的 token），必须对连续系统进行**离散化（Discretization）**。通过引入一个步长参数 $\Delta$（Delta），使用零阶保持（Zero-Order Hold）等数学技巧，上述方程可以转换为离散的递归形式：

$$h_t = \bar{A} h_{t-1} + \bar{B} x_t$$

$$y_t = C h_t$$

其中 $\bar{A} = \exp(\Delta A)$。
你可以看到，离散化后的公式与 Vanilla RNN 非常相似：当前状态 $h_t$ 是前一个状态 $h_{t-1}$ 的线性变换加上当前输入 $x_t$ 的线性变换。因为它是**纯线性**的（没有 LSTM 那样的 $\tanh$ 或 Sigmoid 阻断），这为后续的数学化简和并行计算奠定了基础。

### 为什么需要离散化

状态空间模型 (SSM) 最初用于控制论，描述的是**连续时间**内的动态系统（例如电路的电压变化、流体的速度）。连续系统的数学表达是常微分方程 (ODE)：

$$h'(t) = A h(t) + B x(t)$$

这里 $t$ 是一个连续的实数。

但在自然语言处理 (NLP) 中，输入数据是文本 Token。文本在时间维度上是**高度离散**的（第 1 个 Token，第 2 个 Token……不存在第 1.5 个 Token）。因此，我们无法直接将离散的文本序列输入到连续的微分方程中。

我们需要一种数学映射，把描述连续曲线演化的系统，转换为一步一步跳跃迭代的系统。这就是“离散化”。

为了进行离散化，我们需要定义两个相邻 Token 之间的“虚拟时间间隔”，这就是**步长 $\Delta$**。

在连续系统中，我们要计算 $t$ 时刻到 $t+\Delta$ 时刻的状态变化，本质上是对微分方程求积分。为了简化积分过程，工程上通常引入**零阶保持 (ZOH)** 假设：

* **ZOH 假设**：假设在时间区间 $[t, t+\Delta)$ 内，输入信号 $x(t)$ 保持不变（恒定为当前的 Token 向量）。

基于这个假设，解上述线性常微分方程的精确解析解为：

$$h(t+\Delta) = \exp(\Delta A) h(t) + \left( \int_{0}^{\Delta} \exp(\tau A) d\tau \right) B x(t)$$

我们将连续时间点映射到离散的步数上（令 $t \to t-1$, $t+\Delta \to t$），并定义：

* $\bar{A} = \exp(\Delta A)$  *(这是矩阵指数)*
* $\bar{B} = \left( \int_{0}^{\Delta} \exp(\tau A) d\tau \right) B = (\bar{A} - I)A^{-1}B$

这样，复杂的连续积分就被转换成了极其简单的离散代数递推公式：

$$h_t = \bar{A} h_{t-1} + \bar{B} x_t$$

**$\Delta$ 的工程意义**：在 Mamba 中，$\Delta$ 是随输入动态生成的。如果当前 Token 是无用信息（比如标点），网络会输出极小的 $\Delta$，使得 $\bar{A} = \exp(\approx 0) \approx I$（单位矩阵），此时 $h_t \approx h_{t-1}$，系统直接略过当前输入，维持原有记忆。

### 为什么“纯线性”能实现并行计算？

Vanilla RNN 和离散化后的 SSM 在公式上非常像：

* **RNN**: $h_t = \tanh(W_{hh} h_{t-1} + W_{xh} x_t)$
* **SSM**: $h_t = \bar{A} h_{t-1} + \bar{B} x_t$

RNN 无法并行的罪魁祸首就是那个非线性激活函数 $\tanh$。因为 $\tanh$ 的存在，你无法将公式展开。要算 $h_3$，必须先算完 $h_2$，因为 $h_3 = \tanh(\dots \tanh(\dots) \dots)$，这构成了**严格的时序数据依赖**。

而 SSM 的离散形式是**纯线性**的。纯线性的最大优势在于它满足**结合律 (Associativity)**。我们可以通过代数展开来看：

假设我们要直接计算 $h_3$（假设初始状态 $h_0 = 0$）：

* $h_1 = \bar{B} x_1$
* $h_2 = \bar{A} h_1 + \bar{B} x_2 = \bar{A}(\bar{B} x_1) + \bar{B} x_2$
* $h_3 = \bar{A} h_2 + \bar{B} x_3 = \bar{A}(\bar{A}\bar{B} x_1 + \bar{B} x_2) + \bar{B} x_3$
* **展开结果**:  $h_3 = \bar{A}^2 \bar{B} x_1 + \bar{A} \bar{B} x_2 + \bar{B} x_3$

你看出了什么？
**计算 $h_3$ 不再依赖于 $h_1$ 和 $h_2$ 的中间计算结果了！**

只要我们在 GPU 内存中提前算好 $\bar{A}$ 的幂次（即 $\bar{A}, \bar{A}^2, \bar{A}^3 \dots$），我们就可以把序列中所有的 $x_t$ 与对应的转换矩阵相乘，然后一次性求和。

在实际的硬件底层（CUDA 层面），这种利用结合律将串行累加转化为树状并行计算的算法被称为 **并行前缀和 (Parallel Prefix Sum)** 或 **并行扫描 (Parallel Scan)**。

## Mamba 的核心创新：选择性机制 (Selective SSM)

传统的 SSM（如 S4）有一个致命缺陷：它的矩阵 $A, B, C$ 是**静态的（Linear Time-Invariant, LTI）**。这意味着系统对待所有的输入 token（不管它是关键的动词还是无用的标点符号）都在使用一套固定的规则进行特征提取。它缺乏 LSTM 中“门（Gate）”那种根据当前输入动态决定“记住什么、遗忘什么”的能力。

Mamba 通过引入选择性机制（Selective Mechanism）打破了 LTI 假设

它强制让 $\Delta$、$B$ 和 $C$ 成为当前输入 $x_t$ 的函数：

$$\Delta_t = \text{Linear}(x_t)$$

$$B_t = \text{Linear}(x_t)$$

$$C_t = \text{Linear}(x_t)$$

这意味着对于序列中的每一个 token：

* **$\Delta_t$（步长）**：类似于遗忘门。如果当前输入是无用信息，网络可以输出一个很小的 $\Delta_t$，使得 $\bar{A} \approx I$（保留原状态），从而忽略当前输入；如果遇到关键信息，则输出较大的 $\Delta_t$ 以更新状态。
* **$B_t$ 和 $C_t$**：动态决定如何将当前输入写入隐藏状态，以及如何从隐藏状态中读取输出。

通过这种方式，Mamba 具备了基于内容进行推理（Content-based Reasoning）的能力，能够像 LSTM 一样过滤信息，解决了传统 SSM 难以处理离散语言信息（如精准复制、忽略填充词）的问题。

## 工程魔法：硬件感知与并行扫描 (Parallel Scan)

既然 Mamba 让 $B$ 和 $C$ 随时间变化，它就退化成了一个普通的时变 RNN。由于 $h_t$ 依赖于 $h_{t-1}$，这看似又回到了必须用 `for` 循环按顺序计算的死胡同。

Mamba 的工程神来之笔在于：**利用并行前缀和（Parallel Associative Scan）结合 GPU 内存层级优化，强行把线性的 RNN 依赖并行化。**

因为 $h_t = \bar{A}_t h_{t-1} + \bar{B}_t x_t$ 这个操作满足**结合律（Associativity）**，这使得我们可以像计算并行前缀和（Prefix Sum）一样，通过二叉树状的规约算法在 GPU 的多个线程中同时计算出所有的 $h_t$。

此外，Mamba 的作者编写了定制的 CUDA Kernel：

1. **SRAM 驻留：** 避免了在极其缓慢的 GPU HBM（高带宽内存）和计算单元之间来回搬运庞大的隐藏状态。
2. 将离散化（计算 $\bar{A}_t, \bar{B}_t$）和并行扫描融合（Kernel Fusion）在 GPU 极速但容量极小的 SRAM 中一气呵成完成。
3. 最终只将输出 $y_t$ 写回 HBM。

这种设计使得 Mamba 在训练阶段无需显式的 `for` 循环，速度与 Transformer 相当；而在推理阶段，又可以切换回标准的 RNN 步进模式，无需缓存历史 token。

### 并行前缀和

假设我们有一个数组 $X = [x_0, x_1, x_2, x_3, x_4, x_5, x_6, x_7]$，我们需要计算它的前缀和数组 $Y$，即 $y_t = \sum_{i=0}^{t} x_i$。

输出应该是：
$Y = [x_0, x_0+x_1, x_0+x_1+x_2, \dots, x_0+\dots+x_7]$

**串行计算（Vanilla RNN 的方式）：**
必须按顺序计算：$y_t = y_{t-1} + x_t$。计算 $y_7$ 必须等待 $y_6$ 完成。对于长度为 $N$ 的序列，这需要 $O(N)$ 步（时间步）。

**并行计算（利用结合律）：**
加法满足**结合律**：$(a + b) + c = a + (b + c)$。这意味着我们可以改变计算的优先级，将计算任务分配给 GPU 的多个线程并行执行。

并行前缀和通常通过构建一个**二叉树（Binary Tree）**的规约（Reduction）过程来实现：

1. **第一层（并发执行）：**
线程 1 算 $x_0+x_1$，线程 2 算 $x_2+x_3$，线程 3 算 $x_4+x_5$，线程 4 算 $x_6+x_7$。
2. **第二层（并发执行）：**
线程 1 算 $(x_0+x_1) + (x_2+x_3)$，线程 2 算 $(x_4+x_5) + (x_6+x_7)$。
3. **第三层：**
线程 1 算所有结果的总和。

通过这种树状的合并，长度为 $N$ 的序列，原本需要 $N$ 步，现在只需要 $\log_2(N)$ 步。这就是并行化的本质：**用多余的计算单元（GPU 核心）换取时间复杂度的指数级下降**。

### Mamba 的公式如何套用并行前缀和

你可能会问：前缀和算的是“加法”，但 Mamba 的公式 $h_t = \bar{A}_t h_{t-1} + \bar{B}_t x_t$ 既有乘法又有加法，它怎么算前缀和？

这就需要进行**代数抽象**。前缀和算法不仅适用于加法，它适用于**任何满足结合律的二元运算符**。

我们将 Mamba 的状态更新公式进行变量替换。令 $\tilde{B}_t = \bar{B}_t x_t$，公式变为纯递推形式：

$$h_t = \bar{A}_t h_{t-1} + \tilde{B}_t$$

我们定义一个新的操作数元组 $S_t = (\bar{A}_t, \tilde{B}_t)$。
接下来，我们定义一个自定义的二元运算符 $\otimes$，用于连接相邻的两个元组 $S_i$ 和 $S_j$：

$$S_i \otimes S_j = (A_i, B_i) \otimes (A_j, B_j) = (A_j A_i, A_j B_i + B_j)$$

**为什么这样定义？**
我们来看看连续更新两步会发生什么：

$$h_1 = A_1 h_0 + B_1$$

$$h_2 = A_2 h_1 + B_2 = A_2(A_1 h_0 + B_1) + B_2 = (A_2 A_1) h_0 + (A_2 B_1 + B_2)$$

你会发现，状态从 $h_0$ 转移到 $h_2$ 的等效转移矩阵，恰好就是 $(A_1, B_1) \otimes (A_2, B_2)$ 的结果。

**验证结合律：**
纯线性结构保证了这个算子 $\otimes$ 严格满足结合律：

$$(S_1 \otimes S_2) \otimes S_3 = S_1 \otimes (S_2 \otimes S_3)$$

既然算子 $\otimes$ 满足结合律，我们就可以完全抛弃 $O(N)$ 的串行 `for` 循环，直接把包含矩阵乘法和加法的算子 $\otimes$ 扔进刚才的二叉树并行前缀和算法中。GPU 的各个线程块会并发地计算不同时间段的等效转移矩阵 $(A_{i \to j}, B_{i \to j})$，最终在 $O(\log N)$ 的时间步内解算出所有 $t$ 时刻的隐藏状态 $h_t$。

## 代码与工作流解析

以下是 Mamba 核心处理模块的伪代码，展示了参数动态生成和离散化的过程（省略了底层的定制化 CUDA Scan 实现，用概念上的接口代替）。

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class MambaBlock(nn.Module):
    def __init__(self, d_model: int, d_state: int, d_conv: int):
        super().__init__()
        self.d_model = d_model
        self.d_state = d_state
        
        # 1D Convolution applied to input before SSM mapping
        # This helps capture local token context (like an n-gram)
        self.conv1d = nn.Conv1d(
            in_channels=d_model, 
            out_channels=d_model, 
            kernel_size=d_conv, 
            padding=d_conv - 1,
            groups=d_model
        )
        
        # Linear projections for data-dependent parameters (The Selective part)
        # B and C depend on the input, mapping from d_model to d_state
        self.x_proj = nn.Linear(d_model, d_state * 2 + 1)
        
        # Projection for Delta (step size), which also depends on input
        self.dt_proj = nn.Linear(1, d_model)
        
        # The A matrix is an internal learned parameter, initialized specifically
        # Shape: (d_model, d_state)
        A = torch.arange(1, d_state + 1).float().unsqueeze(0).repeat(d_model, 1)
        self.A_log = nn.Parameter(torch.log(A)) 
        
        # D parameter for a residual skip connection
        self.D = nn.Parameter(torch.ones(d_model))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x shape: (batch_size, seq_len, d_model)
        batch_size, seq_len, _ = x.shape
        
        # Step 1: Local sequence convolution
        # Transpose for PyTorch Conv1d format: (batch, channels, length)
        x_conv = x.transpose(1, 2)
        x_conv = self.conv1d(x_conv)[:, :, :seq_len] 
        x_conv = x_conv.transpose(1, 2)
        x_conv = F.silu(x_conv) # Activation
        
        # Step 2: Project input to Selective Parameters (B, C, and raw delta)
        # x_proj outputs (batch, seq_len, 2 * d_state + 1)
        x_proj_out = self.x_proj(x_conv)
        
        # Split into delta, B, and C
        delta_raw, B, C = torch.split(
            x_proj_out, 
            [1, self.d_state, self.d_state], 
            dim=-1
        )
        
        # Process delta: apply softplus to make it positive
        delta = F.softplus(self.dt_proj(delta_raw)) # (batch, seq_len, d_model)
        
        # Step 3: Discretization (Zero-order hold approximations)
        A = -torch.exp(self.A_log) # Shape: (d_model, d_state)
        
        # delta * A
        delta_A = torch.einsum('b l d, d n -> b l d n', delta, A)
        # bar_A = exp(delta * A)
        bar_A = torch.exp(delta_A) 
        
        # bar_B = delta * B
        bar_B = torch.einsum('b l d, b l n -> b l d n', delta, B)
        
        # Step 4: The Core SSM computation (Selective Scan)
        # In actual implementation, this part is replaced by a highly optimized 
        # custom CUDA kernel to perform parallel associative scan in SRAM.
        # Here we show the conceptual unrolled loop for clarity.
        
        y = self._conceptual_selective_scan(x_conv, bar_A, bar_B, C)
        
        # Step 5: Add skip connection (D)
        output = y + x * self.D
        
        return output
        
    def _conceptual_selective_scan(self, x, bar_A, bar_B, C):
        """
        Conceptual implementation of the sequential dependency.
        In reality, this is computed in parallel $O(log N)$ using prefix sums.
        """
        batch, seq_len, d_model = x.shape
        d_state = self.d_state
        
        h_t = torch.zeros(batch, d_model, d_state, device=x.device)
        outputs = []
        
        for t in range(seq_len):
            x_t = x[:, t, :] # (batch, d_model)
            
            # Update hidden state: h_t = bar_A * h_{t-1} + bar_B * x_t
            # This is linear!
            h_t = bar_A[:, t, :, :] * h_t + bar_B[:, t, :, :] * x_t.unsqueeze(-1)
            
            # Compute output: y_t = C * h_t
            y_t = torch.einsum('b d n, b n -> b d', h_t, C[:, t, :])
            outputs.append(y_t)
            
        return torch.stack(outputs, dim=1)

```

## Mamba vs RNN

事实上，**在推理阶段（Inference），Mamba 的本质就是一个 RNN。** 它们都是处理时序数据的状态机，都具有 $O(1)$ 的推理复杂度和无限长度的理论上下文。

但如果看它的网络拓扑结构和数学表达，Mamba 和传统的 RNN/LSTM 在架构上有**三个根本性的差异**。正是这三个差异，不仅让 Mamba 可以使用并行前缀和，也彻底改变了它的特征提取能力。

### 核心差异一：非线性激活函数的位置（纯线性 vs 非线性递推）

这是两者在架构上最底层的分歧。

* **RNN/LSTM：非线性发生在“循环内部”（Inside the Recurrence）**

在 RNN 中，每一个时间步的递推公式是：$h_t = \tanh(W_{hh} h_{t-1} + W_{xh} x_t)$。
注意这个 $\tanh$。隐藏状态 $h_{t-1}$ 在传递给 $h_t$ 时，**必须穿过一个非线性激活函数**。这种设计虽然增加了单步表达能力，但导致了严重的信号衰减（梯度消失），并且彻底破坏了代数上的结合律。

* **Mamba：非线性发生在“循环外部”（Outside the Recurrence）**

Mamba 的递推公式是：$h_t = \bar{A}_t h_{t-1} + \bar{B}_t x_t$。
这里的递推是**严格的纯线性**操作，没有 $\tanh$，没有 Sigmoid。$h_{t-1}$ 到 $h_t$ 是一条毫无阻挡的线性高速公路。

> [!question] Mamba 的非线性表达能力从哪里来？
> 答案是：在进入循环**之前**。
>
> Mamba 使用非线性的全连接层（Linear + Softplus/SiLU）根据输入 $x_t$ 动态生成了 $\bar{A}_t$ 和 $\bar{B}_t$。
> 简而言之：RNN 是一边循环一边做非线性变换；Mamba 是先用非线性网络算好当前步的转移矩阵，然后在循环时只做最简单的线性乘加。

### 核心差异二：隐藏状态的维度映射（单通道压缩 vs 多通道展开）

这决定了模型的“记忆容量”和信息瓶颈。

* **RNN/LSTM：低维度的全局状态**

假设输入 $x_t$ 的特征维度是 $D$（即 `d_model`，例如 1024）。RNN 通常维护一个维度也为 $D$ 的隐藏状态 $h_t$。
所有的 $D$ 个特征通道的数据，在进行矩阵乘法 $W_{hh} h_{t-1}$ 时是**完全混合**在一起的。这就像把所有的信息压缩到一个固定大小的向量里，很容易发生“信息覆盖”。

* **Mamba：高维度的结构化状态空间（Structured State Space）**

Mamba 引入了状态维度（`d_state`，通常设为 16）。
对于输入 $x_t \in \mathbb{R}^D$，Mamba 并不是把它压缩成一个 $D$ 维的 $h_t$。相反，Mamba 为输入特征的**每一个通道**，都分配了一个独立的 $N$ 维（`d_state`）记忆空间。
因此，Mamba 实际的隐藏状态 $h_t$ 的形状是 $D \times N$（即 `[d_model, d_state]`，例如 $1024 \times 16 = 16384$）。

并且，Mamba 的状态转移矩阵 $\bar{A}$ 是对角矩阵（Diagonal Matrix）。这意味着在递推时，特征的各个通道之间是**独立演化的，互不干扰**。通道间的交互交由循环外部的其它线性层来完成。这种极高的隐藏维度赋予了 Mamba 远超传统 RNN 的记忆容量。

### 核心差异三：转移矩阵的动态性（静态权重 vs 数据依赖）

这是 Mamba 被称为 Selective SSM（选择性状态空间模型）的原因，也是它区别于早期纯线性 RNN 的关键。

* **RNN：静态转移矩阵（Static Transition）**

RNN 的权重矩阵 $W_{hh}$ 在训练完成后就是**固定（Fixed）**的。无论当前输入的 token 是至关重要的名词，还是毫无意义的标点符号，RNN 总是使用同一个 $W_{hh}$ 去乘以前一个状态 $h_{t-1}$。

* **Mamba：动态生成转移矩阵（Data-Dependent Transition）**

Mamba 中的 $\bar{A}_t$ 和 $\bar{B}_t$ 带有下标 $t$。这意味着对于序列中的每一个 token，网络都会**实时计算出一套全新的转移参数**。

```python
# Vanilla RNN (Weights are parameters)
# self.W_hh is an nn.Parameter
h_t = torch.tanh(self.W_hh @ h_prev + self.W_xh @ x_t)

# Mamba (Transition matrices are dynamic outputs of the input)
# delta, B, C are generated dynamically via linear layers from x_t
delta_t = F.softplus(self.proj_delta(x_t))
B_t = self.proj_B(x_t)

# A_bar changes for every single token based on delta_t
A_bar_t = torch.exp(delta_t * A_parameter) 

# The recurrence happens with the dynamic A_bar_t and B_t
h_t = A_bar_t * h_prev + (delta_t * B_t) * x_t 

```

正是这种动态生成 $\bar{A}_t$ 的能力，让 Mamba 拥有了类似于 LSTM 中“遗忘门”的功能：如果 $x_t$ 是无关信息，网络会让生成的 $\Delta_t$ 趋近于 0，使得 $\bar{A}_t = \exp(0) = 1$，从而 $h_t \approx 1 \times h_{t-1}$，完美保留了历史记忆，忽略了当前垃圾信息。

### 总结对比表

| 特性 | Vanilla RNN / LSTM | Mamba |
| --- | --- | --- |
| **循环函数性质** | **非线性**（包含 $\tanh$ 或 Sigmoid） | **严格线性**（纯代数乘加） |
| **硬件并行性** | 无法跨时间步并行 | 可使用 GPU 并行前缀和 |
| **隐藏状态大小** | $O(D)$（通常与输入维度 $D$ 相同） | $O(D \times N)$（大幅度扩容的独立通道状态） |
| **状态转移机制** | 全连接矩阵混合乘法 | 独立通道对角线矩阵相乘 |
| **时序参数动态性** | $W_{hh}$ 训练后全局静态固定 | $\bar{A}_t, \bar{B}_t$ 根据每个输入 token 动态生成 |

综上所述，Mamba 不仅仅是“换了个算法算 RNN”。它是将非线性剥离出循环核心，大幅度扩容了隐藏状态维度，并让系统演化方程直接受输入数据控制的一种全新架构。

## To Read

我们直接深入代码。这段伪代码非常经典，它完美映射了 Mamba 的三大核心工程：**局部特征提取**、**数据依赖的参数生成（Selective 机制）**，以及**高维状态空间的纯线性递推**。

我将按照数据流的执行顺序，逐块（Block by Block）为你拆解。

---

## Block 1: 初始化参数 (`__init__`) —— 搭建架构骨架

这一部分定义了 Mamba Block 内部需要的权重。

```python
# 1. 深度可分离卷积 (Depthwise 1D Conv)
self.conv1d = nn.Conv1d(
    in_channels=d_model, out_channels=d_model, 
    kernel_size=d_conv, padding=d_conv - 1, groups=d_model
)

```

* **工程意义：** 在进入严格的 SSM 线性递推之前，先用一个局部的 1D 卷积对输入进行平滑。`groups=d_model` 表示这是一个**深度可分离卷积（Depthwise Convolution）**，即每个特征通道独立进行卷积，跨通道不混合。这弥补了纯线性 SSM 在捕捉极短期、局部词汇组合（如 n-gram）时的能力不足。

```python
# 2. 选择性参数投影层
self.x_proj = nn.Linear(d_model, d_state * 2 + 1)
self.dt_proj = nn.Linear(1, d_model)

```

* **工程意义：** 这两行就是 Mamba 被称为 "Selective" 的灵魂。
* `x_proj` 负责把输入的 token 向量（维度 $D$）映射为三个动态参数：$\Delta_{raw}$ (1维), $B$ ($N$维), $C$ ($N$维)。加起来刚好是 `d_state * 2 + 1`。
* `dt_proj` 将标量 $\Delta_{raw}$ 投影回 $D$ 维（`d_model`）。这意味着**对于每一个 token 的每一个特征通道，都有一个独立的步长 $\Delta$**。

```python
# 3. 核心状态转移矩阵 A 的初始化
A = torch.arange(1, d_state + 1).float().unsqueeze(0).repeat(d_model, 1)
self.A_log = nn.Parameter(torch.log(A)) 

```

* **工程意义：** $A$ 是 SSM 内部的系统演化矩阵。这里有两个极其重要的数学设计：

1. **对角线结构：** $A$ 的形状是 `(d_model, d_state)`，代表它为每个通道维护一个独立的 $N$ 维向量。在数学上，这等价于一个分块对角矩阵。
2. **特定的初始化与对数存储：** $A$ 被初始化为 $[1, 2, \dots, N]$。根据 HiPPO（High-order Polynomial Projection Operators）理论，这种特定的初始化能让系统最优地记忆历史信息。存储 `log(A)` 是为了在后续计算中强制 $A$ 取负值（$-\exp(\log A)$），在控制论中，**负的特征值保证了系统的稳定性**（历史记忆会平滑衰减，而不是指数爆炸）。

---

## Block 2: 局部卷积与参数生成 (`forward` Step 1 & 2)

```python
# Step 1: 局部卷积
x_conv = self.conv1d(x_conv)[:, :, :seq_len] 
x_conv = F.silu(x_conv)

```

* 这里执行了前面定义的 1D 卷积，并通过 `SiLU` 激活函数。注意切片 `[:seq_len]` 是为了因果卷积（Causal Convolution）的对齐，确保当前 token 看不到未来的 token。

```python
# Step 2: 动态生成 \Delta, B, C
x_proj_out = self.x_proj(x_conv)
delta_raw, B, C = torch.split(x_proj_out, [1, self.d_state, self.d_state], dim=-1)
delta = F.softplus(self.dt_proj(delta_raw)) # (batch, seq_len, d_model)

```

* 将卷积后的特征映射并切分为 $\Delta_{raw}$, $B$, $C$。
* **为什么用 `softplus`？** $\Delta$ 代表连续系统离散化时的“时间步长”。时间步长在物理意义上**必须是正数**。`softplus` ($f(x) = \ln(1 + e^x)$) 是 ReLU 的平滑版本，确保 $\Delta > 0$。

---

## Block 3: 离散化 (`forward` Step 3) —— 从连续到离散的映射

这一步将连续的参数 $A, B$ 结合动态步长 $\Delta$，转换为离散环境下的 $\bar{A}, \bar{B}$。

```python
A = -torch.exp(self.A_log) # 强制 A 为负数，保证系统衰减稳定

```

```python
# 计算 \bar{A} = \exp(\Delta * A)
delta_A = torch.einsum('b l d, d n -> b l d n', delta, A)
bar_A = torch.exp(delta_A) 

```

* **数学映射：** 这里执行的是 $\bar{A} = \exp(\Delta A)$。
* **维度解析 (`einsum`)：**
* `delta`: `(batch, seq_len, d_model)`
* `A`: `(d_model, d_state)`
* 输出 `delta_A` 形状为 `(batch, seq_len, d_model, d_state)`。这印证了前文所述：对于批次中的每个序列、每个时间步、每个特征通道，都有一个独立的 $N$ 维状态转移向量。

```python
# 计算 \bar{B} = \Delta * B
bar_B = torch.einsum('b l d, b l n -> b l d n', delta, B)

```

* **工程化简：** 严格的 ZOH 离散化中，$\bar{B} = (\exp(\Delta A) - I)A^{-1}B$。但在 Mamba（以及很多现代 SSM）的工程实现中，通常采用**欧拉一阶近似（Euler Approximation）**，直接化简为 $\bar{B} = \Delta B$。这不仅省去了矩阵求逆的巨大开销，在实际训练效果上也基本没有损失。

---

## Block 4: 核心 SSM 状态递推 (`_conceptual_selective_scan`)

进入真正的 RNN 形态运行阶段。在 GPU 实际执行时，这里会被替换为 CUDA 的并行前缀和算法。但这个伪代码清晰地展示了底层的代数逻辑。

```python
h_t = torch.zeros(batch, d_model, d_state, device=x.device)

```

* 初始化隐藏状态 $h_0$。注意它的庞大维度：`d_model * d_state`。这就是 Mamba 记忆容量远超常规 RNN 的物理基础。

```python
for t in range(seq_len):
    x_t = x[:, t, :] # 提取当前时间步的 token 特征

    # 核心递推公式：h_t = \bar{A} * h_{t-1} + \bar{B} * x_t
    h_t = bar_A[:, t, :, :] * h_t + bar_B[:, t, :, :] * x_t.unsqueeze(-1)

```

* **最关键的性能细节：这里的 `*` 是逐元素乘法（Hadamard Product），不是矩阵乘法。**
因为 $A$ 被设计为对角矩阵，各个特征通道（`d_model` 维度）之间的演化是**绝对独立**的。这也是为什么它能被轻易地转化为并行扫描——没有任何跨通道的混合计算阻碍并行。

```python
    # 计算输出：y_t = C * h_t
    y_t = torch.einsum('b d n, b n -> b d', h_t, C[:, t, :])
    outputs.append(y_t)

```

* **状态读取：** 当前时间步的输出 $y_t$ 是由内部高维状态 $h_t$ (`d_model, d_state`) 与读取矩阵 $C$ (`d_state`) 投影计算得来的。
* `einsum` 在这里执行了一个类似点积的操作，把庞大的 `d_state` 维度重新压缩求和，输出回到标准的 `d_model` 维度。

---

## 总结

看完了这段代码，你会发现 Mamba 的优雅之处在于：

1. **极简的循环核：** 内部的 `for` 循环里没有任何全连接层，没有任何非线性激活，只有极其简单的标量乘法和加法。
2. **把复杂性前置：** 所有的非线性、通道混合、数据依赖路由，都在进入循环**之前**，由常规的 PyTorch 线性层并行计算完了（即生成 $\bar{A}, \bar{B}, C$ 的过程）。

这就是为什么定制的 CUDA Kernel 可以轻易接管那个简单的 `for` 循环，并在 SRAM 中以闪电般的速度执行并行前缀和，从而实现了“并行训练”与“RNN 式推理”的完美统一。
