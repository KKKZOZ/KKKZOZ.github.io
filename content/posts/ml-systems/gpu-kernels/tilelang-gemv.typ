#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, cols, fold, hint, term, xref
#import "/figures/tilelang-gemv.typ" as fig
#import "/figures/tilelang.typ": fig-alloc-scopes, fig-op-scopes

#tola-meta((
  title: "Learning TileLang with GEMV",
  date: "2026-11-04",
  summary: "用 GEMV 入门 TileLang：同一个 FP16 GEMV 写十四遍，依次用到 T.Kernel、线程绑定、shared / local / fragment 三种分配、T.copy、T.vectorized、T.Pipelined 和 reducer，以及 warp、合并访存、128-bit 加载这些与 CPU 不同的 GPU 访存特性。",
  tags: ("TileLang", "GPU"),
  weight: 10,
  toc-depth: 3,
))

这是一篇 TileLang 入门，例子只有一个：GEMV，向量乘矩阵。GEMV 的计算只有一行，没有算法上的技巧，所以写法上的每个选择都直接体现在运行时间上：一个线程算几个元素，线程怎样编号，数据先放进哪一级存储。下面把同一个 GEMV 写十四遍，每一遍用到一两个新的 TileLang 特性，或者碰到一个 GPU 的特性。

其中有些写法，从 CPU 的经验看是反直觉的。下面两个 kernel 只差两行，交换了线程编号的两个维度：

#cols(labels: ([`thread_naive_split_k`：614 µs], [`thread_coalesced_naive_split_k`：170 µs]))[
  ```python
  with T.Kernel(
      ..., threads=(block_n, block_k)
  ):
      tid_n = T.get_thread_binding(0)
      tid_k = T.get_thread_binding(1)
  ```
][
  ```python
  with T.Kernel(
      ..., threads=(block_k, block_n)
  ):
      tid_k = T.get_thread_binding(0)
      tid_n = T.get_thread_binding(1)
  ```
]

左边每个线程读的地址比右边更连续，在 CPU 上应该更快，在 GPU 上却慢了 3.6 倍。原因在于 GPU 上要看的不是一个线程前后读的地址是否相邻，而是同一时刻一组线程读的地址是否相邻。#link(<sec-gemv-coalescing>)[Coalescing] 一节专门讲这一点。

= GEMV

本文计算 $y = x W$：$x$ 是长 $K$ 的行向量，$W$ 是 $K times N$ 的矩阵，$y$ 长 $N$。形状取 $K = 14336$、$N = 4096$，FP16。这是 Llama 3 8B 的 MLP down projection；逐个 token 解码时，每个线性层都是这样一次 GEMV。

后面的图都按 @gemv-layout 摆放：$x$ 在左下，$W$ 在右上，$y$ 在 $W$ 正下方。这样 $y$ 的每个元素正好落在 $x$ 所在的行与 $W$ 的一列的交点上：$y[j]$ 由整个 $x$ 和 $W$ 的第 $j$ 列算出。

#figure(
  fig.fig-layout(),
  caption: [全文的图示约定。$y[j]$ 对应整个 $x$ 和 $W$ 的第 $j$ 列；这一列就是代码中 `matrix` 的第 $j$ 行，在内存中连续。],
) <gemv-layout>

代码中的权重是 `matrix: T.Tensor((N, K))`，行主序，与 `nn.Linear` 存权重的方式相同。它就是 $W^T$：`matrix[j, k]` 等于 $W[k, j]$。所以*图中 $W$ 的一列在内存中是连续的*，地址沿着列从上往下增长。后面讨论访存时都要用到这一点。

所有 kernel 都用 FP32 累加。GPU 是一张 RTX A6000，有 84 个 #term("SM")[Streaming Multiprocessor，GPU 上独立调度的计算单元。一个 thread block 整个运行在一个 SM 上，一个 SM 可以同时容纳多个 block。]，显存带宽 768 GB/s。时间取 `tilelang.profiler.do_bench` 跑 100 次的中位数；作为对照，`torch.compile` 编译的 `matrix @ vector` 是 168.96 µs。

= Bandwidth Bound

先算出 GEMV 最快能有多快。$W$ 的每个元素只用一次，做一次乘法和一次加法。数一下字节和 FLOPs：

#table(
  columns: 3,
  align: (left, right, left),
  table.header([], [元素数], [FP16 字节数]),
  [$W$], [58,720,256], [117,440,512],
  [$x$], [14,336], [28,672],
  [$y$], [4,096], [8,192],
  [合计], [58,738,688], [*117,477,376*],
)

