#import "@tola/source:0.0.0": tola-meta
#import "@tola-modules/nasapunk:0.0.0": mi, mitex
#import "@tola-modules/nasapunk:0.0.0": callout
#import "/figures/binary-coding-quantization.typ" as fig

#tola-meta((
  title: "Binary-Coding Quantization: Weights as Sums of Signs",
  date: "2026-11-24",
  summary: "How BCQ writes a weight as a sum of signed scales, how greedy and alternating fits choose the scales, how fast its error falls with each bit, how it compares with uniform quantization, and how a kernel computes with bit planes.",
  tags: ("Quantization", "LLM-Inference"),
  weight: 10,
  toc-depth: 2,
))

*Binary-coding quantization* (BCQ) stores a weight as a sum of terms, each a sign times a scale:

#mitex(`w \approx \sum_{p=1}^{P} \alpha_p \, b_p, \qquad b_p \in \{-1, +1\}`)

Each term corrects what the earlier ones left, so the first _p_ terms are a _p_-bit quantization on their own. Stored as separate bit planes, one copy of the weights can be read at 1, 2, 3 or 4 bits, and the arithmetic reduces to adding and subtracting.

This post covers the format, the two ways to fit it, how fast its error falls with each bit, how it compares with uniform quantization, and how a kernel computes with it.

= The Format

== Signs and Scales

Weights are split into groups of _g_ consecutive weights. Each weight stores _P_ sign bits #mi(`b_1, \dots, b_P`)\; each group stores _P_ scales #mi(`\alpha_1 > \alpha_2 > \dots > \alpha_P > 0`), shared by its weights. The signs of all weights for one _p_ form *bit plane p*.

@fig-format shows one group with _g_ = 8 and _P_ = 3. Each column is one weight _j_; each row is one plane _p_, with its scale #mi(`\alpha_p`):

#figure(fig.fig-format(), caption: [BCQ on one group, fitted with the greedy method described below. The error on the right is a share of the group's #mi(`\sum w^2 = 3.8`).]) <fig-format>

Storage per weight is _P_ bits for the signs plus the group's share of the scales. With an FP16 α per plane and group, each plane stores 1 bit for the sign of every weight, plus one 16-bit α shared by _g_ weights, so one plane costs

#mitex(`1 + \frac{16}{g} \text{ bits per weight (bpw)}`)

1.125 bpw for _g_ = 128 and 2 bpw for _g_ = 16. Small groups fit better but pay more for their scales, the same trade-off as in group-wise INT4 formats.

== The Grid

A group with _P_ planes can take 2#super[_P_] values, the sums #mi(`\pm\alpha_1 \pm \dots \pm \alpha_P`). We call this set the *grid*.

#figure(fig.fig-grid(), caption: [The grid for four choices of α. Flipping every sign negates a value, so each grid is symmetric about 0.]) <fig-grid>

- *The grid is symmetric about 0*, because flipping every sign of a value gives its negative. It has no offset, so a group whose weights are centred away from 0 cannot shift its levels to follow them.
- *Uniform quantization is a special case.* With #mi(`\alpha_{p+1} = \alpha_p / 2`), the levels are evenly spaced: #mi(`\alpha = (1, 0.5)`) gives {−1.5, −0.5, 0.5, 1.5}. Other α make the spacing uneven.

= Fitting the Signs and Scales

#callout(kind: "info", title: [THE PROBLEM])[
  Given the _g_ weights #mi(`w_1, \dots, w_g`) of one group and the number of planes _P_, choose the signs #mi(`b_{p,j} \in \{-1, +1\}`) and the scales #mi(`\alpha_1, \dots, \alpha_P`) that minimize the squared error

  #mitex(`\sum_{j=1}^{g} \Big(w_j - \sum_{p=1}^{P} \alpha_p \, b_{p,j}\Big)^2`)

  Every group is fitted on its own. The signs and the scales depend on each other: the best signs depend on the scales, and the best scales on the signs.
]

To compare fits, we measure the error relative to the size of the weights. With #mi(`\hat w_{b,j}`) the value of weight _j_ after reading _b_ planes,

#mitex(`D(b) = \frac{\sum_j (w_j - \hat w_{b,j})^2}{\sum_j w_j^2}`)

