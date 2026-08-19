---
title: "Production Ready TileLang Ops Framework"
tags:
  - TileLang
date: 2026-08-17
showtoc: true
weight: 10
---

在生产环境下使用 TileLang，需要考虑几个问题：

1. 算子缓存
2. 与 torch.compile 兼容

## 算子缓存

### 算子定义

在了解算子缓存之前，我们需要了解一个 GPU 算子应该如何定义，通常由三部分组成：

| 参数类型                                           | RMSNorm 中的实例       | 作用                   |
| ---------------------------------------------- | ------------------ | -------------------- |
| **问题规格（Workload / specialization parameters）** | `M, N, eps, dtype` | 确定一类具体计算问题           |
| **调度参数（Schedule / config / meta-parameters）**  | `block_m, threads` | 确定该 workload 的一种实现方案 |
| **运行时参数（Runtime arguments / operands）**        | `x, weight`        | 每次调用时传入的实际数据         |

在代码里对应得非常直接：

```python
_rms_norm_kernel(M, N, eps, dtype)   # workload parameters

    def _func(block_m, threads):     # schedule/meta-parameters

        def main(x, weight, y):      # runtime arguments
```

这三类参数不是一次性传给同一个函数，而是在 kernel 从定义到执行的过程中逐层绑定：

```python
jit_impl = _rms_norm_kernel(M, N, eps, dtype)
jit_kernel = jit_impl(block_m=4, threads=128)
y = jit_kernel(x, weight)
```

- 第一步绑定 workload 参数，得到 TileLang `JITImpl`
  - 描述一个确定的计算问题，例如处理形状为 `(M, N)`、数据类型为 `dtype` 的 RMSNorm，但尚未确定具体的调度方案。
- 第二步绑定 schedule 参数，得到可以执行的 `JITKernel`
  - `block_m/threads` 可以来自默认配置、手动配置或 autotune
  - 不同 schedule 对应同一个 workload 的不同实现版本
- 最后传入 `x/weight` 等 runtime arguments，启动已经选定的 `JITKernel`
  - 运行数据只参与本次调用，不改变前面已经确定的 workload 和 schedule

### 算子调用流程

一次真实的算子调用从业务 `Op` 开始，依次确定 workload、选择 schedule、取得编译结果，最后才把 Tensor 作为 runtime arguments 启动 kernel

首次遇到一个 workload 时，完整路径如下：

```ascii
forward(x, weight)
        |
        v
从 x.shape 得到 M
        |
        v  第三层：按 workload dispatch, 同一个 Workload 调用同一种 Kernel
_get_kernel(M)
        |
        v  第二层：取得或创建 JITImpl，同一种 Kernel 只调用同一个实例
_rms_norm_kernel(M, N, eps, dtype)
        |
        v  第一层：按 schedule 取得或编译 JITKernel，同一个实例反复调用时只编译一次
JITImpl(block_m, threads)
        |
        v
JITKernel(x, weight)
```

在当前延迟初始化的设计中，模块导入只会定义带有 `lru_cache` 的 `_rms_norm_kernel`，不会立即执行函数体中的 `@tilelang.jit`，也不会编译 CUDA kernel。构造 `RMSNormFwdOp` 时会保存 `N/eps/dtype` 等固定配置并创建空的 workload cache，真正的 kernel 构造发生在首次收到输入之后。

第一次收到某个 `M` 时，`_get_kernel(M)` 发生第三层 cache miss，因此创建 `RMSNormKernel`。其构造过程调用 `_rms_norm_kernel(M, N, eps, dtype)`；如果第二层也 miss，Python 才会创建闭包并执行 `@tilelang.jit`，得到绑定当前 workload 的 `JITImpl`。随后确定 `block_m/threads`，调用 `JITImpl` 取得相应的 `JITKernel`。只有当第一层的进程内缓存和持久化缓存都未命中时，TileLang 才需要执行完整的 lowering 和设备代码编译。

后续调用会根据命中的缓存层级跳过不同工作：