FLOPs 为 $2 N K$ = 117,440,512，所以 GEMV *每搬一个字节只做一次浮点运算*。A6000 的 FP32 CUDA Core 算力是 38.7 TFLOP/s，相当于显存每送来一个字节，它能做 50 次运算。因此 GEMV 的时间几乎全花在读显存上，任何 kernel 最快也只能是

$ ("117,477,376 B") / ("768 GB/s") = "153.0 µs". $

`torch.compile` 达到 695 GB/s，是这个上限的 90.5%。下文的*带宽*都指这 117 MB 除以 kernel 的时间。它是按算法算出来的数，不是硬件计数器：重复读取的字节、atomic 和缓存命中都没有计入。

这个上限决定了后面优化什么：算术怎么写几乎无关紧要，要紧的是*让显存一直忙着，并且读回来的每个字节都有用*。

= Thread and Block View

TileLang 可以从两个视角写 kernel（#xref("tilelang-programming-model") 有更详细的介绍）：

- *Thread 视角。* 代码描述单个线程做什么：用 `T.get_thread_binding` 取得自己的编号，再用它索引内存。读起来和 CUDA 一样。
- *Block 视角。* 代码描述整个 block 对一个 tile 做什么，用的是 `T.copy`、`T.clear` 这类集体操作和 `T.Parallel` 循环。哪个线程处理哪个元素由 TileLang 决定。

前九个 kernel 用 Thread 视角，因为它把线程和地址的对应关系摆在明面上，适合用来看 GPU 的访存特性；后五个用 Block 视角。它们的外层结构都一样，第一个完整列出：

```python
@tilelang.jit(out_idx=[2])
def thread_naive_gemv(N: int, K: int, dtype: str = "float16"):
    def _func(block_n: int, block_k: int):
        @T.prim_func
        def main(
            vector: T.Tensor((K,), dtype),
            matrix: T.Tensor((N, K), dtype),
            output: T.Tensor((N,), dtype),
        ):
            with T.Kernel(T.ceildiv(N, block_n), threads=block_n) as pid_n:
                tid_n = T.get_thread_binding(0)
                vector_shared = T.alloc_shared((block_k,), dtype)
                matrix_shared = T.alloc_shared((block_n, block_k), dtype)
                accumulator = T.alloc_local((1,), "float32")
                T.clear(accumulator)

                for pid_k in T.serial(T.ceildiv(K, block_k)):
                    if tid_n == 0:
                        for k in T.serial(block_k):
                            vector_shared[k] = vector[pid_k * block_k + k]
                    for k in T.serial(block_k):
                        matrix_shared[tid_n, k] = matrix[
                            pid_n * block_n + tid_n, pid_k * block_k + k
                        ]
                    T.sync_threads()
                    for k in T.serial(block_k):
                        accumulator[0] += T.cast(vector_shared[k], "float32") * T.cast(
                            matrix_shared[tid_n, k], "float32"
                        )
                    T.sync_threads()

                output[pid_n * block_n + tid_n] = accumulator[0]

        return main

    return _func
```

从外往里：

- 外层函数固定问题本身：形状和 dtype。
- `_func` 固定调度：tile 大小，这里是 `block_n` 和 `block_k`。`tilelang.jit` 为每组 tile 大小编译一个 kernel，autotuner 因此可以逐个尝试。
- `out_idx=[2]` 告诉 TileLang 第 2 个参数 `output` 是输出：由 TileLang 分配并返回，调用者只需传入 `vector` 和 `matrix`。
- `@T.prim_func` 下的 `main` 是 kernel 本身，`T.Tensor` 声明参数的形状和 dtype。
- `T.Kernel(grid, threads=...)` 启动 grid。这里有 `N / block_n` 个 block，每个 block 有 `block_n` 个线程，`pid_n` 是 block 的编号。`with` 里面的代码由每个线程执行一遍。

后面的代码只列出 `T.Kernel` 的内部，其余部分与上面相同。

= Thread View

== `thread_naive`

`thread_naive` 是最直接的写法：*每个线程算一个输出*。一个 block 负责 `block_n` 个输出，也就是 $W$ 的 `block_n` 列；它沿 $K$ 方向往下走，每次处理 `block_k` 行的一个 tile：

+ 线程 0 把 $x$ 中对应的一段复制到 shared memory；每个线程把 tile 中自己那一列复制过去。
+ `T.sync_threads()`：等 tile 复制完整。
+ 每个线程把自己那一列的乘积累加到自己的 FP32 accumulator。
+ 再次 `T.sync_threads()`，避免有线程还在读 tile 时，另一个线程已经开始写下一个 tile。

#figure(
  fig.fig-thread-naive(),
  caption: [`thread_naive`，图中 `block_n = 2`，`block_k = 2`。block 负责虚线框中的两列，此刻处理第二个 tile；线程 t0、t1 各负责一列和一个 accumulator。],
) <gemv-thread-naive>

