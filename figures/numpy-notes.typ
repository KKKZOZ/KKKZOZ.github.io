// Detailed figures for content/posts/ml-systems/numpy-notes.typ, drawn with
// cetz. Each `fig-*` function returns one canvas; coordinates are in points
// (1pt per unit, y grows upward) and every figure stays under ~560pt wide, so
// it renders at true scale in the 760px column.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, tag, txt

// Cell tones: fill, stroke, text.
#let tones = (
  a: (c.blue1, c.blue, c.ink),
  b: (c.orange1, c.orange, c.ink),
  t: (c.teal1, c.teal, c.ink),
  g: (c.grey1, c.grey2, c.muted),
  ghost: (white, c.grey2, c.muted),
  dark: (c.ink, c.ink, white),
  bad: (white, c.danger, c.danger),
)

/// A bold label in a theme colour; unlike `tag` it keeps case, for code.
#let lab(body, fill: c.ink) = text(size: 8pt, weight: 700, fill: fill, body)

/// One square cell whose top-left corner is (x, y).
#let cell(x, y, body, tone: "a", s: 22, size: 8pt) = {
  import cetz.draw: *
  let (fill, edge, ink) = tones.at(tone)
  let stroke = if tone == "ghost" { (paint: edge, thickness: .6pt, dash: "dashed") } else { .6pt + edge }
  rect((x + 1, y - 1), (x + s - 1, y - s + 1), fill: fill, stroke: stroke, radius: 1.5)
  if body != none { content((x + s / 2, y - s / 2), txt(body, size: size, fill: ink, weight: 600)) }
}

/// A matrix of cells with its top-left corner at (x, y). `vals` is a list of
/// rows; `tone(r, k)` picks each cell's tone.
#let mat(x, y, vals, tone: (r, k) => "a", s: 22, size: 8pt) = {
  for (r, row) in vals.enumerate() {
    for (k, v) in row.enumerate() {
      cell(x + k * s, y - r * s, if v == none { none } else { str(v) }, tone: tone(r, k), s: s, size: size)
    }
  }
}

// ============================================================================
// reshape
// ============================================================================

/// reshape = flatten row by row, then refill row by row.
#let fig-reshape() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let src(v) = if v <= 6 { "a" } else { "b" }
  // (2, 6)
  content((0, 26), lab("a · shape (2, 6)", fill: c.blue), anchor: "west")
  let a = ((1, 2, 3, 4, 5, 6), (7, 8, 9, 10, 11, 12))
  mat(0, 12, a, tone: (r, k) => src(a.at(r).at(k)))
  // (3, 4)
  let (bx, by) = (390, 12)
  content((bx, 26), lab("a.reshape(3, 4)", fill: c.teal), anchor: "west")
  let b = ((1, 2, 3, 4), (5, 6, 7, 8), (9, 10, 11, 12))
  mat(bx, by, b, tone: (r, k) => src(b.at(r).at(k)))
  // flat strip
  let (fx, fy) = (30, -82)
  content((fx, fy + 14), txt("one row-major stream · shape (12,)", size: 7.5pt), anchor: "west")
  for i in range(12) { cell(fx + i * s, fy, str(i + 1), tone: src(i + 1)) }
  for i in (1, 2, 3) {
    line((fx + i * 4 * s, fy + 3), (fx + i * 4 * s, fy - s - 3), stroke: (paint: c.teal, thickness: .9pt, dash: "dashed"))
  }
  content((fx + 2 * s, fy - s - 10), txt("row 0", size: 7pt, fill: c.teal))
  content((fx + 6 * s, fy - s - 10), txt("row 1", size: 7pt, fill: c.teal))
  content((fx + 10 * s, fy - s - 10), txt("row 2", size: 7pt, fill: c.teal))
  // arrows
  arrow((3 * s, 12 - 2 * s - 4), (3 * s, fy + 22))
  content((3 * s + 8, -50), txt("① flatten, row by row", fill: c.ink, weight: 600), anchor: "west")
  arrow((fx + 12 * s + 6, fy - s / 2), (bx + 2 * s, by - 3 * s - 4))
  content((bx + 2 * s + 4, -78), txt("② refill, 4 per row", fill: c.ink, weight: 600), anchor: "west")
  // legend
  legend(0, -136, "from a[0]", box-swatch(0, -136, c.blue1, stroke: .6pt + c.blue))
  legend(80, -136, "from a[1]", box-swatch(80, -136, c.orange1, stroke: .6pt + c.orange))
  content((170, -136), txt("order never changes; only the row boundaries move"), anchor: "west")
})