- 同一个 `Op` 再次收到相同 `M` 时，第三层直接返回已有的 `RMSNormKernel`，不会重新构造对象或查询第二层；执行时只需用已选 schedule 取得第一层中的 `JITKernel`，然后传入新的 `x/weight` 启动 kernel。
- 另一个 `Op` 首次收到相同完整 workload 时，它自己的第三层仍然 miss，但模块级第二层可以返回共享的 `JITImpl`；相同 schedule 还可以继续命中第一层编译结果。
- 同一个 `Op` 收到新的 `M` 时，会创建新的 workload 对象。第二层和第一层是否 miss，取决于完整 workload 和 schedule 是否已经由其他调用建立对应缓存项。

如果启用 autotune，schedule 选择会在正常执行前依次运行候选 config。每个候选 `block_m/threads` 都可能进入第一层并触发一次新 variant 编译和 benchmark，最终选中的 config 保存在 `RMSNormKernel` 中，供后续调用复用。

### 第一层：TileLang 编译结果缓存

> [!INFO] Summary
> 同一个 kernel variant 被多次执行时，复用 TileLang 已生成的 CUDA 代码和 `JITKernel`，避免重复编译。

最底层缓存 TileLang 的编译结果，例如生成的 CUDA 代码、编译后的设备代码、launcher 和 `JITKernel`。

一个编译结果由三部分共同确定：

- workload：`M, N, eps, dtype`；
- schedule：`block_m, threads`；
- 编译环境：GPU target、TileLang/编译器版本和编译选项。

因此，同一个 workload 使用不同的 `block_m/threads`，会得到不同的编译结果；相同配置在不同 GPU 架构上也不能直接视为同一个结果。

这一层用于避免重复 lowering、生成 CUDA 代码和编译。

自回归解码会多次执行相同 workload。第一次取得编译结果后，后续 token 可以直接复用已经加载的 `JITKernel`。如果当前 TileLang 版本启用了持久化编译缓存，编译产物还可以写入磁盘，供重新创建 JIT wrapper 或下次启动进程时复用。

### 第二层：TileLang `JITImpl` 缓存

> [!INFO] Summary
> 不同 `Op` 实例遇到相同 workload 时，共享同一个 TileLang `JITImpl`，避免重复创建 JIT wrapper。

第二层位于 `_rms_norm_kernel`：

```python
@functools.lru_cache(maxsize=32)
def _rms_norm_kernel(M, N, eps, dtype):
    @tilelang.jit(out_idx=[2])
    def _func(block_m, threads):
        ...
    return _func
```

它缓存的是：

```text
(M, N, eps, dtype) -> JITImpl
```

这个 `JITImpl` 已经通过闭包绑定 workload，但还没有绑定 `block_m/threads`。调用 `JITImpl(block_m=..., threads=...)` 后，才会进入第一层取得对应的编译结果。

如果没有这一层，相同 workload 每次都会重新创建 Python 闭包、执行 `@tilelang.jit` 并生成新的 JIT wrapper。第一层仍可能避免重新编译 CUDA，但这些 Python 和 JIT 对象的构造会重复发生。

`maxsize=32` 表示最多缓存 32 个 workload 对应的 `JITImpl`。

这一层通常定义在模块级，因此可以**被同一 Python 进程中的多个 `Op` 实例共享**。Transformer 的每一层都会实例化自己的 RMSNorm；如果这些 RMSNorm 使用相同的 `M/N/eps/dtype`，没有这一层时会创建多个等价的 `JITImpl`，有这一层后则会取得同一个对象。

因此，`lru_cache` 实现的是**受容量限制的进程内单例**：相同 key 在缓存项仍然存在时返回同一个 `JITImpl`，但 LRU 淘汰或进程重启后仍会重新创建。

### 第三层：workload 缓存

> [!INFO] Summary
> 同一个 `Op` 实例遇到不同 workload 时，分别 dispatch 到对应的 `RMSNormKernel`，并缓存每种 workload。

