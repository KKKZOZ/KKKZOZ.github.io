// Figures for content/posts/journal/weekly-2026-11-23.typ, drawn with cetz.
// True scale (1pt per unit, y grows upward, under ~560pt wide), colours from
// the theme kit so every figure follows the day / night switch. Data are
// copied from the expbook entries each figure cites.

#import "@tola-modules/nasapunk:0.0.0": cetz, c, palette, txt, tag

#let paper = palette.paper
#let grid-stroke = (paint: c.hair, thickness: .5pt, dash: "dotted")
#let axis-stroke = .6pt + c.line
#let canvas(body) = cetz.canvas(length: 1pt, body)
#let lbl(body, size: 8pt, fill: c.ink, weight: 400) = txt(body, size: size, fill: fill, weight: weight)
#let log10(v) = calc.log(v, base: 10)
#let num(v, digits: 1) = str(calc.round(v, digits: digits))

/// First x at which the piecewise-linear series (xs, ys) falls to `target`.
#let crossing(xs, ys, target) = {
  for i in range(xs.len() - 1) {
    let (a, b) = (ys.at(i), ys.at(i + 1))
    if a >= target and b <= target {
      return xs.at(i) + (a - target) / (a - b) * (xs.at(i + 1) - xs.at(i))
    }
  }
  none
}

/// A polyline with a marker on every point.
#let series(pts, color, dash: none, marker: "circle", w: 1.2pt) = {
  import cetz.draw: *
  line(..pts, stroke: (paint: color, thickness: w, dash: dash, join: "round"))
  for p in pts {
    let (x, y) = p
    if marker == "circle" { circle(p, radius: 2.3, fill: color, stroke: .6pt + paper) }
    if marker == "square" { rect((x - 2.3, y - 2.3), (x + 2.3, y + 2.3), fill: color, stroke: .6pt + paper) }
    if marker == "hollow" { circle(p, radius: 2.4, fill: paper, stroke: 1pt + color) }
  }
}

/// Horizontal bars: (label, value, fill, note); sx = pt per unit.
#let hbars(rows, sx, unit: none) = canvas({
  import cetz.draw: *
  let n = rows.len()
  for (i, (label, v, fill, note)) in rows.enumerate() {
    let y = (n - 1 - i) * 20
    content((-8, y + 7), lbl(label), anchor: "east")
    rect((0, y), (v * sx, y + 14), fill: fill, stroke: .5pt + c.line)
    content((v * sx + 5, y + 7), txt(note), anchor: "west")
  }
  line((0, -4), (0, n * 20), stroke: axis-stroke)
  if unit != none { content((0, -12), txt(unit, size: 7.5pt), anchor: "west") }
})

#let arw(..pts, color: c.line, dash: none) = cetz.draw.line(
  ..pts,
  stroke: (paint: color, thickness: .8pt, dash: dash),
  mark: (end: "stealth", fill: color, scale: .5),
)

// ============================================================================
// 0. Recap (reports of Oct 13, 20 and 23)
// ============================================================================

// Prox as an MoE: Stage 1 routes over 12288 width-1 experts, Stage 2 runs the chosen ones.
#let fig-prox() = canvas({
  import cetz.draw: *
  rect((0, 40), (26, 64), fill: c.grey1, stroke: .6pt + c.line, radius: 2)
  content((13, 52), lbl($x$))
  arw((26, 52), (44, 52))
  rect((44, 30), (150, 74), fill: c.orange1, stroke: .7pt + c.orange, radius: 2)
  content((97, 62), lbl([Stage 1 · router], weight: 600))
  content((97, 42), align(center, txt(size: 7.5pt)[INT2 proxy \ scores all 12288]))
  arw((150, 52), (172, 52))
  content((161, 56), txt(size: 7pt, fill: c.orange)[mask], anchor: "south")
  rect((172, 22), (446, 82), fill: none, stroke: (paint: c.blue, thickness: .7pt, dash: "dashed"), radius: 2)
  content((308, 90), lbl([Stage 2 · run the selected width-1 experts, original weights], weight: 600), anchor: "south")
  let names = ([E#sub[1]], [E#sub[2]], [E#sub[3]], [E#sub[4]], [E#sub[5]], [E#sub[6]], [E#sub[7]], none, [E#sub[12288]])
  let chosen = (0, 2, 3, 5, 8)
  for (i, name) in names.enumerate() {
    let x = 180 + i * 29
    if name == none {
      content((x + 12, 52), lbl[⋯])
    } else {
      let on = i in chosen
      let x1 = if i == 8 { x + 30 } else { x + 24 }
      rect((x, 36), (x1, 68), fill: if on { c.blue } else { c.grey1 }, stroke: .5pt + if on { c.blue } else { c.line }, radius: 1.5)
      content(((x + x1) / 2, 52), lbl(name, size: if i == 8 { 6.5pt } else { 7.5pt }, fill: if on { paper } else { c.muted }))
    }
  }
  arw((446, 52), (460, 52))
  circle((471, 52), radius: 10, fill: paper, stroke: .7pt + c.line)
  content((471, 52), lbl($Sigma$))
  arw((481, 52), (497, 52))
  content((501, 52), lbl($y$), anchor: "west")
  arw((13, 40), (13, 8), (308, 8), (308, 22), color: c.muted)
  content((160, 4), txt(size: 7pt)[each expert: one Gate column, one Up column, one Down row; computed from _x_], anchor: "north")
})

// FFN block latency, Qwen3-8B, A6000, batch 1 (Nov 7 report). Optimal: a compact
// dense FFN that keeps the same channels.
#let fig-prox-ffn() = canvas({
  import cetz.draw: *
  let data = ((40, 290.6, 270.4), (50, 233.2, 228.2), (60, 191.1, 191.9), (70, 157.8, 159.4))
  let dense = 453.6
  let sy = 0.26
  content((-30, 500 * sy + 12), tag[FFN block latency], anchor: "west")
  content((-6, 500 * sy - 6), txt(size: 7.5pt)[µs], anchor: "east")
  for t in (100, 200, 300, 400) {
    line((0, t * sy), (330, t * sy), stroke: grid-stroke)
    content((-6, t * sy), lbl(str(t), size: 7.5pt), anchor: "east")
  }
  line((0, 0), (330, 0), stroke: axis-stroke)
  line((0, dense * sy), (330, dense * sy), stroke: (paint: c.danger, thickness: .9pt, dash: "dashed"))
  content((334, dense * sy), txt(size: 7.5pt, fill: c.danger)[dense, 454], anchor: "west")
  for (i, (s, opt, prox)) in data.enumerate() {
    let x = 22 + i * 80
    rect((x, 0), (x + 24, opt * sy), fill: c.grey2, stroke: none)
    rect((x + 26, 0), (x + 50, prox * sy), fill: c.blue, stroke: none)
    content((x + 12, opt * sy + 3), lbl(str(calc.round(opt)), size: 7pt), anchor: "south")
    content((x + 38, prox * sy + 3), lbl(str(calc.round(prox)), size: 7pt, fill: c.blue, weight: 600), anchor: "south")
    content((x + 25, -11), lbl(str(s) + "%", size: 7.5pt))
  }
  content((165, -25), txt[sparsity, Stage 1 counted in the budget])
  rect((334, 70), (345, 78), fill: c.grey2, stroke: none)
  content((349, 74), txt[compact dense FFN], anchor: "west")
  rect((334, 54), (345, 62), fill: c.blue, stroke: none)
  content((349, 58), txt[Prox, both stages], anchor: "west")
})

