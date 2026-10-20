#import "@tola/source:0.0.0": tola-meta

#tola-meta((
  title: "R2R",
  date: "2025-12-06",
  tags: ("LLM-Inference", "Collaborative-Inference"),
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
= Evaluation
= Thoughts
== When Reading
这一类方法其实要处理两个问题：

+ 离线如何高效识别 diverge token
+ 在线如何训练一个 router 在 inference 时进行判断

在训练时，对于 Divergent different token 的处理有点不优雅？

= Related Works