第三层位于业务 `Op`：

```python
def _get_kernel(self, m):
    if m not in self._kernel_cache:
        self._kernel_cache[m] = RMSNormKernel(
            m, self.N, self.eps, self.dtype,
        )
    return self._kernel_cache[m]
```

它缓存的是：

```text
M -> RMSNormKernel
```

`RMSNormKernel` 代表一个已经确定的 workload，内部保存 `M/N/eps/dtype`、选中的 `block_m/threads`，以及第二层返回的 `JITImpl`。

当前缓存只使用 `M` 作为 key，是因为 `N/eps/dtype` 已经固定在当前 `Op` 实例中。例如，输入 `(2, 3, N)` 和 `(6, N)` flatten 后的 `M` 都是 6，可以使用同一个 `RMSNormKernel`。

同一个 `Op` 在 prefill 和 decode 阶段可能遇到不同 workload。假设 batch size 为 1、prefill sequence length 为 128，那么输入 flatten 后，prefill 的 `M=128`，decode 的 `M=1`。第三层会分别缓存这两个 workload：

```python
self._kernel_cache = {
    128: RMSNormKernel(M=128, ...),  # prefill
    1: RMSNormKernel(M=1, ...),      # decode
}
```

这一层避免为相同 workload 重复创建 `RMSNormKernel`、选择配置和查询第二层缓存。它本身不负责缓存 CUDA 代码。

### 三层缓存的关系

| 层级 | 共享范围 | 缓存内容 | 主要作用 |
| --- | --- | --- | --- |
| 第一层 | TileLang 编译缓存 | CUDA 代码、设备代码和 `JITKernel` | 避免重复编译 |
| 第二层 | 当前 Python 进程 | workload 对应的 TileLang `JITImpl` | 让多个 `Op` 共享 JIT wrapper |
| 第三层 | 每个 `Op` 实例内部 | 不同 workload 对应的 `RMSNormKernel` | workload dispatch 和配置选择 |

三层缓存虽然都与 workload 有关，但缓存的不是同一个对象：

- 第一层缓存可以执行的编译结果；
- 第二层缓存生成编译结果的 `JITImpl`；
- 第三层缓存面向业务调用的 workload 对象。

### Transformer 中的缓存示例

假设模型由三个 `TransformerBlock` 堆叠而成，每个 block 都包含两个 RMSNorm：

```python
class TransformerBlock(nn.Module):
    def __init__(self, config: ModelArgs) -> None:
        super().__init__()
        self.attention = Attention(config)
        self.feed_forward = FeedForward(config)
        self.ffn_norm = RMSNorm(config.dim, config.norm_eps)
        self.attention_norm = RMSNorm(config.dim, config.norm_eps)

    def forward(
        self, x: Tensor, input_pos: Tensor, freqs_cis: Tensor
    ) -> Tensor:
        hidden = x + self.attention(
            self.attention_norm(x), freqs_cis, input_pos
        )
        return hidden + self.feed_forward(self.ffn_norm(hidden))
```

三个 block 一共会创建六个独立的 RMSNorm `Op` 实例。假设它们都使用 `N=4096`、`eps=1e-5` 和 `bfloat16`，prefill 时 `M=128`，decode 时 `M=1`，缓存关系如下：

```ascii
第三层：每个 RMSNorm Op 私有的 workload cache

Block 0: attention_norm {128: Kernel, 1: Kernel}
         ffn_norm       {128: Kernel, 1: Kernel}
Block 1: attention_norm {128: Kernel, 1: Kernel}
         ffn_norm       {128: Kernel, 1: Kernel}
Block 2: attention_norm {128: Kernel, 1: Kernel}
         ffn_norm       {128: Kernel, 1: Kernel}

          6 个 Op，共持有 12 个 RMSNormKernel
                            |
                            v
第二层：当前进程共享的 JITImpl cache

(128, 4096, 1e-5, bfloat16) -> JITImpl P  <- 6 个 prefill Kernel 共享
(  1, 4096, 1e-5, bfloat16) -> JITImpl D  <- 6 个 decode Kernel 共享

                            |
                            v
第一层：TileLang 编译结果 cache

(prefill workload, config P, target) -> CUDA / JITKernel P
(decode workload,  config D, target) -> CUDA / JITKernel D
```

