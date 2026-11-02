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

#xref("gpu-server-topology") read the topology of two servers. This post measures them: *how fast each path between two GPUs moves data*, and *how much that matters when the server runs an LLM*.

- Machine 1: 2 × RTX A6000 48 GB in a 2 × Xeon Gold 6248R server, one GPU per socket. The GPUs only meet over PCIe 3.0 and UPI (`SYS`).
- Machine 2: 4 × A100 80 GB PCIe. GPU0–1 and GPU2–3 are NVLink bridge pairs (`NV12`), one pair per socket; every other pair is `SYS`.

The model is Qwen3.8-27B with INT8 weights and BF16 activations (W8A16), served by vLLM 0.32 with tensor parallelism (TP). Each data point is a single run with 4 to 256 requests, so *differences of a few percent are within noise*.

= Background

== Measuring a Link

A CUDA peer copy (`cudaMemcpyPeerAsync`) moves a 256 MiB buffer from one GPU to the other, one way, or both ways at once. It measures the path itself: no reduction and no protocol, so it is the number to *compare with the link's rated speed*.

An NCCL all-reduce is *what tensor parallelism actually runs*, and two tools measure it here:

- `p2p_topo`, a short script on `torch.distributed`: FP32, 1 to 64 MiB, timed on the host. It also sweeps `NCCL_P2P_LEVEL` (below).
- NVIDIA's #link("https://github.com/NVIDIA/nccl-tests")[nccl-tests] `all_reduce_perf`: BF16, 8 B to 128 MiB, with and without CUDA Graphs (`-G 1`), and it checks every result.

nccl-tests prints two bandwidths. `algbw` is bytes divided by time. `busbw` multiplies it by 2(_n_ − 1)/_n_, the share of the data each link carries in a ring all-reduce over _n_ GPUs, so that it *compares with the link's speed whatever _n_ is*. With 2 GPUs the factor is 1 and the two are equal; with 4 it is 1.5.

=== P2P or SHM

NCCL moves data between two GPUs in one of two ways. With the *P2P* transport, a GPU reads or writes the other GPU's memory directly, over NVLink or PCIe. With *SHM*, the sender copies into a buffer in host memory and the receiver copies it out.

#figure(fig.fig-transports(), caption: [The two transports between GPUs on different sockets. Orange and blue mark the parts the data passes through.]) <fig-transports>

Neither transport uses the CPU cores. In both, NCCL kernels on the GPUs read and write the data themselves, and no core copies anything. They differ in which parts of the CPU the data crosses.

*P2P never touches a memory controller or DRAM.* A peer write leaves GPU0 over PCIe, enters CPU0 at a host bridge, rides the on-die fabric and UPI to CPU1, and leaves through CPU1’s host bridge into GPU1. The CPUs only route it, and on the A6000 server Intel PCM saw little DRAM traffic during a peer copy (below). Over NVLink, P2P skips the CPUs entirely.

*SHM goes into DRAM and out again.* GPU0 writes into a buffer through a memory controller, then GPU1 reads it back out. The data crosses PCIe twice, out of GPU0 and into GPU1, and adds a DRAM round trip, so SHM is slower. It does work wherever the GPUs can reach host memory, which is why NCCL falls back to it.

NCCL uses P2P only for pairs *no farther apart than `NCCL_P2P_LEVEL`*. It measures distance on its own ladder, close to the codes of `nvidia-smi topo -m` but without `NODE`: any path through one CPU counts as `PHB`. When the variable is unset, NCCL's source (`ncclTopoCheckP2p` in `paths.cc`) uses `PXB`, so *P2P stops at PCIe switches*. The one exception is an AMD CPU with at most two GPUs, which gets `SYS`.

Both machines here have Intel CPUs, so *pairs on different sockets fall back to SHM*. We raised the level from `PXB` to `SYS`, which lets them use P2P:

#figure(fig.fig-p2p-level(), caption: [`NCCL_P2P_LEVEL` cuts NCCL's distance ladder. The default allows P2P up to `PXB`; `SYS` allows every path. The NVLink pair uses P2P either way.]) <fig-p2p-level>

NCCL's debug log names the transport:

#table(
  columns: 3,
  table.header([Pair], [Default], [`NCCL_P2P_LEVEL=SYS`]),
  [NVLink pair], [`P2P/CUMEM/read`], [`P2P/CUMEM/read`],
  [Across sockets], [`SHM/direct/direct`], [`P2P/CUMEM`],
)

