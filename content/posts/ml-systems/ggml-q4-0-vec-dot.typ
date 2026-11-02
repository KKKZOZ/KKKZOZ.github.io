#import "@tola/source:0.0.0": tola-meta
#import "/utils/mitex.typ": mi, mitex
#import "/utils/ui.typ": callout, hint, two-cols, xref
#import "/figures/ggml-vec-dot.typ" as fig

#tola-meta((
  title: "ggml Q4_0 vec_dot Walkthrough",
  date: "2026-10-29",
  summary: "How ggml's CPU backend computes a Q4_0 matrix-vector product during decode, split across threads, with and without repacking.",
  tags: ("LLM-Inference", "ggml"),
  weight: 10,
))

#hint[ggml's tensors, contexts and memory allocation are covered in #xref("/posts/ml-systems/ggml-with-cpp/").]

```text
dst[12288] = W_gate[12288 × 4096] · x[4096]      W_gate: Q4_0, x: F32
```

This is the FFN gate projection of Qwen3-8B for one token: decode handles one token per step, so every weight matrix is multiplied by a vector. Each row of `W` holds `K` = 4096 weights, and there are `N` = 12288 rows, one per output.

Setup:
- Apple M4 Pro: 10 performance and 4 efficiency cores; NEON with `dotprod` and `i8mm`.
- ggml `83835ff` (Aug 2025), Release build, CPU backend only.
- The thread figures use the same ggml plus a trace in `mul_mat` that logs which rows each thread took, and when.

= Quantization Types in GGUF

A GGUF file stores each tensor with a `ggml_type`. Quantized types are _block formats_: a row is cut into fixed-size blocks, and each block stores one or more scales and a low-bit integer code per weight.

#figure(fig.fig-quant-types(), caption: [The same 256 weights stored as `F16`, `Q8_0`, `Q4_0` and `Q2_K`.]) <fig-quant-types>

== `Q8_0` and `Q4_0`

From `src/ggml-common.h`:

```c
#define QK8_0 32
typedef struct {
    ggml_half d;           // delta
    int8_t  qs[QK8_0];     // quants
} block_q8_0;              // 2 + 32 = 34 bytes per 32 values -> 8.5 bit/weight

#define QK4_0 32
typedef struct {
    ggml_half d;           // delta
    uint8_t qs[QK4_0 / 2]; // nibbles / quants
} block_q4_0;              // 2 + 16 = 18 bytes per 32 values -> 4.5 bit/weight
```

- *Block*: 32 consecutive values of a row.
- *`d`*: one `fp16` scale per block, called `delta` in the comment because it is the step between two neighboring codes.
- *`qs`*: one integer code #mi(`q`) per value, which decodes as #mi(`d \cdot q`).

Neither format stores an offset, so code #mi(`0`) always decodes to #mi(`0.0`). That is what `_0` means, while `Q4_1` and `Q5_1` add a per-block offset #mi(`m`) and decode as #mi(`d \cdot q + m`).

`Q8_0` is quantized by `quantize_row_q8_0_ref`, which sets #mi(`d = \mathrm{amax} / 127`), where #mi(`\mathrm{amax}`) is the largest absolute value in the block, and stores #mi(`q = \mathrm{round}(x / d)`), which falls in #mi(`[-127, 127]`).

`Q4_0` stores each code as a 4-bit nibble, two per byte, and subtracts 8 when decoding: #mi(`q = \mathrm{nib} - 8`), so #mi(`q \in [-8, 7]`). `quantize_row_q4_0_ref` takes the value with the largest magnitude, keeps its sign as #mi(`\mathrm{max}`), and sets #mi(`d = \mathrm{max} / (-8)`), so that value decodes exactly, as code #mi(`-8`).

