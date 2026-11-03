#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, hint, term, xref
#import "/figures/nvlink-vs-pcie-inference.typ" as fig

#tola-meta((
  title: "NVLink vs PCIe in Practice: Bandwidth and LLM Serving",
  date: "2026-11-02",
  summary: "Peer-to-peer and NCCL bandwidth measured on an RTX A6000 and an A100 server, and what NVLink and PCIe change when vLLM serves Qwen3.8-27B with tensor parallelism.",
  tags: ("GPU", "Hardware", "LLM-Inference"),
  weight: 10,
  toc-depth: 3,
))

#xref("gpu-server-topology") read the topology of two servers. This post measures them: how fast each path between two GPUs moves data, and how much that matters when the server runs an LLM.

- Machine 1: 2 × RTX A6000 48 GB in a 2 × Xeon Gold 6248R server, one GPU per socket. The GPUs only meet over PCIe 3.0 and UPI (`SYS`).
- Machine 2: 4 × A100 80 GB PCIe in a 2 × Xeon Platinum 8368 server. GPU0–1 and GPU2–3 are NVLink bridge pairs (`NV12`), one pair per socket; every other pair is `SYS`.

The model is Qwen3.8-27B with INT8 weights and BF16 activations (W8A16), served by vLLM 0.32 with tensor parallelism (TP). Each data point is a single run with 4 to 256 requests, so differences of a few percent are within noise.

= Background

/*
== Measuring a Link

Every GPU pair gets two tests.

A peer copy: `cudaMemcpyPeerAsync` copies a 256 MiB buffer to the other GPU, one way or both ways at once. Nothing runs on top of the copy, so the result is the speed of the path, and compares directly with the link's rated speed.

An all-reduce through NCCL: the operation tensor parallelism runs between GPUs. Two tools run it:

- `p2p_topo`, a short script on `torch.distributed`. FP32 from 1 to 64 MiB, timed on the host. It also sweeps `NCCL_P2P_LEVEL`, covered in the next section.
- `all_reduce_perf` from NVIDIA's #link("https://github.com/NVIDIA/nccl-tests")[nccl-tests]. BF16 from 8 B to 128 MiB, with and without CUDA Graphs (`-G 1`). It checks every result.

nccl-tests prints two bandwidths:

- `algbw`: bytes divided by time.
- `busbw`: `algbw` × 2(_n_ − 1)/_n_. In a ring all-reduce over _n_ GPUs, each link carries 2(_n_ − 1)/_n_ times the buffer, so `busbw` compares with the link's speed for any _n_. The factor is 1 for 2 GPUs and 1.5 for 4.
*/

== P2P or SHM

#term("NCCL")[
  The NVIDIA Collective Communications Library, pronounced "nickel". It is a library, not a network protocol.

  It implements collectives such as all-reduce, all-gather and broadcast, in which a group of GPUs exchange and combine data, plus point-to-point send and receive.

  For each pair of GPUs, NCCL picks a transport: NVLink or PCIe P2P, host shared memory, or the network through InfiniBand, RoCE or TCP sockets. It also picks an algorithm such as ring or tree, then runs the transfer as CUDA kernels on the GPUs.

  PyTorch's `nccl` backend for `torch.distributed`, and through it vLLM, call NCCL for multi-GPU communication. It is open source.
] moves data between two GPUs in one of two ways:

- *P2P*: a GPU reads or writes the other GPU's memory directly, over NVLink or PCIe.
- *SHM*: the sender copies into a buffer in host memory, and the receiver copies it out.

#figure(
  fig.fig-transports(),
  caption: [The two transports between GPUs on different sockets. Orange and blue mark the parts the data passes through.],
) <fig-transports>

Neither uses the CPU cores: NCCL kernels on the GPUs move the data themselves. The two differ in which parts of the CPU the data passes through.

*P2P never touches a memory controller or DRAM.* A peer write leaves GPU0 over PCIe, enters CPU0 at a host bridge, crosses the on-die fabric and UPI to CPU1, and leaves through CPU1's host bridge into GPU1. The CPUs only route it; on the A6000 server, Intel PCM saw little DRAM traffic during a peer copy (below). Over NVLink, P2P does not pass through the CPUs at all.

*SHM goes into DRAM and back out.* GPU0 writes into a buffer through a memory controller, and GPU1 reads it back. The data crosses PCIe twice, out of GPU0 and into GPU1, plus a round trip to DRAM, so SHM is slower. It works wherever the GPUs can reach host memory, which is why NCCL falls back to it.

NCCL uses P2P only for pairs no farther apart than `NCCL_P2P_LEVEL`. Its distance ladder is close to the codes of `nvidia-smi topo -m`, but without `NODE`: any path through one CPU counts as `PHB`. When the variable is unset, NCCL's source (`ncclTopoCheckP2p` in `paths.cc`) uses `PXB`, so *P2P stops at PCIe switches*. The one exception is an AMD CPU with at most two GPUs, which gets `SYS`.

