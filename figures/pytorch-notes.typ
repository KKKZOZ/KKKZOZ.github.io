// Detailed figures for content/posts/ml-systems/pytorch-notes.typ, drawn with
// cetz. Same conventions as figures/numpy-notes.typ (whose cell helpers are
// reused here): coordinates in points, y grows upward, every figure under
// ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, curve-arrow, legend, tag, txt
#import "/figures/numpy-notes.typ": cell, lab, mat, tones

/// A small shape / caption line under or beside a matrix.
#let note(pos, body, anchor: "west", fill: c.muted, weight: 400) = cetz.draw.content(
  pos, txt(body, size: 7pt, fill: fill, weight: weight), anchor: anchor,
)

/// Column indices above a matrix whose top-left corner is (x, y).
#let col-ids(x, y, n, s: 22, fill: c.muted) = {
  for k in range(n) { note((x + k * s + s / 2, y + 7), str(k), anchor: "center", fill: fill) }
}

/// Row indices left of a matrix whose top-left corner is (x, y).
#let row-ids(x, y, n, s: 22, fill: c.muted) = {
  for r in range(n) { note((x - 5, y - r * s - s / 2), str(r), anchor: "east", fill: fill) }
}

// ============================================================================
// integer-array indexing
// ============================================================================

/// x[y] with a 2-D integer y: y is a mould, each slot is filled with a whole
/// row of x.
#let fig-index-int() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 18
  // One tone per row of x, so a row can be followed into the output.
  let rt = ("a", "b", "t", "g", "dark")
  let ys = ((1, 2, 4), (0, 0, 3))
  // x: the table
  let xx = 14
  content((0, 24), lab("x · (5, 4)", fill: c.blue), anchor: "west")
  for r in range(5) { for k in range(4) { cell(xx + k * s, -r * s, none, tone: rt.at(r), s: s) } }
  row-ids(xx, 0, 5, s: s)
  note((xx, -5 * s - 10), "5 rows (words) · 4 features")
  // y: the mould
  let yx = 150
  let yt = -s
  content((yx, 24), lab("y · (2, 3)", fill: c.orange), anchor: "west")
  mat(yx, yt, ys, tone: (r, k) => rt.at(ys.at(r).at(k)), s: s + 4)
  note((yx, yt - 2 * (s + 4) - 10), "each value = a row of x")
  // out: one block per row of y
  let ox = 290
  content((ox, 24), lab("x[y] · (2, 3, 4)", fill: c.teal), anchor: "west")
  for (i, row) in ys.enumerate() {
    let bx = ox + i * (4 * s + 30)
    note((bx + 2 * s, 4), "out[" + str(i) + "]", anchor: "center", fill: c.ink, weight: 600)
    for (j, v) in row.enumerate() {
      for k in range(4) { cell(bx + k * s, -s / 2 - j * s, none, tone: rt.at(v), s: s) }
      note((bx - 3, -s / 2 - j * s - s / 2), "x[" + str(v) + "]", anchor: "east")
    }
  }
  arrow((yx + 3 * (s + 4) + 8, yt - s - 4), (ox - 26, yt - s - 4))
  // shape algebra
  note((ox - 14, -5 * s - 10), "y.shape + x.shape[1:] = (2, 3) + (4,)", fill: c.ink, weight: 600)
})

// ============================================================================
// boolean-mask indexing
// ============================================================================

