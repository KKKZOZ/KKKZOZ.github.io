#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, gallery, hint, img
#import "/utils/figures/ktransformers.typ": diagram

#tola-meta((
  title: "KTransformers: CPU/GPU Hybrid Inference for MoE Models",
  date: "2026-10-24",
  summary: "How KTransformers (SOSP '25) runs the 671B DeepSeek-V3 on one GPU plus a dual-socket Xeon: AMX-aware CPU kernels, a single CUDA Graph for the whole decode step, NUMA-aware tensor parallelism, and Expert Deferral, which overlaps CPU and GPU by letting some experts arrive one layer late.",
  tags: ("SOSP-25", "LLM-Inference"),
  weight: 10,
))

#let fig(name) = "/assets/images/ktransformers/" + name

Running a 671B-parameter MoE model such as DeepSeek-V3 at home sounds impossible: even in Int4 the weights are about 8× larger than an A100's memory. But host DRAM is cheap and large, and an MoE model only touches a few experts per token. So the natural plan is to keep most of the model in DRAM, compute the experts on the CPU, and give the GPU whatever it can hold.

KTransformers (Chen, Xie, Zhang et al., Tsinghua / Approaching.AI, SOSP '25) is a system built on that plan. Its observation is that once you do this, the *CPU side* becomes the bottleneck: its compute, its coordination with the GPU, and its own NUMA topology. The paper fixes each of these, then adds one model-level trick, *Expert Deferral*, so the CPU and GPU actually run at the same time.

On one A100 plus two Xeon 8452Y sockets, the result is *4.62–19.74×* faster prefill and *1.25–4.09×* faster decode than existing hybrid systems, plus up to *45%* more decode throughput from Expert Deferral at an average accuracy drop of at most 0.5%.

= Background: Why Local MoE Inference Is a CPU Problem

== Two phases, two kinds of work

LLM inference has two phases. *Prefill* processes the whole prompt at once; *decode* generates one token per step. What matters for hardware is the *arithmetic intensity* (ARI): FLOPs done per byte of weights read. Prefill reuses every weight across many tokens, so it is compute-bound. Decode reads every weight for one token, so it is bandwidth- and latency-bound.

#diagram("phases")

#hint[In an MoE layer, the ARI is set by *how many tokens are routed to each expert*, not by the prompt length. This number decides later whether the CPU should use AMX or AVX-512.]

== Mixture-of-Experts: a huge model with a sparse step

In an MoE layer, the dense FFN is replaced by a pool of experts, and a learned gate picks the *top-k* experts for each token. DeepSeek and Qwen also have *shared experts* that run for every token.

#diagram("moe-routing")

DeepSeek-V3 has 671B parameters, but each token only touches a few experts per layer. In the cloud, huge batches keep every expert busy. In a local deployment with one or a few requests, most experts sit idle in memory, and sparse activation cuts the memory traffic per token. Local deployment is attractive for *privacy* and for *inspecting model internals*, but the model simply does not fit in VRAM:

#diagram("memory-wall")

== Offloading: move the weights, or move the compute?

There are two ways to use host memory:

- *Weight offloading* keeps experts in DRAM and copies the needed ones to the GPU on demand. Every step then pushes new experts over PCIe (32 GB/s on PCIe 4.0), which is far too slow.
- *Computation offloading* (Fiddler) keeps the experts in DRAM and runs them *on the CPU*. Only activations cross PCIe, and the CPU reads weights from DRAM at up to 440 GB/s on a dual-socket DDR5 machine.

#diagram("offload-modes")

Fiddler also places modules by ARI: attention (highest ARI) and popular experts go to the GPU. KTransformers uses the same idea in a simpler form, aimed at models with shared experts: attention and *shared* experts run on the GPU, *routed* experts (which are trained to be load-balanced) run on the CPU. For models without shared experts, popular experts can still be found by offline profiling, as Fiddler does.

#hint[With computation offloading, the bottleneck moves to the *CPU side*: its memory access, its compute, and its coordination with the GPU.]

= Where Existing Hybrid Systems Lose Time

The starting point is Fiddler-style hybrid inference of DeepSeek-V3 on one A100 and two Xeon CPUs. It reaches *70.02 tokens/s* in prefill and *4.68 tokens/s* in decode, with GPU utilization *below 30%*. The GPU is mostly waiting, so the system is CPU-bound. The paper traces this to three causes.

== ① CPU compute reaches only 7% of the AMX peak

Modern server CPUs have matrix units: Intel *AMX* and ARM *SME*. PyTorch already calls Intel's AMX kernel through oneDNN. On a microbenchmark of a DeepSeek-V3 MoE layer on one 36-core Xeon 8452Y, AMX beats AVX-512 at high ARI, but it *plateaus at 5.4 TFLOPS* (AVX-512 reaches 1.8 TFLOPS).

#img(fig("fig3-cpu-bench.jpg"), alt: "Throughput of DeepSeek-V3 MoE layers with PyTorch AMX, PyTorch AVX-512, and the KTransformers AMX kernel", caption: [Fig. 3: MoE-layer throughput vs. tokens per expert. The KTransformers curve is the kernel described later.], width: "75%")

#diagram("cpu-gauge")

The theoretical AMX peak is 73.7 TFLOPS, so PyTorch gets about 7% of it. The paper blames mainly the *memory layout*: the weights are not arranged the way AMX consumes them, so cache reuse is poor and memory bandwidth is wasted.

== ② In decode, kernel launches eat GPU time

Decode kernels run for microseconds, so launching them costs about as much as running them. Profiling the DeepSeek-V3 decode phase with Nsight Systems:

- *Fiddler* issues over 7,000 kernel launches per token at 16 µs each: launch overhead is *73%* of GPU time.
- *Llama.cpp* fuses aggressively and avoids Python: about 3,000 launches at 5 µs each, still *21%* of GPU time.

#img(fig("fig4-launch.jpg"), alt: "CDF of GPU kernel execution time compared with average launch time for Fiddler and Llama.cpp", caption: [Fig. 4: distribution of kernel execution time against the average launch time.], width: "75%")

#diagram("launch-overhead")

The usual fix is a *CUDA Graph*: capture all kernels once, replay them with one launch. In hybrid inference this breaks, because every CPU expert call is a synchronization point that cuts the graph. `torch.compile` splits the graph at layer boundaries, and Llama.cpp turns CUDA Graphs off to avoid repeated captures. Running GPU shared experts and CPU routed experts *at the same time* adds another scheduling problem that a plain CUDA Graph does not solve.

== ③ Two sockets are only 16% faster than one

A dual-socket server is a NUMA machine: each socket has its own DRAM, and reading the other socket's memory goes over the socket link at about half the bandwidth (220 GB/s local vs. 125 GB/s remote on the testbed).

#diagram("numa-bg")

Fiddler and Llama.cpp treat memory as uniform, so weights land on either node. Decoding one DeepSeek-V3 MoE layer takes 6.9 ms on one socket and 5.8 ms on two. Doubling the cores barely helps when half of the reads go remote.

== From bottlenecks to techniques

Each bottleneck maps to one part of KTransformers:

#diagram("roadmap")

The CPU kernel work (§3.2 of the paper) makes each device fast; the scheduling work (§3.3) removes coordination overhead; Expert Deferral (§4) lets the CPU and GPU work at the same time; the injection framework (§5) makes all of it pluggable into HuggingFace models.

= System Overview

KTransformers is a drop-in extension of *HuggingFace Transformers*: the user-facing interface stays the same, and optimized modules are swapped in underneath.

#img(fig("fig5-overview.jpg"), alt: "System overview of KTransformers", caption: [Fig. 5: KTransformers system overview.], width: "80%")

- *CPU side*: a custom fused-MoE module replaces PyTorch's MoE, running on hand-written AMX / AVX-512 kernels.
- *GPU side*: FlashInfer-based attention, and optionally Marlin kernels for quantized linear layers.
- *Coordination*: asynchronous CPU-GPU scheduling, so that the whole dynamic-shaped hybrid forward pass fits in one CUDA Graph, and NUMA-aware tensor parallelism across sockets.
- *Overlap*: Expert Deferral.
- *Glue*: a YAML-driven module injection framework.

The implementation is about 11,000 lines of C++ and 2,000 lines of Python.

= Making the CPU Fast

== An AMX tiling-aware memory layout

Each AMX-enabled core has *8 tile registers*. A tile is a submatrix of *16 rows × 64 bytes*, and one instruction loads or stores a whole tile. AMX is fast enough that how tiles reach it from memory decides the performance.

With a normal row-major weight matrix, one tile takes 64 B from each of 16 rows, and those pieces are a full row apart in memory: 16 scattered reads per tile. KTransformers instead *repacks the expert weights once, at model load time*:

#diagram("tile-layout")

- Each tile becomes *1 KB of contiguous memory*, so no transpose or reshape happens during inference.
- Tiles are aligned to *64 B*, one cache line per tile row, which keeps hardware prefetching clean.
- Weights use *symmetric group-wise quantization* in Int8 or Int4. Scale factors are stored separately so they do not break the alignment. Int4 tiles are packed into Int8-sized blocks and unpacked with SIMD instructions.

== A cache-friendly AMX kernel

On top of this layout, the kernel's loop nest follows the memory hierarchy, one level per tier:

#img(fig("fig6-amx-kernel.jpg"), alt: "Execution process of the KTransformers AMX kernel", caption: [Fig. 6: execution of the AMX kernel across DRAM, L3, L2, L1 and tile registers.], width: "70%")

+ Expert weights are split by *columns* into tasks, which threads pull from a queue. The input activations are reused by every task, so they naturally stay in the shared *L3* cache (they are not pinned there explicitly).
+ Each task splits its weights by *rows* into blocks sized to fit *L2*.
+ Inside a block, inputs (from L3) and weights (from DRAM) are loaded into L2 *once*.
+ The block is processed as AMX tiles: results are multiplied and accumulated directly in *tile registers*, spilling to L1 only when needed.

#diagram("loop-nest")

#table(
  columns: (auto, auto, 1fr),
  [*Level*], [*Split*], [*What gets reused*],
  [①], [weight columns], [tasks of the *same expert* are co-scheduled, so they share the input $X$ in L3],
  [②], [weight rows], [each weight byte crosses DRAM → L2 *once*],
  [③④], [16 × 64 B tiles], [$X$ tiles are reused against every weight tile of the block],
  [⑤], [2 × 2 outer product], [each loaded tile feeds two multiplies],
)

