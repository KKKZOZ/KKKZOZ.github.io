// Figures for content/posts/ml-systems/math/eval-significance.typ, drawn with cetz.
// Same conventions as figures/cpu-gemv-bandwidth.typ: canvases in pt at
// 10-12pt text, `fig` scales each one to the text column, and colours come
// from the theme palette so that every figure follows the day / night switch.
// 1pt per unit, y grows upward.

#import "@preview/cetz:0.5.2" as cz
#import "@tola-modules/nasapunk:0.0.0": cetz
#let svg-frame = cetz.svg-frame
#import "@tola-modules/nasapunk:0.0.0": c
#import "@tola-modules/nasapunk:0.0.0": palette

#let c-blue = c.blue
#let c-blue-l = c.blue2
#let c-blue-p = c.blue1
#let c-orange = c.orange
#let c-orange-l = c.orange2
#let c-red = c.danger
#let c-muted = c.muted
#let c-rule = palette.rule
#let c-sand = palette.sand
#let c-gray = c.grey1

#let fig(s, body) = svg-frame(scale(s, reflow: true, body))
#let canvas(body) = cz.canvas(length: 1pt, body)

/// Standard normal density.
#let pdf(z) = calc.exp(-z * z / 2) / calc.sqrt(2 * calc.pi)

/// Points of a normal curve centred at `mu` (in SE units) over [a, b].
#let curve(mu, a, b, sx, sy, steps: 120) = range(steps + 1).map(k => {
  let z = a + (b - a) * k / steps
  (z * sx, pdf(z - mu) * sy)
})

/// The area under a normal curve centred at `mu` between a and b.
#let area(mu, a, b, sx, sy, paint) = {
  import cz.draw: *
  line(..curve(mu, a, b, sx, sy, steps: 60), (b * sx, 0), (a * sx, 0), close: true, fill: paint, stroke: none)
}

// ============================================================================
// Reruns: one question's d_i, and the gap over 1940 questions
// ============================================================================

// 100,000 simulated reruns at 50% sparsity under no real difference:
// n = 1940, each question discordant with probability 0.124, half each way
// (Python, random.seed(7), random.binomialvariate). The gap is k / 1940 with
// k = (+1 count) - (-1 count); bin j holds k in [4j - 2, 4j + 1], j = -16..16.
#let rerun-bins = (
  3, 4, 14, 39, 80, 175, 340, 656, 1151, 1928, 2950, 4320, 5951, 7490, 8955, 9762, 10283,
  9973, 9161, 7664, 6187, 4659, 3299, 2178, 1297, 741, 389, 188, 102, 39, 14, 5, 2,
)