Both machines here have Intel CPUs, so *pairs on different sockets fall back to SHM*. Raising the level from `PXB` to `SYS` lets them use P2P:

#figure(
  fig.fig-p2p-level(),
  caption: [`NCCL_P2P_LEVEL` cuts NCCL's distance ladder. The default allows P2P up to `PXB`; `SYS` allows every path. The NVLink pair uses P2P either way.],
) <fig-p2p-level>

NCCL's debug log names the transport:

#table(
  columns: 3,
  table.header([Pair], [Default], [`NCCL_P2P_LEVEL=SYS`]),
  [NVLink pair], [`P2P/CUMEM/read`], [`P2P/CUMEM/read`],
  [Across sockets], [`SHM/direct/direct`], [`P2P/CUMEM`],
)

`PIX` and `PXB` behaved like the default on every cross-socket pair.

=== Bandwidth Along the Path

A P2P transfer is only as fast as the narrowest link on its path. Each GPU hangs off a PCIe x16 link, rated per direction as:

#table(
  columns: 4,
  table.header([Link], [Per lane], [Rated], [A large copy normally reaches]),
  [PCIe 3.0 x16], [8 GT/s], [15.75 GB/s], [about 12.6 GB/s],
  [PCIe 4.0 x16], [16 GT/s], [31.5 GB/s], [about 25 GB/s],
  [PCIe 5.0 x16], [32 GT/s], [63.0 GB/s], [about 50 GB/s],
)

Sixteen lanes, less the 128b/130b line encoding, give the rated speed. Packet headers and flow control take more, so a large copy normally gets about 80% of it.

The two sockets are joined by several UPI links side by side. Each carries 2 bytes per transfer in each direction:

#table(
  columns: 4,
  table.header([CPUs], [UPI], [Per link, per direction], [All links, per direction]),
  [2 × Xeon Gold 6248R (Machine 1)], [2 × 10.4 GT/s], [20.8 GB/s], [41.6 GB/s],
  [2 × Xeon Platinum 8368 (Machine 2)], [3 × 11.2 GT/s], [22.4 GB/s], [67.2 GB/s],
  [2 × Xeon Platinum 8558P], [3 × 20 GT/s], [40.0 GB/s], [120 GB/s],
)

These are rated speeds; UPI also carries headers, checksums and coherence traffic, so data moves slower. Whether one copy spreads over several links depends on how the CPU routes it, so the figure below draws a single link, the least a copy could have.

#figure(
  fig.fig-link-path(),
  caption: [The P2P path between two GPUs on different sockets, each link drawn as a pipe whose height is its rated bandwidth per direction. The orange band is the measured one-way peer copy of 256 MiB. UPI is drawn as one of its links.],
) <fig-link-path>

On both machines the peer copy falls short of every pipe on its path. Copies between a GPU and host memory show where the shortfall lies. They cross the same PCIe link, and when the memory sits on the other socket, the same UPI:

#figure(
  fig.fig-host-copy(),
  caption: [One-way copies of 256 MiB on both machines. Host copies use pinned memory (`cudaHostRegister`), with the pages and the copying thread bound to one NUMA node; each bar spans the two GPUs measured, median of three runs. The dashed line is 80% of the GPU's PCIe rate, what a large copy normally reaches.],
) <fig-host-copy>

The two machines fail in different places:

- Machine 1: every copy falls well short, host copies included, at 51–55% of PCIe 3.0. Even a GPU and its own socket's memory, with no UPI on the path, reach only half the link. *The limit lies between the GPU and its CPU*, not between the sockets; the A6000 section looks further.
- Machine 2: host copies reach 78–83% of PCIe 4.0, which is normal, and the other socket's memory is as fast as the GPU's own. A host copy across sockets crosses UPI at about 25 GB/s, so neither the PCIe link nor UPI holds the peer copy to 18.5 GB/s. What is left is *the step only P2P takes*: the CPU0 host bridge forwarding the GPU's writes over UPI to a device under CPU1.

== What Tensor Parallelism Sends

With TP, each layer ends in two all-reduces, one after attention (GDN or full) and one after the MLP. Each carries the layer's output for every token in the step: tokens × hidden size × 2 bytes. Qwen3.8-27B has a hidden size of 5120, so:

- one decode step of one sequence all-reduces 10 KiB, twice per layer;
- one prefill chunk of 8192 tokens (vLLM's `max_num_batched_tokens` here) all-reduces 80 MiB, twice per layer.

*Decode sends many tiny messages; prefill sends a few large ones.*

== Roofline

A roofline compares two speeds of the GPU, peak compute and memory bandwidth. Their ratio is the ridge point, in FLOPs per byte. A kernel that does fewer FLOPs per byte it reads than the ridge waits on memory; one that does more waits on compute.

=== Where a Step Sits

Two facts place every part of a step:

- A linear layer reads its weights once per step and uses them for every token in the step. The weights are INT8 and multiplied in BF16, so each byte gives 2 FLOPs per token; with the BF16 output layer, the whole model gives 1.9 FLOPs per byte per token. More tokens per step move it right.
- Attention reads each sequence's own KV. A byte of FP8 KV serves 6 query heads, 2 FLOPs each: 12 FLOPs per byte, 48 with MTP's four tokens. More sequences do not move it.

#figure(
  fig.fig-intensity(),
  caption: [FLOPs per byte read from memory for the parts of a Qwen3.8-27B step, against the ridge points of the two GPUs (BF16 peak over memory bandwidth, from the spec sheets).],
) <fig-intensity>

*Decode sits left of both ridges, prefill far right.* Only the A100's concurrency-128 runs cross over.

=== What TP Changes

TP=2 gives each GPU half of every weight matrix and half the KV heads. Each GPU reads half the bytes and does half the FLOPs, so the FLOPs per byte, and the ridge, stay where they were. What TP adds is the all-reduces:

#figure(
  fig.fig-tp-layer(),
  caption: [One layer at TP=1 and TP=2, as time on one GPU; not to scale. vLLM runs the all-reduces between the compute, not alongside it.],
) <fig-tp-layer>

With a free link TP=2 would be exactly twice as fast. How much of that a real link takes depends on the size of the step:

- A small step sends small all-reduces, about 10 µs each whatever the link (@fig-allreduce), so *latency decides*.
- A large step, such as a prefill chunk, sends large ones, so *bandwidth decides*.

For the large case, take one token of a prefill chunk on one GPU of a pair: 25.6 GFLOP at the GPU's peak, and 128 all-reduces of 10 KiB at the bandwidth nccl-tests measured for large messages:

#table(
  columns: 3,
  table.header([], [Compute], [All-reduce]),
  [RTX A6000, PCIe], [165 µs], [182 µs],
  [A100, PCIe], [82 µs], [96 µs],
  [A100, NVLink], [82 µs], [8 µs],
)

The two run one after the other, so *over PCIe a prefill chunk takes about twice as long as its compute*, and over NVLink about 10% longer. Both times grow with the tokens, so the ratio holds for any chunk size.

The roofline figure of each machine below covers both cases. It times the 128 all-reduces of a _B_-token step with nccl-tests and adds that time to the GPU's.

== GDN State in Qwen3.8-27B

Qwen3.8-27B has the Qwen3.5 architecture (#xref("qwen3-5")): of its 64 layers, every fourth is full attention, and the other 48 are Gated DeltaNet (GDN), a linear attention. The two kinds keep different state per sequence.

A full-attention layer keeps K and V for every past token: 4 KV heads × 256 × 2 = 2048 values. With an FP8 KV cache, the 16 such layers hold 32 KiB per token, so the total grows with the sequence.

A GDN layer keeps a state of fixed size instead:

- a recurrent state of 48 heads × 128 × 128 in FP32 (the config's `mamba_ssm_dtype`): 3 MiB;
- a convolution state, the last 3 inputs of its short convolution over 10,240 channels in BF16: 60 KiB.

Over the 48 GDN layers that is *147 MiB per sequence*, as much as 4,700 tokens of full-attention KV, *whether the sequence has 100 tokens or 128K*. TP splits the heads of both kinds, so at TP=2 each GPU holds 73 MiB of GDN state per sequence and 16 KiB of KV per token.

== One Pool for Both

vLLM keeps both in one pool of pages, so that memory freed by one kind can go to the other. That needs one page size for both, and vLLM gets it by sizing attention blocks to the GDN state. At TP=2 with FP8 KV, per layer and per GPU:

#table(
  columns: 2,
  table.header([], [Bytes]),
  [GDN state: 24 × 128 × 128 × 4 B + 30 KiB], [1,603,584],
  [Attention KV for one token: 2 × 256 × 2 × 1 B], [1,024],
  [Attention KV for one block of 1568 tokens], [1,605,632],
)

1568 is the smallest multiple of 16 tokens whose KV fills a GDN page, and vLLM pads the GDN page by the difference:

```text
Setting attention block size to 1568 tokens to ensure that attention page size is >= mamba page size.
Padding mamba page size by 0.13% to ensure that mamba page size and attention page size are exactly equal.
```

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

=== What "GPU KV Cache Size" Counts

At startup vLLM prints:

```text
Available KV cache memory: 52.89 GiB
GPU KV cache size: 3,208,045 tokens, Maximum concurrency for 132,096 tokens per request: 24.29x
```

*The 3,208,045 is not a count of token slots.* vLLM divides the pool by what one request of `max_model_len` needs, then multiplies back:

+ 52.89 GiB / 25.7 MB = 2,210 blocks.
+ A request of 132,096 tokens takes 85 attention blocks and 6 GDN blocks: 91.
+ 2,210 / 91 = 24.29 such requests, and 24.29 × 132,096 = 3,208,045 tokens.

This matches the logged number exactly on every run, including those with prefix caching off, where the GDN part is 3 blocks.

== Why `max_model_len` Changes It

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

= A100: NVLink Pairs and Cross-Socket PCIe

This is Machine 2 of #xref("gpu-server-topology"). Each A100 has a PCIe 4.0 x16 link, 31.5 GB/s per direction on paper, and each bridge pair has 12 NVLinks, 300 GB/s per direction.

#figure(
  fig.fig-copy-bw(),
  caption: [One-way peer copy of 256 MiB between two GPUs, with the A6000 pair for comparison.],
) <fig-copy-bw>