`PIX` and `PXB` behaved like the default on every cross-socket pair.

=== What Tensor Parallelism Sends

With TP, each layer ends in two all-reduces, one after the token mixer and one after the MLP. Each carries the layer's output for every token in the step: tokens × hidden size × 2 bytes. Qwen3.8-27B has a hidden size of 5120, so

- one decode step of one sequence all-reduces 10 KiB, twice per layer;
- one prefill chunk of 8192 tokens, vLLM's `max_num_batched_tokens` here, all-reduces 80 MiB, twice per layer.

*Decode sends many tiny messages and prefill sends large ones*, which explains most of the results below.

== GDN State in Qwen3.8-27B

Qwen3.8-27B has the Qwen3.5 architecture (#xref("qwen3-5")): of its 64 layers, every fourth is full attention and the other 48 are Gated DeltaNet (GDN), a linear attention. The two kinds keep different state for each sequence.

A full-attention layer keeps K and V for every past token: 4 KV heads × 256 × 2 = 2048 values. With an FP8 KV cache, the 16 such layers hold 32 KiB per token, and *the total grows with the sequence*.

A GDN layer keeps *a state of fixed size* instead:

- a recurrent state of 48 heads × 128 × 128 in FP32 (the config's `mamba_ssm_dtype`): 3 MiB;
- a convolution state, the last 3 inputs of its short convolution over 10,240 channels in BF16: 60 KiB.

Over the 48 GDN layers that is 147 MiB per sequence, *as much as 4,700 tokens of full-attention KV*. A 100-token sequence and a 128K-token one *carry the same 147 MiB*. TP splits the heads of both kinds, so at TP=2 each GPU holds 73 MiB of GDN state per sequence and 16 KiB of KV per token.

== One Pool for Both

vLLM keeps both in one pool of pages, so that memory freed by one kind can go to the other. That needs one page size for both, and vLLM gets it by *sizing attention blocks to the GDN state*. At TP=2 with FP8 KV, per layer and per GPU:

#table(
  columns: 2,
  table.header([], [Bytes]),
  [GDN state: 24 × 128 × 128 × 4 B + 30 KiB], [1,603,584],
  [Attention KV for one token: 2 × 256 × 2 × 1 B], [1,024],
  [Attention KV for one block of 1568 tokens], [1,605,632],
)

1568 is *the smallest multiple of 16 tokens whose KV fills a GDN page*, and vLLM pads the GDN page by the difference:

```text
Setting attention block size to 1568 tokens to ensure that attention page size is >= mamba page size.
Padding mamba page size by 0.13% to ensure that mamba page size and attention page size are exactly equal.
```

*The same arithmetic gives every block size in the logs.* BF16 KV takes 2 bytes per value, so the block is 784 tokens. With MTP on, the convolution state keeps 3 more rows for the draft tokens, and the blocks become 1600 (FP8) and 800 (BF16). At TP=4 the state and the KV both halve, and the block stays at 1568.

vLLM then sorts the layers into groups of equal size: one group of the 16 full-attention layers, and the 48 GDN layers in three groups of 16. The log shows `kv cache group sizes (1568, 1568, 1568, 1568)`. A block is one page in each of the 16 layers of a group, 25.7 MB at TP=2, and *any group can take any free block*:

#figure(fig.fig-kv-pool(), caption: [One pool for both kinds of state, TP=2 with FP8 KV. Attention takes a block per 1568 tokens; GDN takes the same number of blocks for any sequence, two per group with prefix caching.]) <fig-kv-pool>

A sequence takes *one attention block per 1568 tokens* and *a fixed number of GDN blocks*. With prefix caching off that is one block per GDN group, three in all. With prefix caching on (`mamba_cache_mode=align`), vLLM also keeps GDN states at block boundaries, so that a cached prefix can resume the recurrence, and it budgets two blocks per group, six in all.

=== What "GPU KV Cache Size" Counts

At startup vLLM prints:

```text
Available KV cache memory: 52.89 GiB
GPU KV cache size: 3,208,045 tokens, Maximum concurrency for 132,096 tokens per request: 24.29x
```

The 3,208,045 is *not a count of token slots*. vLLM divides the pool by what one request of `max_model_len` needs, then multiplies back:

+ 52.89 GiB / 25.7 MB = 2,210 blocks.
+ A request of 132,096 tokens takes 85 attention blocks and 6 GDN blocks: 91.
+ 2,210 / 91 = 24.29 such requests, and 24.29 × 132,096 = 3,208,045 tokens.

This *reproduces the logged number exactly* on every run I checked, including those with prefix caching off, where the GDN part is 3 blocks.

== Why `max_num_seqs` Changes It

Four runs on the A100 server differ only in `max_num_seqs`. Same GPUs (0 and 1), TP=2, FP8 KV, prefix caching on:

#table(
  columns: 5,
  table.header([`max_num_seqs`], [CUDA graphs], [Equivalent utilization], [KV memory], [KV cache size]),
  [1], [2], [0.8982], [52.89 GiB], [3,208,045],
  [8], [5], [0.8958], [52.71 GiB], [3,197,884],
  [16], [7], [0.8945], [52.61 GiB], [3,190,626],
  [128], [35], [0.8814], [51.45 GiB], [3,120,949],
)