#callout(kind: "info", title: [EXAMPLE / Quantizing one `Q4_0` block])[
  A real block has 32 values, but 4 keep the numbers short: #mi(`x = (0.32, -0.80, 0.13, 0.47)`).
  + *Scale.* The largest magnitude is #mi(`-0.80`), so #mi(`d = -0.80 / (-8) = 0.10`).
  + *Codes.* #mi(`\mathrm{nib} = \min(15, \lfloor x / d + 8.5 \rfloor)`), and #mi(`q = \mathrm{nib} - 8`). Adding #mi(`8`) makes #mi(`x / d \in [-8, 8]`) non-negative, and the extra #mi(`0.5`) makes the C cast `(int8_t)`, which truncates, round to the nearest code. #mi(`\min(15, \cdot)`) is for #mi(`x / d \ge 7.5`), which would round to #mi(`16`); only a value of the opposite sign with nearly the same magnitude as the largest gets there.
    #table(
      columns: 5,
      table.header(mi(`x`), mi(`x / d + 8.5`), mi(`\mathrm{nib}`), mi(`q`), [decoded #mi(`d \cdot q`)]),
      mi(`0.32`), mi(`11.7`), mi(`11`), mi(`3`), mi(`0.30`),
      mi(`-0.80`), mi(`0.5`), mi(`0`), mi(`-8`), mi(`-0.80`),
      mi(`0.13`), mi(`9.8`), mi(`9`), mi(`1`), mi(`0.10`),
      mi(`0.47`), mi(`13.2`), mi(`13`), mi(`5`), mi(`0.50`),
    )
  + *Packing.* Value #mi(`j`) goes in the low nibble of byte #mi(`j`) and value #mi(`j + 2`) in the high nibble (#mi(`j + 16`) in a real block), so `qs = {0x9B, 0xD0}`.
  Every value decodes to within #mi(`d / 2 = 0.05`) of the original, and #mi(`-0.80`) exactly. If the largest-magnitude value were positive, #mi(`d`) would be negative, and that value would still be code #mi(`-8`).
]

== `Q2_K`: two levels of scales

The `_K` types ("k-quants") split a row into _super-blocks_ of 256 weights, and each super-block into 16 groups of 16. `Q2_K` gives each weight a 2-bit code, so a group has only 4 levels.

#callout(kind: "info", title: "INSIGHT / Why two levels of scales")[
  With 4 levels, a group has to be small, since 4 levels spread over 256 weights are far too coarse. Small groups, however, make the scales expensive: a group of 16 has #mi(`16 \times 2 = 32`) bits of codes, and an `fp16` scale plus an `fp16` offset is another 32:
  #table(
    columns: 4,
    table.header([Layout], [Codes], [Scale + offset], [bit/weight]),
    [16 per group, `fp16` scale and offset], [2], [2], [4.0],
    [`Q2_K`: 4-bit #mi(`s_j`), #mi(`m_j`) per 16, `fp16` #mi(`d`), #mi(`\mathrm{dmin}`) per 256], [2], [0.625], [2.625],
  )
  With `fp16` scales and offsets, half the bits are metadata, so `Q2_K` keeps groups of 16 but stores their scales and offsets as 4-bit integers, plus two `fp16` values per 256 weights.
]

A weight decodes in two steps:

+ *Per group.* Group #mi(`j`) has a scale and an offset, and a weight is #mi(`\mathrm{scale}_j \cdot q - \mathrm{offset}_j`), with #mi(`q \in \{0, 1, 2, 3\}`). The offset moves the 4 levels to where the group's values are; without it they would always be 0, 1, 2 and 3 times the scale.
+ *Per super-block.* #mi(`\mathrm{scale}_j`) and #mi(`\mathrm{offset}_j`) are 4-bit integers #mi(`s_j`) and #mi(`m_j`), times two `fp16` values shared by the whole super-block:
  #mitex(`\mathrm{scale}_j = d \cdot s_j, \qquad \mathrm{offset}_j = \mathrm{dmin} \cdot m_j`)
  ggml calls the offsets _mins_, hence the names `dmin` and #mi(`m_j`).