虽然本文按照从底层到上层的顺序编号，但一次实际调用的查找顺序是第三层、第二层、第一层：`Op` 先根据 `M` dispatch 到 `RMSNormKernel`，后者取得共享的 `JITImpl`，最后由 workload、schedule 和 target 定位编译结果。

在这个例子中：

1. 当前实现中第三层不会跨 `Op` 共享。六个 RMSNorm 是六个独立 `Op`，每个 `Op` 都维护自己的 prefill/decode dispatch。
2. 第二层可以共享，因为六个 `Op` 的完整 workload 相同，最终只需要两个 `JITImpl`。各层的 RMSNorm `weight` 虽然不同，但它是 runtime argument，不属于 workload key。
3. 假设每个 workload 只选择一个 schedule，第一层只需要两组编译结果。decode 的 `JITKernel D` 会在所有层和后续 token 中反复复用。

如果各层的 `N/eps/dtype` 不同、autotune 选择了额外 schedule，或者运行 target 不同，第二层和第一层的缓存项数量会相应增加。

运行时的 `x`、`weight` 和 `residual` 不属于这三层缓存。它们的 shape、dtype 和 device 用来选择 workload，实际 tensor 只作为参数传给最终的 `JITKernel`，不应该按 tensor pointer 或内容缓存输出。

## torch.compile 兼容

> [!INFO] Summary
> `torch.compile` 负责捕获 PyTorch tensor graph，TileLang JIT 负责生成和编译单个 GPU kernel。要让两者协同工作，需要用 `custom_op` 明确划分编译边界

### 两个不同的编译域

`torch.compile` 和 `tilelang.jit` 都包含“编译”，但它们处理的对象不同：

| 编译器             | 输入                  | 关注的问题                                               | 输出                        |
| --------------- | ------------------- | --------------------------------------------------- | ------------------------- |
| `torch.compile` | PyTorch `forward()` | tensor 如何流动、shape/dtype、图优化与算子融合                    | FX graph 和 Inductor 生成的代码 |
| TileLang JIT    | 具体的 TileLang kernel | block/thread 布局、shared memory、reduction 和 CUDA 代码生成 | `JITKernel` 和设备代码         |

Dynamo 可以捕获 `reshape`、`contiguous` 等 PyTorch tensor 操作，但不适合进入 TileLang 的 Python 实现继续分析。例如：

```python
self._kernel_cache[m] = RMSNormKernel(...)
kernel = _rms_norm_kernel(M, N, eps, dtype)
jit_kernel = kernel(block_m=block_m, threads=threads)
```

这些代码可能包含 Python 字典修改、对象构造、配置选择、文件缓存和 CUDA 编译，不属于 PyTorch tensor graph。直接让 Dynamo 追踪这些行为，容易产生 graph break，使用 `fullgraph=True` 时则可能直接失败。

### 使用 `custom_op` 建立边界

> [!INFO] Summary
> `custom_op` 将 TileLang 调用注册为 PyTorch 图中的一个原子节点。Dynamo 记录这个节点，但不会进入函数内部分析 JIT、缓存和 CUDA launch。

关键在于区分两种表面相似、实际机制不同的调用：Python 实例方法调用和 PyTorch Dispatcher 算子调用。

#### Python 实例方法是 bound method

普通实例方法天然绑定到一个 Python 对象：

```python
class RMSNormFwdOp:
    def forward(self, x, weight):
        ...

op1.forward(x, weight)
```

Python 实际执行的逻辑近似于：

```python
RMSNormFwdOp.forward(op1, x, weight)
```

`op1.forward` 是 bound method，Python 会自动把 `op1` 作为 `self` 传入。因此 `forward()` 可以直接访问实例状态：