Tokens per GiB stay the same; *the memory shrinks*. vLLM captures a CUDA graph for each decode batch size it may run, up to 2 × `max_num_seqs` (1, 2, 4, 8, then every 8), which matches the graph counts in the logs. Since v0.21 it *measures the memory of those graphs before sizing the KV cache*, and logs the result as the `--gpu-memory-utilization` the setting is equivalent to without graph profiling. From 0.8982 to 0.8814 is about 1.3 GiB on an 80 GB card, most of the 1.44 GiB drop.

GDN state does not change the pool size; it shows up at run time. *Each running sequence holds its GDN blocks however short it is.* With 128 running sequences of 1K tokens, the six blocks vLLM budgets for each come to 768 blocks, a third of the 2,150-block pool, against 128 blocks of attention KV. The token count assumes a few long requests, and *many short ones fill the pool faster than it suggests*.

= RTX A6000: One GPU per Socket

This is Machine 1 of #xref("gpu-server-topology"). Each GPU has a PCIe 3.0 x16 link, 15.75 GB/s per direction on paper, and a transfer between them crosses PCIe, CPU0, UPI, CPU1 and PCIe again.

All serving runs on this machine use an FP8 KV cache, FlashInfer attention, prefix caching, MTP with 3 draft tokens and `max_num_seqs=8`. TP=2 runs with `NCCL_P2P_LEVEL=SYS` and `--disable-custom-all-reduce`: vLLM's own all-reduce hung at startup on this machine, so *NCCL does all of the communication*.

The prompts are synthetic, and each length uses one prompt over and over, so *after a warmup request its prefix is in the cache*. Every point is 8 requests of 128 output tokens at temperature 0. Throughput is output tokens divided by wall time, prefill included.

== KV Cache Capacity

#table(
  columns: 4,
  table.header([], [Weights per GPU], [KV memory per GPU], [KV cache size]),
  [TP=1 (GPU1)], [29.68 GiB], [10.64 GiB], [276,323],
  [TP=2], [15.09 GiB], [25.65 GiB], [1,331,743],
)

*TP=2 has 4.8 times the capacity.* Each GPU has 2.4 times the free memory, and holds only half of each token's KV and each sequence's GDN state. TP=1 fits two 128K requests (2.09×), which matters below.

== Serving at TP=1 and TP=2

#figure(fig.fig-a6000-decode(), caption: [Steady decode speed of one request (tokens/s) on the A6000s, 128 output tokens per request. Steps stalled by another request's prefill are left out.]) <fig-a6000-decode>

*TP=2 decodes 1.33 to 1.66 times as fast as TP=1* at every point:

- The lead grows with the input, from about 1.4 times at 1K to 1.6 at 128K. Each GPU reads half of every sequence's KV, and long inputs make attention a larger share of the step.
- Both are slower at 1K, where MTP accepts 2.7 draft tokens per step instead of 3.5–3.9.
- At 128K and concurrency 8, TP=1 runs out of KV and preempts a request. The figure leaves the recompute out, but output throughput falls to 6 tok/s.

In output throughput, prefill included, *TP=2 serves 1.3 to 1.6 times as much as TP=1* on twice the GPUs, so *per GPU, a single card does more work*.