Together:

#mitex(`w = d \cdot s_j \cdot q - \mathrm{dmin} \cdot m_j`)

@fig-q2k draws this with the numbers of the example below.

#figure(fig.fig-q2k(), caption: [`Q2_K`'s two levels of scales: per super-block `d` and `dmin`, per group #mi(`s_j`) and #mi(`m_j`).]) <fig-q2k>

#callout(kind: "info", title: [EXAMPLE / Two groups of one `Q2_K` super-block])[
  Say the super-block has #mi(`d = 0.01`) and #mi(`\mathrm{dmin} = 0.005`).
  - Group 3 stores #mi(`s = 2`), #mi(`m = 10`): #mi(`\mathrm{scale} = 0.02`), #mi(`\mathrm{offset} = 0.05`). Its 4 levels are #mi(`-0.05, -0.03, -0.01, 0.01`).
  - Group 12 stores #mi(`s = 6`), #mi(`m = 4`): #mi(`\mathrm{scale} = 0.06`), #mi(`\mathrm{offset} = 0.02`). Its 4 levels are #mi(`-0.02, 0.04, 0.10, 0.16`).
  Group 3 covers a narrow range around #mi(`-0.02`) in small steps, while group 12 covers a wider, mostly positive range.
]

In memory (`src/ggml-common.h`):

```c
#define QK_K 256
typedef struct {
    uint8_t scales[QK_K/16]; // scales and mins, quantized with 4 bits
    uint8_t qs[QK_K/4];      // quants
    ggml_half d;             // super-block scale for quantized scales
    ggml_half dmin;          // super-block scale for quantized mins
} block_q2_K;                // 16 + 64 + 4 = 84 bytes per 256 weights -> 2.625 bit/weight
```

The offsets have no array of their own: `scales[j]` holds #mi(`s_j`) in its low 4 bits and #mi(`m_j`) in its high 4 bits, and the decoder splits them with `sc & 0xF` and `sc >> 4`. Per weight, that is 2 bits of code, 0.5 bits for #mi(`s_j`) and #mi(`m_j`) (8 bits per 16 weights), and 0.125 bits for `d` and `dmin` (32 bits per 256): 2.625 bits.

== Types vs presets: `Q4_K_M`, `Q2_K`, `Q2_K_S`

`Q4_K` is a tensor type, a block format like the ones above, while `Q4_K_M` is a _preset_ for `llama-quantize` (a `llama_ftype` in llama.cpp). The preset stores most tensors in its base type, `q4_K`, and a few sensitive ones, such as `attn_v` and `ffn_down`, in a type with more bits.

The suffix sets how many tensors get the extra bits: fewest for `_S`, more for `_M`, most for `_L`; more bits mean a larger file and a more accurate model. `llama-quantize --help` lists the numbers for Llama-3-8B, where perplexity measures how well a model predicts text (lower is better) and the last column is how much it rises over the `fp16` model:

#table(
  columns: 4,
  table.header([Preset], [Base type], [File size], [Perplexity increase]),
  [`Q3_K_S`], [`q3_K`], [3.41 GB], [+1.63],
  [`Q3_K_M`], [`q3_K`], [3.74 GB], [+0.66],
  [`Q3_K_L`], [`q3_K`], [4.03 GB], [+0.56],
  [`Q4_K_S`], [`q4_K`], [4.37 GB], [+0.27],
  [`Q4_K_M`], [`q4_K`], [4.58 GB], [+0.18],
  [`Q5_K_S`], [`q5_K`], [5.21 GB], [+0.10],
  [`Q5_K_M`], [`q5_K`], [5.33 GB], [+0.06],
)

Not every base type has all three: `Q3_K` has `_S`, `_M` and `_L`; `Q4_K` and `Q5_K` have `_S` and `_M`; `Q2_K` has `Q2_K` and `Q2_K_S`; `Q6_K` has none. A preset with no suffix, such as `Q4_K`, means its `_M`.

