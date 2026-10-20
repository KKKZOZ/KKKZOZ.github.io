#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, img

#tola-meta((
  title: "Quest Query-Aware Sparsity for Efficient Long-Context LLM Inference",
  date: "2025-11-13",
  tags: ("ICML-24", "KVCache", "Long-Context", "sparse-attention"),
))

#quote(block: true)[
Extensive Reading
]

= Author Info
- #link("https://hanlab.mit.edu/")[MIT HAN Lab]

= Background
In long-context inference:

- The KV cache grows #strong[linearly] with context length ($L$).
- At each decoding step, the model must #strong[read the entire KV cache] to compute attention.

Existing works recognize there is small part of tokens that can domoinate the accuracy of token generation, and they #strong[choose to evict unimportant tokens]:

- #strong[StreamingLLM] keeps a sliding window plus a few “anchor” tokens.
- #strong[H2O], #strong[TOVA], etc., use heuristics or statistics to permanently drop “less important” tokens.

Once a token is evicted, it's gone. #strong[BUT, the important tokens are Query-dependent].

Given a sentence: \"A is B. C is D. A is.\" The token `B`\'s importance varies (shown in Figure 2).

#img("/assets/images/pasted-image-20251113194025.png", alt: "pasted-image-20251113194025")
#img("/assets/images/pasted-image-20251113194152.png", alt: "pasted-image-20251113194152")
= Insights
Don\'t delete KV, just read the right part.

= Approaches
KV caches are organized in the form of pages (according to the PagedAttention).

Quest maintain some metadata per page: (two vectors)

- \($upright(bold(m))$): element-wise #strong[minimum] over all keys in this page.
- \($upright(bold(M))$): element-wise #strong[maximum] over all keys in this page.

Given the metadata ($upright(bold(m))\,upright(bold(M))$), we know that for any key ($upright(bold(k))$) in the page, each dimension ($k_i$) must lie in ($\[m_i\,M_i\]$). So for dimension (i):

- If ($q_i > 0$), the maximum product happens at ($k_i = M_i$).
- If ($q_i < 0$), the maximum product happens at ($k_i = m_i$).

So we can define:

$ U_i = max\(q_i m_i\,\;q_i M_i\) $

Then the #strong[upper bound] of the dot product between ($upright(bold(q))$) and any key in that page is:

$ upright("score")\(upright("page")\)= sum_i U_i $

So we can #strong[run a Top-k selection] over pages using these scores

#callout(kind: "note", title: "NOTE")[
Quest does not reduce the KV cache memory footprint but accelerate the inference

]
Overall workflow:

- Query-aware page selection
- Sparse Attention on Selected Pages

#img("/assets/images/pasted-image-20251113195012.png", alt: "pasted-image-20251113195012")
= Evaluation
= Thoughts
== When Reading
Talk is cheap, show me the code -\- CUDA everywhere

= Related Works