Measuring decode under concurrency takes some care. The usual per-request decode speed, output tokens after the first divided by the time after the first token, *counts waiting as decoding*. With chunked prefill, a decode step that shares the GPU with another request's prefill chunk lasts as long as that chunk. At 128K and concurrency 2:

+ On TP=2, one request got its first token at 3.4 s, then waited 2.7 s while the other prefilled.
+ On TP=1, both requests prefilled in the same steps and never waited.
+ By the usual measure, TP=1 came out ahead: 52.2 against 44.7 tok/s.

The figure therefore leaves out every gap between tokens longer than 0.2 s. A normal step took at most 164 ms and a stall at least 0.53 s, so *any threshold in between gives the same numbers*.

#callout(kind: "info", title: "Why FlashInfer and FP8")[
  An earlier TP=2 run, at concurrency 1 with 128K input, decoded at 24.6 tok/s on vLLM's default `FLASH_ATTN` backend with a BF16 KV cache. The FlashInfer backend alone raised it to 82.9 tok/s, and an FP8 KV cache on top to 88.9 tok/s, with identical output text. *Most of the gain is the backend*; FP8 adds 7% and nearly doubles the KV capacity.
]

== Profiling

An Nsight Systems trace of TP=2 at 128K input and 1024 output tokens, over 80 steady decode steps at each concurrency, averaged over the two GPUs. Each step also verifies MTP drafts, so it covers 4 tokens of every sequence.

#figure(fig.fig-a6000-step(), caption: [One decode step on the A6000s at TP=2, 128K input, in ms. Compute and NCCL never overlapped.]) <fig-a6000-step>

*The linear layers take about 30 ms at any concurrency*: a step reads the weights once, whatever the batch. *Full attention grows from 8 to 33 ms*, because each sequence reads its own 128K tokens of KV. NCCL grows from 5.6 to 13.1 ms: every step runs 138 all-reduces and 7 all-gathers, and the mean all-reduce rises from 32–40 µs at concurrency 2 to 74–82 µs at 8.

*NCCL is 11–15% of the step* and never overlaps compute. Removing it entirely would make concurrency 8 *at most 1.17 times faster*. On this machine PCIe costs something, but *attention costs more*.

== Peer-to-Peer and NCCL

A peer copy runs at 9.75 GB/s from GPU0 to GPU1 and 10.25 GB/s back, and 19.24 GB/s with both directions at once. That is *about 62% of the PCIe 3.0 x16 rate*. Intel PCM, sampled during the copy, rules out the obvious causes:

- both links stayed at PCIe 3.0 x16;
- UPI ran at about 42% of its capacity;
- the target root port wrote about 9.8 GB/s, the same as the copy;
- host memory traffic stayed small, so the data was not staged in DRAM.

*Why it stops at 9.75 GB/s is still open.*

#table(
  columns: 3,
  table.header([All-reduce], [SHM (default)], [P2P (`NCCL_P2P_LEVEL=SYS`)]),
  [`p2p_topo`, FP32, 64 MiB], [5.54 GB/s], [7.04 GB/s],
  [nccl-tests, BF16, 128 MiB], [5.59 GB/s], [7.03 GB/s],
  [nccl-tests, 10 KiB, CUDA Graph], [14.5 µs], [9.4 µs],
  [nccl-tests, 40 KiB, CUDA Graph], [23.3 µs], [17.3 µs],
)

*P2P gives 27% more bandwidth*, and a quarter to a third less latency for small messages. In serving, with MTP off, a BF16 KV cache and one request at a time, setting `NCCL_P2P_LEVEL=SYS` on TP=2 *cut time to first token by 7–10%* at every length, raised decode speed by 2.4–3.1%, and output throughput by 3.9–8.8%. *Most of the gain is in prefill*, where the messages are large.

#hint[
  Check that cross-socket P2P works before setting `NCCL_P2P_LEVEL=SYS`. On this machine it once failed with DMA errors until a reboot. nccl-tests verifies every result and prints `#wrong`.
]

= A100: NVLink Pairs and Cross-Socket PCIe

This is Machine 2 of #xref("gpu-server-topology"). Each A100 has a PCIe 4.0 x16 link, 31.5 GB/s per direction on paper, and each bridge pair has 12 NVLinks, 300 GB/s per direction.

