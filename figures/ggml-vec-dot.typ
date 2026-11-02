// Figures for content/posts/ml-systems/ggml-q4-0-vec-dot.typ, drawn with cetz.
// Block-level figures use one probe run (ggml 83835ff, Apple M4 Pro, K = 64);
// the work-distribution figures read ggml-vec-dot-trace.typ, a traced decode
// of the Qwen3-8B gate projection, Q4_0 [4096 -> 12288].
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.
// Text is 8–10pt so the figures read at the size of the body text.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, pill
#import "/figures/ggml-vec-dot-trace.typ": trace

// ============================================================================
// Shared pieces
// ============================================================================

#let txt(body, size: 9pt, fill: c.muted, weight: 400, style: "normal") = text(
  size: size, fill: fill, weight: weight, style: style, body,
)
#let head(body, fill: c.ink) = text(size: 9pt, weight: 700, tracking: .6pt, fill: fill, upper(body))
#let num(v) = if v < 0 { "−" + str(-v) } else { str(v) }

/// Thread colours for up to 4 threads.
#let tc = (c.blue, c.orange, c.teal, c.ink)

/// A row of labelled cells; `o` is the top-left corner.
#let vals(o, labels, w, h, paint: k => c.grey1, size: 9pt, ink: k => c.ink, weight: 400) = {
  import cetz.draw: *
  let (x, y) = o
  for (k, body) in labels.enumerate() {
    rect((x + k * w, y), (x + (k + 1) * w, y - h), fill: paint(k), stroke: .6pt + white)
    content((x + (k + .5) * w, y - h / 2), txt(body, size: size, fill: ink(k), weight: weight))
  }
}

/// A row label right-aligned at x: a name and, optionally, a muted note under it.
#let row-label(x, y, name, note: none) = {
  import cetz.draw: *
  if note == none {
    content((x, y), txt(name, fill: c.ink), anchor: "east")
  } else {
    content((x, y + 5), txt(name, fill: c.ink), anchor: "east")
    content((x, y - 6), txt(note, size: 7.5pt), anchor: "east")
  }
}

/// A bracket under x0..x1 at height y, pointing down.
#let brace(x0, x1, y, color: c.line) = {
  import cetz.draw: *
  line((x0 + 1, y), (x0 + 1, y - 4), (x1 - 1, y - 4), (x1 - 1, y), stroke: .7pt + color)
  line(((x0 + x1) / 2, y - 4), ((x0 + x1) / 2, y - 9), stroke: .7pt + color)
}

#let dotted = (paint: c.line, thickness: .5pt, dash: "dotted")

// ============================================================================
// Quantization types
// ============================================================================

/// The same 256 weights in four storage types, drawn to scale in bytes.
#let fig-quant-types() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, u, h, gap) = (88, .9, 20, 54)
  let name(i, n, bits) = {
    let y = -i * gap - h / 2
    content((0, y + 6), txt(n, size: 10pt, fill: c.ink, weight: 700), anchor: "west")
    content((0, y - 7), txt(bits, size: 8.5pt), anchor: "west")
  }
  let desc(i, body) = content((x0, -i * gap + 4), txt(body, size: 8.5pt), anchor: "south-west")
  let total(i, x, body) = content((x + 6, -i * gap - h / 2), txt(body, fill: c.ink, weight: 600), anchor: "west")
  rect((0, 12), (1, 11), stroke: none)  // headroom

  // F16
  name(0, "F16", "16 bit/w")
  rect((x0, 0), (x0 + 512 * u, -h), fill: c.grey1, stroke: .6pt + white)
  content((x0 + 256 * u, -h / 2), txt("256 × fp16 = 512 B", fill: c.ink))

  // Q8_0: 8 blocks of (d + 32 int8)
  name(1, "Q8_0", "8.5 bit/w")
  desc(1, "8 blocks × (d: fp16 + 32 × int8) = 8 × 34 B")
  for b in range(8) {
    let x = x0 + b * 34 * u
    rect((x, -gap), (x + 2 * u, -gap - h), fill: c.ink, stroke: .6pt + white)
    rect((x + 2 * u, -gap), (x + 34 * u, -gap - h), fill: c.teal1, stroke: .6pt + white)
  }
  total(1, x0 + 272 * u, "272 B")

  // Q4_0: 8 blocks of (d + 32 nibbles)
  name(2, "Q4_0", "4.5 bit/w")
  desc(2, "8 blocks × (d: fp16 + 32 × 4-bit) = 8 × 18 B")
  for b in range(8) {
    let x = x0 + b * 18 * u
    rect((x, -2 * gap), (x + 2 * u, -2 * gap - h), fill: c.ink, stroke: .6pt + white)
    rect((x + 2 * u, -2 * gap), (x + 18 * u, -2 * gap - h), fill: c.blue1, stroke: .6pt + white)
  }
  total(2, x0 + 144 * u, "144 B")

  // Q2_K: one super-block
  let y3 = -3 * gap
  name(3, "Q2_K", "2.625 bit/w")
  desc(3, "1 super-block: scales[16] + qs[64] + d + dmin")
  let parts = ((16, c.orange1, none), (64, c.blue1, none), (2, c.ink, none), (2, c.ink, none))
  let x = x0
  for (n, fill, body) in parts {
    rect((x, y3), (x + n * u, y3 - h), fill: fill, stroke: .6pt + white)
    if body != none { content((x + n * u / 2, y3 - h / 2), txt(body, size: 8pt, fill: c.ink)) }
    x += n * u
  }
  content((x0 + 8 * u, y3 - h - 3), txt("scales", size: 8pt), anchor: "north")
  content((x0 + 48 * u, y3 - h - 3), txt("qs", size: 8pt), anchor: "north")
  content((x0 + 82 * u, y3 - h - 3), txt("d, dmin", size: 8pt), anchor: "north-west")
  total(3, x0 + 84 * u, "84 B")

  let ly = y3 - h - 32
  legend(0, ly, "fp16 scale", box-swatch(0, ly, c.ink))
  legend(112, ly, "int8 codes", box-swatch(112, ly, c.teal1))
  legend(224, ly, "low-bit codes", box-swatch(224, ly, c.blue1))
  legend(350, ly, "4-bit sub-scales", box-swatch(350, ly, c.orange1))
})

