#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": img

#tola-meta((
  title: "Native Sparse Attention Hardware-Aligned and Natively Trainable Sparse Attention",
  date: "2026-01-29",
  tags: ("deepseek",),
  draft: true,
))

#quote(block: true)[
Extensive Reading
]

= Author Info
= Background
= Insights
= Challenges
= Approaches
#img("/assets/images/pasted-image-20260129220930.png", alt: "pasted-image-20260129220930")
== Token Compression
为什么是 $0 lt.eq i lt.eq c e i l frac(t - l, d)$?

第 i 个 Block 起点为 id+1, 终点为 id+l，$i d + l lt.eq t$，移项后可得

== Token Selection
还是以 Block 为单位，需要考虑的是重要性分数如何计算

选择的时候比较简单，就是选择重要性分数 Top-n 的 Block

== Sliding Window
== Kernel Design
#img("/assets/images/pasted-image-20260129223528.png", alt: "pasted-image-20260129223528")
= Evaluation
= Thoughts
== When Reading
= Related Works