#figure(fig.fig-copy-bw(), caption: [One-way peer copy of 256 MiB between two GPUs, with the A6000 pair for comparison.]) <fig-copy-bw>

The serving runs here *keep MTP off*, so that draft acceptance does not differ between runs, and otherwise match the A6000 setup: FP8 KV, FlashInfer, prefix caching, `NCCL_P2P_LEVEL=SYS`, no custom all-reduce. The NVLink pair is GPU0–1 and the PCIe pair is GPU1–2, on different sockets. Every point has 32 requests, 4 at concurrency 1.

== KV Cache Capacity

#table(
  columns: 5,
  table.header([], [`max_num_seqs`], [Weights per GPU], [KV memory per GPU], [KV cache size]),
  [TP=2, NVLink (GPU0–1)], [1], [14.61 GiB], [52.89 GiB], [3,208,045],
  [TP=2, PCIe (GPU1–2)], [1], [14.61 GiB], [55.05 GiB], [3,338,690],
  [TP=4], [16], [7.37 GiB], [59.97 GiB], [7,273,989],
)

There is no TP=1 run on this machine. *TP=4 holds 2.3 times as many tokens as TP=2*: more free memory per GPU, and half the bytes per token.

With identical settings, *the NVLink pair gets 2.2 GiB less KV memory* than the PCIe pair. I have not isolated why; NCCL buffers for the NVLink transport are one candidate.

== Serving at TP=2: NVLink vs PCIe

At concurrency 1 *the two pairs decode at the same speed*: within 0.7% at every length, 65.8 against 65.4 tok/s at 128K. *NVLink cuts time to first token by 6–26%*, and the whole request by 2–5%.

The message sizes explain it. In nccl-tests, *a 10 KiB all-reduce takes about 10 µs on either link*, while 80 MiB takes 0.5 ms over NVLink and 6 ms over PCIe:

#figure(fig.fig-allreduce(), caption: [All-reduce time against message size, nccl-tests with BF16, 2 GPUs and CUDA Graphs. Cross-socket pairs use `NCCL_P2P_LEVEL=SYS`.]) <fig-allreduce>

Below about 64 KiB *the time is fixed cost*: launch, synchronization and a round trip, which bandwidth cannot shorten. A decode step of one sequence sends only such messages, 128 of them at about 10 µs, some 1.3 ms of a 15 ms token on either link. Prefill sends 80 MiB messages, *where NVLink's bandwidth counts*.

*More sequences make the decode messages larger, and the gap opens.* The output throughput gain of NVLink over PCIe:

#figure(fig.fig-a100-gain(), caption: [NVLink (GPU0–1) over PCIe (GPU1–2): output throughput gain at TP=2, 128 output tokens. Concurrency 1 runs with `max_num_seqs=1`, 2–8 with 8, and 16 with 16.]) <fig-a100-gain>

At every length *the gain grows with concurrency*, up to 8–33% at 16. At 16 sequences a decode message is 160 KiB, where PCIe takes about four times as long as NVLink. *The gain shrinks at 128K*, where attention dominates the step, as on the A6000.

TP=4 spans both pairs, so every all-reduce crosses the sockets. At concurrency 16:

#table(
  columns: 4,
  table.header([Input], [TP=2, PCIe], [TP=2, NVLink], [TP=4]),
  [1K], [282.8 tok/s], [377.3 tok/s], [435.0 tok/s],
  [8K], [421.1 tok/s], [513.8 tok/s], [506.1 tok/s],
  [32K], [176.4 tok/s], [216.1 tok/s], [262.5 tok/s],
  [128K], [140.6 tok/s], [151.9 tok/s], [190.8 tok/s],
)

*TP=4 is faster at long inputs*, where it splits attention four ways, and no faster at 8K. *Per GPU, a TP=2 NVLink pair does better* at every length.

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

All-reduces are FP32 with 64 MiB messages. NVLink copies at 93% of its 300 GB/s; a cross-socket copy reaches 59% of PCIe 4.0, about the same share as on the A6000. In bandwidth *the gap is 15 times for copies and 13.5 times for all-reduce*. `NCCL_P2P_LEVEL=SYS` *adds 3–6% on cross-socket pairs*, much less than the 27% on the A6000, and nothing on NVLink pairs, which use P2P anyway.