/// Q2_K's two levels of scales, with the numbers of the example in the post:
/// two fp16 values per super-block scale the 4-bit s_j / m_j of each group,
/// which give that group's scale and offset, which place its 4 levels.
#let fig-q2k() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, n) = (112, 26.5, 16)
  let x1 = x0 + n * cw
  let cx(j) = x0 + (j + .5) * cw
  let (d, dmin) = (0.01, 0.005)
  let s = (7, 4, 9, 2, 11, 5, 8, 6, 10, 3, 6, 13, 6, 7, 9, 5)
  let m = (3, 8, 2, 10, 6, 9, 1, 4, 5, 7, 3, 2, 4, 4, 6, 8)
  let hl = (3, 12)
  let fmt(v) = {
    let r = calc.round(v, digits: 3)
    if r < 0 { "−" + str(-r) } else { str(r) }
  }
  // two decimals, so the levels read 0.10, not 0.1
  let fmt2(v) = {
    let t = str(calc.round(calc.abs(v) * 100))
    let t = if t.len() < 3 { "0" * (3 - t.len()) + t } else { t }
    (if v < -0.0001 { "−" } else { "" }) + t.slice(0, -2) + "." + t.slice(-2)
  }
  let level-label(y, name, note) = {
    content((0, y + 6), txt(name, size: 9.5pt, fill: c.ink, weight: 700), anchor: "west")
    content((0, y - 7), txt(note, size: 8pt), anchor: "west")
  }
  rect((0, 12), (1, 11), stroke: none)  // headroom
  content((0, 0), head("one Q2_K super-block · 256 weights = 16 groups × 16"), anchor: "west")

  // level 1: two fp16 values shared by all 16 groups
  let (yd, ym, bh) = (-16, -40, 22)
  rect((x0, yd), (x1, yd - bh), fill: c.blue2, stroke: .6pt + white)
  content(((x0 + x1) / 2, yd - bh / 2), txt[*d = 0.01* (fp16)  ·  multiplies every $s_j$], anchor: "center")
  rect((x0, ym), (x1, ym - bh), fill: c.orange2, stroke: .6pt + white)
  content(((x0 + x1) / 2, ym - bh / 2), txt[*dmin = 0.005* (fp16)  ·  multiplies every $m_j$], anchor: "center")
  level-label(-39, "per super-block", "2 × fp16 = 4 B")

  // level 2: one byte per group, s_j in the low nibble, m_j in the high one
  let (yi, ys, rh) = (-76, -84, 20)
  for j in range(n) {
    let on = j in hl
    content((cx(j), yi), txt(str(j), size: 8pt, fill: if on { c.ink } else { c.muted }, weight: if on { 700 } else { 400 }))
    rect((x0 + j * cw, ys), (x0 + (j + 1) * cw, ys - rh), fill: if on { c.blue2 } else { c.blue1 }, stroke: .6pt + white)
    rect((x0 + j * cw, ys - rh), (x0 + (j + 1) * cw, ys - 2 * rh), fill: if on { c.orange2 } else { c.orange1 }, stroke: .6pt + white)
    let ink = if on { c.ink } else { c.muted }
    content((cx(j), ys - rh / 2), txt(str(s.at(j)), size: 9pt, fill: ink, weight: if on { 700 } else { 400 }))
    content((cx(j), ys - 1.5 * rh), txt(str(m.at(j)), size: 9pt, fill: ink, weight: if on { 700 } else { 400 }))
  }
  content((x0 - 6, yi), txt("group j", size: 8pt), anchor: "east")
  content((x0 - 6, ys - rh / 2), txt($s_j$, fill: c.blue, weight: 700), anchor: "east")
  content((x0 - 6, ys - 1.5 * rh), txt($m_j$, fill: c.orange, weight: 700), anchor: "east")
  level-label(ys - rh, "per group", "4 + 4 bit = 1 B")
  for j in hl {
    rect((x0 + j * cw, yi + 8), (x0 + (j + 1) * cw, ys - 2 * rh), stroke: 1.1pt + c.ink)
  }

  // the decoded scale and offset of the two highlighted groups
  let (yb, bw, bh2) = (-146, 196, 38)
  for j in hl {
    arrow((cx(j), ys - 2 * rh - 2), (cx(j), yb + 1), color: c.ink, w: .8pt)
    rect((cx(j) - bw / 2, yb), (cx(j) + bw / 2, yb - bh2), fill: c.panel, stroke: .6pt + c.hair)
    content((cx(j), yb - 11), txt([$"scale"_#j$ = d · #s.at(j) = #fmt(d * s.at(j))], size: 9pt, fill: c.blue, weight: 600))
    content((cx(j), yb - 27), txt([$"offset"_#j$ = dmin · #m.at(j) = #fmt(dmin * m.at(j))], size: 9pt, fill: c.orange, weight: 600))
  }

  // level 3: the 4 levels each group can encode, on one shared axis
  let (v0, v1) = (-0.06, 0.18)
  let X(v) = x0 + (v - v0) / (v1 - v0) * (x1 - x0)
  let (yr, ya) = ((-220, -258), -290)
  line((X(0), yb - bh2 - 8), (X(0), ya), stroke: dotted)
  for (r, j) in hl.enumerate() {
    let y = yr.at(r)
    let lv = range(4).map(q => d * s.at(j) * q - dmin * m.at(j))
    arrow((cx(j), yb - bh2 - 1), (cx(j), y + 16), color: c.ink, w: .8pt)
    line((X(lv.first()), y), (X(lv.last()), y), stroke: 1.4pt + c.grey2)
    for (q, v) in lv.enumerate() {
      circle((X(v), y), radius: 3.6, fill: c.ink, stroke: 1pt + white)
      content((X(v), y + 10), txt("q=" + str(q), size: 7.5pt))
      content((X(v), y - 11), txt(fmt2(v), size: 8.5pt, fill: c.ink, weight: 600))
    }
    content((x0 - 6, y), txt("group " + str(j), size: 8.5pt, fill: c.ink), anchor: "east")
  }
  level-label(-239, "per weight", "2-bit q → 1 of 4")
  line((x0, ya), (x1, ya), stroke: .7pt + c.line)
  for t in range(-1, 5) {
    let v = t * 0.04
    line((X(v), ya), (X(v), ya - 4), stroke: .7pt + c.line)
    content((X(v), ya - 12), txt(fmt(v), size: 8pt))
  }

  content(((x0 + x1) / 2, ya - 34), txt([w = $"scale"_j$ · q − $"offset"_j$ = d · $s_j$ · q − dmin · $m_j$], size: 10pt, fill: c.ink, weight: 600))
})

/// Which type each tensor of the real Qwen3-8B-Q4_K_M.gguf got: Q4_K_M is a
/// recipe, not a type; attn_v and ffn_down are bumped to q6_K on half the layers.
#let fig-gguf-mix() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, rh) = (92, 12.5, 17)
  let q6 = (0, 1, 2, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 31, 32, 33, 34, 35)
  let rows = ("attn_q", "attn_k", "attn_v", "attn_output", "ffn_gate", "ffn_up", "ffn_down")
  rect((0, 46), (1, 45), stroke: none)  // headroom
  content((0, 34), head("Qwen3-8B-Q4_K_M.gguf · 36 blocks"), anchor: "west")
  for l in (0, 5, 10, 15, 20, 25, 30, 35) {
    content((x0 + (l + .5) * cw, 4), txt(str(l), size: 8pt), anchor: "south")
  }
  content((x0 - 8, 10), txt("blk.", size: 8pt), anchor: "east")
  for (i, name) in rows.enumerate() {
    let y = -i * rh
    content((x0 - 8, y - rh / 2), txt(name, fill: c.ink), anchor: "east")
    let bumped = name == "attn_v" or name == "ffn_down"
    for l in range(36) {
      let hot = bumped and l in q6
      rect((x0 + l * cw, y), (x0 + (l + 1) * cw, y - rh), fill: if hot { c.orange } else { c.blue1 }, stroke: .6pt + white)
    }
  }
  let yo = -7 * rh - 16
  content((x0 - 8, yo), txt("other", fill: c.ink), anchor: "east")
  pill((x0, yo), "token_embd · q4_K", tone: "pale", size: 8.5pt, anchor: "west")
  pill((x0 + 128, yo), "output · q6_K", tone: "orange", size: 8.5pt, anchor: "west")
  pill((x0 + 230, yo), "145 norm vectors · f32", tone: "muted", size: 8.5pt, anchor: "west")

  let ly = yo - 30
  legend(x0, ly, "q4_K · 217 tensors · 3.70 GB", box-swatch(x0, ly, c.blue1))
  legend(x0 + 230, ly, "q6_K · 37 tensors · 1.32 GB", box-swatch(x0 + 230, ly, c.orange))
})

// ============================================================================
// One row: vec_dot
// ============================================================================

#let qs-hex = ("53", "26", "49", "11", "6C", "B1", "6D", "7D", "22", "C6", "FC", "F4", "E0", "9B", "A4", "45")
#let q-lo = (-5, -2, 1, -7, 4, -7, 5, 5, -6, -2, 4, -4, -8, 3, -4, -3)
#let q-hi = (-3, -6, -4, -7, -2, 3, -2, -1, -6, 4, 7, 7, 6, 1, 2, -4)
#let q-x = (
  8, -32, -40, 127, 123, -43, -45, 73, -74, 105, -3, -121, 124, -108, 57, 18,
  -89, 86, -6, -71, -127, 4, 44, 0, 108, -21, 123, 26, 73, 51, 4, 58,
)

/// block_q4_0 above block_q8_0, column-aligned: byte qs[j] holds element j
/// (low nibble) and element j + 16 (high nibble).
#let fig-block-layout() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, h) = (112, 27, 20)
  let dcell(y, body) = {
    rect((x0 - 46, y), (x0 - 6, y - h), fill: c.ink, stroke: none)
    content((x0 - 26, y - h / 2), txt("d", fill: white, weight: 700))
    content((x0 - 26, y - h - 3), txt(body, size: 7.5pt), anchor: "north")
  }

  rect((0, 38), (1, 37), stroke: none)  // headroom
  content((0, 26), head("block_q4_0 · 18 B", fill: c.blue), anchor: "west")
  dcell(0, "−0.1225")
  for (j, hx) in qs-hex.enumerate() {
    let x = x0 + j * cw
    rect((x, 0), (x + cw / 2, -h), fill: c.orange1, stroke: .6pt + white)
    rect((x + cw / 2, 0), (x + cw, -h), fill: c.blue1, stroke: .6pt + white)
    content((x + cw / 4, -h / 2), txt(hx.at(0), fill: c.ink, weight: 700))
    content((x + 3 * cw / 4, -h / 2), txt(hx.at(1), fill: c.ink, weight: 700))
  }
  content((x0 + 8 * cw, 4), txt("qs[0] … qs[15]: high nibble │ low nibble", size: 8.5pt), anchor: "south")

  let (yl, yh) = (-44, -66)
  vals((x0, yl), q-lo.map(num), cw, h, paint: k => c.blue1)
  vals((x0, yh), q-hi.map(num), cw, h, paint: k => c.orange1)
  row-label(x0 - 8, yl - h / 2, "elems 0–15", note: "low nibble − 8")
  row-label(x0 - 8, yh - h / 2, "elems 16–31", note: "high nibble − 8")

  let yq = -126
  content((0, yq + 24), head("block_q8_0 · 34 B", fill: c.teal), anchor: "west")
  rect((x0 - 46, yq), (x0 - 6, yq - 2 * h - 2), fill: c.ink, stroke: none)
  content((x0 - 26, yq - h / 2 - 2), txt("d", fill: white, weight: 700))
  content((x0 - 26, yq - 1.5 * h), txt("0.0077", size: 7pt, fill: white))
  vals((x0, yq), q-x.slice(0, 16).map(num), cw, h, paint: k => c.teal1, size: 8.5pt)
  vals((x0, yq - h - 2), q-x.slice(16).map(num), cw, h, paint: k => c.teal1, size: 8.5pt)
  content((x0 - 52, yq - h / 2), txt("0–15", fill: c.ink), anchor: "east")
  content((x0 - 52, yq - 1.5 * h - 2), txt("16–31", fill: c.ink), anchor: "east")

  content((x0 + 8 * cw, yq - 2 * h - 14), txt("column j: blue meets q8 elements 0–15, orange meets 16–31", style: "italic"), anchor: "north")
})