is the share of the weights' *energy*, their sum of squares, that is left as error. _D_ = 0 is an exact fit, and _D_(0) = 1, since with no planes every weight is 0. In @fig-format, _D_(1), _D_(2) and _D_(3) are the numbers on the right.

One plane has a closed-form answer. For more planes there are two methods: greedy, which fits one plane at a time, and alternating, which fits all planes together.

== One Plane

With one plane, we want the α and signs that minimize #mi(`\sum_j (w_j - \alpha b_j)^2`) over a group. For any α > 0, the best sign is #mi(`b_j = \operatorname{sign}(w_j)`). Then each term is #mi(`(\lvert w_j \rvert - \alpha)^2`), and setting the derivative in α to zero gives

#mitex(`\alpha = \frac{1}{g} \sum_j \lvert w_j \rvert = \operatorname{mean}\lvert w \rvert`)

the scale #link("https://arxiv.org/abs/1603.05279")[XNOR-Net] derived for binary-weight networks. Substituting it back, with #mi(`m = \operatorname{mean}\lvert w \rvert`) and #mi(`\sum_j \lvert w_j \rvert = g m`), the error is

#mitex(`\sum_j (\lvert w_j \rvert - m)^2 = \sum_j w_j^2 - 2m \cdot g m + g m^2 = \sum_j w_j^2 - g m^2`)

Dividing by #mi(`\sum_j w_j^2 = g \operatorname{mean}(w^2)`) gives

#mitex(`D(1) = 1 - \frac{(\operatorname{mean}\lvert w \rvert)^2}{\operatorname{mean}(w^2)}`)

It depends only on the shape of the distribution:

- *Gaussian*: #mi(`\operatorname{mean}\lvert w \rvert = \sigma\sqrt{2/\pi}`), so #mi(`D(1) = 1 - 2/\pi \approx 0.363`).
- *Laplace*, with heavier tails: #mi(`\operatorname{mean}\lvert w \rvert = b`) and #mi(`\operatorname{mean}(w^2) = 2b^2`), so _D_(1) = 0.5.
- *Uniform* on [−_a_, _a_]: #mi(`\operatorname{mean}\lvert w \rvert = a/2`) and #mi(`\operatorname{mean}(w^2) = a^2/3`), so _D_(1) = 0.25.

== Greedy: One Plane at a Time

