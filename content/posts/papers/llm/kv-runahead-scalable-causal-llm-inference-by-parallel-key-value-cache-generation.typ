#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": img

#tola-meta((
  title: "KV-Runahead Scalable Causal LLM Inference by Parallel Key-Value Cache Generation",
  date: "2025-08-17",
  tags: ("ICML-24", "Tensor-Parallelism"),
))

#quote(block: true)[
Skimming
]

= Author Info
= Background
= Challenges
= Insights
= Approaches
#quote(block: true)[
看了好几遍都没看懂，我大概的理解是

+ 利用了 casual mask 的特性以链式的方式在不同设备之间传递 KV，避免了传统 TSP 的大量重复计算和冗余传输
+ 为了平衡整个流水线采用了 context-level load balancing，靠前的设备多算一些 KV, 靠后的设备少算一些，因为靠后的设备注意力计算会更长
]

这里的关键点是：每个设备不仅传递 KV 缓存，也要利用收到的缓存，完成自己那部分词元的注意力计算。

- 在 D1 上:
  - 计算 T1-T4 的Q\_0, K\_0, V\_0。
  - 立刻进行自己部分的注意力计算：用 Q\_0 与 K\_0 计算一个 4x4 的注意力矩阵，得到输出A\_0。
  - 然后，它将 K\_0, V\_0（尺寸为 4 的缓存）发送给D2。
- 在 D2 上:
  - 在等待 D1 数据的同时，它可以并行计算 T5-T7 的本地Q\_1, K\_1, V\_1。
  - 当它收到 D1 发来的 K\_0, V\_0 后，它将自己本地的 K\_1, V\_1 追加上去，形成一个包含 T1-T7 信息的、尺寸为 7 的 KV 缓存。
  - 立刻进行自己部分的注意力计算：用自己的 Q\_1（来自 T5-T7）与这个尺寸为 7 的完整缓存进行计算（一个 3x7 的注意力计算），得到输出 A\_1。
  - 然后，它将这个尺寸为 7 的 KV 缓存发送给 D3。
- 在 D3 上:
  - 并行计算 T8-T9 的本地Q\_2, K\_2, V\_2。
  - 收到 D2 发来的尺寸为 7 的缓存后，追加自己的 K\_2, V\_2，形成包含全部 9 个词元信息的最终KV缓存。
  - 它进行自己部分的注意力计算：用 Q\_2 与这个尺寸为 9 的完整缓存进行计算（一个 2x9 的注意力计算），得到输出 A\_2。
  - 作为最后一个设备，它最终生成第一个令牌。

== TSP
#img("/assets/images/pasted-image-20250818105741.png", alt: "pasted-image-20250818105741")
TSP 方案旨在并行化标准的单设备注意力计算流程。其标准工作流程如图4所示：

- #strong[执行流程]:

  + 将输入上下文在多个处理器（进程）间#strong[均匀划分]。
  + 每个进程独立计算其对应部分的 Q, K, V 向量。
  + 通过一次 `all-gather` 集体通信操作，所有进程交换并获得完整的 K 和 V 向量。
  + 每个进程使用其本地的 Q 和全局的 K, V 来计算均等分配的注意力输出部分。

- #strong[技术瓶颈]:

  - #strong[计算冗余]: TSP 忠实地并行化了通用的注意力计算方法，即先计算一个完整的稠密 $Q K^T$ 矩阵，然后再通过掩码（mask）忽略掉上三角部分。这个过程没有利用 LLM 的因果性，导致了大量的无效计算，造成了计算资源的浪费。
  - #strong[通信瓶颈]: `all-gather` 操作是一个#strong[全局同步点]，要求所有进程必须互相等待，这会成为性能瓶颈。同时，它导致了很高的网络流量；在论文的示例中，TSP 需要交换 36 个 (K, V) 条目。

== KVR
#img("/assets/images/pasted-image-20250818105844.png", alt: "pasted-image-20250818105844")
- #strong[执行流程]:

  + 对输入上下文进行#strong[非均匀划分]以实现负载均衡。
  + 每个进程独立计算其对应部分的 Q, K, V 向量。
  + 进程间形成一个计算链，通过#strong[点对点（point-to-point）的 `send` 操作]，将本地计算并拼接后的 KV 缓存逐级传递给下一个进程。
  + 每个进程利用接收到的 KV 缓存和自己本地的 QKV，计算出自己负责部分的注意力输出。只有最后一个进程会拥有完整的 KV 缓存。

- #strong[技术优化]:

  - #strong[计算优化]: KVR的链式构建过程天然遵循了因果关系，因此它能#strong[自动避免]对 $Q K^T$ 矩阵上三角部分的无效计算。论文的例子显示，TSP 在所有进程上都需要 27 次点积运算，而 KVR 的计算瓶颈（最繁忙的进程）仅需 21 次。
  - #strong[通信优化]: KVR 用点对点通信取代了全局同步的 `all-gather`，消除了全局等待瓶颈。同时，总通信量也显著降低；在同一示例中，KVR 仅需交换 22 个 (K, V) 条目，远少于 TSP 的 36 个。

#quote(block: true)[
即使TSP通过定制的BLAS内核来避免无效计算，其 `all-gather` 通信模式仍然是低效的，而KVR通过复用KV缓存机制，无缝地同时解决了计算和通信两个瓶颈。
]

= Evaluation
= Thoughts
== When Reading
= Related Works
- #link("/posts/papers/llm/ring-attention-with-blockwise-transformers-for-near-infinite-context/")[Ring Attention with Blockwise Transformers for Near-Infinite Context]
- #link("/posts/papers/llm/striped-attention-faster-ring-attention-for-causal-transformers/")[Striped Attention Faster Ring Attention for Causal Transformers]