On a single socket this kernel reaches *21.3 TFLOPS*, *3.98×* the oneDNN-based PyTorch baseline (the top curve in Fig. 3 above).

== AMX or AVX-512? It depends on the ARI

AMX always works on whole tiles. One input tile holds 16 token rows, so if only one or two tokens are routed to an expert, most of the tile is padding. This is exactly the decode case.

#diagram("ari-tiles")

KTransformers therefore also has an *AVX-512 kernel that reads the same tiled layout*, and picks between the two at runtime, with no repacking. In the microbenchmark, AVX-512 wins whenever there are *4 or fewer tokens per expert*:

#img(fig("fig7-amx-vs-avx.jpg"), alt: "Latency of MoE layers with the KTransformers AMX and AVX-512 kernels across models", caption: [Fig. 7: MoE-layer latency with the AMX and AVX-512 kernels as tokens per expert grow.], width: "70%")

The hybrid kernel is *1.20×* faster than pure AMX in decode and *10.81×* faster than pure AVX-512 in prefill.

== Fused MoE and dynamic scheduling

An MoE layer is many small matrix multiplications (Gate, Up and Down for each expert), and every one of them is a thread barrier if run separately. KTransformers fuses them:

- Gate projections of all active experts are merged into one large task; Up and Down likewise.
- Gate and Up have no data dependency, so they run in the same batch.
- The whole MoE layer becomes *two fused batches*.