这个 kernel 用到了 TileLang 的两种分配，它们属于不同的层级：

- `T.alloc_shared` 属于 block。每个线程执行到这一行时拿到的是*同一块* shared memory，所以 `vector_shared` 只需要线程 0 写一次，所有线程都能读到。
- `T.alloc_local` 属于线程。每个线程有自己的一份，放在寄存器里，别的线程看不到。

#figure(
  fig-alloc-scopes(),
  caption: [三种分配的归属。`alloc_fragment` 在 Block 视角中才会用到。],
) <gemv-alloc-scopes>

`T.serial` 是普通的串行循环。因为线程之间共享 `vector_shared` 和 `matrix_shared`，写和读之间必须有 `T.sync_threads()`，它就是 CUDA 的 `__syncthreads()`。对照编译出的 CUDA 看会更清楚：

#fold(title: [编译出的 CUDA（简化）])[
  ```cpp
  extern "C" __global__ void __launch_bounds__(128, 1) main_kernel(
      const half_t* __restrict__ vector,
      const half_t* __restrict__ matrix,
      half_t* __restrict__ output) {
    // block_n = block_k = 128, K = 14336
    extern __shared__ __align__(1024) half_t buf[];
    half_t* matrix_shared = buf;               // [128][128]
    half_t* vector_shared = buf + 128 * 128;   // [128]

    int row = blockIdx.x * 128 + threadIdx.x;
    float accumulator = 0.0f;

    for (int pid_k = 0; pid_k < 14336 / 128; ++pid_k) {
      // thread 0 loads the vector tile; each thread loads its own row of matrix
      if (threadIdx.x == 0) {
        for (int k = 0; k < 128; ++k)
          vector_shared[k] = vector[pid_k * 128 + k];
      }
      for (int k = 0; k < 128; ++k)
        matrix_shared[threadIdx.x * 128 + k] = matrix[row * 14336 + pid_k * 128 + k];
      __syncthreads();

      for (int k = 0; k < 128; ++k)
        accumulator += (float)vector_shared[k] * (float)matrix_shared[threadIdx.x * 128 + k];
      __syncthreads();
    }
    output[row] = (half_t)accumulator;
  }
  ```
]

这个 kernel 需要 *1709 µs*，只有上限的 9%。慢在三处：

- *block 太少。* 默认 `block_n = 128`，只有 $4096 / 128 = 32$ 个 block，而 GPU 有 84 个 SM，一大半无事可做。在 `block_n` ∈ {32, 64, 128} 中 autotune 后，时间降到 817 µs。
- *串行循环太长。* 每个线程独自走完自己那一列的 14,336 个元素。
- *访存分散。* 每个线程沿自己那一列往下读，单看一个线程，地址是连续的，这在 CPU 上正是最好的访问方式。但在 GPU 上，同一时刻相邻的线程读的是相邻的列，地址相隔 28,672 字节。#link(<sec-gemv-coalescing>)[Coalescing] 一节解释为什么这很慢。

== `thread_naive_split_k`

为了缩短串行循环，`thread_naive_split_k` 把 $K$ 也分给线程。现在一个 block 有 `block_n × block_k` 个线程，排成二维：`tid_n` 选列，`tid_k` 选这一列中的行。每个线程在每个 tile 中只读一个元素，以 `block_k` 为步长往下走；最后每一列有 `block_k` 个部分和需要合并：

```python
with T.Kernel(T.ceildiv(N, block_n), threads=(block_n, block_k)) as pid_n:
    tid_n = T.get_thread_binding(0)
    tid_k = T.get_thread_binding(1)
    accumulator = T.alloc_local((1,), "float32")
    reduced = T.alloc_shared((block_n,), "float32")
    if tid_k == 0:
        reduced[tid_n] = 0
    T.clear(accumulator)
    T.sync_threads()

    for pid_k in T.serial(T.ceildiv(K, block_k)):
        col = pid_k * block_k + tid_k  # the k index: a column of matrix, a row of W
        accumulator[0] += T.cast(vector[col], "float32") * T.cast(
            matrix[pid_n * block_n + tid_n, col], "float32"
        )

    T.atomic_add(reduced[tid_n], accumulator[0])
    T.sync_threads()
    if tid_k == 0:
        output[pid_n * block_n + tid_n] = reduced[tid_n]
```

这里有两个新东西：