/// x[mask] with a 2-D mask over a 3-D x: the mask covers the first two axes,
/// each hit pulls out a whole length-4 vector.
#let fig-index-mask() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let m = ((true, false, true), (false, true, false))
  // mask
  content((0, 26), lab("y · (2, 3) bool", fill: c.orange), anchor: "west")
  mat(0, 0, m.map(row => row.map(v => if v { "T" } else { "F" })), tone: (r, k) => if m.at(r).at(k) { "b" } else { "g" })
  row-ids(0, 0, 2)
  col-ids(0, 0, 3)
  note((0, -2 * s - 10), "covers x's first two axes")
  // x: a 2 x 3 grid of length-4 vectors
  let (xx, u, gap) = (124, 11, 10)
  let vw = 4 * u
  content((xx, 26), lab("x · (2, 3, 4)", fill: c.blue), anchor: "west")
  for i in range(2) {
    for j in range(3) {
      let v = i * 3 + j + 1
      let hit = m.at(i).at(j)
      for k in range(4) {
        cell(xx + j * (vw + gap) + k * u, -i * s - (s - u) / 2, str(v), tone: if hit { "b" } else { "g" }, s: u, size: 6pt)
      }
    }
  }
  for j in range(3) { note((xx + j * (vw + gap) + vw / 2, 7), "j = " + str(j), anchor: "center") }
  for i in range(2) { note((xx - 5, -i * s - s / 2), "i = " + str(i), anchor: "east") }
  note((xx, -2 * s - 10), "each (i, j) holds a vector x[i, j, :]")
  // result
  let rx = 330
  content((rx, 26), lab("x[y] · (3, 4)", fill: c.teal), anchor: "west")
  let hits = ((0, 0), (0, 2), (1, 1))
  for (n, (i, j)) in hits.enumerate() {
    let v = i * 3 + j + 1
    mat(rx, -n * s + 4, ((v, v, v, v),), tone: (r, k) => "b", s: s - 4)
    note((rx + 4 * (s - 4) + 5, -n * s + 4 - (s - 4) / 2), "(" + str(i) + ", " + str(j) + ")", anchor: "west")
  }
  arrow((xx + 3 * (vw + gap) + 4, -s), (rx - 10, -s))
  note((rx, -3 * s - 4), "N_true = 3 rows, flattened in row-major order")
})

// ============================================================================
// repeat
// ============================================================================

/// repeat tiles the whole tensor; extra leading sizes first pad the shape with
/// 1s on the left.
#let fig-repeat() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 20
  // panel 1: x.repeat(2, 3)
    content((0, 22), lab("x · (2, 2)", fill: c.blue), anchor: "west")
  mat(0, 0, ((1, 2), (3, 4)), tone: (r, k) => "a", s: s)
  arrow((2 * s + 8, -s), (2 * s + 34, -s))
  let tx = 2 * s + 44
  content((tx, 22), lab("x.repeat(2, 3) · (4, 6)", fill: c.teal), anchor: "west")
  mat(tx, 0, range(4).map(r => range(6).map(k => (r, k))).map(row => row.map(((r, k)) => (1, 2, 3, 4).at(calc.rem(r, 2) * 2 + calc.rem(k, 2)))),
    tone: (r, k) => if r < 2 and k < 2 { "a" } else { "t" }, s: s)
  for ti in range(2) {
    for tk in range(3) {
      rect((tx + tk * 2 * s, -ti * 2 * s), (tx + (tk + 1) * 2 * s, -(ti + 1) * 2 * s), stroke: 1.1pt + c.ink, fill: none)
    }
  }
  note((tx + 3 * s, -4 * s - 10), "3 tiles across", anchor: "center", fill: c.ink, weight: 600)
  note((tx + 6 * s + 6, -2 * s), "2 tiles\ndown", anchor: "west", fill: c.ink, weight: 600)
  // panel 2: alignment, x.repeat(3, 1) on a 1-D x
  let px = 290
    content((px, 22), lab("x · (2,)", fill: c.blue), anchor: "west")
  mat(px, 0, ((10, 20),), tone: (r, k) => "a", s: s)
  arrow((px + 2 * s + 6, -s / 2), (px + 2 * s + 30, -s / 2))
  note((px + 2 * s + 18, -s / 2 + 8), "pad 1", anchor: "center")
  let qx = px + 2 * s + 40
  content((qx, 22), lab("(1, 2)", fill: c.blue), anchor: "west")
  rect((qx - 3, 3), (qx + 2 * s + 3, -s - 3), stroke: (paint: c.blue, thickness: .7pt, dash: "dashed"), radius: 3)
  mat(qx, 0, ((10, 20),), tone: (r, k) => "a", s: s)
  arrow((qx + 2 * s + 6, -s / 2), (qx + 2 * s + 30, -s / 2))
  let rx = qx + 2 * s + 40
  content((rx, 22), lab("x.repeat(3, 1) · (3, 2)", fill: c.teal), anchor: "west")
  mat(rx, 0, ((10, 20), (10, 20), (10, 20)), tone: (r, k) => if r == 0 { "a" } else { "t" }, s: s)
  // shape alignment ledger
  let ly = -3 * s - 14
  let ledger(y, name, a, b, why) = {
    note((px, y), name, fill: c.ink, weight: 600)
    note((px + 64, y), a, anchor: "center", fill: c.ink)
    note((px + 82, y), b, anchor: "center", fill: c.ink)
    note((px + 100, y), why)
  }
  ledger(ly, "sizes", "3", "1", "2 numbers → 2-D")
  ledger(ly - 13, "x.shape", "", "2", "right-aligned")
  ledger(ly - 26, "padded", "1", "2", "missing dim filled with 1")
  ledger(ly - 39, "result", "3", "2", "1·3, 2·1")
  // legend
  legend(0, -4 * s - 34, "original", box-swatch(0, -4 * s - 34, c.blue1, stroke: .6pt + c.blue))
  legend(76, -4 * s - 34, "physical copy (new memory)", box-swatch(76, -4 * s - 34, c.teal1, stroke: .6pt + c.teal))
})

