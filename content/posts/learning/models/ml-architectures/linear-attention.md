---
title: "[Sequence Modeling 04] Linear Attention"
series:
  - Sequence Modeling
date: 2026-03-16
showtoc: true
weight: 10
---

linear_attention 是把 Mamba2 的 gating 机制 和 DeltaNet 的 delta rule 结合起来形成的新结构

先简单分析一下 线性注意力是什么

## Overview

### 从 Transformer 视角

标准 causal self-attention 的一层，大致是：

$$
Q = XW_Q,\quad K = XW_K,\quad V = XW_V
$$

$$
A = \text{softmax}(QK^\top + \text{mask}),\quad O = AV
$$

对第 $t$ 个 token 来说，本质上是在做：

$$
o_t = \sum_{i \le t} \alpha_{t,i} v_i
$$

> O(n, t) 中的每一行是把 attn_map 中的对应行作为权重，对 value 矩阵的行进行线性组合(加权)

也就是：**当前 token 用 query 去和历史所有 key 打分，再把历史 value 加权求和**。这给了 Transformer 很强的“按内容检索历史”的能力，但代价是训练时通常要处理完整的 token-token 交互矩阵。Mamba2、DeltaNet、Gated DeltaNet 这一类工作，核心目标就是：**尽量保留这种“从历史取信息”的能力，但不要每次都真的显式查看全部历史 token**。

如果用一句工程化的话说：

* **Transformer**：历史以 **KV cache / attention matrix** 的形式存在
* **Gated DeltaNet**：历史以 **compressed recurrent state** 的形式存在

### 线性 Attention 视角

在线性 attention 里，把输出写成某种“特征映射后”的形式，使得历史可以压缩进一个状态矩阵 $S_t$。一个最经典的形态是：

$$
S_t = S_{t-1} + v_t k_t^\top
$$

$$
o_t = S_t q_t
$$

这个结构说明了一件事：

* 不需要保存所有历史 token
* 只需要维护一个不断更新的状态 $S_t$，当前输出就能由 $S_t$ 和当前 query 算出来。

所以它看起来更像一个 **矩阵状态的 RNN**。作者在 DeltaNet 相关解释里也明确强调：linear attention 本质上就是带矩阵状态的 linear RNN。

你可以把它和 Transformer 对比成：

* **Transformer**

```python
history = [(k1,v1), (k2,v2), ..., (kt,vt)]
output_t = attend(q_t, history)
```

* **Linear-attention style**

```python
state_t = update(state_{t-1}, k_t, v_t)
output_t = read(state_t, q_t)
```

**DeltaNet 和 Gated DeltaNet 都是在这个“state update / state read”框架里工作**

## DeltaNet 在改什么

如果最简单的 linear attention 是：

$$
S_t = S_{t-1} + v_tk_t^\top
$$

因为这个更新更像是“把新记忆一直往状态里累加”。这样做效率高，但在复杂检索、覆盖旧记忆、冲突信息替换这些场景里，能力往往不够强。

Gated DeltaNet 论文对 DeltaNet 的定位就是：它用 **delta rule** 来做更精细的记忆修改，从而提升 retrieval 和长上下文能力

delta rule 的核心想法不是“直接把 $v_t k_t^\top$ 加进去”，而是：

* 先看看当前 state 对这个 key 已经会“读出”什么
* 再计算“真正想写进去的 value”和“当前 state 已经能给出的 value”之间的差
* 只把这个差值写进去

也就是类似：

$$
\text{pred}_t = S_{t-1} k_t
$$

$$
\Delta_t = v_t - \text{pred}_t
$$

$$
S_t = S_{t-1} + \Delta_t k_t^\top
$$

如果 Transformer 的直觉是：

> “query 去所有历史里检索最相关内容”

那 DeltaNet 更像：

> “历史不是按 token 存，而是被编码进一个大 memory matrix；
> 当前 token 通过 query 从这个 matrix 里读；
> 新 token 通过 delta-rule 对这个 matrix 做纠偏式更新。”

所以 DeltaNet 的“像 attention”的地方在于：
它仍然有 **key / value / query**，仍然有 **content-based read/write**。
但它不是显式对每个历史 token 打 attention score，而是对一个 **压缩状态** 做读写。

