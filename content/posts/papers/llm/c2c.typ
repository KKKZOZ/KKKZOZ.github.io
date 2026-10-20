#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, img

#tola-meta((
  title: "C2C",
  date: "2025-12-06",
  tags: ("LLM-Inference", "KVCache", "Collaborative-Inference"),
  draft: true,
))

#quote(block: true)[
Extensive Reading
]

= Author Info
= Background
= Insights
The author conducts two oracle experiments to answer:

- Can a model's capabilities be improved through KV-Cache semantic enrichment without extending sequence length?
- Can the KV-Cache of one model be effectively utilized by another model?

== Cache Enrichment Oracle
The author sets up three methods with $X$\(the question) and $E$\(the examples) to test accuracy:

+ Direct: Only use $X$
+ Few-shot: Use $E + X$
+ Oracle: Use $E + X$ for prefill and use $X$ for decoding

- The KV Cache of $X$ now contains richer semantics including the examples($E$)

#img("/assets/images/pasted-image-20251206155952.png", alt: "pasted-image-20251206155952")
TODO: \"while some layers benefit from cache enrichment, others experience performance degradation\" -\-\> Does this experiment include all layers?

== Cache Transformation Oracle
Train a 3-layer MLP to map the KV-Cache from a source LLM

#img("/assets/images/pasted-image-20251206160151.png", alt: "pasted-image-20251206160151")
These results demonstrate that KV-Caches from different models are, in general, convertible as the transformed cache in the representation space of the target model.

#callout(kind: "note", title: "NOTE")[
- The transformed cache occupies only a smaller subset of the target's space.
- The correct-answer sets of different models exhibit limited overlap (Figure 7), despite the comparable aggregated accuracy of respective models.

]
#img("/assets/images/pasted-image-20251206160858.png", alt: "pasted-image-20251206160858")
TODO: How does this MLP being trained? Can we reproduce it?

= Challenges
= Approaches
== Overall
In general, the C2C paradigm contains a set of key/value cache fusers $cal(F)$ and a layer mapping strategy $cal(G)$.

During the prefill stage, fuser $cal(F)_n$ takes the $n$-th layer cache of the Receiver Model $cal(C)_n\(X\)$ and the corresponding $cal(G)\(n\)$-th layer cache of the Sharer Model $cal(C)_(cal(G)\(n\))^(cal(S))\(X\)$ and generates the corresponding fused cache:

$ cal(C)^(cal(F)) = { cal(F)_n\(cal(C)_n\(X\)\,cal(C)_(cal(G)\(n\))^(cal(S))\(X\)\)}_(n = 1)^N $

During decoding, with the current token $y_i$ and caches from the input and the generated prefix, the next token is predicted as:

$ y_(i + 1) = cal(P)\(y_i\|cal(C)^(cal(F))\(X\)xor cal(C)\(Y_(\[0 : i\])\)\) $

== Fuser
it contains three key modules:

- #strong[Projection module] concatenates the Receiver's KV-Cache with the Sharer's KV-Cache, then processes the concatenated feature through a projection layer followed by a feature fusion layer.
- #strong[Dynamic weighting module] applies an input-aware head modulation layer to dynamically re-weight the projected information.
- #strong[Learnable gate] introduces a trainable per-layer gate value that decides whether to inject the Sharer's context. The value applies a Gumbel-sigmoid with temperature annealing to smoothly transition from differentiable during training to binary at inference.

#img("/assets/images/pasted-image-20251206161148.png", alt: "pasted-image-20251206161148")
= Evaluation
= Thoughts
== When Reading
= Related Works
