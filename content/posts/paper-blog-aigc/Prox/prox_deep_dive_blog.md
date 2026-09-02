---
title: "Prox Deep Dive Blog"
tags:
  - TOBETAGGED
date: 2026-09-02
showtoc: true
weight: 10
---

# Prox 完全拆解：先用便宜代理找通道，再用精确计算守住 SwiGLU 的质量

## 先问一个部署问题：70% 的 FFN 通道可以跳过，但谁来决定该跳过谁？

在小 batch、自回归解码中，Transformer 的瓶颈经常不是注意力，而是把权重从 HBM 搬到片上存储。现代 LLM 普遍使用 SwiGLU FFN：up、gate、down 三个矩阵共同占据了 FFN 的参数、内存流量和乘加运算。以 Qwen3-8B 为例，$d_{\rm model}=4096$、$d_{\rm ff}=12288$，每层 FFN 有

$$
3d_{\rm model}d_{\rm ff}
=3\times4096\times12288
\approx 1.51\times10^8
$$

个权重参数。逐 token 解码时，这三次投影都要反复读取，因此激活稀疏是一个高杠杆的优化点。

但“把 70% 的值置零”并不自动等于“质量只损失 70%”。每个中间通道还会经过 down 投影的不同权重行；错误的通道选择可能比同样数量的正确选择昂贵得多。更棘手的是，真正有用的信号恰好是 SwiGLU 的中间状态，而它只有在执行 up 和 gate 之后才知道：如果先做完整计算再选择通道，就已经失去了大部分加速机会。

这篇稿件（Jinyi Liu 等，来源文档未给出正式 venue 和发布日期）围绕一个中心问题展开：**怎样以远低于 dense FFN 的代价，提前得到足够可靠的中间通道掩码？**

一句话概括 Prox：**用输入稀疏加 INT4 权重构造一个只负责“排名”的代理状态，再用原始权重对入选通道做精确计算。**

## SwiGLU 中间状态为什么是最自然的选择信号？

给定输入 $\mathbf{x}\in\mathbb{R}^{d_{\rm model}}$，SwiGLU 的三个中间量为

$$
\mathbf{u}=\mathbf{x}W_{\rm up},\qquad
\mathbf{h}=\operatorname{SiLU}(\mathbf{x}W_{\rm gate}),\qquad
\mathbf{s}=\mathbf{u}\odot\mathbf{h},
$$

最终输出是 $\mathbf{y}=\mathbf{s}W_{\rm down}$。把它改写成按通道求和：

$$
\mathbf{y}=\sum_{i=1}^{d_{\rm ff}}s_iW_{\rm down}[i,:].
$$

因此，$s_i$ 是第 $i$ 行 down 权重的输入系数；$|s_i|$ 小的通道通常对当前 token 的输出贡献较小。更重要的是，同一个索引 $i$ 同时对应 up、gate 的输出通道和 down 的输入通道。一个共享掩码就能同时产生：up/gate 的输出稀疏，以及 down 的输入稀疏。

这比只看单分支信号更完整。CATS 用 dense gate 激活 $\mathbf{h}$ 排名，COUNTDOWN 用 dense up 激活 $\mathbf{u}$ 排名；两者都没有看到逐元素乘积中的另一半信息。TEAL 虽然对输入和中间状态连续做稀疏化，却把近似的 $\mathbf{s}$ 继续送入 down 投影，误差会沿着 FFN 传播。

论文用一个理想化的 oracle-s 实验验证上限：假设 exact $\mathbf{s}$ 可以零成本获得，只保留绝对值最大的通道。在多数测试模型上，即使中间通道稀疏率达到 70%，相对困惑度增幅仍低于 3%。源稿还观察到 $\mathbf{s}$ 呈尖峰、重尾的 Laplace-like 分布。理想 Laplace 变量删去最小幅值的 70% 后，保留下来的平方激活能量约为 87.9%；这解释了为什么大量低幅值通道可以被跳过，但不等于它们在所有输入和所有 down 权重下都完全无害。

![Oracle-s 的质量曲线与中间状态分布](/images/b485967ffa2d597008bafee802e08c74d415c8d33befbd2fd1587b1b02e8a4d8.jpg)

图中真正重要的信息是：中间状态适合做通道级选择，但 exact 状态本身不能在计算前免费得到。

## 关键转折：代理不必还原数值，只需保留排序

要执行稀疏 FFN，运行时真正需要的是二值掩码，而不是完整的 $\mathbf{s}$ 数值。若掩码由 top-magnitude 规则产生，那么代理的要求可以从“数值接近”降级为“相对排序大致一致”。这给了 Prox 一个误差隔离点：代理出错时，主要风险是某个接近阈值的通道被换入或换出；代理值本身不会被继续传播到模型输出。

代理输入采用幅值稀疏。令 $\mathbf{x}_{\rm sp}$ 保留 $\mathbf{x}$ 中幅值最大的坐标，残差为 $\mathbf{r}=\mathbf{x}-\mathbf{x}_{\rm sp}$。在固定保留比例下，这种选择最小化坐标稀疏近似的 $\ell_2$ 残差，因此对任意投影矩阵 $W$ 有