// ============================================================================
// transpose
// ============================================================================

/// transpose(2, 0, 1) permutes the axes: shape and strides move together,
/// the data stays where it is.
#let fig-transpose() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, gap) = (92, 40, 22)
  let x(i) = 96 + i * (w + gap)
  let axis-box(i, y, ax, n, st, tone) = {
    let (fill, edge, _) = tones.at(tone)
    rect((x(i), y), (x(i) + w, y - h), fill: fill, stroke: .7pt + edge, radius: 3)
    content((x(i) + w / 2, y - 12), txt("axis " + str(i) + " = old " + str(ax), size: 7pt))
    content((x(i) + w / 2, y - 28), txt("len " + str(n) + " · stride " + str(st), size: 8pt, fill: c.ink, weight: 600))
  }
  let old = ((0, 2, 48, "a"), (1, 3, 16, "b"), (2, 4, 4, "t"))
  content((0, -20), txt("a", size: 10pt, fill: c.ink, weight: 700), anchor: "west")
  content((0, -34), txt("(2, 3, 4) int32", size: 7pt), anchor: "west")
  for (i, (ax, n, st, tone)) in old.enumerate() {
    let (fill, edge, _) = tones.at(tone)
    rect((x(i), 0), (x(i) + w, -h), fill: fill, stroke: .7pt + edge, radius: 3)
    content((x(i) + w / 2, -12), txt("axis " + str(i), size: 7pt))
    content((x(i) + w / 2, -28), txt("len " + str(n) + " · stride " + str(st), size: 8pt, fill: c.ink, weight: 600))
  }
  let y2 = -100
  content((0, y2 - 20), txt("b", size: 10pt, fill: c.ink, weight: 700), anchor: "west")
  content((0, y2 - 34), txt("(4, 2, 3) int32", size: 7pt), anchor: "west")
  content((0, -h - 30), lab("a.transpose(2, 0, 1)", fill: c.orange), anchor: "west")
  let order = (2, 0, 1)
  for (i, ax) in order.enumerate() {
    let (_, n, st, tone) = old.at(ax)
    axis-box(i, y2, ax, n, st, tone)
    let (_, edge, _) = tones.at(tone)
    arrow((x(ax) + w / 2, -h - 3), (x(i) + w / 2, y2 + 3), color: edge, w: .9pt)
  }
  content((x(1) + w / 2, y2 - h - 18), text(9pt, fill: c.ink)[`b[k, i, j]` is `a[i, j, k]` — same bytes, new index order])
  content((x(1) + w / 2, y2 - h - 34), txt("strides are bytes to step along an axis; transpose only reorders them (a view, no copy)", size: 7pt))
})

// ============================================================================
// concatenate & stack
// ============================================================================

/// concatenate joins along an axis that already exists.
#let fig-concatenate() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  // axis = 0
  content((0, 30), lab("np.concatenate((A, B), axis=0)", fill: c.blue), anchor: "west")
  content((0, 12), txt("A (2, 2)", size: 7pt), anchor: "west")
  mat(0, 0, ((1, 2), (3, 4)), tone: (r, k) => "a")
  content((64, 12), txt("B (1, 2)", size: 7pt), anchor: "west")
  mat(64, 0, ((5, 6),), tone: (r, k) => "b")
  arrow((122, -2 * s / 2 - 4), (148, -2 * s / 2 - 4))
  content((160, 12), txt("(3, 2)", size: 7pt, fill: c.ink, weight: 600), anchor: "west")
  mat(160, 0, ((1, 2), (3, 4), (5, 6)), tone: (r, k) => if r < 2 { "a" } else { "b" })
  arrow((160 + 2 * s + 8, 0), (160 + 2 * s + 8, -3 * s), color: c.orange, w: .9pt)
  content((160 + 2 * s + 12, -3 * s / 2), txt("axis 0 grows", size: 7pt, fill: c.orange), anchor: "west")
  // axis = 1
  let ox = 300
  content((ox, 30), lab("np.concatenate((A, C), axis=1)", fill: c.blue), anchor: "west")
  content((ox, 12), txt("A (2, 2)", size: 7pt), anchor: "west")
  mat(ox, 0, ((1, 2), (3, 4)), tone: (r, k) => "a")
  content((ox + 58, 12), txt("C (2, 2)", size: 7pt), anchor: "west")
  mat(ox + 58, 0, ((5, 6), (7, 8)), tone: (r, k) => "t")
  arrow((ox + 112, -s), (ox + 136, -s))
  content((ox + 146, 12), txt("(2, 4)", size: 7pt, fill: c.ink, weight: 600), anchor: "west")
  mat(ox + 146, 0, ((1, 2, 5, 6), (3, 4, 7, 8)), tone: (r, k) => if k < 2 { "a" } else { "t" })
  arrow((ox + 146, -2 * s - 8), (ox + 146 + 4 * s, -2 * s - 8), color: c.orange, w: .9pt)
  content((ox + 146 + 2 * s, -2 * s - 18), txt("axis 1 grows", size: 7pt, fill: c.orange))
  content((0, -92), txt("every other axis must match: A and B share 2 columns; A and C share 2 rows · ndim stays 2"), anchor: "west")
})

