#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": xref
#import "/figures/vllm-hybrid-kv-cache.typ" as fig

#tola-meta((
  title: "vLLM Hybrid KV Cache",
  date: "2026-11-04",
  summary: "Why vLLM's \"GPU KV cache size\" for Qwen3.8-27B is not a count of token slots and changes with max_model_len: GDN state, attention pages and one shared block pool.",
  tags: ("vLLM", "LLM-Inference"),
  series: "AI Infra",
  part: 4,
  weight: 10,
))

At startup vLLM prints how much KV cache it has. For Qwen3.8-27B on two A100s with TP=2 and an FP8 KV cache, the setup of #xref("nvlink-vs-pcie-inference"):

```text
Available KV cache memory: 52.89 GiB
GPU KV cache size: 3,208,045 tokens, Maximum concurrency for 132,096 tokens per request: 24.29x
```

The 3,208,045 is not the number of tokens the pool can hold. It is also related to `max_model_len`, which should only cap the length of a request: with the same 52.89 GiB, vLLM's formula gives 1,508,693 at `max_model_len=8192`.

Qwen3.8-27B mixes full attention with Gated DeltaNet, two kinds of layer that keep different state per sequence, and vLLM puts both in one block pool. The printed number comes from how that pool is shared.

= State

Qwen3.8-27B has the Qwen3.5 architecture (#xref("qwen3-5")): of its 64 layers, every fourth is full attention, and the other 48 are Gated DeltaNet (GDN), a linear attention. The two kinds keep different state per sequence.

#figure(
  fig.fig-layer-state(),
  caption: [The layer pattern of Qwen3.8-27B and one repeating unit. Each GDN layer keeps a fixed state per sequence; the full-attention layer keeps a K and V row per token. Sizes are for the whole model, before TP; not to scale.],
) <fig-layer-state>

*A full-attention layer keeps K and V for every past token*: 4 KV heads × 256 × 2 = 2048 values. With an FP8 KV cache, the 16 such layers hold 32 KiB per token, so the total grows with the sequence.

*A GDN layer keeps a state of fixed size instead*:

- a recurrent state of 48 heads × 128 × 128 in FP32 (the config's `mamba_ssm_dtype`): 3 MiB;
- a convolution state, the last 3 inputs of its short convolution over 10,240 channels in BF16: 60 KiB.

Over the 48 GDN layers that is *147 MiB per sequence*, as much as 4,700 tokens of full-attention KV, *whether the sequence has 100 tokens or 128K*. TP splits the heads of both kinds, so at TP=2 each GPU holds 73 MiB of GDN state per sequence and 16 KiB of KV per token.

= Block Pool

vLLM keeps both in one pool of pages, so that memory freed by one kind can go to the other. That needs one page size for both, and vLLM gets it by sizing attention blocks to the GDN state. At TP=2 with FP8 KV, per layer and per GPU:

#table(
  columns: 2,
  table.header([], [Bytes]),
  [GDN state: 24 × 128 × 128 × 4 B + 30 KiB], [1,603,584],
  [Attention KV for one token: 2 × 256 × 2 × 1 B], [1,024],
  [Attention KV for one block of 1568 tokens], [1,605,632],
)

1568 is the smallest multiple of 16 tokens whose KV fills a GDN page. vLLM sets the attention block size to it and pads the GDN page by the difference, 0.13%; both steps show up in its startup log.

The same arithmetic gives every block size in the logs:

- BF16 KV takes 2 bytes per value, so the block is 784 tokens.
- With MTP on, the convolution state keeps 3 more rows for the draft tokens, and the blocks become 1600 (FP8) and 800 (BF16).
- At TP=4 the state and the KV both halve, and the block stays at 1568.

vLLM then sorts the layers into groups of equal size: one group of the 16 full-attention layers, and the 48 GDN layers in three groups of 16. The log shows `kv cache group sizes (1568, 1568, 1568, 1568)`. A block is one page in each of the 16 layers of a group, 25.7 MB at TP=2, and any group can take any free block:

#figure(
  fig.fig-kv-pool(),
  caption: [One pool for both kinds of state, TP=2 with FP8 KV. Attention takes a block per 1568 tokens; GDN takes the same number of blocks for any sequence, two per group with prefix caching.],
) <fig-kv-pool>

A sequence takes *one attention block per 1568 tokens, plus a fixed number of GDN blocks*:

- With prefix caching off, one block per GDN group, three in all.
- With prefix caching on (`mamba_cache_mode=align`), two blocks per group, six in all. vLLM also keeps GDN states at block boundaries, so that a cached prefix can resume the recurrence.

= GPU KV Cache Size

*The 3,208,045 is not a count of token slots.* vLLM divides the pool by what one request of `max_model_len` needs, then multiplies back:

+ 52.89 GiB / 25.7 MB = 2,210 blocks.
+ A request of 132,096 tokens takes 85 attention blocks and 6 GDN blocks: 91.
+ 2,210 / 91 = 24.29 such requests, and 24.29 × 132,096 = 3,208,045 tokens.

This matches the logged number exactly on every run, including those with prefix caching off, where the GDN part is 3 blocks.

= `max_model_len`

vLLM computes the number in `get_kv_cache_capacity` and `get_max_concurrency_for_kv_cache_config` (`vllm/v1/core/kv_cache_utils.py`). For this model they reduce to:

```python
attn_blocks = cdiv(max_model_len, block_size)   # 1 attention group, 1 block per 1568 tokens
gdn_blocks = 3 * 2                              # 3 GDN groups, 2 blocks each with prefix caching
blocks_per_request = attn_blocks + gdn_blocks
max_concurrency = num_blocks / blocks_per_request
kv_cache_size = int(max_concurrency * max_model_len)
```

With $N$ blocks in the pool, block size $B$, `max_model_len` $L$ and $G$ GDN blocks per request, and ignoring the rounding up:

$ "kv_cache_size" approx N / (L \/ B + G) dot L = N B dot L / (L + G B) $

For a model with only full attention, $G = 0$, the two $L$ terms cancel, and the result is $N B$, the token slots in the pool, whatever the setting.

Here $G = 6$, so *each request is charged as if it were $G B$ = 9,408 tokens longer*. The attention blocks grow with $L$ but the GDN blocks do not, so a shorter `max_model_len` gives GDN a larger share of each request, and the number drops. The same 2,210 blocks at different settings:

#table(
  columns: 4,
  table.header([`max_model_len`], [Blocks per request], [Max concurrency], [KV cache size]),
  [8,192], [6 + 6 = 12], [184.17], [1,508,693],
  [32,768], [21 + 6 = 27], [81.85], [2,682,121],
  [132,096], [85 + 6 = 91], [24.29], [3,208,045],
  [262,144], [168 + 6 = 174], [12.70], [3,329,530],
)

Only the 132,096 row is from a log; the others follow from the formula. The pool is the same in every row, and the number approaches 2,210 × 1568 = 3,465,280 as `max_model_len` grows.

= Summary

- *For a hybrid model, read "GPU KV cache size" as how many max-length requests fit*, times `max_model_len`. It changes with `max_model_len` even when the memory does not.
- *The real capacity is the block pool*: here 2,210 blocks, each 1568 tokens of attention KV or one GDN state for 16 layers.
- *Every running sequence holds GDN state, however short*: a fixed number of blocks per sequence, on top of its attention blocks.