// ============================================================================
// einsum
// ============================================================================

/// 'ik,kj->ij': a letter in the output is kept, a letter only in the inputs
/// is summed away.
#let fig-einsum() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 16
  let (i0, j0) = (1, 2)
  // A (i, k)
  content((0, 26), lab("A · ik (3, 5)", fill: c.blue), anchor: "west")
  mat(0, 0, range(3).map(_ => range(5).map(_ => none)), tone: (r, k) => if r == i0 { "a" } else { "g" }, s: s)
  note((-5, -i0 * s - s / 2), "i", anchor: "east", fill: c.blue, weight: 700)
  note((5 * s / 2, -3 * s - 9), "k →", anchor: "center", fill: c.orange, weight: 700)
  // B (k, j)
  let bx = 5 * s + 40
  content((bx, 26), lab("B · kj (5, 4)", fill: c.blue), anchor: "west")
  mat(bx, 0, range(5).map(_ => range(4).map(_ => none)), tone: (r, k) => if k == j0 { "a" } else { "g" }, s: s)
  note((bx + j0 * s + s / 2, -5 * s - 9), "j", anchor: "center", fill: c.blue, weight: 700)
  note((bx - 5, -5 * s / 2), "k ↓", anchor: "east", fill: c.orange, weight: 700)
  // C (i, j)
  let cx = bx + 4 * s + 40
  content((cx, 26), lab("C · ij (3, 4)", fill: c.teal), anchor: "west")
  mat(cx, 0, range(3).map(_ => range(4).map(_ => none)), tone: (r, k) => if r == i0 and k == j0 { "t" } else { "ghost" }, s: s)
  content((cx + 2 * s, -3 * s - 18), txt($C_(i j) = sum_k A_(i k) B_(k j)$, size: 8pt, fill: c.ink))
  note((0, -5 * s - 26), "k appears in both inputs but not after '->', so it is multiplied pairwise and summed away", fill: c.orange)
  // ledger for attention
  let lx = cx + 4 * s + 34
  content((lx, 26), lab("'bhid, bhjd -> bhij'", fill: c.ink), anchor: "west")
  let cols = (lx + 4, lx + 34, lx + 64, lx + 94)
  for (k, h) in ("", "Q", "K", "out").enumerate() { note((cols.at(k), 8), h, fill: c.ink, weight: 600) }
  let rows = (("b", true, true, true), ("h", true, true, true), ("i", true, false, true), ("j", false, true, true), ("d", true, true, false))
  for (n, (l, q, kk, o)) in rows.enumerate() {
    let y = -6 - n * 13
    let summed = not o
    note((cols.at(0), y), l, fill: if summed { c.orange } else { c.blue }, weight: 700)
    for (k, v) in (q, kk, o).enumerate() { note((cols.at(k + 1), y), if v { "✓" } else { "·" }) }
    note((cols.at(3) + 20, y), if summed { "summed" } else { "kept" }, fill: if summed { c.orange } else { c.muted })
  }
})

