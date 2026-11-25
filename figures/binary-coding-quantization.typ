// Figures for content/posts/ml-systems/binary-coding-quantization.typ, drawn
// with cetz. True scale (1pt per unit, y grows upward, under ~560pt wide),
// colours from the theme kit so every figure follows the day / night switch.
// Small examples are computed by hand in the post; distribution numbers
// (Gaussian, Laplace, uniform) come from numpy simulations.

#import "@tola-modules/nasapunk:0.0.0": cetz, c, palette, txt

#let paper = palette.paper
#let grid-stroke = (paint: c.hair, thickness: .5pt, dash: "dotted")
#let axis-stroke = .6pt + c.line
#let canvas(body) = cetz.canvas(length: 1pt, body)
#let lbl(body, size: 8pt, fill: c.ink, weight: 400) = txt(body, size: size, fill: fill, weight: weight)
#let log10(v) = calc.log(v, base: 10)
/// A number with a typographic minus sign.
#let fmt(v) = str(v).replace("-", "−")
#let sgn(v) = if v >= 0 { 1 } else { -1 }

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

#let arw(..pts, color: c.line, w: .8pt, dash: none) = cetz.draw.line(
  ..pts,
  stroke: (paint: color, thickness: w, dash: dash),
  mark: (end: "stealth", fill: color, scale: .5),
)

/// All 2^P sums of +-alpha_p, sorted.
#let levels(alphas) = {
  let out = (0,)
  for a in alphas {
    out = out.map(v => (v - a, v + a)).flatten()
  }
  out.sorted()
}

// ============================================================================
// 1. The format
// ============================================================================

