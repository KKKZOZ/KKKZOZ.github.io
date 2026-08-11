---
title: ML Compilers Overview
tags:
  - ML Compilers
  - torch.compile
date: 2026-08-9
showtoc: true
weight: 10
---

## ML Compiler Overview

ML Compiler 位于深度学习框架和底层硬件之间，作用是把 TensorFlow、PyTorch、JAX 等框架描述的高层张量计算转换成能在 CPU/GPU/TPU 等硬件上高效执行的程序。

它的典型架构是 Frontend → IR → Optimization → Backend:

+ Frontend 接收框架已经构造或捕获出来的计算图/算子程序（例如 tf.function 得到的 TF Graph、PyTorch Dynamo 得到的 FX Graph），转换成统一的中间表示 IR
+ 中间层进行算子融合、常量折叠、布局变换、内存规划、并行化等与机器学习计算相关的优化
+ Backend 再根据目标硬件进行 lowering、调度和代码生成

因而 ML compiler 输入通常是带有 tensor shape、dtype、算子及数据依赖关系的计算图或 IR，输出则是面向特定设备的低层 IR、kernel 或可执行程序。

> 需要特别区分的是：graph capture 不一定属于 compiler 本身——例如 TensorFlow 由 tf.function tracing 捕获图，PyTorch 由 TorchDynamo 捕获图，然后 ML compiler 才接手，对这个图做优化并最终生成高效机器码。

## IR Pipeline

下面这套 IR 划分描述的是一个典型 ML Compiler 从**高层模型计算**逐渐 lowering 到**硬件可执行 kernel** 的过程。不同编译器实际使用的 IR 名称和数据结构可能不同，但抽象层次通常可以归纳为：

```text
Framework Program: 使用 PyTorch、TensorFlow 等框架描述模型计算
    ↓ graph capture / import
Framework IR: 表达框架级算子及其数据依赖关系
    ↓ decomposition + canonicalization
Tensor IR: 用 Elementwise、Reduction 和 IndexMap 表达规范化张量语义
    ↓ lifting + legal loop fusion
Loop IR: 将张量计算组织成显式循环和 kernel loop nests
    ↓ scheduling + abstract hardware mapping
Tile IR: 描述分块、内存 staging 和 THREAD/BLOCK 等抽象调度决策
    ↓ materialize concrete hardware primitives
Kernel IR: 将调度决策落实为线程、内存和同步等硬件操作
    ↓ target code emission
Target Code: 生成面向具体硬件后端的源代码
```

> [!NOTE]
> 每向下一层，都会逐渐减少框架语义，增加执行、调度和硬件相关的信息

下面各层的 **Example** 来自同一次 Emmy `compile --ir` 运行。输入程序为 `SiluAndMul(x)`：沿最后一维将 `float32[1, 32, 4096]` 的 `x` 分成两半，对前半部分计算 SiLU，再与后半部分逐元素相乘。导出环境为 PyTorch `2.13.0`、Emmy `c6755ee`，目标 GPU 为 A6000

```python
class SiluAndMul(nn.Module):
    def forward(self, x):
        left, right = x.chunk(2, dim=-1)
        return F.silu(left) * right
```

### Framework IR

**Framework IR 表达模型中的高层算子以及算子之间的数据依赖关系**

这一层关注的是“**要计算什么**”，通常仍然保留深度学习框架中的高层 tensor operator，例如 matrix multiplication、convolution、attention、softmax 等，而不会描述这些算子内部如何实现

**Example**

Emmy 的 Torch IR 仍接近捕获到的 PyTorch operator：

```text
inputs:
  x: (1, 32, 4096) f32

chunk_0 = slice(x, dim=2, start=0)     -> (1, 32, 2048) f32
chunk_1 = slice(x, dim=2, start=2048)  -> (1, 32, 2048) f32
silu    = silu(chunk_0)                -> (1, 32, 2048) f32
mul     = multiply(silu, chunk_1)      -> (1, 32, 2048) f32

outputs:
  mul: (1, 32, 2048) f32
```

`chunk(2, -1)` 已被静态解析为两个 `slice`，但 `silu` 和 `multiply` 仍是高层 tensor operator。这一层描述两个 slice、SiLU 和 multiply 的数据依赖，尚未决定 slice 是否复制数据，也没有显式 loop 或 hardware mapping。

### Tensor IR

**Tensor IR 将高层算子分解成更基础、统一的张量计算语义。** 对大量规则的 dense tensor computation，可以把其核心抽象归纳为三类：

1. **Elementwise**：描述每个输出位置执行的标量计算，例如 `add`、`mul`、`exp`
2. **Reduction**：描述沿某个维度进行聚合，例如 `sum`、`max`
3. **IndexMap**：使用坐标映射统一表示 broadcast、reshape、transpose、slice 等布局和索引变换

**Example**

同一个 SiluAndMul 在 Emmy Tensor IR 中被表示为 IndexMap 与 Elementwise primitive：

> 本例只有 IndexMap 和 Elementwise semantics，没有 Reduction

```python
chunk_0      = x[i, j, k]
chunk_1      = x[i, j, k + 2048]
silu_neg     = negative(chunk_0)
silu_exp     = exp(silu_neg)
silu_denom   = add(1.0, silu_exp)
silu_sigmoid = reciprocal(silu_denom)
silu         = multiply(chunk_0, silu_sigmoid)
mul          = multiply(silu, chunk_1)
```

+ 两个 `slice` 已经变成直接作用于原输入的坐标映射，因此 graph 中没有 chunk copy
+ 高层 `silu` 则被 decomposition 为 `negative`、`exp`、`add`、`reciprocal` 和 `multiply`
+ 不同框架中的高层 operator 正是通过这种 canonicalization 被统一到少数基础 tensor semantics，供后续 Loop IR 使用。

### Loop IR

**Loop IR 将 Tensor IR 中的张量计算显式展开成 iteration、indexing、load/store 和 reduction。**

Tensor IR 中的 primitive 会先被 lifting 为 loop nest，再在合法的情况下进行 loop fusion，将相邻计算合并为尽可能少的 kernel loop nests。

> 这一层开始从“Tensor 之间做什么计算”转向“这个计算如何通过循环执行”

**Example**

Emmy 将前面的 IndexMap 和 Elementwise nodes lifting 并 fusion 为一个 pointwise loop nest：

```python
for a0 in 0..32:
    for a1 in 0..2048:
        left = load x[0, a0, a1]
        neg = negative(left)
        exp_neg = exp(neg)
        sigmoid = reciprocal(add(1.0, exp_neg))
        silu = multiply(left, sigmoid)
        right = load x[0, a0, a1 + 2048]
        output = multiply(right, silu)
        store mul[0, a0, a1] = output
```

`a0` 和 `a1` 都是 free / parallel axes。两个 chunk load、SiLU decomposition 和最终 multiply 已进入同一次 loop iteration，没有 intermediate tensor store。

此时 IR 已明确 iteration space、indexing 和 load/store，但还没有决定展开因子、worker 数量或 CUDA thread mapping。

### Tile IR

**Tile IR 在 Loop IR 的基础上加入 schedule 信息，描述循环如何被切分、重排、映射到并行计算资源，以及数据如何在内存层级之间 staging。**

在 ML Compiler 中，**schedule** 指的是：

> 在不改变计算结果的前提下，决定一个 computation 应该以什么执行策略运行。

典型的 scheduling 决策包括：

1. **Tiling**：把大的 iteration space 划分成较小的 tile
2. **Reordering**：调整 loop 的执行顺序
3. **Parallelization**：将计算轴抽象地绑定到 THREAD、BLOCK 等并行维度
4. **Memory staging**：决定哪些数据需要经过 shared memory 等片上存储
5. **Hardware-aware scheduling**：根据目标硬件加入规约、同步和流水线等调度决策

**Example**

本次默认 pointwise schedule 选择 4 路展开。下面保留第一个和最后一个 unrolled lane：