/// One block through the NEON path: unpack, two SDOT passes into one
/// int32x4, scale into a float32x4.
#let fig-neon-block() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, h) = (150, 25, 18)
  let rows = (
    (0, "vld1q_u8(x->qs)", "16 bytes", qs-hex, c.grey1),
    (-46, "& 0x0F, − 8", "elems 0–15", q-lo.map(num), c.blue1),
    (-66, "vld1q_s8(y->qs)", "elems 0–15", q-x.slice(0, 16).map(num), c.teal1),
    (-104, ">> 4, − 8", "elems 16–31", q-hi.map(num), c.orange1),
    (-124, "vld1q_s8(y->qs + 16)", "elems 16–31", q-x.slice(16).map(num), c.teal1),
  )
  for (y, l, sub, body, fill) in rows {
    row-label(x0 - 8, y - h / 2, l, note: sub)
    vals((x0, y), body, cw, h, paint: k => fill, size: 8.5pt)
  }
  for g in range(5) {
    let x = x0 + g * 4 * cw
    line((x, -44), (x, -86), stroke: 1.1pt + c.ink)
    line((x, -102), (x, -144), stroke: 1.1pt + c.ink)
  }
  for l in range(4) { content((x0 + (l * 4 + 2) * cw, -44), txt("lane " + str(l), size: 8.5pt, fill: c.ink, weight: 600), anchor: "south") }
  arrow((x0 + 10 * cw, -h - 1), (x0 + 10 * cw, -30), color: c.line)
  content((x0 + 10 * cw + 6, -h - 3), txt("4-bit → 8-bit", size: 8.5pt), anchor: "north-west")
  content((x0 + 8 * cw, -94), txt("SDOT #1 above, SDOT #2 below, both into one int32x4", size: 8.5pt, fill: c.ink, style: "italic"))

  let yl = -148
  for l in range(4) { brace(x0 + l * 4 * cw, x0 + (l + 1) * 4 * cw, yl, color: c.ink) }
  let lo = (-905, 933, 706, -1598)
  let hi = (272, 178, 311, 265)
  let s = (-633, 1111, 1017, -1333)
  let yi = yl - 12
  row-label(x0 - 8, yi - h / 2, "int32x4", note: "8 products per lane")
  vals((x0, yi), range(4).map(l => num(lo.at(l)) + " + " + num(hi.at(l)) + " = " + num(s.at(l))), 4 * cw, h, paint: k => c.teal2, size: 8.5pt)
  let yf = yi - 48
  arrow((x0 + 8 * cw, yi - h - 1), (x0 + 8 * cw, yf + 1), color: c.line)
  content((x0 + 8 * cw + 6, yi - h - 6), txt("to float, × d_w · d_x, add to sumv0", size: 8.5pt), anchor: "north-west")
  row-label(x0 - 8, yf - h / 2, "float32x4", note: "sumv0 += …")
  vals((x0, yf), ("0.5984", "−1.0503", "−0.9614", "1.2601"), 4 * cw, h, paint: k => c.blue2, size: 8.5pt)
  content((x0 + 16 * cw, yf - h - 4), txt("the 4 lanes are only added together when the row ends", size: 8.5pt), anchor: "north-east")
})

