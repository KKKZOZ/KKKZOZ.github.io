#import "@tola/source:0.0.0": tola-meta
#import "@tola-modules/nasapunk:0.0.0": mi, mitex
#import "@tola-modules/nasapunk:0.0.0": callout, cols, hint, xref
#import "/figures/cuda-hardware-hierarchy.typ" as fig

#tola-meta((
  title: "CUDA Hardware Hierarchy: From SMs to Lanes",
  date: "2026-11-16",
  summary: "Where the threads of one CUDA launch run on an RTX A6000, where their data lives, and why some memory access patterns are slow.",
  tags: ("GPU", "CUDA", "Hardware"),
  series: "AI Infra",
  part: 6,
  weight: 10,
  toc-depth: 3,
))

A CUDA kernel is written for one thread and launched for a million. What happens in between, which threads run together, where their variables live, and why one access pattern is fast and another is not, is decided by the hardware hierarchy of the GPU. This post follows one small launch down that hierarchy:

```cuda
__global__ void scale(float* x, float a, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) x[i] = a * x[i];
}

scale<<<4096, 256>>>(x, 2.0f, 4096 * 256);
```

This launch asks for 1,048,576 threads. An RTX A6000 has 84 SMs, and one SM holds at most 1,536 threads, so at most 129,024 are on the chip at a time. Three questions:

- Where does each thread run, and which other threads run with it?
- Where do `i`, `a` and `x[i]` live?
- Why would `x[2 * i]` instead of `x[i]` halve the useful memory bandwidth?

The answers come from the hardware hierarchy, from the chip down to one lane of one warp. Numbers are for the RTX A6000 (GA102, compute capability 8.6), from NVIDIA's #link("https://images.nvidia.com/aem-dam/en-zz/Solutions/geforce/ampere/pdf/NVIDIA-ampere-GA102-GPU-Architecture-Whitepaper-V1.pdf")[GA102 whitepaper] and the #link("https://docs.nvidia.com/cuda/cuda-c-programming-guide/")[CUDA C++ Programming Guide]. Other GPUs change the numbers, not the structure.

= The Chip

#figure(fig.fig-gpu(), caption: [The RTX A6000 as CUDA sees it: 84 SMs, one L2 shared by all of them, and GDDR6 behind 12 memory controllers. Schematic; on the die the L2 sits in the middle.]) <fig-gpu>

- *SM* (streaming multiprocessor): where threads run. Every instruction of a kernel, arithmetic, load or branch, executes inside one SM.
- *GPC*: a group of 12 SMs. CUDA code on Ampere never sees it.
- *L2 cache*: 6 MB, shared by all SMs. Every access to device memory passes through it.
- *Device memory*: 48 GB of GDDR6 on a 384-bit bus, 768 GB/s. CUDA calls it global memory. A100 and H100 use HBM here; the rules below are the same.

== Inside an SM

#figure(fig.fig-sm(), caption: [One GA102 SM: four partitions, each with its own warp scheduler, register file and execution units, sharing one 128 KB SRAM for L1 and shared memory. Shared memory is spread over 32 banks.]) <fig-sm>

An SM is split into 4 *partitions* (NVIDIA also calls them processing blocks, or SMSPs). Each has:

- a *warp scheduler* that issues one instruction per clock, for one warp;
- a *register file* of 64 KB: 16,384 32-bit registers;
- its own *execution units*: 32 FP32 lanes (16 that only do FP32, 16 that do FP32 or INT32), load/store units, 4 special-function units (SFUs) for `sin`, `exp` and `rsqrt`, and a tensor core.

The 4 partitions share one 128 KB SRAM, split between shared memory and the L1 cache. Shared memory is one level finer still: it is spread over *32 banks*, each 4 bytes wide, and each bank serves one word per cycle. The banks decide how fast one warp's shared-memory access is; #link(<sec-banks>)[Banks] below shows how.

*The SM is also where the state of its threads lives*: the registers and shared memory of every resident thread stay on the SM until the thread exits, for up to 48 warps from up to 16 blocks. How many actually fit is the question of #link(<sec-occupancy>)[occupancy].

= From Launch to Warps

== Grid, Block, Warp, Thread

`<<<4096, 256>>>` creates a *grid* of 4096 *blocks*, each of 256 *threads*. NVIDIA's documents also call a block a CTA (cooperative thread array). Both the grid and the block can be 1-, 2- or 3-dimensional:

- blocks per grid: `gridDim.x × gridDim.y × gridDim.z`;
- threads per block: `blockDim.x × blockDim.y × blockDim.z`, at most 1,024;
- warps per block: threads per block / 32, rounded up.