#diagram("fused-moe")

In prefill, expert load is very uneven: popular experts get many more tokens. With static partitioning some threads finish early and wait. KTransformers cuts large tasks into small subtasks in a lightweight queue, and threads *pull* work dynamically. This gives up to *1.83×* in prefill.

= CPU-GPU and CPU-CPU Coordination

== Asynchronous scheduling inside one CUDA Graph

The decode step for one MoE layer goes like this. The GPU runs the gate and now knows the routed experts for each token. A CPU control thread pushes the routed-expert tasks into a *lock-free queue* and launches the GPU kernels for the shared experts. Background worker threads run the queued tasks. When the GPU finishes, the control thread waits for the CPU work, merges the two outputs, and moves on to the next layer.

#diagram("async-timeline")

A naive version needs two host-side barriers per layer: *submit* (GPU activations go to the CPU) and *sync* (CPU results come back). Each one breaks the CUDA Graph. KTransformers wraps both in `cudaLaunchHostFunc`, which lets CUDA call a host function *from inside the stream*:

#diagram("async-callbacks")

- Callbacks are stream-ordered, so shared experts → sync → merge keep their order without any host-side launch.
- *Which* experts run and *how many* tokens each gets are handled inside the CPU tasks, so the GPU graph is *identical at every step*, even though the routing changes.
- Callbacks only enqueue or wait; the expert math stays on the worker threads.