- *二维线程。* `threads=(block_n, block_k)` 给 block 两个线程维度。`T.get_thread_binding(0)` 是第一个维度，即 `threadIdx.x`；`T.get_thread_binding(1)` 是第二个，即 `threadIdx.y`。
- *`T.atomic_add`。* 部分和在 `reduced` 中汇合，它在 shared memory 中为每个输出留一个 FP32 位置。同一列的 `block_k` 个线程用 atomic add 把各自的和加进去；过了 barrier 之后，每列由 `tid_k == 0` 的线程写回结果。

默认配置是 `block_n = block_k = 32`：每个 block 1024 个线程，共 128 个 block，每个线程串行 448 步。时间是 *614 µs*，比 `thread_naive` 快 2.8 倍，但仍比 `torch.compile` 慢 3.6 倍。剩下的差距来自线程的编号方式。

== Coalescing <sec-gemv-coalescing>

硬件给 block 中的线程排号时，`threadIdx.x` 变化最快：

$ "linear id" = "threadIdx.y" times "blockDim.x" + "threadIdx.x", $

每 32 个连续编号组成一个 #term("warp")[GPU 调度和执行的基本单位：32 个线程执行同一条指令，各自用自己的寄存器和地址。]。这里 CPU 和 GPU 的差别就显现出来了：

- *CPU 上，每个线程独立执行。* 一个线程顺序读内存时，第一次读取把 64 字节的 cache line 取进来，后面几次都命中缓存，预取器还会提前取下一行。所以 CPU 上的经验是*让每个线程读连续的地址*。
- *GPU 上，一个 warp 的 32 个线程执行同一条加载指令。* 这条指令带着 32 个地址一起发出，显存以 32 字节的 #term("sector")[GPU 访问 L2 和显存的最小单位，32 字节。]为单位响应。*一次加载的代价取决于这 32 个地址落在多少个 sector 里*，与某个线程前后两次读的地址是否相邻关系不大。

所以在 GPU 上要看的是：*同一时刻，一个 warp 中的线程读的地址是否相邻*。这叫合并访存（coalescing）。

`thread_naive_split_k` 中 `tid_n` 是 `threadIdx.x`，`block_n = 32`，所以第 $w$ 个 warp 由 `tid_n` 0–31、`tid_k` = $w$ 的线程组成。在 @gemv-coalescing 左边：

- `vector[col]`：32 个线程读同一个元素，硬件广播，整个 warp 只需一个 sector。
- `matrix[row, col]`：32 个线程分布在 32 列上，读同一行。每列在内存中连续，列与列相隔 $K times 2$ = 28,672 字节，所以每个线程需要单独一个 sector，并且只用其中 32 字节中的 2 字节。整个 warp 取回 32 个 sector，只用到 64 字节。

*把 `tid_k` 放到第一个维度*，就是开头右边的写法，情况反过来：一个 warp 落在同一列中相邻的 32 行，即 2 个 sector 中连续的 64 字节，每个字节都用上。它读的 $x$ 也是连续的一段。

#figure(
  fig.fig-coalescing(),
  caption: [两种线程布局下一个 warp 的一次加载，数字是 lane 编号。按比例缩小为 8 个 lane 的 warp 和 8 个元素的 sector；$W$ 的每一列在内存中连续（箭头方向），一个 sector 是一列中相邻的 8 格。实际上一个 warp 有 32 个 lane，一个 sector 装 16 个 FP16，所以左边只用到取回数据的 1/16。],
) <gemv-coalescing>

反直觉的地方在于：交换之后，*单个线程*前后两次读的地址相隔 `block_k` 个元素，在 CPU 上这是更差的访问方式；可是每一时刻整个 warp 读的是一段连续内存，在 GPU 上这才是对的。`thread_naive` 的问题也一样：每个线程沿自己的列连续地读，但同一时刻一个 warp 散落在 32 列上。

只改这一处就快了 3.6 倍，与 `torch.compile` 的差距缩小到 1% 以内。加速是 3.6 倍而不是 16 倍：每个 sector 中其余 30 字节，正是后面几个 `tid_k` 对应的 warp 在同一轮迭代中要读的行，所以一个 warp 浪费的字节，很可能从缓存中供给了另一个 warp。

#hint[
  `T.get_thread_binding(0)` 是 `threadIdx.x`，即 warp 内变化最快的维度。把它绑定到沿连续内存前进的那个下标上。对行主序的 `matrix` 来说是第二个下标 $k$，在图中就是沿着 $W$ 的一列往下。
]

== `thread_split_k`

每个线程只读一个元素时，线程的活太少：每次加载只做一次乘加，一个 block 多达 1024 个线程。`thread_split_k` 沿 $K$ 方向只用 `reduce_threads` 个线程，每个线程在每个 tile 中负责 `tile_k = block_k / reduce_threads` 个元素，先把它们读进寄存器，再累加：

