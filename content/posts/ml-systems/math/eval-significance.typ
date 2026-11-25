#import "@tola/source:0.0.0": tola-meta
#import "@tola-modules/nasapunk:0.0.0": mi, mitex
#import "@tola-modules/nasapunk:0.0.0": callout
#import "/figures/eval-significance.typ" as fig

#tola-meta((
  title: "Comparing Two Eval Runs: Standard Error, z and Pairing",
  date: "2026-11-23",
  summary: "Two 2-bit quantizations differ by under 0.75 pp on the same 1940 questions. Standard error, z, paired differences, and the smallest gap an eval of this size can detect.",
  tags: ("Math", "Quantization"),
  weight: 10,
  toc-depth: 2,
))

Two 2-bit quantizations of the same pruned model, Q2_K and INT2, were scored on the same multiple-choice questions at four sparsity levels. The mean accuracies differ by less than 0.75 percentage points (pp) at every level, twice in Q2_K's favour and twice in INT2's:

#figure(
  table(
    columns: 4,
    table.header([Sparsity], [INT2], [Q2_K], [Q2_K − INT2]),
    [40%], [72.09%], [72.70%], [+0.611 pp],
    [50%], [72.19%], [71.46%], [−0.735 pp],
    [60%], [71.89%], [71.50%], [−0.395 pp],
    [70%], [68.80%], [69.48%], [+0.677 pp],
  ),
  caption: [Mean accuracy of the two formats at each sparsity level. The last column, the *gap*, is the one number this post is about.],
)

Is any of these gaps a real difference between the formats, or noise that a different set of questions would have erased or flipped?

*None of the four can be told apart from noise.* At this size, the eval reliably detects only gaps of about 2–3 pp. The rest of this post builds that answer one step at a time on the 50% row, a gap of −0.735 pp, and then applies each step to all four rows.

#callout(kind: "info", title: [SETUP])[
  - *Tasks*: five non-generative (NG) tasks, ARC-Challenge and ARC-Easy among them: multiple choice, scored without generating text. `limit=200` questions per task or subtask, *1940 questions* per sparsity level.
  - *Runs*: at each level, the same pruned model, batch size 8 and default compile settings; only the 2-bit format differs.
  - *Pairing*: both formats saw the same 1940 questions, checked one by one by hashing each document and prompt.
  - *Score*: the mean over the five tasks, each weighted equally.
]

= Rerunning the Eval

The gap was measured on 1940 questions, but the tasks could have asked others. Call the gap over all the questions the tasks could ask the *true gap*. The measured gap is the true gap plus a *deviation* that depends on which 1940 questions happened to be drawn:

#mitex(`\text{measured gap} = \text{true gap} + \text{deviation}`)

"Real or noise?" then becomes: if the true gap were 0, could the deviation alone produce −0.735 pp?

Rerunning on fresh questions is not possible, but simulating it is. On each question _i_, write #mi(`d_i`) for Q2_K's score minus INT2's: +1 if only Q2_K is right, −1 if only INT2 is, and 0 if the two agree. The gap is the mean of the #mi(`d_i`), in pp. Now assume the formats are equally good: on 12.4% of questions exactly one of them is right, split evenly between the two, and on the rest they agree. (The 12.4% is chosen to match the 50% runs; Computing SE From One Run shows how.) Ten simulated reruns of 1940 questions give these gaps:

#mitex(`+0.36,\ -1.65,\ -0.21,\ +0.15,\ +1.08,\ -0.46,\ +0.36,\ -1.60,\ -0.41,\ +0.77\ \text{pp}`)

The true gap is 0, so each of these is pure deviation, and each comes from two formats that are equally good. They differ from rerun to rerun, and the −0.735 pp measured at 50% sits comfortably among them.

= Standard Error

To say how large the deviations typically are, square each one, average the squares and take the square root. The result is the *standard deviation*. On the ten reruns:

#figure(
  table(
    columns: 3,
    table.header([Rerun], [Deviation, pp], [Deviation², pp²]),
    [1], [+0.36], [0.13],
    [2], [−1.65], [2.72],
    [3], [−0.21], [0.04],
    [4], [+0.15], [0.02],
    [5], [+1.08], [1.17],
    [6], [−0.46], [0.21],
    [7], [+0.36], [0.13],
    [8], [−1.60], [2.56],
    [9], [−0.41], [0.17],
    [10], [+0.77], [0.59],
    [*Mean*], [], [*0.77*],
  ),
  caption: [The ten simulated reruns at 50% sparsity, true gap 0. Their standard deviation is #mi(`\sqrt{0.77} \approx 0.88`) pp.],
)