```python
in1__u0 = load x[0, a0, a1 * 4 + 0]
in2__u0 = load x[0, a0, a1 * 4 + 0 + 2048]
v0__u0 = negative(in1__u0)
v1__u0 = exp(v0__u0)
v2__u0 = add(1.0, v1__u0)
v3__u0 = reciprocal(v2__u0)
v5__u0 = multiply(in2__u0, multiply(in1__u0, v3__u0))

# __u1 和 __u2 执行相同计算

in1__u3 = load x[0, a0, a1 * 4 + 3]
in2__u3 = load x[0, a0, a1 * 4 + 3 + 2048]
v0__u3 = negative(in1__u3)
v1__u3 = exp(v0__u3)
v2__u3 = add(1.0, v1__u3)
v3__u3 = reciprocal(v2__u3)
v5__u3 = multiply(in2__u3, multiply(in1__u3, v3__u3))

store mul[0, a0, a1 * 4 + 0] = v5__u0
store mul[0, a0, a1 * 4 + 1] = v5__u1
store mul[0, a0, a1 * 4 + 2] = v5__u2
store mul[0, a0, a1 * 4 + 3] = v5__u3
```

一个逻辑 worker 现在处理 `a1 * 4 + {0, 1, 2, 3}` 四个连续位置。`__u0` 到 `__u3` 是四个彼此独立的 unrolled lane；前后两个 chunk 的 load 使用相同展开因子，为后续 vector store 准备连续结果。

### Kernel IR

**Kernel IR 将 Tile IR 中的抽象调度决策物化为具体的硬件 primitive。** 这一层已经面向目标硬件的执行模型，但仍然是一种结构化 IR，而不是最终的 CUDA、Triton 或 C++ 源代码。

经过 Tile IR lowering 之后，Kernel IR 通常已经明确：

1. kernel 的输入、输出和边界
2. block、thread 等具体 launch geometry
3. global、shared、local 等内存空间
4. indexing、load、store 和异步拷贝方式
5. barrier、同步和跨线程规约操作
6. 目标相关的并行工作分解

**Example**

Emmy Kernel IR 将 4 路展开落实为 worker tile、具体 `f32` scalar 和 vector store。下面只展开第一个 lane：

```python
Tile[a0, a1] (N=16384)
    in1__u0 = load x[0, a0, a1 * 4 + 0]
    f32 v0__u0 = negative(in1__u0)
    f32 v1__u0 = exp(v0__u0)
    f32 v2__u0 = add(1.0, v1__u0)
    f32 v3__u0 = reciprocal(v2__u0)
    f32 v4__u0 = multiply(in1__u0, v3__u0)
    in2__u0 = load x[0, a0, a1 * 4 + 0 + 2048]
    f32 v5__u0 = multiply(in2__u0, v4__u0)

    # __u1、__u2、__u3 采用相同结构
    mul[0, a0, a1 * 4] = (v5__u0, v5__u1, v5__u2, v5__u3)
```

`N=16384` 对应 `32 × 512` 个逻辑 worker，每个 worker 处理四个连续元素，因此覆盖 `32 × 2048` 个输出。四个结果被组合为一次 vector store。该 kernel 没有跨 worker dependency，所以不需要 reduction、shared memory、barrier 或 synchronization。

Kernel IR 可以理解为已经形成 kernel boundary，并将 schedule 落实为 target-oriented worker、dtype、memory operation 和 synchronization primitive，但尚未渲染成目标语言源码。

不同 compiler 的分层边界并不完全相同：Emmy 在这一层使用 `Tile[a0, a1]` 表达 worker grid，具体 `blockIdx.x`、`threadIdx.x` 和 block size 在 CUDA rendering 时才完全物化。

### Target Code

**Target Code 将 Kernel IR 渲染为目标 backend 可以继续编译的源代码。** 它已经使用目标语言的 thread index、pointer arithmetic、intrinsic 和 vector type，但通常还不是 GPU 直接执行的 machine code。

**Example**

Emmy 将上述 Kernel IR 渲染为 CUDA C++。下面保留 thread mapping、四个 unrolled lanes 和最终 vector store：

```cpp
extern "C" __global__
__launch_bounds__(256)
void k_slice_pointwise_dcfb6d(
    const float * x,
    const float * silu_one,
    float * mul
) {
    int gid = blockIdx.x * blockDim.x + threadIdx.x;
    int a0 = gid / 512;
    int a1 = gid % 512;

    float left_u0 = x[a0 * 4096 + a1 * 4];
    float right_u0 = x[a0 * 4096 + a1 * 4 + 2048];
    float out_u0 = right_u0 * (
        left_u0 * (1.0f / (silu_one[0] + expf(0.0f - left_u0)))
    );

    float left_u1 = x[a0 * 4096 + a1 * 4 + 1];
    float right_u1 = x[a0 * 4096 + a1 * 4 + 1 + 2048];
    float out_u1 = right_u1 * (
        left_u1 * (1.0f / (silu_one[0] + expf(0.0f - left_u1)))
    );

    float left_u2 = x[a0 * 4096 + a1 * 4 + 2];
    float right_u2 = x[a0 * 4096 + a1 * 4 + 2 + 2048];
    float out_u2 = right_u2 * (
        left_u2 * (1.0f / (silu_one[0] + expf(0.0f - left_u2)))
    );

    float left_u3 = x[a0 * 4096 + a1 * 4 + 3];
    float right_u3 = x[a0 * 4096 + a1 * 4 + 3 + 2048];
    float out_u3 = right_u3 * (
        left_u3 * (1.0f / (silu_one[0] + expf(0.0f - left_u3)))
    );

    float4 output = make_float4(out_u0, out_u1, out_u2, out_u3);
    *reinterpret_cast<float4 *>(&mul[a0 * 2048 + a1 * 4]) = output;
}
```

`Tile[a0, a1]` 被映射为一维 `gid`，再通过 `/ 512` 和 `% 512` 恢复两个 worker axes。`16384` 个 worker 按 `256` threads/block 启动时需要 `64` 个 block。输入仍是 scalar load，明确的 vectorization 出现在最终 `float4` store。此次导出停在 CUDA source；还需经过 `nvcc` 等工具链才能得到 PTX、cubin 或其他 machine-code artifact。

### Summary

整个 lowering 过程可以概括为：

```text
Framework Program
    │
    │ Graph capture / import
    ▼
Framework IR
    │
    │ Decomposition + canonicalization
    ▼
Tensor IR
    │
    │ Lifting + legal loop fusion
    ▼
Loop IR
    │
    │ Scheduling + abstract hardware mapping
    ▼
Tile IR
    │
    │ Materialize concrete hardware primitives
    ▼
Kernel IR
    │
    │ Target code emission
    ▼
Target Code
    │
    │ Compile
    ▼
Machine Code
```

因此各层最核心的区别可以理解为：

```text
Framework IR
    算什么高层 operator

Tensor IR
    用 Elementwise、Reduction 和 IndexMap 表达什么张量计算

Loop IR
    张量计算如何展开并融合成 kernel loop nests

Tile IR
    loop nest 如何切分、进行内存 staging 并映射到抽象 GPU 资源

Kernel IR
    调度决策如何落实为线程、内存和同步等硬件 primitive

Target Code
    Kernel IR 如何表示为目标 backend 源代码

Machine Code
    硬件最终执行什么
```

从 ML Compiler 的角度看，这整个过程本质上就是不断进行 **lowering**：

```text
High-level semantics
        ↓
Tensor semantics
        ↓
Iteration semantics
        ↓
Scheduling semantics
        ↓
Kernel semantics
        ↓
Hardware semantics
```

也就是不断从“**描述计算是什么**”下降到“**描述硬件具体怎么执行这个计算**”。

### Summary

Compiler 的典型架构是 Frontend → IR → Optimization → Backend Code:

+ Frontend 接收框架已经构造或捕获出来的计算图/算子程序（例如 tf.function 得到的 TF Graph、PyTorch Dynamo 得到的 FX Graph），转换成统一的中间表示 IR
+ 中间层进行算子融合、常量折叠、布局变换、内存规划、并行化等与机器学习计算相关的优化
+ Backend 再根据目标硬件进行 lowering、调度和代码生成

## PyTorch Eager Mode

Eager mode 下不存在 “Python → IR → Backend Code” 这个编译过程

Python 每执行一个 PyTorch op，就通过 Dispatcher 找到已经实现好的 CUDA kernel，然后直接 launch

整体流程如下:

```ascii
Python / nn.Module
      │
      │ Python 调用
      ▼
1. PyTorch Python API
   torch.add / torch.matmul / F.relu / ...
      │
      ▼
2. ATen Operator
   aten::add
   aten::mm
   aten::relu
      │
      ▼
3. PyTorch Dispatcher
   根据 Tensor 属性选择实现
   CPU / CUDA / Autograd / Autocast / ...
      │
      ▼
4. CUDA Operator Implementation
   ATen native CUDA implementation
      │
      ├───────────────┐
      ▼               ▼
5a. PyTorch CUDA     5b. External Library
    Kernel               cuBLAS / cuDNN / ...
      │                   │
      └─────────┬─────────┘
                ▼
5. CUDA Runtime / Driver
   kernel launch
                │
                ▼
               GPU

```