The whole decode step for one token is now *one* CUDA Graph. Kernel launch overhead drops from 21–73% to almost zero, and decode gets up to *1.23×* faster.

== NUMA-aware tensor parallelism

Cloud systems usually spread MoE across devices with *expert parallelism* (EP): each socket owns whole experts. With only a handful of tokens, the routed experts are rarely balanced across sockets, so one socket is busy while the other idles:

#diagram("numa-load")

KTransformers uses *tensor parallelism* instead: every expert's weight matrices are split across sockets (column-wise or row-wise per linear layer). Each socket keeps only its slice in local DRAM, computes on it locally, and a lightweight reduce-scatter combines the partial outputs.

#diagram("numa-split")

#hint[Every expert is split evenly, so the work is balanced, nearly all weight reads are local, and there is only one reduce per expert. Compared with a NUMA-oblivious baseline, decode gets up to *1.63×* faster (prefill 1.22×).]

= Expert Deferral: Overlapping CPU and GPU

== Why the CPU and GPU still wait for each other

After all the above, decode of DeepSeek-V3 still reaches only 5.87 tokens/s. The reason is the Transformer's strict layer order: the attention of layer $k+1$ needs the outputs of *all* routed experts of layer $k$. So the GPU idles while the CPU computes routed experts, and the CPU idles while the GPU computes attention. Shared experts do run on the GPU in parallel with routed experts, but they are only *18%* of the GPU time in DeepSeek-V3.

#img(fig("fig1-timeline.jpg"), alt: "Timelines of GPU-only, CPU-GPU hybrid, and Expert Deferral execution", caption: [Fig. 1: execution timelines. The bottom row is CPU-GPU orchestration with Expert Deferral.], width: "70%")

The key observation is that *residual connections* make Transformers tolerant to late updates: each layer adds its output to a residual stream that every later layer reads. So a few experts can add their output one layer later, to layer $k+2$ instead of $k+1$, and the model still sees their contribution.

== Immediate and deferred experts

At each layer, the routed experts chosen by the gate are split in two groups:

- *Immediate experts*: the top-scored ones. Their output feeds layer $k+1$ as usual.
- *Deferred experts*: the rest. Their output is added at layer $k+2$, and they are computed *while the GPU runs the attention of layer $k+1$*.