$$
\|\mathbf{x}W-\mathbf{x}_{\rm sp}W\|_2
=\|\mathbf{r}W\|_2
\leq \|\mathbf{r}\|_2\|W\|_2.
$$

这个界说明输入稀疏会扰动投影值，但仍保留所有输出坐标，适合用来估计排序。论文在 Qwen3 上测得，代理和 exact 的 top-ranking 通道重叠率约为 82.04%；一个代表性 token 的重叠率为 82.77%。这不是数值等价的证明，而是“足够稳定地找出大部分重要通道”的经验依据。

![Exact 与 proxy 中间状态的排序重叠](/images/d2da7bd59a461b29cbf9591a5f51b0bde0d28d513870cd1918ba1fff1f95984e.jpg)

## Prox 的两阶段数据流

### Stage 1：低成本代理只负责生成掩码

对第 $\ell$ 层，先用离线校准得到的阈值 $\tau_{x,\ell}^{s_1}$ 选择输入坐标：

$$
[\mathbf{m}_x]_i=\mathbf{1}\left[|x_i|\geq\tau_{x,\ell}^{s_1}\right].
$$

将同一个输入掩码用于 up 和 gate，并把两组代理权重量化为对称 per-row INT4：

$$
\tilde{\mathbf{u}}=\Pi^{\rm in}(\mathbf{x},\widetilde W_{\rm up},\mathbf{m}_x),\qquad
\tilde{\mathbf{h}}=\operatorname{SiLU}\left(\Pi^{\rm in}(\mathbf{x},\widetilde W_{\rm gate},\mathbf{m}_x)\right).
$$

代理中间状态为 $\tilde{\mathbf{s}}=\tilde{\mathbf{u}}\odot\tilde{\mathbf{h}}$。再按第二个离线阈值生成共享通道掩码：

$$
[\mathbf{m}_s]_j=\mathbf{1}\left[|\tilde{s}_j|\geq\tau_{s,\ell}^{s_2}\right].
$$

为什么可以大胆压低代理精度？因为 INT4 只影响“选谁”，不会直接改写 hidden state。另一方面，代理仍然要计算两个分支；如果把它做得太精确，节省的 FFN 计算会被代理开销吃掉。

### Stage 2：原始权重对选中通道做精确值计算

拿到 $\mathbf{m}_s$ 后，Prox 使用原始模型权重，只计算被保留的中间通道：

$$
\begin{aligned}
\mathbf{u}_{\rm sp}&=\Pi^{\rm out}(\mathbf{x},W_{\rm up},\mathbf{m}_s),\\
\mathbf{h}_{\rm sp}&=\operatorname{SiLU}\left(\Pi^{\rm out}(\mathbf{x},W_{\rm gate},\mathbf{m}_s)\right),\\
\mathbf{s}_{\rm sp}&=\mathbf{u}_{\rm sp}\odot\mathbf{h}_{\rm sp},\\
\mathbf{y}&=\Pi^{\rm in}(\mathbf{s}_{\rm sp},W_{\rm down},\mathbf{m}_s).
\end{aligned}
$$

这一步的关键不是“又做了一次计算”，而是把近似误差截断在掩码生成处。A3 消融直接把选中的代理值送进 down 投影；在 Qwen3-8B、70% 稀疏率下，Prox 比 A3 高 24.3 个聚合分数点，说明代理适合做筛选器，不适合替代最终激活值。

![Prox 两阶段框架](/images/6e877ca42488a2cb81adbeaff989c6eb7e19f16a12e29ea54f3c09e8c578218e.jpg)

## 计算预算：Stage 1 和 Stage 2 不能各自追求最稀疏

代理和精确路径共享一个 FFN 预算。把 dense 的三次投影各记为单位成本，令 $\alpha$ 为一次量化代理投影相对 FP16 dense 投影的实测成本，则

$$
C_{\rm Prox}=2\alpha(1-s_1)+3(1-s_2),
$$

对应的有效稀疏率为

$$
e=1-\frac{C_{\rm Prox}}{3}
=s_2-\frac{2\alpha(1-s_1)}{3}.
$$

源稿没有直接把 INT4 的 1/4 bit 宽度当成速度比例，而是在多 GPU、多模型上测量后取 $\alpha=1/3$。把目标有效稀疏率设为 $e=70\%$ 代入：如果以质量经验为依据先把 Stage 2 设为 $s_2=70\%$，公式会要求 Stage 1 达到 100% 稀疏，这会让代理排序失去信息。因此 Prox 把 $s_1$ 限制在 $[0,0.7]$，在上限处重新调高 $s_2$：

$$
s_2=0.7+\frac{2(1/3)(1-0.7)}{3}\approx0.7667.
$$

也就是说，70% 的有效预算对应约 70% 输入稀疏和 76.7% 中间通道稀疏，而不是简单地把所有投影都删掉 70%。不同目标点动态分配 $s_1,s_2$，正是 A2 消融优于固定 $s_1=0.8$ 的原因。

## 从公式到 GPU：稀疏率只有能转成少读权重才算加速