All serving runs on this machine:

- use an FP8 KV cache, FlashInfer attention and prefix caching, with MTP off so that draft acceptance does not differ between runs;
- run TP=2 with `NCCL_P2P_LEVEL=SYS` and `--disable-custom-all-reduce`, so that NCCL does all of the communication;
- use GPU0–1 as the NVLink pair and GPU1–2, on different sockets, as the PCIe pair;
- have 32 requests of 128 output tokens per point, except TP=2 at concurrency 1, which has 4.

== KV Cache Capacity

#table(
  columns: 5,
  table.header([], [`max_num_seqs`], [Weights per GPU], [KV memory per GPU], [KV cache size]),
  [TP=2, NVLink (GPU0–1)], [1], [14.61 GiB], [52.89 GiB], [3,208,045],
  [TP=2, PCIe (GPU1–2)], [1], [14.61 GiB], [55.05 GiB], [3,338,690],
  [TP=4], [16], [7.37 GiB], [59.97 GiB], [7,273,989],
)

TP=4 holds 2.3 times as many tokens as TP=2: it has more free memory per GPU and stores half the bytes per token.

With identical settings, *the NVLink pair gets 2.2 GiB less KV memory* than the PCIe pair. The cause is not known; NCCL buffers for the NVLink transport are one candidate.

== Serving at TP=1 and TP=2

TP=1 runs on GPU0 alone. Output throughput, prefill included:

#figure(
  fig.fig-a100-tp(),
  caption: [Output throughput (tokens/s, prefill included) on the A100s, 128 output tokens per request. Each panel has its own scale. TP=2 at concurrency 1 runs with `max_num_seqs=1`; the rest with 8.],
) <fig-a100-tp>

- TP=2 over NVLink serves *1.51 to 1.75 times* as much as TP=1. At every length its lead grows with concurrency, and it is largest at 128K and concurrency 8.
- TP=2 over PCIe serves *1.38 to 1.61 times* as much. Up to 16K its lead shrinks with concurrency, from 1.46 to 1.38 at 1K: more sequences make the all-reduces larger, and PCIe pays for each byte. At 64K and 128K, where attention takes most of the step, it grows with concurrency like NVLink's.
- At concurrency 1 both pairs serve about 1.5 times as much as TP=1, well short of 2, so *per GPU a single A100 does more work*.


== Serving at TP=2: NVLink vs PCIe

At concurrency 1 the two pairs *decode at the same speed*: within 0.7% at every length, 65.8 against 65.4 tok/s at 128K. NVLink cuts time to first token by 6–26%, and the whole request by 2–5%.

In nccl-tests, a 10 KiB all-reduce, the size of a decode message, takes about 10 µs on either link. An 80 MiB prefill message takes 0.5 ms over NVLink and 6 ms over PCIe:

#figure(
  fig.fig-allreduce(),
  caption: [All-reduce time against message size, nccl-tests with BF16, 2 GPUs and CUDA Graphs. Cross-socket pairs use `NCCL_P2P_LEVEL=SYS`. Time is in µs on the left and in ms on the right.],
) <fig-allreduce>

Below about 64 KiB the time is _*fixed cost*_: launch, synchronization and a round trip, which bandwidth cannot shorten. A decode step of one sequence sends only such messages, 128 of them at about 10 µs, some 1.3 ms of a 15 ms token on either link. Prefill sends 80 MiB messages, where NVLink's bandwidth matters.

More sequences make decode messages larger, and the gap opens. NVLink's gain in output throughput over PCIe:

#figure(
  fig.fig-a100-gain(),
  caption: [NVLink (GPU0–1) over PCIe (GPU1–2): output throughput gain at TP=2, 128 output tokens. Concurrency 1 runs with `max_num_seqs=1`, 2–8 with 8, and 16 with 16.],
) <fig-a100-gain>

At every length the gain grows with concurrency, *up to 8–33% at 16*. At 16 sequences a decode message is 160 KiB, where PCIe takes about four times as long as NVLink. The gain shrinks at 128K, where attention dominates the step.