/// The NEON loop: two blocks per iteration into two independent accumulators.
#let fig-neon-loop() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, bw, n) = (72, 68, 7)
  let xc(i) = x0 + (i + .5) * bw
  rect((0, 30), (1, 29), stroke: none)
  for i in range(n) {
    let fill = if i == n - 1 { c.grey1 } else if calc.rem(i, 2) == 0 { c.blue1 } else { c.teal1 }
    rect((x0 + i * bw, 0), (x0 + (i + 1) * bw, -22), fill: fill, stroke: .6pt + white)
    content((xc(i), -11), txt("block " + str(i), fill: c.ink, weight: 600))
  }
  for p in range(3) {
    let (a, b) = (x0 + p * 2 * bw, x0 + (p + 1) * 2 * bw)
    line((a + 1, 4), (a + 1, 8), (b - 1, 8), (b - 1, 4), stroke: .7pt + c.line)
    content(((a + b) / 2, 10), txt("iteration " + str(p), size: 8.5pt), anchor: "south")
  }
  content((xc(n - 1), 10), txt("odd one", size: 8.5pt), anchor: "south")

  for (y, name, color, tone, r) in ((-54, "sumv0", c.blue, "pale", 0), (-92, "sumv1", c.teal, "teal", 1)) {
    content((x0 - 10, y), txt(name, fill: color, weight: 700), anchor: "east")
    for p in range(3) {
      let i = 2 * p + r
      arrow((xc(i), -23), (xc(i), y + 10), color: color, w: .6pt)
      pill((xc(i), y), "+ b" + str(i), name: name + str(p), tone: tone, size: 8.5pt)
      if p > 0 { arrow(name + str(p - 1) + ".east", name + str(p) + ".west", color: color, w: .9pt) }
    }
  }
  arrow((xc(n - 1), -23), (xc(n - 1), -118), color: c.line, w: .6pt)
  pill((xc(n - 1), -126), "scalar", name: "t", tone: "muted", size: 8.5pt)
  pill((xc(3), -164), "vaddvq(sumv0) + vaddvq(sumv1) + tail", name: "h", tone: "orange", size: 9pt)
  arrow("sumv02.south", (xc(3) - 40, -153), color: c.orange, w: .7pt)
  arrow("sumv12.south", (xc(3) + 30, -153), color: c.orange, w: .7pt)
  arrow("t.south", (xc(3) + 110, -153), color: c.orange, w: .7pt)
  content((x0 - 10, -73), align(right, txt("two\nindependent\nchains", size: 8pt)), anchor: "east")
})

