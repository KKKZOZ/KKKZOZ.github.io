#import "@tola/source:0.0.0": tola-meta
#import "@tola-modules/nasapunk:0.0.0": mi, mitex
#import "@tola-modules/nasapunk:0.0.0": callout, hint, term, xref
#import "/figures/cpu-gemv-bandwidth.typ" as fig

#tola-meta((
  title: "Decode GEMV on the CPU: Bandwidth, Compute or NUMA",
  date: "2026-11-19",
  summary: "Decode GEMV on a Core Ultra 9, an M4 Pro and a dual-socket Xeon: how close each gets to its memory bandwidth, and what holds it back.",
  tags: ("LLM-Inference", "Hardware", "ggml"),
  series: "AI Infra",
  part: 7,
  weight: 10,
  toc-depth: 3,
))

In decode, every weight matrix is multiplied by one vector: a GEMV (General Matrix-Vector multiply). Each weight is read once per token, for one multiply-add.

The example here is the up and gate projections of one Qwen3-8B layer: two 12288 × 4096 matrices, 31.5 MiB in Q2_K and 54 MiB in Q4_0. #xref("/posts/ml-systems/ggml-q4-0-vec-dot/") shows how ggml computes them.

With _n_ threads, the time has two floors:

#mitex(`T(n) \approx \max\left(\frac{T(1)}{n},\ \frac{B}{BW(n)}\right)`)

- #mi(`B/BW(n)`), the *bandwidth floor*: weight bytes over the rate _n_ cores read DRAM (Dynamic Random-Access Memory, the main memory). No kernel is faster, so this post calls it the *optimal latency*.
- #mi(`T(1)/n`), the *compute floor*: one thread's time, mostly compute, split over _n_ cores.

On three CPUs, Q2_K is held back by something different each time:

#table(
  columns: 5,
  table.header([Machine], [CPU read ceiling], [Q2_K is limited by], [Fix], [Best 2-bit / 4-bit]),
  [Core Ultra 9 285K], [67 GB/s], [bandwidth], [software prefetch, 16 threads], [0.50 / 0.85 ms],
  [Apple M4 Pro], [223 GB/s], [compute], [T-MAC table lookups], [0.13 / 0.24 ms],
  [2 × Xeon Gold 6248R], [216 GB/s, each socket reading its own memory], [NUMA layout], [one shard per socket], [0.145 / 0.27 ms],
)

With each fix, all three come within about 10% of the optimal latency.

#callout(kind: "info", title: [SETUP])[
  - *Workload*: up and gate fused into one call; median latency per layer. The benchmark rotates through *36 copies of the weights*, one per layer, so every call reads from DRAM, as in real decode.
  - *ggml*: the CPU backend's `mul_mat`, the path llama.cpp runs.
  - *gemv-probe*: our harness around ggml's own `vec_dot` for Q2_K and Q4_0. Same arithmetic; thread split, prefetch and memory placement can change.
  - *T-MAC*: #link("https://github.com/microsoft/T-MAC")[Microsoft's low-bit kernels] built on table lookups. `W2 g128` is 2-bit weights with one scale per 128 weights.
  - *Read-only probe*: 36 buffers of 31.5 MiB, rotated, each thread summing its share. GB/s = bytes / median time. This is the *read ceiling*.
]

= Memory Bandwidth

What the bus can carry at best:

#mitex(`\text{peak} = \text{transfers per second} \times \text{bytes per transfer} \times \text{channels}`)

Each factor has its own limit, and some numbers on a spec sheet, like CAS (Column Address Strobe) latency, are not one of them.

== Transfers per Clock

#figure(fig.fig-ddr(), caption: [DDR moves data on both edges of the I/O clock: a 2400 MHz clock gives 4800 MT/s.]) <fig-ddr>

DDR (Double Data Rate) memory moves data on both edges of the clock. *DDR5-4800*, its fifth generation, makes 4800 Mega-Transfers per Second (MT/s) from a 2400 MHz I/O clock. A channel is 64 bits wide, so each transfer moves 8 bytes:

#mitex(`4800\,\text{MT/s} \times 8\,\text{B} = 38.4\ \text{GB/s per channel}`)

== Channels

A *channel* is an independent 64-bit path from the memory controller to the DIMMs (Dual In-line Memory Modules, the memory sticks). The Core Ultra 9 285K has two.

#figure(fig.fig-channels(), caption: [Same capacity, twice the bandwidth: with one stick per channel, both channels transfer at the same time.]) <fig-channels>

One 64 GB stick leaves channel B idle: 38.4 GB/s. Two 32 GB sticks, one on each channel, give 76.8 GB/s. The sticks must sit on different channels; two on the same channel are still single channel.

Adding two more sticks adds capacity, not bandwidth:

#figure(fig.fig-four-sticks(), caption: [Four sticks share the same two channels: twice the capacity, the same peak.]) <fig-four-sticks>

On the 285K it even costs bandwidth: with two sticks per channel, Intel's supported speed drops from 5600–6400 to 4400–4800 MT/s. *More bandwidth needs more channels*, that is, a wider bus.

== Transfer Rate

#figure(fig.fig-speed-grades(), caption: [Dual-channel peak for each DDR5 speed grade, and where the 285K sits.]) <fig-speed-grades>

The 285K's official speed depends on the kind of DIMM:

#table(
  columns: 2,
  table.header([2 DIMMs, one per channel], [Supported speed]),
  [CUDIMM], [DDR5-6400],
  [UDIMM], [DDR5-5600],
)

On a *UDIMM* (Unbuffered DIMM) the clock goes straight from the CPU to the DRAM chips, and arrives distorted at high rates. A *CUDIMM* (Clocked UDIMM) regenerates it with a Client Clock Driver (CKD) on the stick:

#figure(fig.fig-dimm(), caption: [UDIMM vs. CUDIMM: a clock driver on the stick regenerates the clock that reaches the DRAM chips.]) <fig-dimm>

The machine in this post runs DDR5-4800: 2 × 38.4 = *76.8 GB/s* peak.

== CAS Latency

#figure(fig.fig-cas(), caption: [CL40: 40 clock cycles from a READ command to the first data.]) <fig-cas>

"C40" is the CAS Latency (CL): *40 clock cycles* from a READ command to the first data, 16.7 ns at DDR5-4800. Across speeds, compare in nanoseconds:

#mitex(`t_{CL} = CL \times 2000 / \text{MT/s}\ \ \text{ns}`)

CL does not change the peak. Decode streams weights, so what matters is MT/s and bus width.

== Bus Width

Apple's M4 Pro uses LPDDR5X (Low-Power DDR5, eXtended), soldered next to the chip. It gets more than twice the 285K's best, mostly from a wider bus:

#table(
  columns: 4,
  table.header([], [Memory], [Total bus width], [Peak]),
  [Core Ultra 9 285K (this post)], [DDR5-4800], [128-bit], [76.8 GB/s],
  [Core Ultra 9 285K (official max)], [DDR5-6400], [128-bit], [102.4 GB/s],
  [M4 Pro], [LPDDR5X-8533], [*256-bit*], [*273 GB/s*],
)

#figure(fig.fig-bus-steps(), caption: [From 102.4 to 273 GB/s: twice the bus width, then a 1.33× faster rate.]) <fig-bus-steps>

The width is set by the memory controller, not by the memory type:

#figure(fig.fig-controllers(), caption: [The 285K's controller drives two 64-bit channels; the M4 Pro's drives four 64-bit LPDDR5X packages next to the SoC (System on a Chip).]) <fig-controllers>

- Neither LPDDR5X nor DDR5 fixes the total width: 4- and 8-channel DDR5 workstations reach 256 and 512 bits.
- Memory in the package makes a wide bus practical, but its capacity cannot be upgraded.
- The CPU and GPU of the M4 Pro share the controller, and with it the 273 GB/s.

