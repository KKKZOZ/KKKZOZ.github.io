#import "@tola/source:0.0.0": tola-meta

#tola-meta((
  title: "Learning to Decode Collaboratively with Multiple Language Models",
  date: "2025-12-02",
  tags: ("LLM-Inference", "Collaborative-Inference"),
  draft: true,
))

#quote(block: true)[
Extensive Reading
]

= Author Info
= Background
= Insights
$P_theta\(Z_t divides X_(< t)\)$

where:

$P_0\(dot.op\)= P_(upright("base"))\(dot.op\)$,

$P_1\(dot.op\)= P_(upright("assistant"))\(dot.op\)$, etc.

Let $h_t\(X_(< t)\)in bb(R)^d$ be the last hidden state of the base model at step $t$.

Compute argmax predictions of both models:

$hat(v)_(upright("base")) = arg max_v P_(upright("base"))\(v divides X_(< t)\)$

$hat(v)_(upright("assist")) = arg max_v P_(upright("assist"))\(v divides X_(< t)\)$

Given:

prompt $x =\(x_0\,dots.h\,x_m\)$

partial response $y_(0 : h)$ (tokens generated so far)

state $s_h =\(x_0\,dots.h\,x_m\,y_0\,dots.h\,y_h\)$

The router outputs $pi_theta\(a_S divides s_h\)$ and $pi_theta\(a_L divides s_h\)$.

If $pi_theta\(a_S divides s_h\)gt.eq tau$ (a threshold), use the SLM to generate the next token.

Otherwise, use the LLM.

They view token-level routing as a Markov Decision Process (MDP):

State: $s_h =\(x_0\,dots.h\,x_m\,y_0\,dots.h\,y_h\)$.

Action set: $A = A_L\,A_S$.

$A_L$: generate next token with LLM.

$A_S$: generate next token with SLM.

Transition: $P\(s_(h + 1) divides s_h\,a_h\)$ is given by the behavior of the chosen model. The process ends when \<EOS\> is generated.

Reward:

Depends on both

final answer correctness (quality),

and compute cost (LLM vs SLM usage).

This induces a state-action value function $Q_h^pi\(s\,a\)$

= Challenges
= Approaches
= Evaluation
= Thoughts
== When Reading
= Related Works