// ============================================================================
// Who computes what
// ============================================================================

/// The call tree of one decode mul_mat: chunks are what threads share; below
/// a chunk, everything runs on one thread.
#let fig-call-tree() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (H, bw) = (220, 40)
  let (x1, x2, x3, x4) = (20, 150, 280, 384)
  let band(x, n, k, fill) = {
    rect((x, 0), (x + bw, -H), fill: c.grey1, stroke: .6pt + c.hair)
    let bh = H / n
    if n <= 16 {
      for i in range(1, n) { line((x, -i * bh), (x + bw, -i * bh), stroke: .5pt + white) }
    }
    rect((x, -k * bh), (x + bw, -(k + 1) * bh), fill: fill, stroke: none)
  }
  let span(n, k) = (-k * H / n, -(k + 1) * H / n)
  // level 1: 12288 rows in 192 chunks
  band(x1, 192, 60, c.blue)
  let (a1, b1) = span(192, 60)
  content((x1 + bw / 2, 8), head("mul_mat"), anchor: "south")
  content((x1 + bw / 2, -H - 6), align(center, txt("12288 rows\n192 chunks\n× 64 rows", size: 8.5pt)), anchor: "north")
  // level 2: one chunk, 4 tiles
  band(x2, 4, 1, c.blue2)
  let (a2, b2) = span(4, 1)
  content((x2 + bw / 2, 8), head("chunk"), anchor: "south")
  content((x2 + bw / 2, -H - 6), align(center, txt("64 rows\n4 tiles × 16\n(blck_0)", size: 8.5pt)), anchor: "north")
  // level 3: one tile, 16 rows
  band(x3, 16, 5, c.orange)
  let (a3, b3) = span(16, 5)
  content((x3 + bw / 2, 8), head("tile"), anchor: "south")
  content((x3 + bw / 2, -H - 6), align(center, txt("16 rows\n1 vec_dot\nper row", size: 8.5pt)), anchor: "north")
  line((x1 + bw, a1), (x2, 0), stroke: dotted)
  line((x1 + bw, b1), (x2, -H), stroke: dotted)
  line((x2 + bw, a2), (x3, 0), stroke: dotted)
  line((x2 + bw, b2), (x3, -H), stroke: dotted)
  // level 4: one row = one vec_dot over 128 blocks
  let (rw, rh) = (164, 26)
  let ry = (a3 + b3) / 2 + rh / 2
  line((x3 + bw, a3), (x4, ry), stroke: dotted)
  line((x3 + bw, b3), (x4, ry - rh), stroke: dotted)
  for p in range(64) {
    let w = rw / 64
    rect((x4 + p * w, ry), (x4 + (p + 1) * w, ry - rh), fill: if calc.rem(p, 2) == 0 { c.blue2 } else { c.teal2 }, stroke: none)
  }
  rect((x4, ry), (x4 + rw, ry - rh), stroke: .8pt + c.orange)
  content((x4 + rw / 2, ry + 8), head("one row"), anchor: "south")
  content((x4 + rw / 2, ry - rh - 6), align(center, txt("vec_dot over K = 4096\n128 blocks, 64 NEON iterations\n→ 1 float in dst", size: 8.5pt)), anchor: "north")

  // who runs what
  let yb = 46
  line((x1 - 4, yb), (x1 + bw + 4, yb), stroke: 1.4pt + c.blue)
  content((x1 + bw / 2, yb + 4), txt("threads share", size: 8.5pt, fill: c.blue, weight: 600), anchor: "south")
  line((x2 - 4, yb), (x4 + rw, yb), stroke: 1.4pt + c.orange)
  content(((x2 + x4 + rw) / 2, yb + 4), txt("one thread, start to finish", size: 8.5pt, fill: c.orange, weight: 600), anchor: "south")
})