```python
tile_k = block_k // reduce_threads

with T.Kernel(T.ceildiv(N, block_n), threads=(block_n, reduce_threads)) as pid_n:
    tid_n = T.get_thread_binding(0)
    tid_k = T.get_thread_binding(1)
    vector_local = T.alloc_local((tile_k,), dtype)
    matrix_local = T.alloc_local((tile_k,), dtype)
    # accumulator and reduced as before

    for pid_k in T.serial(T.ceildiv(K, block_k)):
        for k in T.serial(tile_k):
            col = pid_k * block_k + tid_k * tile_k + k
            vector_local[k] = vector[col]
            matrix_local[k] = matrix[pid_n * block_n + tid_n, col]
        for k in T.serial(tile_k):
            accumulator[0] += T.cast(vector_local[k], "float32") * T.cast(
                matrix_local[k], "float32"
            )

    # atomic_add into reduced[tid_n] and write back, as before
```

`T.alloc_local` 这次分配的是数组：每个线程有自己的 `tile_k` 个寄存器。

#figure(
  fig.fig-thread-split-k(),
  caption: [一个 tile 上的 `thread_split_k`，图中 `reduce_threads = 4`，`tile_k = 4`，颜色表示 `tid_k`。每个线程沿一列读属于自己的 `tile_k` 个元素，然后同一列的线程把各自的和加到同一个 shared 位置。],
) <gemv-thread-split-k>

把一列中的 `block_k` 个元素分给 `reduce_threads` 个线程，有两种方式：

#figure(
  fig.fig-block-cyclic(),
  caption: [4 个线程以 Block 方式和 Cyclic 方式访问一列中的 16 个元素，颜色表示所属线程，$i$ 是线程内的循环变量。],
) <gemv-block-cyclic>

- *Block access* 让每个线程负责连续的 `tile_k` 个元素，可以用一次向量加载取回。
- *Cyclic access* 让各线程在每一步读相邻的元素，于是 warp 的加载是合并的，但前提是 `tid_k` 绑定在 `threadIdx.x` 上。

在 `thread_split_k` 中 `threadIdx.x` 是 `tid_n`，一个 warp 仍然横跨多列，两种方式都不能合并访存。这里的 kernel 采用 Block access，为下一节的向量加载做准备。

默认配置的时间是 *606 µs*，并不比每线程一个元素的版本快。原因是它就是那个版本：`reduce_threads = block_k = 32` 使得 `tile_k = 1`。有两种改法：

- 把 `tid_k` 放到 `threadIdx.x` 上，即 `threads=(reduce_threads, block_n)`，得到 `thread_coalesced_split_k`。它的默认配置 `reduce_threads = 8`、`tile_k = 4` 跑出 *167.9 µs*。每一步并非完全合并，但同一列的 8 个线程在 4 步中始终落在同样的 64 字节里。
- 直接对 `thread_split_k` 做 autotune，能找到 169.0 µs 的配置。

== `thread_vectorized_split_k`

一个线程的一条加载指令最多读 128 bit，即 16 字节。FP16 下就是 8 个元素，所以 `thread_vectorized_split_k` 由 dtype 推出 `tile_k`，再由它得到 `block_k`：

```python
tile_k = 128 // DataType(dtype).bits      # 8 for float16 and bfloat16
block_k = reduce_threads * tile_k

    for pid_k in T.serial(T.ceildiv(K, block_k)):
        for k in T.vectorized(tile_k):
            col = pid_k * block_k + tid_k * tile_k + k
            vector_local[k] = vector[col]
            matrix_local[k] = matrix[pid_n * block_n + tid_n, col]
        for k in T.serial(tile_k):
            accumulator[0] += T.cast(vector_local[k], "float32") * T.cast(
                matrix_local[k], "float32"
            )
```

`T.vectorized(tile_k)` 告诉 TileLang 这个循环可以合成一条向量指令：每个操作数一次 128-bit 加载，而不是 8 次 16-bit 加载。前提是 Block access：每个线程的 8 个元素在内存中相邻，并且起始地址按 16 字节对齐。

默认配置是 `block_n = 2`、`reduce_threads = 32`：每个 block 64 个线程，共 2048 个 block。线程布局是 `(block_n, reduce_threads)`，正是前面不能合并访存的那种，但只有两列时它没有代价。一个 warp 包含两列的 `tid_k` 0–15，在每一列中，16 个线程读 16 × 16 = 256 个连续字节：

#figure(
  fig.fig-vectorized-warp(),
  caption: [默认配置下 `thread_vectorized_split_k` 对一个 tile 的加载。每格是一个线程的一次 128-bit 加载，颜色表示所属的 warp；block 的两个 warp 各自从两列中读 256 个连续字节。],
) <gemv-vectorized-warp>