Qwen3-8B-Q4_K_M.gguf, read with ggml's `gguf_init_from_file`:

#figure(fig.fig-gguf-mix(), caption: [Tensor types inside Qwen3-8B-Q4_K_M.gguf.]) <fig-gguf-mix>

- Most tensors are `q4_K`.
- `attn_v` and `ffn_down` are `q6_K` on 18 of the 36 layers: the first 4, the last 5, and every third one in between (`use_more_bits()` in `llama-quant.cpp`).
- `output` is also `q6_K`; the norm vectors stay `f32`.

There is no `Q2_K_M`, only `Q2_K` and `Q2_K_S`. For Qwen3-8B (32 query heads and 8 KV heads, so `n_gqa = 4`), their rules give:

#table(
  columns: 3,
  table.header([Tensor], [`Q2_K` preset], [`Q2_K_S` preset]),
  [most tensors], [`q2_K`], [`q2_K`],
  [`attn_v`], [`q4_K` (`n_gqa ≥ 4`)], [`q4_K` (`n_gqa ≥ 4`)],
  [`ffn_down`], [`q3_K`], [`q4_K` in the first 1/8 of layers, else `q2_K`],
  [`attn_output`], [`q3_K`], [`q2_K`],
  [`output`], [`q6_K`], [`q6_K`],
)

On the CPU, each type has its own dot-product kernel and its own format for the activation: `Q4_0` and `Q8_0` pair with `Q8_0`, and the `_K` types with `Q8_K` (8-bit codes in blocks of 256). The rest of the post uses `Q4_0`, whose kernel is the shortest, but how `mul_mat` splits the work across threads doesn't depend on the type.

= One Row: vec_dot

The CPU backend's entry for `Q4_0` (`src/ggml-cpu/ggml-cpu.c`):

```c
[GGML_TYPE_Q4_0] = {
    .from_float   = quantize_row_q4_0,
    .vec_dot      = ggml_vec_dot_q4_0_q8_0,
    .vec_dot_type = GGML_TYPE_Q8_0,
    .nrows        = 2,   // 1 without __ARM_FEATURE_MATMUL_INT8
},
```

- *`vec_dot_type`*: the format `x` is converted to first, here `Q8_0`, so the inner loop multiplies int8 by int8. The conversion runs once per `mul_mat` and covers 4096 values, against 50 million weights.
- *`from_float`*: the function that converts `x`.
- *`vec_dot`*: computes one output, the dot product of one row of `W` and `x`.
- *`nrows`*: rows per `vec_dot` call; see the note at the end of this section.

Both operands are now in blocks of 32 with one scale each, and the blocks line up along `K`. For one output, row `r` of `W` against `x`:

- `wq[b][j]` is the code of value `j` in block `b` of the row, as an int8 (for `Q4_0`, the nibble minus 8), and `wd[b]` is that block's scale.
- `xq[b][j]` and `xd[b]` are the same for `x`, after its conversion to `Q8_0`.

#two-cols(
  ([Decode every value],
  ```c
  float sum = 0;
  for (int i = 0; i < 4096; i++) {
    int b = i / 32, j = i % 32;
    float w = wd[b] * wq[b][j];
    float a = xd[b] * xq[b][j];
    sum += w * a;
  }
  ```),
  ([ggml: scales once per block],
  ```c
  float sum = 0;
  for (int b = 0; b < 128; b++) {
    int isum = 0;
    for (int j = 0; j < 32; j++)
      isum += wq[b][j] * xq[b][j];
    sum += wd[b] * xd[b] * isum;
  }
  ```),
)