// ============================================================================
// topk / argmax
// ============================================================================

/// topk along dim=1: values and indices both have k columns; argmax is the
/// first column of indices.
#let fig-topk() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 24
  let p = ((0.1, 0.9, 0.0, 0.0, 0.0), (0.2, 0.1, 0.4, 0.1, 0.2), (0.0, 0.0, 0.1, 0.8, 0.1))
  let top = ((1, 0), (2, 0), (3, 2))
  let f(v) = str(v)
  let rank(r, k) = top.at(r).position(t => t == k)
  let tone-of(n) = if n == 0 { "b" } else if n == 1 { "t" } else { "g" }
  content((0, 30), lab("preds · (3, 5)", fill: c.blue), anchor: "west")
  mat(0, 0, p.map(row => row.map(f)), tone: (r, k) => tone-of(rank(r, k)), s: s, size: 7pt)
  col-ids(0, 0, 5, s: s)
  row-ids(0, 0, 3, s: s)
  arrow((0, -3 * s - 8), (5 * s, -3 * s - 8), color: c.orange, w: .9pt)
  note((5 * s / 2, -3 * s - 18), "search along dim=1", anchor: "center", fill: c.orange)
  // values
  let vx = 5 * s + 56
  content((vx, 30), lab("values · (3, 2)", fill: c.teal), anchor: "west")
  mat(vx, 0, top.enumerate().map(((r, t)) => t.map(k => f(p.at(r).at(k)))), tone: (r, k) => tone-of(k), s: s, size: 7pt)
  // indices
  let ix = vx + 2 * s + 30
  content((ix, 30), lab("indices · (3, 2)", fill: c.teal), anchor: "west")
  mat(ix, 0, top, tone: (r, k) => tone-of(k), s: s)
  rect((ix, 1), (ix + s, -3 * s - 1), stroke: (paint: c.ink, thickness: 1.2pt, dash: "dashed"), radius: 2)
  note((ix + s / 2, -3 * s - 12), "= argmax(dim=1)", anchor: "center", fill: c.ink, weight: 600)
  arrow((5 * s + 10, -1.5 * s), (vx - 10, -1.5 * s))
  note((5 * s + 33, -1.5 * s + 9), "k = 2", anchor: "center")
  // legend
  let ly = -3 * s - 40
  legend(0, ly, "1st", box-swatch(0, ly, c.orange1, stroke: .6pt + c.orange))
  legend(50, ly, "2nd", box-swatch(50, ly, c.teal1, stroke: .6pt + c.teal))
  note((100, ly), "only dim=1 shrinks 5 → k; dim 0 stays 3")
})

// ============================================================================
// scatter / gather
// ============================================================================

// Tone of src column j (scatter) / out column j (gather).
#let jt = ("a", "b")