时间是 *166.9 µs*，每个线程走 $14336 / 256 = 56$ 步。到这里，三件事都做到了：block 足够多，访存是合并的，每个线程一次读 16 字节。

== Reduction

最后，每一列的部分和还要在线程之间相加。保持 `thread_vectorized_split_k` 的加载不变，有三种收尾方式：

- *Shared memory atomic*，即上面的做法：166.9 µs。
- *线程间 all-reduce。* `thread_tvm_reduce_split_k` 用 TVM 的 `tvm_thread_allreduce` 在 `tid_k` 上规约，代替 atomic；TVM 把它 lower 成 warp shuffle，只在 warp 之间使用 shared memory。*165.9 µs，本文最快*：708 GB/s，上限的 92.2%，比 `torch.compile` 快 1.9%。
- *经 shared memory 中转。* `thread_shared_memory_split_k` 先用 Cyclic 的合并加载把每个 tile 复制到 shared memory，再用向量加载读回来：175.8 µs。每个字节搬了两次，每个 tile 还要等两次 barrier。

all-reduce 的写法比较底层，要直接写 TVM 的 intrinsic：

```python
reduced_local = T.alloc_local((1,), "float32")
with T.attr(
    T.comm_reducer(lambda x, y: x + y, [T.cast(0, "float32")]),
    "reduce_scope",
    T.reinterpret(T.uint64(0), dtype="handle"),
):
    T.evaluate(
        T.tvm_thread_allreduce(
            T.uint32(1), accumulator[0], True, reduced_local[0], tid_k,
            dtype="handle",
        )
    )
if tid_k == 0:
    output[pid_n * block_n + tid_n] = reduced_local[0]
```

规约在 56 步加载之后、每列只做一次，占的时间很少；三种做法相差不到 6%。

最后一个 Thread 视角的 kernel `thread_intra_block_split_k` 把每个 tile 暂存到 shared memory，但仍然每个线程一个元素。每处理 32 个元素就要等两次 barrier，时间是 281.6 µs，autotune 后 210.9 µs。

= Block View

Thread 视角中，线程和地址的对应、barrier 的位置都要自己写。Block 视角把同样的计算写成对 tile 的操作，这些交给 TileLang。代价是要遵守它的规则：每类操作只能出现在特定的位置。

#figure(
  fig-op-scopes(),
  caption: [Block 视角 kernel 中各类操作能出现的位置。Tile 操作是集体操作，属于 block；在 `T.Parallel` 内部，每个线程各自工作。],
) <gemv-op-scopes>

大多数 Block 视角的 kernel 都是同样四步：分配 tile、把数据复制进来、计算、把结果复制出去。

== `block_naive`

`block_naive` 的调度与 `thread_naive` 相同：每个 block 负责 `block_n` 个输出，沿 $K$ 每次处理一个 tile。整个矩阵放不进 shared memory，所以逐个 tile 复制：

```python
with T.Kernel(T.ceildiv(N, block_n), threads=block_n) as pid_n:
    vector_shared = T.alloc_shared((block_k,), dtype)
    matrix_shared = T.alloc_shared((block_n, block_k), dtype)
    accumulator = T.alloc_fragment((block_n,), "float32")
    T.clear(accumulator)

    for pid_k in T.serial(T.ceildiv(K, block_k)):
        T.copy(vector[pid_k * block_k], vector_shared)
        T.copy(matrix[pid_n * block_n, pid_k * block_k], matrix_shared)
        for i in T.Parallel(block_n):
            for k in T.serial(block_k):
                accumulator[i] += T.cast(matrix_shared[i, k], "float32") * T.cast(
                    vector_shared[k], "float32"
                )

    T.copy(accumulator, output[pid_n * block_n])
```

与 `thread_naive` 对比，代码里没有 `T.get_thread_binding`，也没有 `T.sync_threads`：

- `T.copy` 用 block 的全部线程搬运整个 tile。谁搬哪部分、怎样合并访存、在哪里插 barrier，都由 TileLang 决定。
- `T.copy(matrix[pid_n * block_n, pid_k * block_k], matrix_shared)` 只写出源 tile 的左上角，大小由目标 buffer 决定。
- `T.alloc_fragment` 是放在寄存器中、分布在 block 各线程上的 tile（见 @gemv-alloc-scopes）。`T.Parallel(block_n)` 把它的 `block_n` 个元素分给线程，每个线程负责一个输出。

默认 `block_n = 128` 又只有 32 个 block，时间是 *319.5 µs*；autotune 后为 *171.0 µs*。*Block 视角替你决定哪个线程做什么，但不替你决定有多少个 block。*

== `block_split_k`