TP=4 spans both pairs, so every all-reduce crosses the sockets. At concurrency 16:

#table(
  columns: 4,
  table.header([Input], [TP=2, PCIe], [TP=2, NVLink], [TP=4]),
  [1K], [282.8 tok/s], [377.3 tok/s], [435.0 tok/s],
  [8K], [421.1 tok/s], [513.8 tok/s], [506.1 tok/s],
  [32K], [176.4 tok/s], [216.1 tok/s], [262.5 tok/s],
  [128K], [140.6 tok/s], [151.9 tok/s], [190.8 tok/s],
)

TP=4 is faster at long inputs, where it splits attention four ways, and no faster at 8K. *Per GPU, a TP=2 NVLink pair does better at every length.*

== Peer-to-Peer and NCCL

Every pair, with `p2p_topo` for the all-reduce:

#table(
  columns: 6,
  table.header([GPUs], [Link], [Copy one way], [Copy both ways], [All-reduce, default], [All-reduce, `SYS`]),
  [0, 1], [`NV12`], [278.6 GB/s], [526.7 GB/s], [171.8 GB/s], [172.0 GB/s],
  [2, 3], [`NV12`], [278.7 GB/s], [526.9 GB/s], [171.6 GB/s], [171.8 GB/s],
  [0, 2], [`SYS`], [18.5 GB/s], [36.4 GB/s], [12.0 GB/s], [12.7 GB/s],
  [0, 3], [`SYS`], [18.5 GB/s], [37.1 GB/s], [12.1 GB/s], [12.7 GB/s],
  [1, 2], [`SYS`], [18.4 GB/s], [37.0 GB/s], [12.1 GB/s], [12.7 GB/s],
  [1, 3], [`SYS`], [18.5 GB/s], [35.5 GB/s], [12.0 GB/s], [12.3 GB/s],
)

All-reduces are FP32 with 64 MiB messages. *In bandwidth NVLink is 15 times faster for copies and 13.5 times for all-reduce.*

- NVLink copies at 93% of its 300 GB/s.
- A cross-socket copy reaches 59% of PCIe 4.0, about the same share as the A6000 pair's 62%. Unlike the A6000, this machine's host copies reach 78–83% (@fig-host-copy), so *the shortfall here is specific to P2P across sockets*.
- `NCCL_P2P_LEVEL=SYS` adds 3–6% on cross-socket pairs, much less than the 27% on the A6000, and nothing on NVLink pairs, which use P2P anyway.

nccl-tests agrees on the bandwidth, with two details:

- With CUDA Graphs, which vLLM uses for decode, cross-socket P2P at 64 MiB rises from 12.2–12.5 to 13.1–13.5 GB/s, while NVLink drops from 174 to 148–155 GB/s, for reasons not yet found.
- For small messages, `SYS` cuts latency across sockets: on GPU1–2, a 40 KiB all-reduce takes 12.7 µs instead of 18.1.

*Four GPUs behave differently.* Over GPU0–3, the default mixes NVLink P2P inside the pairs with SHM between them, and reaches 34.5 GB/s `busbw` at 64 MiB. With `SYS` everything is P2P, and it drops to 32.5 GB/s; a 1 MiB all-reduce takes 155 µs instead of 109. Set it for a cross-socket pair, but *measure first on a mixed topology*.

== Training

Short TP=2 training runs, 16 steps each, of one 1024-token sequence per step. LoRA uses Qwen3-32B. Full fine-tuning (SFT) and continued pretraining use Qwen3-14B, because the FP16 weights, gradients and AdamW states of 32B need about 122 GiB per GPU at TP=2.

#table(
  columns: 5,
  table.header([], [NVLink, s/step], [PCIe, s/step], [Data per GPU per step], [Average rate]),
  [LoRA, 32B], [2.106], [2.100], [6.22 GB], [3.0 GB/s],
  [SFT, 14B], [1.026], [1.041], [3.52 GB], [3.4 GB/s],
  [Pretraining, 14B], [1.003], [1.041], [3.52 GB], [3.5 GB/s],
)

*NVLink is 0–4% faster.* Spread over a step, the traffic needs about 3.5 GB/s, a quarter of what the PCIe pair delivers. This is a small, unoptimized setup (eager mode, activation checkpointing, batch of one); larger batches would move more data per step, but they also compute longer.

== Looking for a Workload That Needs NVLink

Qwen3.8-27B with shared prefixes gains at most a third from NVLink. Two more experiments look for a larger gap: prompts that share nothing, so that every request runs its full prefill, and smaller models at high concurrency. Each bar is NVLink's output throughput divided by PCIe's, at TP=2:

#figure(
  fig.fig-scenarios(),
  caption: [NVLink over PCIe at TP=2 on the A100s: output throughput ratio. "c16" is concurrency 16; "distinct" prompts share only their first token. The 32B and 4B runs use distinct prompts.],
) <fig-scenarios>

*Distinct prompts widen the gap a little* for long inputs: at 8K from 1.23× to 1.37×, at 32K from 1.22× to 1.34×. Each request now runs its full prefill, with its large all-reduces. Absolute throughput falls by a factor of 7 to 14 on both pairs, so most of that time is compute.

*Small models at high concurrency widen it much more.* Qwen3-4B goes from 1.02× at concurrency 1 to 1.78× at 128, and a repeat with new prompts gave 1.80×. Qwen3-32B reaches only 1.41×.

*The difference is the ratio of communication to compute.* An all-reduce carries hidden size × 2 bytes per token, while a token costs about 2 × parameters in FLOPs. Per forward pass and token:

#table(
  columns: 5,
  table.header([], [Layers], [Hidden size], [All-reduced], [Compute]),
  [Qwen3-4B], [36], [2560], [369 KB], [8 GFLOP],
  [Qwen3-32B], [64], [5120], [1.3 MB], [64 GFLOP],
)

The small model moves 2.3 times as much data per FLOP. High concurrency then pushes its messages past 64 KiB, where bandwidth matters.

== Roofline

The A100 80 GB PCIe has 312 TFLOPS of dense BF16 and 1,935 GB/s, so its ridge point is 161 FLOPs per byte, which the linear layers reach at about 85 tokens per step. It has twice the A6000's compute but 2.5 times its bandwidth, so it turns compute-bound at fewer tokens. Only the concurrency-128 runs pass the ridge; *the serving sweeps, at 1 to 16 tokens per step, are memory-bound*:

#figure(
  fig.fig-a100-roofline(),
  caption: [Roofline of the A100 for Qwen3.8-27B, from spec-sheet peaks and the nccl-tests all-reduce times of @fig-allreduce. Left: one GPU; c1 to c128 are decode steps at that concurrency, MTP off. Right: the tokens per second a step of each size can reach. A dashed line counts only the step's 128 all-reduces over that link, as if compute and memory were free; a thick line adds them to the GPU's time.],
) <fig-a100-roofline>

A decode step's floor is 13.9 ms on one GPU and 6.9 ms per GPU at TP=2.

*Decode of one sequence is latency-bound on both links.* 128 all-reduces of 10 KiB take 1.0 ms over NVLink and 1.1 ms over PCIe, about 13% of a step at the floor. Two things follow:

- The two pairs decoded at the same speed at concurrency 1.
- Even over NVLink, TP=2 decodes *at most 1.75 times* as fast as one A100. Measured, it serves 1.51–1.52 times as much as TP=1 at concurrency 1 (@fig-a100-tp).

*With more tokens per step, PCIe becomes bandwidth-bound.* At 16 tokens the messages are 160 KiB:

#table(
  columns: 3,
  table.header([At 16 tokens per step], [NVLink], [PCIe]),
  [All-reduces], [1.15 ms], [4.6 ms],
  [Step floor], [8.1 ms], [11.5 ms],
)

The floors differ by a factor of 1.42, but the measured gain at concurrency 16 was smaller, *8–33%*. Real steps run well above the floor, 25 ms at 8K over NVLink, and the link's extra 3.4 ms is a smaller share of them.

*In prefill, PCIe takes longer than the compute.* Per token:

- all-reduces: 8 µs over NVLink, 96 µs over PCIe;
- compute: 82 µs.

For 8192-token chunks the PCIe link alone allows 10,300 tok/s, against a compute ceiling of 12,200. The two run one after the other, so the PCIe pair prefills at about 5,600 tok/s, against 11,100 over NVLink: *less than one A100 at its peak*.

The distinct-prompt runs test this. The model says PCIe costs 89 µs per token more than NVLink. With 32 requests at concurrency 16:

#table(
  columns: 4,
  table.header([Input], [Tokens prefilled], [PCIe's extra time, model], [PCIe's extra time, measured]),
  [8K], [262K], [23 s], [20.7 s (77.0 s against 56.3 s)],
  [32K], [1.05M], [93 s], [79 s],
)

*So the link costs about what the roofline predicts.* The throughput ratio is 1.37, not 2, because compute ran far below its roof: the NVLink pair prefilled at about 4,700 tok/s, under 40% of its ceiling, so the same 89 µs is a smaller share of each token.

= RTX A6000: One GPU per Socket

This is Machine 1 of #xref("gpu-server-topology"). Each GPU has a PCIe 3.0 x16 link, 15.75 GB/s per direction on paper, and a transfer between them crosses PCIe, CPU0, UPI, CPU1 and PCIe again.

All serving runs on this machine:

- use an FP8 KV cache, FlashInfer attention, prefix caching, MTP with 3 draft tokens and `max_num_seqs=8`;
- run TP=2 with `NCCL_P2P_LEVEL=SYS` and `--disable-custom-all-reduce`: vLLM's own all-reduce hung at startup on this machine, so NCCL does all of the communication;
- use synthetic prompts, one per length, so after a warmup request its prefix is in the cache;
- have 8 requests of 128 output tokens per point, at temperature 0.

Throughput is output tokens divided by wall time, prefill included.

== KV Cache Capacity

#table(
  columns: 4,
  table.header([], [Weights per GPU], [KV memory per GPU], [KV cache size]),
  [TP=1], [29.68 GiB], [10.64 GiB], [276,323],
  [TP=2], [15.09 GiB], [25.65 GiB], [1,331,743],
)

*TP=2 has 4.8 times the capacity*: each GPU has 2.4 times the free memory, and holds only half of each token's KV and each sequence's GDN state. TP=1 fits two 128K requests (2.09×), which matters below.

== Serving at TP=1 and TP=2

#figure(
  fig.fig-a6000-decode(),
  caption: [Steady decode speed of one request (tokens/s) on the A6000s, 128 output tokens per request.],
) <fig-a6000-decode>

TP=2 decodes *1.33 to 1.66 times* as fast as TP=1 at every point:

- The lead grows with the input, from about 1.4 times at 1K to 1.6 at 128K. Each GPU reads half of every sequence's KV, and long inputs make attention a larger share of the step.
- Both are slower at 1K, where MTP accepts 2.7 draft tokens per step instead of 3.5–3.9.
- At 128K and concurrency 8, TP=1 runs out of KV and preempts a request. The figure leaves out the recompute, but output throughput falls to 6 tok/s.

In output throughput, prefill included, TP=2 serves 1.3 to 1.6 times as much as TP=1 on twice the GPUs. *Per GPU, a single card does more work.*

The usual per-request decode speed, output tokens after the first divided by the time after the first token, *counts waiting as decoding*. With chunked prefill, a decode step that shares the GPU with another request's prefill chunk lasts as long as that chunk. At 128K and concurrency 2:

+ On TP=2, one request got its first token at 3.4 s, then waited 2.7 s while the other prefilled.
+ On TP=1, both requests prefilled in the same steps and never waited.
+ By the usual measure, TP=1 came out ahead: 52.2 against 44.7 tok/s.

So the figure leaves out every gap between tokens longer than 0.2 s. A normal step took at most 164 ms and a stall at least 0.53 s, so any threshold in between gives the same numbers.

#callout(kind: "info", title: "Why FlashInfer and FP8")[
  An earlier TP=2 run, at concurrency 1 with 128K input, decoded at 24.6 tok/s on vLLM's default `FLASH_ATTN` backend with a BF16 KV cache. The FlashInfer backend alone raised it to 82.9 tok/s, and an FP8 KV cache on top to 88.9 tok/s, with identical output text. Most of the gain is the backend; FP8 adds 7% and nearly doubles the KV capacity.
]

== Profiling

Nsight Systems traced TP=2 at 128K input and 1024 output tokens. The numbers below cover 80 steady decode steps at each concurrency, averaged over the two GPUs. Each step also verifies MTP drafts, so it covers 4 tokens of every sequence.

#figure(
  fig.fig-a6000-step(),
  caption: [One decode step on the A6000s at TP=2, 128K input, in ms. Compute and NCCL never overlapped.],
) <fig-a6000-step>

- *Linear layers*: about 30 ms at any concurrency. A step reads the weights once, whatever the batch.
- *Full attention*: grows from 8 to 33 ms, because each sequence reads its own 128K tokens of KV.
- *NCCL*: grows from 5.6 to 13.1 ms. Every step runs 138 all-reduces and 7 all-gathers, and the mean all-reduce rises from 32–40 µs at concurrency 2 to 74–82 µs at 8.

NCCL is 11–15% of the step and never overlaps compute, so removing it entirely would make concurrency 8 at most 1.17 times faster. *On this machine, attention costs more than PCIe.*

== Peer-to-Peer and NCCL

A large copy over PCIe 3.0 x16 normally reaches about 12.6 GB/s. On this machine, the peer copy runs at 9.75 GB/s from GPU0 to GPU1 and 10.25 GB/s back, 62–65% of the 15.75 GB/s rate, and 19.24 GB/s with both directions at once. Copies to and from host memory get only 8.0–8.7 GB/s (@fig-host-copy).

Even a copy between a GPU and its own socket's memory gets only about half the link rate, less than the copy across sockets. Intel PCM, sampled during the peer copy, rules out the obvious causes:

- both links stayed at PCIe 3.0 x16;
- UPI ran at about 42% of its capacity;
- the target root port wrote about 9.8 GB/s, the same as the copy;
- host memory traffic stayed small, so the data was not staged in DRAM.