/// Decode with 1, 2 and 4 threads, from the trace: who quantizes which part
/// of x, and which thread ended up computing each of the 192 chunks.
#let fig-threads-plain() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (cw, cols, gw, gap) = (10.5, 16, 168, 18)
  let ns = (1, 2, 4)
  let qy = 0
  content((0, qy + 34), head("① quantize x → Q8_0 · 128 blocks split along K"), anchor: "west")
  for (i, n) in ns.enumerate() {
    let x0 = i * (gw + gap)
    content((x0, qy + 5), txt(str(n) + (if n == 1 { " thread" } else { " threads" }), size: 9.5pt, fill: c.ink, weight: 700), anchor: "south-west")
    for t in range(n) {
      let (a, b) = (t * 128 / n, (t + 1) * 128 / n)
      rect((x0 + a / 128 * gw, qy), (x0 + b / 128 * gw, qy - 16), fill: tc.at(t), stroke: .8pt + white)
      content((x0 + (a + b) / 256 * gw, qy - 8), txt("t" + str(t), size: 8.5pt, fill: white, weight: 700))
    }
  }
  let by = qy - 28
  line((0, by), (3 * gw + 2 * gap, by), stroke: (paint: c.orange, thickness: 1.2pt, dash: "dashed"))
  content((3 * gw + 2 * gap, by + 3), txt("ggml_barrier", size: 8.5pt, fill: c.orange), anchor: "south-east")

  let gy = by - 40
  content((0, gy + 18), head("② 192 chunks × 64 rows · colour = thread that ran it"), anchor: "west")
  for (i, n) in ns.enumerate() {
    let x0 = i * (gw + gap)
    let owner = trace.at(str(n)).owner
    for (k, t) in owner.enumerate() {
      let (r, col) = (calc.quo(k, cols), calc.rem(k, cols))
      rect((x0 + col * cw, gy - r * cw), (x0 + (col + 1) * cw, gy - (r + 1) * cw), fill: tc.at(t), stroke: .5pt + white)
    }
    // the first n chunks are fixed: chunk i -> thread i
    for t in range(n) {
      circle((x0 + (t + .5) * cw, gy - .5 * cw), radius: 1.8, fill: white, stroke: none)
    }
    let counts = range(n).map(t => owner.filter(o => o == t).len())
    content((x0 + gw / 2, gy - 12 * cw - 6), txt(range(n).map(t => "t" + str(t) + ": " + str(counts.at(t))).join("  "), size: 8.5pt, fill: c.ink), anchor: "north")
    content((x0 + gw / 2, gy - 12 * cw - 20), txt("one mul_mat: " + str(trace.at(str(n)).plain-us) + " µs", size: 8.5pt, fill: c.orange, weight: 700), anchor: "north")
  }
  content((0, gy + 3), txt("chunk 0 → 15, then next line", size: 7.5pt), anchor: "south-west")
  let ly = gy - 12 * cw - 48
  circle((5, ly), radius: 2.2, fill: c.ink, stroke: none)
  content((14, ly), txt("chunk i < nth: thread i, fixed", size: 8.5pt), anchor: "west")
  content((236, ly), txt("rest: whoever bumps current_chunk first", size: 8.5pt), anchor: "west")
})