`block_split_k` 不再让每个 block 沿 $K$ 往下走，而是每个 tile 一个 block。grid 是二维的，共 $4096 / 128 times 14336 / 128 = 32 times 112 = 3584$ 个 block，每个只处理一个 tile：

```python
with T.Kernel(
    T.ceildiv(N, block_n), T.ceildiv(K, block_k), threads=block_n
) as (pid_n, pid_k):
    vector_shared = T.alloc_shared((block_k,), dtype)
    matrix_shared = T.alloc_shared((block_n, block_k), dtype)
    accumulator = T.alloc_fragment((block_n,), "float32")
    T.clear(accumulator)

    T.copy(vector[pid_k * block_k], vector_shared)
    T.copy(matrix[pid_n * block_n, pid_k * block_k], matrix_shared)

    for i in T.Parallel(block_n):
        for k in T.serial(block_k):
            accumulator[i] += T.cast(matrix_shared[i, k], "float32") * T.cast(
                vector_shared[k], "float32"
            )

    for i in T.Parallel(block_n):
        T.atomic_add(output[pid_n * block_n + i], accumulator[i])
```

`T.Kernel` 接受多个 grid 维度，`as (pid_n, pid_k)` 依次取得 block 在各维的编号。

#figure(
  fig.fig-block-split-k(),
  caption: [`block_split_k`。每个 tile 各自是一个 block；同一列上的 block 分别算出部分和，再用 atomic 加到 FP32 输出中。右：一个 block 的内部，摆放方式相同。],
) <gemv-block-split-k>

现在每个输出元素要接收 $14336 / 128 = 112$ 次 atomic add，同一列上的每个 block 各一次。这对 `output` 提出两个要求，kernel 自己无法满足，由 wrapper 负责：

```python
output = torch.zeros((N,), dtype=torch.float32, device=vector.device)
kernel(vector, matrix, output)
return output.to(vector.dtype)
```

+ *初值必须为零。* atomic add 是在已有的值上累加，而 `torch.empty` 分配的内存里是残留数据。这个 kernel 没有 `out_idx`，由调用者分配 `output` 并先填零。
+ *必须是 FP32。* 如果目标是 FP16，112 次累加中每一次都会对累计值做舍入。FP16 在 64 到 128 之间的相邻值相差 0.0625，所以 64 加 0.03 仍是 64；FP32 在这里的间距是 $2^(-17) approx 7.6 times 10^(-6)$。因此签名中写 `output: T.Tensor((N,), "float32")`，由 wrapper 在最后转换一次。

这两步的开销都很小。上面的 *171.0 µs* 是整个调用的时间：填零、kernel 和类型转换。Thread 视角的 kernel 没有这个问题：部分和在同一个 block 内的 FP32 shared memory 中汇合，只有最终结果才转换。

`block_split_k_v2` 交换了两层循环，外层 `T.serial(block_k)`，内层 `T.Parallel(block_n)`，时间是 174.1 µs。

== `block_pipelined`

`block_pipelined` 就是把 `block_naive` 中 $K$ 循环的 `T.serial` 换成 `T.Pipelined`：

```python
for pid_k in T.Pipelined(T.ceildiv(K, block_k), num_stages=num_stages):
    T.copy(vector[pid_k * block_k], vector_shared)
    T.copy(matrix[pid_n * block_n, pid_k * block_k], matrix_shared)
    ...
```

有 `num_stages` 份 buffer 时，TileLang 在累加当前 tile 的同时发出后面 tile 的复制，让加载和计算重叠。默认配置 `block_n = block_k = 128`、2 个 stage，又只有 32 个 block，需要 201.7 µs。autotune 后是 *166.9 µs*，Block 视角中最快。

== `block_alloc_reducer`

`block_alloc_reducer` 把规约也交给 TileLang：

```python
with T.Kernel(T.ceildiv(N, block_n), threads=threads) as pid_n:
    reducer = T.alloc_reducer(block_n, "float32", replication="all")
    T.clear(reducer)
    for pid_k in T.Pipelined(T.ceildiv(K, block_k), num_stages=num_stages):
        # T.copy the tile of matrix and vector into fragments
        for i, k in T.Parallel(block_n, block_k):
            reducer[i] += matrix_fragment[i, k] * vector_fragment[k]
    T.finalize_reducer(reducer)
    T.copy(reducer, output[pid_n * block_n])
```

`T.Parallel(block_n, block_k)` 把整个 tile 分给 block 的 256 个线程，于是多个线程会加到同一个 `reducer[i]` 上。`replication="all"` 时每个线程持有 `block_n` 个和的一份副本，`T.finalize_reducer` 在最后把各副本加起来。这是本文最简洁的 kernel：默认 215.0 µs，autotune 后 170.0 µs。