/// stack adds a new axis k (k = 0 → a, k = 1 → b) at the given position.
#let fig-stack() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let src = (r, k, v) => if v <= 4 { "a" } else { "b" }
  let a = ((1, 2), (3, 4))
  let b = ((5, 6), (7, 8))
  // inputs
  content((0, 26), tag("inputs", fill: c.muted), anchor: "west")
  content((0, 10), txt("a", size: 8pt, fill: c.ink, weight: 700), anchor: "west")
  mat(0, 0, a, tone: (r, k) => "a")
  content((0, -54), txt("b", size: 8pt, fill: c.ink, weight: 700), anchor: "west")
  mat(0, -64, b, tone: (r, k) => "b")
  line((74, 30), (74, -130), stroke: .5pt + c.hair)
  // results: s[0] and s[1] for each axis
  let results = (
    ("axis=0 ·", "s[k, i, j]", (((1, 2), (3, 4)), ((5, 6), (7, 8))), "s[0] = a, s[1] = b"),
    ("axis=1 ·", "s[i, k, j]", (((1, 2), (5, 6)), ((3, 4), (7, 8))), "s[i] = (a[i], b[i])"),
    ("axis=2 ·", "s[i, j, k]", (((1, 5), (2, 6)), ((3, 7), (4, 8))), "s[i, j] = (a[i, j], b[i, j])"),
  )
  for (n, (title, idx, slices, rule)) in results.enumerate() {
    let ox = 100 + n * 150
    content((ox, 26), lab(title, fill: c.blue), anchor: "west")
    content((ox + 52, 26), txt(idx, size: 7.5pt, fill: c.ink), anchor: "west")
    for (q, m) in slices.enumerate() {
      let oy = -q * 64
      content((ox, oy + 10), txt("s[" + str(q) + "]", size: 7.5pt), anchor: "west")
      mat(ox, oy, m, tone: (r, k) => if m.at(r).at(k) <= 4 { "a" } else { "b" })
    }
    content((ox, -122), txt(rule, size: 7pt), anchor: "west")
  }
  content((100, -142), txt("all are (2, 2, 2) · k picks a or b · axis= sets where k sits in the index"), anchor: "west")
})

// ============================================================================
// broadcasting
// ============================================================================