// Eight weights, three greedy planes: one sign per weight and plane, one
// alpha per plane.
#let fig-format() = canvas({
  import cetz.draw: *
  let w = (0.9, -0.4, 0.2, -1.3, 0.6, -0.1, 0.3, -0.8)
  let planes = (
    (1, -1, 1, -1, 1, -1, 1, -1),
    (1, 1, -1, -1, 1, 1, -1, -1),
    (1, -1, -1, -1, -1, 1, 1, 1),
  )
  let alphas = ("0.575", "0.325", "0.15")
  let rec = (1.05, -0.4, 0.1, -1.05, 0.75, -0.1, 0.4, -0.75)
  let ds = ("0.304", "0.082", "0.034")
  let (x0, cw, ch) = (128, 34, 18)
  let X(j) = x0 + j * cw
  let rx = X(8) + 12
  let yw = 100
  // The group: g = 8 weights, indexed by j.
  line((X(0), 132), (X(0), 136), (X(8), 136), (X(8), 132), stroke: .6pt + c.muted)
  content((X(4), 140), lbl([one group: _g_ = 8 weights], size: 7.5pt, weight: 600), anchor: "south")
  content((x0 - 10, 118), txt(size: 7.5pt)[index _j_], anchor: "east")
  for j in range(8) {
    content((X(j) + cw / 2, 118), lbl(str(j + 1), size: 7pt, fill: c.muted))
  }
  content((x0 - 10, yw), lbl[weight _w#sub[j]_], anchor: "east")
  for (j, v) in w.enumerate() {
    content((X(j) + cw / 2, yw), lbl(fmt(v), size: 7.5pt, weight: 600))
  }
  content((rx, yw + 6), txt(size: 7pt)[error left after], anchor: "west")
  content((rx, yw - 4), txt(size: 7pt)[planes 1 to _p_], anchor: "west")
  for (p, signs) in planes.enumerate() {
    let y = 86 - p * (ch + 4)
    content((x0 - 10, y - ch / 2), lbl([_p_ = #(p + 1) · α#sub[#(p + 1)] = #alphas.at(p)], size: 7.5pt), anchor: "east")
    for (j, s) in signs.enumerate() {
      let pos = s > 0
      rect(
        (X(j) + 1, y), (X(j) + cw - 1, y - ch),
        fill: if pos { c.blue1 } else { c.orange1 },
        stroke: .5pt + if pos { c.blue } else { c.orange },
      )
      content((X(j) + cw / 2, y - ch / 2), lbl(if pos { "+1" } else { "−1" }, size: 7.5pt))
    }
    content((rx, y - ch / 2), lbl(ds.at(p), size: 7.5pt), anchor: "west")
  }
  // The P = 3 planes, as a bracket on the left.
  let (ptop, pbot) = (86, 86 - 3 * (ch + 4) + 4)
  line((24, ptop), (20, ptop), (20, pbot), (24, pbot), stroke: .6pt + c.muted)
  content((16, (ptop + pbot) / 2), align(right, lbl([_P_ = 3 \ planes], size: 7.5pt, weight: 600)), anchor: "east")
  let yr = 86 - 3 * (ch + 4) - 8
  line((X(0), yr + 8), (X(8), yr + 8), stroke: axis-stroke)
  content((x0 - 10, yr), lbl[3-bit value #box[$hat(w)_j$]], anchor: "east")
  for (j, v) in rec.enumerate() {
    content((X(j) + cw / 2, yr), lbl(fmt(v), size: 7.5pt, fill: c.blue))
  }
  content((X(4), yr - 16), txt(size: 7.5pt)[column _j_: #box[$hat(w)_j = alpha_1 b_(1,j) + alpha_2 b_(2,j) + alpha_3 b_(3,j)$]\; row _p_: bit plane _p_])
})

// The values a group can take: all 2^P signed sums of its alphas.
#let fig-grid() = canvas({
  import cetz.draw: *
  let rows = (
    ([1 plane], (1,), [α = (1)]),
    ([2 planes], (1, 0.5), [α = (1, 0.5): even]),
    ([2 planes], (1, 0.3), [α = (1, 0.3): uneven]),
    ([3 planes], (1, 0.5, 0.25), [α = (1, 0.5, 0.25): even]),
  )
  let (x0, sx, pitch) = (70, 80, 34)
  let X(v) = x0 + (v + 2) * sx
  let n = rows.len()
  for (r, (name, al, note)) in rows.enumerate() {
    let y = (n - 1 - r) * pitch
    content((x0 - 10, y), lbl(name, size: 7.5pt), anchor: "east")
    line((X(-2), y), (X(2), y), stroke: axis-stroke)
    line((X(0), y - 4), (X(0), y + 4), stroke: .8pt + c.muted)
    let lv = levels(al)
    for v in lv {
      circle((X(v), y), radius: 2.8, fill: c.blue, stroke: .6pt + paper)
      content((X(v), y - 6), lbl(fmt(calc.round(v, digits: 2)), size: 6.5pt, fill: c.muted), anchor: "north")
    }
    content((X(2) + 10, y), lbl(note, size: 7.5pt), anchor: "west")
  }
  content((X(0), (n - 1) * pitch + 14), txt(size: 7pt)[0], anchor: "south")
})

// ============================================================================
// 2. Fitting the scales
// ============================================================================

// The same four weights fitted two ways: greedy alpha = (0.5, 0.45) against
// the best alpha for the same signs, (0.8, 0.6).
#let fig-fit() = canvas({
  import cetz.draw: *
  let ws = (-0.3, -0.1, 0.2, 1.4)
  let row = 24
  let top = ws.len() * row
  let sx = 70
  let panel(x0, title, a1, a2, sse, names: false) = {
    let X(v) = x0 + (v + 1.5) * sx
    for v in (-a1 - a2, -a1 + a2, a1 - a2, a1 + a2) {
      line((X(v), -4), (X(v), top), stroke: grid-stroke)
    }
    line((X(0), -4), (X(0), top), stroke: axis-stroke)
    for v in (-1, 0, 1) {
      content((X(v), -12), lbl(fmt(v), size: 7pt, fill: c.muted))
    }
    content((X(-1.5), top + 12), lbl(title, weight: 600), anchor: "west")
    let bar(a, b, y, color) = line(
      (X(a), y), (X(b), y),
      stroke: 1.6pt + color, mark: (end: "stealth", fill: color, scale: .5),
    )
    for (i, w) in ws.enumerate() {
      let y = top - (i + .5) * row
      if names {
        content((X(-1.5) - 6, y), lbl([_w_#sub[#(i + 1)] = #fmt(w)], size: 7.5pt), anchor: "east")
      }
      let v1 = sgn(w) * a1
      let v2 = v1 + sgn(w - v1) * a2
      bar(0, v1, y + 3, c.blue)
      bar(v1, v2, y - 3, c.orange)
      line((X(w), y - 8), (X(w), y + 8), stroke: 1.4pt + c.ink)
    }
    content((X(0.05), -28), lbl([α = (#fmt(a1), #fmt(a2)) · squared error *#sse*], size: 7.5pt))
  }
  panel(52, [(a) greedy], 0.5, 0.45, "0.29", names: true)
  panel(310, [(b) α refitted for the same signs], 0.8, 0.6, "0.02")
  let ly = -48
  let X0(v) = 52 + (v + 1.5) * sx
  line((X0(-1.3), ly), (X0(-1.05), ly), stroke: 1.6pt + c.blue, mark: (end: "stealth", fill: c.blue, scale: .5))
  content((X0(-1.0), ly), lbl([plane 1: ±α#sub[1]], size: 7pt), anchor: "west")
  line((X0(0.2), ly), (X0(0.45), ly), stroke: 1.6pt + c.orange, mark: (end: "stealth", fill: c.orange, scale: .5))
  content((X0(0.5), ly), lbl([plane 2: ±α#sub[2]], size: 7pt), anchor: "west")
  line((X0(1.8), ly - 6), (X0(1.8), ly + 6), stroke: 1.4pt + c.ink)
  content((X0(1.86), ly), lbl([original _w_], size: 7pt), anchor: "west")
  content((X0(3.2), ly), txt(size: 7pt)[dotted: the four values of the grid], anchor: "west")
})

// Two planes as sign + magnitude: the density of |w| for Gaussian weights,
// the split into small / large, and the two magnitude levels.
#let fig-magnitude() = canvas({
  import cetz.draw: *
  let (sx, sy, mmax) = (120, 62, 3.0)
  let f(m) = calc.sqrt(2 / calc.pi) * calc.exp(-m * m / 2)
  let ms = range(0, 61).map(k => k * 0.05)
  let panel(y0, title, t, lv, means, below, d) = {
    let X(m) = m * sx
    let Y(v) = y0 + v * sy
    content((X(0), Y(1.12)), lbl(title, weight: 600), anchor: "west")
    let left = ms.filter(m => m <= t)
    let rightm = ms.filter(m => m >= t)
    line((X(0), Y(0)), ..left.map(m => (X(m), Y(f(m)))), (X(t), Y(f(t))), (X(t), Y(0)), close: true, fill: c.blue1, stroke: none)
    line((X(t), Y(0)), (X(t), Y(f(t))), ..rightm.map(m => (X(m), Y(f(m)))), (X(mmax), Y(0)), close: true, fill: c.orange1, stroke: none)
    line(..ms.map(m => (X(m), Y(f(m)))), stroke: 1pt + c.ink)
    line((X(0), Y(0)), (X(mmax), Y(0)), stroke: axis-stroke)
    line((X(t), Y(0)), (X(t), Y(0.86)), stroke: (paint: c.ink, thickness: .8pt, dash: "dashed"))
    content((X(t) + 3, Y(0.86)), txt(size: 7pt)[split at #t], anchor: "west")
    content((X(t / 2), Y(0.12)), lbl([#below.at(0) small], size: 7pt, fill: c.blue, weight: 600))
    content((X(2.2), Y(0.2)), lbl([#below.at(1) large], size: 7pt, fill: c.orange, weight: 600))
    // Magnitude levels (filled) and the mean |w| of each class (hollow).
    for v in lv {
      line((X(v), Y(0) - 2), (X(v), Y(0) - 12), stroke: 2pt + c.blue)
      content((X(v), Y(0) - 14), lbl(str(v), size: 6.5pt, fill: c.blue), anchor: "north")
    }
    if means != none {
      for v in means {
        circle((X(v), Y(0) - 7), radius: 2.6, fill: paper, stroke: 1pt + c.ink)
      }
    }
    content((X(mmax) + 6, Y(0.4)), lbl([_D_(2) = #d], size: 7.5pt), anchor: "west")
  }
  panel(118, [(a) greedy: levels 0.798 ± 0.483], 0.798, (0.315, 1.281), (0.378, 1.365), ("57.5%", "42.5%"), "0.130")
  panel(0, [(b) best: levels at the class means], 0.981, (0.452, 1.510), none, ("67.3%", "32.7%"), "0.117")
  for m in (0, 1, 2, 3) {
    content((m * sx, -32), lbl(str(m), size: 7pt, fill: c.muted))
  }
  content((1.5 * sx, -44), txt(size: 7.5pt)[magnitude |_w_| (Gaussian weights, σ = 1)])
  line((300, -44), (300, -56), stroke: 2pt + c.blue)
  content((305, -50), txt(size: 7pt)[magnitude level], anchor: "west")
  circle((392, -50), radius: 2.6, fill: paper, stroke: 1pt + c.ink)
  content((398, -50), txt(size: 7pt)[mean |_w_| of the class], anchor: "west")
})

// ============================================================================
// 3. How fast the error falls
// ============================================================================

#let fig-decay() = canvas({
  import cetz.draw: *
  let (sx, sy, x0) = (78, 54, 40)
  let X(p) = x0 + p * sx
  let Y(d) = (log10(d) + 2.6) * sy
  for (d, s) in ((1, "1"), (0.3, "0.3"), (0.1, "0.1"), (0.03, "0.03"), (0.01, "0.01"), (0.003, "0.003")) {
    line((X(0) - 4, Y(d)), (X(4) + 4, Y(d)), stroke: grid-stroke)
    content((X(0) - 8, Y(d)), lbl(s, size: 7pt, fill: c.muted), anchor: "east")
  }
  line((X(0) - 4, Y(0.0025)), (X(4) + 4, Y(0.0025)), stroke: axis-stroke)
  for p in range(5) {
    content((X(p), Y(0.0025) - 10), lbl(str(p), size: 7.5pt))
  }
  content((X(2), Y(0.0025) - 24), txt[planes read])
  content((X(0) - 8, Y(1) + 14), txt(size: 7.5pt)[_D_], anchor: "east")
  let pts(ds) = ds.enumerate().map(((p, d)) => (X(p), Y(d)))
  series(pts((1, 0.25, 0.0624, 0.0156, 0.0039)), c.muted, dash: "dashed", marker: "none", w: 1pt)
  series(pts((1, 0.501, 0.230, 0.143, 0.096)), c.blue, dash: "dashed", marker: "hollow", w: .9pt)
  series(pts((1, 0.363, 0.130, 0.058, 0.033)), c.blue)
  series(pts((1, 0.363, 0.117, 0.037, 0.0115)), c.teal)
  let lx = X(4) + 10
  content((lx, Y(0.096)), lbl([greedy, Laplace], size: 7pt, fill: c.blue, weight: 600), anchor: "west")
  content((lx, Y(0.033)), lbl([greedy, Gaussian], size: 7pt, fill: c.blue, weight: 600), anchor: "west")
  content((lx, Y(0.0115)), lbl([alternating, Gaussian], size: 7pt, fill: c.teal, weight: 600), anchor: "west")
  content((lx, Y(0.0039)), lbl([greedy, uniform (÷4 per plane)], size: 7pt, fill: c.muted), anchor: "west")
})

// ============================================================================
// 4. Computing with bit planes
// ============================================================================

// Packed 2-bit codes against bit planes: which bytes a 1-bit read touches.
#let fig-layout() = canvas({
  import cetz.draw: *
  let bw = 15
  let byte(x, y, cells, read) = {
    for (k, (name, hi)) in cells.enumerate() {
      rect(
        (x + k * bw, y), (x + (k + 1) * bw, y + 18),
        fill: if hi { c.blue1 } else { c.orange1 },
        stroke: .5pt + c.line,
      )
      content((x + k * bw + bw / 2, y + 9), lbl(name, size: 6pt))
    }
    rect((x, y), (x + 8 * bw, y + 18), fill: none, stroke: if read { 1.6pt + c.ink } else { (paint: c.line, thickness: .6pt, dash: "dashed") })
  }
  let x0 = 104
  // Packed: each byte holds both bits of four weights.
  let yp = 60
  content((x0 - 10, yp + 9), lbl([packed (Q2_K)], size: 7.5pt), anchor: "east")
  let packed(off) = {
    let out = ()
    for k in range(4) {
      out.push((str(off + k + 1), true))
      out.push((str(off + k + 1), false))
    }
    out
  }
  byte(x0, yp, packed(0), true)
  byte(x0 + 8 * bw + 10, yp, packed(4), true)
  content((x0 + 16 * bw + 20, yp + 9), lbl([1 bit of _w_#sub[1]–_w_#sub[8]: read both bytes], size: 7.5pt), anchor: "west")
  // Planar: one byte per plane.
  let yq = 20
  content((x0 - 10, yq + 9), lbl([bit planes (BCQ)], size: 7.5pt), anchor: "east")
  byte(x0, yq, range(8).map(k => (str(k + 1), true)), true)
  byte(x0 + 8 * bw + 10, yq, range(8).map(k => (str(k + 1), false)), false)
  content((x0 + 4 * bw, yq - 8), txt(size: 7pt)[plane 1], anchor: "north")
  content((x0 + 12 * bw + 10, yq - 8), txt(size: 7pt)[plane 2], anchor: "north")
  content((x0 + 16 * bw + 20, yq + 9), lbl([1 bit of _w_#sub[1]–_w_#sub[8]: read plane 1 only], size: 7.5pt), anchor: "west")
  // Legend.
  rect((x0, -30), (x0 + 10, -22), fill: c.blue1, stroke: .5pt + c.line)
  content((x0 + 14, -26), txt(size: 7pt)[first bit of weight _k_], anchor: "west")
  rect((x0 + 130, -30), (x0 + 140, -22), fill: c.orange1, stroke: .5pt + c.line)
  content((x0 + 144, -26), txt(size: 7pt)[second bit], anchor: "west")
  rect((x0 + 220, -30), (x0 + 240, -22), fill: none, stroke: 1.6pt + c.ink)
  content((x0 + 244, -26), txt(size: 7pt)[bytes read], anchor: "west")
})

// A lookup table over mu = 3 inputs: 8 signed sums, then one lookup per
// three sign bits of every row.
#let fig-lut() = canvas({
  import cetz.draw: *
  let xs = ("0.5", "−1", "2")
  // Inputs.
  content((20, 132), lbl([input chunk], size: 7.5pt, weight: 600))
  for (k, v) in xs.enumerate() {
    let y = 104 - k * 24
    rect((0, y), (40, y + 18), fill: c.grey1, stroke: .5pt + c.line)
    content((20, y + 9), lbl([_x_#sub[#(k + 1)] = #v], size: 7.5pt))
  }
  arw((50, 82), (90, 82))
  content((70, 76), align(center, txt(size: 7pt)[once per \ input]), anchor: "north")
  // Table: index bits b1 b2 b3 (1 = +1, 0 = -1).
  let vals = ("−1.5", "2.5", "−3.5", "0.5", "−0.5", "3.5", "−2.5", "1.5")
  let bits = ("000", "001", "010", "011", "100", "101", "110", "111")
  let (tx, th) = (96, 15)
  content((tx + 60, 132), lbl([table: all 8 signed sums], size: 7.5pt, weight: 600))
  let ty(k) = 116 - (k + 1) * th
  for k in range(8) {
    let y = ty(k)
    rect((tx, y), (tx + 40, y + th), fill: c.grey1, stroke: .5pt + paper)
    content((tx + 20, y + th / 2), lbl(raw(bits.at(k)), size: 7pt))
    rect((tx + 40, y), (tx + 120, y + th), fill: paper, stroke: .5pt + c.line)
    content((tx + 80, y + th / 2), lbl(vals.at(k), size: 7.5pt))
  }
  content((tx + 60, ty(7) - 10), txt(size: 7pt)[#raw("101") = +_x_#sub[1] − _x_#sub[2] + _x_#sub[3] = 3.5])
  // Weight rows: three sign bits each, one lookup each.
  let rows = (("row a", "101", 5), ("row b", "011", 3), ("row c", "110", 6))
  let rx = 330
  content((rx + 40, 132), lbl([sign bits of one plane], size: 7.5pt, weight: 600))
  for (r, (name, b, k)) in rows.enumerate() {
    let y = 100 - r * 34
    content((rx - 8, y + 9), lbl(name, size: 7.5pt), anchor: "east")
    rect((rx, y), (rx + 48, y + 18), fill: c.blue1, stroke: .5pt + c.blue)
    content((rx + 24, y + 9), lbl(raw(b), size: 8pt))
    arw((rx - 34, y + 9), (tx + 124, ty(k) + th / 2), color: c.blue)
    content((rx + 56, y + 9), lbl([→ #vals.at(k)], size: 7.5pt), anchor: "west")
  }
})