The greedy method (#link("https://arxiv.org/abs/1706.02021")[Guo et al., 2017]) fits each plane like the single plane above, on what the earlier planes left:

```python
r = w                        # residual: what the planes so far leave out
for p in range(P):
    b[p] = sign(r)           # one sign per weight
    alpha[p] = mean(abs(r))  # one scale for the group
    r = r - alpha[p] * b[p]  # remove what plane p represents
# now w = alpha[0] * b[0] + ... + alpha[P-1] * b[P-1] + r
```

With the four weights #mi(`w = (-0.3, -0.1, 0.2, 1.4)`) and _P_ = 2, each line of the loop gives one row of @tab-greedy-steps:

#figure(
  table(
    columns: 6,
    align: (left, right, right, right, right, left),
    table.header([Step], [_w_#sub[1]], [_w_#sub[2]], [_w_#sub[3]], [_w_#sub[4]], [Shared by the group]),
    [_w_], [−0.3], [−0.1], [0.2], [1.4], [],
    [#mi(`b_1 = \operatorname{sign}(w)`)], [−1], [−1], [+1], [+1], [#mi(`\alpha_1 = \operatorname{mean}\lvert w \rvert = 0.5`)],
    [#mi(`r = w - \alpha_1 b_1`)], [0.2], [0.4], [−0.3], [0.9], [squared error 1.10],
    [#mi(`b_2 = \operatorname{sign}(r)`)], [+1], [+1], [−1], [+1], [#mi(`\alpha_2 = \operatorname{mean}\lvert r \rvert = 0.45`)],
    [#mi(`r = r - \alpha_2 b_2`)], [−0.25], [−0.05], [0.15], [0.45], [squared error 0.29],
    [#mi(`\hat w = \alpha_1 b_1 + \alpha_2 b_2`)], [−0.05], [−0.05], [0.05], [0.95], [],
  ),
  caption: [Greedy BCQ with _P_ = 2 on a group of four weights, one row per line of the loop. The squared error is #mi(`\sum r^2`) after each plane.],
) <tab-greedy-steps>

Each step only adds a correction, so the first _p_ planes are exactly what greedy would have built with _P_ = _p_. *Reading fewer planes gives the greedy fit at fewer bits, not a broken weight.* In @fig-format, _D_ falls from 0.304 to 0.082 to 0.034 as planes 2 and 3 are read.

== Where Greedy Falls Short

Each greedy α is the best scale for its own plane given the earlier ones, but it is chosen before the later planes exist. In @tab-greedy-steps, greedy ends with #mi(`\alpha = (0.5, 0.45)`), the grid {−0.95, −0.05, 0.05, 0.95} and a squared error of 0.29. With the same signs, two planes can do much better.

To see where greedy's α go wrong, split each value #mi(`\alpha_1 b_1 + \alpha_2 b_2`) into a sign and a magnitude. With two planes and #mi(`\alpha_1 > \alpha_2`):

- *The sign of the value is the sign of #mi(`b_1`)*, because #mi(`\alpha_2`) is too small to flip it.
- *The magnitude depends on whether #mi(`b_2`) has the same sign as #mi(`b_1`):*
  - same sign: the two terms add, and the magnitude is #mi(`\alpha_1 + \alpha_2`), the large level;
  - opposite signs: the two terms partly cancel, and the magnitude is #mi(`\alpha_1 - \alpha_2`), the small level.

So plane 2 splits the weights into two classes by magnitude. In @tab-greedy-steps, #mi(`b_2`) has the opposite sign of #mi(`b_1`) for _w_#sub[1], _w_#sub[2] and _w_#sub[3], the small class (|_w_| = 0.3, 0.1, 0.2), and the same sign for _w_#sub[4], the large class (|_w_| = 1.4).

For a fixed split, the best level for each class is the mean |_w_| of that class, for the same reason that one plane takes #mi(`\alpha = \operatorname{mean}\lvert w \rvert`):

- small class: (0.3 + 0.1 + 0.2) / 3 = 0.2;
- large class: 1.4.

Solving #mi(`\alpha_1 - \alpha_2 = 0.2`) and #mi(`\alpha_1 + \alpha_2 = 1.4`) gives #mi(`\alpha_1 = 0.8,\ \alpha_2 = 0.6`). Greedy instead puts the two levels at #mi(`0.5 \pm 0.45`), that is, 0.05 and 0.95, centred on mean |_w_| = 0.5 rather than on the two class means.

With #mi(`\alpha = (0.8, 0.6)`) and the same signs, the grid is {−1.4, −0.2, 0.2, 1.4} and the squared error is 0.02, 14 times lower:

#figure(fig.fig-fit(), caption: [The same four weights and the same signs, with greedy α (a) and with α refitted by least squares (b). Each weight's value is the tip of its orange arrow.]) <fig-fit>

*Greedy never makes this correction.* It fixes #mi(`\alpha_1`) before plane 2 exists and does not go back to it. Refitting α for fixed signs is the first step of the alternating method in the next section.

*Greedy's two levels are the class means only when as many weights fall above mean |w| as below.* With half the weights in each class, of class means #mi(`m_s`) and #mi(`m_l`), mean |_w_| is #mi(`(m_s + m_l)/2`) and the mean distance from it is #mi(`(m_l - m_s)/2`), so greedy lands on #mi(`m_s`) and #mi(`m_l`) exactly. The example has 3 small weights and 1 large one.

Bell-shaped weights are unbalanced in the same direction: for a Gaussian, only 42.5% of the magnitudes exceed their mean. The greedy levels then sit below both class means:

#figure(fig.fig-magnitude(), caption: [Two planes on Gaussian weights, seen as a 2-level quantizer of |_w_|. (a) Greedy splits at mean |_w_| = 0.798 and puts the levels at 0.798 ± 0.483; the class means (hollow) are 0.378 and 1.365. (b) The best 2-plane fit: each level is its class mean and the split lies halfway between them. _D_(2) is the remaining share of the energy.]) <fig-magnitude>

== Alternating: All Planes Together

#link("https://arxiv.org/abs/1802.00150")[Xu et al. (2018)] fit all planes together, alternating two steps that each cannot raise the error:

+ *Fix the signs, solve for α.* With the signs of a group as a _P_ × _g_ matrix _B_, the best α is the least-squares solution #mi(`\alpha = (B B^\top)^{-1} B w`), a _P_ × _P_ system per group.
+ *Fix α, choose the signs.* Each weight takes the nearest of the 2#super[_P_] grid values, which sets all its _P_ signs. With the grid sorted, this is a comparison against the midpoints between neighbouring values (Xu et al. use a binary search tree).

On the example of the previous section:

+ Step 1 takes greedy's signs from @tab-greedy-steps and gives #mi(`\alpha = (0.8, 0.6)`), the fit of @fig-fit (b).
+ Step 2 checks each weight against the new grid {−1.4, −0.2, 0.2, 1.4}. Every weight is already nearest to its current value, so no sign changes, and the fit stops after one round.

In general, new α move the grid, some weights end up nearer a different value and change their signs, and the two steps repeat until nothing changes. Starting from the greedy fit, a few rounds suffice. This is Lloyd's algorithm (_k_-means in one dimension) restricted to grids of the form #mi(`\pm\alpha_1 \pm \dots \pm \alpha_P`).

*The price is the prefix property.* Alternating fits α for one _P_. In both cases below, its first plane keeps an #mi(`\alpha_1`) larger than mean |_w_|, so read alone it is a worse 1-bit fit:

#figure(
  table(
    columns: 5,
    table.header([Fit], [Example, 1 plane], [Example, 2 planes], [Gaussian _D_, 1 plane], [Gaussian _D_, 2 planes]),
    [Greedy], [1.10], [0.29], [0.363], [0.130],
    [Alternating], [1.46], [0.02], [0.397], [0.117],
  ),
  caption: [Error after reading the first plane and both planes of a 2-plane fit. Example: squared error on #mi(`w = (-0.3, -0.1, 0.2, 1.4)`). Gaussian: remaining share of the energy on 10#super[6] samples (numpy), one α per plane for all of them.],
) <tab-prefix>

#callout(kind: "info", title: [GREEDY OR ALTERNATING])[
  - *Greedy* fits one plane at a time, each given the planes before it, so every prefix of _p_ planes is itself a good _p_-plane fit. Use it when a kernel reads fewer planes for some weights or at some times.
  - *Alternating* fits all _P_ planes together, for the error after reading all of them, and its prefixes get worse. Use it when a kernel always reads all _P_ planes.
]

= How Fast the Error Falls

This section follows _D_(_b_) as _b_ grows. For a uniform quantizer, one more bit halves the step between levels, and the rounding error, whose variance is proportional to the step squared, falls by 4.

*Greedy BCQ falls by 4 per plane only on uniformly distributed weights.* There, the residual after a plane is again uniform, at half the width, so every plane solves the same problem at half the scale. On bell-shaped weights it falls more slowly:

#figure(fig.fig-decay(), caption: [_D_ against planes read, on a log scale, simulated with numpy (4 × 10#super[5] samples per distribution, one α per plane for all of them). Blue: greedy fits on Gaussian and on Laplace weights. Teal: alternating fits on Gaussian weights, each depth fitted on its own. Grey: greedy on uniform weights, which divides _D_ by exactly 4 per plane.]) <fig-decay>

- *Gaussian, greedy*: 0.363, 0.130, 0.058, 0.033. Planes 2, 3 and 4 divide _D_ by 2.8, 2.2 and 1.8.
- *Laplace, greedy*: 0.501, 0.230, 0.143, 0.096, divided by 2.2, 1.6 and 1.5. The heavier the tails, the slower the fall.
- *Gaussian, alternating*: 0.363, 0.117, 0.037, 0.012, about 3× per plane. The best possible 16-level quantizer for a Gaussian (Lloyd–Max) leaves 0.0095, so at 4 bits most of greedy's shortfall comes from its fitting order, not from the grid.

@fig-magnitude shows the first step of the mechanism. Inside each sign, the residual left by plane 1 is skewed: more weights sit just below #mi(`\alpha_1`) than far above it. A symmetric step of ±#mi(`\alpha_2`) fits a skewed residual poorly, and each later plane inherits a skewed residual again.

= BCQ Against Uniform Quantization

A uniform format with an offset, such as Q2_K, writes a weight as #mi(`w \approx d \cdot q - m`) with #mi(`q \in \{0, 1, 2, 3\}`), a scale _d_ and a min _m_ per group. Its four levels are evenly spaced but shifted to fit each group. Two BCQ planes give four levels that are unevenly spaced but centred on 0. *Both spend two parameters per group: the uniform format on a step and an offset, BCQ on two steps.*

To see which parameter matters more, we fitted each 2-bit grid to Gaussian weights in groups of 16, with exact (unquantized) parameters, so only the shape of the grid differs:

#figure(
  table(
    columns: 3,
    table.header([2-bit grid], [Parameters per group], [_D_(2)]),
    [BCQ, greedy], [α#sub[1], α#sub[2]], [0.114],
    [Even and centred on 0 (BCQ with #mi(`\alpha_2 = \alpha_1/2`))], [one scale], [0.104],
    [BCQ, alternating], [α#sub[1], α#sub[2]], [0.092],
    [Even with an offset], [scale, min], [0.072],
    [BCQ with an offset, alternating], [α#sub[1], α#sub[2], offset], [0.071],
  ),
  caption: [Remaining share of the energy at 2 bits per weight, on 20,000 groups of 16 Gaussian samples (numpy). Greedy BCQ as in the pseudocode above; every other grid fitted by alternating least squares, from the greedy fit or from the group's min and max.],
) <tab-grids>

- *The offset is worth more than uneven spacing.* Going from an even, centred grid to an uneven one lowers _D_ from 0.104 to 0.092; adding an offset to the even grid lowers it to 0.072.
- *Small groups are where the offset pays.* The mean of 16 Gaussian samples carries 1/16 ≈ 6.3% of their energy, close to the offset grid's whole error of 7.2%. A grid centred on 0 has to cover that shift with its levels; an offset removes it first.
- *BCQ with an offset matches the uniform grid*: #mi(`w \approx \sum_p \alpha_p b_p + z`) reaches 0.071, at the cost of a third parameter per group. #link("https://arxiv.org/abs/2206.09557")[LUT-GEMM] adds such an offset so that its kernel also covers uniform quantization: with #mi(`\alpha = (d, d/2)`) and #mi(`z = 1.5d - m`), the four values are exactly #mi(`d q - m`).

The last point also means that the bits of a uniform integer, stored most significant bit first, are bit planes of BCQ with an offset. Reading only the top bits of such an integer is a coarser uniform quantization, so it keeps the prefix property too.

= Computing with Bit Planes

== The Planar Layout

A kernel saves time by reading fewer planes only if each plane is stored on its own. A packed format keeps both bits of a weight in one byte; a planar layout stores plane 1 of a row, then plane 2:

#figure(fig.fig-layout(), caption: [Eight 2-bit weights in two layouts. Packed, a 1-bit read still loads every byte; in planes, it loads half of them.]) <fig-layout>

== Each Plane Is an Add or a Subtract

The output of a matrix-vector product with BCQ weights is

#mitex(`y_j = \sum_i x_i \hat w_{ij} = \sum_p \sum_i (\alpha_{p} x_i)\, b_{p,ij}`)

Suppose row _i_ of _W_ holds the weights of one input #mi(`x_i`) for every output _j_, and α is shared by 16 consecutive outputs. The kernel computes #mi(`c = \alpha_p x_i`) once per plane and group, then adds _c_ to or subtracts it from each of the 16 accumulators, as the 16 sign bits say. No weight needs a multiply.

== Lookup Tables

In the other layout, each output is a dot product along a row, #mi(`\sum_i x_i b_{p,ij}`) for one plane. #link("https://arxiv.org/abs/2206.09557")[LUT-GEMM] (Park et al., ICLR 2024) splits _x_ into chunks of μ inputs and computes all #mi(`2^\mu`) signed sums of each chunk once per input vector. Then every μ sign bits of a row form an index into that table:

#figure(fig.fig-lut(), caption: [A table over μ = 3 inputs. Bit 1 means +1 and bit 0 means −1, so #raw("101") selects #mi(`x_1 - x_2 + x_3`). Each row looks up its value instead of adding three inputs.]) <fig-lut>

With μ = 8, a table of 256 sums replaces 8 additions by one lookup. The table is built once per chunk and input vector and is shared by every row and every plane, so its cost is spread over all of them. It needs α to be constant across the μ inputs of a chunk, so groups run along the input dimension.