#figure(fig.fig-mapping(), caption: [Blocks are placed whole on SMs, and each block is cut into warps of 32 threads. The placement shown is illustrative; the hardware does not promise an order.]) <fig-mapping>

Three rules put them on the hardware:

+ *A block runs on one SM*, from start to finish. Its threads can use that SM's shared memory and wait for each other at `__syncthreads()`. Threads in different blocks can do neither.
+ *The SM cuts each block into warps* of 32 consecutive threads. The warp is the unit the hardware schedules: an instruction is issued once for all 32 threads.
+ *An SM holds several blocks at once*, and when one finishes, a waiting block takes its place. Blocks run in no particular order, so they must not depend on each other.

For `scale`, 256 threads are 8 warps, and if registers allow, an SM holds 6 such blocks (48 warps). 84 × 6 = 504 blocks fit at a time, so the 4096 blocks go through in 9 rounds, the last one partial.

== Which Threads Form a Warp

Warps are cut from the _linear_ thread index, x first:

```c
int tid  = threadIdx.x
         + threadIdx.y * blockDim.x
         + threadIdx.z * blockDim.x * blockDim.y;
int warp = tid / 32;
int lane = tid % 32;
```

In a 16 × 16 block, a warp is two rows:

#figure(fig.fig-warp-slice(), caption: [A 16 × 16 block cut into 8 warps. Each cell shows its thread's lane, `tid % 32`; thread (5, 2) is lane 5 of warp 1.]) <fig-warp-slice>

A block whose size is not a multiple of 32 wastes lanes: 100 threads become 4 warps, and the last has 4 active lanes and 28 idle ones on every instruction.

== Lanes and Threads

The numbers in @fig-warp-slice are lanes, not thread ids. The two words are easy to mix up:

#cols(labels: ([Thread], [Lane]))[
  - One execution of the kernel: software.
  - Named by `blockIdx` and `threadIdx`, unique in the grid.
  - Has its own registers and, since Volta, its own program counter and call stack.
  - Exists from launch until it exits.
][
  - A position in a warp, 0–31: `tid % 32`, `%laneid` in PTX.
  - Not unique: every warp has a lane 5.
  - The slot through which the thread's operands go when its warp issues an instruction.
  - Active or inactive for each instruction.
]

*A thread occupies one lane of its warp for its whole life*, but the same lane number in another warp is another thread:

#figure(fig.fig-lanes(), caption: [Lane 5 is thread 5 in warp 0 and thread 37 in warp 1. Inside `if (tid < 44)`, warp 1 runs with only lanes 0–11 active.]) <fig-lanes>

The difference matters in three places.

*Divergence.* When threads of one warp take different branches, the warp runs both paths one after the other, each with only some lanes active. In @fig-lanes, threads 44–63 still exist and keep their registers; their lanes just do nothing while warp 1 runs the `if` body.

*Warp-level primitives address lanes.* `__shfl_down_sync(mask, v, d)` returns `v` from lane `lane + d` of the same warp, and `mask` has one bit per lane. A warp sum:

```cuda
__device__ float warp_sum(float v) {
    for (int d = 16; d > 0; d /= 2)
        v += __shfl_down_sync(0xffffffff, v, d);
    return v;  // lane 0 now holds the sum of all 32 lanes
}
```

In warp 1, "lane 0" is thread 32.

*The memory rules are per lane.* #link(<sec-coalescing>)[Coalescing] and #link(<sec-banks>)[bank conflicts] look at the 32 addresses the lanes of one warp give in one instruction.

#hint[A lane is not a core either. A partition serves a warp's 32 lanes with as many units of the right kind as it has: 32 FP32 lanes, but only 4 SFUs, so an `__expf` for a whole warp takes several cycles to go through them. The CUDA guide's throughput table says the same per SM: 128 FP32 results per clock, 16 for `exp2` or `sin`.]

== Registers: Private, Not Single <sec-registers>

Each thread's registers are private: no other thread can read them, except by a shuffle, which copies a value. *Private does not mean one register per thread.*

- The compiler decides how many 32-bit registers each thread of a kernel gets, the same number for every thread, up to 255. `nvcc -Xptxas -v` prints it per kernel, as `Used 40 registers`.
- Local scalars, pointers, loop counters and intermediate values all live in registers. A `double` or a 64-bit pointer takes two.
- The SM has 65,536 registers, 16,384 per partition, and divides them among all resident threads.

An instruction reads an operand for all 32 lanes at once, so the register file is laid out by warp: *register R5 of a warp is one 128-byte row*, 32 lanes × 4 bytes, and lane _k_'s slot in it is thread _k_'s R5. A thread's registers are a column through its warp's rows:

#figure(fig.fig-regfile(), caption: [The register file, logically: one row per register of each warp, one column per lane. Thread 37's 40 registers are lane 5's column in warp 1's rows.]) <fig-regfile>

Allocation follows the same layout: registers are handed out per warp, in units of 256 on compute capability 8.x, so a kernel that uses 37 registers per thread is charged 40 (37 × 32 = 1,184, rounded up to 1,280).

The SM's four register files are not one pool. *Which registers a lane can reach narrows in three steps:*

+ *A warp stays in one partition.* NVIDIA's #link("https://docs.nvidia.com/nsight-compute/ProfilingGuide/index.html")[Nsight Compute guide] puts it directly: "A warp is allocated to a sub partition and resides on the sub partition from launch to completion." Its registers are allocated in that partition's register file, its instructions are issued by that partition's scheduler and run on that partition's units. A warp in partition 0 has no path to the register file of partition 1.
+ *A lane reads its own column.* An ordinary instruction reads and writes only its lane's slot in its own warp's rows. The other warps' registers in the same file are out of reach.
+ *A shuffle stays inside the warp.* `__shfl_sync` and its variants read another lane's register, but only within the same warp, and so within the same partition.

A block with more than one warp usually has warps in several partitions, so *threads in different warps exchange data through shared memory*, which all 4 partitions reach, and wait for each other with `__syncthreads()`. The split also sets two limits. A partition holds at most 48 / 4 = 12 warps. And one warp's registers must fit in a single partition's 16,384: at the 255-register maximum a warp takes 255 × 32 = 8,160, rounded up to 8,192, so a partition still holds two such warps.

When a thread needs more registers than it gets, because it would exceed 255 or because `__launch_bounds__` or `-maxrregcount` caps it, the compiler *spills* values to _local memory_. Despite the name, local memory is per-thread space in device memory, cached in L1 and L2; `-Xptxas -v` reports it as `bytes spill stores`. Arrays indexed by a value known only at run time go to local memory too, since registers cannot be indexed.

= Occupancy <sec-occupancy>

Registers and shared memory hold the state of every resident warp, so *how many warps an SM can hold is the smallest of four limits*:

#table(
  columns: 3,
  table.header([Resource], [Per SM], [Per block]),
  [Warps], [48 (1,536 threads)], [32 (1,024 threads)],
  [Blocks], [16], [—],
  [Registers], [65,536], [65,536],
  [Shared memory], [up to 100 KB], [up to 99 KB],
)

With #mi(`W`) warps per block, #mi(`R`) registers per warp (rounded up to a multiple of 256) and #mi(`S`) KB of shared memory per block:

#mitex(`\text{blocks per SM} = \min\left(16,\ \left\lfloor \frac{48}{W} \right\rfloor,\ \left\lfloor \frac{65536}{W R} \right\rfloor,\ \left\lfloor \frac{100}{S + 1} \right\rfloor\right)`)

The extra 1 KB per block is shared memory the driver reserves for itself on compute capability 8.x. Four configurations:

#figure(fig.fig-occupancy(), caption: [The 48 warp slots of one A6000 SM under four launch configurations. Each colour band is one block.]) <fig-occupancy>

- *256 threads, 32 registers.* Registers would allow 8 blocks (8,192 each), but 48 warps allow 6: the SM is full.
- *32 threads.* One warp per block, and the 16-block limit stops at 16 warps, a third of the SM. *A block needs at least 48 / 16 = 3 warps, 96 threads, to fill an A6000 SM.*
- *256 threads, 64 registers.* 16,384 registers per block, so 4 blocks use all 65,536.
- *40 KB of shared memory per block.* 2 × 41 KB fits in 100 KB; 3 × 41 KB does not.

Occupancy is resident warps over 48. It is not a goal in itself: it sets how many warps each scheduler can choose from, and the next section shows when that is enough.

= Issuing Instructions

Every cycle, each partition's scheduler picks one of its warps that is _ready_, meaning the operands of its next instruction are available, and issues that instruction for all 32 lanes. With 4 partitions, an SM issues up to 4 warp instructions per cycle, and a partition holds at most 48 / 4 = 12 warps to choose from.

*Issuing and executing are separate steps*, and they overlap:

- *Issue*: the scheduler hands the instruction to a pipeline. At most one per cycle per scheduler.
- *Execute*: the pipeline delivers the result some cycles later. On V100, #link("https://arxiv.org/abs/1804.06826")[Jia et al.] measured about 4 cycles for a dependent FP32 FMA, about 19 for a shared-memory load and about 375 for a load that misses L2.