#hint[
  Jetson AGX Thor has the M4 Pro's bus: LPDDR5X-8533, 256-bit, 273 GB/s, but up to 128 GB. CPU and GPU share it, as on the M4 Pro.

  #figure(fig.fig-thor-bw(), caption: [Peak memory bandwidth: bus width × rate.]) <fig-thor-bw>
]

The dual-socket Xeon server goes wide the other way: each Xeon Gold 6248R has its own *6-channel* controller, and the two sockets are joined by UPI (Ultra Path Interconnect, Intel's link between sockets).

#figure(fig.fig-xeon-board(6, [32 GB], [6 × 64 = *384-bit* · *128 GB/s* peak]), caption: [2 × Xeon Gold 6248R with 12 × 32 GB DDR4-2666, one DIMM on each channel.]) <fig-xeon-board>

DDR4-2666 gives 21.3 GB/s per channel, 128 GB/s per socket, 256 GB/s in total, but only if each socket reads its own memory.

The three machines:

#table(
  columns: 4,
  table.header([Machine], [Memory], [Bus width], [Peak]),
  [Core Ultra 9 285K], [DDR5-4800, 2 channels], [128-bit], [76.8 GB/s],
  [M4 Pro], [LPDDR5X-8533], [256-bit], [273 GB/s],
  [2 × Xeon Gold 6248R], [DDR4-2666, 6 channels per socket], [2 × 384-bit], [2 × 128 GB/s],
)

The peak is what the bus can carry. What the cores can pull through it is lower, and has to be measured.

= Core Ultra 9: Bandwidth-Bound

The Core Ultra 9 285K has 8 Performance (P) and 16 Efficiency (E) cores, with 2 × DDR5-4800.

== The Read Ceiling

#figure(fig.fig-u9-ceiling(), caption: [Read-only probe on the Core Ultra 9: 67 GB/s from 8 threads, 87% of the DDR5-4800 peak.]) <fig-u9-ceiling>

- One core reads 19 GB/s. 8 P-cores reach *67 GB/s*, 87% of the 76.8 GB/s peak.
- More threads add nothing: 57 at 16, 66 at 24.

#term("STREAM")[A standard benchmark of sustainable memory bandwidth, by John McCalpin. It times four loops over arrays far larger than the cache, Copy, Scale, Add and Triad, and divides the bytes it counts by the time.] Triad (`a[i] = b[i] + s * c[i]`) reports 52 GB/s at 8 threads. It counts 3 arrays of traffic, but the core also reads `a[i]`'s line before writing it (write-allocate): × 4/3 ≈ 70 GB/s.

The optimal latency follows: 33.0 MB / 67 GB/s = *493 µs* for Q2_K, and 56.6 MB / 67 GB/s = *845 µs* for Q4_0.

== Baseline: ggml

*Effective bandwidth* = weight bytes / measured latency. Plotted on the same axes:

#figure(fig.fig-u9-kernels(), caption: [ggml's effective bandwidth for Q2_K and Q4_0 against the read ceiling. Error bars: range over runs.]) <fig-u9-kernels>

- *Q2_K and Q4_0 read at the same rate* at every thread count, so Q4_0 takes 1.7× as long, its weight size over Q2_K's (54 / 31.5 MiB).
- At 24 threads both reach 62–67 GB/s, the probe's ceiling.

#figure(fig.fig-u9-optimal(), caption: [Latency per layer against the optimal. Ranges are over runs; the 24-thread runs have rare 6 ms outliers.]) <fig-u9-optimal>

With 24 threads, ggml is within 2–4% of the optimal. The M4 Pro rows are a preview of the next section: its Q2_K and Q4_0 take the same time though Q4_0 reads 1.7× the bytes.

Two problems remain:

- At 24 threads, latency spikes.
- On 8 P-cores, ggml reads 38 GB/s; the probe reads 67. *ggml keeps too few loads in flight per core*, and the E-cores close the gap only by adding more loads.

== Diagnosis: Bandwidth-Bound

The two floors from the top of the post, at every thread count, against the measured latency without and with software prefetch (Fix 2 below):

