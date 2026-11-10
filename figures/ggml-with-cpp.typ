// Figures for content/posts/ml-systems/ggml-with-cpp.typ, drawn with cetz.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, curve-arrow, legend

// ============================================================================
// Shared pieces
// ============================================================================

#let txt(body, size: 9pt, fill: c.muted, weight: 400, style: "normal") = text(
  size: size, fill: fill, weight: weight, style: style, body,
)
#let head(body, fill: c.ink) = text(size: 9pt, weight: 700, fill: fill, body)
#let dotted = (paint: c.line, thickness: .5pt, dash: "dotted")
#let dashed(color) = (paint: color, thickness: .8pt, dash: "dashed")

#let tones = (
  leaf: (fill: c.teal1, stroke: c.teal, ink: c.ink),
  op: (fill: c.blue1, stroke: c.blue, ink: c.ink),
  hot: (fill: c.orange1, stroke: c.orange, ink: c.ink),
  plain: (fill: white, stroke: c.line, ink: c.ink),
  grey: (fill: c.grey1, stroke: c.grey2, ink: c.muted),
  dark: (fill: c.ink, stroke: c.ink, ink: white),
)

/// A rounded box with a bold label and an optional muted second line.
#let node(pos, body, name: none, tone: "op", anchor: "center", width: auto, size: 9pt, weight: 600, dash: none, note: none) = {
  let t = tones.at(tone)
  let inner = text(size: size, weight: weight, fill: t.ink, body)
  if note != none {
    inner = inner + linebreak() + text(size: size - 1pt, weight: 400, fill: if tone == "dark" { white } else { c.muted }, note)
  }
  cetz.draw.content(pos, name: name, anchor: anchor, box(
    fill: t.fill, stroke: (paint: t.stroke, thickness: .8pt, dash: dash), radius: 4pt,
    inset: (x: 7pt, y: 5pt), width: if type(width) == int or type(width) == float { width * 1pt } else { width }, align(center, inner),
  ))
}

/// A row of labelled cells; `o` is the top-left corner.
#let vals(o, labels, w, ht, paint: k => c.grey1, size: 8.5pt, ink: k => c.ink, weight: 400) = {
  import cetz.draw: *
  let (x, y) = o
  for (k, body) in labels.enumerate() {
    rect((x + k * w, y), (x + (k + 1) * w, y - ht), fill: paint(k), stroke: .6pt + white)
    content((x + (k + .5) * w, y - ht / 2), txt(body, size: size, fill: ink(k), weight: weight))
  }
}

/// An arc with an arrow head from (x0, y) to (x1, y); `rise` < 0 bends it downward.
#let hop(x0, x1, y, rise, color: c.orange) = cetz.draw.bezier(
  (x0, y), (x1, y), (x0, y + rise), (x1, y + rise),
  stroke: .8pt + color, mark: (end: "stealth", fill: color, scale: .5),
)

/// A bracket under x0..x1 at height y, with a label below it.
#let brace(x0, x1, y, body, color: c.line) = {
  import cetz.draw: *
  line((x0, y), (x0, y - 4), (x1, y - 4), (x1, y), stroke: .7pt + color)
  content(((x0 + x1) / 2, y - 7), body, anchor: "north")
}

// ============================================================================
// Tensor layout: ne / nb, reshape, view, cont, permute
// ============================================================================

/// A [3, 2] F32 matrix: logical view and its row-major bytes.
#let fig-strides() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (cw, ch) = (34, 24)
  let names = (("a0", "a1", "a2"), ("b0", "b1", "b2"))
  let fills = (c.blue1, c.orange1)
  content((1.5 * cw, 40), head("Logical view"), anchor: "south")
  for r in range(2) {
    for k in range(3) {
      rect((k * cw, -r * ch), ((k + 1) * cw, -(r + 1) * ch), fill: fills.at(r), stroke: .6pt + white)
      content(((k + .5) * cw, -(r + .5) * ch), txt(names.at(r).at(k), fill: c.ink))
    }
  }
  arrow((0, 8), (3 * cw, 8), color: c.muted)
  content((1.5 * cw, 12), txt("ne0 = 3", size: 8.5pt), anchor: "south")
  arrow((-8, 0), (-8, -2 * ch), color: c.muted)
  content((-12, -ch), txt("ne1 = 2", size: 8.5pt), anchor: "east")

  let (x0, mw) = (180, 40)
  let flat = names.at(0) + names.at(1)
  for (i, n) in flat.enumerate() {
    rect((x0 + i * mw, -12), (x0 + (i + 1) * mw, -36), fill: fills.at(calc.floor(i / 3)), stroke: .6pt + white)
    content((x0 + (i + .5) * mw, -24), txt(n, fill: c.ink))
    content((x0 + i * mw, -40), txt("+" + str(4 * i), size: 7.5pt), anchor: "north")
  }
  content((x0 + 6 * mw, -40), txt("+24", size: 7.5pt), anchor: "north")
  content((x0, -56), head("Memory, row by row"), anchor: "north-west")

  hop(x0 + 20, x0 + 60, -12, 14, color: c.teal)
  content((x0 + 40, -1), txt("nb0 = 4 B", size: 8pt, fill: c.teal, weight: 600), anchor: "south")
  hop(x0 + 20, x0 + 140, -12, 56, color: c.orange)
  content((x0 + 80, 31), txt("nb1 = 12 B = nb0 × ne0", size: 8pt, fill: c.orange, weight: 600), anchor: "south")

  arrow((3 * cw + 10, -24), (x0 - 10, -24))
  content(((3 * cw + x0) / 2, -20), txt("flatten rows", size: 8pt), anchor: "south")

  content((-50, -84), txt([Address of element (i0, i1) = data + i0 · nb0 + i1 · nb1. Contiguous ⇔ nb1 = nb0 · ne0.], fill: c.ink), anchor: "north-west")
})

