#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": img

#tola-meta((
  title: "SmoothQuant Accurate and Efficient Post-Training Quantization for Large Language Models",
  date: "2025-11-16",
  tags: ("ICML-23", "Quantization"),
))

#quote(block: true)[
Extensive Reading
]

= Author Info
- #link("https://hanlab.mit.edu/")[MIT HAN Lab]

= Background
- Modern large language models (LLMs) are extremely costly to serve in FP16 because of their massive parameter counts and long-context workloads; while low-bit quantization (especially INT8) is an attractive way to cut memory and latency, naïve post-training W8A8 (8-bit weights and activations) breaks down on large models due to #strong[severe activation outliers] that cause large accuracy drops.

- Existing INT8 solutions either focus on weights only (e.g., GPTQ-style methods) or handle activation outliers with mixed precision (e.g., LLM.int8(), outlier-aware kernels); these approaches can preserve accuracy but often bring limited end-to-end gains because they leave activations/KV caches in higher precision, rely on complex custom kernels, or end up slower than plain FP16 in practical deployments.

- More advanced PTQ approaches (e.g., dynamic or group-wise quantization, outlier suppression via LayerNorm variants) alleviate some issues but still struggle to robustly quantize activations for very large LLMs under real hardware constraints, since they cannot easily use per-channel activation scaling inside standard GEMM kernels; this motivates a method that tames activation outliers while remaining fully compatible with simple, high-performance INT8 matrix multiplication.

= Insights
#strong[Different tokens exhibit similar variations across their channels]

#quote(block: true)[
We can say the values in activations follow #strong[power law distribution]
]

Due to the characterics of INT8 GEMM kernels, when calculating $Y = X @ W$ we can only quantize:

- per-token (a row) in the $X$
- per-channel (a column) in the $W$

The most straightforward way (per-channel quantization) is #strong[not feasible], and it\'s hard to quantize by using per-token due to the outliers in the token activation

We can \"smooth\" these outlier channels by #strong[scaling the weights accordingly] to minimize the effect of outliers in the activations, leading to precisely per-token quantization

#quote(block: true)[
In a nutshell, $Y = X @ W$, outliers appear in the same columns of different tokens(same column in the activation matrix), we can scale the corresponding channel in the weight matrix to make the rows in the activation matrix more uniform thus easier to quantize
]

Summary:

#img("/assets/images/pasted-image-20251116102802.png", alt: "pasted-image-20251116102802")
Origin:

- Activations are #strong[hard] to quantize due to outliers
- Weights are very easy to quantization

SmoothQuant migrate diffculity from activations to weights by a mathmatical equivalent transformation:

- Activations are easy to quantize
- Weights are easy to quantize

= Prequsitions
A channel is a column of the weight matrix -\- a dimention of the output features

#img("/assets/images/pasted-image-20251116102748.png", alt: "pasted-image-20251116102748")
A basic matrix multiply is:

$ C_(M times N) = A_(M times K) dot.op B_(K times N) $

Loop form:

```text
for m in 0..M-1:
  for n in 0..N-1:
    acc = 0
    for k in 0..K-1:
      acc += A[m,k] * B[k,n]
    C[m,n] = acc
```

For an LLM linear layer:

- \(M = T) (tokens / batch\*seq)
- \(K = C\_i) (input hidden dim, “in channels”)
- \(N = C\_o) (output hidden dim, “out channels”)

So:

- \(A) ↔ activation (X \\in \\mathbb{R}^{T \\times C\_i})
- \(B) ↔ weight (W \\in \\mathbb{R}^{C\_i \\times C\_o})
- \(C) ↔ output (Y \\in \\mathbb{R}^{T \\times C\_o})

Here, #strong[K = (C\_i) is the inner dimension]: it's the one we sum over.

Simple symmetric quantization:

- Activations: $A_(upright("real")) approx s_A\(dot.op\)dot.op A_(upright("int8"))$
- Weights: $B_(upright("real")) approx s_B\(dot.op\)dot.op B_(upright("int8"))$

Suppose:

- \(s\_X) depends on #strong[N] (per-row / per-token) or is global per-tensor
- \(s\_W) depends on #strong[C\_o] (per-col / per-output-channel) or is global

So:

- \(s\_A(m)): scale for row (m) of A (per-token)
- \(s\_B(n)): scale for column (n) of B (per-output-channel)

Then:

$ C_(upright("real"))\[m\,n\] & = sum_k A_(upright("real"))\[m\,k\]dot.op B_(upright("real"))\[k\,n\]med & approx sum_k\(s_A\(m\)A_(upright("int8"))\[m\,k\]\)dot.op\(s_B\(n\)B_(upright("int8"))\[k\,n\]\)med & = s_A\(m\)s_B\(n\)sum_k A_(upright("int8"))\[m\,k\]B_(upright("int8"))\[k\,n\] $

Note:

- \(s\_A(m)) and (s\_B(n)) do #strong[not] depend on (k),
- So we can #strong[pull them out] of the summation:
  - Inner loop (over $k$) is pure INT8×INT8→INT32
  - We can only multiply by (s\_A(m)s\_B(n)) #strong[once per output element]

So the whole process could be:

+ Run the integer GEMM (General Matrix-Matrix Multiplication)

```text
C_int32 = A_int8 @ B_int8
```

#block[
#set enum(numbering: "1.", start: 2)
+ for each element
]

```text
for m in 0..M-1:
  row_scale = s_A[m]
  for n in 0..N-1:
    col_scale = s_B[n]
    C_real[m,n] = (row_scale * col_scale) * C_int32[m,n] + bias[n]
```

The Equation 2 is the same meaning (but there are no extra two diga matrix multiplications):

$ Y\[t\,j\]= Delta_X^(upright("FP16"))\[t\]\;#scale(x: 180%, y: 180%)[\(] sum_k macron(X)_(upright("INT8"))\[t\,k\]\;macron(W)_(upright("INT8"))\[k\,j\]#scale(x: 180%, y: 180%)[\)]\;Delta_W^(upright("FP16"))\[j\] $

About W8A8 quantization:

- Weights are always quantized into INT8
- Activations keep in FP16 most of the time, because the activations will go into GELU/LayerNorm/etc

So we can quantize activations just-in-time for the GEMM (linear)

#quote(block: true)[
activation flow is FP16, only quantize to INT8 before GEMM
]

Activations are input-dependent, so there are two strategies to quantize:

- #strong[Dynamic quantization]
  - For every GEMM, compute the scales #strong[based on its current states]
- #strong[Static quantization]
  - Use calibration data to estimate the typical range of activations for each layer
  - #strong[Fix] a scale per layer #strong[offline]

= Approaches
How to smooth the activations?

To keep the mathmatical equivalence:

$ Y =\(X d i a g\(s\)^(- 1)\)dot.op\(d i a g\(s\)W\)= hat(X) hat(W) $

To balance the diffculity of quantization in activations and weights, SmoothQuant introduces a hyper-parameter:

$ s_j = frac(max #scale(x: 120%, y: 120%)[\(]\|X_j\|#scale(x: 120%, y: 120%)[\)]^alpha, max #scale(x: 120%, y: 120%)[\(]\|W_j\|#scale(x: 120%, y: 120%)[\)]^(1 - alpha))\,quad j = 1\,2\,dots.h\,C_i $

#img("/assets/images/pasted-image-20251116102707.png", alt: "pasted-image-20251116102707")
#quote(block: true)[
We can regard quantization $Q\(x\)$ is not a linear operation, so transformation can work
]

= Evaluation
= Thoughts
== When Reading
Understanding the mechinism of this paper can give you a comprehensive understanding of how quantization does underneath the inference process

= Related Works
