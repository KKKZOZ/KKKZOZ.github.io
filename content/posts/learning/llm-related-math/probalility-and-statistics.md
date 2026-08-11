---
title: "Probability and Statistics"
summary: "Notes on L1 and L2 norms, KL divergence, and their applications in machine learning."
tags:
  - Math
date: 2026-03-18
showtoc: true
weight: 10
---

## L1 范数

The $L_1$ norm calculates the sum of the absolute values of all elements within a vector or matrix.

Calculation: For a weight vector $w$ with $n$ elements, the $L_1$ norm is defined as:

$$
\|w\|_1 = \sum_{i=1}^{n} |w_i|
$$

> [!INFO] Related to LLM
>
> Pruning Context: When applying the $L_1$ norm to a structural group (like a specific attention channel), you take the absolute value of every single parameter in that channel and sum them up. A low $L_1$ norm indicates that the parameters in that group are collectively very close to zero.

## L2 范数

The $L_2$ norm calculates the standard Euclidean distance of the weight vector from the origin. It is the square root of the sum of the squared values of the elements.

Calculation: For the same weight vector $w$, the $L_2$ norm is defined as:

$$
\|w\|_2 = \sqrt{\sum_{i=1}^{n} w_i^2}
$$

> [!INFO] Related to LLM
>
> Pruning Context: Because the $L_2$ norm squares each parameter before summing them, **it disproportionately heavily weights larger parameters**. A structural group with just a few very large weights will have a high $L_2$ norm, even if the rest of the weights are near zero. Conversely, a group with consistently small weights will have a low $L_2$ norm and will be targeted for pruning.

## KL 散度

KL Divergence calculates the expected excess surprise from using an approximation distribution instead of the true distribution.

Calculation: For two discrete probability distributions, $P$ (the true distribution) and $Q$ (the approximated or predicted distribution), defined on the same probability space $\mathcal{X}$, the KL Divergence from $Q$ to $P$ is defined as:

$$
D_{KL}(P \parallel Q) = \sum_{x \in \mathcal{X}} P(x) \log \left( \frac{P(x)}{Q(x)} \right)
$$

Mathematical Breakdown:

- $P(x)$ represents the actual probability of an event $x$ occurring.
- $Q(x)$ represents the model's predicted probability of that same event $x$.
- The ratio $\frac{P(x)}{Q(x)}$ compares these probabilities. If they are identical, the ratio is 1, and the $\log(1)$ becomes 0, meaning there is zero divergence.
- We multiply the log value by $P(x)$ to compute the expected value (the weighted average) across the entire true distribution.

### Application in ML

While norms are typically used to penalize or prune network weights, KL Divergence is predominantly used to optimize network outputs that represent probabilities.

- Knowledge Distillation
  - When compressing a massive neural network (the "teacher") into a smaller network (the "student"), KL divergence is used as the loss function.
  - The student model is trained to minimize the KL divergence between its output probability distribution ($Q$) and the teacher's output probability distribution ($P$), forcing the student to mimic the teacher's exact confidence levels across all classes.
- Cross-Entropy Loss
  - In standard classification tasks, minimizing the Cross-Entropy loss is mathematically equivalent to minimizing the KL Divergence between the training data's one-hot encoded labels ($P$) and the model's softmax predictions ($Q$).

### Calculation Example

- Vector $P$ (The True Distribution): This represents the actual, ground-truth probabilities.

  $$
  P = [0.5, 0.2, 0.2, 0.1]
  $$

- Vector $Q$ (The Predicted Distribution): This represents what our neural network predicts the probabilities are.

  $$
  Q = [0.4, 0.3, 0.2, 0.1]
  $$

- Element 1: $0.5 \times \ln \left( \frac{0.5}{0.4} \right) = 0.5 \times \ln(1.25) \approx 0.5 \times 0.2231 = 0.1116$
- Element 2: $0.2 \times \ln \left( \frac{0.2}{0.3} \right) = 0.2 \times \ln(0.6667) \approx 0.2 \times -0.4055 = -0.0811$
- Element 3: $0.2 \times \ln \left( \frac{0.2}{0.2} \right) = 0.2 \times \ln(1) = 0.2 \times 0 = 0$
- Element 4: $0.1 \times \ln \left( \frac{0.1}{0.1} \right) = 0.1 \times \ln(1) = 0.1 \times 0 = 0$

Finally, we sum these individual components together:

$$
D_{KL}(P \parallel Q) = 0.1116 + (-0.0811) + 0 + 0 = 0.0305 \text{ nats}
$$