#diagram("defer-compare")

In a standard MoE layer, the output is $O_k = I_k + S_k (I_k) + R_k^"all" (I_k)$, where $I_k$ is the MoE input, $S_k$ the shared experts and $R_k^"all"$ all routed experts. With Expert Deferral, using $R_k^"imm"$ and $R_k^"def"$ for the immediate and deferred experts of layer $k$, and $L$ for the number of MoE layers:

$ O_k = cases(
  I_k + S_k (I_k) + R_k^"imm" (I_k) & quad k = 1,
  I_k + S_k (I_k) + R_(k-1)^"def" (I_(k-1)) + R_k^"imm" (I_k) & quad 1 < k < L,
  I_k + S_k (I_k) + R_(k-1)^"def" (I_(k-1)) + R_k^"all" (I_k) & quad k = L,
) $

The first layer has no deferred input from earlier, and the last layer does not defer anything, so no expert output is lost at the end.

Unrolling two layers shows where the deferred output lands:

#diagram("defer-unrolled")

- The attention and the router of layer $k$ never see $R_(k-1)^"def"$; it joins the residual stream right before the attention of layer $k+1$.
- Its CPU work sits in the same time window as the GPU's attention, so the CPU is busy while the GPU computes attention.
- Its input $I_(k-1)$ is already on the CPU (it was sent for the immediate experts), so deferral needs *no extra transfer*.

#callout(kind: "warning", title: [DECODE ONLY])[
  Expert Deferral is applied only during decode. In prefill, the many tokens of a batch jointly select almost all experts, so the immediate and deferred groups both cover nearly every expert. That almost doubles the memory traffic and cancels the gain from overlap.
]

== How many experts to defer?

The paper profiles one DeepSeek-V3 layer (BF16, top-8 routing). Without deferral, the CPU is busy 74% of the time, the GPU 28%, and the two overlap for only 5% of the time; synchronization and activation transfers add another 3% of idle time.

#diagram("defer-timeline")

- *2 deferred*: the GPU can start attention as soon as the CPU finishes 6 immediate experts. Layer time drops by 19%, but the deferred experts finish early and the CPU idles again.
- *3 deferred*: the deferred work exactly fills the CPU's free time, ending when the next layer's immediate experts start. The CPU is saturated; layer time drops by 26% and end-to-end decode throughput rises by *33%*. CPU / GPU utilization goes from 74% / 28% to 100% / 37%.
- *4 deferred*: no further gain, because the CPU is already full; work just shifts around.

So DeepSeek-V3 (BF16) uses *5 immediate + 3 deferred* experts. The general rule: defer the *fewest* experts needed to saturate the CPU, and keep *at least 2 immediate experts* per layer for model stability.

= Flexible Module Injection

All these optimizations are only useful if they are easy to apply to new models. KTransformers exports its C++ kernels through *pybind11* and wraps them as ordinary PyTorch modules, so they can replace any existing module. A YAML file describes the replacements as *match* → *replace* rules:

```yaml
- match:
    class: modeling_deepseek_v3.DeepseekV3MoE
  replace:
    class: operators.experts.FusedMoE
    device: "cpu"
    kwargs:
      backend: "hybrid_AMX_AVX512"
      data_type: "Int4"
      n_deferred_experts: 6
- match:
    name: "^model\.layers\..*\.self_attn$"
  replace:
    class: operators.attention.FlashInferMLA
    device: "cuda:0"
- match:
    name: "^(?!lm_head$).*"
    class: torch.nn.Linear
  replace:
    class: operators.linear.MarlinLinear
    device: "cuda:0"
    kwargs: {data_type: "Int4"}
```