```python
self.N
self.eps
self.dtype
self._kernel_cache
```

#### custom op 是全局 Dispatcher 算子

`torch.library.custom_op` 不使用 bound method 机制。装饰器在模块导入时执行一次，将一个具有全局名称和固定 schema 的算子注册到 PyTorch Dispatcher：

```python
@torch.library.custom_op("tilelang_ops::rms_norm", mutates_args=())
def _rms_norm_wrapped(
    x: torch.Tensor,
    weight: torch.Tensor,
    instance_key: str,
) -> torch.Tensor:
    op = get_instance(instance_key)
    return op._eager_forward(x, weight)
```

可以近似理解为：

```python
def implementation(x, weight, instance_key):
    op = get_instance(instance_key)
    return op._eager_forward(x, weight)

_rms_norm_wrapped = register_global_torch_operator(
    name="tilelang_ops::rms_norm",
    implementation=implementation,
)
```

PyTorch 注册的是一个全局算子，而不是某个 `RMSNormFwdOp` 实例的方法。它的 schema 可以概括为：

```text
tilelang_ops::rms_norm(
    Tensor x,
    Tensor weight,
    str instance_key
) -> Tensor
```

这里的 `mutates_args=()` 表示 custom op 不会原地修改输入。Dynamo 遇到 `_rms_norm_wrapped(...)` 时，只会在 FX graph 中记录一个 `tilelang_ops.rms_norm` 节点，不会进入 `_eager_forward()` 分析 workload dispatch、缓存或 TileLang JIT。

#### 多个实例共享同一个 custom op

假设模型中有两个配置不同的 RMSNorm：

```python
op1 = RMSNormFwdOp(
    hidden_size=2048,
    eps=1e-6,
    dtype=torch.bfloat16,
)

op2 = RMSNormFwdOp(
    hidden_size=4096,
    eps=1e-5,
    dtype=torch.bfloat16,
)
```

`op1.forward` 和 `op2.forward` 分别绑定 `op1` 和 `op2`，但它们最终调用的是同一个全局 custom op：

```python
op1.forward(x1, weight1)  # 调用 tilelang_ops::rms_norm
op2.forward(x2, weight2)  # 调用 tilelang_ops::rms_norm
```

全局算子本身没有 `self`，因此不知道当前调用来自哪个实例。`instance_key` 的作用就是在 schema 允许的参数中携带实例身份。

#### 为什么不能直接传入 `self`

理论上可能希望直接调用：

```python
_rms_norm_wrapped(x, weight, self)
```

但 custom op 的参数必须能够用 PyTorch operator schema 表示，例如 `Tensor`、`int`、`float`、`bool`、`str` 及其支持的容器。任意 Python 对象 `RMSNormFwdOp` 无法成为 graph 中的 operator 参数：

```text
Tensor x
Tensor weight
RMSNormFwdOp self  # PyTorch schema 无法表示
```

Dynamo、FakeTensor、Inductor 和模型序列化也无法解释这个 Python 对象。因此需要把 `self` 替换为 schema 支持的标识符：

```python
instance_key: str
```

#### registry 如何找回实例

每个 `RMSNormFwdOp` 在构造时把自己加入 registry，并保存返回的 key：

```python
class RMSNormFwdOp:
    def __init__(self, ...):
        ...
        self._instance_key = register_instance(self)

    def forward(self, x, weight):
        return _rms_norm_wrapped(
            x,
            weight,
            self._instance_key,
        )
```

假设两个实例分别得到：

```text
op1._instance_key = "140001"
op2._instance_key = "140002"
```

registry 保存 `instance_key` 到 Python 实例的映射：

```python
{
    "140001": op1,
    "140002": op2,
}
```

于是一次真实调用可以还原为：

```python
op1.forward(x, weight)
_rms_norm_wrapped(x, weight, "140001")
get_instance("140001")._eager_forward(x, weight)
```