在 Eager Mode 下，CUDA code 大部分是**在 PyTorch / CUDA libraries 构建时**就编译好了

## PyTorch torch.compile

### Overview

> 我们只考虑 inference, 不考虑 backward/training

> [!INFO] Frontend and Backend in ML Compilers
>
> + Fronted: 把框架/模型表达转换成统一的中间表示（IR），供编译器分析和优化
> + Backend: 对 IR 进行优化和 scheduling，并将其逐步 lowering 为目标硬件可执行的代码

```ascii
Python / nn.Module
     │
     ▼
1. TorchDynamo
   Python bytecode → FX Graph
     │
     ▼
2. AOTDispatcher / AOTAutograd
   FX Graph → functionalized / decomposed ATen FX Graph
     │
     │                                        Frontend
======================================================
     ▼                                        Backend
3. TorchInductor Graph Passes
   图优化 / pattern rewrite / lowering preparation
     │
     ▼
4. TorchInductor IR + Scheduler
   ATen Graph → loop-level IR
   fusion / scheduling / memory planning
     │
     ▼
5. Codegen
   GPU: Triton / CuTeDSL / external kernels
   CPU: C++ / OpenMP
     │
     ▼
6. Kernel Compilation + Runtime
   Triton/CuTeDSL/CUDA/C++ 编译 → 执行

```

总的来说可以分为四层

| 阶段                    | 组件                              | 核心职责                                               |
| --------------------- | ------------------------------- | -------------------------------------------------- |
| **Capture**           | **TorchDynamo**                 | Python bytecode → FX Graph，guards / graph break    |
| **Normalize**         | **AOTDispatcher / AOTAutograd** | functionalization、decomposition，得到规范化 ATen Graph   |
| **Optimize + Lower**  | **TorchInductor**               | graph optimization → loop IR → fusion / scheduling |
| **Codegen + Execute** | **Inductor + Triton/CuTeDSL/C++** | 生成 kernel、编译、缓存、执行                               |

### Workflow

#### 1 Graph Capture：TorchDynamo

> 对应从 **Framework Program** 到 **Framework IR** 的 graph capture。

Dynamo 会 hook CPython 的 frame evaluation，解释 Python bytecode，把其中能编译的 Tensor 操作提取成 `torch.fx.GraphModule`

相关的操作有:

+ Python bytecode tracing
+ 捕获 PyTorch Tensor 操作
+ 建立 FX Graph
+ 处理 Python control flow
+ Shape / dtype / stride 等 symbolic 信息
+ 建立 guards
+ 遇到不能 capture 的代码时产生 graph break

**Example**

下面各阶段的示例来自同一次 SiluAndMul inference 编译：PyTorch `2.11.0+cu129`，运行设备为 NVIDIA RTX A6000，输入为连续的 `float16[4, 256]` tensor，输出 shape 为 `[4, 128]`。调用侧通过 `torch.compile(model)` 编译整个 module：

```python
class SiluAndMul(nn.Module):
    def forward(self, x):
        left, right = x.chunk(2, dim=-1)
        return F.silu(left) * right

compiled_model = torch.compile(SiluAndMul().cuda().eval())
output = compiled_model(x)
```

Dynamo 捕获的 FX Graph 可以先打印为便于阅读的 Python-like code：

```python
def forward(L_x_):
    chunk = L_x_.chunk(2, -1)
    x = chunk[0]  # f16[4, 128], stride=[256, 1]
    y = chunk[1]  # f16[4, 128], stride=[256, 1]
    silu = torch.nn.functional.silu(x)
    output = silu * y
    return (output,)
```

同一张图的 node-level 表示由 backend wrapper 在 Dynamo 与 Inductor 的边界直接读取 `graph_module.graph` 得到：

```text
graph():
    %l_x_ : torch.Tensor [num_users=1] = placeholder[target=L_x_]
    %chunk : [num_users=2] = call_method[target=chunk](
        args = (%l_x_, 2, -1), kwargs = {}
    )
    %x : [num_users=1] = call_function[target=operator.getitem](
        args = (%chunk, 0), kwargs = {}
    )
    %y : [num_users=1] = call_function[target=operator.getitem](
        args = (%chunk, 1), kwargs = {}
    )
    %silu : [num_users=1] = call_function[target=torch.nn.functional.silu](
        args = (%x,), kwargs = {}
    )
    %mul : [num_users=1] = call_function[target=operator.mul](
        args = (%silu, %y), kwargs = {}
    )
    return (mul,)
```

其中每一行对应一个 `torch.fx.Node`：

+ `placeholder` 表示 graph input。
+ `call_method[target=chunk]` 表示调用 Tensor method `x.chunk(...)`。
+ 两个 `call_function[target=operator.getitem]` 分别取得 chunk result 的第 `0`、`1` 项。
+ `call_function[target=torch.nn.functional.silu]` 和 `call_function[target=operator.mul]` 表示两个普通函数调用。
+ `num_users` 是该 node output 被后续 node 使用的次数。例如 `%chunk` 同时被 `%x` 和 `%y` 使用，因此为 `2`。
+ `return (mul,)` 对应 FX Graph 的 `output` node。

这一层仍保留 `Tensor.chunk()` 和 `F.silu()` 等高层调用。两个 chunk output 的 row stride 都是 `256`，说明它们只是分别指向每行前后两半的 view，并没有复制数据。Dynamo 同时为输入建立 `TENSOR_MATCH` guard，约束其 shape、stride、dtype、device 和 `requires_grad`；相关条件不兼容时可能触发重新编译。

本次运行记录的关键 input guard 为：

```python
TENSOR_MATCH: check_tensor(
    L['x'], Tensor,
    DispatchKeySet(
        CUDA,            # 数据位于 CUDA backend，operator 应 dispatch 到 CUDA implementation
        BackendSelect,   # Dispatcher 用它参与选择具体 device/backend
        ADInplaceOrView, # 处理 autograd 的 inplace/view bookkeeping；不表示输入本身一定是 view
    ),
    torch.float16, device=1, requires_grad=False,
    size=[4, 256], stride=[256, 1]
)
```

#### 2 Graph Normalize: AOTAutograd

> 对应从 **Framework IR** 到 **Tensor IR** 的 decomposition 与 canonicalization。

这一阶段主要负责对 Dynamo 捕获的高层 PyTorch graph 进行 functionalization、decomposition 以及 alias/mutation 规范化，生成适合后续后端优化与 lowering 的 ATen FX Graph

```ascii
Dynamo FX Graph
       ↓
functionalization
decomposition
alias / mutation normalization
       ↓
ATen FX Graph
```

典型工作包括：

+ **Functionalization**
  + 尽量处理 mutation / inplace / alias
+ **Decomposition**
  + 复杂 op 拆成 backend 更容易处理的 ATen op
+ 规范化 graph
+ 根据 inference/training 情况 dispatch 给后端 compiler

**Example**

同一个 SiluAndMul 经 AOTDispatcher normalization 后得到规范化 ATen/Prims Graph：

```python
def forward(arg0_1):
    split = torch.ops.aten.split.Tensor(arg0_1, 128, -1)
    x = split[0]
    y = split[1]

    x_fp32 = torch.ops.prims.convert_element_type.default(x, torch.float32)
    neg = torch.ops.aten.neg.default(x_fp32)
    exp = torch.ops.aten.exp.default(neg)
    denominator = torch.ops.aten.add.Tensor(exp, 1)
    silu = torch.ops.aten.div.Tensor(x_fp32, denominator)
    silu_fp16 = torch.ops.prims.convert_element_type.default(
        silu, torch.float16
    )
    output = torch.ops.aten.mul.Tensor(silu_fp16, y)
    return (output,)
```

+ `chunk(2, -1)` 被规范化为固定 split size 为 `128` 的 `aten.split.Tensor`
+ 高层 `F.silu()` 则 decomposition 为 `float32` 中的 `neg → exp → add → div`，对应 `x / (1 + exp(-x))`；结果在与 `y` 相乘前转换回 `float16`。
+ 这组显式 dtype conversion 为后续判断 codegen 是否进行 floating-point fusion 提供了依据。

#### 3 Graph Optimization：TorchInductor Graph Passes

> 对应 **Tensor IR** 层的 graph-level optimization。