This is the configuration for DeepSeek-V3 in Int4. The first rule replaces every `DeepseekV3MoE` (matched by class) with the fused CPU MoE using the hybrid AMX / AVX-512 kernel and 6 deferred experts. The second replaces self-attention (matched by name) with FlashInfer's MLA kernel. The third turns every `nn.Linear` except `lm_head` into an Int4 Marlin layer on the GPU.

At initialization, the framework walks the module tree, replaces every match, and keeps walking into the new submodules. There is no runtime overhead and the HuggingFace API is unchanged. Porting to DeepSeek-V2 means changing *one line*: the matched class name. The same mechanism also supports multi-GPU pipelining, mixed precision and KV-cache offloading.

= Evaluation

== Setup

#diagram("testbed")

- *Hardware*: two Xeon Platinum 8452Y sockets (36 cores each, 1 TB DDR5 per socket), with either an A100 40 GB (server-grade) or an RTX 4080 16 GB (consumer-grade), both on PCIe 4.0.
- *Workloads*: batch size 1, Wikitext prompts. Prefill varies the prompt from 32 to 8192 tokens; decode uses a 32-token prompt and up to 512 output tokens.
- *Baselines*: *Fiddler* (PyTorch hybrid system) and *Llama.cpp*, which the authors extended with expert-level offloading so both baselines use the same Fiddler-style placement.
- *Precision*: on the A100, full precision (BF16; FP16 for Llama.cpp, which lacks BF16 CUDA kernels). On the RTX 4080, the most accurate quantized version that fits: DS-3 in Int4, DS-2 and QW-2 in Int8.

Almost the whole model lives on the CPU side:

#diagram("model-split")

#table(
  columns: (auto, 1fr, 1fr, 1fr),
  [], [*DS-3*], [*DS-2*], [*QW-2*],
  [Model], [DeepSeek-V3-0324], [DeepSeek-V2.5-1210], [Qwen2-57B-A14B],
  [Total / GPU / CPU params], [671B / 17B / 654B], [236B / 13B / 223B], [57B / 8B / 49B],
  [MoE layers], [58], [59], [28],
  [Routed experts per layer], [256], [160], [64],
  [Routing], [top-8], [top-6], [top-8],
)

== Prefill: faster at every prompt length

#img(fig("fig11-prefill.jpg"), alt: "Prefill throughput of KTransformers, Fiddler and Llama.cpp across prompt lengths", caption: [Fig. 11: prefill throughput vs. prompt length.])

Among the baselines, Llama.cpp wins on short prompts thanks to operator fusion, while Fiddler wins on long prompts thanks to oneDNN's AMX path. KTransformers beats both at every length, by *4.62–19.74×*, mostly because of the AMX kernel.

== Decode: CUDA Graph first, then Expert Deferral

#diagram("decode-bars")

#hint[Bars redrawn (approximately) from the paper's Fig. 12; the labels give the extra gain of Expert Deferral over KTransformers without it.]

- *Without Expert Deferral*, full precision: *2.42–4.09×* over Fiddler and *1.25–1.76×* over Llama.cpp. Besides the kernels, the single CUDA Graph removes the 20%+ launch overhead seen in Fig. 4.
- *Quantized*: *1.77–1.93×* over Llama.cpp. Shorter kernels on both CPU and GPU make the synchronization savings matter even more.
- *With Expert Deferral*: up to *45%* more decode throughput, for *1.66–2.56×* overall over Llama.cpp.

== Breakdown: which optimization helps where

Starting from Fiddler (BF16) and adding the optimizations one at a time:

#gallery(
  columns: 2,
  caption: [Fig. 14: speed normalized to Fiddler. v: AVX-512 kernel, m: AMX kernel, d: dynamic scheduling, n: NUMA-aware tensor parallelism, c: CUDA Graph.],
  (fig("fig14a-breakdown-prefill.jpg"), "Prefill (8192 tokens)"),
  (fig("fig14b-breakdown-decode.jpg"), "Decode"),
)