`instance_key` 本质上是一个可以进入 PyTorch graph 的“Python 对象引用替代品”。registry 应使用不会冲突的稳定 key，并通过弱引用或显式注销管理实例生命周期，避免全局注册表阻止对象释放。这个 key 只在当前进程的 registry 中有效；如果需要跨进程加载或导出 graph，就必须重建映射，或者改用显式传递配置的无状态设计。

#### 为什么不为每个实例注册 custom op

另一种设想是为每个实例动态注册不同的算子名称：

```text
tilelang_ops::rms_norm_140001
tilelang_ops::rms_norm_140002
```

这种设计会让每个 `Op` 实例都向全局 Dispatcher 添加一个新算子。算子注册无法随 Python 实例自然撤销，模型层数越多，全局算子越多，同时还会降低 `torch.compile` graph cache 的复用能力并增加生命周期管理难度。

更合理的模型是：

```text
一个全局 custom op
+ 多个 RMSNormFwdOp 实例
+ instance_key 区分调用来自哪个实例
```

也可以把 `hidden_size/eps/dtype` 等简单配置全部作为 custom-op 参数传入，但无法直接传递 `_kernel_cache`、autotune 状态或已经选择的 config。registry 方案保留了清晰的所有权：调用者持有 `Op`，`Op` 持有自己的 kernel cache，全局 custom op 只负责跨越 compile boundary，`instance_key` 负责找回对应的 `Op`。

### 使用 `register_fake` 描述输出

> [!INFO] Summary
> `register_fake` 不执行 TileLang kernel，只根据输入 metadata 构造一个虚拟输出，让 Dynamo 能继续推导后续节点。

RMSNorm 的输出与 `x` 具有相同的 shape、dtype 和 device，因此 fake implementation 不需要访问 registry：

```python
@_rms_norm_wrapped.register_fake
def _(
    x: torch.Tensor,
    weight: torch.Tensor,
    instance_key: str,
) -> torch.Tensor:
    return torch.empty_like(x)
```

编译阶段和真实执行阶段使用同一个 custom-op 节点，但调用不同的 implementation：

| 阶段 | 调用的实现 | 作用 |
| --- | --- | --- |
| Dynamo 捕获和 FakeTensor 推导 | `register_fake` | 根据 `x` 推导输出 metadata，不访问实例，也不执行 GPU 计算 |
| 编译后 graph 的真实执行 | `_rms_norm_wrapped` | 通过 registry 找回实例，查询缓存并启动 TileLang kernel |

如果某个 custom op 的输出 metadata 无法只从 tensor 输入推导，就需要把必要的 shape/config 信息作为 schema 支持的标量参数显式传入。

### custom-op 边界放在哪里

`custom_op` 只能隐藏它包裹的函数体。为了兼容 cold start 和 `fullgraph=True`，workload dispatch、缓存 miss 和 TileLang JIT 都应发生在真实 custom-op implementation 调用的 `_eager_forward()` 中：

```python
class RMSNormFwdOp:
    def forward(self, x, weight):
        return _rms_norm_wrapped(
            x,
            weight,
            self._instance_key,
        )

    def _eager_forward(self, x, weight):
        original_shape = x.shape
        x = x.reshape(-1, self.N)
        kernel = self._get_kernel(x.shape[0])
        y = kernel.forward(x, weight)
        return y.reshape(original_shape)
```

Dynamo 捕获 `forward()` 时只看到全局 custom-op 节点；执行编译后的 graph 时，Dispatcher 才调用 `_rms_norm_wrapped()`，通过 registry 找回实例并进入 `_eager_forward()`。因此，第三层 workload cache、第二层 `JITImpl` cache 和第一层编译结果 cache 都位于 compile boundary 内部。

如果把 custom-op 边界放到更深的 `kernel.forward()`，使 `_get_kernel()` 留在边界外，那么第一次遇到新 workload 时，Dynamo 仍会看到 Python 字典修改和 `RMSNormKernel` 构造。提前 warmup 可以让已知 workload 变成 cache hit，但不能覆盖 cold start 或之后出现的新 shape。