/// reshape keeps the bytes and the data pointer, only ne / nb change.
#let fig-reshape() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let cols = (c.blue1, c.teal1, c.orange1, c.blue2)
  let nm = ("a0", "a1", "a2", "a3")
  let (cw, ch) = (32, 24)
  // [2, 2]
  for i in range(4) {
    let (r, k) = (calc.floor(i / 2), calc.rem(i, 2))
    rect((k * cw, -r * ch), ((k + 1) * cw, -(r + 1) * ch), fill: cols.at(i), stroke: .6pt + white)
    content(((k + .5) * cw, -(r + .5) * ch), txt(nm.at(i), fill: c.ink))
  }
  content((cw, 6), txt("[2, 2]", fill: c.ink, weight: 700), anchor: "south")
  content((cw, -2 * ch - 6), align(center, txt("ne = {2, 2}\nnb = {4, 8}", size: 8pt)), anchor: "north")
  // [1, 4]
  let rx = 240
  for i in range(4) {
    rect((rx + i * cw, -12), (rx + (i + 1) * cw, -36), fill: cols.at(i), stroke: .6pt + white)
    content((rx + (i + .5) * cw, -24), txt(nm.at(i), fill: c.ink))
  }
  content((rx + 2 * cw, -6), txt("[1, 4]", fill: c.ink, weight: 700), anchor: "south")
  content((rx + 2 * cw, -42), align(center, txt("ne = {4, 1}\nnb = {4, 16}", size: 8pt)), anchor: "north")

  arrow((2 * cw + 10, -24), (rx - 10, -24), color: c.blue, w: .9pt)
  content(((2 * cw + rx) / 2, -20), txt("ggml_reshape_2d(ctx, a, 4, 1)", size: 8pt, fill: c.blue), anchor: "south")

  // shared bytes
  let mx = 120
  for i in range(4) {
    rect((mx + i * cw, -100), (mx + (i + 1) * cw, -124), fill: cols.at(i), stroke: .6pt + white)
    content((mx + (i + .5) * cw, -112), txt(nm.at(i), fill: c.ink))
  }
  curve-arrow((cw, -82), (mx + 4, -98), (cw, -98), (mx - 30, -98), color: c.orange)
  curve-arrow((rx + 2 * cw, -70), (mx + 10, -97), (rx + 2 * cw, -92), (mx + 60, -84), color: c.orange)
  content((mx + 2 * cw, -130), txt("Same data pointer; the bytes keep their order", size: 8pt, fill: c.ink), anchor: "north")
})

/// Three views into a KV cache of n_ctx = 6 positions × 8 floats (2 heads × 4).
#let fig-view-kv() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (nr, d, t) = (6, 8, 3)
  let (gw, gh) = (11, 9)
  let (sx, sw, sh) = (124, 6.4, 14)
  let pitch = 80
  let base(r) = if r <= t { c.grey2 } else { c.grey1 }
  let panels = (
    (
      title: "(a) Write a new token: cache[t]",
      code: "ggml_view_1d(ctx, cache, 8, t*cache->nb[1])",
      desc: "ne = {8}, offset = 3 · nb1 = 96 B: one contiguous run, written by ggml_cpy",
      hit: (r, k) => r == t, fill: c.orange,
    ),
    (
      title: "(b) Attention reads: cache[0..t]",
      code: "ggml_view_2d(ctx, cache, 8, t+1, cache->nb[1], 0)",
      desc: "ne = {8, 4}, nb1 = 32 B: a contiguous prefix from row 0",
      hit: (r, k) => r <= t, fill: c.blue2,
    ),
    (
      title: "(c) One head: cache[0..t, head 1]",
      code: "ggml_view_2d(ctx, cache, 4, t+1, cache->nb[1], 4*cache->nb[0])",
      desc: "ne = {4, 4}, nb1 = 32 B ≠ ne0 · nb0: not contiguous, skips head 0 in every row",
      hit: (r, k) => r <= t and k >= 4, fill: c.teal2,
    ),
  )
  content((2 * gw, 3), txt("head 0", size: 7pt), anchor: "south")
  content((6 * gw, 3), txt("head 1", size: 7pt), anchor: "south")
  for (i, p) in panels.enumerate() {
    let top = -i * pitch
    for r in range(nr) {
      content((-4, top - (r + .5) * gh), txt(if r == t { "t=3" } else { str(r) }, size: 6.5pt, fill: if r == t { c.orange } else { c.muted }), anchor: "east")
      for k in range(d) {
        let f = if (p.hit)(r, k) { p.fill } else { base(r) }
        rect((k * gw, top - r * gh), ((k + 1) * gw, top - (r + 1) * gh), fill: f, stroke: .5pt + white)
        let j = r * d + k
        rect((sx + j * sw, top - 28), (sx + (j + 1) * sw, top - 28 - sh), fill: f, stroke: .3pt + white)
      }
    }
    line((4 * gw, top), (4 * gw, top - nr * gh), stroke: .7pt + c.line)
    for r in range(1, nr) {
      line((sx + r * d * sw, top - 26), (sx + r * d * sw, top - 30 - sh), stroke: .6pt + c.line)
    }
    content((sx, top + 2), txt(p.title, fill: c.ink, weight: 700), anchor: "north-west")
    content((sx, top - 12), txt(p.code, size: 7.5pt, fill: c.blue), anchor: "north-west")
    content((sx, top - 47), txt(p.desc, size: 8pt), anchor: "north-west")
  }
  let ly = -2 * pitch - 76
  legend(0, ly, "K written so far", box-swatch(0, ly, c.grey2))
  legend(110, ly, "Empty (reserved for n_ctx)", box-swatch(110, ly, c.grey1))
  content((270, ly), txt("Right: the same 192 B in memory; bars mark rows", size: 8pt), anchor: "west")
})

/// ggml_cont gathers the rows of a strided view into a new contiguous tensor.
#let fig-cont() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (sw, sh) = (6.4, 14)
  for r in range(6) {
    for k in range(8) {
      let j = r * 8 + k
      let f = if r <= 3 and k >= 4 { c.teal2 } else if r <= 3 { c.grey2 } else { c.grey1 }
      rect((j * sw, 0), ((j + 1) * sw, -sh), fill: f, stroke: .3pt + white)
    }
    if r > 0 { line((r * 8 * sw, 2), (r * 8 * sw, -sh - 2), stroke: .6pt + c.line) }
  }
  for i in range(4) {
    content(((i * 8 + 6) * sw, 3), txt("i1=" + str(i), size: 7pt, fill: c.teal, weight: 600), anchor: "south")
  }
  content((0, 18), head("src: view (c) above, not contiguous"), anchor: "south-west")

  let (dx, dy) = (100, -64)
  for i in range(4) {
    rect((dx + i * 4 * sw, dy), (dx + (i + 1) * 4 * sw, dy - sh), fill: if calc.rem(i, 2) == 0 { c.teal2 } else { c.teal1 }, stroke: .6pt + white)
    arrow(((i * 8 + 6) * sw, -sh - 2), (dx + (i * 4 + 2) * sw, dy + 2), color: c.teal)
  }
  content((dx, dy - sh - 6), head("dst = ggml_cont(src): contiguous"), anchor: "north-west")
  content((230, -24), align(left, txt(
    "for i1 in 0..ne1:\n  memcpy(d, s + i1·nb1, ne0·nb0)\n  d += ne0·nb0",
    size: 8pt, fill: c.ink,
  )), anchor: "north-west")
  content((230, -66), txt("ne0·nb0 = 16 B per row, 4 memcpy calls", size: 8pt), anchor: "north-west")
})