nccl-tests agrees on the bandwidth. With CUDA Graphs, which vLLM uses for decode, *cross-socket P2P at 64 MiB rises* from 12.2–12.5 to 13.1–13.5 GB/s, while *NVLink drops* from 174 to 148–155 GB/s; I have not found why. For small messages, `SYS` cuts latency across sockets: on GPU1–2, a 40 KiB all-reduce takes 12.7 µs instead of 18.1.

*Four GPUs behave differently.* Over GPU0–3, the default mixes NVLink P2P inside the pairs with SHM between them, and reaches 34.5 GB/s `busbw` at 64 MiB. With `SYS` everything is P2P, and it drops to 32.5 GB/s; a 1 MiB all-reduce takes 155 µs instead of 109. Set it for a cross-socket pair, but *measure before setting it for a mixed topology*.

== Training

Short TP=2 training runs, 16 steps each, of one 1024-token sequence per step. LoRA uses Qwen3-32B. Full fine-tuning (SFT) and continued pretraining use Qwen3-14B, because the FP16 weights, gradients and AdamW states of 32B need about 122 GiB per GPU at TP=2.

#table(
  columns: 5,
  table.header([], [NVLink, s/step], [PCIe, s/step], [Data per GPU per step], [Average rate]),
  [LoRA, 32B], [2.106], [2.100], [6.22 GB], [3.0 GB/s],
  [SFT, 14B], [1.026], [1.041], [3.52 GB], [3.4 GB/s],
  [Pretraining, 14B], [1.003], [1.041], [3.52 GB], [3.5 GB/s],
)

*NVLink is 0–4% faster.* Spread over a step, the traffic needs about 3.5 GB/s, *a quarter of what the PCIe pair delivers*. This is a small, unoptimized setup (eager mode, activation checkpointing, batch of one); larger batches would move more data per step, but they also compute longer.

== Looking for a Workload That Needs NVLink

Qwen3.8-27B with shared prefixes *gains at most a third from NVLink*. Two more experiments looked for a larger gap: prompts that share nothing, so that every request runs its full prefill, and smaller models at high concurrency. Each bar is NVLink's output throughput divided by PCIe's, at TP=2:

#figure(fig.fig-scenarios(), caption: [NVLink over PCIe at TP=2 on the A100s: output throughput ratio. "c16" is concurrency 16; "distinct" prompts share only their first token. The 32B and 4B runs use distinct prompts.]) <fig-scenarios>

*Distinct prompts widen the gap a little* for long inputs: at 8K from 1.23× to 1.37×, at 32K from 1.22× to 1.34×. Each request now runs its full prefill, with its large all-reduces. Absolute throughput falls by a factor of 7 to 14 on both pairs, so *most of that time is compute*.

*Small models at high concurrency widen it much more.* Qwen3-4B goes from 1.02× at concurrency 1 to 1.78× at 128, and a repeat with new prompts gave 1.80×. Qwen3-32B reaches only 1.41×.

*The ratio of communication to compute* explains it. An all-reduce carries hidden size × 2 bytes per token, while a token costs about 2 × parameters in FLOPs. Per forward pass and token, Qwen3-4B (36 layers, hidden size 2560) all-reduces 369 KB for 8 GFLOP, and Qwen3-32B (64 layers, hidden size 5120) 1.3 MB for 64 GFLOP: *the small model moves 2.3 times as much data per FLOP*. High concurrency then pushes its messages past 64 KiB, where bandwidth counts.

= Takeaways

- *At low concurrency, TP over PCIe costs little.* Decode all-reduces are small, and take about 10 µs on any link. NVLink helps *time to first token, not decode speed*.
- *NVLink pays off as batches grow and with prefill-heavy traffic*: 8–33% more throughput for Qwen3.8-27B at concurrency 16, and up to 1.8 times for a 4B model at 128.
- On the A6000 server, NCCL was 11–15% of a decode step. *Full attention over long contexts cost more than communication.*
- On a two-GPU cross-socket pair, `NCCL_P2P_LEVEL=SYS` *is worth setting once P2P is known to work*. *Do not assume the same for four GPUs.*
- With a hybrid model like Qwen3.8-27B, read "GPU KV cache size" as *how many max-length requests fit*. Every running sequence holds GDN state, however short, and `max_num_seqs` costs CUDA graph memory.