## 与 Triton 的异同

> [!NOTE]
> 缓存和 `torch.compile` 兼容也是生产级 Triton 算子需要处理的问题，但 TileLang 的三层缓存和 `custom_op` 方案不能原样套用。Triton 通常由一个模块级 `JITFunction` 管理编译 variant，而且 PyTorch 可以直接捕获用户定义的 Triton kernel。

### 缓存层级不完全对应

TileLang 和 Triton 都需要缓存已经编译的设备代码，但两者的 Python 对象模型不同，因此上层缓存并不一一对应：

| TileLang 中的层级 | Triton 中的对应机制 | 是否通常需要额外实现 |
| --- | --- | --- |
| 编译结果缓存 | `JITFunction` 的进程内 variant cache 和 Triton 持久化编译缓存 | 不需要 |
| workload 对应的 `JITImpl` 缓存 | 模块级 `@triton.jit` 创建的单个 `JITFunction` | 通常不需要 `lru_cache` |
| `Op` 内部的 workload 缓存 | JIT specialization、`triton.autotune` 或业务 dispatch | 按实现需要 |

#### 编译结果缓存

Triton 会根据 kernel 源码及其依赖、参数签名和 specialization、`tl.constexpr` 参数、编译选项以及 GPU target 等信息定位编译结果。`BLOCK_SIZE`、`num_warps` 和 `num_stages` 等调度参数发生变化时，通常会产生不同的编译 variant。进程内命中时可以直接复用已经加载的 `CompiledKernel`，磁盘缓存命中时则可以避免重新执行完整编译流程。

不过，不能把 Tensor shape 直接等同于 Triton 的编译 key。Triton kernel 无法从 pointer 参数本身取得完整 shape；`M/N` 等尺寸通常需要作为独立参数传入。某个尺寸是否产生新 variant，取决于它是否是 `tl.constexpr`、是否触发运行时 specialization，以及是否改变了编译选项。仅用于计算 grid 或边界 mask 的普通运行时尺寸可以由同一个编译结果处理。

因此，prefill 的 `M=128` 和 decode 的 `M=1` 不一定对应两个 Triton 编译结果。如果 `M` 只决定 launch grid，而 `N`、dtype 和 schedule 相同，两者可以复用同一个 variant；如果 `M` 是编译期常量或导致 autotune 选择不同配置，则会形成不同的 specialization 或调度结果。

#### `JITFunction` 通常不需要外部缓存

典型 Triton kernel 会定义在模块级：

```python
@triton.jit
def rms_norm_kernel(
    x,
    weight,
    y,
    M,
    N: tl.constexpr,
    eps: tl.constexpr,
    BLOCK_SIZE: tl.constexpr,
):
    ...
```

模块导入时，`@triton.jit` 创建一个长期存在的 `JITFunction`。不同 dtype、specialization 和 schedule 对应的编译结果由这个对象在内部管理，因此通常不需要再建立：

```text
(M, N, eps, dtype) -> JITFunction
```

只有在应用主动使用 kernel factory，并为每个 workload 动态创建新的 `@triton.jit` 闭包时，类似第二层的 `lru_cache` 才可能用于避免重复构造 Python 和 JIT 对象。模块级 kernel 通常更直接，也更符合 Triton 的使用方式。

#### autotune 缓存与编译缓存

当一个 workload 有多个候选 schedule 时，`triton.autotune` 会根据 `key` 指定的参数缓存最佳 `triton.Config`：

```python
@triton.autotune(
    configs=[...],
    key=["M", "N"],
)
@triton.jit
def rms_norm_kernel(
    x,
    weight,
    y,
    M,
    N: tl.constexpr,
    BLOCK_SIZE: tl.constexpr,
):
    ...
```

这与编译结果缓存是两个不同层次：autotune 缓存回答“这个 workload 应选择哪个 config”，编译缓存回答“这个 specialization 和 config 是否已经生成设备代码”。当前 Triton API 中，`cache_results=False` 是默认值；只有显式设置 `cache_results=True`，autotune timings 才会持久化到磁盘。