/// A timeline per thread for one 4-thread decode mul_mat: the vec_dot path
/// (192 small chunks) above, the repack path (one static range) below.
#let fig-gantt-4() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let tr = trace.at("4")
  let (x0, s, lh, lg) = (40, 1.45, 15, 5)
  let tx(t) = x0 + t * s
  let lane(y, t) = (y - t * (lh + lg), y - t * (lh + lg) - lh)
  let yp = -22
  let yr = yp - 4 * (lh + lg) - 30
  for t in range(0, 351, step: 50) {
    line((tx(t), 4), (tx(t), yr - 4 * (lh + lg)), stroke: (paint: c.grey2, thickness: .4pt))
    content((tx(t), 6), txt(str(t), size: 8pt), anchor: "south")
  }
  content((x0 - 8, 6), txt("µs", size: 8pt), anchor: "south-east")

  content((0, yp + 10), head("vec_dot path"), anchor: "west")
  for t in range(4) {
    let (a, b) = lane(yp - 2, t)
    content((x0 - 8, (a + b) / 2), txt("t" + str(t), fill: c.ink), anchor: "east")
  }
  for (ith, ch, s0, s1) in tr.chunks {
    let (a, b) = lane(yp - 2, ith)
    rect((tx(s0), a), (tx(s1), b), fill: tc.at(ith), stroke: .4pt + white)
  }
  let pe = tr.plain-us
  line((tx(pe), yp), (tx(pe), yp - 4 * (lh + lg)), stroke: 1pt + c.orange)
  content((tx(pe) + 4, yp - 2 * (lh + lg)), txt(str(pe) + " µs", fill: c.orange, weight: 700), anchor: "west")

  content((0, yr + 10), head("repack path"), anchor: "west")
  for (ith, a0, b0, s0, s1) in tr.rows {
    let (a, b) = lane(yr - 2, ith)
    content((x0 - 8, (a + b) / 2), txt("t" + str(ith), fill: c.ink), anchor: "east")
    rect((tx(s0), a), (tx(s1), b), fill: tc.at(ith), stroke: none)
    content((tx(s0) + 6, (a + b) / 2), txt("rows " + str(a0) + "–" + str(b0 - 1), size: 8.5pt, fill: white, weight: 600), anchor: "west")
  }
  let re = tr.repack-us
  line((tx(re), yr), (tx(re), yr - 4 * (lh + lg)), stroke: 1pt + c.orange)
  content((tx(re) + 4, yr - 2 * (lh + lg)), txt(str(re) + " µs", fill: c.orange, weight: 700), anchor: "west")
  content((x0, yr - 4 * (lh + lg) - 8), txt("each small box is one 64-row chunk (≈ 6 µs); quantizing x + barrier: < 1 µs", size: 8.5pt), anchor: "north-west")
})

// ============================================================================
// Repack
// ============================================================================