The left version turns each weight and each activation into a float before multiplying: 3 float multiplies per value, 12288 per row. But `w * a` is the scale product `wd[b] * xd[b]` times the code product `wq[b][j] * xq[b][j]`, and the scale product is the same for all 32 values of a block. So the right version multiplies the codes as integers, which is exact, and applies the two scales once per block: 128 times per row instead of 4096.

One `Q4_0` block and one `Q8_0` block, from a small probe (`K = 64`):

#figure(fig.fig-block-layout(), caption: [One `Q4_0` block and one `Q8_0` block from the probe.]) <fig-block-layout>

Byte `qs[j]` holds element `j` in its low nibble and element `j + 16` in its high nibble. One AND gives elements 0–15 in order and one shift gives 16–31, with no shuffle, and each half lines up with one half of the `Q8_0` block. The portable C version, where `x` is the weight row and `y` the quantized activation:

```c
for (int ib = 0; ib < nb; ++ib) {
    int sumi0 = 0;
    int sumi1 = 0;

    for (int j = 0; j < qk/2; ++j) {
        const int v0 = (x[ib].qs[j] & 0x0F) - 8;
        const int v1 = (x[ib].qs[j] >>   4) - 8;

        sumi0 += (v0 * y[ib].qs[j]);
        sumi1 += (v1 * y[ib].qs[j + qk/2]);
    }

    int sumi = sumi0 + sumi1;
    sumf += sumi*GGML_CPU_FP16_TO_FP32(x[ib].d)*GGML_CPU_FP16_TO_FP32(y[ib].d);
}
```

== The NEON kernel

A NEON register is 128 bits, split into _lanes_: 16 int8 values, or 4 int32 or `fp32` values. The ARM version (`src/ggml-cpu/arch/arm/quants.c`) reads the codes of a whole `Q4_0` block with one 16-byte load:

```c
const uint8x16_t v0_0 = vld1q_u8(x0->qs);

const int8x16_t v0_0ls = vsubq_s8(vreinterpretq_s8_u8(vandq_u8  (v0_0, m4b)), s8b);  // elements 0-15
const int8x16_t v0_0hs = vsubq_s8(vreinterpretq_s8_u8(vshrq_n_u8(v0_0, 4)),   s8b);  // elements 16-31

const int8x16_t v1_0l = vld1q_s8(y0->qs);
const int8x16_t v1_0h = vld1q_s8(y0->qs + 16);

const int32x4_t p_0 = ggml_vdotq_s32(ggml_vdotq_s32(vdupq_n_s32(0), v0_0ls, v1_0l), v0_0hs, v1_0h);

sumv0 = vmlaq_n_f32(sumv0, vcvtq_f32_s32(p_0), GGML_CPU_FP16_TO_FP32(x0->d)*GGML_CPU_FP16_TO_FP32(y0->d));
```

#figure(fig.fig-neon-block(), caption: [One block of `vec_dot` on NEON: unpack, two `SDOT`s, scale.]) <fig-neon-block>

`ggml_vdotq_s32` is `SDOT` from the `dotprod` extension, which multiplies 16 pairs of int8 values and adds each run of 4 consecutive products into one of 4 int32 lanes. Two `SDOT`s cover the block's 32 products. The 4 lanes are converted to `fp32`, multiplied by the two scales and added lane by lane into the accumulator `sumv0`, without being summed together yet.

Each iteration takes two blocks, each into its own accumulator, so one block's multiply-add doesn't wait for the previous one. A row of 4096 values is 128 blocks, so 64 iterations:

#figure(fig.fig-neon-loop(), caption: [The NEON loop takes two blocks per iteration into two accumulators.]) <fig-neon-loop>

At the end of the row, the two accumulators are added and `vaddvq_f32` sums their 4 lanes.

#hint[With `i8mm`, `vec_dot` can also be called with `nrc = 2` and use `SMMLA` to compute a 2 × 2 tile: 2 rows × 2 columns of `x`. That needs two columns, so it only helps prefill; in decode `x` has one column and `nrc` is 1. On x86, AVX2 unpacks a block into one 256-bit register and uses `maddubs` / `madd` (or `dpbusd` with VNNI) instead of `SDOT`.]

