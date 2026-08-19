---
title: "TileLang Programming Model"
tags:
  - TileLang
date: 2026-08-18
showtoc: true
weight: 10
---

## Overview

首先介绍一下使用 tilelang 写 kernel 的两个视角：

+ Block 视角
  + 从一个 BLock 的视角写 Kernel, 操作的对象是整个 tile（比如一个 (BLOCK_M, BLOCK_N) 的矩阵片段），并行的粒度和分工方式通过 `T.Parallel`/`T.copy` 等声明式原语来表达，不关心具体哪个 threadIdx 做哪个元素。
  + 换句话说，我们只需要声明，具体的线程分配由 tilelang 框架来完成
+ Thread 视角
  + 从单个 Thread 的视角写 Kernel，block 内的并发是隐含的——因为 BLOCK_N 个 thread 各自都在执行同一份代码，天然并行，但代码里不体现这个并行结构。

> [!NOTE]
> Thread 视角可以让我们更贴近 CUDA 代码，但好像 tilelang example 中的用法基本都是 Block 视角，所以我们的重心应该放在 Block 视角上

### 简单例子

用 copy 1D tensor 举例：

+ **Block 视角**

```python
@tilelang.jit
def tl_copy_1d_parallel(A, BLOCK_N: int):
    # The host/declaration part of TileLang script.
    N = T.const("N")
    A: T.Tensor((N,), T.float16)
    B = T.empty((N,), T.float16)

    with T.Kernel(T.ceildiv(N, BLOCK_N), threads=256) as bx:
        offs = bx * BLOCK_N
        T.copy(A[offs : offs + BLOCK_N], B[offs : offs + BLOCK_N])

    return B
```

只需要声明在 Block level 的操作: 把 `A[offs : offs + BLOCK_N]` 复制到 `B[offs : offs + BLOCK_N]`, 具体底层是 threads 是如何复制的由框架决定

+ **Thread 视角**

```python
@tilelang.jit
def tl_copy_1d_parallel_thread_view(A, BLOCK_N: int):
    # The host/declaration part of TileLang script.
    N = T.const("N")
    A: T.Tensor((N,), T.float16)
    B = T.empty((N,), T.float16)

    with T.Kernel(T.ceildiv(N, BLOCK_N), threads=256) as bx:
        tx = T.get_thread_binding(0)

        for i in T.serial(T.ceildiv(BLOCK_N, 256)):
            idx = bx * BLOCK_N + i * 256 + tx
            B[idx] = A[idx]

    return B
```

在 Thread-level 进行操作: 当前 thread 具体负责复制哪些精确位置的数据

从这个简单例子也可以看出，Block Level 抽象程度更高，Thread Level 操作粒度更细，有着更多自由发挥的空间

两者编译后的 CUDA 代码如下:

+ **Block Level**

```c++
extern "C" __global__ void __launch_bounds__(256, 1) tl_copy_1d_parallel_kernel(const half_t* __restrict__ A, half_t* __restrict__ B) {
 int offset = blockIdx.x * 1024 + threadIdx.x * 4;
 *(uint2*)(B + offset) = *(uint2*)(A + offset);
}
```

+ **Thread level**

```c++
extern "C" __global__ void __launch_bounds__(256, 1) tl_copy_1d_parallel_thread_view_kernel(const half_t* __restrict__ A, half_t* __restrict__ B) {
  for (int i = 0; i < 4; ++i) {
    B[(blockIdx.x * 1024) + (i * 256) + threadIdx.x] = A[(blockIdx.x * 1024) + (i * 256)) + threadIdx.x];
  }
}
```

可以发现由 Block Level 生成的代码自动做了向量化优化，在 1024x1024 长度下进行 copy:

+ block_level: 0.034ms
+ thread_level: 0.055ms

#### 向量化优化

一个简化版的解释如下：

假设一个 block 有 4 个线程，要搬 16 个格子：

```ascii
格子编号:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
```

Kernel 1 的切法（按块切，每人拿一整块）

```ascii
Thread 0: [0  1  2  3]           → threadIdx.x * 4 = 0
Thread 1:             [4  5  6  7]
Thread 2:                         [8  9 10 11]
Thread 3:                                     [12 13 14 15]
```

每人拿到连续的 4 个，一次拿走。threadIdx.x * 4 就是每人的起始位置。

Kernel 2 的切法（按列切，分 4 轮，每轮每人拿 1 个）

```ascii
         i=0        i=1        i=2        i=3
Thread 0: [0]        [4]        [8]        [12]
Thread 1:  [1]        [5]        [9]        [13]
Thread 2:   [2]        [6]        [10]       [14]
Thread 3:    [3]        [7]        [11]       [15]
每轮 i，每人拿 i*4 + threadIdx.x 号格子。i * 4（实际是 i * 线程数）用来跳到下一轮。
```