A warp whose next instruction needs a result still in flight is _stalled_, and the scheduler issues from another warp. *Switching costs nothing*: the registers a thread was given (#link(<sec-registers>)[Registers]) stay allocated to its warp, in its partition's register file, until the warp exits. Every resident warp's state is therefore already in place, and there is nothing to save or restore. This is what the SM's 65,536 registers (256 KB) are for: they hold the live state of every resident warp at once, all 48 when each thread uses at most 40 registers.

#figure(fig.fig-issue(), caption: [One scheduler, a program `I1 I2 LD I3 I4 I5` where `I3` needs the load, and a load latency of 10 cycles. With 4 warps the others fill the wait; with 2 the scheduler idles for 6 of 16 cycles.]) <fig-issue>

*The rule behind the figure*: a warp issues #mi(`k`) instructions, then waits #mi(`L`) cycles for a result. While it waits, each of the other #mi(`W - 1`) warps fills #mi(`k`) cycles, so the scheduler stays busy when

#mitex(`(W - 1)\,k \ge L - 1, \qquad \text{roughly} \quad W \ge L / k.`)

In @fig-issue, #mi(`k = 3`) and #mi(`L = 10`): 4 warps cover the wait exactly, 2 leave a gap of #mi(`10 - 1 - 3 = 6`) cycles. With real latencies:

- *A chain of dependent FMAs*, #mi(`L \approx 4`), #mi(`k = 1`): 4 warps per scheduler suffice.
- *A load from device memory*, #mi(`L \approx 400`), with 20 independent instructions before the result is needed: 20 warps per scheduler, more than the 12 a partition can hold. Occupancy alone cannot hide this; each warp needs more independent work before it stalls, for example several loads issued before the first is used, which raises #mi(`k`).

= Memory Hierarchy

#figure(fig.fig-memory(), caption: [Where each kind of memory sits, and who can see it.]) <fig-memory>

#table(
  columns: 5,
  table.header([Memory], [Where], [Visible to], [A6000 size], [Latency on V100]),
  [Registers], [partition], [one thread], [256 KB per SM], [part of the instruction],
  [Shared memory], [SM], [one block], [up to 100 KB per SM], [~19 cycles],
  [L1 cache], [SM, same SRAM], [the SM, managed by hardware], [128 KB minus shared], [~28 cycles (hit)],
  [L2 cache], [chip], [all SMs], [6 MB], [~193 cycles (hit)],
  [Device memory], [off chip], [all threads; the host by copies], [48 GB], [~375 cycles (L2 miss)],
)

The latencies are Jia et al.'s V100 measurements; Ampere is in the same range. In `scale`, `i`, `a` and the pointer `x` are in registers, and `x[i]` is in device memory, reached through L2 and L1. Added up over 84 SMs, the A6000 has 21 MB of registers and 10.5 MB of L1 and shared memory, both more than its 6 MB of L2. *Most of the on-chip memory is registers.*

== Shared Memory and L1

The two share one SRAM but are used differently:

#cols(labels: ([Shared memory: explicit], [L1: implicit]))[
  ```cuda
  __shared__ float tile[256];
  tile[threadIdx.x] = global_data[idx];
  __syncthreads();
  ```
][
  ```cuda
  float v = global_data[idx];
  ```
]

- *Shared memory* is allocated per block with `__shared__` and lives as long as the block. Code decides what goes in, when, and who reads it.
- *L1* is a cache managed by the hardware. It keeps lines of global and local memory that loads brought in; code cannot address a line, only issue loads that may hit it.

Below the SM, shared memory has one more level: its 32 banks. Its "~19 cycles" holds only when the 32 lanes of a warp hit 32 different banks, or the same word; #link(<sec-banks>)[Banks] covers the rule.

How the 128 KB is split is set per kernel: on compute capability 8.6 the shared part is 0, 8, 16, 32, 64 or 100 KB, picked by the driver from `cudaFuncAttributePreferredSharedMemoryCarveout` and the kernel's needs. A block that wants more than 48 KB of dynamic shared memory must ask for it with `cudaFuncAttributeMaxDynamicSharedMemorySize`.

= Global Memory: Sectors and Coalescing <sec-coalescing>

Device memory is read in *32-byte sectors*; a cache line in L1 and L2 is 128 bytes, four sectors. When a warp executes a load, the load/store unit collects the 32 lanes' addresses and fetches every distinct sector they touch. In the words of NVIDIA's #link("https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/")[Best Practices Guide], the accesses of a warp "coalesce into a number of transactions equal to the number of 32-byte transactions necessary to service all of the threads of the warp". *The cost of a load is the number of sectors, not the number of lanes.*