Ten reruns give a rough figure, 0.88 pp; 100,000 give 0.80 pp. *The standard deviation of the measured gap is its standard error* (SE). At 50% sparsity, SE ≈ 0.8 pp.

SE is the typical size of the deviation over many reruns, not the deviation of any one of them. Of the ten above, seven are smaller than 0.8 pp and three are larger, just as a group's average height need not be anyone's height.

Squaring keeps positive and negative deviations from cancelling. The mean absolute deviation would also measure the spread (0.71 pp on the ten), but the squared version has a property the SE formula relies on later: for independent quantities, squared spreads add.

In symbols, for a quantity _x_ with mean #mi(`\mathrm{E}[x]`):

#mitex(`\sigma = \sqrt{\mathrm{E}\big[(x - \mathrm{E}[x])^2\big]}`)

Here _x_ is the measured gap and #mi(`\mathrm{E}[x]`) is the true gap, since over many reruns the deviations average out to 0.

= How Often Noise Is This Large

SE gives the typical size of a deviation. "Could noise alone produce −0.735 pp?" asks something more specific: how often a deviation is at least that large. Counting over the 100,000 reruns:

#figure(
  table(
    columns: 3,
    table.header([\|Deviation\| at least], [Share of reruns], [Normal approximation]),
    [0.4 pp (0.5 SE)], [62.9%], [61.7%],
    [*0.735 pp (the 50% gap)*], [*35.0%*], [*35.8%*],
    [0.8 pp (1 SE)], [31.7%], [31.7%],
    [1.6 pp (2 SE)], [4.2%], [4.6%],
    [2.4 pp (3 SE)], [0.3%], [0.3%],
  ),
  caption: [Share of 100,000 simulated reruns at 50% sparsity (true gap 0, SE 0.8 pp) whose deviation is at least a given size, in either direction, and the share a normal distribution with the same SE gives.],
)

*Even if the two formats were equally good, 35% of reruns would give a gap at least as large as the one measured.* Noise alone explains −0.735 pp easily. Deviations beyond 2 SE are rare, and beyond 3 SE almost never happen.

== The Normal Approximation

The last column needed no simulation. One question's #mi(`d_i`) takes only three values, nothing like a bell. The gap is the mean of 1940 of them, and the *central limit theorem* says that the mean of many independent values is approximately *normally distributed*, whatever the distribution of each value:

#figure(fig.fig-reruns(), caption: [Left: one question's #mi(`d_i`) under the simulation's assumptions. Right: the gap, the mean of 1940 of them, over 100,000 simulated reruns. Dashed: a normal curve with standard deviation 0.8 pp.]) <fig-reruns>

The normal distribution is the bell curve, and two numbers fix it: its mean and its standard deviation. Every normal curve is the same shape, shifted and stretched, so the share of draws beyond _k_ standard deviations depends only on _k_: 31.7% beyond ±1, 5% beyond ±1.96, 0.27% beyond ±3. That is all the last column used: the SE, and the bell shape.

= z: The Gap in Units of SE

Measuring the gap in SE turns every comparison into the same question:

#mitex(`z = \frac{\text{gap}}{\text{SE}}`)

At 50% sparsity, _z_ = −0.735 / 0.793 = −0.93: the gap is 0.93 SE from zero.

If the true gap is 0, the gap is approximately normal with mean 0 and standard deviation SE, so _z_ is approximately normal with mean 0 and standard deviation 1. One table then serves every comparison:

#figure(
  table(
    columns: 2,
    table.header([Measured \|z\| at least], [Chance under no real difference]),
    [1], [31.7%],
    [1.96], [5%],
    [2.58], [1%],
    [3], [0.27%],
  ),
  caption: [How often noise alone produces a given |_z_|, from the normal distribution.],
)

That chance is the *p-value*: the share of reruns in which noise alone would produce a gap at least this large. At 50%, |_z_| = 0.93 gives p = 0.35, the 35% counted in the simulation. The convention: if the p-value is below 5%, the gap is *significant at the 0.05 level*. That is |_z_| ≥ 1.96, or about 2.