## Mamba2 在改什么

最好把 Mamba2 理解成：

> 一种把序列处理写成“**状态递推**”的模型层，重点不是显式 attention，而是让状态在时间上流动，并通过可学习机制控制信息保留与遗忘。

Mamba2 这条线很强调 **gating / selective memory control**。
也就是每来一个 token，不是无脑更新状态，而是会学到：

* 旧状态保留多少
* 当前 token 写入多少
* 哪些通道更该忘
* 哪些通道更该保留

所以如果你硬要用最粗略的话描述：

* 普通 RNN

```python
state_t = f(state_{t-1}, x_t)
```

* Mamba2 风格

```python
gate_t  = g(x_t)
state_t = gate_t * old_part + (1 - gate_t) * new_part
output_t = read(state_t)
```

## Gated DeltaNet

现在你已经有两块积木了：

* **DeltaNet**：擅长“精准改写记忆”
* **Mamba2**：擅长“门控地保留/擦除记忆”

那 Gated DeltaNet 的想法就很自然：

> 把 delta-rule 的“纠偏式写入”
> 和 Mamba2 风格的“门控遗忘/控制”
> 合在同一个 recurrent memory update 里。

论文原话概括就是：

* gating enables rapid memory erasure
* delta rule facilitates targeted updates

用非严格但有帮助的写法：

### DeltaNet 风格

$$
S_t = S_{t-1} + (v_t - S_{t-1} k_t) k_t^\top
$$

### Gated DeltaNet 风格

$$
\tilde{S}_{t-1} = g_t \odot S_{t-1}
$$

$$
\text{pred}_t = \tilde{S}_{t-1} k_t
$$

$$
\Delta_t = v_t - \text{pred}_t
$$

$$
S_t = \tilde{S}_{t-1} + \eta_t \cdot \Delta_t k_t^\top
$$

这里只需要读懂语义：

* `$g_t$`：先对旧记忆做门控，决定保留多少
* `$\text{pred}_t$`：看看当前记忆对这个 key 的“已有回答”
* `$\Delta_t$`：和目标 value 的差
* `$\eta_t$`：控制这次写入有多强

也就是说，Gated DeltaNet 不是“先忘后重写”那么粗糙，而是：

1. 先门控旧状态
2. 再计算当前记忆对这条 key 的预测
3. 最后按差值做低秩修正写入

### 与 Transformer Q/K/V 重新对齐

最好把 Gated DeltaNet 理解为：**Q/K/V 仍然存在，但显式的 attention map 消失了**。Q/K/V 的职责并没有完全改变：

* `$k_t$` 表示当前内容应该写到哪个“地址”
* `$v_t$` 表示这个地址应该存储的内容
* `$q_t$` 表示当前输出想从哪些地址读取内容

变化的是历史的存储方式。Transformer 保留每个历史 token 的 key/value，读取时才计算当前 query 与所有 key 的匹配程度；Gated DeltaNet 则在 token 到来时就把 key/value 写入固定大小的状态矩阵，之后直接用 query 读取该矩阵。

* **Transformer Layer**

```python
x_t
 ├─> q_t
 ├─> k_t
 └─> v_t

scores_t = q_t @ K_past^T
weights_t = softmax(scores_t)
o_t = weights_t @ V_past
```

* **Gated DeltaNet Layer**

```python
x_t
 ├─> q_t
 ├─> k_t
 ├─> v_t
 └─> gate/update params

state_{t-1} --(gate)--> gated_state
pred_t = gated_state @ k_t       # 写入前校验
delta_t = v_t - pred_t
state_t = gated_state + write(delta_t, k_t)
o_t = state_t @ q_t              # 最终读取
```

这里的两次矩阵-向量乘法用途不同。`gated_state @ k_t` 不是该层的最终输出，它是在写入新内容前检查：“状态对当前 key 已经会返回什么？”然后只写入预测值与目标 `$v_t$` 的差。`state_t @ q_t` 才是为当前 token 生成输出的读取操作。