= Who Computes What

`vec_dot` runs on one thread and produces one output, so the parallelism comes from a thread pool: ggml starts `nth` threads once, and for each op every thread calls the same function, here `ggml_compute_forward_mul_mat`, with its own index `ith`, and the function decides which part of the work is thread `ith`'s. For the gate projection:

#figure(fig.fig-call-tree(), caption: [How the gate projection's `mul_mat` is split into chunks, tiles and `vec_dot` calls.]) <fig-call-tree>

- *Chunk*: 64 rows of `W`, the unit a thread takes; 12288 / 64 = 192 chunks.
- *Tile*: 16 rows; a chunk is 4 tiles. `vec_dot` writes a tile's 16 results into a small buffer, which is then copied into `dst`. In prefill a tile is 16 rows × 16 columns of `x`, so each column stays in cache while 16 rows use it. In decode there is one column, and a tile is just 16 `vec_dot` calls.
- *`vec_dot`*: one row, 64 NEON iterations.

Only chunks are shared between threads: once a thread takes a chunk, it computes all of it.

== The two phases

```c
// phase 1: every thread quantizes its own slice of x (along K) into wdata
int64_t ne10_block_start = (ith * ne10/bs) / nth;
int64_t ne10_block_end   = ((ith + 1) * ne10/bs) / nth;
from_float(x + ne10_block_start*bs, wdata + ne10_block_start*nbw0,
           (ne10_block_end - ne10_block_start) * bs);

if (ith == 0) {
    atomic_store_explicit(&params->threadpool->current_chunk, nth, memory_order_relaxed);
}
ggml_barrier(params->threadpool);

// phase 2: chunks of dst rows
int chunk_size = 16;
if (nr0 == 1 || nr1 == 1) {
    chunk_size = 64;                       // decode: nr1 = 1
}
int64_t nchunk0 = (nr0 + chunk_size - 1) / chunk_size;    // 12288 / 64 = 192
...
int current_chunk = ith;                   // first chunk: my own index
while (current_chunk < nchunk0 * nchunk1) {
    ggml_compute_forward_mul_mat_one_chunk(params, dst, ..., ir0_start, ir0_end, ...);
    current_chunk = atomic_fetch_add_explicit(&params->threadpool->current_chunk, 1, memory_order_relaxed);
}
```

The loops over the batch dimensions are left out.

Phase 1 splits `x` along `K`, the same way every time. `x` has 4096 / 32 = 128 blocks, and thread `ith` quantizes blocks `[ith · 128 / nth, (ith + 1) · 128 / nth)` into `wdata`, a scratch buffer shared by all threads. Every thread then waits at `ggml_barrier` until all `nth` have arrived, since in phase 2 any thread may read any block of `x`.

Phase 2 splits the output into chunks of up to `chunk_size` rows by `chunk_size` columns of `dst`. Decode has one column (`nr1 = 1`), where 16 × 16 would mean only 16 outputs per chunk, so ggml raises `chunk_size` to 64: 192 chunks of 64 rows. Threads take chunks as they go:

- Thread `i` starts on chunk `i`, so chunks 0 to `nth − 1` are already taken, and thread 0 sets the shared counter `current_chunk` to `nth` before the barrier.
- When a thread finishes a chunk, it calls `atomic_fetch_add` on the counter, which returns the old value and adds 1 in one atomic step. The old value is the thread's next chunk, so no two threads get the same one.
- Once the counter reaches 192, threads leave the loop.

With fewer than `4 · nth` chunks, or on a NUMA system, ggml skips this and gives each thread one equal range. That doesn't happen here: 192 chunks is well above `4 · 14` = 56.

One traced `mul_mat` with 1, 2 and 4 threads, where each square is a chunk, 16 per line in row order, coloured by the thread that computed it:

#figure(fig.fig-threads-plain(), caption: [Which thread computed each chunk, with 1, 2 and 4 threads.]) <fig-threads-plain>

- 1 thread: thread 0 does all 192 chunks in order.
- 2 threads: they run at the same speed and alternate: `t0` takes chunk 0, `t1` chunk 1, then each takes the next free one.
- 4 threads: no regular pattern, since small timing differences decide who reaches the counter first. Each thread still gets 46–49 chunks, but which rows it computes is only decided at run time.
- Phase 1 takes under 1 µs, and phase 2, which takes the rest, halves with each doubling of threads: 1112, 587, 310 µs.

The same 4-thread run on a timeline, one lane per thread, together with the repack path from the next section:

#figure(fig.fig-gantt-4(), caption: [A 4-thread `mul_mat` on a timeline: `vec_dot` path vs repack path.]) <fig-gantt-4>

All 4 lanes of the `vec_dot` path end within a few µs of each other, because the last chunks go to whichever thread is free. The repack path does the same work in 189 µs; each thread runs once, over a fixed quarter of the rows.

= The Repack Path

In ggml, a tensor's memory comes from a _buffer_, and the buffer's type decides how the data is laid out and which kernels run on it. With `GGML_CPU_REPACK` (on by default), the CPU backend has an extra buffer type, `CPU_REPACK`, and llama.cpp places `Q4_0` weights used by `MUL_MAT` in it unless `--no-repack` is given.

Copying a weight into a `CPU_REPACK` buffer rearranges it once, at load time, and a different kernel runs on the result. On this machine (`NEON` and `i8mm`, and 12288 rows, a multiple of 4) that kernel is `q4_0_4x8_q8_0`:

#figure(fig.fig-repack(), caption: [The repacked `block_q4_0x4` layout and the 4-row gemv kernel.]) <fig-repack>

== Layout

For every 4 rows, the 4 blocks at the same position along `K` become one `block_q4_0x4`: the 4 scales first, then the codes of the 4 rows, interleaved 8 bytes at a time.

== Dropping the − 8

The copy also XORs every byte with `0x88`, which flips the top bit of both nibbles: a nibble #mi(`u`) becomes #mi(`u \oplus 8`), which, read as a signed 4-bit number, is #mi(`u - 8`).

The kernel doesn't sign-extend it to int8; instead it moves each nibble into the top half of a byte (`<< 4` for the low nibble, `& 0xF0` for the high one), where the byte reads as #mi(`16 \cdot (u - 8)`). `SDOT` then returns 16 times the true sum, and the conversion to `fp32`, `vcvtq_n_f32_s32(ret, 4)`, treats the low 4 bits as a fraction, which divides by 16 in the same instruction.

== The gemv kernel

`ggml_gemv_q4_0_4x8_q8_0` works on 4 rows at once and issues as many `SDOT`s as 4 calls of `vec_dot`; what it saves is the work around them:

#table(
  columns: 3,
  table.header([Per block, 4 rows], [`vec_dot` × 4], [repack `gemv`]),
  [`SDOT`s], [8], [8],
  [Loads of `x`'s 32 codes], [4 times], [once],
  [`− 8` subtractions], [8], [none],
  [Scale multiply-adds], [4], [1, on a `float32x4` holding the 4 rows],
)

`vec_dot` sums its 4 lanes once, at the end of a row, while the `gemv` does one pairwise add per block, which leaves row #mi(`i`) in lane #mi(`i`), so its final `float32x4` holds the 4 outputs.

== Thread split

There are no chunks: thread `ith` takes rows `[ith · N / nth, (ith + 1) · N / nth)`, rounded up to a multiple of 4, and runs one `gemv` over them. In decode, phase 1 runs on thread 0 alone, since `x` has one column; it is tiny either way.