#figure(fig.fig-u9-floors(), caption: [Compute floor, bandwidth floor and measured latency on the Ultra 9, µs per layer. Red: measured without prefetch / bandwidth floor at 8 threads.]) <fig-u9-floors>

- *The compute floor is far below the bandwidth floor at every thread count*: 1.4× below at one thread (Q2_K 1267 vs. 1829 µs), 3.6× at 8 (158 vs. 568). Unpacking is never the limit here, unlike on the M4 Pro.
- *Without prefetch, the latency sits 1.4–1.5× above the bandwidth floor from 4 to 10 threads*, in both formats. The cores do not pull what the probe pulls at the same thread count. More threads hide the gap: 7–8% at 16, 1–2% at 20.
- *With prefetch, the latency is within about 5% of the bandwidth floor from 4 threads on.* A few points fall up to 3% under it; the floor is a measurement too.

So the Ultra 9 is bandwidth-bound, and the gap below 16 threads is loads in flight, not compute.

== Fix 1: Leave One Core Free

Each thread pinned to one core (0 … _n_ − 1), 600 calls per run:

#table(
  columns: 4,
  table.header([Threads], [Q2_K, µs], [Q4_0, µs], [Slow calls, poll = 50 / 0]),
  [8 (P only)], [823], [1461], [0 / 0],
  [12], [642], [1136], [0 / 0],
  [16], [548], [951], [0 / 0],
  [20], [*490*], [*855*], [0 / 4],
  [22], [494], [854], [0 / 0],
  [23], [496], [851], [0 / 0],
  [24 (all)], [490], [841], [*47 / 21*],
)

A slow call takes over 3× the median (Q2_K). `poll` is how long ggml's threads busy-wait before they sleep; 0 turns it off. Latencies are with poll = 50.

#figure(fig.fig-u9-tail(), caption: [With every core busy, an OS task preempts one thread and the other 23 wait at the barrier.]) <fig-u9-tail>

- *With one core free the spikes go away.* At 24 threads the 99th percentile is 3.5–5.9 ms, near multiples of 6 ms, which looks like scheduler time slices.
- Turning busy-waiting off halves the slow calls but does not remove them (47 → 21), and gemv-probe's own thread pool spikes too, so busy-waiting is not the cause.
- 20 threads (8 P + 12 E) already reach 67 GB/s, with the 99th percentile under 0.94 ms.

== Fix 2: Software Prefetch

More threads reach the ceiling, but the E-cores are wanted elsewhere: a GPU inference server needs host threads to drive the GPU. The goal is the ceiling from the 8 P-cores alone.

Each core needs more loads in flight. Software prefetch asks for the next rows before they are needed:

#figure(fig.fig-prefetch(), caption: [While a thread computes row _r_, it prefetches row _r_ + _D_.]) <fig-prefetch>

A sketch of the loop in gemv-probe:

```c
// one thread's chunk of rows [r0, r1); D = 2
for (int r = r0; r < r1; r++) {
    const char *ahead = W + (size_t)(r + D) * row_bytes;
    for (size_t off = 0; off < row_bytes; off += 64)
        __builtin_prefetch(ahead + off);                 // one hint per cache line
    y[r] = vec_dot(K, W + (size_t)r * row_bytes, x);    // ggml's own dot product
}
```

A Q2_K row of 4096 weights is 1344 bytes, 21 cache lines; a Q4_0 row is 2304 bytes, 36 lines.

- The distance barely matters: _D_ = 1, 2, 4 and 8 all give 59–62 GB/s on 8 P-cores. _D_ = 2 is the most stable.
- We keep ggml's *dynamic* split (64-row chunks from a shared counter). With a static split the P-cores wait for the E-cores: 590 vs. 497 µs (Q2_K, 16 threads).

#figure(fig.fig-u9-prefetch(), caption: [Effective bandwidth with and without software prefetch (Q2_K; Q4_0 is within 2 GB/s).]) <fig-u9-prefetch>