/// permute swaps nb (and ne), the bytes stay where they are.
#let fig-permute() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let col = (a: c.blue1, b: c.teal1, c: c.orange1, d: c.blue2)
  let (cw, ch, mw) = (36, 24, 32)
  let grid(x0, rows) = {
    for (r, row) in rows.enumerate() {
      for (k, e) in row.enumerate() {
        rect((x0 + k * cw, -r * ch), (x0 + (k + 1) * cw, -(r + 1) * ch), fill: col.at(e), stroke: .6pt + white)
        content((x0 + (k + .5) * cw, -(r + .5) * ch), txt(e, fill: c.ink, weight: 600))
      }
    }
  }
  let strip(x0) = {
    for (i, e) in ("a", "b", "c", "d").enumerate() {
      rect((x0 + i * mw, -76), (x0 + (i + 1) * mw, -98), fill: col.at(e), stroke: .6pt + white)
      content((x0 + (i + .5) * mw, -87), txt(e, fill: c.ink))
      content((x0 + i * mw, -72), txt(str(4 * i), size: 7pt), anchor: "south")
    }
  }
  // A
  grid(28, (("a", "b"), ("c", "d")))
  content((64, 6), align(center, txt("A\n", fill: c.ink, weight: 700) + txt("ne = {2, 2}, nb = {4, 8}", size: 8pt)), anchor: "south")
  strip(0)
  hop(16, 48, -98, -14, color: c.orange)
  hop(16, 80, -98, -34, color: c.blue)
  // P
  grid(288, (("a", "c"), ("b", "d")))
  content((324, 6), align(center, txt("P = ggml_permute(A, 1, 0, 2, 3)\n", fill: c.ink, weight: 700) + txt("ne = {2, 2}, nb = {8, 4}", size: 8pt)), anchor: "south")
  strip(260)
  hop(276, 340, -98, -34, color: c.orange)
  hop(276, 308, -98, -14, color: c.blue)

  arrow((112, -24), (276, -24), color: c.ink, w: .9pt)
  content((194, -20), txt("swap nb[0] and nb[1]", size: 8pt, fill: c.ink), anchor: "south")
  content((194, -28), txt("data stays put", size: 8pt), anchor: "north")

  content((0, -132), txt([#text(fill: c.orange, weight: 600)[Orange]: next column in the same row, address + nb0 (+4 B in A, +8 B in P)], fill: c.ink), anchor: "north-west")
  content((0, -146), txt([#text(fill: c.blue, weight: 600)[Blue]: next row in the same column, address + nb1 (+8 B in A, +4 B in P)], fill: c.ink), anchor: "north-west")
})

/// ggml_mul_mat(a, b): both operands are read along rows, so c = b · aᵀ.
#let fig-mul-mat() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (cw, ch) = (18, 16)
  let mat(x0, rows, cols, paint) = {
    for r in range(rows) {
      for k in range(cols) {
        rect((x0 + k * cw, -r * ch), (x0 + (k + 1) * cw, -(r + 1) * ch), fill: paint(r, k), stroke: .6pt + white)
      }
    }
  }
  mat(0, 3, 4, (r, k) => if r == 1 { c.orange1 } else { c.grey1 })
  content((36, 6), align(center, txt("a\n", fill: c.ink, weight: 700) + txt("ne = {K=4, M=3}", size: 8pt)), anchor: "south")
  content((-4, -1.5 * ch), txt("m=1", size: 7.5pt, fill: c.orange), anchor: "east")
  mat(130, 2, 4, (r, k) => if r == 0 { c.blue2 } else { c.grey1 })
  content((166, 6), align(center, txt("b\n", fill: c.ink, weight: 700) + txt("ne = {K=4, N=2}", size: 8pt)), anchor: "south")
  content((126, -.5 * ch), txt("n=0", size: 7.5pt, fill: c.blue), anchor: "east")
  mat(290, 2, 3, (r, k) => if r == 0 and k == 1 { c.orange } else { c.grey1 })
  content((317, 6), align(center, txt("c = ggml_mul_mat(a, b)\n", fill: c.ink, weight: 700) + txt("ne = {M=3, N=2}", size: 8pt)), anchor: "south")
  curve-arrow((72, -1.5 * ch), (326 - 9, -ch), (190, -60), (300, -50), color: c.orange)
  curve-arrow((202, -.5 * ch), (290 + 1.5 * cw - 9, -.5 * ch + 2), (240, -.5 * ch + 14), (270, -.5 * ch + 14), color: c.blue)
  content((0, -66), txt([c[n][m] = dot(row m of a, row n of b), so c = b · aᵀ. Both inputs are read along ne0 = K.], fill: c.ink), anchor: "north-west")
})

// ============================================================================
// ggml components and the compute graph
// ============================================================================

/// How cgraph, context, buffers and backend point at each other.
#let fig-components() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // cgraph
  rect((0, 10), (120, -110), fill: c.panel, stroke: none, radius: 4pt)
  content((60, 16), head("ggml_cgraph"), anchor: "south")
  content((8, 0), txt("leafs[]", size: 8pt), anchor: "north-west")
  vals((8, -14), ("W", "b", "x"), 30, 18, paint: k => c.teal1)
  content((8, -50), txt("nodes[]", size: 8pt), anchor: "north-west")
  vals((8, -64), ("y", "z"), 30, 18, paint: k => c.blue1)
  content((8, -90), txt("tensor pointers only", size: 7.5pt), anchor: "north-west")

  // context
  rect((160, 10), (320, -110), fill: c.panel, stroke: none, radius: 4pt)
  content((240, 16), head("ggml_context"), anchor: "south")
  let cards = (
    ("W", "leaf · weight", c.teal1), ("b", "leaf · weight", c.teal1), ("x", "leaf · input", c.teal1),
    ("y", "MUL_MAT(W, x)", c.blue1), ("z", "ADD(y, b)", c.blue1),
  )
  for (i, (n, info, f)) in cards.enumerate() {
    let y = -i * 22
    rect((168, y), (312, y - 18), fill: f, stroke: .5pt + white, radius: 2pt)
    content((175, y - 9), txt(n, fill: c.ink, weight: 700), anchor: "west")
    content((188, y - 9), txt(info, size: 7.5pt), anchor: "west")
    circle((304, y - 9), radius: 2.2, fill: c.ink, stroke: none)
  }
  arrow((124, -40), (156, -40), color: c.muted)

  // buffers: one cell per tensor, level with its card
  let cell(i, body, f) = {
    let y = -i * 22
    rect((370, y), (480, y - 18), fill: f, stroke: .6pt + white)
    content((425, y - 9), txt(body, size: 8pt, fill: c.ink))
    arrow((306, y - 9), (368, y - 9), color: c.blue)
  }
  cell(0, "W.data", c.teal1)
  cell(1, "b.data", c.teal1)
  cell(2, "x.data", c.teal1)
  cell(3, "y.data", c.blue1)
  cell(4, "z.data", c.blue1)
  line((486, 0), (490, 0), (490, -40), (486, -40), stroke: .7pt + c.line)
  content((494, -20), align(left, txt("weights\nbuffer", size: 8pt, fill: c.ink, weight: 600)), anchor: "west")
  line((486, -44), (490, -44), (490, -106), (486, -106), stroke: .7pt + c.line)
  content((494, -75), align(left, txt("compute\nbuffer", size: 8pt, fill: c.ink, weight: 600)), anchor: "west")
  content((338, 2), txt("tensor->data", size: 7.5pt, fill: c.blue), anchor: "south")

  // backend
  node((300, -150), [ggml_backend], name: "be", tone: "dark", width: 300, note: [CPU / CUDA / Metal: allocates buffers, runs the ops])
  line((425, -133), (425, -110), stroke: dashed(c.line))
  content((429, -121), txt("allocates", size: 7.5pt), anchor: "west")
  arrow((150, -150), (60, -114), color: c.muted, dash: "dashed")
  content((96, -138), txt("graph_compute(gf)", size: 7.5pt), anchor: "east")
})