// GPU-only Prox against Stage 1 on the CPU, not to scale. The GPU time Stage 1
// used goes to Stage 2.
#let fig-recap-timeline() = canvas({
  import cetz.draw: *
  let h = 20
  let block(x0, x1, y, body, fill, stroke, ink: c.ink) = {
    rect((x0, y), (x1, y + h), fill: fill, stroke: stroke, radius: 2)
    content(((x0 + x1) / 2, y + h / 2), lbl(body, size: 7.5pt, fill: ink, weight: 600))
  }
  let (ya, yg, yc) = (124, 56, 18)
  content((0, ya + h + 14), lbl([(a) Prox: both stages on the GPU], weight: 600), anchor: "west")
  content((-8, ya + h / 2), lbl("GPU", size: 7.5pt), anchor: "east")
  block(0, 130, ya, [attn#sub[i]], c.blue2, .7pt + c.blue)
  block(130, 180, ya, [Stage 1], c.orange1, .7pt + c.orange)
  block(180, 380, ya, [Stage 2 · keeps 26% of channels], c.blue1, .7pt + c.blue)
  content((130, ya - 4), txt(size: 7pt)[exact FFN input ready], anchor: "north")
  content((0, yg + h + 14), lbl([(b) Stage 1 on the CPU, from an early input], weight: 600), anchor: "west")
  content((-8, yg + h / 2), lbl("GPU", size: 7.5pt), anchor: "east")
  content((-8, yc + h / 2), lbl("CPU", size: 7.5pt), anchor: "east")
  block(0, 14, yg, [], c.teal1, .7pt + c.teal)
  block(14, 144, yg, [attn#sub[i]], c.blue2, .7pt + c.blue)
  block(144, 380, yg, [Stage 2 · keeps 30% of channels], c.blue1, .7pt + c.blue)
  block(24, 136, yc, [Stage 1#sub[i]], c.orange, .7pt + c.orange, ink: paper)
  arw((10, yg), (26, yc + h), color: c.teal)
  content((20, yc - 4), txt(size: 7pt, fill: c.teal)[Attn_prox#sub[i]], anchor: "north-east")
  arw((136, yc + h), (146, yg), color: c.orange)
  content((150, yc + h), txt(size: 7pt, fill: c.orange)[mask#sub[i]], anchor: "west")
  line((24, yc - 18), (24, yc - 22), (144, yc - 22), (144, yc - 18), stroke: .6pt + c.line)
  content((84, yc - 26), lbl([must end before attn#sub[i] does], size: 7.5pt), anchor: "north")
  line((380, yc + 4), (380, ya + h + 4), stroke: (paint: c.muted, thickness: .6pt, dash: "dotted"))
  content((384, ya + h / 2), txt(size: 7pt)[same end], anchor: "west")
  content((384, yg + h / 2), txt(size: 7pt)[same end], anchor: "west")
})

// Where each router input for FFN_i is taken on the GPU timeline (not to
// scale), and its Top-30% overlap (Qwen3-8B, 8K, INT2 proxy, s1 = 0).
#let fig-recap-router() = canvas({
  import cetz.draw: *
  let (h, ty, sy, bw) = (20, 134, 1.4, 24)
  let block(x0, x1, body, fill, stroke) = {
    rect((x0, ty), (x1, ty + h), fill: fill, stroke: stroke, radius: 2)
    content(((x0 + x1) / 2, ty + h / 2), lbl(body, size: 7.5pt, weight: 600))
  }
  block(0, 100, [attn#sub[i−1]], c.blue2, .7pt + c.blue)
  block(100, 205, [FFN#sub[i−1]], c.blue1, .7pt + c.blue)
  block(205, 250, [], c.teal1, .7pt + c.teal)
  block(250, 350, [attn#sub[i]], c.blue2, .7pt + c.blue)
  block(350, 470, [FFN#sub[i]], c.blue1, .7pt + c.blue)
  content((227.5, ty + h / 2), txt(size: 6.5pt, fill: c.teal)[prox])
  line((250, ty + h + 4), (250, ty + h + 8), (350, ty + h + 8), (350, ty + h + 4), stroke: .6pt + c.orange)
  content((300, ty + h + 11), txt(size: 7pt, fill: c.orange)[CPU Stage 1 must fit here], anchor: "south")
  let taps = (
    (100, 62.74, c.grey1, [Attn#sub[i−1]], -10),
    (205, 70.37, c.blue2, [FFN#sub[i−1]], -10),
    (250, 77.14, c.orange, [*Attn_prox#sub[i]*], -22),
    (350, 78.66, c.grey2, [Attn#sub[i]: too late], -10),
  )
  line((40, 0), (420, 0), stroke: axis-stroke)
  for (x, v, fill, name, ny) in taps {
    let top = v * sy
    rect((x - bw / 2, 0), (x + bw / 2, top), fill: fill, stroke: .5pt + c.line)
    content((x, top + 3), lbl(num(v) + "%", size: 7pt, weight: if fill == c.orange { 600 } else { 400 }), anchor: "south")
    line((x, ty), (x, top + 14), stroke: (paint: c.muted, thickness: .6pt, dash: "dotted"))
    circle((x, ty), radius: 1.8, fill: c.ink, stroke: none)
    content((x, ny), lbl(name, size: 7.5pt), anchor: "north")
  }
})

#let fig-recap-m4() = canvas({
  import cetz.draw: *
  let rows = (
    ([dense], 27.9, c.grey2, [27.9]),
    ([overlap], 41.0, c.orange, [*41.0*: 58% of Stage 1 hidden]),
    ([serial], 58.7, c.orange2, [58.7]),
  )
  let sx = 6
  let n = rows.len()
  for (i, (label, v, fill, note)) in rows.enumerate() {
    let y = (n - 1 - i) * 20
    content((-8, y + 7), lbl(label, weight: 600), anchor: "east")
    rect((0, y), (v * sx, y + 14), fill: fill, stroke: .5pt + c.line)
    content((v * sx + 5, y + 7), txt(note), anchor: "west")
  }
  line((0, -4), (0, n * 20), stroke: axis-stroke)
  content((0, -12), txt(size: 7.5pt)[ms per token · Qwen3-8B, 8K context, M4 Pro], anchor: "west")
  // What each row runs.
  let defs = (
    ([dense], [no Prox: the dense FFN, all on the GPU]),
    ([overlap], [the CPU computes Stage 1 #emph[while] the GPU computes attention; the GPU then waits for the mask]),
    ([serial], [the GPU computes attention, #emph[then] waits while the CPU computes Stage 1]),
  )
  for (i, (k, d)) in defs.enumerate() {
    let y = -32 - i * 12
    content((-8, y), lbl(k, size: 7.5pt, weight: 600), anchor: "east")
    content((0, y), txt(size: 7.5pt, fill: c.ink, d), anchor: "west")
  }
})

// TEAL vs. WINA on six toy inputs: same budget (keep 3), different channels kept
// (Oct 20 report).
#let fig-wina-score() = canvas({
  import cetz.draw: *
  let xs = (0.9, 0.2, 0.7, 0.4, 0.15, 0.6)
  let ws = (0.5, 3.0, 0.6, 2.0, 1.0, 1.5)
  let panel(x0, title, vals, keep, norms: false) = {
    content((x0 + 88, 92), lbl(title, weight: 600))
    line((x0 - 4, 0), (x0 + 180, 0), stroke: axis-stroke)
    for i in range(6) {
      let x = x0 + i * 30
      let on = i in keep
      rect((x, 0), (x + 22, vals.at(i) * 80), fill: if on { c.blue } else { c.grey1 }, stroke: .5pt + if on { c.blue } else { c.line })
      content((x + 11, -9), lbl(str(i + 1), size: 7pt, fill: c.muted))
      if norms { content((x + 11, -21), lbl(str(ws.at(i)), size: 7pt, fill: c.orange)) }
    }
  }
  panel(0, [TEAL: $|x_i|$], xs, (0, 2, 5))
  panel(250, [WINA: $|x_i| dot norm(W_(i,:))$], xs.zip(ws).map(p => p.at(0) * p.at(1)), (1, 3, 5), norms: true)
  arw((192, 36), (238, 36))
  content((215, 42), txt(size: 7.5pt, fill: c.orange)[$times norm(W_(i,:))$], anchor: "south")
  content((246, -21), txt(size: 7pt, fill: c.orange)[$norm(W_(i,:))$], anchor: "east")
  content((-6, -9), txt(size: 7pt)[input], anchor: "east")
  rect((120, -42), (130, -34), fill: c.blue, stroke: none)
  content((134, -38), txt[kept (top 3)], anchor: "west")
  rect((220, -42), (230, -34), fill: c.grey1, stroke: .5pt + c.line)
  content((234, -38), txt[dropped], anchor: "west")
})

// ============================================================================
// 1. WINA's norm term
// ============================================================================

// PPL from the exact-s ablation (same 65,536 tokens); NG difference from the
// limit=1000 rerun, whiskers = ±1.96 SE.
#let fig-wina-quality() = canvas({
  import cetz.draw: *
  let sp = (40, 50, 60, 70)
  let (w, h) = (170, 120)
  let X(s) = (s - 35) / 40 * w
  let xaxis(dx) = {
    for s in sp {
      line((dx + X(s), 0), (dx + X(s), -3), stroke: axis-stroke)
      content((dx + X(s), -11), lbl(str(s) + "%", size: 7.5pt))
    }
    content((dx + w / 2, -25), txt[channels dropped])
  }

  // Panel A: PPL
  let Y(v) = (v - 8.1) / 0.35 * h
  content((-30, h + 18), tag[PPL · lower is better], anchor: "west")
  for (v, s) in ((8.1, "8.10"), (8.2, "8.20"), (8.3, "8.30"), (8.4, "8.40")) {
    line((0, Y(v)), (w, Y(v)), stroke: if v == 8.1 { axis-stroke } else { grid-stroke })
    content((-5, Y(v)), lbl(s, size: 7.5pt), anchor: "east")
  }
  xaxis(0)
  line((0, Y(8.183)), (w, Y(8.183)), stroke: (paint: c.muted, thickness: .7pt, dash: "dashed"))
  content((w + 4, Y(8.183)), txt[dense 8.183], anchor: "west")
  let mag = (8.172, 8.203, 8.244, 8.405)
  let wn = (8.156, 8.165, 8.186, 8.27)
  series(sp.zip(mag).map(((s, v)) => (X(s), Y(v))), c.blue)
  series(sp.zip(wn).map(((s, v)) => (X(s), Y(v))), c.orange, marker: "square")
  content((X(70) - 4, Y(8.405)), lbl("magnitude", fill: c.blue, weight: 600), anchor: "east")
  content((X(70) + 6, Y(8.27) - 2), lbl("weight-norm", fill: c.orange, weight: 600), anchor: "north-west")

  // Panel B: NG difference
  let dx = w + 120
  let (d0, d1) = (-0.9, 0.4)
  let Yd(v) = (v - d0) / (d1 - d0) * h
  content((dx - 30, h + 18), tag[NG mean · weight-norm − magnitude (pp)], anchor: "west")
  for (v, s) in ((-0.8, "−0.8"), (-0.4, "−0.4"), (0, "0"), (0.4, "+0.4")) {
    line((dx, Yd(v)), (dx + w, Yd(v)), stroke: if v == 0 { .8pt + c.ink } else { grid-stroke })
    content((dx - 5, Yd(v)), lbl(s, size: 7.5pt), anchor: "east")
  }
  line((dx, 0), (dx + w, 0), stroke: axis-stroke)
  xaxis(dx)
  for (s, d, se) in ((40, -0.171, 0.153), (50, -0.114, 0.181), (60, -0.358, 0.224), (70, -0.23, 0.296)) {
    let x = dx + X(s)
    let (lo, hi) = (d - 1.96 * se, d + 1.96 * se)
    line((x, Yd(lo)), (x, Yd(hi)), stroke: 1pt + c.orange)
    for e in (lo, hi) { line((x - 3, Yd(e)), (x + 3, Yd(e)), stroke: 1pt + c.orange) }
    rect((x - 2.6, Yd(d) - 2.6), (x + 2.6, Yd(d) + 2.6), fill: c.orange, stroke: .6pt + paper)
    content((x + 5, Yd(d)), lbl(num(d, digits: 2), size: 7pt), anchor: "west")
  }
  content((dx + w + 6, Yd(0)), txt(size: 7pt)[no difference], anchor: "west")
  content((dx + w + 6, Yd(0.25)), txt(size: 7pt, fill: c.orange)[↑ weight-norm better], anchor: "west")
  content((dx + w + 6, Yd(-0.3)), txt(size: 7pt, fill: c.blue)[↓ magnitude better], anchor: "west")
})

// Per-layer coefficient of variation of the Down column norms.
#let cv-data = (
  ("Qwen3-8B", c.orange, none, (
    0.039, 0.776, 0.903, 0.747, 0.254, 0.063, 0.039, 0.04, 0.04, 0.054, 0.056, 0.059, 0.066, 0.084, 0.087, 0.09,
    0.09, 0.092, 0.09, 0.091, 0.093, 0.096, 0.102, 0.092, 0.077, 0.072, 0.066, 0.066, 0.068, 0.064, 0.063, 0.061,
    0.06, 0.07, 0.106, 0.209,
  )),
  ("Qwen3-4B", c.blue, none, (
    0.033, 0.598, 0.738, 0.446, 0.133, 0.057, 0.045, 0.049, 0.048, 0.066, 0.063, 0.063, 0.076, 0.098, 0.104, 0.105,
    0.106, 0.11, 0.108, 0.109, 0.114, 0.118, 0.125, 0.113, 0.098, 0.09, 0.082, 0.08, 0.081, 0.076, 0.074, 0.07,
    0.07, 0.082, 0.125, 0.213,
  )),
  ("Qwen3.5-9B", c.teal, "dashed", (
    0.032, 0.028, 0.028, 0.026, 0.031, 0.037, 0.037, 0.035, 0.039, 0.043, 0.059, 0.061, 0.063, 0.066, 0.071, 0.082,
    0.086, 0.089, 0.106, 0.102, 0.081, 0.074, 0.086, 0.073, 0.064, 0.063, 0.064, 0.072, 0.079, 0.085, 0.12, 0.201,
  )),
  ("Llama-3-8B-Instruct", c.ink, none, (
    0.035, 0.037, 0.043, 0.047, 0.046, 0.043, 0.05, 0.057, 0.06, 0.058, 0.057, 0.064, 0.072, 0.068, 0.073, 0.066,
    0.06, 0.056, 0.048, 0.044, 0.043, 0.044, 0.039, 0.036, 0.035, 0.037, 0.043, 0.05, 0.066, 0.091, 0.133, 0.185,
  )),
)

#let fig-wina-cv() = canvas({
  import cetz.draw: *
  let (w, h) = (420, 150)
  let X(l) = l / 35 * w
  let (lo, hi) = (0.02, 1)
  let Y(v) = (log10(v) - log10(lo)) / (log10(hi) - log10(lo)) * h
  content((-34, h + 16), tag[Down column-norm CV per layer (log)], anchor: "west")
  for (v, s) in ((0.02, "0.02"), (0.05, "0.05"), (0.1, "0.1"), (0.2, "0.2"), (0.5, "0.5"), (1, "1")) {
    line((0, Y(v)), (w, Y(v)), stroke: if v == lo { axis-stroke } else { grid-stroke })
    content((-6, Y(v)), lbl(s, size: 7.5pt), anchor: "east")
  }
  line((0, Y(0.15)), (w, Y(0.15)), stroke: (paint: c.danger, thickness: .7pt, dash: "dashed"))
  content((w + 4, Y(0.15)), txt(size: 7pt, fill: c.danger)[CV = 0.15], anchor: "west")
  for (_, color, dash, vals) in cv-data {
    let pts = vals.enumerate().map(((l, v)) => (X(l), Y(v)))
    line(..pts, stroke: (paint: color, thickness: 1.1pt, dash: dash, join: "round"))
    for p in pts { circle(p, radius: 1.5, fill: color, stroke: .5pt + paper) }
  }
  for l in range(0, 36, step: 5) {
    line((X(l), 0), (X(l), -3), stroke: axis-stroke)
    content((X(l), -11), lbl("L" + str(l), size: 7.5pt))
  }
  content((w / 2, -25), txt[decoder layer])
  for (i, (name, color, dash, _)) in cv-data.enumerate() {
    let lx = 20 + i * 100
    line((lx, -42), (lx + 14, -42), stroke: (paint: color, thickness: 1.4pt, dash: dash))
    content((lx + 18, -42), lbl(name, size: 7.5pt), anchor: "west")
  }
})

// ============================================================================
// 2. Mask quality
// ============================================================================

// Dense Top-30% by dense rank segment: miss rate and where each missed
// channel lands in the proxy ranking (shares of the misses, sum 100).
// Why misses at the threshold are cheap. 40 channels with exponential |y|
// (quantiles of Laplace y), sorted; keep the top 30%. The proxy's noise moves an
// estimate by about sigma, so only channels within sigma of tau can cross it.
// Threshold scatter: 300 channels, Laplace y (scale 1), unit Gaussian noise
// (seed 3, generated offline). Stage 1 sees |y + s * rms(y) * e|.
#let thr-y = (-0.742, 0.093, -0.301, 0.233, 0.290, -2.032, -3.637, 1.124, -0.656, -0.758, 4.743, -0.061, 1.118, -0.048, 0.326, -1.200, 0.314, 1.332, 0.047, 0.659, 0.420, -2.055, 0.727, 0.201, -0.507, -2.780, 1.313, -0.056, 0.576, 1.417, 0.559, 1.846, -0.236, 0.921, -0.117, 2.049, 1.418, -1.635, -1.302, -0.835, 2.673, -0.137, 0.292, -0.507, 0.015, -0.259, -0.354, 0.187, 0.185, 1.652, 0.453, 1.951, 1.248, 4.016, 0.419, -1.120, 1.278, 2.649, 1.658, 0.149, 0.558, -0.862, 1.088, 0.159, -0.562, -2.064, 1.231, 3.893, -1.731, 0.919, -0.197, -1.199, -0.531, 0.771, 1.369, -2.426, 0.260, -2.409, 0.574, -0.413, 1.435, 3.251, 0.011, 5.815, -0.479, -1.871, 0.223, -2.769, -0.929, -0.203, 0.250, -1.163, -2.467, 1.330, -0.466, 2.493, 1.577, -0.280, -0.082, 0.041, 0.339, 0.212, 0.126, 0.275, 2.131, 0.014, -0.148, 0.581, -0.744, -0.507, 3.114, 0.043, 0.102, -3.776, -0.186, 0.174, -3.216, 0.263, 0.307, -2.119, 0.294, -0.070, 0.444, -0.349, 0.534, 0.646, -3.115, -2.111, 0.434, 2.612, -0.689, -0.091, 0.205, -0.446, -0.318, -0.469, -0.303, 0.212, -0.509, -0.282, 0.786, -2.922, 0.149, 0.636, -0.478, -0.810, 0.936, -0.739, -0.981, -0.139, 0.504, -1.591, -0.440, -0.404, 1.100, -0.131, 1.242, -1.083, -0.395, 0.357, 1.469, -0.103, -0.798, -1.419, 0.061, -0.963, 0.951, 1.130, -1.002, -0.585, 0.953, 0.334, 0.948, -0.370, -1.349, -0.538, 0.886, -0.612, -0.367, -0.182, -0.175, -0.200, 1.840, -1.165, -4.675, 2.176, 1.427, 3.643, -0.141, 2.306, 1.929, -0.812, 0.675, 1.119, 0.394, 0.039, -0.548, -0.383, -0.788, -1.994, 0.195, -0.555, 0.969, -2.406, 1.646, 0.490, 1.882, 1.576, 1.606, 0.167, -3.639, 0.675, -1.068, -0.511, 0.394, 0.051, -0.189, 2.104, 0.254, -0.382, -0.683, 1.285, -0.047, 0.832, -0.351, -0.930, 0.072, 1.004, -1.071, 0.875, 1.855, 0.947, 1.041, -4.199, 0.297, 1.291, -2.304, -0.611, -0.621, 0.056, -0.167, -0.056, 0.805, -5.622, -2.210, -1.371, -1.389, -1.989, 2.984, 1.234, -1.759, 0.004, -0.459, -0.463, -0.353, 0.348, 0.190, -0.326, -0.962, -0.419, -1.396, 0.118, 0.566, -0.274, -1.834, -1.030, -0.292, 0.234, 0.833, -0.274, 0.922, 0.282, -0.147, -0.295, -0.008, 0.520, -0.173, 0.491, -0.082, -0.713, 0.074, 0.495, -1.944, -0.163, -0.161, 1.424, 2.063, -0.290, 1.588, 0.872, -0.646, -0.074, -1.401, 0.985, 0.392, 1.490, 0.879, 0.408, 0.630, 0.137)
#let thr-e = (1.061, 0.804, 0.556, 0.017, 0.046, -0.298, 0.383, 0.249, 0.459, -0.429, 1.899, 0.282, 1.394, 1.331, -0.879, -1.687, 1.257, -0.388, 0.082, -0.259, 0.131, -1.190, -0.103, -0.464, -0.015, -2.335, 0.821, 0.332, -1.727, -0.734, 0.031, 0.629, 0.000, 1.384, 0.022, -1.000, -0.676, 0.744, -0.613, 0.841, 1.020, 0.589, 1.017, -0.174, -0.010, -0.592, -0.610, -1.565, -0.555, -1.071, -1.428, 0.147, 0.455, -0.342, 1.368, 0.941, 1.045, -0.604, -1.492, 0.558, 0.308, 0.726, 0.417, 1.260, -0.288, 0.668, -0.895, -2.309, -0.444, 1.499, -1.676, 1.017, -0.680, -0.400, 0.044, 0.212, -0.974, 0.126, 0.444, 0.835, -0.755, 1.551, 1.907, 2.415, -1.341, 0.173, -1.859, 0.378, 0.555, -1.149, -1.586, 0.187, 0.628, -0.793, -0.261, -2.526, -0.707, 0.147, 0.152, 1.583, -1.141, -2.252, 0.452, -0.592, 0.286, 0.719, 0.601, 1.442, 1.353, -1.665, -0.063, 2.001, -0.407, 0.967, -0.056, -0.420, 1.583, 1.042, -0.244, 0.907, -1.313, -0.725, 0.902, 0.039, -1.062, 0.450, 0.329, 1.285, 0.957, -0.276, -0.484, -0.139, -0.229, 1.462, 1.588, 1.357, 0.379, -0.245, 0.903, -0.349, 0.236, -1.666, -0.424, 1.440, -1.027, -1.492, -0.164, 1.667, 1.451, -0.360, -0.478, -0.110, -0.931, 0.036, -0.300, -1.476, -0.579, -0.257, -0.861, -1.119, 0.905, 1.896, -0.287, -0.425, 0.502, -0.229, -0.783, 1.392, -1.041, -0.731, -0.664, -0.885, -0.238, 0.576, 1.441, 0.663, 0.035, -1.251, -0.061, -0.941, -0.098, 0.978, 0.204, -0.211, -0.753, -0.022, 0.111, -0.928, -0.506, 0.882, -1.661, -0.443, -1.167, 1.546, 0.605, 0.514, 0.396, 0.287, 0.292, -1.585, 0.258, 0.594, -1.428, 0.825, 0.667, -1.522, -0.472, -0.307, -0.527, 0.391, -1.277, -0.224, 0.225, 0.725, 0.049, -0.242, 0.690, -1.990, 0.934, -0.308, -1.251, -0.429, -1.834, -2.045, -0.327, -0.778, 0.733, -0.886, -1.295, -0.958, 1.715, 0.026, -0.611, -0.990, -1.099, -0.164, 0.427, 1.151, 1.146, 0.272, -0.659, -0.860, -2.313, -1.019, 0.420, -0.339, 0.368, -1.348, 0.897, 0.295, 0.042, 0.400, -2.237, -0.558, -0.897, 1.812, -0.183, -0.505, 0.853, -1.054, 1.422, -0.703, -0.059, -0.916, 0.808, -2.172, 0.691, -0.820, 0.050, -1.151, 0.229, 0.187, 0.590, 0.315, 0.623, 0.993, -0.389, -1.179, -1.278, 0.680, -0.376, 1.052, 0.045, -1.012, 0.905, 1.943, -0.181, -0.939, -0.846, 0.890, -0.585, -0.406, 0.685, 0.012, 0.115, -0.544, -0.638, 0.164, 0.155, 0.592)

// Overlap loss grows like sigma, the extra error like sigma^2. Both are
// scaled to meet at sigma = 1; only the shapes matter.
#let fig-lin-quad() = canvas({
  import cetz.draw: *
  let (w, h) = (300, 170)
  let X(s) = s / 2 * w
  let Y(v) = v / 4 * h
  // Zones: left of the crossing the error is the smaller loss, right of it the larger.
  rect((0, 0), (X(1), h), fill: c.blue1, stroke: none)
  rect((X(1), 0), (w, h), fill: c.orange1, stroke: none)
  content((X(.5), h - 6), lbl([*accurate Stage 1*], size: 7.5pt, fill: c.blue), anchor: "north")
  content((X(.5), h - 17), txt(size: 7pt)[error < overlap loss], anchor: "north")
  content((X(1.5), h - 6), lbl([*noisy Stage 1*], size: 7.5pt, fill: c.orange), anchor: "north")
  content((X(1.5), h - 17), txt(size: 7pt)[error > overlap loss], anchor: "north")
  // Axes.
  for v in range(0, 5) {
    line((0, Y(v)), (w, Y(v)), stroke: if v == 0 { axis-stroke } else { grid-stroke })
    content((-6, Y(v)), lbl(str(v), size: 7.5pt), anchor: "east")
  }
  for s in (0, .5, 1, 1.5, 2) {
    line((X(s), 0), (X(s), -3), stroke: axis-stroke)
    content((X(s), -11), lbl(str(s), size: 7.5pt))
  }
  content((w / 2, -25), txt[noise σ (relative)])
  content((-30, h / 2), txt[loss (relative)], angle: 90deg)
  // Curves.
  let ss = range(0, 41).map(k => k / 20)
  line(..ss.map(s => (X(s), Y(s))), stroke: 1.4pt + c.blue)
  line(..ss.map(s => (X(s), Y(s * s))), stroke: 1.4pt + c.orange)
  content((w + 5, Y(2)), lbl([overlap loss #sym.prop σ], size: 7.5pt, fill: c.blue, weight: 600), anchor: "west")
  content((w + 5, Y(4)), lbl([extra error #sym.prop σ#super[2]], size: 7.5pt, fill: c.orange, weight: 600), anchor: "west")
  // Doubling a large sigma: error x4, overlap loss x2.
  for (s, v, col) in ((1, 1, c.ink), (2, 2, c.blue), (2, 4, c.orange)) {
    circle((X(s), Y(v)), radius: 2.2, fill: col, stroke: .6pt + paper)
  }
  content((X(1.62), Y(3.1)), txt(size: 7pt)[σ ×2: error 1 #sym.arrow 4], anchor: "east")
  content((X(1.62), Y(2.75)), txt(size: 7pt, fill: c.muted)[overlap loss 1 #sym.arrow 2], anchor: "east")
  // Halving a small sigma: little error left to save.
  for (s, v) in ((.5, .25), (.25, .0625)) {
    circle((X(s), Y(v)), radius: 2.2, fill: c.orange, stroke: .6pt + paper)
  }
  content((X(.08), Y(2.2)), txt(size: 7pt)[σ ÷2 from 0.5: error 0.25 #sym.arrow 0.06], anchor: "west")
  content((X(.08), Y(1.85)), txt(size: 7pt, fill: c.muted)[overlap loss 0.5 #sym.arrow 0.25], anchor: "west")
  line((X(.3), Y(1.65)), (X(.37), Y(.3)), stroke: (paint: c.muted, thickness: .5pt, dash: "dotted"))
})

#let fig-threshold() = canvas({
  import cetz.draw: *
  let n = thr-y.len()
  let k = int(0.3 * n)
  let rms = calc.sqrt(thr-y.map(v => v * v).sum() / n)
  let a = thr-y.map(calc.abs)
  let cut(vs) = { let s = vs.sorted().rev(); (s.at(k - 1) + s.at(k)) / 2 }
  let tau = cut(a)
  let (lim, sz) = (4.5, 190)
  let S(v) = calc.min(v, lim) / lim * sz
  let panel(x0, s, title) = {
    let h = range(n).map(i => calc.abs(thr-y.at(i) + s * rms * thr-e.at(i)))
    let that = cut(h)
    content((x0, sz + 12), lbl(title, weight: 600), anchor: "west")
    for t in range(5) {
      line((x0 + S(t), 0), (x0 + S(t), sz), stroke: grid-stroke)
      line((x0, S(t)), (x0 + sz, S(t)), stroke: grid-stroke)
      content((x0 + S(t), -8), lbl(str(t), size: 7pt, fill: c.muted))
      content((x0 - 5, S(t)), lbl(str(t), size: 7pt, fill: c.muted), anchor: "east")
    }
    line((x0, 0), (x0 + sz, sz), stroke: (paint: c.hair, thickness: .6pt))
    let (miss, lost, tot) = (0, 0.0, 0.0)
    // Draw the agreeing channels first, the disagreements on top.
    for pass in (0, 1) {
      for i in range(n) {
        let (keep-o, keep-p) = (a.at(i) > tau, h.at(i) > that)
        let p = (x0 + S(a.at(i)), S(h.at(i)))
        if pass == 0 and keep-o == keep-p {
          circle(p, radius: 1.5, fill: if keep-o { c.blue } else { c.grey2 }, stroke: none)
        } else if pass == 1 and keep-o and not keep-p {
          circle(p, radius: 2.3, fill: c.danger, stroke: .5pt + paper)
        } else if pass == 1 and keep-p and not keep-o {
          circle(p, radius: 2.1, fill: paper, stroke: 1pt + c.orange)
        }
        if pass == 0 {
          if keep-o { tot += a.at(i) * a.at(i) }
          if keep-o and not keep-p { miss += 1 }
          if keep-o { lost += a.at(i) * a.at(i) }
          if keep-p { lost -= a.at(i) * a.at(i) }
        }
      }
    }
    let dash = (paint: c.ink, thickness: .7pt, dash: "dashed")
    line((x0 + S(tau), 0), (x0 + S(tau), sz), stroke: dash)
    line((x0, S(that)), (x0 + sz, S(that)), stroke: dash)
    content((x0 + S(tau) + 3, sz - 2), txt(size: 7pt)[oracle cut], anchor: "north-west")
    content((x0 + sz - 2, S(that) + 3), txt(size: 7pt)[Stage 1 cut], anchor: "south-east")
    line((x0, 0), (x0 + sz, 0), stroke: axis-stroke)
    line((x0, 0), (x0, sz), stroke: axis-stroke)
    content((x0 + sz / 2, -20), txt(size: 7.5pt)[exact |y#sub[j]|])
    let pct = calc.round(100 * miss / k, digits: 1)
    let lp = calc.round(100 * lost / tot, digits: 2)
    content((x0 + sz / 2, -36), lbl([*#miss* missed (#pct% of the kept) · $y^2$ lost: *#lp%*], size: 7.5pt))
  }
  content((-14, 95), txt(size: 7.5pt)[Stage 1 #linebreak() |ŷ#sub[j]|], anchor: "east")
  panel(0, 0.15, [(a) noise σ = 0.15 × RMS])
  panel(250, 0.3, [(b) noise 2σ])
  let key(x, y, body, dot) = {
    dot((x + 4, y))
    content((x + 11, y), txt(size: 7.5pt, body), anchor: "west")
  }
  let ky = -58
  key(-20, ky, [kept by both], p => circle(p, radius: 2, fill: c.blue, stroke: none))
  key(62, ky, [dropped by both], p => circle(p, radius: 2, fill: c.grey2, stroke: none))
  key(156, ky, [missed: oracle keeps, Stage 1 drops], p => circle(p, radius: 2.3, fill: c.danger, stroke: none))
  key(352, ky, [kept in its place], p => circle(p, radius: 2.1, fill: paper, stroke: 1pt + c.orange))
})

// Quick simulation: Laplace scores, keep 30%, Gaussian proxy noise.
#let sim-sigma = (0.05, 0.10, 0.20, 0.40)
#let sim-miss = (0.028, 0.057, 0.113, 0.222)
#let sim-excess = (0.0009, 0.0036, 0.0142, 0.0533)
#let fig-sim() = canvas({
  import cetz.draw: *
  let (x0, x1, y0, y1) = (log10(0.04), log10(0.5), log10(0.0005), log10(0.5))
  let (w, h) = (280, 150)
  let X(v) = (log10(v) - x0) / (x1 - x0) * w
  let Y(v) = (log10(v) - y0) / (y1 - y0) * h
  content((-30, h + 14), tag[simulated, log–log], anchor: "west")
  for t in (0.001, 0.01, 0.1) {
    line((0, Y(t)), (w, Y(t)), stroke: grid-stroke)
    content((-6, Y(t)), lbl(str(t), size: 7.5pt), anchor: "east")
  }
  for t in sim-sigma {
    line((X(t), 0), (X(t), h), stroke: grid-stroke)
    content((X(t), -10), lbl(str(t), size: 7.5pt))
  }
  line((0, 0), (w, 0), stroke: axis-stroke)
  line((0, 0), (0, h), stroke: axis-stroke)
  content((w / 2, -24), txt[proxy noise σ, relative to the RMS of _y_])
  series(sim-sigma.zip(sim-miss).map(((a, b)) => (X(a), Y(b))), c.blue)
  series(sim-sigma.zip(sim-excess).map(((a, b)) => (X(a), Y(b))), c.orange, marker: "square")
  content((X(0.4) + 8, Y(0.222)), lbl([miss rate · slope 1], size: 7.5pt, fill: c.blue, weight: 600), anchor: "west")
  content((X(0.4) + 8, Y(0.0533)), lbl([excess error · slope 2], size: 7.5pt, fill: c.orange, weight: 600), anchor: "west")
  content((X(0.05) + 2, Y(0.028) - 5), txt(size: 7pt, fill: c.blue)[2.8%], anchor: "north-west")
  content((X(0.05) + 6, Y(0.0009) - 4), txt(size: 7pt, fill: c.orange)[0.0009], anchor: "north-west")
})

#let landing-data = (
  ("AutoRound INT2 G64", (
    (2.137, (20.148, 14.826, 20.695, 14.044, 18.642, 11.642)),
    (5.694, (25.39, 16.796, 20.913, 12.65, 15.296, 8.952)),
    (11.997, (30.106, 19.072, 21.51, 11.274, 11.776, 6.26)),
    (22.362, (30.18, 19.923, 22.756, 11.402, 10.654, 5.082)),
    (35.627, (28.177, 19.653, 23.793, 12.335, 11.127, 4.912)),
    (50.251, (25.504, 18.813, 24.375, 13.51, 12.472, 5.324)),
  ), (21.341, (27.401, 19.108, 23.446, 12.576, 11.943, 5.522))),
  ("GGUF Q2_K", (
    (0.647, (22.978, 15.843, 20.637, 13.256, 16.906, 10.377)),
    (2.313, (28.557, 17.767, 20.823, 11.817, 13.489, 7.544)),
    (5.751, (36.451, 19.881, 19.794, 9.5, 9.512, 4.86)),
    (13.747, (40.032, 21.821, 20.01, 8.144, 6.865, 3.126)),
    (27.554, (38.438, 22.757, 21.783, 8.46, 6.135, 2.423)),
    (45.887, (34.508, 22.676, 23.998, 9.836, 6.672, 2.306)),
  ), (15.979, (36.325, 22.245, 22.438, 9.249, 6.95, 2.792))),
  ("GGUF Q4_K_M", (
    (0.048, (28.915, 17.392, 20.617, 12.053, 14.876, 6.143)),
    (0.228, (31.991, 17.993, 20.256, 11.004, 13.216, 5.537)),
    (0.72, (38.489, 19.142, 18.837, 9.182, 10.161, 4.185)),
    (2.047, (45.381, 19.715, 17.035, 7.365, 7.456, 3.046)),
    (6.557, (59.207, 17.273, 12.509, 4.807, 4.432, 1.767)),
    (29.599, (72.928, 15.8, 6.741, 2.085, 1.762, 0.68)),
  ), (6.53, (68.266, 16.327, 8.563, 3.012, 2.744, 1.086))),
)
#let landing-colors = (c.blue, c.blue2, c.teal2, c.orange2, c.orange, c.danger)
#let landing-bins = ("30–35%", "35–40%", "40–50%", "50–60%", "60–80%", "80–100%")
#let rank-segs = ("0–5%", "5–10%", "10–15%", "15–20%", "20–25%", "25–30%")

#let fig-landing() = canvas({
  import cetz.draw: *
  let (pw, gap) = (120, 42)
  let sx = pw / 55
  let (bh, step) = (11, 15)
  let seg-y(i) = (7 - i) * step
  let top = 8 * step
  content((-6, top + 4), txt(size: 7.5pt)[dense rank], anchor: "east")
  for (i, s) in rank-segs.enumerate() { content((-6, seg-y(i) + bh / 2), lbl(s, size: 7.5pt), anchor: "east") }
  content((-6, bh / 2), lbl("all 0–30%", size: 7.5pt, weight: 600), anchor: "east")
  for (pi, (name, rows, total)) in landing-data.enumerate() {
    let x0 = pi * (pw + gap)
    content((x0, top + 4), lbl(name, weight: 600), anchor: "west")
    for v in (0, 25, 50) {
      line((x0 + v * sx, -4), (x0 + v * sx, top - 4), stroke: if v == 0 { axis-stroke } else { grid-stroke })
      content((x0 + v * sx, -12), lbl(str(v) + "%", size: 7pt))
    }
    line((x0 - 2, step + 1), (x0 + pw, step + 1), stroke: (paint: c.hair, thickness: .5pt))
    let bar(y, rate, shares) = {
      let x = x0
      for (k, sh) in shares.enumerate() {
        let len = rate * sh / 100 * sx
        rect((x, y), (x + len, y + bh), fill: landing-colors.at(k), stroke: none)
        x += len
      }
      content((x + 3, y + bh / 2), lbl(num(rate, digits: if rate < 1 { 2 } else { 1 }) + "%", size: 7pt), anchor: "west")
    }
    for (i, (rate, shares)) in rows.enumerate() { bar(seg-y(i), rate, shares) }
    bar(0, ..total)
  }
  content((pw + gap + pw / 2, -27), txt[miss rate: share of the segment that the proxy ranks below its Top-30%])
  content((-6, -46), txt(size: 7.5pt)[missed channels land at proxy rank], anchor: "east")
  for (k, b) in landing-bins.enumerate() {
    let lx = k * 72
    rect((lx, -50), (lx + 11, -42), fill: landing-colors.at(k), stroke: none)
    content((lx + 15, -46), lbl(b, size: 7.5pt), anchor: "west")
  }
})

// Single-layer FFN output error vs mask budget; selected channels use exact
// dense values. The crossings with the oracle's Top-30% error give the budget
// each proxy needs to match it.
#let ffn-budgets = (30, 35, 40, 45, 50, 60)
#let ffn-err = (
  ("dense oracle", c.ink, "dashed", (20.427, 17.311, 14.57, 12.163, 10.056, 6.541)),
  ("AutoRound INT2", c.danger, none, (25.806, 22.992, 20.512, 18.312, 16.359, 12.998)),
  ("GGUF Q2_K", c.orange, none, (23.465, 20.565, 18.018, 15.781, 13.823, 10.532)),
  ("GGUF Q4_K_M", c.blue, none, (20.974, 17.881, 15.165, 12.78, 10.697, 7.245)),
)

#let fig-ffn-error() = canvas({
  import cetz.draw: *
  let (w, h) = (330, 180)
  let X(b) = (b - 30) / 30 * w
  let Y(e) = (e - 4) / 24 * h
  let target = ffn-err.at(0).at(3).at(0)
  content((-34, h + 16), tag[FFN output relative error], anchor: "west")
  for e in range(4, 29, step: 4) {
    line((0, Y(e)), (w, Y(e)), stroke: if e == 4 { axis-stroke } else { grid-stroke })
    content((-6, Y(e)), lbl(str(e) + "%", size: 7.5pt), anchor: "east")
  }
  for b in ffn-budgets {
    line((X(b), 0), (X(b), -3), stroke: axis-stroke)
    content((X(b), -11), lbl(str(b) + "%", size: 7.5pt))
  }
  content((w / 2, -25), txt[mask budget (share of 12288 channels kept)])
  line((0, Y(target)), (w, Y(target)), stroke: (paint: c.muted, thickness: .5pt, dash: "dotted"))
  content((w - 2, Y(target) + 3), txt(size: 7pt)[oracle at 30%: 20.4%], anchor: "south-east")
  for (_, color, dash, errs) in ffn-err {
    series(ffn-budgets.zip(errs).map(((b, e)) => (X(b), Y(e))), color, dash: dash, marker: if dash == none { "circle" } else { "hollow" })
  }
  let ends = ffn-err.map(((name, color, _, errs)) => (name, color, Y(errs.last()))).sorted(key: r => r.at(2))
  let last = -1e9
  for (name, color, y) in ends {
    let ly = calc.max(y, last + 10)
    last = ly
    content((w + 6, ly), lbl(name, size: 7.5pt, fill: color, weight: 600), anchor: "west")
  }
  for (_, color, dash, errs) in ffn-err.slice(1) {
    let b = crossing(ffn-budgets, errs, target)
    if b != none {
      line((X(b), Y(target)), (X(b), 0), stroke: (paint: color, thickness: .7pt, dash: "dotted"))
      circle((X(b), Y(target)), radius: 2.8, fill: paper, stroke: 1.2pt + color)
      content((X(b) + 2, 6), lbl("≈" + num(b) + "%", size: 7pt, fill: color, weight: 600), anchor: "south-west")
    }
  }
})

// ============================================================================
// 3. no-write GDN
// ============================================================================

// One GDN decode step, simplified from the expbook's gdn-state-only figure:
// the read path (kept by no-write) below the state, the write path (dropped)
// above it. The conv, the L2 norms and the per-head decay α are left out.
#let fig-gdn-flow() = canvas({
  import cetz.draw: *
  let keep = c.blue
  let drop = c.orange
  let drop-stroke = (paint: drop, thickness: .7pt, dash: "dashed")
  let arw(..pts, color: c.line, dash: none) = line(
    ..pts,
    stroke: (paint: color, thickness: .8pt, dash: dash),
    mark: (end: "stealth", fill: color, scale: .5),
  )
  let bx(x0, y0, x1, y1, body, fill: paper, stroke: .7pt + keep) = {
    rect((x0, y0), (x1, y1), fill: fill, stroke: stroke, radius: 2)
    content(((x0 + x1) / 2, (y0 + y1) / 2), body)
  }
  let m(body, fill: c.ink) = text(size: 8.5pt, fill: fill, body)

  // input and in_proj: q, z rows (kept) below, k, v, b rows (dropped) above
  bx(0, 108, 30, 132, m($x_t$), fill: c.grey1, stroke: .6pt + c.line)
  arw((30, 120), (50, 120))
  rect((50, 70), (115, 150), fill: c.blue1, stroke: .7pt + keep)
  rect((50, 150), (115, 230), fill: c.orange1, stroke: drop-stroke)
  content((82.5, 125), lbl([q], fill: keep, weight: 600))
  content((82.5, 95), lbl([z], fill: keep, weight: 600))
  content((82.5, 190), lbl([k, v, b], fill: drop, weight: 600))
  content((82.5, 238), txt[in_proj], anchor: "south")

  // write path: the delta of token t
  arw((115, 215), (150, 215), color: drop, dash: "dashed")
  bx(150, 203, 250, 227, m($beta k (v - S^top k)^top$, fill: drop), fill: c.orange1, stroke: drop-stroke)
  arw((230, 203), (230, 183), color: drop, dash: "dashed")

  // state lane
  bx(140, 162, 200, 188, m($S_(t-1)$), fill: c.teal1, stroke: .7pt + c.teal)
  content((170, 158), txt(size: 7pt)[state from tokens < t], anchor: "north")
  arw((200, 175), (222, 175), color: c.ink)
  circle((230, 175), radius: 8, fill: paper, stroke: drop-stroke)
  content((230, 175), lbl([+], fill: drop, weight: 600))
  arw((238, 175), (265, 175), color: c.ink)
  bx(265, 162, 320, 188, m($S_t$), fill: c.teal1, stroke: .7pt + c.teal)
  arw((320, 175), (350, 175), color: drop, dash: "dashed")
  content((354, 175), txt(size: 7pt, fill: drop)[written back for t + 1], anchor: "west")

  // read path
  arw((115, 125), (255, 125), color: keep)
  bx(255, 112, 330, 138, m($o_t = S_t^top q$))
  arw((292, 162), (292, 138), color: c.ink)
  arw((330, 125), (350, 125), color: keep)
  bx(350, 112, 475, 138, m($"RMSNorm"(o_t) dot.o "SiLU"(z)$))
  line((115, 95), (412, 95), stroke: .8pt + keep)
  arw((412, 95), (412, 112), color: keep)
  arw((475, 125), (492, 125), color: keep)
  bx(492, 112, 547, 138, lbl([out_proj], weight: 600), fill: c.blue1)
  arw((547, 125), (560, 125), color: keep)
  content((563, 125), m($y_t$), anchor: "west")

  // legend
  line((50, 55), (70, 55), stroke: 1.2pt + keep)
  content((76, 55), txt[read path: kept by no-write], anchor: "west")
  line((250, 55), (270, 55), stroke: (paint: drop, thickness: 1.2pt, dash: "dashed"))
  content((276, 55), txt[write path: dropped by no-write (β = 0)], anchor: "west")
})

// Weight rows of one Qwen3.5-9B GDN layer, to scale; the 64-row in_proj_ba
// is left out.
#let fig-gdn-rows() = canvas({
  import cetz.draw: *
  let u = 440 / 16384
  let segs = (("k", 2048, false), ("v", 4096, false), ("q", 2048, true), ("z", 4096, true), ("out_proj", 4096, true))
  let x = 0
  for (name, rows, kept) in segs {
    let x1 = x + rows * u
    rect(
      (x, 0),
      (x1, 24),
      fill: if kept { c.blue1 } else { c.orange1 },
      stroke: if kept { .7pt + c.blue } else { (paint: c.orange, thickness: .7pt, dash: "dashed") },
    )
    content(((x + x1) / 2, 12), lbl(name + " · " + str(rows), fill: if kept { c.blue } else { c.orange }, weight: 600))
    x = x1
  }
  let brace(x0, x1, body) = {
    line((x0, 30), (x0, 35), (x1, 35), (x1, 30), stroke: .6pt + c.line)
    content(((x0 + x1) / 2, 39), txt(body), anchor: "south")
  }
  brace(0, 12288 * u, [in_proj_qkvz · 4096 → 12288 rows · 96 MiB BF16])
  brace(12288 * u + 2, 16384 * u, [out_proj · 32 MiB])
  rect((0, -24), (11, -16), fill: c.blue1, stroke: .7pt + c.blue)
  content((15, -20), txt[read by no-write: 10 240 of 16 384 rows = 62.5% of the bytes], anchor: "west")
  rect((0, -38), (11, -30), fill: c.orange1, stroke: (paint: c.orange, thickness: .7pt, dash: "dashed"))
  content((15, -34), txt[skipped: the k and v rows, and the state write], anchor: "west")
})

// Linear-layer Top-30% overlap against the dense oracle vs estimated proxy
// weight bytes (share of BF16 in_proj_qkvz + out_proj).
#let fig-gdn-overlap() = canvas({
  import cetz.draw: *
  let (w, h) = (400, 220)
  let X(b) = b / 100 * w
  let Y(o) = (o - 60) / 40 * h
  content((-34, h + 16), tag[linear-layer Top-30% overlap], anchor: "west")
  for o in range(60, 101, step: 10) {
    line((0, Y(o)), (w, Y(o)), stroke: if o == 60 { axis-stroke } else { grid-stroke })
    content((-6, Y(o)), lbl(str(o) + "%", size: 7.5pt), anchor: "east")
  }
  for b in range(0, 101, step: 20) {
    line((X(b), 0), (X(b), -3), stroke: axis-stroke)
    content((X(b), -11), lbl(str(b) + "%", size: 7.5pt))
  }
  content((w / 2, -25), txt[proxy weight bytes, share of exact GDN's in_proj_qkvz + out_proj (estimate)])
  let P(b, o) = (X(b), Y(o))
  series((P(9.77, 81.35), P(17.58, 89.6), P(62.5, 90.24)), c.blue)
  series((P(15.63, 82.916), P(28.13, 96.49), P(100, 100)), c.orange, marker: "square")
  for (b, o) in ((0, 76.927), (0, 64.389), (18.75, 77.912)) { circle(P(b, o), radius: 2.6, fill: paper, stroke: 1pt + c.muted) }
  let note(p, body, anchor, color: c.ink) = content(p, lbl(body, size: 7.5pt, fill: color), anchor: anchor)
  note((5, Y(76.927) - 4), [previous FFN 76.9%], "north-west", color: c.muted)
  note((6, Y(64.389)), [previous mixer 64.4%], "west", color: c.muted)
  note((X(18.75) + 6, Y(77.912) - 2), [SVD r512 77.9%], "west", color: c.muted)
  note((X(9.77) + 6, Y(81.35) - 4), [no-write INT2 81.4%], "west", color: c.blue)
  note((X(15.63) + 6, Y(82.916) + 4), [INT2 proj 82.9%], "west", color: c.orange)
  note((X(17.58) + 22, Y(89.6) - 3), [no-write INT4 89.6%], "north-west", color: c.blue)
  note((X(28.13) - 4, Y(96.49) + 3), [INT4 proj 96.5%], "south-east", color: c.orange)
  note((X(62.5), Y(90.24) - 6), [no-write BF16 90.2%], "north", color: c.blue)
  note((X(100) - 4, Y(100) - 5), [exact GDN 100%], "north-east", color: c.orange)
  let (lx, ly) = (250, 70)
  line((lx, ly), (lx + 14, ly), stroke: 1.4pt + c.blue)
  content((lx + 18, ly), lbl("no-write (β = 0)", size: 7.5pt), anchor: "west")
  line((lx, ly - 13), (lx + 14, ly - 13), stroke: 1.4pt + c.orange)
  content((lx + 18, ly - 13), lbl("exact GDN, quantized proj", size: 7.5pt), anchor: "west")
  circle((lx + 7, ly - 26), radius: 2.6, fill: paper, stroke: 1pt + c.muted)
  content((lx + 18, ly - 26), lbl("no GDN, or low rank", size: 7.5pt), anchor: "west")
})

#let fig-gdn-latency() = hbars(
  (
    ([exact GDN decode (gpt-fast)], 211.82, c.grey2, [211.8 µs · 132.5 MiB]),
    ([TileLang no-write, BF16 proj], 105.87, c.blue2, [105.9 µs · 82.3 MiB · *2.0×*]),
    ([TileLang no-write, INT4 proj], 37.44, c.blue, [37.4 µs · 24.8 MiB · *5.7×*]),
    ([TileLang no-write, INT2 proj], 28.03, c.blue, [28.0 µs · 14.8 MiB · *7.6×*]),
  ),
  1.3,
  unit: [one layer, CUDA graph, cold L2, RTX 3090],
)

// ============================================================================
// 4. CPU Stage 1
// ============================================================================

// The overlap plan, not to scale.
#let fig-plan() = canvas({
  import cetz.draw: *
  let (gy, cy, h) = (64, 0, 24)
  let block(x0, x1, y, body, fill, stroke, ink: c.ink) = {
    rect((x0, y), (x1, y + h), fill: fill, stroke: stroke, radius: 2)
    content(((x0 + x1) / 2, y + h / 2), lbl(body, size: 7.5pt, fill: ink, weight: 600))
  }
  let dashed(col) = (paint: col, thickness: .7pt, dash: "dashed")
  content((-10, gy + h / 2), lbl("GPU", weight: 600), anchor: "east")
  content((-10, cy + h / 2), lbl("CPU", weight: 600), anchor: "east")
  block(0, 140, gy, [FFN#sub[i−1]], c.blue1, .7pt + c.blue)
  block(140, 162, gy, [], c.teal1, .7pt + c.teal)
  block(162, 262, gy, [attn#sub[i]], c.blue2, .7pt + c.blue)
  block(282, 440, gy, [FFN#sub[i]: Stage 2, sparse], c.blue1, .7pt + c.blue)
  content((151, gy + h + 4), txt(size: 7pt, fill: c.teal)[Attn_prox#sub[i]], anchor: "south")
  block(0, 140, cy, [warm Stage 1 weights?], paper, dashed(c.orange), ink: c.orange)
  block(170, 262, cy, [Stage 1#sub[i]], c.orange, .7pt + c.orange, ink: paper)
  block(282, 440, cy, [idle: share FFN#sub[i]?], paper, dashed(c.muted), ink: c.muted)
  line((158, gy), (172, cy + h), stroke: .8pt + c.teal, mark: (end: "stealth", fill: c.teal, scale: .5))
  line((262, cy + h), (282, gy), stroke: .8pt + c.orange, mark: (end: "stealth", fill: c.orange, scale: .5))
  content((280, 44), txt(size: 7pt, fill: c.orange)[mask#sub[i]], anchor: "west")
  line((170, -6), (170, -10), (262, -10), (262, -6), stroke: .6pt + c.line)
  content((216, -14), lbl([goal 1: hide under attn#sub[i]], size: 7.5pt), anchor: "north")
  line((282, -6), (282, -10), (440, -10), (440, -6), stroke: .6pt + c.line)
  content((361, -14), lbl([goal 2: help with FFN#sub[i]], size: 7.5pt), anchor: "north")
  content((70, -14), lbl([idea in §5.3], size: 7.5pt, fill: c.orange), anchor: "north")
})

// One layer's CPU Stage 1 against the GPU running layer after layer, to scale.
// Qwen3-8B, KV 0: RTX 3090 (CUPTI) and Ultra 9 (20 threads, pure-format GGUF).
#let fig-gpu-budget() = canvas({
  import cetz.draw: *
  let tmax = 920
  let s = 0.5
  let X(t) = calc.min(t, tmax) * s
  let bh = 15
  let gpu = (
    ([GPU · Q4_K_M], 96, 62.47, 118.01),
    ([GPU · Q8_0], 70, 84.19, 191.89),
  )
  let cpu = (
    ([CPU · Q2_K], 30, 506.49, c.orange),
    ([CPU · Q4_K], 6, 895.11, c.orange2),
  )
  // attn_i ends: the window.
  for (_, _, at, _) in gpu {
    line((X(at), -2), (X(at), 70 + bh + 2), stroke: (paint: c.danger, thickness: .6pt, dash: "dashed"))
  }
  content((X(84.19) + 3, 52), txt(size: 7pt, fill: c.danger)[attn#sub[i] ends: the window], anchor: "west")
  for (label, y, at, ft) in gpu {
    content((-8, y + bh / 2), lbl(label, size: 7.5pt), anchor: "east")
    let (t, k) = (0, 0)
    while t < tmax {
      let first = k == 0
      rect((X(t), y), (X(t + at), y + bh), fill: if first { c.blue } else { c.blue2 }, stroke: .5pt + paper)
      if first { content((X(t + at / 2), y + bh / 2), lbl([attn#sub[i]], size: 6.5pt, fill: paper, weight: 600)) }
      let f0 = t + at
      if f0 < tmax {
        rect((X(f0), y), (X(f0 + ft), y + bh), fill: c.blue1, stroke: .5pt + paper)
        if f0 + ft <= tmax {
          let name = if first [FFN#sub[i]] else [FFN#sub[i+#k]]
          content((X(f0 + ft / 2), y + bh / 2), lbl(name, size: 6.5pt, fill: c.blue))
        }
      }
      t += at + ft
      k += 1
    }
  }
  for (label, y, t, fill) in cpu {
    content((-8, y + bh / 2), lbl(label, size: 7.5pt), anchor: "east")
    rect((X(0), y), (X(t), y + bh), fill: fill, stroke: .5pt + paper)
    // Where the GPU is when this Stage 1 ends.
    line((X(t), y + bh), (X(t), 96 + bh + 2), stroke: (paint: c.muted, thickness: .6pt, dash: "dotted"))
    let ink = if fill == c.orange { paper } else { c.ink }
    let layers = gpu.map(((_, _, at, ft)) => num(t / (at + ft), digits: 1))
    content((X(4), y + bh / 2), lbl([Stage 1#sub[i] · #num(t, digits: 0) µs], size: 7pt, fill: ink, weight: 600), anchor: "west")
    content((X(t) - 4, y + bh / 2), lbl([GPU done with #layers.at(0) / #layers.at(1) layers], size: 7pt, fill: ink), anchor: "east")
  }
  line((0, -6), (X(tmax), -6), stroke: axis-stroke)
  for t in range(0, 901, step: 100) {
    line((X(t), -6), (X(t), -9), stroke: axis-stroke)
    content((X(t), -16), lbl(str(t), size: 7pt))
  }
  content((X(tmax) + 4, -16), txt(size: 7pt)[µs], anchor: "west")
})

// GPU attention per layer split into weight reads (estimated at the FFN
// projections' bandwidth) and the rest.
#let fig-attn-split() = canvas({
  import cetz.draw: *
  let sx = 1.55
  // (label, weight reads, rest at KV 0, added by the context); weight reads
  // are estimated, the totals measured, the rest is total minus weight reads.
  let rows = (
    ([Q4_K_M · KV 0], 31.4, 31.07, 0),
    ([Q8_0 · KV 0], 53.8, 30.39, 0),
    ([Q4_K_M · KV 32K], 31.4, 31.07, 151.8),
    ([Q8_0 · KV 32K], 53.8, 30.39, 151.56),
  )
  let ys = ()
  for (i, (label, wr, fixed, kv)) in rows.enumerate() {
    let y = (3 - i) * 20 - (if i >= 2 { 10 } else { 0 })
    ys.push(y)
    let (x1, x2, x3) = (wr * sx, (wr + fixed) * sx, (wr + fixed + kv) * sx)
    content((-8, y + 7), lbl(label), anchor: "east")
    rect((0, y), (x1, y + 14), fill: c.blue, stroke: .5pt + paper)
    rect((x1, y), (x2, y + 14), fill: c.grey2, stroke: .5pt + paper)
    content(((0 + x1) / 2, y + 7), lbl(num(wr), size: 7pt, fill: paper, weight: 600))
    content(((x1 + x2) / 2, y + 7), lbl(num(fixed), size: 7pt))
    if kv > 0 {
      rect((x2, y), (x3, y + 14), fill: c.grey1, stroke: .5pt + c.grey2)
      content(((x2 + x3) / 2, y + 7), lbl(num(kv), size: 7pt))
    }
    content((x3 + 5, y + 7), txt[*#num(wr + fixed + kv)* µs], anchor: "west")
  }
  // Ratio of each Q8_0 / Q4_K_M pair, to the right of the bars.
  let pair(ya, yb, x, body) = {
    line((x, ya + 7), (x + 4, ya + 7), (x + 4, yb + 7), (x, yb + 7), stroke: .6pt + c.muted)
    content((x + 8, (ya + yb) / 2 + 7), txt(size: 7.5pt, fill: c.orange)[#body], anchor: "west")
  }
  pair(ys.at(0), ys.at(1), 84.2 * sx + 46, [*×1.35*])
  pair(ys.at(2), ys.at(3), 235.8 * sx + 46, [*×1.10*])
  line((0, -12), (0, 76), stroke: axis-stroke)
  let key(y, fill, stroke, body) = {
    rect((0, y), (11, y + 8), fill: fill, stroke: stroke)
    content((15, y + 4), txt(body), anchor: "west")
  }
  key(-26, c.blue, none, [reading the Q/K/V/O weights: bytes ÷ the FFN's bandwidth (estimate)])
  key(-40, c.grey2, none, [rest at KV 0: \~10 small kernels that read no weights])
  key(-54, c.grey1, .5pt + c.grey2, [added by 32K of context: flash attention reading the KV cache])
})

// The warming plan, not to scale: a timeline on top, the memory traffic of
// each CPU block below it.
#let fig-warm-plan() = canvas({
  import cetz.draw: *
  let (h, gy, cy) = (20, 150, 116)
  let block(x0, x1, y, body, fill, stroke, ink: c.ink) = {
    rect((x0, y), (x1, y + h), fill: fill, stroke: stroke, radius: 2)
    content(((x0 + x1) / 2, y + h / 2), lbl(body, size: 7.5pt, fill: ink, weight: 600))
  }
  content((-8, gy + h / 2), lbl("GPU", weight: 600), anchor: "east")
  content((-8, cy + h / 2), lbl("CPU", weight: 600), anchor: "east")
  block(0, 200, gy, [FFN#sub[i−1]], c.blue1, .7pt + c.blue)
  block(200, 222, gy, [], c.teal1, .7pt + c.teal)
  block(222, 322, gy, [attn#sub[i]], c.blue2, .7pt + c.blue)
  block(338, 470, gy, [FFN#sub[i]], c.blue1, .7pt + c.blue)
  content((211, gy + h + 3), txt(size: 7pt, fill: c.teal)[Attn_prox#sub[i]], anchor: "south")
  block(0, 200, cy, [warm layer _i_'s weights], c.orange1, (paint: c.orange, thickness: .7pt, dash: "dashed"), ink: c.orange)
  block(222, 322, cy, [Stage 1#sub[i], from cache], c.orange, .7pt + c.orange, ink: paper)
  arw((218, gy), (226, cy + h), color: c.teal)
  arw((322, cy + h), (338, gy), color: c.orange)
  content((334, cy + 12), txt(size: 7pt, fill: c.orange)[mask#sub[i]], anchor: "west")

  // Memory below.
  let my = 5 + 6 * 5.4 + 1.8
  // DRAM: every layer's Stage 1 weights, layer i highlighted.
  rect((0, 0), (80, 74), fill: c.grey1, stroke: .6pt + c.line, radius: 2)
  content((40, 66), lbl([DRAM], size: 7.5pt, weight: 600))
  for k in range(10) {
    let y = 5 + k * 5.4
    rect((8, y), (72, y + 3.6), fill: if k == 6 { c.orange } else { c.grey2 }, stroke: none)
  }
  // L3: the layer fits.
  let (l0, l1) = (175, 265)
  rect((l0, 8), (l1, 66), fill: paper, stroke: .6pt + c.line, radius: 2)
  content(((l0 + l1) / 2, 58), lbl([L3 · 36 MB], size: 7.5pt, weight: 600))
  rect((l0 + 6, 16), (l1 - 6, 46), fill: none, stroke: .5pt + c.line)
  rect((l0 + 6, 16), (l0 + 6 + (l1 - l0 - 12) * 31.5 / 36, 46), fill: c.orange1, stroke: none)
  content(((l0 + l1) / 2, 31), txt(size: 7pt, fill: c.orange)[layer _i_ · 31.5 MiB])
  // Cores.
  let (k0, k1) = (315, 385)
  rect((k0, 8), (k1, 66), fill: paper, stroke: .6pt + c.line, radius: 2)
  content(((k0 + k1) / 2, 58), lbl([20 threads], size: 7.5pt, weight: 600))
  for r in range(4) {
    for q in range(5) {
      rect((k0 + 7 + q * 12, 14 + r * 9), (k0 + 15 + q * 12, 20 + r * 9), fill: c.orange2, stroke: none)
    }
  }
  arw((72, my), (l0, my), color: c.orange)
  content(((80 + l0) / 2, my + 3), txt(size: 7pt)[1 word per 64 B line], anchor: "south")
  content(((80 + l0) / 2, my - 3), txt(size: 7pt, fill: c.muted)[≈ 16 µs / MiB], anchor: "north")
  arw((l1, my), (k0, my), color: c.orange)
  content(((l1 + k0) / 2, my + 3), txt(size: 7pt)[compute], anchor: "south")
  content(((l1 + k0) / 2, my - 3), txt(size: 7pt, fill: c.muted)[4 µs / MiB], anchor: "north")
  // Tie each CPU block to its traffic.
  let tie = (paint: c.muted, thickness: .6pt, dash: "dotted")
  line(((80 + l0) / 2, cy), ((80 + l0) / 2, my + 14), stroke: tie)
  line(((l1 + k0) / 2, cy), ((l1 + k0) / 2, my + 14), stroke: tie)
})

// Compute time left after the warm-up window (Q2_K, 20 threads), sequential
// vs interleaved compute order, from the same run.
#let fig-warm-window() = canvas({
  import cetz.draw: *
  let (w, h) = (360, 200)
  let X(t) = t / 500 * w
  let Y(t) = t / 550 * h
  content((-34, h + 16), tag[CPU Stage 1 time after the window], anchor: "west")
  content((-6, h + 4), txt(size: 7pt)[µs], anchor: "south-east")
  for t in range(0, 501, step: 100) {
    line((0, Y(t)), (w, Y(t)), stroke: if t == 0 { axis-stroke } else { grid-stroke })
    content((-6, Y(t)), lbl(str(t), size: 7.5pt), anchor: "east")
  }
  for t in (0, 100, 200, 300, 400, 500) {
    line((X(t), 0), (X(t), -3), stroke: axis-stroke)
    content((X(t), -11), lbl(str(t), size: 7.5pt))
  }
  content((w / 2, -25), txt[warm-up window W (µs), all 20 threads reading the next layer's weights])
  line((X(192), 0), (X(192), h), stroke: (paint: c.blue, thickness: .7pt, dash: "dashed"))
  content((X(192) + 3, h - 2), txt(size: 7pt, fill: c.blue)[Q8_0 FFN#sub[i−1] = 192 µs], anchor: "north-west")
  for (v, s) in ((84.19, "KV 0"), (122.77, "KV 8K"), (235.75, "KV 32K")) {
    line((0, Y(v)), (w, Y(v)), stroke: (paint: c.teal, thickness: .7pt, dash: "dotted"))
    content((w + 4, Y(v)), txt(size: 7pt, fill: c.teal)[attn#sub[i] #s · #num(v, digits: 0)], anchor: "west")
  }
  line((0, Y(127.4)), (w, Y(127.4)), stroke: (paint: c.muted, thickness: .7pt, dash: "dashed"))
  content((4, Y(127.4) + 3), txt(size: 7pt)[cache-hot: 127], anchor: "south-west")
  let ws = (0, 120, 180, 330, 500)
  series(ws.zip((500.6, 456, 418.6, 292.6, 175.1)).map(((t, v)) => (X(t), Y(v))), c.muted, marker: "hollow")
  series(ws.zip((498, 429.5, 378.4, 248.7, 181.1)).map(((t, v)) => (X(t), Y(v))), c.orange)
  content((X(330) + 6, Y(292.6) + 2), lbl("sequential order", size: 7.5pt, fill: c.muted, weight: 600), anchor: "south-west")
  content((X(250) - 4, Y(310)), lbl("interleaved order", size: 7.5pt, fill: c.orange, weight: 600), anchor: "north-east")
})

// Per-layer timeline, to scale, KV 0, Qwen3-8B Q8_0 on the GPU.
#let fig-stall() = canvas({
  import cetz.draw: *
  let s = 0.55
  let X(t) = t * s
  let (bh, step) = (15, 24)
  let attn-end = 192 + 84.19
  let gy = 4 * step + 6
  content((-8, gy + bh / 2), lbl("GPU", weight: 600), anchor: "east")
  rect((X(0), gy), (X(192), gy + bh), fill: c.blue1, stroke: .5pt + c.blue)
  content((X(96), gy + bh / 2), lbl([FFN#sub[i−1] · 192], size: 7pt))
  rect((X(192), gy), (X(attn-end), gy + bh), fill: c.blue2, stroke: .5pt + c.blue)
  content((X(234), gy + bh / 2), lbl([attn#sub[i] · 84], size: 7pt))
  content((X(attn-end) + 6, gy + bh / 2), txt(size: 7pt)[then FFN#sub[i] waits for the mask], anchor: "west")
  let rows = (
    ([dense, no warm-up], none, 524.8),
    ([dense + warm-up], 192, 424),
    ([input-sparse, _s_#sub[1] = 0.7], none, 203.1),
    ([input-sparse, _s_#sub[1] = 0.9], none, 76.5),
  )
  for (i, (label, warm, t)) in rows.enumerate() {
    let y = (3 - i) * step
    content((-8, y + bh / 2), lbl(label, size: 7.5pt), anchor: "east")
    if warm != none {
      rect((X(0), y), (X(warm), y + bh), fill: c.orange1, stroke: (paint: c.orange, thickness: .6pt, dash: "dashed"))
      content((X(warm / 2), y + bh / 2), lbl([warm-up], size: 7pt, fill: c.orange))
    }
    let end = 192 + t
    rect((X(192), y), (X(end), y + bh), fill: c.orange, stroke: .5pt + paper)
    let body = if t > 150 [Stage 1 · #num(t, digits: 0)] else [#num(t, digits: 0)]
    content((X(192) + 4, y + bh / 2), lbl(body, size: 7pt, fill: paper, weight: 600), anchor: "west")
    let d = t - 84.19
    if d > 0 {
      content((X(end) + 5, y + bh / 2), lbl([stall #num(d, digits: 0) µs], size: 7.5pt, fill: c.danger, weight: 600), anchor: "west")
    } else {
      content((X(end) + 5, y + bh / 2), lbl([hidden (#num(d, digits: 0) µs)], size: 7.5pt, fill: c.teal, weight: 600), anchor: "west")
    }
  }
  line((X(attn-end), -4), (X(attn-end), gy + bh + 4), stroke: (paint: c.danger, thickness: .7pt, dash: "dashed"))
  content((X(attn-end), -6), txt(size: 7pt, fill: c.danger)[attn#sub[i] ends], anchor: "north")
  line((X(500), -10), (X(700), -10), stroke: .8pt + c.line)
  for t in (500, 700) { line((X(t), -7), (X(t), -13), stroke: .8pt + c.line) }
  content((X(600), -14), txt(size: 7pt)[200 µs], anchor: "north")
})

// Why input sparsity needs a transposed layout.
#let fig-layout() = canvas({
  import cetz.draw: *
  let (cw, ch, nr, nc) = (14, 9, 10, 12)
  let kept-in(k) = calc.rem(k * 7, 10) < 3
  // Left: llama.cpp layout, blocks along the input dimension.
  content((0, 150), lbl("llama.cpp Q2_K: blocks run along inputs", weight: 600), anchor: "west")
  for k in range(nc * 4) {
    let x = k * cw / 4
    rect((x + .5, 118), (x + cw / 4 - .5, 128), fill: if kept-in(k) { c.blue } else { c.grey2 }, stroke: none)
  }
  content((nc * cw + 4, 123), txt(size: 7pt)[inputs], anchor: "west")
  for r in range(nr) {
    for k in range(nc) {
      rect((k * cw, 110 - (r + 1) * ch), ((k + 1) * cw, 110 - r * ch), fill: c.orange2, stroke: .5pt + paper)
    }
  }
  content((nc * cw + 4, 110 - nr * ch / 2), txt(size: 7pt)[output rows], anchor: "west")
  content((0, 6), txt(size: 7pt)[cell: 256 inputs of one output (84 B)], anchor: "west")
  content((0, -5), txt(size: 7pt)[all cells hold kept inputs → *all bytes read*], anchor: "west")
  // Right: transposed, one row per input.
  let x0 = 300
  content((x0, 150), lbl("transposed: one row per input", weight: 600), anchor: "west")
  let kept-row(r) = r in (1, 4, 8)
  for r in range(nr) {
    let y1 = 128 - r * (ch + 2)
    rect((x0 - 12, y1 - ch), (x0 - 4, y1), fill: if kept-row(r) { c.blue } else { c.grey2 }, stroke: none)
    for k in range(nc) {
      rect(
        (x0 + k * cw, y1 - ch),
        (x0 + (k + 1) * cw, y1),
        fill: if kept-row(r) { c.orange2 } else { c.grey1 },
        stroke: .5pt + paper,
      )
    }
  }
  content((x0 + nc * cw + 4, 123), txt(size: 7pt)[input rows], anchor: "west")
  content((x0, 6), txt(size: 7pt)[row: 24 576 outputs, 96 blocks (8064 B)], anchor: "west")
  content((x0, -5), txt(size: 7pt)[skipped input = skipped row → *bytes ∝ 1 − s#sub[1]*], anchor: "west")
})

// Transposed-Q2_K Stage 1 latency vs input sparsity, against the GPU attention
// it has to hide under.
#let sp-s1 = (0, 0.25, 0.5, 0.6, 0.7, 0.8, 0.9)
#let sp-lat = (
  ("ideal: dense × (1 − s1)", c.muted, "dashed", "none", (524.8, 393.6, 262.4, 209.92, 157.44, 104.96, 52.48)),
  ("read only (no compute)", c.blue2, none, "circle", (521, 400.8, 283.2, 230.4, 175.3, 118.8, 55.1)),
  ("int8 kernel (AVX-VNNI)", c.orange, none, "square", (566.6, 451.9, 321.3, 264.2, 203.1, 141.5, 76.5)),
  ("fp32 kernel", c.muted, none, "hollow", (653.7, 532.8, 381.5, 308.9, 234.9, 160.4, 82.2)),
)

#let fig-sparse-latency() = canvas({
  import cetz.draw: *
  let (w, h) = (360, 210)
  let X(s) = s / 0.9 * w
  let Y(t) = t / 700 * h
  content((-34, h + 16), tag[CPU Stage 1 per layer], anchor: "west")
  content((-6, h + 4), txt(size: 7pt)[µs], anchor: "south-east")
  for t in range(0, 701, step: 100) {
    line((0, Y(t)), (w, Y(t)), stroke: if t == 0 { axis-stroke } else { grid-stroke })
    content((-6, Y(t)), lbl(str(t), size: 7.5pt), anchor: "east")
  }
  for s in sp-s1 {
    line((X(s), 0), (X(s), -3), stroke: axis-stroke)
    content((X(s), -11), lbl(str(s), size: 7.5pt))
  }
  content((w / 2, -25), txt[input sparsity _s_#sub[1] (share of the 4096 inputs skipped)])
  let attn = ((84.19, "KV 0"), (122.77, "KV 8K"), (235.75, "KV 32K"))
  for (v, s) in attn {
    line((0, Y(v)), (w, Y(v)), stroke: (paint: c.teal, thickness: .7pt, dash: "dotted"))
    content((w + 4, Y(v)), txt(size: 7pt, fill: c.teal)[GPU attn#sub[i] #s · #num(v, digits: 0)], anchor: "west")
  }
  for (_, color, dash, mk, vals) in sp-lat {
    let pts = sp-s1.zip(vals).map(((s, t)) => (X(s), Y(t)))
    if mk == "none" {
      line(..pts, stroke: (paint: color, thickness: 1pt, dash: dash))
    } else {
      series(pts, color, marker: mk, w: if color == c.orange { 1.6pt } else { 1.1pt })
    }
  }
  let int8 = sp-lat.at(2).at(4)
  for (k, (v, _)) in attn.enumerate() {
    let s = crossing(sp-s1, int8, v)
    circle((X(s), Y(v)), radius: 3.2, fill: paper, stroke: 1.2pt + c.orange)
    let body = box(fill: paper, inset: 1.5pt, lbl("≈" + num(s, digits: 2), size: 7pt, fill: c.orange, weight: 600))
    if k == 0 {
      content((X(s) - 6, Y(v) - 4), body, anchor: "north-east")
    } else if k == 1 {
      content((X(s) - 8, Y(v) + 4), body, anchor: "south-east")
    } else {
      content((X(s) - 8, Y(v) - 4), body, anchor: "north-east")
    }
  }
  for (i, (name, color, dash, _, _)) in sp-lat.enumerate() {
    let (lx, ly) = (215, h - 6 - i * 12)
    line((lx, ly), (lx + 14, ly), stroke: (paint: color, thickness: 1.3pt, dash: dash))
    content((lx + 18, ly), lbl(name, size: 7.5pt), anchor: "west")
  }
})

// ============================================================================
// Discussion: input sparsity as 0-bit quantization
// ============================================================================

// Uniform quantization of weights in [-1, 1]. (a) Cells, stored midpoints and
// the error of one weight w = 0.9 at b = 0..3. (b) The error w - w_hat over the
// whole interval: w itself at b = 0, then a sawtooth of height ±Δ/2.
#let fig-quant-error() = canvas({
  import cetz.draw: *
  let (sx, pitch, sy) = (80, 24, 42)
  let w = 0.9
  let cells(b) = calc.pow(2, b)
  let mid(v, b) = if b == 0 { 0 } else {
    let d = 2 / cells(b)
    -1 + (calc.min(calc.floor((v + 1) / d), cells(b) - 1) + 0.5) * d
  }
  let minus(v) = str(v).replace("-", "−")
  // (a) One weight at b = 0..3.
  let Xa(v) = (v + 1) * sx
  let Ya(b) = (3 - b) * pitch + 20
  let top = Ya(0) + 22
  content((Xa(-1) - 30, top), lbl([(a) one weight, _w_ = 0.9], weight: 600), anchor: "west")
  for b in range(4) {
    let (y, n) = (Ya(b), cells(b))
    content((Xa(-1) - 8, y), lbl([_b_ = #b], size: 7.5pt), anchor: "east")
    line((Xa(-1), y), (Xa(1), y), stroke: axis-stroke)
    for k in range(n + 1) {
      let v = -1 + k * 2 / n
      line((Xa(v), y - 4), (Xa(v), y + 4), stroke: axis-stroke)
    }
    let m = mid(w, b)
    line((Xa(m), y), (Xa(w), y), stroke: 2.2pt + c.orange)
    let vals = if b == 0 { (0,) } else { range(n).map(k => -1 + (k + 0.5) * 2 / n) }
    for v in vals { circle((Xa(v), y), radius: 2.2, fill: c.blue, stroke: .6pt + paper) }
    content((Xa(1) + 6, y), lbl([error #num(w - m, digits: 3)], size: 7pt, fill: c.orange), anchor: "west")
  }
  line((Xa(w), Ya(3) - 7), (Xa(w), Ya(0) + 7), stroke: 1pt + c.ink)
  for v in (-1, 0, 1) { content((Xa(v), Ya(3) - 14), lbl(minus(v), size: 7pt, fill: c.muted)) }
  // (b) The error over the whole interval.
  let bx = Xa(1) + 100
  let yc = Ya(1.5)
  let Xb(v) = bx + (v + 1) * sx
  let Yb(e) = yc + e * sy
  content((Xb(-1) - 30, top), lbl([(b) error _w_ − _ŵ_ for every _w_], weight: 600), anchor: "west")
  for e in (-1, -0.5, 0.5, 1) {
    line((Xb(-1), Yb(e)), (Xb(1), Yb(e)), stroke: grid-stroke)
    content((Xb(-1) - 5, Yb(e)), lbl(minus(e), size: 7pt, fill: c.muted), anchor: "east")
  }
  line((Xb(-1), yc), (Xb(1), yc), stroke: axis-stroke)
  content((Xb(-1) - 5, yc), lbl("0", size: 7pt, fill: c.muted), anchor: "east")
  line((Xb(-1), Yb(-1)), (Xb(1), Yb(1)), stroke: 1.2pt + c.muted)
  for (b, color) in ((1, c.blue), (2, c.orange)) {
    let d = 2 / cells(b)
    for k in range(cells(b)) {
      let lo = -1 + k * d
      line((Xb(lo), Yb(-d / 2)), (Xb(lo + d), Yb(d / 2)), stroke: 1.4pt + color)
    }
  }
  for (b, e, ms, color) in ((0, 1, "1/3", c.muted), (1, 0.5, "1/12", c.blue), (2, 0.25, "1/48", c.orange)) {
    content((Xb(1) + 5, Yb(e)), lbl([_b_ = #b: mean square #ms], size: 7pt, fill: color, weight: 600), anchor: "west")
  }
  for v in (-1, 0, 1) { content((Xb(v), Yb(-1) - 10), lbl(minus(v), size: 7pt, fill: c.muted)) }
  content((Xb(0), Yb(-1) - 22), txt(size: 7.5pt)[weight _w_])
  content((Xa(0), Ya(3) - 26), txt(size: 7.5pt)[weight _w_])
})

// The 4-row example on a log scale: one bit lowers a bar by log2(4) = 2.
#let fig-waterfill() = canvas({
  import cetz.draw: *
  let ls = (6, 4, 2, -2) // log2(a_i), a = 64, 16, 4, 0.25
  let scores = ("8", "4", "2", "0.5")
  let sy = 11
  let Y(l) = (l + 3) * sy
  let (bw, pitch) = (26, 40)
  let panel(x0, title, bits, water: none) = {
    content((x0, Y(7) + 12), lbl(title, weight: 600), anchor: "west")
    let w = 4 * pitch
    for l in (-2, 0, 2, 4, 6) {
      line((x0 - 4, Y(l)), (x0 + w, Y(l)), stroke: grid-stroke)
    }
    for (i, l) in ls.enumerate() {
      let x = x0 + 8 + i * pitch
      let b = bits.at(i)
      let r = l - 2 * b
      rect((x, 0), (x + bw, Y(r)), fill: c.grey2, stroke: none)
      for p in range(b) {
        let (lo, hi) = (l - 2 * (p + 1), l - 2 * p)
        rect((x, Y(lo)), (x + bw, Y(hi)), fill: c.blue, stroke: .6pt + paper)
        content((x + bw / 2, (Y(lo) + Y(hi)) / 2), lbl("bit " + str(p + 1), size: 6.5pt, fill: paper))
      }
      content((x + bw / 2, -9), lbl(scores.at(i), size: 7.5pt))
      content((x + bw / 2, -21), lbl(str(b), size: 7.5pt, fill: c.blue, weight: 600))
      let e = calc.pow(2.0, r)
      content((x + bw / 2, -33), lbl(if e < 1 { str(e) } else { str(int(e)) }, size: 7.5pt))
    }
    line((x0 - 4, 0), (x0 + w, 0), stroke: axis-stroke)
    if water != none {
      line((x0 - 4, Y(water)), (x0 + w + 4, Y(water)), stroke: (paint: c.teal, thickness: 1pt, dash: "dashed"))
      content((x0 + w + 6, Y(water)), txt(size: 7pt, fill: c.teal)[water level θ = 1], anchor: "west")
    }
  }
  panel(0, [(a) greedy / water-filling], (3, 2, 1, 0), water: 0)
  panel(270, [(b) Prox: 0 or 2 bits], (2, 2, 2, 0))
  for (l, s) in ((-2, "1/4"), (0, "1"), (2, "4"), (4, "16"), (6, "64")) {
    content((-8, Y(l)), lbl(s, size: 7pt, fill: c.muted), anchor: "east")
  }
  content((-8, Y(7)), txt(size: 7pt, fill: c.muted)[error], anchor: "east")
  for (y, s) in ((-9, [score]), (-21, [bits]), (-33, [error left])) {
    content((-8, y), txt(size: 7pt)[#s], anchor: "east")
  }
  content((88, -50), lbl([6 bits → error *3.25*], size: 8pt))
  content((358, -50), lbl([6 bits → error *5.5*], size: 8pt))
  rect((120, -72), (130, -64), fill: c.blue, stroke: none)
  content((134, -68), txt[removed by one bit (÷4)], anchor: "west")
  rect((260, -72), (270, -64), fill: c.grey2, stroke: none)
  content((274, -68), txt[error left], anchor: "west")
})

// Bits per row against the row's score (log2 of score / sqrt(theta)).
#let fig-bit-staircase() = canvas({
  import cetz.draw: *
  let (sx, sy) = (62, 22)
  let (lo, hi, bmax) = (-1.5, 4.4, 4.4)
  let X(l) = (l - lo) * sx
  let Y(b) = b * sy
  rect((X(lo), 0), (X(0), Y(bmax)), fill: c.grey1, stroke: none)
  content((X((lo + 0) / 2), Y(bmax) - 8), txt(size: 7pt)[0 bits = skipped input], anchor: "north")
  for b in range(5) {
    line((X(lo), Y(b)), (X(hi), Y(b)), stroke: if b == 0 { axis-stroke } else { grid-stroke })
    content((X(lo) - 5, Y(b)), lbl(str(b), size: 7.5pt), anchor: "east")
  }
  content((X(lo) - 22, Y(bmax / 2)), txt(size: 7.5pt)[bits #linebreak() _b#sub[i]_], anchor: "east")
  for (k, s) in ((-1, [√θ / 2]), (0, [√θ]), (1, [2√θ]), (2, [4√θ]), (3, [8√θ]), (4, [16√θ])) {
    line((X(k), 0), (X(k), -3), stroke: axis-stroke)
    content((X(k), -11), lbl(s, size: 7.5pt))
  }
  content((X((lo + hi) / 2), -27), txt[row importance #box[$|x_i| dot norm(W_(i,:))$] (log scale, ×2 per tick)])
  // Closed form, clipped at 0.
  line((X(lo), 0), (X(0), 0), (X(hi), Y(hi)), stroke: (paint: c.muted, thickness: 1pt, dash: "dashed"))
  content((X(hi) + 4, Y(hi)), txt(size: 7pt, fill: c.muted)[closed form #box[$1/2 log_2 (a_i \/ theta)$]], anchor: "west")
  // Whole bits: one more each time the score doubles.
  let pts = ((X(lo), 0), (X(0), 0))
  for k in range(4) {
    pts += ((X(k), Y(k + 1)), (X(calc.min(k + 1, hi)), Y(k + 1)))
  }
  pts += ((X(hi), Y(4)),)
  line(..pts, stroke: (paint: c.blue, thickness: 1.6pt, join: "round"))
  content((X(hi) + 4, Y(4) - 4), lbl("whole bits", size: 7.5pt, fill: c.blue, weight: 600), anchor: "west")
  // Prox: one threshold, 0 or 2 bits.
  let tx = 1.4
  line((X(lo), 1.5), (X(tx), 1.5), (X(tx), Y(2)), (X(hi), Y(2)), stroke: (paint: c.orange, thickness: 1.6pt, join: "round"))
  content((X(hi) + 4, Y(2)), lbl("Prox: 0 or 2", size: 7.5pt, fill: c.orange, weight: 600), anchor: "west")
  content((X(tx), Y(2) + 4), txt(size: 7pt, fill: c.orange)[τ#sub[x]], anchor: "south")
  // The four rows of the greedy example (θ = 1): scores 8, 4, 2, 0.5.
  for (l, b, name) in ((3, 3, "row 1"), (2, 2, "row 2"), (1, 1, "row 3"), (-1, 0, "row 4")) {
    circle((X(l), Y(b)), radius: 2.6, fill: c.ink, stroke: .8pt + paper)
    if b == 0 {
      content((X(l), Y(b) + 5), lbl(name, size: 7pt), anchor: "south")
    } else {
      content((X(l) + 5, Y(b) - 2), lbl(name, size: 7pt), anchor: "north-west")
    }
  }
})

// Bit-plane Stage 1: plane p of row i is read only when |x_i| >= tau_p.
#let fig-bitplane() = canvas({
  import cetz.draw: *
  let xs = (0.3, 2.6, 0.9, 5.2, 0.4, 1.4, 3.1, 0.7, 1.1, 0.2)
  let taus = (0.8, 1.6, 3.2)
  let (x0, pitch, cw, sy, base) = (70, 30, 22, 17, 76)
  let w = xs.len() * pitch
  content((x0 - 8, base + 50), txt(size: 7.5pt)[|x#sub[i]|], anchor: "east")
  for (i, v) in xs.enumerate() {
    let x = x0 + i * pitch
    let on = v >= taus.at(0)
    rect((x, base), (x + cw, base + v * sy), fill: if on { c.blue } else { c.grey2 }, stroke: none)
  }
  line((x0 - 4, base), (x0 + w, base), stroke: axis-stroke)
  for (p, t) in taus.enumerate() {
    line((x0 - 4, base + t * sy), (x0 + w, base + t * sy), stroke: (paint: c.orange, thickness: .8pt, dash: "dashed"))
    content((x0 + w + 4, base + t * sy), txt(size: 7pt, fill: c.orange)[τ#sub[#(p + 1)]], anchor: "west")
  }
  // One strip per plane, rows stored contiguously.
  let names = ([plane 1 (sign)], [plane 2], [plane 3])
  for (p, t) in taus.enumerate() {
    let y = 52 - p * 18
    content((x0 - 8, y + 6), txt(size: 7.5pt)[#names.at(p)], anchor: "east")
    let n = 0
    for (i, v) in xs.enumerate() {
      let x = x0 + i * pitch
      let on = v >= t
      if on { n += 1 }
      rect((x, y), (x + cw, y + 12), fill: if on { c.orange2 } else { c.grey1 }, stroke: .5pt + if on { c.orange2 } else { c.line })
    }
    content((x0 + w + 4, y + 6), lbl([#n #if n == 1 [row] else [rows] read], size: 7.5pt), anchor: "west")
  }
  content((x0 - 8, -6), txt(size: 7pt)[input row], anchor: "east")
  for i in range(xs.len()) {
    content((x0 + i * pitch + cw / 2, -6), lbl(str(i + 1), size: 6.5pt, fill: c.muted))
  }
  content((x0 + w / 2, -22), lbl([$w approx alpha_1 b_1 + alpha_2 b_2 + alpha_3 b_3$, #h(4pt) $b_p in {-1, +1}$: each plane adds or subtracts $alpha_p x_i$], size: 7.5pt))
})

// BCQ on four weights: layer 1 jumps +-alpha_1 from 0, layer 2 adds +-alpha_2.
#let fig-bcq() = canvas({
  import cetz.draw: *
  let ws = (0.7, -0.3, 1.2, -0.9)
  let (a1, a2) = (0.775, 0.275)
  let sgn(v) = if v >= 0 { 1 } else { -1 }
  let (sx, row, x0) = (110, 26, 0)
  let X(v) = x0 + v * sx
  let (lo, hi) = (-1.4, 1.4)
  let top = ws.len() * row
  // Grid: 0 and the four 2-bit values.
  for v in (-1.05, -0.5, 0.5, 1.05) {
    line((X(v), -4), (X(v), top), stroke: grid-stroke)
  }
  line((X(0), -4), (X(0), top), stroke: axis-stroke)
  for v in (-1, -0.5, 0, 0.5, 1) {
    content((X(v), -12), lbl(str(v).replace("-", "−"), size: 7pt, fill: c.muted))
  }
  let arrow(a, b, y, color) = line((X(a), y), (X(b), y), stroke: 1.6pt + color, mark: (end: "stealth", fill: color, scale: .5))
  for (i, w) in ws.enumerate() {
    let y = top - (i + .5) * row
    content((X(lo) - 6, y), lbl([_w_#sub[#(i + 1)] = #str(w).replace("-", "−")], size: 7.5pt), anchor: "east")
    let v1 = sgn(w) * a1
    let v2 = v1 + sgn(w - v1) * a2
    arrow(0, v1, y + 3, c.blue)
    arrow(v1, v2, y - 3, c.orange)
    // The original weight.
    line((X(w), y - 8), (X(w), y + 8), stroke: 1.4pt + c.ink)
  }
  // Legend.
  let ly = -30
  line((X(-1.3), ly), (X(-1.1), ly), stroke: 1.6pt + c.blue, mark: (end: "stealth", fill: c.blue, scale: .5))
  content((X(-1.05), ly), lbl([layer 1: ±α#sub[1] = ±0.775], size: 7pt), anchor: "west")
  line((X(-0.15), ly), (X(0.05), ly), stroke: 1.6pt + c.orange, mark: (end: "stealth", fill: c.orange, scale: .5))
  content((X(0.1), ly), lbl([layer 2: ±α#sub[2] = ±0.275], size: 7pt), anchor: "west")
  line((X(1.05), ly - 6), (X(1.05), ly + 6), stroke: 1.4pt + c.ink)
  content((X(1.1), ly), lbl([original _w_], size: 7pt), anchor: "west")
})