/// Align shapes on the right, pad with 1s, then compare dim by dim.
#let fig-broadcast-rules() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h) = (34, 20)
  // One shape row; `cols` is the number of aligned columns, `dims` may be
  // shorter (padded on the left). `mark(i)` picks the tone per column.
  let shape-row(ox, y, cols, dims, mark) = {
    let pad = cols - dims.len()
    for i in range(cols) {
      let x = ox + i * w
      let (v, tone) = if i < pad { ("1", "ghost") } else { (str(dims.at(i - pad)), mark(i)) }
      let (fill, edge, ink) = tones.at(tone)
      let stroke = if tone == "ghost" { (paint: edge, thickness: .6pt, dash: "dashed") } else { .6pt + edge }
      rect((x + 2, y), (x + w - 2, y - h), fill: fill, stroke: stroke, radius: 2)
      content((x + w / 2, y - h / 2), txt(v, size: 8.5pt, fill: ink, weight: 600))
    }
  }
  let example(ox, title, x, y, out, verdicts, tone-x, tone-y, ok) = {
    let cols = calc.max(x.len(), y.len())
    content((ox, 34), tag(title, fill: if ok { c.blue } else { c.danger }), anchor: "west")
    let lx = ox + 22
    content((ox, -h / 2), txt("x", size: 8pt, fill: c.ink, weight: 700), anchor: "west")
    shape-row(lx, 0, cols, x, tone-x)
    content((ox, -28 - h / 2), txt("y", size: 8pt, fill: c.ink, weight: 700), anchor: "west")
    shape-row(lx, -28, cols, y, tone-y)
    for (i, v) in verdicts.enumerate() {
      content((lx + i * w + w / 2, -62), txt(v, size: 6.5pt, fill: if v == "✗" { c.danger } else { c.muted }))
    }
    line((lx, -72), (lx + cols * w, -72), stroke: .7pt + c.line)
    content((ox, -80 - h / 2), txt(if ok { "out" } else { "" }, size: 8pt, fill: c.ink, weight: 700), anchor: "west")
    if ok {
      shape-row(lx, -80, cols, out, i => "dark")
    } else {
      content((lx + cols * w / 2, -80 - h / 2), txt("ValueError: 3 vs 2, neither is 1", size: 7.5pt, fill: c.danger, weight: 600))
    }
    arrow((lx + cols * w, 18), (lx, 18), color: c.muted, w: .5pt)
    content((lx + cols * w + 4, 18), txt("compare from the right", size: 6.5pt), anchor: "west")
  }
  example(
    0, "compatible", (8, 1, 6, 1), (7, 1, 5), (8, 7, 6, 5),
    ("pad → 8", "1 → 7", "1 → 6", "1 → 5"),
    i => if i == 1 or i == 3 { "b" } else { "a" },
    i => if i == 2 { "b" } else { "a" },
    true,
  )
  example(
    320, "incompatible", (2, 3), (2,), none,
    ("pad → 2", "✗"),
    i => if i == 1 { "bad" } else { "a" },
    i => if i == 1 { "bad" } else { "a" },
    false,
  )
  legend(0, -118, "padded on the left (rule 1)", box-swatch(0, -118, white, stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed")))
  legend(170, -118, "size 1, stretched (rule 2b)", box-swatch(170, -118, c.orange1, stroke: .6pt + c.orange))
  legend(340, -118, "result: max per dim", box-swatch(340, -118, c.ink))
})

/// x (4, 1) + y (1, 3): each side is copied along its size-1 axis.
#let fig-broadcast-stretch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let xs = range(4).map(i => (i, i, i))
  let ys = range(4).map(_ => (0, 1, 2))
  // x
  content((0, 26), lab("x · (4, 1)", fill: c.blue), anchor: "west")
  mat(0, 12, xs, tone: (r, k) => if k == 0 { "a" } else { "ghost" })
  arrow((s + 4, 12 - 4 * s - 6), (3 * s, 12 - 4 * s - 6), color: c.blue, w: .7pt)
  content((2 * s + 2, 12 - 4 * s - 14), txt("copy →", size: 6.5pt, fill: c.blue))
  content((3 * s + 18, 12 - 2 * s), text(14pt, fill: c.muted)[+])
  // y
  let yx = 3 * s + 36
  content((yx, 26), lab("y · (1, 3)", fill: c.orange), anchor: "west")
  mat(yx, 12, ys, tone: (r, k) => if r == 0 { "b" } else { "ghost" })
  arrow((yx + 3 * s + 6, 12 - s - 2), (yx + 3 * s + 6, 12 - 4 * s), color: c.orange, w: .7pt)
  content((yx + 3 * s + 10, 12 - 2.5 * s), txt("copy ↓", size: 6.5pt, fill: c.orange), anchor: "west")
  content((yx + 3 * s + 50, 12 - 2 * s), text(14pt, fill: c.muted)[=])
  // result
  let rx = yx + 3 * s + 72
  content((rx, 26), lab("x + y · (4, 3)", fill: c.teal), anchor: "west")
  mat(rx, 12, range(4).map(i => (i, i + 1, i + 2)), tone: (r, k) => "t")
  legend(0, -104, "real data", box-swatch(0, -104, c.blue1, stroke: .6pt + c.blue))
  legend(80, -104, "virtual copy (stride 0, no memory)", box-swatch(80, -104, white, stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed")))
})

// ============================================================================
// boolean masks
// ============================================================================