### 原语差别

很容易想到，在 Block 视角下，有一些声明式原语会指导框架进行线程分配，常见的有:

+ 数据复制
  + `T.copy`: 只需要声明需要复制的数据在哪里，有哪些
+ 执行工作流
  + `T.Parallel(BLOCK_N)`: 这 BLOCK_N 次迭代之间没有依赖，请用 Block 里的所有线程尽量并行地完成它们

使用 `T.Parallel(BLOCK_N)` 时自然会出现一个问题，如果迭代次数大于 Block 中的线程数，编译器会不会自动加入一个类似于 `T.serial` 的 for loop 呢？

答案是会的，对于上面提到的 copy kernel，如果我们关闭向量化优化，就会得到下面的 CUDA 代码：

```cpp
extern "C" __global__ void __launch_bounds__(256, 1) tl_copy_1d_parallel_kernel(const half_t* __restrict__ A, half_t* __restrict__ B) {
 for (int i = 0; i < 4; ++i) {
     B[(blockIdx.x * 1024) + (threadIdx.x * 4) + i] = A[(blockIdx.x * 1024) + (threadIdx.x * 4) + i];
  }
}
```

虽然说是线程是 block 访问的，不能合并访问，但是这种 pattern 非常利于向量化优化

所以从 Block Level -> Thread Level, 一个常见的转换是：

+ 把 `T.Parallel(BLOCK_N)` 这个外层循环去掉
+ 增加一个 `T.serial(BLOCK_N // threads)` 的循环，代表每个 thread 需要做多少次串行迭代

```python
# block level
for i in T.Parallel(BLOCK_N):
 do_sth

# thread level
for i in T.serial(BLOCK_N // threads):
 do_sth

```

## 内存分配

在 Block 视角下进行内存的分配，比如 `T.alloc_shared` 比较直观，如果是 Thread 视角下，`T.alloc_shared` 会不会被执行多份呢？

答案是不会的， 这和 CUDA 的 `__shared__` 完全一致

```c++
__global__ void kernel() {
    // 语法上"每个 thread 都执行到这行"
    // 但 __shared__ 变量实际上是 block 级别，只有一份
    __shared__ float A_shared[BLOCK_K];
    // ...
}
```

TileLang 的 `T.alloc_shared` 同理，虽然写在 thread body 里，但编译器知道它是 Block 级别的声明，只会分配一块 shared memory，所有 thread 访问的是同一块物理地址

自然而然，使用 `T.alloc_local` 就是单个 Thread 私有的，典型用途是用来存储 Thread 视角的中间变量

`T.alloc_fragment` 比较特殊，在 thread 之间是共享还是私有？

可以说两者都不是，是分布式持有（distributed）

```python
T.alloc_local((1,), dtype)     → 完全私有，每个 thread 独立一份，互不可见
T.alloc_shared((N,), dtype)    → 完全共享，所有 thread 访问同一份
T.alloc_fragment((N,), dtype)  → 分布式，逻辑上是一个 tile，物理上切分给各 thread
```

以 `T.alloc_fragment((BLOCK_N,), accum)` 且 threads=BLOCK_N 为例：

```ascii
逻辑视图（block 看到的）：     acc = [a0, a1, a2, ..., a_{N-1}]
                                       ↑                  ↑
物理视图（每个 thread 持有）：  thread 0: acc[0]    thread N-1: acc[N-1]
```

每个 thread 只在寄存器里持有自己那一份，但程序员可以用 tile 坐标来索引，框架负责翻译成 thread 本地的正确访问。

所以 fragment 的特点是：逻辑上是 block 级别的 tile，物理上是 per-thread 的私有寄存器，只是按照某种 layout 分布在各 thread 上

## 操作的层级归宿

TileLang 对操作有严格的层级归属：

```ascii
Block scope（块级）
│
│  ← T.copy, T.clear, T.fill, T.gemm 等 tile-op 必须在这里
│     所有线程协作完成，本质是集体操作（collective op）
│
└── T.Parallel（线程级并行边界）
      │
      │  ← 只允许 elementwise 操作
      │     每个线程独立执行，彼此不协调
      │
      └── T.serial
```

换句话说：

+ 需要所有线程参与的操作（T.copy、T.gemm）→ 必须在 T.Parallel 外
+ 每个线程独立做的操作（加减乘除、赋值）→ 可以在 T.Parallel 内

所以下面的写法无法编译，因为 `T.copy` 是 collective 操作，不能放在 `T.Parallel` 内：

```python
with T.Kernel(T.ceildiv(N, BLOCK_N), threads=256) as bx:
    shared = T.alloc_shared((BLOCK_N,), T.float16)
    for i in T.Parallel(BLOCK_N):
        T.copy(source, shared)  # 非法：collective 操作位于线程级边界内
```
