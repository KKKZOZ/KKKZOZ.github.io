---
title: "QServe W4A8KV4 Quantization and System Co-design for Efficient LLM Serving"
tags:
  - MLSys-25
  - Quantization
date: 2025-11-16
showtoc: true
---

> Extensive Reading

## Author Info

- [MIT HAN Lab](https://hanlab.mit.edu/)

## Background

- Common quantization formats for LLMs:
  - W8A8: 8-bit weights, 8-bit activations – almost lossless, widely deployed.
  - W4A16: 4-bit weights, 16-bit activations – also near-lossless; good for weight memory.
  - W4A4: 4-bit weights and activations – more aggressive, but accuracy drops and real GPU speedups are disappointing.
- On data center GPUs (A100, L40S), 4-bit quantization often underperforms because:
  - Dequantization of weights or partial sums runs on slow CUDA cores, not fast tensor cores.
  - For W4A4 systems like Atom and QuaRot, 20–90% of runtime can be eaten by dequantization in the main GEMM loop.

To achieve resonable accuracy, W4A4 must apply **per-group** quantization, which is finer than per-channel quantization -- sharing FP16 scaling factors a *sub-channel* basis

## Prequistions

### How GPUs Run Calculations

A **GPU thread** is like a tiny worker that can do simple arithmetic:

- Read numbers from memory
- Multiply, add
- Write results back

A modern GPU runs tens of thousands of these simultaneously.

A thread block is a group of threads that work together on a small piece of the problem.

Inside a block:

- Threads can share fast memory
- They can cooperate
- They run on the same GPU core unit (called an SM)

But different blocks do not cooperate, they run independently

A tile is simply a small submatrix that a thread block is responsible for computing.

```text
4096x4096 output Y
broken into (4096/32) × (4096/32) = 128 × 128 tiles
```

This is a variant of block matrix multiplication (a.k.a. tiled GEMM)

### CUDA Cores and Tensor Cores

| Aspect               | CUDA Cores                                            | Tensor Cores                                              |
| -------------------- | ----------------------------------------------------- | --------------------------------------------------------- |
| Role                 | General-purpose compute units                         | Specialized matrix-multiply units                         |
| Typical Work         | Indexing, control flow, bit ops, dequant, activations | GEMM/conv inner math (A×B→C)                              |
| Supported Operations | Scalar/vector add, mul, div, logic, branches          | Small tile MMA (e.g. 16×16) with accumulate               |
| Data Types           | FP32/FP16/INT, etc. (flexible)                        | FP16/BF16/TF32/INT8/INT4 (depends on GPU generation)      |
| Throughput           | Lower per-op; many used in parallel                   | Very high FLOPS/TOPS for dense matrix math                |
| Flexibility          | High — can run arbitrary code                         | Low — fixed-function for matrix ops only                  |
| Where Used in LLMs   | Dequantization, softmax, layernorm, glue logic        | Q/K/V projections, MLP layers, sometimes QK/SV matmuls    |
| Performance Pitfall  | Becomes bottleneck if heavy math is done here         | Underutilized if kernels push too much work to CUDA cores |

### MAC

MAC = Multiply–ACcumulate.

One MAC means:

- Take two numbers → multiply them
- Add the result into an accumulator

```python
acc = 0.0
for t in range(k):
    acc += A[i, t] * B[t, j]  # 1 MAC per loop
C[i, j] = acc
```

Each loop iteration is one MAC (one multiply + one add), for the whole GEMM, there is $m \times n \times k$ total MACs.

QServe defines **computation intensity** as

$$
\text{Intensity} \approx \frac{\text{Total MACs}}{\text{Total number of matrix elements loaded/stored}}
$$

For a GEMM:

$$
\text{Intensity} \approx \frac{mnk}{mk + kn + mn}
$$

So, when $n,k \gg m$, MACs per elements approximates to $m$

- When m is small, intensity ≈ small → memory-bound.
- When m is large, intensity ≈ large → compute-bound.

### Main GEMM Loop

$C = AB$

```python
for m in range(M):
    for n in range(N):
        acc = 0.0
        for k in range(K):   # <-- main GEMM loop (reduction over k)
            acc += A[m, k] * B[k, n]
        C[m, n] = acc
```

On a real GPU GEMM kernel:

- The outer loops (over m and n) are tiled and parallelized across threads/warps/blocks.
- The **innermost loop over k** is the “main GEMM loop” where each iteration feeds data into tensor cores.

W8A8 does not need dequantization in the main loop:

The computation can be arranged as:

1. Inner GEMM loop: integer only

```python
# A_q: int8, B_q: int8, acc: int32
for m in range(M):
    for n in range(N):
        acc = 0  # int32 accumulator
        for k in range(K):  # main GEMM loop
            a_int = A_q[m, k]        # int8
            b_int = B_q[k, n]        # int8
            acc += int(a_int) * int(b_int)  # int32 MAC
        C_int32[m, n] = acc

```

2. Epilogue (outside the main loop): apply scales once

```python
# convert final int32 result to float using scales
for m in range(M):
    for n in range(N):
        C_fp[m, n] = float(C_int32[m, n]) * (s_A[m] * s_B[n])

```

When the quantization is **more fine-grained** than the tensor core can handle, for example:

- 4-bit weights with per-group scales/zero-points along the k dimension
- Or group-wise activation scales that vary inside the reduction

Instead, at each step of the k loop, you need to:

- Unpack 4-bit values
- Subtract group-specific zero points
- Multiply by group-specific scales
- Potentially convert to FP16 or INT8 before multiply

Native W4A4 with group-wise scales:

```python
for m in range(M):
    for n in range(N):
        acc = 0.0  # float32 or float16 accumulator
        for k in range(K):  # main GEMM loop
            g = k // group_size

            # 1. Load packed 4-bit values (simplified)
            a_q4 = A_q[m, k]          # int4 logical
            b_q4 = B_q[k, n]          # int4 logical

            # 2. Dequantize INSIDE the loop
            a_fp = (float(a_q4) - z_A[g]) * s_A[g]
            b_fp = (float(b_q4) - z_B[g]) * s_B[g]

            # 3. Multiply in higher precision
            acc += a_fp * b_fp

        C_fp[m, n] = acc
```

There is another scenario that needs dequantizatino in the GEMM kernel: **WXAY(`X != Y`)**

![pasted-image-20251116164558](/images/pasted-image-20251116164558.png)

### Per-group quantization

the per-group quantization is finer than the per-channel quantization

When we talk about quantization granularity, the ordering is usually:

1. Per-tensor (1 scale for the whole tensor) – coarsest
2. Per-channel (1 scale per channel) – finer
3. Per-group (many scales per tensor; each group has its own) – can be even finer, depending on how groups are defined

Per-group INT4 quantization is not friendly to GPU hardwares

- INT4 tensor cores take integer inputs and accumulate in INT32.
- But with per-group scales, you can’t just apply one scale at the very end.
- So you have to convert some INT32 partial sums to float and scale them during the computation,

```python
# A_q, W_q: int4
# s_x: activation scale (scalar)
# s_w[g, n]: group-wise weight scale for group g and output channel n

num_groups = K // G

for m in range(M):
    for n in range(N):
        acc_fp = 0.0  # now floating accumulator

        for g in range(num_groups):
            acc_int32 = 0  # INT32 partial sum for this group

            # --- group-level reduction using INT4 tensor cores ---
            for kk in range(G):
                k = g * G + kk

                a = int(A_q[m, k])          # int4 -> int
                w = int(W_q[k, n])          # int4 -> int
                acc_int32 += a * w          # int32

            # --- HERE is the required int -> float dequantization ---
            group_contribution = float(acc_int32) * (s_x * s_w[g, n])
            acc_fp += group_contribution  # accumulate in FP

        C_fp[m, n] = acc_fp
```

We must dequantize per group because each group has a different scale `s_w[g, n]`.

## Insights

W4A8KV4 is a superior choice:

- 4-bit weights
- 8-bit activations
- 4-bit KV caches

## Approaches

### QoQ

**Progressive group quantization**:

- FP16 -> INT 8
  - Per-channel symmetric quantization, with FP16 scales
  - With a *protective range* of `[-119,119]`
- INT8 -> INT4
  - Per-group quantization, with sclaes and zero points

At runtime, INT4 is dequantized to INT8, and use the INT8 weights with per-channel scales, like a normal W8A8 kernel

> Ensure **all GEMMs are performed on INT8 tensor cores**, previous approaches also adopt the two level fo quantization but they are not INT8-centric

### SmoothAttention

Key observation: **the Value matrices show no significant outlier pattern, whereas Key matrices tend to have fixed outlier channels in each head**.

QServe proposes SmoothAttention to scale down the outlier channels in Key cache by a per-channel factor:

$$
Z = (Q \Lambda)\bigl(K \Lambda^{-1}\bigr)^{\top}
$$

$$
\lambda_i = \bigl(\max(|K_i|)\bigr)^{\alpha},
\qquad i = 1,\dots,D
$$

> The paper claims that $\alpha = 0.5$ is good enough

> [!TODO]
> The relationship between $\Lambda$ and RoPE

### QServe Serving System

Three types of optimizations:

- **Compute-aware Weight Reorder** to maximize data loading efficiency
- **Subtraction after multiplication**
- **Register-level parallelism**

> Similar to the characteristics of flash storage on the mobile devices, bigger reading block brings high bandwidth

## Evaluation

## Thoughts

### When Reading

Very hardcore

QServe combines multiple optimizations related Nvidia GPU hardwares

## Related Works