/// a[mask] flattens the hits; np.where keeps the shape.
#let fig-mask() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let a = ((1, 2, 3, 4), (5, 6, 7, 8), (9, 10, 11, 12))
  content((0, 26), lab("five_up = (a >= 5)", fill: c.orange), anchor: "west")
  mat(0, 12, a, tone: (r, k) => if a.at(r).at(k) >= 5 { "b" } else { "g" })
  content((0, 12 - 3 * s - 12), txt("orange = True · (3, 4) bool", size: 7pt), anchor: "west")
  // a[mask]
  let ox = 150
  content((ox, 26), lab("a[five_up]", fill: c.blue), anchor: "west")
  content((ox, 12 - s - 10), txt("(8,) · 1-D, shape lost", size: 7pt), anchor: "west")
  for i in range(8) { cell(ox + i * s, 12, str(i + 5), tone: "b") }
  arrow((4 * s + 8, 12 - s / 2), (ox - 8, 12 - s / 2))
  // np.where
  let wy = -50
  content((ox, wy + 14), lab("np.where(five_up, a, 0)", fill: c.teal), anchor: "west")
  content((ox + 4 * s + 10, wy - 1.5 * s), txt("(3, 4) · shape kept,\nmisses become 0", size: 7pt), anchor: "west")
  mat(ox, wy, a.map(row => row.map(v => if v >= 5 { v } else { 0 })), tone: (r, k) => if a.at(r).at(k) >= 5 { "b" } else { "g" })
  arrow((4 * s + 8, 12 - 2 * s), (ox - 8, wy - s))
})

// ============================================================================
// matmul
// ============================================================================

/// (3, 4) @ (2, 4, 5): the last two axes multiply, the rest broadcast.
#let fig-matmul-batch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let u = 11
  let dz = (9, 7)
  // A rectangle `rows` x `cols` (in u) whose top-left corner is (x, y),
  // with `depth` copies stacked behind it.
  let stack(x, y, rows, cols, depth, tone, ghost: false) = {
    let (fill, edge, _) = tones.at(tone)
    for d in range(depth - 1, -1, step: -1) {
      let (ddx, ddy) = (d * dz.at(0), d * dz.at(1))
      let back = ghost and d > 0
      rect((x + ddx, y + ddy), (x + ddx + cols * u, y + ddy - rows * u),
        fill: if back { white } else { fill },
        stroke: if back { (paint: c.grey2, thickness: .6pt, dash: "dashed") } else { .7pt + edge })
    }
  }
  let y0 = 0
  // arr1
  content((0, 40), lab("arr1 · (3, 4)", fill: c.blue), anchor: "west")
  stack(0, y0, 3, 4, 2, "a", ghost: true)
  content((2 * u, y0 - 3 * u - 10), txt("4", size: 7.5pt, fill: c.orange, weight: 700))
  content((-6, y0 - 1.5 * u), txt("3", size: 7.5pt), anchor: "east")
  content((2 * u, y0 - 3 * u - 24), txt("reused for each batch", size: 6.5pt))
  content((4 * u + 30, y0 - 1.5 * u), text(12pt, fill: c.muted)[\@])
  // arr2
  let x2 = 4 * u + 66
  content((x2, 40), lab("arr2 · (2, 4, 5)", fill: c.orange), anchor: "west")
  stack(x2, y0, 4, 5, 2, "b")
  content((x2 - 6, y0 - 2 * u), txt("4", size: 7.5pt, fill: c.orange, weight: 700), anchor: "east")
  content((x2 + 2.5 * u, y0 - 4 * u - 10), txt("5", size: 7.5pt))
  content((x2 + 5 * u + dz.at(0) + 4, y0 + dz.at(1) - 4), txt("2 matrices", size: 6.5pt), anchor: "west")
  content((x2 + 5 * u + 50, y0 - 2 * u), text(12pt, fill: c.muted)[=])
  // result
  let x3 = x2 + 5 * u + 74
  content((x3, 40), lab("arr1 @ arr2 · (2, 3, 5)", fill: c.teal), anchor: "west")
  stack(x3, y0, 3, 5, 2, "t")
  content((x3 - 6, y0 - 1.5 * u), txt("3", size: 7.5pt), anchor: "east")
  content((x3 + 2.5 * u, y0 - 3 * u - 10), txt("5", size: 7.5pt))
  // shape algebra
  let ty = -78
  let row(y, label, a, b, out) = {
    content((0, y), txt(label, size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
    content((120, y), txt(a, size: 7.5pt), anchor: "west")
    content((210, y), txt(b, size: 7.5pt), anchor: "west")
    content((300, y), txt(out, size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
  }
  row(ty, "batch axes (broadcast)", "()", "(2,)", "→ (2,)")
  row(ty - 16, "matrix axes (@)", "(3, 4)", "(4, 5)", "→ (3, 5)  inner 4 must match")
})