业务层仍然可以维护 `M -> config` 或 `M -> wrapper` 的缓存，但这属于自定义 dispatch，不是调用 Triton kernel 的必要条件。运行时 Tensor pointer 和 Tensor 内容同样不应该作为这些缓存的 key。

### Triton 可以被 `torch.compile` 直接捕获

两个编译域的区分仍然成立：`torch.compile` 处理 PyTorch tensor graph，Triton 编译单个 GPU kernel。与 TileLang 不同的是，PyTorch 从 2.3 起原生支持在编译函数中调用用户定义的 Triton kernel，包括多数 `fullgraph=True`、dynamic shape、JITInductor 和 AOTInductor 场景。

下面是省略 grid 计算和完整参数列表后的调用结构：

```python
@torch.compile(fullgraph=True)
def rms_norm(x, weight):
    y = torch.empty_like(x)
    rms_norm_kernel[grid](x, weight, y, ...)
    return y
```

Dynamo 能识别 `kernel[grid](...)` 形式的 Triton 调用，因此不需要仅为了隐藏 Triton JIT 和 CUDA launch 而添加 `custom_op`。这不意味着 Dynamo 可以自由追踪任意 Python 行为：如果调用前仍包含字典修改、动态对象构造、文件访问或不受支持的配置选择，这些行为依然可能产生 graph break。

### 三种 PyTorch 集成方式

当前用户 Triton kernel 可以按所需的组合能力选择三种集成方式：

| 集成方式 | `torch.compile` 是否进入实现 | 适用场景 |
| --- | --- | --- |
| 直接调用 `kernel[grid](...)` | 是 | 只需要在编译模型中调用 Triton kernel |
| `torch.library.triton_op` + `torch.library.wrap_triton` | 是 | 需要 autograd、CPU fallback、Tensor subclass 或其他 PyTorch 子系统 |
| `torch.library.custom_op` | 否 | 必须隐藏任意 Python 状态、第三方 JIT 或其他不可追踪逻辑 |

PyTorch 2.6 引入的 `torch.library.triton_op` 是面向 Triton 的结构化 custom operator。它和 `custom_op` 一样可以通过 `torch.library` 注册与其他 PyTorch 子系统的交互，但 `torch.compile` 会继续进入其实现并捕获由 `wrap_triton` 包装的 kernel 调用，从而保留图级优化机会。

`torch.library.custom_op` 则会建立真正的不透明边界。它仍然可以包装 Triton，但 Dynamo 只记录一个原子算子节点，不会分析内部实现。这适合保留复杂 Python registry、可变 workload cache 或其他无法被捕获的状态，但需要额外提供 fake implementation 和 autograd 等注册，而且编译器无法跨越该节点观察和优化内部计算。

因此，TileLang 示例中的 registry 和 `instance_key` 方案对 Triton 仍然可用，但只应在确实需要隐藏实例状态时采用。无状态的模块级 Triton kernel 通常可以直接调用；需要完整 PyTorch 算子语义时，优先使用 `triton_op` 和 `wrap_triton`；只有无法消除不可追踪 Python 行为时，才需要退回不透明的 `custom_op` 边界。

### 参考资料

- [Using User-Defined Triton Kernels with `torch.compile`](https://docs.pytorch.org/tutorials/recipes/torch_compile_user_defined_triton_kernel_tutorial.html)
- [Triton `jit` API](https://triton-lang.org/main/python-api/generated/triton.jit.html)
- [Triton `autotune` API](https://triton-lang.org/main/python-api/generated/triton.autotune.html)
- [Triton JIT runtime source](https://raw.githubusercontent.com/triton-lang/triton/main/python/triton/runtime/jit.py)
- [Triton compiler cache source](https://raw.githubusercontent.com/triton-lang/triton/main/python/triton/compiler/compiler.py)