/// target.scatter_(1, index, src): src[i][j] is written to target[i][index[i][j]].
#let fig-scatter() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let src = ((1, 2), (3, 4), (5, 6))
  let idx = ((1, 3), (0, 2), (4, 1))
  content((0, 30), lab("src · (3, 2)", fill: c.blue), anchor: "west")
  mat(0, 0, src, tone: (r, k) => jt.at(k), s: s)
  row-ids(0, 0, 3, s: s)
  col-ids(0, 0, 2, s: s)
  let ix = 2 * s + 34
  content((ix, 30), lab("index · (3, 2)", fill: c.orange), anchor: "west")
  mat(ix, 0, idx, tone: (r, k) => jt.at(k), s: s)
  col-ids(ix, 0, 2, s: s)
  note((ix + s, -3 * s - 10), "= column in target", anchor: "center")
  // target
  let tx = ix + 2 * s + 60
  let t = range(3).map(r => range(5).map(k => none))
  let who = range(3).map(r => range(5).map(k => none))
  for r in range(3) { for j in range(2) { who.at(r).at(idx.at(r).at(j)) = j } }
  content((tx, 30), lab("target · (3, 5)", fill: c.teal), anchor: "west")
  mat(tx, 0, range(3).map(r => range(5).map(k => {
    let j = who.at(r).at(k)
    if j == none { "0" } else { str(src.at(r).at(j)) }
  })), tone: (r, k) => { let j = who.at(r).at(k); if j == none { "g" } else { jt.at(j) } }, s: s)
  col-ids(tx, 0, 5, s: s)
  row-ids(tx, 0, 3, s: s)
  arrow((ix + 2 * s + 8, -1.5 * s), (tx - 18, -1.5 * s))
  // one worked element: src[2][0] = 5, index[2][0] = 4
  let y = -3 * s
  curve-arrow((s / 2, y - 2), (tx + 4 * s + s / 2, y - 2), (s / 2, y - 44), (tx + 4 * s + s / 2, y - 44), color: c.blue, w: .8pt)
  content(((tx + 4 * s) / 2 + s / 2, y - 36), box(fill: white, inset: 2pt,
    txt("src[2][0] = 5,  index[2][0] = 4  →  target[2][4] = 5", size: 7.5pt, fill: c.ink, weight: 600)))
  note((0, y - 58), "dim=1: the row i stays, the column comes from index · cells nobody writes keep their old value")
})

/// torch.gather(input, 1, index): out[i][j] = input[i][index[i][j]].
#let fig-gather() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let inp = ((1, 2, 3), (4, 5, 6), (7, 8, 9))
  let idx = ((0, 2), (1, 1), (2, 0))
  // which out column(s) read input[r][k]
  let readers(r, k) = range(2).filter(j => idx.at(r).at(j) == k)
  content((0, 30), lab("input · (3, 3)", fill: c.blue), anchor: "west")
  mat(0, 0, inp, tone: (r, k) => {
    let rd = readers(r, k)
    if rd.len() == 0 { "g" } else if rd.len() == 2 { "t" } else { jt.at(rd.at(0)) }
  }, s: s)
  row-ids(0, 0, 3, s: s)
  col-ids(0, 0, 3, s: s)
  let ix = 3 * s + 34
  content((ix, 30), lab("index · (3, 2)", fill: c.orange), anchor: "west")
  mat(ix, 0, idx, tone: (r, k) => jt.at(k), s: s)
  col-ids(ix, 0, 2, s: s)
  note((ix + s, -3 * s - 10), "= column in input", anchor: "center")
  let ox = ix + 2 * s + 60
  content((ox, 30), lab("out · (3, 2)", fill: c.teal), anchor: "west")
  mat(ox, 0, range(3).map(r => idx.at(r).map(k => inp.at(r).at(k))), tone: (r, k) => jt.at(k), s: s)
  col-ids(ox, 0, 2, s: s)
  note((ox + 2 * s + 8, -1.5 * s), "same shape\nas index", anchor: "west", fill: c.ink, weight: 600)
  arrow((ix + 2 * s + 8, -1.5 * s), (ox - 10, -1.5 * s))
  // worked element: out[2][0] = input[2][index[2][0]] = input[2][2] = 9
  let y = -3 * s
  curve-arrow((2 * s + s / 2, y - 2), (ox + s / 2, y - 2), (2 * s + s / 2, y - 40), (ox + s / 2, y - 40), color: c.blue, w: .8pt)
  content(((2 * s + ox) / 2 + s / 2, y - 32), box(fill: white, inset: 2pt,
    txt("index[2][0] = 2  →  out[2][0] = input[2][2] = 9", size: 7.5pt, fill: c.ink, weight: 600)))
  let ly = y - 56
  legend(0, ly, "read by out[:, 0]", box-swatch(0, ly, c.blue1, stroke: .6pt + c.blue))
  legend(110, ly, "read by out[:, 1]", box-swatch(110, ly, c.orange1, stroke: .6pt + c.orange))
  legend(220, ly, "read twice", box-swatch(220, ly, c.teal1, stroke: .6pt + c.teal))
  legend(296, ly, "not read", box-swatch(296, ly, c.grey1, stroke: .6pt + c.grey2))
})