#table(
  columns: 3,
  table.header([8 P-cores, µs per layer], [Q2_K], [Q4_0]),
  [ggml], [860], [1490],
  [gemv-probe + prefetch], [*535*], [*930*],
  [Change], [−38%], [−38%],
)

- *One core gains nothing*: 17.5 GB/s with or without prefetch, near the probe's 19 GB/s. The hardware prefetcher keeps up.
- *Many cores* raise DRAM latency under load, and the hardware prefetcher falls behind. Software prefetch restores the loads in flight: 8 cores go from 38 to 61 GB/s.

== Best Achievable

#figure(fig.fig-u9-best(), caption: [Every configuration against the optimal latency; "free cores" are cores left for other work.]) <fig-u9-best>

*16 threads with prefetch* is within 1% of the optimal and leaves 8 E-cores free. The M4 Pro is still 1.5× (Q2_K) and 2.6× (Q4_0) faster; that is bandwidth, not kernel.

Tried, with no effect: pinning threads to P- or E-cores, huge pages (`MADV_HUGEPAGE`), and turning off ggml's busy-wait.

= M4 Pro: Compute-Bound

The M4 Pro has 10 P-cores and 4 E-cores, with LPDDR5X-8533 on a 256-bit bus. The same benchmark with 8 threads:

#figure(fig.fig-m4-same-time(), caption: [Q4_0 reads 1.7× the bytes of Q2_K. On the Ultra 9 it takes 1.7× as long; on the M4 Pro, the same time.]) <fig-m4-same-time>

If bytes do not set the latency here, something else does.

== The Read Ceiling

#figure(fig.fig-m4-ceiling(), caption: [Read-only probe on the M4 Pro: 223 GB/s at 10 threads, 82% of the nominal 273 GB/s.]) <fig-m4-ceiling>

- The probe saturates at *10 threads* (all P-cores): *223 GB/s*, 82% of nominal, 3.3× the Ultra 9.
- One core reads *86 GB/s*, 4.5× an Ultra 9 core. A few M4 Pro cores already pull most of the bandwidth.

== Baseline: ggml

#figure(fig.fig-m4-kernels(), caption: [Left: effective bandwidth against the read ceiling. Right: share of the ceiling at 8 threads.]) <fig-m4-kernels>

- Near 100% of the ceiling, a kernel is *bandwidth-bound*.
- Far below it, the kernel is *compute-bound*: memory idles while the cores unpack and multiply.

At 8 threads, a pure read of Q2_K's 33 MB takes 0.162 ms; ggml takes 0.332 ms. *About half of the time is compute.*

== Diagnosis: Compute-Bound

A call takes the longer of two times:

- *Read time*: weight bytes / read ceiling. Q4_0 has 1.7× the bytes, so it reads longer.
- *Compute time*: unpacking the weights and multiply-adding them.

To measure compute time, we run one thread. Memory is not the limit there: one core can read 86 GB/s, and ggml uses only 14 (Q2_K) and 25 GB/s (Q4_0).

#figure(fig.fig-m4-per-core(), caption: [One thread, time to compute one layer.]) <fig-m4-per-core>

*The two formats take the same compute time.* Q2_K has fewer bits per weight but more work to unpack each:

- *Q4_0*: blocks of 32 weights with one FP16 (16-bit Floating Point) scale; a weight is `d × (q − 8)`.
- *Q2_K*: super-blocks of 256 weights in 16 sub-blocks, each with a 4-bit scale and a 4-bit minimum, on top of two FP16 factors; a weight is `d × scale × q − dmin × min`.

More threads split the compute time, and the read ceiling grows with the thread count. Per layer, in ms:

#figure(fig.fig-m4-floors(), caption: [Compute time (one-thread time / threads), read time ("bandwidth": bytes / read ceiling) and measured latency on the M4 Pro.]) <fig-m4-floors>

- *Q2_K computes longer than it reads*, at both thread counts: it is compute-bound, and its fewer bytes do not help.
- At 8 threads, both formats come down to about the same compute time, so they take the same time. This answers the puzzle at the top of the section.
- At 10 threads, Q4_0's read time is the longer one: it turns bandwidth-bound.