Inductor 会先做一系列 FX-level optimization/pass，比如:

```
ATen FX Graph
     ↓
pattern matching
operator rewrite
layout-related optimization
fusion preparation
...
```

> [!NOTE]
> 可以把这个阶段理解为对计算图本身做 compiler optimization

**Example**

这次运行中，Inductor 的 pre-grad 和 post-grad FX passes 均实际执行，但 `fx_graph_readable.py` 与 `fx_graph_transformed.py` 没有文本差异。例如下面的 operation sequence 在 pass 前后保持不变：

```text
aten.split.Tensor
prims.convert_element_type
aten.neg.default
aten.exp.default
aten.add.Tensor
aten.div.Tensor
prims.convert_element_type
aten.mul.Tensor
```

这表示 `remove_noop_ops`、pattern rewrite 和 reorder 没有找到适用于当前 graph 的 FX-level transformation。

本例的主要变化出现在后续 lowering、scheduling 和 codegen。

#### 4 Lowering + Scheduling: TorchInductor IR

> 对应 **Tensor IR → Loop IR → Tile IR** 的 lowering、fusion 与 scheduling。

Inductor 会从 FX / ATen graph lower 到自己的 loop-level IR

随后 scheduler 会决定：

+ 哪些 op 可以 fuse
+ kernel 边界
+ execution order
+ buffer dependencies
+ memory reuse / planning
+ tile / scheduling strategy

> [!NOTE]
> 这一层往往是 `torch.compile` 性能收益非常重要的一部分

**Example**

SiluAndMul lowering 后直接得到一个覆盖完整计算的 pointwise `ComputedBuffer`：

```python
op0: SchedulerNode(ComputedBuffer)  # 由 Inductor loop IR 计算得到的 pointwise output
op0.writes = [
    # 将 [4, 128] 输出按 row-major index 写入逻辑 buffer buf0
    MemoryDep("buf0", 128 * d0 + d1, {d0: 4, d1: 128})
]
op0.met_dependencies = [  # 已满足的 read dependencies；数据直接来自 graph input
    # 读取输入每行的前 128 个元素，即 chunk 后的 x
    MemoryDep("arg0_1", 256 * d0 + d1, {d0: 4, d1: 128}),
    # offset +128，读取同一行的后 128 个元素，即 chunk 后的 y
    MemoryDep("arg0_1", 256 * d0 + d1 + 128, {d0: 4, d1: 128}),
]
op0.sizes = ([4, 128], [])  # pointwise iteration ranges；空列表表示没有 reduction axes

def op0_loop_body(ops, row, column):
    x_numerator = ops.to_dtype(
        ops.load("arg0_1", 256 * row + column),
        torch.float32,
        src_dtype=torch.float16,
    )
    x_for_exp = ops.to_dtype(
        ops.load("arg0_1", 256 * row + column),
        torch.float32,
        src_dtype=torch.float16,
    )
    neg = ops.neg(x_for_exp)
    exp = ops.exp(neg)
    denominator = ops.add(exp, 1.0)
    silu = ops.truediv(x_numerator, denominator)
    silu_fp16 = ops.to_dtype(silu, torch.float16)
    y = ops.load("arg0_1", 256 * row + column + 128)
    output = ops.mul(silu_fp16, y)
    ops.store("buf0", 128 * row + column, output)
```

两个 chunk view 被 lower 为 `256 * row + column` 和 `256 * row + column + 128` 两组 indexing，没有 split output buffer 或数据复制。SiLU decomposition 和最终 multiply 已经位于同一个 loop body 中，因此 pre-fusion 与 post-fusion IR 都只有同一个 `op0`：

```text
pre-fusion:  op0: SchedulerNode(ComputedBuffer)
post-fusion: op0: SchedulerNode(ComputedBuffer)
```

这并不表示 pointwise fusion 没有发生，而是这些 operation 在 lowering 时就已经合并进一个 loop-level node，Scheduler 不需要再构造 `FusedSchedulerNode`。原始 Loop IR 对前半部分输入保留两次 `ops.load()`；后续 Triton codegen 会通过 common-subexpression elimination 将其合并为一次实际 load。

#### 5 Backend Codegen

> 对应 **Tile IR → Kernel IR → Target Code** 的硬件 primitive 物化与代码生成。

##### PyTorch 2.13：CuTeDSL Native DSL Backend

PyTorch 2.13 的一个重点是继续扩展 TorchInductor 的 GPU backend。对于 NVIDIA GPU，如果暂时忽略 external kernel，过去常将 Inductor 的主要 codegen path 简化为：

```text
Inductor
    ↓
Triton
```

从 PyTorch 2.13 开始，Inductor 增加了 CuTeDSL 这条 alternative code-generation path：

```text
                    ┌─ Triton
Inductor kernels ───┤
                    └─ CuTeDSL
```

CuTeDSL 是基于 NVIDIA CuTe（CUDA Templates）的 Python-native DSL，可以直接表达 GPU tensor layout、tiling strategy 和 memory access pattern。当前 Inductor 集成主要面向 GEMM 与 RMSNorm 等关键 operation，为这些 workload 提供 Triton 之外的另一条高性能 codegen path；它不是对所有 Inductor GPU kernel 的整体替换。

PyTorch 2.13 还将相关 kernel compilation 从 thread pool 移到 subprocess pool，以绕开 Python GIL 对并行编译的限制。官方将这项能力描述为兼顾高性能与更快 compilation 的第二条路径，但目前仍标记为 `API Unstable`，实际是否选择 CuTeDSL 取决于 operation、hardware、dtype、layout 和 backend support。