#table(
  columns: (auto, 1fr, 1fr),
  [*Step*], [*Prefill (compute-bound)*], [*Decode (latency / bandwidth-bound)*],
  [v vs. m], [AVX-512 is slower than the baseline; AMX up to *3.14×*], [both beat the baseline; AVX-512 is better, up to *2.22×*],
  [+d], [up to *1.83×* (uneven expert load)], [almost none (load is balanced)],
  [+n], [up to 1.22×], [up to *1.63×* (bandwidth-bound)],
  [+c], [almost none (launch cost amortized over many tokens)], [up to *1.23×*],
)

The pattern matches the bottleneck analysis: prefill gains come from compute and load balance, decode gains come from memory locality and launch overhead.

== Does Expert Deferral hurt accuracy?

Deferral changes the model's computation, so it needs an accuracy check. The paper reports the quantized models, which defer the most experts (DS-3: 3 in BF16 / 6 in Int4; DS-2: 4 / 4; QW-2: 2 / 4). Each configuration is written (immediate + deferred).

#table(
  columns: (auto, 1fr, 1fr, 1fr, 1fr),
  [*Model*], [*HumanEval*], [*MBPP*], [*GSM8K*], [*StrategyQA*],
  [DS-3 (8+0)], [83.0], [71.2], [94.8], [83.0],
  [DS-3 (2+6)], [83.0], [70.2], [95.2], [82.9],
  [DS-2 (6+0)], [80.5], [67.6], [93.3], [79.7],
  [DS-2 (2+4)], [82.5], [66.8], [92.8], [80.4],
  [QW-2 (8+0)], [65.7], [52.4], [84.7], [83.6],
  [QW-2 (4+4)], [67.4], [53.4], [83.4], [82.5],
)

Every change stays within *2 points*, and the changes go in both directions. That looks like noise rather than systematic damage.

== Deferral vs. simply skipping experts

The obvious alternative is *Expert Skipping*: drop the lowest-scored experts entirely. When the deferred work fully overlaps with the GPU, deferral costs almost nothing, so the two give a similar speedup. The question is what each costs in accuracy. On DS-3 with LiveBench:

#diagram("defer-vs-skip")

#gallery(
  columns: 2,
  caption: [Fig. 13: DS-3 on LiveBench. First column: baseline scores; other columns: relative accuracy change (%) with more affected experts.],
  (fig("fig13a-skip.jpg"), "(a) Expert Skipping"),
  (fig("fig13b-defer.jpg"), "(b) Expert Deferral"),
)

At the default of 6 affected experts, deferral loses *0.5%* on average while skipping loses *13.3%*. Late is far better than never: the deferred experts' output still reaches the residual stream, one layer later.

= Takeaways

#table(
  columns: (1fr, 1fr, auto),
  [*Technique*], [*Bottleneck it targets*], [*Gain*],
  [AMX tiled layout + cache-aware kernel], [CPU compute (prefill)], [3.98× vs. oneDNN],
  [AMX / AVX-512 switch], [low-ARI decode], [1.20× decode],
  [Fused MoE + dynamic scheduling], [thread barriers, load imbalance], [1.83× prefill],
  [Host callbacks in one CUDA Graph], [kernel launch overhead], [1.23× decode],
  [NUMA-aware tensor parallelism], [cross-socket memory traffic], [1.63× decode],
  [Expert Deferral], [CPU-GPU serialization], [up to 1.45× decode],
)

- Once experts run on the CPU, local MoE inference is a *CPU systems problem*: the matrix units need a matching memory layout, the decode step needs to avoid host round trips, and the memory system is not uniform.
- The kernel and scheduling work makes each device fast. Expert Deferral is the one change at the *model* level: it relaxes the strict layer dependency so the two devices are busy at the same time, which the residual stream tolerates at a cost of at most 0.5% accuracy, compared with 13.3% for skipping the same experts.
- The YAML injection framework is what makes this practical: the same kernels and placement policies apply to a new model by editing a config file instead of the model code.