#figure(fig.fig-null(), caption: [Where the four measured gaps fall if the true gap is 0. Shaded orange: the 5% of outcomes beyond ±1.96.]) <fig-null>

All four rows sit inside ±1, well short of the threshold:

#figure(
  table(
    columns: 6,
    table.header([Sparsity], [Gap], [SE], [z], [p-value], [Verdict]),
    [40%], [+0.611 pp], [0.699 pp], [+0.87], [0.38], [not significant],
    [50%], [−0.735 pp], [0.793 pp], [−0.93], [0.35], [not significant],
    [60%], [−0.395 pp], [0.856 pp], [−0.46], [0.64], [not significant],
    [70%], [+0.677 pp], [1.045 pp], [+0.65], [0.52], [not significant],
  ),
  caption: [The test at each sparsity level. Each SE is computed from that level's runs, as the next section shows.],
)

If the two formats were identical, gaps this large would appear 35–64% of the time.

== Confidence Intervals

The same test can be read as an interval. *gap ± 1.96 SE* is the 95% confidence interval: the range of true gaps the measurement is consistent with. It contains 0 exactly when |_z_| < 1.96. At 50%, it runs from −0.735 − 1.55 = −2.29 pp to −0.735 + 1.55 = +0.82 pp.

#figure(fig.fig-forest(), caption: [95% confidence intervals for the four gaps. Every one contains 0.]) <fig-forest>

= Computing SE From One Run

#callout(kind: "info", title: [ONE RUN])[
  SE is defined over many reruns, but there is one run of each format. This section estimates the SE from that one run alone.
]

The simulation needed an assumption, the 12.4% of questions on which the formats disagree. A real run needs no assumption, because it already contains the reruns in small form. The gap is the mean of 1940 #mi(`d_i`), one per independently drawn question, and each question is a tiny rerun of its own:

- How much the #mi(`d_i`) differ from one question to the next shows how much one question's contribution varies.
- Averaging 1940 of them shrinks that variation by a factor of #mi(`\sqrt{1940}`).

*The spread between questions within the run stands in for the spread between reruns.* The rest of this section turns that into a formula.

== Per-Question Differences

Both formats answered the same questions, so each question gives one #mi(`d_i`):

#mitex(`d_i = a_i - b_i, \qquad a_i, b_i \in \{0, 1\}`)

where #mi(`a_i`) is 1 if Q2_K got question _i_ right and #mi(`b_i`) the same for INT2.

#figure(fig.fig-paired(), caption: [Ten questions. Only the three discordant ones carry information about the gap.]) <fig-paired>

- A question both formats get right, or both get wrong, has #mi(`d_i = 0`). It adds nothing to the gap and nothing to the noise.
- Only the *discordant* questions, right in one run and wrong in the other, move the gap and set the SE.

The gap is the mean of the #mi(`d_i`) (the five tasks are weighted equally; the last subsection handles that), so its SE is the SE of a mean.

== SE of a Mean

It takes three steps.