Stage 1 使用融合的 split-N CUDA kernel，同时计算 up/gate 代理投影，共享 hidden-state 读取；INT4 在寄存器中解包，部分和用 FP32 归约，直接形成 $\tilde{\mathbf{s}}$ 和掩码，不额外存储两条 FP16 代理向量。Stage 2 用融合 output-sparse kernel 同时计算精确 up/gate，再用 input-sparse GEMV 完成 down。掩码判断被放进主循环，从而真正减少权重访问和 MAC，而不是只在算完矩阵乘后把结果置零。

这种实现也解释了为什么论文主要面向单 batch 自回归解码：小矩阵、动态掩码和不规则访存下，通用 dense GEMM 的利用率并不保证。批量变大后，掩码的合并、负载均衡和 kernel 形状都需要重新设计。

## 证据：Prox 改善的是高稀疏率下的质量-速度折中

论文在 Qwen3、Qwen3.5、Ministral、Mistral、Llama-3 和 GeGLU 风格的 Gemma-3 上评估，共 10 个模型、6 个下游任务。结果应按主张理解，而不是按表格逐行背诵：

* 在 50% 有效稀疏率，Prox 超过 TEAL 的模型数为 8/10；在 60% 和 70%，10 个模型全部超过 TEAL。CATS 与 COUNTDOWN 在高稀疏率更早失效，因为它们只稀疏两个投影，且通道信号不完整。
* NVIDIA A6000 单 batch 解码中，60%–70% 稀疏率达到 1.51–1.99 倍端到端加速；70% 时吞吐与 TEAL 的差距不超过 2.9%，但平均下游分数高 14.4%。这表明精确 Stage 2 的质量收益没有明显抵消稀疏 kernel 的速度收益。
* 代理精度并非越高越好。在固定预算下，把 INT4 代理换成 FP16（A1）反而降低分数；Qwen3-8B、70% 稀疏率时低 9.0 分。多出的代理成本挤占了精确计算通道。
* Prox 与量化和稀疏注意力是正交的。在 Qwen3-8B 上结合 AWQ、FP8、W4A16、W8A8 时，Prox 的困惑度均最低；结合 RocketKV 后，16K/32K 吞吐分别达到 dense 的 1.92/2.62 倍。不过量化与稀疏的联合收益仍需要专门的低比特稀疏 kernel，论文将其留作后续工作。

![A6000 上的端到端解码加速](/images/99b30d2b718756f9052668e39cffe439a84e3fd5c42617171bcc394401a5d49f.jpg)

校准也不是一次 top-k 就结束。Prox 使用 Alpaca instruction 文本的 20,480 个 token 位置，为每层保存最多 200,000 个激活样本和 4,096-bin 直方图，并按网络深度顺序校准：后层看到的是前层已经稀疏化后的分布。固定阈值使运行时稀疏率可以随输入变化；四个目标点的平均实测有效稀疏率为 38.71%、48.74%、58.44%、68.33%，比目标低约 1.26–1.67 个百分点。

## 局限：这不是“任意 batch、任意硬件”的免费剪枝

首先，代理掩码的质量依赖校准分布。输入分布显著变化时，固定层阈值可能改变实际稀疏率，且接近阈值的通道更容易错选。其次，论文的速度结果集中在单 batch 解码和定制 CUDA/Triton kernel；大 batch serving、并发请求和不同 GPU 上的负载均衡尚未解决。

再次，INT4 代理权重需要常驻 GPU，带来约 12% 的权重存储额外开销。对于显存极紧张的设备，这笔开销可能抵消部分收益。最后，论文把 $\alpha$ 统一取 $1/3$ 是工程近似；实际延迟还受 kernel 启动、访存模式、GPU 架构和 token 间稀疏率波动影响，不能把有效稀疏率直接等同于端到端加速倍数。

## 研究脉络：从“删激活”到“分离选择与计算”

早期工作利用 ReLU 的零值跳过神经元；ReLUfication 通过改造激活函数把稀疏性重新引入现代 LLM。面向原生 SwiGLU 的 CATS、COUNTDOWN 说明了训练免费稀疏的可行性，但依赖单分支信号；TEAL 进一步把输入稀疏扩展到多条路径，却承担了连续近似误差。

Prox 真正改变的设计选择是：**通道选择和通道值计算不必使用同一种精度、甚至不必使用同一条计算路径。** 代理只回答“哪些通道值得算”，原始权重再回答“这些通道的精确值是多少”。这是一种可推广到其他动态稀疏算子的概念分解，但其收益仍取决于代理排序稳定性和硬件是否能把不规则掩码转化为少量权重读取。

## 结语：最便宜的近似，应该放在不会传播的地方

Prox 的核心不是某个 INT4 技巧，也不是把稀疏率设成 70%。它抓住了 SwiGLU 的结构事实：中间状态同时连接三次投影，是最有解释力的通道信号；但这个信号又必须通过计算才能获得。于是系统先用输入稀疏和低比特权重近似它的排序，再把近似误差截留在 mask 边界，最后对保留通道做 exact 计算。

如果只记住一个 idea：**动态稀疏的关键不是让所有中间值都近似得很准，而是让“选谁”和“算什么”承担不同的精度责任。**