So the result is odd, and what holds every copy on this machine to 50–65% of the link is still an open question.

#table(
  columns: 3,
  table.header([All-reduce], [SHM (default)], [P2P (`NCCL_P2P_LEVEL=SYS`)]),
  [`p2p_topo`, FP32, 64 MiB], [5.54 GB/s], [7.04 GB/s],
  [nccl-tests, BF16, 128 MiB], [5.59 GB/s], [7.03 GB/s],
  [nccl-tests, 10 KiB, CUDA Graph], [14.5 µs], [9.4 µs],
  [nccl-tests, 40 KiB, CUDA Graph], [23.3 µs], [17.3 µs],
)

*P2P gives 27% more bandwidth*, and a quarter to a third less latency for small messages. In serving, with MTP off, a BF16 KV cache and one request at a time, setting `NCCL_P2P_LEVEL=SYS` on TP=2:

- cut time to first token by 7–10% at every length;
- raised decode speed by 2.4–3.1%;
- raised output throughput by 3.9–8.8%.

*Most of the gain is in prefill*, where the messages are large.

#hint[
  Check that cross-socket P2P works before setting `NCCL_P2P_LEVEL=SYS`. On this machine it once failed with DMA errors until a reboot. nccl-tests verifies every result and prints `#wrong`.
]

== Roofline

The RTX A6000 has 154.8 TFLOPS of dense BF16 and 768 GB/s of memory bandwidth. Its ridge point is 202 FLOPs per byte. At 1.9 FLOPs per byte per token, Qwen3.8-27B's linear layers reach it at about 106 tokens per step: below that, *a step takes as long as reading the weights*, however many tokens it holds. The serving runs above put 8 to 32 tokens in a step, concurrency 2 to 8 with 4 tokens of each sequence, so decode is memory-bound:

#figure(
  fig.fig-a6000-roofline(),
  caption: [Roofline of the RTX A6000 for Qwen3.8-27B, from spec-sheet peaks and the nccl-tests all-reduce times of @fig-allreduce. Left: one GPU; c2 and c8 are decode steps at concurrency 2 and 8 with MTP. Right: the tokens per second a step of each size can reach. A dashed line counts only the step's 128 all-reduces over that link, as if compute and memory were free; a thick line adds them to the GPU's time.],
) <fig-a6000-roofline>

A decode step reads the weights:

- at TP=1, 26.9 GB, at least 35.0 ms;
- at TP=2, 13.4 GB per GPU, at least 17.5 ms.

*The link takes back part of that halving*: 128 all-reduces of 10 KiB take 1.2 ms over this PCIe pair, and at 32 tokens, concurrency 8 with MTP, 7.9 ms.

*In prefill the link is as slow as the compute*: per token, 182 µs of all-reduce against 165 µs of compute. For 8192-token chunks the link alone allows 5,500 tok/s against a compute ceiling of 6,000 for the pair, so TP=2 prefills at about 2,900 tok/s, *less than one A6000 at its peak*.

Adding the KV each step reads, the model gives TP=2 over TP=1 for the steady decode speeds of @fig-a6000-decode:

#table(
  columns: 4,
  table.header([], [Concurrency 2], [4], [8]),
  [2K, model], [1.67], [1.52], [1.39],
  [2K, measured], [1.45], [1.40], [1.34],
  [128K, model], [1.73], [1.67], [1.67],
  [128K, measured], [1.61], [1.66], [1.62],
)

*The model follows the measured trend.*

- At short inputs the gain shrinks with concurrency, because the weights take the same time every step while the all-reduces grow.
- At 128K the KV reads, which TP halves, hold it near 1.65.
- At 2K the model runs high: it leaves out costs that do not halve, and in the trace NCCL took 1.6 times the model's estimate, 13.1 ms per step against 7.9 at concurrency 8.

= Takeaways

- *At low concurrency, TP over PCIe costs little.* Decode all-reduces are small and take about 10 µs on any link. NVLink helps time to first token, not decode speed.
- *NVLink pays off with larger batches and prefill-heavy traffic*: 8–33% more throughput for Qwen3.8-27B at concurrency 16, and up to 1.8 times for a 4B model at 128.
- *A roofline with the link added explains most of this.* Decode is memory-bound and its all-reduces latency-bound, about 1 ms per step on any link. Prefill is compute-bound, and there PCIe's all-reduces take about as long as the compute.
- *On the A6000 server, NCCL was 11–15% of a decode step*; full attention over long contexts cost more.
- *On a two-GPU cross-socket pair, `NCCL_P2P_LEVEL=SYS` is worth setting* once P2P is known to work. On four GPUs, measure first.
- *With a hybrid model like Qwen3.8-27B, read "GPU KV cache size" as how many max-length requests fit*; it changes with `max_model_len` even when the memory does not. Every running sequence holds GDN state, however short.