#let fig-reruns() = fig(88%, canvas({
  import cz.draw: *
  let h = 110
  // Left: one question's d_i.
  let (wl, x0) = (110, 0)
  let probs = ((-1, 0.062), (0, 0.876), (1, 0.062))
  for (d, q) in probs {
    let x = x0 + (d + 1) / 2 * wl
    rect((x - 9, 0), (x + 9, q / 0.876 * h), fill: c-blue-l, stroke: none)
    content((x, q / 0.876 * h + 10), text(9pt)[#calc.round(q * 100, digits: 1)%])
    line((x, 0), (x, -4), stroke: .6pt + c-muted)
    content((x, -14), text(10pt)[#if d > 0 [+1] else if d < 0 [−1] else [0]])
  }
  line((x0 - 14, 0), (x0 + wl + 14, 0), stroke: .6pt + c-muted)
  content((x0 + wl / 2, h + 34), text(11pt, weight: "bold")[one question])
  content((x0 + wl / 2, -32), text(10pt, fill: c-muted)[$d_i$])
  // Right: the gap, the mean of 1940 of them.
  let (sx, xr) = (52, 330)
  let n = 1940
  let width = 4 / n * 100
  let total = rerun-bins.sum()
  let se = 0.8
  let peak = 1 / (se * calc.sqrt(2 * calc.pi))
  let sy = h / peak
  for (i, cnt) in rerun-bins.enumerate() {
    let j = i - 16
    let lo = (4 * j - 2.5) / n * 100
    let dens = cnt / (total * width)
    rect((xr + lo * sx + .4, 0), (xr + (lo + width) * sx - .4, dens * sy), fill: c-blue-l, stroke: none)
  }
  let pts = range(121).map(m => {
    let g = -3.2 + 6.4 * m / 120
    (xr + g * sx, pdf(g / se) / se * sy)
  })
  line(..pts, stroke: (paint: c-orange, dash: "dashed", thickness: 1.1pt))
  line((xr - 3.4 * sx, 0), (xr + 3.4 * sx, 0), stroke: .6pt + c-muted)
  for t in (-3, -2, -1, 0, 1, 2, 3) {
    line((xr + t * sx, 0), (xr + t * sx, -4), stroke: .6pt + c-muted)
    content((xr + t * sx, -14), text(10pt)[#if t > 0 [+]#t])
  }
  for s in (-1, 1) {
    line((xr + s * se * sx, 0), (xr + s * se * sx, h + 6), stroke: (paint: c-red, dash: "dotted", thickness: .9pt))
  }
  content((xr + se * sx + 4, h + 2), text(9pt, fill: c-red)[±1 SE = ±0.8], anchor: "west")
  content((xr - 2.3 * sx, 0.55 * h), text(10pt, fill: c-blue)[68% of reruns], anchor: "center")
  content((xr - 2.3 * sx, 0.55 * h - 13), text(10pt, fill: c-blue)[inside ±0.8], anchor: "center")
  content((xr, h + 34), text(11pt, weight: "bold")[the gap, mean of 1940])
  content((xr, -32), text(10pt, fill: c-muted)[measured gap, pp (true gap 0)])
}))

// ============================================================================
// z under no real difference
// ============================================================================

// (label, z) for the four sparsity levels, and the height of each label stem.
#let observed = (
  ([40%], 0.874, 150),
  ([50%], -0.927, 150),
  ([60%], -0.461, 178),
  ([70%], 0.648, 178),
)

#let fig-null() = fig(82%, canvas({
  import cz.draw: *
  let (sx, sy) = (62, 300)
  let lim = 3.6
  area(0, -1, 1, sx, sy, c-blue-p)
  area(0, 1.96, lim, sx, sy, c-orange-l)
  area(0, -lim, -1.96, sx, sy, c-orange-l)
  line(..curve(0, -lim, lim, sx, sy), stroke: 1.4pt + c-muted)
  line((-lim * sx, 0), (lim * sx, 0), stroke: .6pt + c-muted)
  for t in (-3, -2, -1, 0, 1, 2, 3) {
    line((t * sx, 0), (t * sx, -4), stroke: .6pt + c-muted)
    content((t * sx, -14), text(10pt)[#if t > 0 [+]#t])
  }
  content((0, -32), text(11pt, fill: c-muted)[$z$ = gap / SE])
  // significance thresholds
  for s in (-1, 1) {
    line((s * 1.96 * sx, 0), (s * 1.96 * sx, 112), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
    content((s * 2.75 * sx, 30), text(10pt, fill: c-orange, weight: "bold")[2.5%])
  }
  content((1.96 * sx + 4, 104), text(10pt, fill: c-red)[1.96], anchor: "west")
  content((-1.96 * sx - 4, 104), text(10pt, fill: c-red)[−1.96], anchor: "east")
  content((0.15 * sx, 34), text(10pt, fill: c-blue)[68%])
  content((0.15 * sx, 21), text(9pt, fill: c-blue)[in ±1])
  // the four measured gaps
  for (label, z, h) in observed {
    line((z * sx, 0), (z * sx, h - 8), stroke: .8pt + c-blue)
    circle((z * sx, 0), radius: 4, fill: c-blue, stroke: none)
    content((z * sx, h), text(10pt, weight: "bold", fill: c-blue, label))
  }
  content((lim * sx, 170), text(10pt, fill: c-muted)[if the true gap is 0,], anchor: "east")
  content((lim * sx, 155), text(10pt, fill: c-muted)[$z$ falls under this curve], anchor: "east")
}))

// ============================================================================
// Paired differences on ten questions
// ============================================================================

// (Q2_K score, INT2 score) per question
#let pairs = ((1, 1), (1, 1), (1, 0), (1, 1), (0, 0), (1, 1), (0, 1), (1, 1), (1, 0), (1, 1))

#let fig-paired() = fig(80%, canvas({
  import cz.draw: *
  let (w, h) = (30, 24)
  let rows = (([Q2_K $a_i$], 0), ([INT2 $b_i$], 1))
  for (i, (a, b)) in pairs.enumerate() {
    let x = i * w
    if a != b {
      rect((x, -2.7 * h), (x + w, 2 * h + 4), fill: c-sand, stroke: none)
    }
    content((x + w / 2, 2 * h + 14), text(9pt, fill: c-muted)[#(i + 1)])
    for (ri, (_, k)) in rows.enumerate() {
      let v = (a, b).at(k)
      let y = (1 - ri) * h
      rect(
        (x + 3, y + 2),
        (x + w - 3, y + h - 2),
        fill: if v == 1 { c-blue } else { white },
        stroke: .5pt + c-muted,
      )
      content((x + w / 2, y + h / 2), text(11pt, fill: if v == 1 { white } else { c-muted })[#v])
    }
    let d = a - b
    content(
      (x + w / 2, -h - 2),
      text(11pt, weight: if d != 0 { "bold" } else { "regular" }, fill: if d != 0 { c-orange } else { c-muted })[
        #if d > 0 [+1] else if d < 0 [−1] else [0]
      ],
    )
  }
  for (ri, (label, _)) in rows.enumerate() {
    content((-8, (1 - ri) * h + h / 2), text(11pt, label), anchor: "east")
  }
  line((0, -h / 2 + 4), (10 * w, -h / 2 + 4), stroke: .6pt + c-muted)
  content((-8, -h - 2), text(11pt)[$d_i = a_i - b_i$], anchor: "east")
  content((-8, 2 * h + 14), text(9pt, fill: c-muted)[question], anchor: "east")
  let rx = 10 * w + 18
  content((rx, 1.5 * h), text(11pt)[8 / 10 right], anchor: "west")
  content((rx, 0.5 * h), text(11pt)[7 / 10 right], anchor: "west")
  content((rx, -h - 2), text(11pt)[$overline(d) = (2 - 1) \/ 10 = +0.1$], anchor: "west")
  content((5 * w, -2.7 * h - 14), text(10pt, fill: c-orange)[shaded: discordant, the only questions with $d_i != 0$])
}))

// ============================================================================
// Confidence intervals
// ============================================================================

// (label, gap, SE, z), in pp
#let ng-rows = (
  ([40%], 0.611, 0.699, [+0.87]),
  ([50%], -0.735, 0.793, [−0.93]),
  ([60%], -0.395, 0.856, [−0.46]),
  ([70%], 0.677, 1.045, [+0.65]),
)

#let fig-forest() = fig(82%, canvas({
  import cz.draw: *
  let sx = 36
  let (xa, xb) = (-3, 3)
  let groups = (([Q2_K − INT2, accuracy], ng-rows),)
  let y = 0
  let ys = ()
  // lay the rows out from the top down
  for (gi, (title, rows)) in groups.enumerate() {
    ys.push((title, y))
    y -= 20
    for row in rows {
      ys.push((row, y))
      y -= 22
    }
    y -= 8
  }
  let bottom = y + 14
  for t in range(xa, xb + 1) {
    line((t * sx, bottom), (t * sx, 10), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
    content((t * sx, bottom - 12), text(10pt)[#if t > 0 [+]#t])
  }
  line((0, bottom), (0, 10), stroke: 1pt + c-muted)
  content((0, bottom - 30), text(11pt, fill: c-muted)[pp · bars: gap ± 1.96 SE])
  for (item, y) in ys {
    // `content` is shadowed by cetz's draw function here, so test for rows
    if type(item) != array {
      content((xa * sx - 70, y), text(11pt, weight: "bold", item), anchor: "west")
      continue
    }
    let (label, gap, se, z) = item
    let (lo, hi) = (gap - 1.96 * se, gap + 1.96 * se)
    let sig = lo > 0 or hi < 0
    let paint = if sig { c-orange } else { c-blue }
    content((xa * sx - 8, y), text(11pt, label), anchor: "east")
    line((lo * sx, y), (hi * sx, y), mark: (start: "|", end: "|"), stroke: 1.2pt + paint)
    circle((gap * sx, y), radius: 4, fill: paint, stroke: none)
    content((xb * sx + 8, y), text(10pt, fill: paint)[$z$ = #z], anchor: "west")
  }
}))

// ============================================================================
// Power: how big a true gap must be
// ============================================================================

#let fig-power() = fig(84%, canvas({
  import cz.draw: *
  let (sx, sy) = (50, 300)
  let (a, b) = (-3.4, 6.2)
  let mu = 2.8
  area(mu, 1.96, b, sx, sy, c-blue-p)
  area(0, 1.96, b, sx, sy, c-orange-l)
  line(..curve(0, a, b, sx, sy), stroke: 1.3pt + c-muted)
  line(..curve(mu, a, b, sx, sy), stroke: 1.3pt + c-blue)
  line((a * sx, 0), (b * sx, 0), stroke: .6pt + c-muted)
  for t in (-3, -2, -1, 0, 1, 2, 3, 4, 5, 6) {
    line((t * sx, 0), (t * sx, -4), stroke: .6pt + c-muted)
    content((t * sx, -14), text(10pt)[#t])
  }
  content((1.4 * sx, -32), text(11pt, fill: c-muted)[measured gap / SE])
  // threshold
  line((1.96 * sx, 0), (1.96 * sx, 150), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
  content((1.96 * sx, 158), text(10pt, fill: c-red)[significant →])
  // curve labels
  content((-1.2 * sx, 112), text(10pt, fill: c-muted)[true gap 0], anchor: "east")
  content((4.1 * sx, 112), text(10pt, fill: c-blue)[true gap 2.8 SE], anchor: "west")
  content((3.6 * sx, 46), text(10pt, weight: "bold", fill: c-blue)[80%])
  // 1.96 + 0.84 = 2.8
  let yb = 186
  line((0, yb), (1.96 * sx, yb), mark: (start: "|", end: "|"), stroke: .9pt + c-muted)
  content((0.98 * sx, yb + 11), text(10pt)[1.96])
  line((1.96 * sx, yb), (mu * sx, yb), mark: (end: "|"), stroke: .9pt + c-blue)
  content((2.38 * sx, yb + 11), text(10pt, fill: c-blue)[0.84])
  line((0, 0), (0, yb), stroke: (paint: c-rule, dash: "dotted", thickness: .5pt))
  line((mu * sx, 0), (mu * sx, yb), stroke: (paint: c-rule, dash: "dotted", thickness: .5pt))
}))

// ============================================================================
// Detectable gap against eval size
// ============================================================================

#let fig-mde() = fig(80%, canvas({
  import cz.draw: *
  let (sx, sy) = (0.2, 40)
  let (xmax, ymax) = (2100, 4)
  let se(n) = 0.8 * calc.sqrt(200 / n)
  // observed |gap| band
  rect((100 * sx, 0.395 * sy), (xmax * sx, 0.735 * sy), fill: c-sand, stroke: none)
  content((1300 * sx, 0.565 * sy), text(9pt, fill: c-muted)[measured |gaps| 0.40–0.74])
  line((0, 0), (xmax * sx, 0), stroke: .6pt + c-muted)
  line((0, 0), (0, ymax * sy), stroke: .6pt + c-muted)
  for t in (1, 2, 3, 4) {
    line((0, t * sy), (xmax * sx, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
    content((-6, t * sy), text(10pt)[#t], anchor: "east")
  }
  for n in (200, 500, 1000, 1500, 2000) {
    content((n * sx, -12), text(10pt)[#n])
  }
  content((xmax * sx / 2, -30), text(11pt, fill: c-muted)[questions per task (`limit`)])
  content((-28, ymax * sy / 2), text(11pt, fill: c-muted)[pp], angle: 90deg)
  let ns = range(100, 2101, step: 20)
  line(..ns.map(n => (n * sx, 2.8 * se(n) * sy)), stroke: 1.4pt + c-orange)
  line(..ns.map(n => (n * sx, se(n) * sy)), stroke: 1.2pt + c-blue)
  content((240 * sx, 3.05 * sy), text(10pt, fill: c-orange, weight: "bold")[detectable gap = 2.8 × SE], anchor: "west")
  content((300 * sx, 1.0 * sy), text(10pt, fill: c-blue, weight: "bold")[SE], anchor: "south-west")
  for (n, lab) in ((200, [2.2]), (1000, [1.0]), (2050, [0.7])) {
    circle((n * sx, 2.8 * se(n) * sy), radius: 3.5, fill: c-orange, stroke: none)
    content((n * sx + 6, 2.8 * se(n) * sy + 9), text(10pt, fill: c-orange, lab), anchor: "west")
    circle((n * sx, se(n) * sy), radius: 3, fill: c-blue, stroke: none)
  }
}))