/// The MLP of Figure 1: leaves (weights, input) and nodes (intermediates).
#let fig-mlp-graph() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let ow = 150
  node((120, 0), [x], name: "x", tone: "leaf", width: 40)
  node((280, 0), [W#sub[1]], name: "w1", tone: "leaf", width: 40)
  node((200, -52), [M#sub[1] = mul_mat(W#sub[1], x)], name: "m1", width: ow)
  node((360, -100), [b#sub[1]], name: "b1", tone: "leaf", width: 40)
  node((200, -100), [M#sub[2] = add(M#sub[1], b#sub[1])], name: "m2", width: ow)
  node((200, -148), [M#sub[3] = gelu(M#sub[2])], name: "m3", width: ow)
  node((360, -196), [W#sub[2]], name: "w2", tone: "leaf", width: 40)
  node((200, -196), [M#sub[4] = mul_mat(W#sub[2], M#sub[3])], name: "m4", width: ow)
  node((360, -244), [b#sub[2]], name: "b2", tone: "leaf", width: 40)
  node((200, -244), [out = add(M#sub[4], b#sub[2])], name: "out", width: ow, tone: "hot")
  arrow("x.south", (180, -40))
  arrow("w1.south", (220, -40))
  arrow("m1.south", "m2.north")
  arrow("b1.west", "m2.east")
  arrow("m2.south", "m3.north")
  arrow("m3.south", "m4.north")
  arrow("w2.west", "m4.east")
  arrow("m4.south", "out.north")
  arrow("b2.west", "out.east")

  // the two arrays of ggml_cgraph
  let (ax, cw) = (70, 50)
  for i in range(5) { content((ax + (i + .5) * cw, -282), txt(str(i), size: 7pt), anchor: "south") }
  content((ax - 6, -294), txt("leafs[]", size: 8pt, fill: c.ink), anchor: "east")
  vals((ax, -284), ([W#sub[2]], [W#sub[1]], [x], [b#sub[1]], [b#sub[2]]), cw, 20, paint: k => c.teal1)
  content((ax - 6, -320), txt("nodes[]", size: 8pt, fill: c.ink), anchor: "east")
  vals((ax, -310), ([M#sub[1]], [M#sub[2]], [M#sub[3]], [M#sub[4]], [out]), cw, 20, paint: k => if k == 4 { c.orange1 } else { c.blue1 })
  content((ax + 5 * cw + 12, -284), align(left, txt("ggml_build_forward_expand(gf, out)\nDFS from out, src[0] first:\nnodes in topological order,\nleafs in order of first visit", size: 7.5pt)), anchor: "north-west")
  let ly = -350
  legend(0, ly, "Leaf: weight or input, ready before compute", box-swatch(0, ly, c.teal1))
  legend(270, ly, "Node: intermediate, made during compute", box-swatch(270, ly, c.blue1))
})

// ============================================================================
// The four gpt-2 examples
// ============================================================================

#let fig-examples() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let cols = ((96, 176, "Weights"), (276, 176, "Intermediates"), (456, 92, "Backend"))
  let rh = 36
  for (x, w, title) in cols { content((x + w / 2, 6), head(title), anchor: "south") }
  let man = c.orange1
  let aut = c.teal1
  let rows = (
    ("main-ctx", (man, "manual", "ctx_size summed by hand, in ctx_w"), (man, "manual", "new 256 MB ctx0 per eval"), (c.grey1, "CPU", "")),
    ("main-alloc", (man, "manual", "as in main-ctx"), (aut, "gallocr", "reserve once, reuse every eval"), (c.grey1, "CPU", "")),
    ("main-backend", (aut, "automatic", "ggml_backend_alloc_ctx_tensors"), (aut, "gallocr", "as in main-alloc"), (c.blue1, "one backend", "CPU/CUDA/Metal")),
    ("main-sched", (aut, "automatic", "one buffer per backend"), (aut, "backend_sched", "split graph across backends"), (c.blue2, "several", "GPU + CPU")),
  )
  for (i, row) in rows.enumerate() {
    let y = -i * rh
    content((88, y - rh / 2), txt(row.at(0), fill: c.ink, weight: 700), anchor: "east")
    for (j, (x, w, _)) in cols.enumerate() {
      let (f, a, b) = row.at(j + 1)
      rect((x, y), (x + w, y - rh), fill: f, stroke: 1pt + white)
      if b == "" {
        content((x + w / 2, y - rh / 2), txt(a, fill: c.ink, weight: 600))
      } else {
        content((x + 6, y - 11), txt(a, size: 8.5pt, fill: c.ink, weight: 600), anchor: "west")
        content((x + 6, y - 25), txt(b, size: 7.5pt, fill: c.ink), anchor: "west")
      }
    }
  }
  let ly = -4 * rh - 16
  legend(96, ly, "by hand", box-swatch(96, ly, man))
  legend(200, ly, "ggml computes sizes and allocates", box-swatch(200, ly, aut))
})

/// main-ctx: with no_alloc = false the tensor data sits right after its struct.
#let fig-ctx-pool() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let sh = 22
  let spans(parts) = {
    let x = 0
    let out = ()
    for (w, ..rest) in parts {
      out.push((x, w))
      x += w
    }
    out
  }
  let segs(y, parts) = {
    let x = 0
    for (w, kind, body) in parts {
      let (f, ink) = if kind == "obj" { (c.grey2, c.muted) } else if kind == "t" { (c.blue2, c.ink) } else if kind == "d" { (c.teal1, c.ink) } else { (white, c.muted) }
      rect((x, y), (x + w, y - sh), fill: f, stroke: if kind == "free" { dashed(c.grey2) } else { .6pt + white })
      if body != none { content((x + w / 2, y - sh / 2), txt(body, size: 7.5pt, fill: ink)) }
      x += w
    }
  }
  // no_alloc = false
  content((0, 30), txt("no_alloc = false (main-ctx): metadata and data both in mem_buffer", fill: c.ink, weight: 700), anchor: "south-west")
  let p = (
    (18, "obj", none), (62, "t", "ln_f_g"), (44, "d", "data"),
    (18, "obj", none), (62, "t", "ln_f_b"), (44, "d", "data"),
    (18, "obj", none), (62, "t", "wte"), (120, "d", "data"), (52, "free", "…"),
  )
  segs(0, p)
  let xs = spans(p)
  for i in (1, 4, 7) {
    let (tx, tw) = xs.at(i)
    let (dx, dw) = xs.at(i + 1)
    hop(tx + tw / 2, dx + 8, 0, 18, color: c.blue)
  }
  content((xs.at(1).at(0) + 60, 16), txt("data = result + 1", size: 7.5pt, fill: c.blue), anchor: "south-west")
  brace(0, 500, -sh - 4, txt("mem_size = ctx_size: every weight's size, summed by hand before loading", size: 8pt))

  // no_alloc = true
  let y2 = -84
  content((0, y2 + 8), txt("no_alloc = true (main-backend on): the context holds metadata only", fill: c.ink, weight: 700), anchor: "south-west")
  let q = (
    (18, "obj", none), (62, "t", "ln_f_g"), (18, "obj", none), (62, "t", "ln_f_b"),
    (18, "obj", none), (62, "t", "wte"),
  )
  segs(y2, q)
  let ys = spans(q)
  content((250, y2 - sh / 2), txt("mem_size = ggml_tensor_overhead() × n_tensors", size: 8pt), anchor: "west")
  let y3 = -150
  let bparts = ((44, "ln_f_g"), (44, "ln_f_b"), (120, "wte"))
  let bx = 40
  let targets = ()
  for (w, body) in bparts {
    rect((bx, y3), (bx + w, y3 - sh), fill: c.teal1, stroke: .6pt + white)
    content((bx + w / 2, y3 - sh / 2), txt(body, size: 7.5pt, fill: c.ink))
    targets.push(bx + w / 2)
    bx += w
  }
  content((bx + 10, y3 - sh / 2), txt("ggml_backend_buffer (RAM or VRAM)", size: 8pt, fill: c.ink, weight: 600), anchor: "west")
  for (k, i) in (1, 3, 5).enumerate() {
    let (tx, tw) = ys.at(i)
    arrow((tx + tw / 2, y2 - sh - 2), (targets.at(k), y3 + 2), color: c.blue)
  }
  let ly = y3 - sh - 22
  legend(0, ly, "ggml_object header", box-swatch(0, ly, c.grey2))
  legend(130, ly, "ggml_tensor struct (metadata)", box-swatch(130, ly, c.blue2))
  legend(330, ly, "tensor data", box-swatch(330, ly, c.teal1))
})

// ============================================================================
// ggml_gallocr
// ============================================================================

/// gallocr on the MLP graph: in-place reuse and freeing keep two blocks alive.
#let fig-galloc-reuse() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, rh) = (70, 84, 26)
  let steps = (([M#sub[1]], "mul_mat"), ([M#sub[2]], "add"), ([M#sub[3]], "gelu"), ([M#sub[4]], "mul_mat"), ([out], "add"))
  for (i, (n, op)) in steps.enumerate() {
    content((x0 + (i + .5) * cw, 22), txt([Step #(i + 1): #n], fill: c.ink, weight: 600), anchor: "south")
    content((x0 + (i + .5) * cw, 8), txt(op, size: 7.5pt), anchor: "south")
  }
  content((x0 - 8, -rh / 2), txt("Block A", fill: c.ink, weight: 600), anchor: "east")
  content((x0 - 8, -rh - 8 - rh / 2), txt("Block B", fill: c.ink, weight: 600), anchor: "east")
  let cell(i, slot, fill, body, note, dash: false) = {
    let y = -slot * (rh + 8)
    rect((x0 + i * cw + 2, y), (x0 + (i + 1) * cw - 2, y - rh), fill: fill,
      stroke: if dash { dashed(c.grey2) } else { none }, radius: 3pt)
    content((x0 + (i + .5) * cw, y - rh / 2 + 5), txt(body, size: 8.5pt, fill: c.ink, weight: 600))
    content((x0 + (i + .5) * cw, y - rh / 2 - 6), txt(note, size: 7pt, fill: c.ink))
  }
  cell(0, 0, c.blue2, [M#sub[1]], "new")
  cell(1, 0, c.blue2, [M#sub[2]], "in place of M₁")
  cell(2, 0, c.blue2, [M#sub[3]], "in place of M₂")
  cell(3, 0, c.blue1, [M#sub[3]], "read by M₄")
  cell(4, 0, white, [free], "M₃ freed", dash: true)
  cell(3, 1, c.orange1, [M#sub[4]], "new")
  cell(4, 1, c.orange1, [out], "in place of M₄")
  for i in range(3) { cell(i, 1, white, [], "", dash: true) }

  let y = -2 * (rh + 8) - 10
  content((x0 - 8, y - 8), txt("No reuse", fill: c.ink, weight: 600), anchor: "east")
  for i in range(5) {
    rect((x0 + i * 30, y), (x0 + i * 30 + 28, y - 16), fill: c.grey1, stroke: none, radius: 2pt)
    content((x0 + i * 30 + 14, y - 8), txt(steps.at(i).at(0), size: 7.5pt, fill: c.ink))
  }
  content((x0 + 160, y - 8), txt("One block per intermediate: 5. With reuse the peak is 2.", size: 8pt, fill: c.ink), anchor: "west")
  content((x0 - 60, y - 30), align(left, txt(
    "In place: the op supports in-place, the parent has this node as its only child\n(n_children == 1), and the layouts match.\nFree: once all of a node's children are allocated, n_children reaches 0\nand its block returns to the free list.",
    size: 7.5pt,
  )), anchor: "north-west")
})

/// reserve once with the worst-case graph, then reuse the buffer every eval.
#let fig-reserve-alloc() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, lx, rx) = (226, 115, 380)
  content((lx, 6), head("Once, at startup"), anchor: "south")
  node((lx, 0), [Build the worst-case graph], name: "a1", tone: "plain", width: w, anchor: "north", note: [n_tokens = n_batch, n_past = n_ctx − n_batch])
  node((lx, -56), [ggml_gallocr_reserve], name: "a2", width: w, anchor: "north", note: [dry run: record offsets and the peak])
  node((lx, -112), [Allocate the compute buffer at the peak], name: "a3", width: w, anchor: "north", note: [ggml_vbuffer_alloc])
  arrow("a1.south", "a2.north")
  arrow("a2.south", "a3.north")

  content((rx, 6), head("Every eval"), anchor: "south")
  node((rx, 0), [Build this step's graph], name: "b1", tone: "plain", width: w, anchor: "north", note: [no larger than the reserved graph])
  node((rx, -56), [ggml_gallocr_alloc_graph], name: "b2", width: w, anchor: "north", note: [reset, set data from the recorded offsets])
  node((rx, -112), [ggml_backend_graph_compute], name: "b3", tone: "hot", width: w, anchor: "north", note: [compute, no allocation])
  arrow("b1.south", "b2.north")
  arrow("b2.south", "b3.north")
  let ex = rx + w / 2
  curve-arrow((ex, -128), (ex, -16), (ex + 30, -128), (ex + 30, -16), color: c.orange)
  content((ex + 26, -72), txt("next\ntoken", size: 7.5pt, fill: c.orange), anchor: "west")

  // the buffer
  let (bx, by) = (170, -180)
  let parts = ((40, c.blue1, "Q"), (60, c.blue2, "KQ"), (30, c.blue1, "…"), (50, c.blue2, "ffn"))
  let x = bx
  for (w2, f, b) in parts {
    rect((x, by), (x + w2, by - 20), fill: f, stroke: .6pt + white)
    content((x + w2 / 2, by - 10), txt(b, size: 7.5pt, fill: c.ink))
    x += w2
  }
  content((bx + 90, by - 24), txt("compute buffer: fixed size, tensor->data = base + offset", size: 8pt, fill: c.ink), anchor: "north")
  arrow("a3.south", (bx + 20, by + 2), color: c.blue)
  arrow("b3.south", (bx + 150, by + 2), color: c.blue, dash: "dashed")
  content((rx - 30, by + 12), txt("read / write", size: 7.5pt, fill: c.blue), anchor: "west")
})

/// n_batch caps how many tokens one graph run takes; the KV cache grows across runs.
#let fig-nbatch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, u, rh, gap) = (136, 2.8, 16, 26)
  let rows = (
    ("prompt, part 1", 0, 32),
    ("prompt, part 2", 32, 32),
    ("prompt, part 3", 64, 6),
    ("generate 1 token", 70, 1),
    ("worst case at reserve", 96, 32),
  )
  for (i, (name, past, n)) in rows.enumerate() {
    let y = -i * gap
    let worst = i == 4
    content((x0 - 8, y - rh / 2), txt(name, size: 8.5pt, fill: c.ink, weight: if worst { 700 } else { 400 }), anchor: "east")
    rect((x0, y), (x0 + 128 * u, y - rh), fill: c.grey1, stroke: none)
    if past > 0 { rect((x0, y), (x0 + past * u, y - rh), fill: if worst { c.grey2 } else { c.blue1 }, stroke: none) }
    rect((x0 + past * u, y), (x0 + (past + n) * u, y - rh), fill: c.orange, stroke: none)
    content((x0 + 128 * u + 6, y - rh / 2), txt("n_past=" + str(past) + "  n_tokens=" + str(n), size: 7.5pt), anchor: "west")
  }
  let ay = -5 * gap + 6
  for k in (0, 32, 64, 96, 128) {
    line((x0 + k * u, ay), (x0 + k * u, ay - 4), stroke: .6pt + c.line)
    content((x0 + k * u, ay - 6), txt(str(k), size: 7pt), anchor: "north")
  }
  content((x0 + 64 * u, ay - 18), txt("KV position (n_ctx = 128, n_batch = 32, 70-token prompt)", size: 8pt), anchor: "north")
  let ly = ay - 40
  legend(x0, ly, "Tokens in this run (≤ n_batch)", box-swatch(x0, ly, c.orange))
  legend(x0 + 190, ly, "Already in the KV cache", box-swatch(x0 + 190, ly, c.blue1))
})

// ============================================================================
// main-backend / main-sched
// ============================================================================

/// buffer type -> buffer -> tallocr carving out tensors one after another.
#let fig-backend-buffer() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  node((70, 0), [ggml_backend], name: "be", tone: "dark", width: 140, note: [CUDA])
  node((70, -64), [buffer_type], name: "bt", width: 140, note: [get_alloc_size(t)\ alloc_buffer(size)])
  arrow("be.south", "bt.north")
  content((76, -28), txt("get_default_buffer_type", size: 7pt), anchor: "west")

  let (bx, by, sh) = (200, -50, 24)
  let parts = ((70, "wq"), (6, none), (70, "wk"), (6, none), (70, "wv"), (6, none), (24, "b"), (8, none))
  let x = bx
  for (w, body) in parts {
    if body == none {
      rect((x, by), (x + w, by - sh), fill: c.grey1, stroke: none)
    } else {
      rect((x, by), (x + w, by - sh), fill: c.teal1, stroke: .6pt + white)
      content((x + w / 2, by - sh / 2), txt(body, size: 8pt, fill: c.ink))
    }
    x += w
  }
  content((bx, by + 6), txt("ggml_backend_buffer (cur_buf_size)", size: 8.5pt, fill: c.ink, weight: 600), anchor: "south-west")
  arrow("bt.east", (bx - 4, by - sh / 2), color: c.blue)
  // tallocr pointer
  let px = bx + 70 + 6 + 70 + 6
  arrow((px, by - sh - 22), (px, by - sh - 2), color: c.orange)
  content((px, by - sh - 24), txt("tallocr.offset", size: 7.5pt, fill: c.orange), anchor: "north")
  content((bx + 73, by - sh - 3), txt("align", size: 6.5pt), anchor: "north")

  content((0, -118), align(left, txt(
    "① Sum get_alloc_size over the tensors in ctx, each rounded up to the alignment: cur_buf_size\n② The buffer type's alloc_buffer(cur_buf_size) allocates one block\n③ ggml_tallocr carves it in order: tensor->data = base + offset, offset += aligned size",
    size: 8pt, fill: c.ink,
  )), anchor: "north-west")
})

/// gpt-2 main-sched with 12 layers and n_gpu_layers = 4.
#let fig-sched-layers() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (bw, bh) = (28, 26)
  let blocks = (("wte\nwpe", "cpu"),) + range(12).map(i => ("h" + str(i), if i >= 8 { "gpu" } else { "cpu" })) + (("ln_f", "gpu"),)
  for (i, (n, dev)) in blocks.enumerate() {
    let x = i * (bw + 2)
    rect((x, 0), (x + bw, -bh), fill: if dev == "gpu" { c.blue2 } else { c.grey2 }, stroke: none, radius: 2pt)
    content((x + bw / 2, -bh / 2), align(center, txt(n, size: if n.contains("\n") { 6.5pt } else { 7.5pt }, fill: c.ink)))
  }
  let pitch = bw + 2
  content((0, 6), txt("Weights (a layer's position decides its backend)", size: 8.5pt, fill: c.ink, weight: 600), anchor: "south-west")
  brace(0, 9 * pitch - 2, -bh - 4, txt("CPU buffer", size: 8pt, fill: c.ink, weight: 600))
  brace(9 * pitch, 14 * pitch - 2, -bh - 4, txt("GPU buffer", size: 8pt, fill: c.blue, weight: 600))
  content((9 * pitch - 1, -bh - 34), txt("i_gpu_first_layer = n_layer − n_gpu_layers = 8", size: 7.5pt), anchor: "north")

  // KV cache
  let kx = 14 * pitch + 20
  rect((kx, 0), (kx + 74, -bh), fill: c.grey2, stroke: .8pt + c.ink, radius: 2pt)
  content((kx + 37, -bh / 2), txt("KV cache", size: 8pt, fill: c.ink, weight: 600))
  content((kx + 37, -bh - 4), align(center, txt("8 CPU > 4 GPU\n→ on the CPU", size: 7.5pt)), anchor: "north")
})

/// The passes of ggml_backend_sched_split_graph on 12 nodes.
#let fig-sched-passes() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, ch, gap) = (120, 30, 18, 26)
  let rows = (
    ("Pass 1: follow weights", "C?C?C??G?G??", ""),
    ("Pass 2: GPU, downward", "C?C?C??GGGGG", "-------.-.--"),
    ("Pass 2: GPU, upward", "C?C?CGGGGGGG", "-----**-----"),
    ("Pass 2: the rest", "CCCCCGGGGGGG", "-*-*--------"),
  )
  for k in range(12) {
    content((x0 + (k + .5) * cw, 12), txt("n" + str(k), size: 7pt), anchor: "south")
  }
  for k in (0, 2, 4, 7, 9) {
    content((x0 + (k + .5) * cw, 2), txt("W", size: 6.5pt, fill: c.orange, weight: 700), anchor: "south")
  }
  let newly = ((), (8, 10, 11), (5, 6), (1, 3))
  for (i, (name, s, _)) in rows.enumerate() {
    let y = -i * gap
    content((x0 - 8, y - ch / 2), txt(name, size: 8pt, fill: c.ink), anchor: "east")
    for k in range(12) {
      let sk = s.at(k)
      let (f, b) = if sk == "C" { (c.grey2, "CPU") } else if sk == "G" { (c.blue2, "GPU") } else { (white, "?") }
      let hot = k in newly.at(i)
      rect((x0 + k * cw + 1, y), (x0 + (k + 1) * cw - 1, y - ch), fill: f,
        stroke: if hot { 1.2pt + c.orange } else if sk == "?" { dashed(c.grey2) } else { none }, radius: 2pt)
      content((x0 + (k + .5) * cw, y - ch / 2), txt(b, size: 6.5pt, fill: c.ink))
    }
  }
  // pass 5: splits
  let y = -4 * gap - 6
  content((x0 - 8, y - ch / 2), txt("Pass 5: split", size: 8pt, fill: c.ink), anchor: "east")
  rect((x0 + 1, y), (x0 + 5 * cw - 1, y - ch), fill: c.grey2, stroke: none, radius: 2pt)
  content((x0 + 2.5 * cw, y - ch / 2), txt("split 0 · CPU (n0–n4)", size: 7.5pt, fill: c.ink, weight: 600))
  rect((x0 + 5 * cw + 1, y), (x0 + 12 * cw - 1, y - ch), fill: c.blue2, stroke: none, radius: 2pt)
  content((x0 + 8.5 * cw, y - ch / 2), txt("split 1 · GPU (n5–n11)", size: 7.5pt, fill: c.ink, weight: 600))
  arrow((x0 + 5 * cw, y - ch - 14), (x0 + 5 * cw, y - ch - 2), color: c.orange)
  content((x0 + 5 * cw, y - ch - 16), txt("n4's output is copied to the GPU as split 1's input", size: 7.5pt, fill: c.orange), anchor: "north")
  let ly = y - 52
  legend(x0, ly, "Assigned in this pass", box-swatch(x0, ly, white, stroke: 1.2pt + c.orange))
  legend(x0 + 160, ly, "Node that uses a weight", box-swatch(x0 + 160, ly, white, stroke: none))
  content((x0 + 165, ly), txt("W", size: 6.5pt, fill: c.orange, weight: 700))
})

// ============================================================================
// llama.cpp
// ============================================================================

/// simple.cpp: from llama_decode to the backend, with source locations.
#let fig-decode-flow() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (cx, w) = (140, 260)
  let loc(y, body) = content((cx + w / 2 + 14, y), txt(body, size: 7.5pt), anchor: "west")
  node((cx, 0), [llama_init_from_model → new llama_context], name: "a", tone: "plain", width: w, note: [graph_reserve × 3: reserve sched buffers for the worst case])
  loc(0, "simple.cpp")
  node((cx, -56), [llama_decode(ctx, batch)], name: "b", tone: "plain", width: w)
  loc(-56, "llama-context.cpp")
  node((cx, -100), [llama_context::decode(batch)], name: "c", width: w, note: [split the batch into ubatches])
  loc(-100, "llama-context.cpp")
  arrow("a.south", "b.north")
  arrow("b.south", "c.north")

  // process_ubatch
  let (py0, py1) = (-136, -306)
  rect((cx - w / 2 - 10, py0), (cx + w / 2 + 10, py1), fill: c.panel, stroke: none, radius: 4pt)
  content((cx - w / 2 - 2, py0 - 4), txt("process_ubatch(ubatch, LLM_GRAPH_TYPE_DECODER, …)", size: 8pt, fill: c.ink, weight: 700), anchor: "north-west")
  loc(py0 - 10, "llama-context.cpp")
  node((cx, -180), [① Build the graph], name: "d1", width: w - 20, note: [reuse the previous graph if it fits, else model.build_graph()])
  node((cx, -236), [② Allocate], name: "d2", width: w - 20, note: [ggml_backend_sched_alloc_graph])
  loc(-236, "llama-context.cpp")
  node((cx, -278), [③ Compute], name: "d3", tone: "hot", width: w - 20, note: [ggml_backend_sched_graph_compute_async])
  arrow("c.south", (cx, py0))
  arrow("d1.south", "d2.north")
  arrow("d2.south", "d3.north")
  curve-arrow((cx - w / 2 - 10, -278), (cx - w / 2, -100), (cx - w / 2 - 50, -278), (cx - w / 2 - 50, -100), color: c.orange)
  content((cx - w / 2 - 44, -190), txt("next\nubatch", size: 7.5pt, fill: c.orange), anchor: "east")
  curve-arrow((cx + w / 2, -8), (cx + w / 2 + 120, -236), (cx + w / 2 + 200, -8), (cx + w / 2 + 170, -236), color: c.blue, dash: "dashed")
  content((cx + w / 2 + 172, -150), txt("reuses the\nreserved buffers", size: 7.5pt, fill: c.blue), anchor: "west")
})

/// The GGUF file: header, metadata, tensor infos, then aligned tensor data.
#let fig-gguf-layout() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let sh = 24
  let parts = (
    (80, c.grey2, "header"), (100, c.orange1, "KV metadata"), (110, c.blue1, "tensor info"),
    (8, c.grey1, none), (100, c.teal1, "token_embd"), (4, c.grey1, none), (76, c.teal2, "blk.0.attn_q"), (40, c.teal1, "…"),
  )
  let x = 0
  let xs = ()
  for (w, f, b) in parts {
    rect((x, 0), (x + w, -sh), fill: f, stroke: .6pt + white)
    if b != none { content((x + w / 2, -sh / 2), txt(b, size: 7.5pt, fill: c.ink)) }
    xs.push(x)
    x += w
  }
  let data0 = xs.at(4)
  let below = (
    (40, "magic GGUF\nversion\nn_tensors, n_kv"), (130, "hyperparameters\ntokenizer"), (235, "per tensor:\nname / shape\ntype / offset"),
  )
  for (cx, body) in below { content((cx, -sh - 6), align(center, txt(body, size: 7pt)), anchor: "north") }
  arrow((data0, -sh - 34), (data0, -sh - 2), color: c.orange)
  content((data0, -sh - 36), txt("data_offset", size: 7.5pt, fill: c.orange, weight: 600), anchor: "north")
  content((data0 + 120, -sh - 6), align(center, txt("tensor data, each aligned\nto general.alignment", size: 7pt)), anchor: "north")

  // tensor infos, zoomed
  let (zx, zy, zw) = (150, 92, 250)
  rect((zx, zy), (zx + zw, zy - 52), fill: white, stroke: .7pt + c.blue, radius: 3pt)
  line((180, 0), (zx, zy - 52), stroke: dotted)
  line((290, 0), (zx + zw, zy - 52), stroke: dotted)
  content((zx + 8, zy - 6), txt("token_embd.weight   F16  [4096, 32000]  offset 0", size: 7pt, fill: c.ink), anchor: "north-west")
  content((zx + 8, zy - 20), txt("blk.0.attn_q.weight F16  [4096, 4096]   offset 262144000", size: 7pt, fill: c.ink), anchor: "north-west")
  content((zx + 8, zy - 34), txt("…", size: 7pt, fill: c.ink), anchor: "north-west")
  arrow((zx + zw - 40, zy - 52), (data0 + 30, 2), color: c.teal)
  arrow((zx + zw - 10, zy - 52), (xs.at(6) + 30, 2), color: c.teal)
  content((zx + zw / 2, zy + 4), txt("tensor info: offsets relative to data_offset", size: 8pt, fill: c.blue, weight: 600), anchor: "south")
})

/// mmap: the file is the buffer; each tensor's data is addr + offs.
#let fig-mmap-range() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let sh = 22
  let parts = ((110, c.grey2, "header + meta + info"), (90, c.teal1, "token_embd"), (70, c.teal2, "attn_q"), (70, c.teal1, "attn_k"), (90, c.teal2, "…"), (40, c.teal1, "output"))
  let xs = (0,)
  for (w, ..rest) in parts { xs.push(xs.last() + w) }
  let row(y) = {
    for (i, (w, f, b)) in parts.enumerate() {
      let x = xs.at(i)
      rect((x, y), (x + w, y - sh), fill: f, stroke: .6pt + white)
      content((x + w / 2, y - sh / 2), txt(b, size: 7.5pt, fill: c.ink))
    }
  }
  content((-8, -sh / 2), txt(".gguf on disk", size: 8pt, fill: c.ink, weight: 600), anchor: "east")
  row(0)
  let y2 = -64
  content((-8, y2 - sh / 2), txt("virtual memory", size: 8pt, fill: c.ink, weight: 600), anchor: "east")
  row(y2)
  let ys = xs
  for x in (0, xs.last()) { line((x, -sh), (x, y2), stroke: dotted) }
  content((xs.last() / 2, (y2 - sh) / 2 - 3), txt("llama_mmap: the whole file is mapped, paged in on demand, never copied", size: 7.5pt), anchor: "center")
  content((0, y2 - sh - 4), txt("↑ mapping->addr()", size: 7pt, fill: c.blue), anchor: "north-west")

  // buffer range
  let (first, last) = (ys.at(1), ys.last())
  let by = y2 - sh - 6
  line((first, by), (first, by - 6), (last, by - 6), (last, by), stroke: 1.2pt + c.orange)
  content(((first + last) / 2, by - 9), txt("buffer_from_host_ptr(addr + first, last − first): wraps this range only", size: 7.5pt, fill: c.orange, weight: 600), anchor: "north")
  content((first, by - 26), txt("first = min(offs)", size: 7pt), anchor: "north")
  content((last, by - 26), txt("last = max(offs + nbytes)", size: 7pt), anchor: "north-east")

  // one tensor
  let tx = ys.at(2)
  arrow((tx, y2 - sh - 52), (tx, y2 - sh - 2), color: c.blue)
  content((tx + 4, y2 - sh - 50), txt("attn_q->data = addr + offs", size: 7.5pt, fill: c.blue, weight: 600), anchor: "west")
  content((tx + 4, y2 - sh - 60), align(left, txt("offs = data_offset + offset from tensor info\nggml_backend_tensor_alloc(buf, t, addr + offs)", size: 7pt)), anchor: "north-west")
})