```c
int64_t src0_start = (ith * ne01) / nth;
int64_t src0_end   = ((ith + 1) * ne01) / nth;
src0_start = (src0_start % NB_COLS) ? src0_start + NB_COLS - (src0_start % NB_COLS) : src0_start;
src0_end   = (src0_end   % NB_COLS) ? src0_end   + NB_COLS - (src0_end   % NB_COLS) : src0_end;
...
gemv<BLOC_TYPE, INTER_SIZE, NB_COLS, PARAM_TYPE>(ne00,
        (float *) ((char *) dst->data + (iter * nb1)) + src0_start, ne01,
        (const char *) src0->data + src0_start * nb01,
        (const char *) src1_wdata + (src1_col_stride * iter), 1,
        src0_end - src0_start);
```

The two paths therefore differ in the kernel (4 rows at a time vs 1) and in scheduling (fixed ranges vs chunks taken at run time), and the benchmark below shows the effect of each.

= Performance: Decode, gate + up

The benchmark computes the gate and up projections of Qwen3-8B for one `F32` `x`. Each is a `Q4_0` `[12288 × 4096]` weight: 12288 × 4096 × 4.5 bits = 28.3 MB, 56.6 MB for both.

- The same quantized weights are loaded into a plain `CPU` buffer and into a `CPU_REPACK` buffer, and their outputs match to within `2.4e-6`.
- Each mode cycles through 8 copies of the weights, 450 MB in total, which doesn't fit in the caches, so the weights come from DRAM, as in a real decode step.
- Each entry is the median of 400 runs. Three separate runs agreed to within about 7%; the rows marked ≈ varied most.
- Speedup is `vec_dot` time / repack time. The last column is 56.6 MB divided by the repack time, e.g. 56.6 MB / 244 µs = 232 GB/s at 10 threads.

#table(
  columns: 5,
  table.header([Threads], [`vec_dot` (µs)], [repack (µs)], [Speedup], [repack, GB/s of weights]),
  [1], [2216], [1365], [1.62×], [41],
  [2], [1179], [688], [1.71×], [82],
  [4], [607], [353], [1.72×], [160],
  [6], [425], [286], [≈ 1.5×], [≈ 200],
  [8], [329], [256], [≈ 1.3×], [≈ 220],
  [10], [282], [244], [1.16×], [232],
  [12], [274], [336], [0.82×], [≈ 168],
  [14], [274], [490], [0.56×], [≈ 116],
)

- *Up to 4 threads*, memory bandwidth is far from used up, and the time depends on how many instructions each core runs; repack runs fewer per row and is 1.6–1.7× faster.
- *At 10 threads* (all performance cores), repack reads weights at 232 GB/s, close to the M4 Pro's 273 GB/s, and `vec_dot` at 56.6 MB / 282 µs = 200 GB/s. Both now mostly wait on memory, and the gap shrinks to 1.16×.
- *Beyond 10 threads*, repack slows down while `vec_dot` stays flat. A trace of one 14-thread `mul_mat`:

#figure(fig.fig-gantt-14(), caption: [One 14-thread `mul_mat`: the efficiency cores hold up the repack path.]) <fig-gantt-14>

In the `vec_dot` path, four of the 14 threads take about 18 µs per chunk instead of 7.5 µs, 2.4× slower. They probably ran on the 4 efficiency cores, though that is a guess from their speed, since macOS doesn't let a program pin threads to cores.

- In the `vec_dot` path, those 4 threads take fewer chunks (6–7 instead of 16–17), and the op ends when the chunks run out.
- In the repack path, each thread owns a fixed 1/14 of the rows, so the threads on slow cores (4, 5, 6 and 10 here, and 9 for part of its run) hold up the whole op: it takes 220 µs, while the fast threads were done at about 95 µs.

For CPU-only decode on this machine, use repack with 10 threads, one per performance core: gate + up take about 244 µs instead of 282. With more threads than performance cores, repack is the slower path.