== Fix: T-MAC

#link("https://github.com/microsoft/T-MAC")[T-MAC] replaces unpack-and-multiply with table lookups:

+ Split each 2-bit weight into two 1-bit planes.
+ For every 4 activations, precompute the 16 possible sums, once per token.
+ Each 4 bits of a plane index that table; one `tbl` instruction of NEON, Arm's SIMD (Single Instruction, Multiple Data) extension, does 16 lookups.
+ Combine the planes with a shift, then apply the scales.

#figure(fig.fig-m4-tmac(), caption: [Left: one thread, weights processed per second. Right: effective bandwidth as a share of the read ceiling at the same thread count.]) <fig-m4-tmac>

One core computes a layer in 0.88 ms instead of ggml Q2_K's 2.36 ms: *2.7×* the weights per second (114 vs. 42.6 G/s). 2-bit becomes bandwidth-bound: 96% of the ceiling at 14 threads, against ggml's 62%.

== Best Achievable

#figure(fig.fig-m4-best(), caption: [Measured / optimal latency at 10 threads; optimal = bytes the kernel reads / read ceiling.]) <fig-m4-best>

- *2-bit*: ggml is 1.7–1.9× the optimal; T-MAC is within 2–8%, about *2× faster* (0.265 → 0.133 ms).
- *4-bit*: everything is within 7%. ggml Q4_0 was already bandwidth-bound.

#hint[
  T-MAC at 10 threads reads about 200 GB/s from memory the GPU also uses. In earlier experiments the GPU slowed down more the faster the CPU read.
]

= Dual Xeon: NUMA-Bound

2 × Xeon Gold 6248R, 24 cores and 6 × DDR4-2666 per socket.

- One socket, 16 cores: Q2_K 0.56 ms, Q4_0 0.64 ms.
- Both sockets, 48 cores: Q2_K 0.99 ms, Q4_0 0.50 ms. *Q2_K is 2× slower while reading 42% fewer bytes.*

== The Read Ceiling

=== Four Layouts

On a two-socket machine, each socket has its own memory, a NUMA node (Non-Uniform Memory Access: a core reaches its own node faster than the other). A socket reads its own node directly; it reaches the other node over UPI and through the other socket's memory controller.

#figure(fig.fig-xeon-modes(), caption: [Four ways to place threads and weights. Solid: local read. Dashed: remote read, over UPI and through the other socket's memory controller.]) <fig-xeon-modes>

One thread pool over both sockets with `numactl --interleave=all` is the third case: about half of all reads cross UPI.

=== Ceiling by Layout

The same read-only probe, with each layout:

#figure(fig.fig-xeon-ceiling(), caption: [Read ceiling by layout, GB/s, mean of 2 runs.]) <fig-xeon-ceiling>

- Remote memory gives *half* the local bandwidth: 32 vs. 61 GB/s at 8 cores.
- One pool interleaved over both sockets gets *116 GB/s*, barely more than one socket alone.
- Each socket reading only its own node gets *216 GB/s*, both sockets' worth.

== Baseline: One Thread Pool

gemv-probe with one thread pool and one shared queue of 64-row chunks, pages interleaved across the sockets:

#table(
  columns: 5,
  table.header([One thread pool], [Read ceiling], [Optimal], [Measured], [Measured / optimal]),
  [Q2_K · 1 socket, 24 cores], [109 GB/s], [304 µs], [600 µs], [*1.98×*],
  [Q4_0 · 1 socket, 24 cores], [109 GB/s], [520 µs], [662 µs], [1.27×],
  [Q2_K · 2 sockets, 48 cores], [116 GB/s], [285 µs], [*989 µs*], [*3.47×*],
  [Q4_0 · 2 sockets, 48 cores], [116 GB/s], [489 µs], [504 µs], [1.03×],
)

