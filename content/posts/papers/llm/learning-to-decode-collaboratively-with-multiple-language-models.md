---
title: "Learning to Decode Collaboratively with Multiple Language Models"
tags:
  - LLM-Inference
  - Collaborative-Inference
date: 2025-12-02
showtoc: true
draft: true
---

> Extensive Reading

## Author Info

## Background

## Insights

$P_\theta(Z_t \mid X_{<t})$

where:

$P_0(\cdot) = P_{\text{base}}(\cdot)$,

$P_1(\cdot) = P_{\text{assistant}}(\cdot)$, etc.

Let $h_t(X_{<t}) \in \mathbb{R}^d$ be the last hidden state of the base model at step $t$.

Compute argmax predictions of both models:

$\hat v_{\text{base}} = \arg\max_v P_{\text{base}}(v \mid X_{<t})$

$\hat v_{\text{assist}} = \arg\max_v P_{\text{assist}}(v \mid X_{<t})$

Given:

prompt $x = (x_0, \dots, x_m)$

partial response $y_{0:h}$ (tokens generated so far)

state $s_h = (x_0, \dots, x_m, y_0, \dots, y_h)$

The router outputs $\pi_\theta(a_S \mid s_h)$ and $\pi_\theta(a_L \mid s_h)$.

If $\pi_\theta(a_S \mid s_h) \ge \tau$ (a threshold), use the SLM to generate the next token.

Otherwise, use the LLM.

They view token-level routing as a Markov Decision Process (MDP):

State: $s_h = (x_0, \dots, x_m, y_0, \dots, y_h)$.

Action set: $A = {A_L, A_S}$.

$A_L$: generate next token with LLM.

$A_S$: generate next token with SLM.

Transition: $P(s_{h+1} \mid s_h, a_h)$ is given by the behavior of the chosen model. The process ends when \<EOS> is generated.

Reward:

Depends on both

final answer correctness (quality),

and compute cost (LLM vs SLM usage).

This induces a state-action value function $Q^\pi_h(s,a)$

## Challenges

## Approaches

## Evaluation

## Thoughts

### When Reading

## Related Works