#figure(fig.fig-coalesce(), caption: [One warp loading 4-byte floats. A sector is 8 floats; every touched sector moves 32 bytes, whether one lane uses it or eight do.]) <fig-coalesce>

#table(
  columns: 4,
  table.header([Access], [Sectors], [Bytes moved], [Useful]),
  [`x[i]`], [4], [128], [100%],
  [`x[i + 1]`, off by one float], [5], [160], [80%],
  [`x[2 * i]`], [8], [256], [50%],
  [`x[idx[i]]`, scattered], [up to 32], [1,024], [12.5%],
)

*Coalescing asks that adjacent lanes read adjacent addresses in the same instruction.* What one thread reads over time doesn't matter. That is the opposite of the CPU habit of giving each thread its own contiguous chunk:

#cols(labels: ([Each thread walks its own chunk], [Lanes walk together]))[
  ```cuda
  // lanes are N floats apart:
  // up to 32 sectors per load
  for (int k = 0; k < N; k++)
      s += x[tid * N + k];
  ```
][
  ```cuda
  // lane i reads float i of each
  // 32-float stretch: 4 sectors
  for (int k = tid; k < total; k += nthreads)
      s += x[k];
  ```
]

#xref("tilelang-gemv") measures this on a GEMV: swapping the two thread-index dimensions so that lanes read along a row takes the kernel from 614 µs to 170 µs. Nsight Compute shows it directly, as sectors per request: 4 for a fully coalesced warp of 4-byte loads.

= Shared Memory: Banks <sec-banks>

Shared memory is split into *32 banks*, each 4 bytes wide, and consecutive 4-byte words go to consecutive banks:

#mitex(`\text{bank} = \left(\frac{\text{byte address}}{4}\right) \bmod 32`)

Bytes 0–3 are in bank 0, 4–7 in bank 1, ..., 124–127 in bank 31, and byte 128 is in bank 0 again. *Each bank serves one word per cycle*, so for one warp instruction:

- all 32 lanes in different banks: one pass;
- #mi(`n`) lanes on _different_ words of one bank: #mi(`n`) passes, an #mi(`n`)-way bank conflict;
- several lanes on the _same_ word: the word is read once and broadcast, no conflict.

*Only "same bank, different word" serializes.*

#figure(fig.fig-banks(), caption: [Shared memory as 32 bank columns, one 4-byte word per cell, with the lane that reads each word. The number of distinct words in the busiest bank is the number of passes.]) <fig-banks>

In `s[2 * lane]`, lane 0 reads word 0 and lane 16 reads word 32, both in bank 0. Any even stride conflicts; an odd stride never does, since it is coprime with 32 and so visits all 32 banks.

== Padding

The common case is a tile read by column, as in a matrix transpose. With 32 floats per row, element `[r][c]` is word `32r + c`, and its bank is `c` for every row: a column read puts all 32 lanes in one bank. One unused float per row moves each row one bank over:

```cuda
__shared__ float tile[32][32];  // tile[lane][c]: word 32 * lane + c, bank c: 32-way
__shared__ float tile[32][33];  // tile[lane][c]: word 33 * lane + c, bank (lane + c) % 32: 1 pass
```

#figure(fig.fig-padding(), caption: [Reading column 0 of a 32 × 32 float tile. Without padding every element is in bank 0; with one pad word per row, element `[k][0]` is in bank `k`.]) <fig-padding>

The cost is 32 floats, 128 bytes per tile.

= Summary

#callout(kind: "info", title: "OVERVIEW / One launch, top to bottom")[
  + A *grid* of blocks is spread over the SMs; each *block* runs whole on one SM, with as many blocks per SM as warps, registers and shared memory allow.
  + Each block is cut into *warps* of 32 consecutive threads; each warp belongs to one of the SM's 4 partitions, whose scheduler issues one warp instruction per cycle.
  + Each *thread* occupies one *lane* of its warp. Its registers, as many as the compiler chose, are its lane's column in the partition's register file.
  + The block's *shared memory* sits in its SM's SRAM, spread over 32 *banks*; each bank serves one 4-byte word per cycle to the lanes of a warp.
]

Both memory rules are about one warp instruction and the 32 addresses its lanes give:

- *Global memory*: how many 32-byte sectors the addresses touch. Adjacent lanes should read adjacent words.
- *Shared memory*: how many different words fall in the busiest bank. Lanes should spread over banks, or read the same word.