> 参考：[PyTorch 2.13 Release Blog：CuTeDSL “Native DSL” Backend for Inductor](https://pytorch.org/blog/pytorch-2-13-release-blog/)

本文 SiluAndMul 实验使用 PyTorch `2.11.0+cu129`，实际走的是 Triton codegen path。对应 pipeline 为：

```ascii
ATen FX Graph
     │
     │ lowering.py
     ▼
Inductor IR
     │
     │ Scheduler
     │ fusion / grouping / dependencies
     ▼
Scheduled kernels
     │
     │ TritonScheduling + TritonKernel codegen
     ▼
Triton Python source
```

**Example**

上面的 pointwise `ComputedBuffer` 最终生成一个 Triton pointwise kernel：

```python
@triton_heuristics.pointwise(size_hints={"x": 512}, ...)
@triton.jit
def triton_poi_fused_mul_silu_split_0(
    in_ptr0,
    out_ptr0,
    xnumel,
    XBLOCK: tl.constexpr,
):
    xnumel = 512
    xindex = tl.program_id(0) * XBLOCK + tl.arange(0, XBLOCK)
    xmask = xindex < xnumel
    column = xindex % 128
    row = xindex // 128

    x = tl.load(
        in_ptr0 + column + 256 * row, xmask
    ).to(tl.float32)
    y = tl.load(
        in_ptr0 + 128 + column + 256 * row, xmask
    ).to(tl.float32)

    silu = x / (libdevice.exp(-x) + 1.0)
    output = silu * y

    tl.store(out_ptr0 + xindex, output, xmask)
```

Wrapper 中只有一次 output allocation 和一次 kernel launch：

```python
buf0 = empty_strided_cuda((4, 128), (128, 1), torch.float16)
triton_poi_fused_mul_silu_split_0.run(
    arg0_1, buf0, 512, stream=stream1
)
return (buf0,)
```

最终 kernel 使用两次 global load 分别读取每行前后两半，在 register 中完成 SiLU 和 multiply，再进行一次 global store。Loop IR 中对 `x` 的重复读取已经被 common-subexpression elimination 合并。AOT Graph 中 `silu: float32 → float16 → mul` 的中间 cast 也在启用 `enable_fp_fusion=True` 的 codegen 中被消除，SiLU 与最终乘法均在 `float32` 中完成，只在写入 `float16` output 时舍入。

Pointwise autotuner 最终选择 `XBLOCK=128`、`num_warps=4` 和 `num_stages=1`。输出共有 `512` 个元素，因此需要四个 Triton programs，每个 CTA 使用 `128` threads。

## Emmy && TVM

> [!QUESTION]
>
> + 为什么像 emmy, tvm 就不需要 torch.Dynamo, 也能处理 PyTorch 的代码?

Emmy 和 TVM 的 compiler core 都不直接解释任意 Python，而是接收已经捕获的计算图。Graph 可以由不同 frontend 产生：

```text
                         Graph Capture

                 ┌── TorchDynamo / torch.compile
Python / nn.Module
                 ├── torch.export(strict=True)
                 │      使用 Dynamo
                 │
                 ├── torch.export(strict=False)
                 │      使用 non-strict ProxyTensor tracing
                 │
                 ├── torch.fx.symbolic_trace
                 │
                 └── TorchScript / ONNX / 手写 IR
                              ↓
                      FX Graph / ExportedProgram
                              ↓
                    Emmy / TVM / Inductor
```

核心边界是：

> **Compiler 真正需要的是 Graph，不一定需要 Dynamo；是否使用 Dynamo 取决于上游选择的 graph capture frontend。**

### Emmy

当前 Emmy 的默认 PyTorch frontend 为：

```text
Python nn.Module
      ↓ torch.export.export()，默认 strict=True
ExportedProgram / FX Graph
      ↓ Emmy FX walker
Emmy Torch IR
      ↓ decomposition / fusion / scheduling / codegen
CUDA
```

Emmy 自己不分析 Python bytecode，但当前源码调用 `torch.export.export()` 时没有传入 `strict=False`，因此默认 capture 路径仍然会使用 Dynamo。只有改用 `torch.export(..., strict=False)` 时，capture 部分才会变成 CPython 正常执行加 ProxyTensor/FakeTensor tracing，从而绕开 Dynamo 的 bytecode analysis。

即使 graph capture 可以避开 Dynamo，复杂性也不会消失。为了让 HuggingFace 模型满足可导出和可编译约束，Emmy 会在 frontend 中进行模型适配，例如：

+ 预计算 causal mask。
+ 预计算或替换 rotary embedding 的 cos/sin 路径。
+ 将部分 MoE layer 拆成 pre、post-attention 和 expert wrapper，由 compiler 与 PyTorch runtime 分别处理。
+ 对尚未支持的 mutation、attention 或 MoE 结构直接报错，而不是静默生成不等价的 graph。

因此，Emmy 将问题限制为：

```text
满足约束的 PyTorch model
        ↓
可捕获、可规范化的 Graph
        ↓
Emmy compiler
```

它避免了自己实现通用 Python tracer，但代价是模型必须符合更严格的 frontend contract。

参考：[Emmy trace frontend](https://github.com/cloudrift-ai/emmy/blob/main/emmy/compiler/trace/torch.py) 和 [HuggingFace adapters](https://github.com/cloudrift-ai/emmy/blob/main/emmy/compiler/trace/huggingface.py)。

### TVM

TVM Relax 提供多条 PyTorch frontend 路径。

推荐的 `ExportedProgram` 路径为：

```text
PyTorch nn.Module
      ↓ torch.export.export(...)
ExportedProgram
      ↓ tvm.relax.frontend.torch.from_exported_program()
Relax IRModule
```

这里 TVM 不解释 Python，但是否使用 Dynamo 取决于 `torch.export` 的 `strict` 参数：默认 `strict=True` 会使用 Dynamo，`strict=False` 才使用 non-strict tracing。

TVM 也可以直接导入 FX Graph：

```text
PyTorch nn.Module
      ↓ torch.fx.symbolic_trace()
FX GraphModule
      ↓ tvm.relax.frontend.torch.from_fx()
Relax IRModule
```

这条路径不需要 Dynamo，但 `symbolic_trace()` 能处理的 Python 和 PyTorch 语义范围更窄。

TVM 还可以作为 `torch.compile` backend：

```text
Python / nn.Module
      ↓ torch.compile(backend=relax_dynamo())
TorchDynamo captured FX Graph
      ↓ TVM Relax backend
Relax IRModule → executable
```

`relax_dynamo()` 路径位于 `torch.compile` pipeline 内，因此会使用 Dynamo。三条路径的区别主要在 graph capture frontend，而不是 TVM compiler core 是否能够直接理解任意 Python。

参考：[TVM Importing Models 教程](https://tvm.apache.org/docs/how_to/tutorials/import_model.html)。

### torch.export

`torch.export` 会将 PyTorch callable 捕获为可序列化的 `ExportedProgram`。

从版本演进来看，`torch.export`、AOTInductor 与 deployment API 逐步沿着下面的主线收敛：

```ascii
PyTorch 2.2
│
├─ torch.export(strict=False) 出现
└─ AOTInductor Prototype 出现
        │
        ▼
PyTorch 2.6               ★ 第一个大分水岭
│
├─ PT2 Archive
├─ aoti_compile_and_package
├─ ABI-compatible codegen
├─ AOTI Minifier
└─ Dim.AUTO
        │
        ▼
PyTorch 2.8               ★ 第二个大分水岭
│
├─ strict=False 成为 torch.export 默认
├─ control-flow export 增强
└─ export API 开始进一步收敛
        │
        ▼
PyTorch 2.10
│
├─ AOTI backend integration
└─ TorchScript deprecated → export/compiler stack
        │
        ▼
PyTorch 2.11
│
└─ export_for_training 删除
   统一为 torch.export.export
        │
        ▼
PyTorch 2.12 / 2.13       ★ 新分支出现
│
├─ torch.export + AOTI
│     → C++ / non-Python AOT deployment
│
└─ torch.compile().aot_compile()
      → Python runtime AOT deployment
```

这条主线反映了两个变化：graph capture API 逐步向 `torch.export.export()` 收敛；AOT deployment 则开始区分面向 C++ / non-Python runtime 的 `torch.export + AOTI`，以及保留 Python runtime 的 `torch.compile().aot_compile()`。

下面继续比较 `strict=True` 与 `strict=False` 两种 graph capture 机制：

```text
strict=True：Dynamo tracing
Python bytecode
    ↓ Dynamo symbolic interpretation
FX Graph + guards / constraints

strict=False：non-strict tracing
CPython 正常执行
    ↓ FakeTensor 传播 metadata，ProxyTensor 记录 Tensor op
FX Graph
```

> **Dynamo 在分析 Python 程序的同时构图；non-strict tracing 则让 Python 正常执行，并记录实际执行到的 Tensor 操作。**

#### Non-strict tracing

例如：

```python
def f(x):
    y = x + 1
    y = torch.relu(y)
    return y * 2
```

使用 `strict=False` export 时，输入会由 FakeTensor/ProxyTensor 机制跟踪：

+ **FakeTensor** 保存 shape、dtype、stride 和 device 等 metadata，用于推导每个操作的输出信息，但不持有真实 tensor data。
+ **ProxyTensor** 拦截执行到的 Tensor 操作，并将 `aten.add`、`aten.relu` 和 `aten.mul` 等节点记录到 FX Graph。
+ 普通 Python 控制流仍由 CPython 执行，tracer 不需要解释完整的 Python bytecode。

```text
CPython 执行 Python
        ↓
Tensor op 被调用
        ├── FakeTensor：推导输出 metadata
        └── ProxyTensor：记录 FX node
        ↓
FX Graph
```

#### 控制流差异

考虑下面的分支：

```python
def f(x):
    if x.shape[0] > 2:
        return x**2
    return x * 3
```

对于某组示例输入，non-strict tracing 会由 CPython 选择实际执行的分支，然后只记录该分支中的 Tensor 操作。Dynamo 则会分析对应的 Python bytecode、symbolic shape 和分支条件，并判断需要生成哪些 guard 或 constraint，才能保证捕获结果仍然有效。

#### 对比

| | Dynamo tracing (`strict=True`) | Non-strict tracing (`strict=False`) |
| --- | --- | --- |
| Python 执行方式 | Dynamo 对 bytecode 进行 symbolic interpretation | CPython 正常执行函数 |
| Graph 构建方式 | 分析程序语义并提取 Tensor graph | 记录本次执行遇到的 Tensor op |
| Python 控制流 | 分析条件并生成 guard/constraint | 执行具体路径，只记录已执行分支 |
| Python 特性支持 | 受 Dynamo 可分析能力限制 | 可复用 CPython 对普通 Python 的支持 |
| 正确性前提 | 通过 guards 和 constraints 约束 graph 的适用范围 | 依赖被导出程序满足 non-strict tracing 的纯函数假设 |

non-strict tracing 的简洁性也带来了限制：如果程序读取可变的 global state、产生 tracing 无法观察的 side effect，或者后续输入会走不同的 Python 路径，那么记录下来的 graph 可能无法完整表示原程序语义。因此，`strict=False` 更适合 Tensor 计算路径稳定、外部状态可控的程序。

参考：[PyTorch `torch.export` 文档](https://docs.pytorch.org/docs/stable/export.html)。

## Compilations in PyTorch

> [!QUESTION]
>
> + 在 torch.compile 过程中 dynamo bug 多且性能低， PyTorch 社区有没有想过出一个自己的 model DSL 之类的东西来跳过 dynamo?

想过，而且 PyTorch 曾经沿着这条路线实现了 TorchScript。

### TorchScript：受限语言路线

**TorchScript 的核心思路是定义一个静态、可编译的 PyTorch/Python 子集，而不是支持任意 Python 语义。**

```text
TorchScript-compatible Python
        ↓ TorchScript frontend
TorchScript IR
        ↓ compiler / runtime
Executable program
```

这与“为 compiler 设计一个受限 DSL”的思路非常接近。Frontend 只需要理解预先定义的语言子集，因此分析和编译更直接，但用户必须修改不兼容的 Python 代码。

| 路线 | 用户侧 | Compiler 侧 |
| --- | --- | --- |
| 受限语言或 DSL | 需要遵守静态子集，部分模型需要重写 | 语义边界清晰，frontend 相对简单 |
| 普通 Python | 保留熟悉的编程体验和动态能力 | 必须处理动态语义、控制流、guards 和 fallback |

TorchScript 选择了前一种路线，TorchDynamo 选择了后一种路线

> PyTorch 当前已经将 TorchScript 视为 deprecated，并将新的模型捕获与部署工作转向 `torch.export`。

### torch.export：中间路线

`torch.export` 没有要求用户改写成一套完整 DSL，而是继续接收普通 PyTorch code，同时要求被导出的程序满足更明确的可捕获约束。

其中 `torch.export(..., strict=False)` 代表一种更接近中间路线的选择：它不尝试通过 bytecode analysis 理解所有 Python 语义，而是由 CPython 执行程序，再通过 FakeTensor/ProxyTensor 机制记录 Tensor 操作。具体 tracing 过程见上一节。

这降低了 graph capture frontend 的复杂度，但没有消除约束：程序仍需避免 tracing 无法观察的 side effect、不可控的 global state 和依赖未捕获 Python 路径的行为。对于不满足这些条件的程序，export 应当失败或要求用户修改模型，而不是依赖任意 Python fallback。

因此三种设计可以概括为：

| 方案 | Python 支持范围 | 主要代价 |
| --- | --- | --- |
| TorchScript | 明确定义的静态子集 | 用户需要适配或重写代码 |
| TorchDynamo | 尽量支持普通 Python | bytecode analysis、guards 和 graph breaks 更复杂 |
| Non-strict export | 普通 Python 执行，但要求程序满足 export contract | 支持范围取决于 tracing purity 和可导出约束 |

### torch.compile().aot_compile()

**`torch.compile().aot_compile()` 将普通 `torch.compile` 在第一次调用时完成的编译提前到部署之前，并将结果保存为可序列化的 compiled callable。**

普通 `torch.compile` 使用 **lazy compilation**：

+ `torch.compile(model)` 主要创建 compiled wrapper
+ Dynamo tracing、Inductor lowering、backend codegen、kernel compilation 和 autotuning 在第一次实际调用时触发，后续调用复用缓存；
+ 如果输入不满足已有 guards，则可能重新捕获或编译。

PyTorch 2.13 引入的 `aot_compile()` 会在调用该 API 时完成上述工作。它接收由 `torch.compile(..., fullgraph=True)` 创建的 callable 和一组 example inputs，输出可执行并可序列化的 compiled function：

```text
Python callable + example inputs
        ↓ Dynamo full-graph capture
FX Graph
        ↓ Inductor lowering + backend codegen
Kernel compilation + autotuning
        ↓
Serializable compiled callable
```

最小的编译、保存与加载流程为：

```python
compiled_fn = torch.compile(
    model,
    fullgraph=True,
).forward.aot_compile(
    ((example_input,), {})
)

compiled_fn.save_compiled_function("model.pt")
```

部署进程仍然运行 Python，但加载 artifact 后不需要重新执行 Dynamo、Inductor codegen、kernel compilation 和 autotuning：

```python
with open("model.pt", "rb") as f:
    fn = torch.compiler.load_compiled_function(f)

output = fn(model, input)
```

两种 `torch.compile` 模式的核心差异是编译时机和 runtime specialization 能力：

| | `torch.compile` | `torch.compile().aot_compile()` |
| --- | --- | --- |
| 编译时机 | 第一次实际执行时 | 部署之前 |
| 编译模式 | JIT / lazy | AOT |
| 第一次请求 | 可能包含 compilation cold start | 直接加载并执行 compiled code |
| 编译结果 | Runtime cache | 可显式序列化的 artifact |
| Graph break | 可以切回 Python eager execution | 不支持，要求 `fullgraph=True` |
| 输入变化 | Guard failure 后可以 specialization 或 recompile | 受预编译 artifact 的 guards 和 shape assumptions 约束 |
| Python runtime | 需要 | 仍然需要 |
| Backend | 可以使用 Inductor | 同样可以使用 Inductor |

普通 `torch.compile` 可以根据实际 workload 生成多组 specialization。例如 shape 变化导致 guard failure 时，Dynamo 可以编译新的 graph，或在检测到 shape dynamism 后尝试生成更动态的 kernel。`aot_compile()` 的目标则是在 deployment 前结束编译，因此 example inputs 会参与确定 artifact 对 shape、dtype、device 和其他 guards 的适用范围；部署时不能依赖 compiler 为不兼容输入自动生成新版本。

> [!NOTE]
> 对于相同的 Inductor backend，两种模式最终生成的 optimized kernels 可以非常接近。`aot_compile()` 的主要价值是消除 production compilation cold start，以及支持 artifact 保存、跨进程加载和 cross compilation，而不是提高 steady-state kernel performance。

> [!WARNING]
> `aot_compile()` 不支持 graph break。待编译函数必须能够在 `fullgraph=True` 下形成完整 graph；如果输入超出 artifact 的 guard 或 shape constraints，需要重新构建兼容的 artifact。

### Inference Deployment：torch.export + AOTInductor

对于模型结构相对固定、可以接受 export constraints、且不需要 arbitrary Python fallback 的 inference deployment，可以使用 `torch.export` 和 AOTInductor：

```text
PyTorch nn.Module
       ↓ torch.export(..., strict=False)
ExportedProgram
       ↓ AOTInductor
Compiled package (`.pt2`，包含 shared library 等 artifact)
       ↓ C++ / non-Python runtime
Inference execution
```

AOTInductor 接收 `ExportedProgram`，通过 `torch._inductor.aoti_compile_and_package()` ahead-of-time 编译并生成可部署的 `.pt2` package。线上 runtime 直接加载编译产物，不需要在请求期间运行 Python、TorchDynamo 或即时 graph capture。

| | `torch.compile` | `torch.compile().aot_compile()` | `torch.export(strict=False)` + AOTInductor |
| --- | --- | --- | --- |
| 主要定位 | Python runtime JIT | Python runtime AOT | C++ / non-Python AOT deployment |
| Graph capture | Dynamo，可包含 graph break | Dynamo，要求 full graph | Non-strict ProxyTensor tracing |
| 编译时机 | 第一次实际执行时 | 部署之前 | 部署之前 |
| 主要产物 | Runtime compiled graph/cache | Serialized compiled callable | `.pt2` package / native artifact |
| Graph transformation | 主要围绕 `torch.compile` pipeline | 不以暴露稳定 exported IR 为目标 | 可在 `ExportedProgram` / ATen Graph 上变换 |
| Runtime specialization | 可以 guard、specialization 和 recompile | 受 artifact 的预编译约束限制 | 受 export constraints 限制 |
| Python runtime | 需要 | 需要 | C++ deployment 不需要，也可以由 Python loader 使用 |
| 适用场景 | 动态 workload、开发和 training | Python service 消除 compile cold start | 稳定 IR、graph pass 与 non-Python deployment |

`torch.compile().aot_compile()` 与 AOTInductor 都可能使用 TorchInductor，但两者不是同一个 deployment abstraction。前者沿用 `torch.compile` 和 Dynamo semantics，产出供 Python runtime 加载的 compiled callable；后者以 `ExportedProgram` 为稳定输入边界，适合在编译前执行 graph transformation，并生成面向 C++ / non-Python runtime 的 package。

> 对部署型 inference 而言，`torch.export(strict=False)` 加 AOTInductor 更接近传统的 ahead-of-time compiler pipeline；它通过收紧输入程序的约束，换取更简单的 capture 路径和不依赖 Dynamo 的线上 runtime。

参考：[TorchScript 文档](https://docs.pytorch.org/docs/stable/jit.html)、[`torch.export` 文档](https://docs.pytorch.org/docs/stable/export.html) 和 [AOTInductor 文档](https://docs.pytorch.org/docs/stable/torch.compiler_aot_inductor.html)。

### Helion：Kernel DSL

Helion 于 2025 年以 Beta 形式发布，之后成为 PyTorch Foundation hosted project。它是一个 PyTorch-native、Python-embedded 的 kernel DSL，官方将其编程模型概括为 **“PyTorch with Tiles”**。

```python
@helion.kernel()
def matmul(x, y):
    m, k = x.size()
    _, n = y.size()
    out = torch.empty([m, n], device=x.device, dtype=x.dtype)

    for tile_m, tile_n in hl.tile([m, n]):
        acc = hl.zeros([tile_m, tile_n], dtype=torch.float32)
        for tile_k in hl.tile(k):
            acc = torch.addmm(acc, x[tile_m, tile_k], y[tile_k, tile_n])
        out[tile_m, tile_n] = acc

    return out
```

Helion 使用普通 PyTorch 代码完成 host-side setup；最外层 `hl.tile` 循环内的代码表示 device computation，并通过 TorchInductor lower 到 Triton。整体路径为：

```text
Helion kernel
      ↓ Helion compiler + TorchInductor lowering
Triton kernel
      ↓ Triton compiler
GPU code
```

需要注意，Helion 是 **Kernel DSL**，不是 **Model DSL**：

| | Model DSL / graph capture frontend | Helion Kernel DSL |
| --- | --- | --- |
| 处理范围 | 完整模型及算子之间的数据依赖 | 单个或少量 GPU kernel |
| 主要输入 | 模型程序或模型计算图 | 显式编写的 tile-level kernel function |
| 主要输出 | 模型级计算图 | Triton kernel |
| 是否替代 Dynamo | 可以改变模型级 graph capture 路径 | 不能替代模型级 graph capture |

因此，Helion 解决的是“如何更容易地编写高性能 kernel”，而不是“如何把任意 PyTorch model 转换成 graph”。在完整编译栈中，模型仍需先经过 Dynamo、`torch.export` 或其他 frontend 完成 graph capture，之后其中适合自定义实现的 kernel 才可能使用 Helion 表达。

参考：[Helion 官方介绍](https://pytorch.org/blog/helion/)、[Helion GitHub](https://github.com/pytorch/helion) 和 [PyTorch Foundation hosted project 公告](https://pytorch.org/blog/pytorch-foundation-welcomes-helion-as-a-foundation-hosted-project-to-standardize-open-portable-and-accessible-ai-kernel-authoring/)。

### 总结

PyTorch 最大的历史资产就是一个极其灵活的 Python eager framework，所以 PyTorch 2.x 面临的是：

```text
不能破坏已有 eager semantics
        +
又希望获得 compiler graph
```

于是才出现 Dynamo。

Dynamo 并不是 ML compiler 架构中不可避免的一层。它的复杂性主要来自 PyTorch 对既有 eager semantics 和动态 Python program 的兼容要求，而不是 Tensor Graph compilation 本身的必然要求。

从 PyTorch 2.13 的 compilation 与 deployment API 来看，可以将主要路线概括为：

```ascii
       PyTorch model
                         /           \
                        /             \
                compile world       export world
                     │                   │
                     ▼                   ▼
                  Dynamo        non-strict tracing
                     │             (default)
                     │                   │
                     ▼                   ▼
                  FX Graph       ExportedProgram
                     │                   │
             ┌───────┴──────┐            │
             │              │            │
             ▼              ▼            ▼
       torch.compile   .aot_compile   AOTInductor
             │              │            │
             ▼              ▼            ▼
          runtime       Python AOT    native AOT
```

+ `compile world` 保留 `torch.compile` 的 Dynamo semantics。普通 `torch.compile` 面向 runtime JIT，可以通过 guards、graph breaks 和 recompilation 适应 workload；`.aot_compile()` 使用同一类 frontend semantics，但要求 full graph，并将编译提前到 deployment 之前，产出由 Python runtime 加载的 serialized callable。

+ `export world` 以 `ExportedProgram` 作为稳定边界。Non-strict tracing 不需要解释完整 Python bytecode，而是要求程序满足更严格的 export contract；AOTInductor 随后将 graph 编译为 `.pt2` / native artifact，适合 graph transformation 与 C++ / non-Python deployment。

> [!NOTE]
> 图中 `non-strict tracing (default)` 表示 PyTorch 2.13 的默认 export 路径。显式使用 `torch.export(..., strict=True)` 时，graph capture 仍然会使用 Dynamo。`native AOT` 表示 artifact 可以脱离原始 Python graph capture 过程部署

三条路线最终都可能使用 TorchInductor，因此 steady-state kernel 不一定有本质差异。

真正的选择边界是 frontend contract、编译时机和 deployment runtime：

+ 需要 runtime flexibility 时使用 `torch.compile`
+ Python service 只需要消除 compilation cold start 时使用 `.aot_compile()`
+ 需要稳定 exported IR、编译前 graph pass 或 non-Python deployment 时使用 `torch.export + AOTInductor`

## Lazy Execution

### 为什么 Lazy Execution 适合 ML Compiler

**Lazy execution 让 Tensor API 在真正执行计算之前先构造 computation graph，为跨算子优化和 code generation 提供了天然的 graph capture boundary。**

在 eager-first framework 中，Tensor operation 通常会立即 dispatch 并执行；如果之后才尝试融合多个操作，完整的计算关系已经丢失。因此 PyTorch 需要 Dynamo 在 eager execution 发生前拦截 Python program 并提取 FX Graph。

Lazy-first framework 则通常采用下面的路径：

```text
Python
  ↓ overloaded Tensor / Array API
Computation Graph
  ↓ realization
Scheduling / optimization / lowering
  ↓
Execution
```

| | Eager-first API | Lazy-first API |
| --- | --- | --- |
| Tensor operation | 默认立即执行 | 默认构造或扩展 computation graph |
| Graph 来源 | 需要额外 tracing/capture frontend | Tensor API 执行过程自然产生 |
| 跨算子优化机会 | 必须在执行前截获程序 | 可以在 realization 前观察多个操作 |
| Python semantics | Frontend 可能需要分析和约束 | 通常由 CPython 先执行，只保留实际构造的 Tensor graph |

但需要严格区分：

> **Lazy execution 解决“能否先获得 computation graph”；graph compilation 解决“是否进一步优化、生成代码并缓存这个 graph”。Lazy execution 不等于自动启用 function-level compilation。**

普通 Python control flow 仍然由 CPython 决定。例如条件是 Python `bool` 时，最终 graph 通常只包含实际执行分支中的 Tensor operation。Lazy Tensor API 并没有理解完整的 Python `if`，也不会自动为未执行分支生成 graph、guard 或 constraint。这种限制正是其 frontend 相对简单的原因之一。

### tinygrad

tinygrad 将 Tensor API 设计成一个 lazy、Python-embedded Tensor DSL。官方开发文档将 `Tensor` 描述为构造 `UOp` graph 的语法糖。

```python
z = (x + y).relu() * 2
```

执行这段 Python 时，`Tensor.__add__()`、`relu()` 和乘法操作主要是在扩展 UOp graph，概念上可以表示为：

```text
MUL(
    RELU(
        ADD(x, y)
    ),
    2
)
```

这些操作默认是 lazy 的，直到调用 `.realize()` 或 `.numpy()` 才触发实际计算。当前 tinygrad 实现中的主要处理路径为：

```text
Tensor / UOp Graph
      ↓ Scheduler
LINEAR UOp + scheduled CALL work units
      ↓ AST lowering
Backend-specific PROGRAM
      ↓ Renderer / Compiler
CUDA / Metal / LLVM / other backend
```

Scheduler 会把 UOp dependency graph 组织成有序的 `CALL` work units。每个 work unit 可能表示 kernel、copy、view 或其他运行时工作；kernel 对应的 AST 会继续 lower、render 并编译为目标 backend 可执行的 program。

tinygrad 从一开始就采用 lazy-first Tensor API，不需要兼容“Tensor operation 默认立即执行”的既有 eager programming model。因此它不需要 Dynamo 从 eager Python 中恢复 Tensor graph：执行 tinygrad Tensor API 本身已经在构造 UOp graph。相应地，tinygrad compiler 只处理实际构造出的 Tensor computation，不负责理解任意 Python semantics。

#### TinyJit

TinyJit 也不等价于 Dynamo。Dynamo 在 Tensor operation 执行前分析 Python program 并构建 graph；TinyJit 则在 Python 和 tinygrad compiler 已经生成 scheduled work 后进行 capture/replay：

+ 第一次调用正常执行 Python function。
+ 第二次调用继续执行 Python，同时捕获生成的 scheduled work。
+ 后续兼容调用跳过 Python function，直接 replay 捕获的 `LINEAR` work。

因此，影响 kernel 的普通 Python value 可能在 capture 时被冻结。TinyJit 的目标是减少重复执行 Python frontend 和 scheduling 的开销，而不是为任意 Python control flow 建立 symbolic semantics。

参考：[tinygrad Developer 文档](https://docs.tinygrad.org/developer/developer/)、[tinygrad Quickstart](https://docs.tinygrad.org/quickstart/) 和 [TinyJit 示例说明](https://github.com/tinygrad/tinygrad/blob/master/docs/mnist.md)。

### llama.cpp

**llama.cpp 底层的 ggml 使用 lazy graph construction，并利用完整 computation graph 进行 backend scheduling 和 ahead-of-execution memory planning。**

调用 `ggml_add()`、`ggml_mul_mat()` 等 Tensor operation 时，ggml 主要创建输出 tensor metadata，并通过 `src[]` 记录输入依赖，不立即执行对应 kernel。`ggml_build_forward_expand()` 从输出 tensor 展开依赖并形成 `ggml_cgraph`，实际计算由 backend graph compute 显式触发。

```text
ggml Tensor Operations
        ↓ build dependency graph
ggml_cgraph
        ↓ backend split + memory planning
Allocated Execution Graph
        ↓ graph compute
Backend Kernels
```

因此 llama.cpp 不需要从 eager C++ program 中恢复 Tensor graph。模型的 C++ builder 本身就在调用 ggml Tensor API 显式构图，这与 tinygrad 通过 Python Tensor API 构造 UOp graph 的基本思路相似。区别在于，llama.cpp 是针对已知 model architecture 的 inference runtime，而不是面向用户程序的通用 Python Tensor framework。

#### Graph Compilation 的边界

llama.cpp 对 graph 进行了多种执行前处理，但这些处理不等价于 XLA 或 TorchInductor 风格的统一全图 code generation：

| 处理层次 | llama.cpp / ggml 的行为 | 定位 |
| --- | --- | --- |
| Graph construction | 将 ggml Tensor dependency 展开为 `ggml_cgraph` | Lazy graph capture |
| Backend scheduling | 将 graph split 并分配给 CPU、CUDA、Metal 等 backend | Execution planning |
| Memory planning | 根据 tensor lifetime 规划 buffer 和 offset | Static memory planning |
| Graph optimization | 部分 backend 会 reorder graph 或识别可 fusion 的 operation | Backend-specific optimization |
| Kernel execution | 根据 operation、dtype、shape 和 hardware dispatch 已有 kernel | Kernel selection / dispatch |
| Executable graph capture | CUDA backend 可 capture 并 replay CUDA Graph | Backend command-graph replay |

ggml 定义了 `graph_plan_create()`、`graph_plan_update()` 和 `graph_plan_compute()` 接口，但当前 backend interface 将 graph plan 标记为尚未在通用路径中使用。CPU、CUDA 等常规路径仍主要遍历 graph 并 dispatch backend kernel；CUDA Graph capture 可以缓存 kernel launch sequence，但不会将整张 Tensor graph 重新生成一个 fused CUDA kernel。

因此，从宽泛定义看，llama.cpp 包含有限的 graph optimization 和 backend command-graph compilation；从 ML compiler 的严格定义看，它没有统一的 Tensor IR lowering、跨图 kernel generation 和 target-code emission pipeline。将其描述为 **lazy graph executor with static memory planning** 更准确。

#### AOT Memory Planning

Lazy graph 的一个重要作用是让 ggml 在执行前看到所有 intermediate tensor 及其依赖关系。`ggml_gallocr` 会统计 tensor 的 consumer 和 view，在最后一个 consumer 之后释放对应逻辑区间，并将该区间复用于后续生命周期不重叠的 tensor。最终 allocation plan 会记录每个 tensor 所属的 backend buffer、offset 和最大容量。

初始化 `llama_context` 时，`llama_context::sched_reserve()` 会构造用于估算的 prompt-processing graph 和 token-generation graph，并使用较大的 graph 预留 compute buffers。源码将其称为 `worst-case graph`，目的是避免 inference 期间发生 `ggml-alloc` reallocation。

在后续执行中存在两种情况：

+ 如果 batch layout、token 数量、sequence 数量、output 数量和其他 graph parameters 兼容，`llm_graph_result::can_reuse()` 允许直接复用上一张 graph，只更新 input tensor 后再次执行。
+ 如果 graph 需要重新构建，`ggml_backend_sched_alloc_graph()` 会将新 tensor metadata 绑定到已经 reserve 的 buffer offset；只要新的内存需求未超过预留容量，就不需要重新申请 compute buffer。

这是一种 ahead-of-execution memory reservation，也可以在限定语境下称为 AOT memory allocation。它发生在 runtime 初始化阶段，而不是离线 compiler 生成部署 artifact 时。

> [!NOTE]
> 这里的 runtime zero allocation 应限定为：对于预留范围内且 topology 兼容的 steady-state inference，activation tensor storage 通常不发生新的 backend compute-buffer allocation 或 reallocation。它不保证整个 `llama_decode()` 没有动态分配；batch preparation、output buffer 扩容、CPU workspace、backend command resource、KV cache 更新和 graph topology 变化仍可能触发 host 或 device allocation。

以上实现细节基于 llama.cpp `d2f83055`。参考：[ggml graph overview](https://github.com/ggml-org/llama.cpp/blob/d2f83055d6e3b379b5d34c4837122a918cf402c2/ggml/include/ggml.h)、[graph allocator API](https://github.com/ggml-org/llama.cpp/blob/d2f83055d6e3b379b5d34c4837122a918cf402c2/ggml/include/ggml-alloc.h)、[llama.cpp graph reserve 与 reuse](https://github.com/ggml-org/llama.cpp/blob/d2f83055d6e3b379b5d34c4837122a918cf402c2/src/llama-context.cpp) 和 [CUDA Graph capture](https://github.com/ggml-org/llama.cpp/blob/d2f83055d6e3b379b5d34c4837122a918cf402c2/ggml/src/ggml-cuda/ggml-cuda.cu)。

### MLX

MLX 同样默认使用 lazy evaluation。Array operation 不会立即计算，而是动态记录 compute graph；显式调用 `mx.eval()` 时才 materialize 结果。打印 array、转换为 NumPy、保存数据、读取 scalar `.item()` 或在 Python control flow 中使用 scalar array，也会隐式触发 evaluation。

普通 MLX 调用的重点是动态构图和延迟执行，并不自动启用 `mx.compile()` 所提供的 function-level graph compilation：

| | 默认 Lazy Evaluation | `mx.compile()` |
| --- | --- | --- |
| Graph 构建 | 每次调用动态记录 compute graph | 首次调用使用 placeholder inputs trace function |
| 执行方式 | `mx.eval()` 或隐式 materialization 触发执行 | 优化并编译 graph，后续调用复用 cache |
| 优化范围 | 为 graph transformation 和运行时调度提供基础 | 合并公共计算，并 fusion 部分兼容操作 |
| Specialization | 不涉及 compiled-function cache | shape、dtype 或输入数量变化可能触发 recompilation |

`mx.compile()` 是显式 function transformation。第一次调用会构图、优化、生成并编译代码，之后兼容输入会复用缓存结果。`shapeless=True` 可以避免仅因输入 shape 变化而重新编译，但它不适用于依赖静态 shape 构造计算的函数，也不代表支持任意 dynamic shape semantics。

MLX 说明了 lazy execution 与 graph compilation 的关系：lazy Tensor/Array API 可以天然提供 computation graph，但 framework 仍然可以把普通 graph execution 与经过优化、fusion 和 cache 的 compiled execution 设计成两个独立模式。

参考：[MLX Lazy Evaluation](https://ml-explore.github.io/mlx/build/html/usage/lazy_evaluation.html) 和 [MLX Compilation](https://ml-explore.github.io/mlx/build/html/usage/compile.html)。