+ *Variances add.* The *variance* is the square of the standard deviation: the mean squared deviation, before the square root. For independent values it adds: the sum of _n_ values, each with variance #mi(`\sigma^2`), has variance #mi(`n\sigma^2`). Under the simulation's assumptions, one #mi(`d_i`) has mean 0 and variance #mi(`0.062 \cdot 1 + 0.876 \cdot 0 + 0.062 \cdot 1 = 0.124`), and two questions show the rule:

  #figure(
    table(
      columns: 3,
      table.header([], [Values (probability)], [Variance]),
      [#mi(`d_1`)], [−1, 0, +1 (6.2%, 87.6%, 6.2%)], [0.124],
      [#mi(`d_1 + d_2`)], [−2, −1, 0, +1, +2 (0.4%, 10.9%, 77.5%, 10.9%, 0.4%)], [0.248],
      [#mi(`(d_1 + d_2) / 2`)], [−1, −0.5, 0, +0.5, +1 (the same)], [0.062],
    ),
    caption: [One question's #mi(`d_i`), the sum of two and their mean, with 12.4% of questions discordant. The sum doubles the variance; halving the sum quarters it.],
  )

+ *Averaging divides the variance by _n_.* Dividing a quantity by _n_ divides every deviation by _n_, so its variance by #mi(`n^2`):

  #mitex(`\text{Var}(\bar{d}) = \frac{n\sigma^2}{n^2} = \frac{\sigma^2}{n}, \qquad \text{SE} = \frac{\sigma}{\sqrt{n}}`)

  With #mi(`\sigma^2 = 0.124`) and _n_ = 1940, #mi(`\text{SE} = \sqrt{0.124 / 1940} = 0.0080`), or 0.80 pp: the SE the 100,000 reruns gave. Averaging lets lucky and unlucky questions cancel, but slowly: four times the questions only halves the SE.

+ *Estimate #mi(`\sigma`) from the run.* #mi(`\sigma`) is the standard deviation of #mi(`d_i`) over all the questions the tasks could ask, and only _n_ of them are at hand. Their sample standard deviation #mi(`s_d`) stands in:

  #mitex(`s_d^2 = \frac{1}{n-1}\sum_{i=1}^{n} (d_i - \bar{d})^2, \qquad \text{SE} \approx \frac{s_d}{\sqrt{n}}`)

  Dividing by #mi(`n - 1`) rather than _n_ makes up for #mi(`\bar{d}`) being computed from the same values, which puts it closer to them than the true gap is. For large _n_ the two hardly differ.

#mi(`s_d`) describes one question and does not shrink as _n_ grows; only #mi(`\sqrt{n}`) does. Five times the questions gives #mi(`1/\sqrt{5} \approx 0.45`) times the SE.

On the ten questions of the figure above:

#mitex(`\bar{d} = 0.1, \quad s_d^2 = \frac{7(0 - 0.1)^2 + 2(1 - 0.1)^2 + (-1 - 0.1)^2}{9} = 0.32, \quad \text{SE} = \sqrt{0.32 / 10} = 0.18`)

A 10 pp gap with an 18 pp SE: _z_ = 0.56. Ten questions decide nothing.

Since #mi(`d_i^2`) is 1 on a discordant question and 0 elsewhere, #mi(`s_d^2 \approx p_\text{disc} - \bar{d}^2`), where #mi(`p_\text{disc}`) is the share of discordant questions. *When the gap is small, the variance is about the share of questions on which the two formats disagree.* That is how the simulation's 12.4% was chosen: a discordant share of 12.4% gives an SE of #mi(`\sqrt{0.124 / 1940}`) = 0.80 pp, close to the 0.79 pp computed from the 50% runs. It is also why the SE grows with sparsity, from 0.70 to 1.05 pp: the more aggressively the model is pruned, the more questions the two formats answer differently.

== Why Pairing Helps

Treating the two runs as independent samples would use

#mitex(`\text{Var}(a - b) = \text{Var}(a) + \text{Var}(b) - 2\,\text{Cov}(a, b)`)

without the last term. But an easy question tends to be right in both runs and a hard one wrong in both, so _a_ and _b_ are strongly correlated. The paired difference removes that shared difficulty; an independent-samples test counts it as noise.

At 50% sparsity, an independent-samples SE would be #mi(`\sqrt{(0.7146 \cdot 0.2854 + 0.7219 \cdot 0.2781) / 1940} \approx 1.4`) pp, *almost twice the paired 0.79*. The paired test can detect a gap little more than half as large.

== SE of the Five-Task Mean

The score is the mean of five tasks, each weighted 1/5:

#mitex(`\text{SE}_\text{mean} = \frac{1}{5}\sqrt{\sum_{k=1}^{5} \frac{s_k^2}{n_k}}`)

- #mi(`s_k^2 / n_k`) is the variance of task _k_'s mean gap.
- The tasks use different questions, so their variances add.
- Each enters the mean with weight 1/5, so its variance is multiplied by #mi(`(1/5)^2`).

#callout(kind: "warning", title: [WHEN THIS WORKS])[
  Estimating the SE from one run rests on three conditions. This eval meets all three; many others do too, but not all.

  - *The score is a mean of per-question scores*, as accuracy, exact match and pass\@1 are. A corpus-level metric such as corpus BLEU, classification F1 or AUC does not split into per-question terms; resample the questions with replacement many times, recompute the metric on each resample, and use the spread of the results (the *bootstrap*).
  - *Questions are independent.* Several questions on one passage, or several variants of one question, rise and fall together; compute the SE over those groups instead of over questions (a *clustered* SE).
  - *The only noise is which questions were drawn.* These tasks score log-likelihoods, so the same question gives the same result every time. With sampled generation, one question can be answered differently from run to run; that noise needs several samples per question, or several runs.

  Two parts are specific to this comparison. Pairing needs both formats on the same questions; on different questions, only the larger independent-samples SE is available. And #mi(`s_d^2 \approx p_\text{disc}`) holds only for 0/1 scores; with other scores, compute #mi(`s_d`) directly.
]

= Not Significant Is Not "Equal"

|_z_| < 2 says this eval cannot tell the two apart; it does not say they are equal. At 50%, the confidence interval runs from −2.29 to +0.82 pp: the runs are consistent with Q2_K being 2 pp worse, or nearly 1 pp better. A true gap of 0.5 pp would be hidden under 0.8 pp of noise.

How large must a true gap be to be detected *reliably*, conventionally 80% of the time (the test's *power*)? If the true gap is δ, the measured gap / SE is centred at δ / SE. It lands past 1.96 in 80% of reruns when δ / SE = 1.96 + 0.84:

#figure(fig.fig-power(), caption: [With a true gap of 2.8 SE, 80% of reruns measure a significant gap. With no gap, 2.5% do on each side.]) <fig-power>

#mitex(`\delta_\text{min} \approx (1.96 + 0.84)\,\text{SE} = 2.8\,\text{SE}`)

#figure(
  table(
    columns: 4,
    table.header([Sparsity], [SE], [Detectable gap, 2.8 × SE], [Measured \|gap\|]),
    [40%], [0.70 pp], [2.0 pp], [0.61 pp],
    [50%], [0.79 pp], [2.2 pp], [0.74 pp],
    [60%], [0.86 pp], [2.4 pp], [0.40 pp],
    [70%], [1.05 pp], [2.9 pp], [0.68 pp],
  ),
  caption: [The smallest true gap each level detects 80% of the time, against the gap measured.],
)

The measured gaps are a third of what this eval can detect, or less.

More questions help only as #mi(`\sqrt{n}`), taking SE = 0.8 pp at `limit=200`:

#figure(fig.fig-mde(), caption: [SE and detectable gap against questions per task, scaled from SE = 0.8 pp at `limit=200`.]) <fig-mde>

- `limit=1000`: SE ≈ 0.8 / #mi(`\sqrt{5}`) ≈ 0.36 pp, detectable gap ≈ *1.0 pp*.
- A 0.7 pp gap needs SE ≈ 0.25 pp: #mi(`(0.8 / 0.25)^2 \approx 10`) times the questions, about 2000 per task. ARC-Challenge's test split has 1172.

= Many Comparisons

Four sparsity levels × five tasks are 20 comparisons. At the 5% threshold, luck alone makes one of 20 "significant" on average even when nothing differs; the chance of at least one is #mi(`1 - 0.95^{20} \approx 64\%`), if the comparisons were independent.

The per-task gaps look like that. At 70% sparsity Q2_K is 6 pp ahead on ARC-Challenge and 2.5 pp behind on ARC-Easy. Each task has a fraction of the questions, so its SE is larger than the mean's, and its gap scatters further in both directions.

Two defences:

- *Demand more.* Divide 0.05 by the number of comparisons (the Bonferroni correction): 0.05 / 20 = 0.0025, which is |_z_| ≥ 3.0.
- *Look for consistency.* If there is no real difference, each level's sign is a coin flip. All four levels with the same sign happens with probability #mi(`2 \times (1/2)^4 = 0.125`), still not significant on its own. Here the signs split 2–2, which is what noise looks like.

= Rules of Thumb

+ Compute _z_ = gap / SE, with the SE from per-question paired differences.
+ |_z_| < 2: noise. 2 to 3: worth a second look. Above 3: fairly reliable.
+ Not significant means the eval is too small, not that the two are equal. The smallest gap it detects reliably is about 2.8 × SE.
+ With many comparisons, ask for more than 2, or check that several levels agree in sign.

For Q2_K against INT2: every |_z_| < 1 and the signs split 2–2. *At `limit=200`, the two formats are indistinguishable on accuracy*; to resolve a 1 pp gap, the eval needs about five times the questions.