= Performance

#figure(
  fig.fig-results(),
  caption: [十四个 kernel 在默认配置和 autotune 后的带宽，对比 A6000 的 768 GB/s 和 `torch.compile`。右侧为中位时间。],
) <gemv-results>

- *autotune 之后，14 个 kernel 中有 11 个彼此相差不到 4%*，在 165.9–172.0 µs 之间，即上限的 89–92%。`torch.compile` 的 169.0 µs 也在其中。
- *默认配置之间相差 10 倍。* autotune 消除了大部分差距，因为差距主要来自 block 数量。但它救不了每个线程要走完一整列的 kernel：`thread_naive` 仍需 817 µs。
- *单步收益最大的是合并访存*：交换两个线程维度，614 µs 降到 170 µs。
- *规约方式影响最小。* Shared atomic、线程间 all-reduce 和 TileLang reducer 相差只有几微秒。

#fold(title: [全部数据])[
  #table(
    columns: 4,
    align: (left, right, right, right),
    table.header([Kernel], [默认 (µs)], [Autotune (µs)], [Autotune (GB/s)]),
    [`thread_naive`], [1709.1], [817.2], [144],
    [`thread_naive_split_k`], [614.4], [181.2], [648],
    [`thread_coalesced_naive_split_k`], [170.0], [170.0], [691],
    [`thread_split_k`], [606.2], [169.0], [695],
    [`thread_coalesced_split_k`], [167.9], [166.9], [704],
    [`thread_vectorized_split_k`], [166.9], [166.8], [704],
    [`thread_tvm_reduce_split_k`], [165.9], [165.9], [708],
    [`thread_shared_memory_split_k`], [175.8], [171.0], [687],
    [`thread_intra_block_split_k`], [281.6], [210.9], [557],
    [`block_naive`], [319.5], [171.0], [687],
    [`block_split_k`], [171.0], [170.0], [691],
    [`block_split_k_v2`], [174.1], [172.0], [683],
    [`block_pipelined`], [201.7], [166.9], [704],
    [`block_alloc_reducer`], [215.0], [170.0], [691],
    [`torch.compile`], [169.0], [], [695],
  )
]

#callout(kind: "note", title: "NOTE / 算法有效带宽")[
  这里的 GB/s 是 GEMV 必须搬运的 117 MB 除以时间。kernel 实际搬运的更多：split-K 的 atomic、FP32 输出及其填零、每个 block 各读一遍的向量，以及经过 shared memory 的复制。如果某个数超过 768 GB/s，说明有缓存命中或字节数算少了，而不是显存比硬件还快。
]

= Summary

各个 kernel 第一次用到的 TileLang 特性和碰到的 GPU 特性：

#table(
  columns: 3,
  align: (left, left, left),
  table.header([Kernel], [TileLang], [GPU]),
  [`thread_naive`], [`tilelang.jit`、`out_idx`、`T.Kernel`、`T.get_thread_binding`、`T.alloc_shared`、`T.alloc_local`、`T.serial`、`T.sync_threads`], [grid、block 与 SM 数],
  [`thread_naive_split_k`], [二维 `threads`、`T.atomic_add`], [线程编号与 warp],
  [`thread_coalesced_naive_split_k`], [交换线程维度], [合并访存、sector],
  [`thread_split_k`], [`T.alloc_local` 数组], [Block 与 Cyclic 访问],
  [`thread_vectorized_split_k`], [`T.vectorized`], [128-bit 加载],
  [`thread_tvm_reduce_split_k`], [`tvm_thread_allreduce`], [warp shuffle],
  [`block_naive`], [`T.copy`、`T.alloc_fragment`、`T.Parallel`], [],
  [`block_split_k`], [二维 grid、对 global memory 的 `T.atomic_add`], [FP16 累加的精度],
  [`block_pipelined`], [`T.Pipelined`], [加载与计算重叠],
  [`block_alloc_reducer`], [`T.alloc_reducer`、`T.finalize_reducer`], [],
)

对于受显存带宽限制的 kernel，几乎全部的加速来自三件事：

+ *足够多的 block。* 拿 `N / block_n` 和 SM 数比较；单靠一个维度 block 不够时，像 `block_split_k` 那样把 $K$ 也分给 block。
+ *同一时刻，warp 内的线程读相邻的地址。* 在 Thread 视角中，把 `T.get_thread_binding(0)` 绑定到沿连续内存前进的下标上。这一条和 CPU 的经验相反。
+ *每个线程一次读 16 字节。* 令 `tile_k = 128 // bits`，并使用 `T.vectorized`。

在 Block 视角中，`T.copy` 已经处理了后两条，剩下的只有 tile 大小，交给 autotune 去选。