// ============================================================================
// sum
// ============================================================================

/// sum(dim) squeezes that axis away.
#let fig-sum() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 22
  let a = ((1, 2, 3), (4, 5, 6))
  // sum(0)
  content((0, 14), lab("a.sum(0) · (2, 3) → (3,)", fill: c.blue), anchor: "west")
  mat(0, 0, a, tone: (r, k) => if r == 0 { "a" } else { "b" }, s: s)
  for k in range(3) { arrow((k * s + s / 2, -2 * s - 2), (k * s + s / 2, -2 * s - 18), color: c.ink, w: .8pt) }
  mat(0, -2 * s - 22, ((5, 7, 9),), tone: (r, k) => "t", s: s)
  note((0, -3 * s - 36), "dim 0 (rows) collapses: 1+4, 2+5, 3+6")
  note((0, -3 * s - 49), "keepdim=True → (1, 3)")
  // sum(1)
  let px = 180
  content((px, 14), lab("a.sum(1) · (2, 3) → (2,)", fill: c.blue), anchor: "west")
  mat(px, 0, a, tone: (r, k) => if r == 0 { "a" } else { "b" }, s: s)
  for r in range(2) { arrow((px + 3 * s + 2, -r * s - s / 2), (px + 3 * s + 18, -r * s - s / 2), color: c.ink, w: .8pt) }
  mat(px + 3 * s + 22, 0, ((6,), (15,)), tone: (r, k) => "t", s: s)
  note((px, -3 * s - 36), "dim 1 (columns) collapses: 1+2+3, 4+5+6")
  note((px, -3 * s - 49), "keepdim=True → (2, 1)")
})

// ============================================================================
// slices
// ============================================================================

/// Positive and negative indices, and slices as cuts between elements.
#let fig-slice() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 30
  let x0 = 70
  for k in range(4) { cell(x0 + k * s, 0, str(k + 1), tone: "a", s: s, size: 10pt) }
  note((x0 - 12, -s / 2 + 18), "index", anchor: "east", fill: c.blue, weight: 600)
  note((x0 - 12, -s / 2 - 22), "negative", anchor: "east", fill: c.orange, weight: 600)
  for k in range(4) {
    note((x0 + k * s + s / 2, 9), str(k), anchor: "center", fill: c.blue, weight: 600)
    note((x0 + k * s + s / 2, -s - 9), str(k - 4), anchor: "center", fill: c.orange, weight: 600)
  }
  // slices as brackets under the strip
  let bracket(y, a, b, label, color) = {
    let (l, r) = (x0 + a * s + 2, x0 + b * s - 2)
    if b > a {
      line((l, y + 4), (l, y), (r, y), (r, y + 4), stroke: 1pt + color)
    } else {
      line((l - 2, y + 4), (l - 2, y - 2), stroke: 1pt + color)
    }
    note((x0 + 4 * s + 16, y + 1), label, fill: color, weight: 600)
  }
  bracket(-s - 26, 0, 1, "a[:1]  → (1,)", c.ink)
  bracket(-s - 40, 0, 3, "a[:-1] → (1, 2, 3)   stop = -1 + 4 = 3, not included", c.ink)
  bracket(-s - 54, 1, 3, "a[1:3] → (2, 3)", c.ink)
  bracket(-s - 68, 0, 0, "a[:0]  → ()", c.muted)
})