/// block_q4_0x4: the same K-block of 4 rows, interleaved 8 bytes at a time,
/// and how the repack path splits rows across threads (statically).
#let fig-repack() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let rc = (c.blue2, c.teal2, c.orange2, c.grey2)
  // plain layout: 4 rows, blocks along K
  content((0, 26), head("plain layout"), anchor: "west")
  let bw = 34
  for r in range(4) {
    let y = -r * 18
    content((22, y - 8), txt("r" + str(r), fill: c.ink), anchor: "east")
    for k in range(3) {
      rect((28 + k * bw, y), (28 + (k + 1) * bw, y - 16), fill: if k == 0 { rc.at(r) } else { c.grey1 }, stroke: .6pt + white)
      content((28 + (k + .5) * bw, y - 8), txt("b" + str(k), size: 8.5pt, fill: c.ink))
    }
    content((28 + 3 * bw + 4, y - 8), txt("…", fill: c.ink), anchor: "west")
  }
  arrow((150, -27), (196, -27), color: c.ink, w: 1.2pt)
  content((173, -21), txt("at load", size: 8pt), anchor: "south")

  // one block_q4_0x4 = 72 bytes
  let (x0, u) = (204, 4.6)
  content((x0, 26), head("block_q4_0x4 · b0 of r0–r3 · 72 B"), anchor: "west")
  let x = x0
  for r in range(4) {
    rect((x, 0), (x + 2 * u, -34), fill: c.ink, stroke: .6pt + white)
    x += 2 * u
  }
  content((x0 + 4 * u, -38), txt("4 × d", size: 8pt), anchor: "north")
  for half in range(2) {
    for r in range(4) {
      rect((x, 0), (x + 8 * u, -34), fill: rc.at(r), stroke: .6pt + white)
      content((x + 4 * u, -10), txt("r" + str(r), fill: c.ink, weight: 700))
      content((x + 4 * u, -24), txt(if half == 0 { "qs 0–7" } else { "qs 8–15" }, size: 7pt, fill: c.ink))
      x += 8 * u
    }
  }
  content((0, -88), align(left, txt("nibbles XOR 0x88 at load time, so the kernel needs no − 8.\none Q8_0 block of x is loaded once and used by all 4 rows: 8 × SDOT → float32x4 = 4 outputs.", size: 8.5pt, fill: c.ink)), anchor: "north-west")

  // static split across threads
  let sy = -134
  content((0, sy), head("threads: rows split up front, [ith · N / nth, (ith + 1) · N / nth)"), anchor: "west")
  let (bx, bwid) = (52, 490)
  for (i, n) in (1, 2, 4).enumerate() {
    let y = sy - 14 - i * 26
    content((bx - 8, y - 9), txt(str(n) + " thr", fill: c.ink), anchor: "east")
    for (ith, a0, b0, s0, s1) in trace.at(str(n)).rows {
      rect((bx + a0 / 12288 * bwid, y), (bx + b0 / 12288 * bwid, y - 18), fill: tc.at(ith), stroke: .8pt + white)
      content((bx + (a0 + b0) / 2 / 12288 * bwid, y - 9), txt("t" + str(ith) + " · rows " + str(a0) + "–" + str(b0 - 1), size: 8pt, fill: white, weight: 600))
    }
  }
  content((bx, sy - 14 - 3 * 26 - 2), txt("each thread runs one gemv over its rows, 4 at a time, and never takes more work", size: 8.5pt, style: "italic"), anchor: "north-west")
})

/// 14 threads (10 P + 4 E cores): the dynamic chunks of the vec_dot path
/// absorb the slow cores; the static split of the repack path waits for them.
#let fig-gantt-14() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let tr = trace.at("14")
  let (x0, s, lh, lg) = (24, 1.9, 10, 3)
  let tx(t) = x0 + t * s
  let lane(y, t) = (y - t * (lh + lg), y - t * (lh + lg) - lh)
  let H = 14 * (lh + lg)
  let yp = -22
  let yr = yp - H - 30
  for t in range(0, 241, step: 40) {
    line((tx(t), 4), (tx(t), yr - H), stroke: (paint: c.grey2, thickness: .4pt))
    content((tx(t), 6), txt(str(t), size: 8pt), anchor: "south")
  }
  content((x0 - 5, 6), txt("µs", size: 8pt), anchor: "south-east")

  content((0, yp + 10), head("vec_dot path · chunks handed out at run time"), anchor: "west")
  for (ith, ch, s0, s1) in tr.chunks {
    let (a, b) = lane(yp - 2, ith)
    rect((tx(s0), a), (tx(s1), b), fill: if s1 - s0 > 12 { c.orange } else { c.blue }, stroke: .4pt + white)
  }
  for t in range(14) {
    let (a, b) = lane(yp - 2, t)
    content((x0 - 5, (a + b) / 2), txt(str(t), size: 7.5pt, fill: c.ink), anchor: "east")
  }
  let pe = tr.plain-us
  line((tx(pe), yp), (tx(pe), yp - H), stroke: 1pt + c.ink)
  content((tx(pe) + 6, yp - H / 2), align(left, txt(str(pe) + " µs\nslow threads simply\ntake fewer chunks:\n6–7 vs 16–17", size: 8.5pt, fill: c.ink)), anchor: "west")

  content((0, yr + 10), head("repack path · rows fixed up front"), anchor: "west")
  let fast = calc.min(..tr.rows.map(r => r.at(4) - r.at(3)))
  for (ith, a0, b0, s0, s1) in tr.rows {
    let (a, b) = lane(yr - 2, ith)
    rect((tx(s0), a), (tx(s1), b), fill: if s1 - s0 > 1.3 * fast { c.orange } else { c.blue }, stroke: none)
    content((x0 - 5, (a + b) / 2), txt(str(ith), size: 7.5pt, fill: c.ink), anchor: "east")
  }
  let re = tr.repack-us
  line((tx(re), yr), (tx(re), yr - H), stroke: 1pt + c.ink)
  content((tx(re) + 6, yr - H / 2), align(left, txt(str(re) + " µs\nevery thread has 1/14\nof the rows; the op\nwaits for the slowest", size: 8.5pt, fill: c.ink)), anchor: "west")
  rect((0, yr - H - 34), (1, yr - H - 35), stroke: none)  // room for the legend

  let ly = yr - H - 20
  legend(x0, ly, "fast core", box-swatch(x0, ly, c.blue))
  legend(x0 + 110, ly, "≈ 2.4× slower per row (most likely an E core)", box-swatch(x0 + 110, ly, c.orange))
})