#### 为什么 `$S_t q_t$` 仍然像 attention

先忽略 gate 和 delta rule，考虑最基础的 linear attention：

$$
S_t = \sum_{i \le t} v_i k_i^\top
$$

把状态展开后，读取操作可以写成：

$$
o_t = S_t q_t
= \sum_{i \le t} v_i(k_i^\top q_t)
$$

这个式子展示了它与 attention 的直接对应：`$k_i^\top q_t$` 仍然表示 query 与第 `$i$` 个 key 的匹配程度，该系数仍然决定 `$v_i$` 对输出的贡献。区别在于计算顺序：

* Transformer 先为当前 `$q_t$` 显式生成一行 token-to-token 权重，再对 `$V$` 加权求和
* linear attention 先把历史压缩为 `$S_t$`，读取时只计算 `$S_t q_t$`

因此，基础 linear attention 中的相似度系数是隐含在矩阵乘法里的，并不会形成一个可单独查看的 attention map。它也不等价于 Transformer 的 `softmax` attention：上式中的 `$k_i^\top q_t$` 没有经过 `softmax` 归一化，实际模型还会对 Q/K 做特定的特征变换或归一化。

回到 Gated DeltaNet，gate 和 delta rule 会持续衰减、覆盖和修正状态。因此 `$S_t$` 可以理解为历史 key/value 影响的压缩结果，但通常不能再把它精确拆回每个 token 的独立 key/value 对。

所以两者都在做 query-based retrieval，但读取对象不同：

* Transformer 检索的是 **token list**
* Gated DeltaNet 检索的是 **compressed matrix state**

这就是它与 Transformer 的核心差异。前者保留 token 级历史并在读取时匹配，后者在写入时就将历史融合进固定大小的状态。

## Workflow

先给出一个单头版本：

```python
import torch

def batch_matvec(S, x):
    # S: [B, Dv, Dk]
    # x: [B, Dk]
    return torch.einsum('bvk,bk->bv', S, x)

def batch_outer(a, b):
    # a: [B, Dv]
    # b: [B, Dk]
    return torch.einsum('bv,bk->bvk', a, b)

def gate_memory(S, gate):
    # simplest scalar gate version
    # S: [B, Dv, Dk]
    # gate: [B, 1]
    return S * gate[:, None, None]

def gated_deltanet_forward(x, S, params):
    # x: [B, T, D]
    # S: [B, Dv, Dk]

    h = rmsnorm(x)                         # [B, T, D]

    q = h @ params.Wq                      # [B, T, Dk]
    k = h @ params.Wk                      # [B, T, Dk]
    v = h @ params.Wv                      # [B, T, Dv]

    gate = torch.sigmoid(h @ params.Wg_state)  # [B, T, 1]
    eta  = torch.sigmoid(h @ params.Weta)      # [B, T, 1]

    outputs = []
    S_cur = S

    for t in range(x.shape[1]):
        q_t = q[:, t, :]                   # [B, Dk]
        k_t = k[:, t, :]                   # [B, Dk]
        v_t = v[:, t, :]                   # [B, Dv]
        g_t = gate[:, t, :]                # [B, 1], 衰减系数, 0~1 之间
        e_t = eta[:, t, :]                 # [B, 1]

  # 遗忘：旧记忆乘以衰减系数
        S_gated = gate_memory(S_cur, g_t)              # [B, Dv, Dk]
        # 检索: 用 k_t 从记忆本里查一下现在存的值是什么
        pred = batch_matvec(S_gated, k_t)              # [B, Dv]
        # Delta（纠错）：看看记忆里的值和真实 v_t 差多少
        delta = v_t - pred                             # [B, Dv]

        write = batch_outer(delta, k_t)                # [B, Dv, Dk]
        # e_t 是写入门控
        S_new = S_gated + write * e_t[:, None, None]   # [B, Dv, Dk]
        o_t = batch_matvec(S_new, q_t)                 # [B, Dv]

        outputs.append(o_t)
        S_cur = S_new

    O = torch.stack(outputs, dim=1)        # [B, T, Dv]
    y = x + (O @ params.Wo)                # [B, T, D]

    return y, S_cur
```