Q4_0 on two sockets sits at its ceiling. Q2_K does not, and *gets slower* with the second socket: 600 → 989 µs.

== Diagnosis: Not Compute-Bound

#figure(fig.fig-xeon-floors(), caption: [Compute floor, bandwidth floor and measured latency on the Xeon, with the shared pool.]) <fig-xeon-floors>

On two sockets Q2_K is far above *both* floors: 989 µs against 285 and 97. The time goes to *coordination across cores and sockets*. (The compute floor is generous: one Xeon core reads only 8.7 GB/s, so #mi(`T(1)`) includes memory stalls.)

== Fix: Local Shards

#figure(fig.fig-xeon-shards(), caption: [Left: one pool over both sockets, pages interleaved. Right: the output rows split in half, each half's weights on its own socket's memory.]) <fig-xeon-shards>

- We split the output rows in two and bind each half's weights to one socket's memory.
- Each socket gets its own threads and its own copy of the input vector, splits its rows statically, and the two join at the end.

#figure(fig.fig-xeon-shards-result(), caption: [gemv-probe Q2_K, 48 cores (24 per socket), µs per layer. Q4_0: 503 → 462 → 269 µs.]) <fig-xeon-shards-result>

- Every bar runs the same `vec_dot`, so *the lost time was not unpacking arithmetic*.
- A static split alone gives 2.4×; local shards give another 2.6×. The second step changes page placement and thread coordination at once, so the two are not separated here.

== Best Achievable

With local shards every format reaches the optimal:

#table(
  columns: 6,
  table.header([48 cores, local shards], [Bytes], [Optimal], [Measured], [× optimal], [Shared layout]),
  [gemv-probe Q2_K], [31.5 MiB], [153 µs], [*160 µs*], [1.05×], [994 µs],
  [gemv-probe Q4_0], [54 MiB], [262 µs], [*269 µs*], [1.03×], [503 µs],
  [T-MAC W2 g128], [27 MiB], [131 µs], [*145 µs*], [1.11×], [270 µs],
  [T-MAC W4 g128], [51 MiB], [247 µs], [*269 µs*], [1.09×], [480 µs],
)

Optimal = bytes / 216 GB/s.

- T-MAC W2 is *3.7×* faster than Q2_K with the shared layout, and only *1.1×* with local shards, about what its 14% fewer bytes give.
- 32 cores (16 per socket) are nearly enough: Q2_K 172 µs, W2 151 µs. The last 16 cores add 4–7%.

#callout(kind: "warning", title: [CAVEAT])[
  These are gemv-probe numbers. ggml's own graph, with its NUMA options, still takes about 1 ms per layer here, not yet profiled.
]

= Summary

#table(
  columns: 4,
  table.header([], [Core Ultra 9], [M4 Pro], [2 × Xeon]),
  [CPU read ceiling], [67 GB/s], [223 GB/s], [216 GB/s (local shards)],
  [One-core read], [19 GB/s], [86 GB/s], [8.7 GB/s],
  [Q2_K is limited by], [bandwidth], [compute], [NUMA layout],
  [Fix], [prefetch, 16 threads], [T-MAC], [local shards],
  [Best 2-bit latency], [0.50 ms], [0.13 ms], [0.145 ms (T-MAC W2)],
  [Best 4-bit latency], [0.85 ms], [0.24 ms], [0.27 ms (Q4_0 / W4)],
)

Up and gate fused, per layer, 36 weight copies rotated. Xeon: 48 cores, gemv-probe.

To find out what limits a decode GEMV on a given CPU:

+ Measure the *read ceiling* with the kernel's access pattern: weights larger than the cache, rotated, every thread count.
+ Divide the weight bytes by it: that is the *optimal latency*.
+ Compare the kernel's latency to the optimal. Near 1×, the kernel is done; only fewer bytes help.
+ Far from it, time one thread for the *compute floor*. Above it: unpacking costs too much (M4 Pro). Above both floors: look at thread coordination and where the pages live (Xeon).

All three machines end at the same place: *latency ≈ bytes / read ceiling*.
