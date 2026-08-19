---
title: "Qwen3.5 Dense Model Architecture"
tags:
  - Model-Architecture
date: 2026-08-19
showtoc: true
weight: 10
---

本文以 `transformers==5.14.1` 中的 `Qwen3_5TextModel` 和 `Qwen3_5ForCausalLM` 实现为依据，讨论文本主干，不展开视觉编码器和多模态输入。源码参考：[`modular_qwen3_5.py`](https://github.com/huggingface/transformers/blob/v5.14.1/src/transformers/models/qwen3_5/modular_qwen3_5.py)、[`cache_utils.py`](https://github.com/huggingface/transformers/blob/v5.14.1/src/transformers/cache_utils.py)。

## 总览

**Qwen3.5 是由线性注意力层和标准全注意力层交替组成的 hybrid decoder-only Transformer。**

文本主干的计算顺序是：`Embedding` → 多个 `Qwen3_5DecoderLayer` → 最终 `Qwen3_5RMSNorm` → `lm_head`。每个 decoder layer 都包含一个 token mixer 和一个 MLP；token mixer 的具体类型由 `config.layer_types[layer_idx]` 决定。

在默认配置中，`full_attention_interval=4`，因此每第 4 个 layer 使用 `full_attention`，其余 layer 使用 `linear_attention`。

## 配置定义

**`Qwen3_5TextConfig` 同时定义模型宽度、层数、两类 attention 的维度和层类型。**

| 参数 | 含义 | 影响的模块 |
| --- | --- | --- |
| `hidden_size` | token 表示维度 `H` | embedding、attention 输出、MLP 输入输出 |
| `intermediate_size` | MLP 中间维度 `I` | `gate_proj`、`up_proj`、`down_proj` |
| `num_hidden_layers` | decoder layer 数量 | `layers` |
| `num_attention_heads` | 全注意力的 query head 数 `Nq` | `Qwen3_5Attention` |
| `num_key_value_heads` | 全注意力的 key/value head 数 `Nkv` | GQA 和 KV cache |
| `head_dim` | 全注意力每个 head 的维度 | Q/K/V 和 RoPE |
| `linear_key_head_dim` | 线性 attention 的 key/query head 维度 `Dk` | Gated DeltaNet |
| `linear_value_head_dim` | 线性 attention 的 value head 维度 `Dv` | Gated DeltaNet |
| `linear_num_key_heads` | 线性 attention 的初始 key/query head 数 | Gated DeltaNet |
| `linear_num_value_heads` | 线性 attention 的 value head 数 | recurrent state |
| `linear_conv_kernel_dim` | 线性 attention 的 causal convolution kernel 大小 | `conv1d` 和 convolution cache |
| `layer_types` | 每层的 `linear_attention` 或 `full_attention` | decoder layer 分支 |

`layer_types` 未提供时，配置代码按 `full_attention_interval` 生成：

```python
layer_types = [
    "linear_attention" if (layer_idx + 1) % full_attention_interval else "full_attention"
    for layer_idx in range(num_hidden_layers)
]
```

这里的 layer 编号是从 `1` 计数的；例如 `full_attention_interval=4` 时，第 `4`、`8`、`12` 个 layer 使用全注意力。

## Decoder Layer

**每个 `Qwen3_5DecoderLayer` 使用 Pre-Norm，并通过两次 residual connection 串联 token mixer 和 MLP。**

设输入为 `x`，其形状为 `[batch_size, sequence_length, hidden_size]`，源码等价于：

```python
residual = x
x = input_layernorm(x)
x = token_mixer(x)          # linear_attention 或 full_attention
x = residual + x

residual = x
x = post_attention_layernorm(x)
x = mlp(x)
x = residual + x
```

因此一个 layer 的输出形状仍为 `[B, T, H]`。

`Qwen3_5RMSNorm` 的权重初始化为零，实际缩放因子是 `1 + weight`，而不是直接使用 `weight`。这是该版本实现的特定行为，不应直接套用普通 RMSNorm 的参数语义。

## Linear Attention

**`linear_attention` 使用 Gated DeltaNet，以固定大小的 recurrent state 代替按序列增长的完整 K/V 矩阵。**

### 输入输出

输入和输出都是 `[B, T, H]`。线性 attention 的内部维度由下面几个变量决定：

```python
key_dim   = linear_num_key_heads   * linear_key_head_dim
value_dim = linear_num_value_heads * linear_value_head_dim
conv_dim  = 2 * key_dim + value_dim
```

`in_proj_qkv` 输出 `conv_dim`，另外三个投影分别生成门控向量 `z`、`b` 和 `a`。

### 工作机制

**线性 attention 的核心是“局部 causal convolution + 带衰减和 delta update 的 recurrent state”。**

1. `in_proj_qkv(x)` 生成拼接的 query、key、value；`in_proj_z(x)` 生成输出门控 `z`
2. 对拼接的 QKV 应用 depthwise `Conv1d`，kernel 大小为 `linear_conv_kernel_dim`，随后应用 `SiLU`
3. 将结果拆成 `query`、`key`、`value`，分别 reshape 为 `Dk` 和 `Dv` 的 head
4. `b.sigmoid()` 得到 delta 更新系数 `beta`；`a` 与 `dt_bias` 经过 `softplus`，再和 `A_log` 组合为衰减率 `g`
5. 对 query/key 做 L2 normalization，并把 key head 复制到 `linear_num_value_heads`，使其与 value head 对齐
6. 在 prefill 阶段调用 chunked gated-delta rule；在单 token decode 阶段调用 recurrent gated-delta rule
7. 用 recurrent state 与 query 计算输出，再用 gated RMSNorm 和 `z` 做门控，最后经过 `out_proj` 回到 `H` 维

可将单步状态更新抽象为：

```python
S_t = decay(g_t) * S_{t-1} + delta_update(k_t, v_t, beta_t)
y_t = S_t @ q_t
```

> 上式用于说明数据依赖；实际实现会在 chunk kernel 中重排张量，并使用 `float32` 计算部分衰减量，以避免 `A_log` 在低精度下溢出。

### 最小示例

```python
def forward_linear_attention(self, hidden_states, cache_params=None, attention_mask=None):
    # B/T/H: batch size, sequence length, and hidden size.
    # Nk/Nv: key/query and value head counts; Dk/Dv: their head dimensions.
    # C = 2 * Nk * Dk + Nv * Dv is the concatenated QKV channel size.
    # hidden_states: [B, T, H]
    batch_size, seq_len, _ = hidden_states.shape
    hidden_states = apply_mask_to_padding_states(hidden_states, attention_mask)

    # Project Q/K/V, the output gate z, and the delta parameters a/b.
    mixed_qkv = self.in_proj_qkv(hidden_states).transpose(1, 2)
    # mixed_qkv: [B, C, T]
    z = self.in_proj_z(hidden_states).reshape(batch_size, seq_len, -1, self.head_v_dim)
    # z: [B, T, Nv, Dv]
    b = self.in_proj_b(hidden_states)
    a = self.in_proj_a(hidden_states)
    # b/a: [B, T, Nv] (per-value-head delta/update parameters)

    # Use the cached left context for the causal convolution during decoding.
    has_state = cache_params is not None and cache_params.has_previous_state(self.layer_idx)
    if has_state and seq_len == 1:
        mixed_qkv = self.causal_conv1d_update(
            mixed_qkv,
            cache_params.layers[self.layer_idx].conv_states[0],
            self.conv1d.weight.squeeze(1),
            self.conv1d.bias,
            self.activation,
        )
    else:
        if has_state:
            mixed_qkv = torch.cat(
                [cache_params.layers[self.layer_idx].conv_states[0], mixed_qkv], dim=-1
            )
        if cache_params is not None:
            cache_params.update_conv_state(mixed_qkv, self.layer_idx)
        mixed_qkv = self.causal_conv1d_fn(
            mixed_qkv, self.conv1d.weight.squeeze(1), self.conv1d.bias
        )
        if has_state:
            mixed_qkv = mixed_qkv[:, :, -seq_len:]

    # Split the convolved projection and reshape it into per-head states.
    mixed_qkv = mixed_qkv.transpose(1, 2)
    # mixed_qkv: [B, T, C]
    query, key, value = torch.split(
        mixed_qkv, [self.key_dim, self.key_dim, self.value_dim], dim=-1
    )
    # query/key: [B, T, Nk * Dk]; value: [B, T, Nv * Dv]
    query = query.reshape(batch_size, seq_len, -1, self.head_k_dim)
    key = key.reshape(batch_size, seq_len, -1, self.head_k_dim)
    value = value.reshape(batch_size, seq_len, -1, self.head_v_dim)
    # query/key: [B, T, Nk, Dk]; value: [B, T, Nv, Dv]

    # beta controls delta updates; g controls exponential state decay.
    beta = b.sigmoid()
    g = -self.A_log.float().exp() * torch.nn.functional.softplus(a.float() + self.dt_bias)
    # beta/g: [B, T, Nv]
    if self.num_v_heads // self.num_k_heads > 1:
        query = query.repeat_interleave(self.num_v_heads // self.num_k_heads, dim=2)
        key = key.repeat_interleave(self.num_v_heads // self.num_k_heads, dim=2)
    # After head alignment: query/key: [B, T, Nv, Dk]

    # Prefill uses a chunk kernel; one-token decode uses a recurrent kernel.
    initial_state = (
        cache_params.layers[self.layer_idx].recurrent_states[0] if has_state else None
    )
    # initial_state (when present): [B, Nv, Dk, Dv]
    if has_state and seq_len == 1:
        core_output, recurrent_state = self.recurrent_gated_delta_rule(
            query, key, value, g=g, beta=beta,
            initial_state=initial_state, output_final_state=cache_params is not None,
        )
    else:
        core_output, recurrent_state = self.chunk_gated_delta_rule(
            query, key, value, g=g, beta=beta,
            initial_state=initial_state, output_final_state=cache_params is not None,
        )
    # core_output: [B, T, Nv, Dv]; recurrent_state: [B, Nv, Dk, Dv]
    if cache_params is not None:
        cache_params.update_recurrent_state(recurrent_state, self.layer_idx)

    # Apply gated RMSNorm and project the value-head output back to hidden_size.
    # core_output: [B, T, Nv, Dv]
    core_output = core_output.reshape(-1, self.head_v_dim)
    # core_output: [B * T * Nv, Dv]
    core_output = self.norm(core_output, z.reshape(-1, self.head_v_dim))
    core_output = core_output.reshape(batch_size, seq_len, -1)
    # core_output: [B, T, Nv * Dv]
    output = self.out_proj(core_output)
    # output: [B, T, H]
    return output
```

这里的 `causal_conv1d_fn`、`chunk_gated_delta_rule` 和 `recurrent_gated_delta_rule` 是源码注入的 kernel 接口；具体实现可以来自 `flash-linear-attention`，也可以回退到 Transformers 中的 PyTorch 实现。代码刻意保留了 `prefill` 与单 token `decode` 的分支，因为两者使用不同的状态消费方式。

### Cache 组织

**线性 attention 每层缓存两种固定大小状态：convolution state 和 recurrent state。**

`DynamicCache` 为每个 layer 创建一个 cache layer；线性层使用 `LinearAttentionLayer` 的接口：

| 状态 | 典型形状 | 作用 | 更新时机 |
| --- | --- | --- | --- |
| `conv_states` | `[B, conv_dim, K]` | 保存 causal convolution 所需的最近 `K` 个输入 | 每次 forward 更新，通常只保留尾部 `K` 个位置 |
| `recurrent_states` | `[B, N_v, Dk, Dv]` | 保存 Gated DeltaNet 的矩阵状态 `S` | 每次 chunk 或单 token forward 更新 |

其中 `K=linear_conv_kernel_dim`，`N_v=linear_num_value_heads`。cache 不随历史序列长度线性增长，因此线性层的长期 decode 状态大小与 `T` 无关。

+ prefill 使用多 token 输入时，源码调用 chunk kernel，并把最终状态写回 cache
+ decode 使用单 token 输入时，源码调用 recurrent kernel，并原地更新 `conv_states` 和 `recurrent_states`

### 概念区别

| 维度 | Linear Attention | Full Attention |
| --- | --- | --- |
| 历史信息表示 | 固定大小 recurrent state | 历史 token 的 K/V 序列 |
| 长度方向计算 | 线性递推或 chunk 计算 | 对历史 K/V 做 attention |
| cache 是否随 `T` 增长 | 否 | 是 |
| 是否保存完整 K/V | 否 | 是 |
| 典型实现 | Gated DeltaNet | causal self-attention |

## Full Attention

**`full_attention` 使用带 Q/K RMSNorm、partial RoPE、GQA 和输出 gate 的 causal self-attention。**

### 输入输出

输入和输出都是 `[B, T, H]`。设 `Nq=num_attention_heads`、`Nkv=num_key_value_heads`、`D=head_dim`：

```text
Q: [B, Nq,  T, D]
K: [B, Nkv, T, D]
V: [B, Nkv, T, D]
```

> Grouped-Query Attention (GQA): 当 `Nq > Nkv` 时，`repeat_kv` 将 K/V 复制到 query head 的分组数量，这就是

### 工作机制

**全注意力先计算 Q/K/V，再使用 causal mask 对历史位置做 attention，最后应用 query-side gate。**

1. `q_proj(x)` 的输出维度是 `2 * Nq * D`，沿最后一维拆成 `query_states` 和 `gate`。
2. `k_proj(x)` 和 `v_proj(x)` 分别生成 `Nkv * D` 的 key/value。
3. 对 Q 和 K 的每个 head 应用 `Qwen3_5RMSNorm`。
4. 对 Q/K 应用 `position_embeddings`；文本路径使用 partial RoPE，旋转维度由 `partial_rotary_factor` 决定。
5. 将当前 K/V 写入该层的 cache，再通过 `ALL_ATTENTION_FUNCTIONS` 选择 eager、SDPA 或其他已注册实现。
6. attention 输出乘以 `sigmoid(gate)`，reshape 回 `[B, T, H]`，再经过 `o_proj`。

### 最小示例

**下面的代码保留了 `Qwen3_5Attention.forward` 的核心数据流，用于展示一个 full-attention layer 如何从 `[B, T, H]` 生成输出。**

```python
def forward_full_attention(
    self,
    hidden_states,
    position_embeddings,
    attention_mask=None,
    past_key_values=None,
):
    # hidden_states: [B, T, H]
    input_shape = hidden_states.shape[:-1]
    # input_shape: [B, T]
    hidden_shape = (*input_shape, -1, self.head_dim)
    # hidden_shape: [B, T, N_heads, D]; N_heads is Nq for Q and Nkv for K/V.

    # q_proj emits [B, T, 2 * Nq * D],
    # interleaving a query vector and a gate vector for each attention head.
    query_states, gate = torch.chunk(
        self.q_proj(hidden_states).view(*input_shape, -1, self.head_dim * 2),
        2,
        dim=-1,
    )
    # After view:  [B, T, Nq, 2D]
    # query_states: [B, T, Nq, D]
    # gate:         [B, T, Nq, D]
    gate = gate.reshape(*input_shape, -1)
    # gate: [B, T, Nq * D]

    # Normalize Q and K independently on the per-head dimension.
    query_states = self.q_norm(query_states.view(hidden_shape)).transpose(1, 2)
    # query_states: [B, Nq, T, D]
    key_states = self.k_norm(
        self.k_proj(hidden_states).view(hidden_shape)
    ).transpose(1, 2)
    value_states = self.v_proj(hidden_states).view(hidden_shape).transpose(1, 2)
    # key_states/value_states: [B, Nkv, T, D]

    # Apply partial RoPE to Q and K; V is not position-rotated.
    cos, sin = position_embeddings
    query_states, key_states = apply_rotary_pos_emb(
        query_states, key_states, cos, sin
    )

    # Append the current K/V to this layer's dynamic cache during decoding.
    if past_key_values is not None:
        key_states, value_states = past_key_values.update(
            key_states, value_states, self.layer_idx
        )

    # GQA repeats each KV head for a group of query heads.
    key_states = repeat_kv(key_states, self.num_key_value_groups)
    value_states = repeat_kv(value_states, self.num_key_value_groups)
    # key_states/value_states: [B, Nq, T, D]

 # Select eager attention, SDPA, or FlashAttention from the Transformers registry.
    attention_interface = ALL_ATTENTION_FUNCTIONS.get_interface(
        self.config._attn_implementation,
        eager_attention_forward,
    )
    attn_output, attn_weights = attention_interface(
        self,
        query_states,
        key_states,
        value_states,
        attention_mask,
        dropout=0.0 if not self.training else self.attention_dropout,
        scaling=self.scaling,
        **kwargs,
    )

    # Gate the attention result before projecting it back to hidden_size.
    # Before reshape: [B, T, Nq, D]
    attn_output = attn_output.reshape(*input_shape, -1)
    # After reshape:  [B, T, Nq * D]
    attn_output = attn_output * torch.sigmoid(gate)
    return self.o_proj(attn_output)
```

### Cache 组织

**全注意力层缓存按层保存动态 K/V，形状沿序列维度增长。**

每个 full-attention layer 的 cache 是一个 `DynamicLayer`，典型张量形状为：

```text
keys   : [B, Nkv, cached_length, D]
values : [B, Nkv, cached_length, D]
```

Qwen3.5 的混合 cache 层同时继承动态 K/V cache 和线性 attention cache 能力，因此同一个 `DynamicCache` 可以按 `layer_types` 为不同 layer 保存不同状态：

```text
layer i = linear_attention -> conv_states + recurrent_states
layer j = full_attention   -> keys + values
```

full-attention decode 时，新 token 的 K/V 被追加到对应 layer 的 `keys` 和 `values`；attention 使用当前 query 与整个可见 K/V 序列计算。该部分的显存占用随缓存长度 `T` 增长，且主要由 `Nkv` 而不是 `Nq` 决定。

### 概念区别

Qwen3.5 的 `full_attention` 与 Qwen3 等传统 decoder 的 causal self-attention 在基本 K/Q/V 计算上相近，但 Qwen3.5 额外包含 Q/K RMSNorm、partial RoPE 和 query-side output gate

## FFN

**Qwen3.5 的 FFN 是无 bias 的 SwiGLU，先用 SiLU 门控逐元素融合两条投影，再投影回 hidden size。**

### 输入输出

输入 `x` 的形状为 `[B, T, H]`，中间张量形状为 `[B, T, I]`，输出回到 `[B, T, H]`：

```text
gate_proj: H -> I
up_proj  : H -> I
down_proj: I -> H
```

### 工作机制

源码计算式为：

```python
gate = gate_proj(x)
up = up_proj(x)
y = down_proj(silu(gate) * up)
```

`gate_proj`、`up_proj` 和 `down_proj` 都是 `bias=False` 的线性层。FFN 前有 `post_attention_layernorm`，FFN 输出通过第二次 residual connection 加回 token mixer 的结果。

### 最小示例

```python
def forward_mlp(self, x):
    # Project the same input into the gated and value branches.
    gate = self.gate_proj(x)
    up = self.up_proj(x)

    # SiLU gates the value branch elementwise before the down projection.
    hidden = self.act_fn(gate) * up

    # Return from intermediate_size I to hidden_size H.
    return self.down_proj(hidden)
```

## 端到端数据流

**一个 token 在文本主干中的主要状态流可以概括为 embedding、按层选择 mixer、FFN 和最终 language-model head。**

```text
input_ids
   |
Embedding -> hidden_states [B, T, H]
   |
DecoderLayer 1..L
   |-- linear_attention: conv state + recurrent state
   |-- full_attention:   K/V cache
   |-- SwiGLU MLP + residual
   |
Final RMSNorm -> lm_head -> logits [B, T, vocab_size]
```

图中的两类 cache 不是同一种张量：linear layer 保存有限状态，full-attention layer 保存历史 K/V。生成时，模型必须在每个 layer 使用与 `layer_types` 对应的 cache 更新路径。
