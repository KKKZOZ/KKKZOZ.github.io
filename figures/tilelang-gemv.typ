// Detailed figures for content/posts/ml-systems/gpu-kernels/tilelang-gemv.typ,
// drawn with cetz. Each `fig-*` function returns one canvas; coordinates are in
// points (1pt per unit, y grows upward) and every figure stays under ~560pt
// wide, so it renders at true scale in the 760px column.
//
// Every GEMV figure uses one layout for y = x W: the vector x (length K) lies
// at the lower left, W (K rows, N columns) at the upper right, and y (length
// N) right under W, so y[j] sits below column j of W and in the row of x.
// The kernels store W as `matrix` of shape (N, K), row-major, so a column of
// W is contiguous in memory, top to bottom.
//
// One colour per role: blue for the vector, orange for the matrix tile being
// read, teal for accumulators and outputs, grey for tiles already consumed.
// Figures that colour work by owner use `thread-fill`.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, tag, txt
#import "/templates/base.typ": palette
#import "/figures/tilelang.typ": thread-fill

#let cell-stroke = .4pt + c.line
#let grid-stroke = (paint: c.hair, thickness: .5pt, dash: "dotted")

/// A rows x cols grid; `o` is the top-left corner, rows grow downward.
/// `paint(r, k)` gives a fill (or none), `body(r, k)` optional centred content.
#let grid-cells(o, rows, cols, w, h, paint: (r, k) => none, body: (r, k) => none) = {
  import cetz.draw: *
  let (x0, y0) = o
  for r in range(rows) {
    for k in range(cols) {
      rect((x0 + k * w, y0 - r * h), (x0 + (k + 1) * w, y0 - (r + 1) * h), fill: paint(r, k), stroke: cell-stroke)
      let t = body(r, k)
      if t != none { content((x0 + k * w + w / 2, y0 - r * h - h / 2), t) }
    }
  }
}

/// A horizontal dimension line from x0 to x1 at y, label above (or below).
#let dim-h(x0, x1, y, body, below: false, color: c.muted) = {
  import cetz.draw: *
  let s = .6pt + c.muted
  line((x0, y), (x1, y), stroke: s)
  line((x0, y - 3), (x0, y + 3), stroke: s)
  line((x1, y - 3), (x1, y + 3), stroke: s)
  if below {
    content(((x0 + x1) / 2, y - 5), txt(body, size: 7.5pt, fill: color), anchor: "north")
  } else {
    content(((x0 + x1) / 2, y + 5), txt(body, size: 7.5pt, fill: color), anchor: "south")
  }
}

/// A vertical dimension line from y0 to y1 at x, label to the left (or right).
#let dim-v(x, y0, y1, body, right: false, color: c.muted) = {
  import cetz.draw: *
  let s = .6pt + c.muted
  line((x, y0), (x, y1), stroke: s)
  line((x - 3, y0), (x + 3, y0), stroke: s)
  line((x - 3, y1), (x + 3, y1), stroke: s)
  if right {
    content((x + 5, (y0 + y1) / 2), txt(body, size: 7.5pt, fill: color), anchor: "west")
  } else {
    content((x - 5, (y0 + y1) / 2), txt(body, size: 7.5pt, fill: color), anchor: "east")
  }
}

/// The name of an operand, x, W or y.
#let name(pos, body, anchor: "east", size: 9pt) = cetz.draw.content(
  pos, txt(body, size: size, fill: c.ink, style: "italic"), anchor: anchor,
)

/// A small label for an allocation (alloc_shared, alloc_local, ...).
#let alloc(body) = txt(body, size: 7.5pt, fill: c.orange, weight: 600)

// ============================================================================
// Layout
// ============================================================================

/// The layout every figure follows: y[j] comes from all of x and column j of
/// W, which is row j of `matrix` and contiguous in memory.
#let fig-layout() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, K, N, j) = (20, 16, 6, 8, 2)
  let (wx, wy) = (176, 0)
  let yy = wy - K * h - 14
  let x0 = wx - 30 - K * w
  // W, with column j highlighted
  grid-cells((wx, wy), K, N, w, h, paint: (k, n) => if n == j { c.orange1 } else { none })
  rect((wx + j * w, wy), (wx + (j + 1) * w, wy - K * h), stroke: 1pt + c.orange)
  arrow((wx + j * w + w / 2, wy - 4), (wx + j * w + w / 2, wy - K * h + 4), color: c.orange, w: 1pt)
  content((wx + j * w + w / 2, wy + 4), txt("j", size: 8pt, fill: c.ink, style: "italic"), anchor: "south")
  name((wx + N * w + 6, wy - K * h + 2), "W", anchor: "south-west")
  // y and x
  grid-cells((wx, yy), 1, N, w, h, paint: (r, n) => if n == j { c.teal1 } else { none })
  grid-cells((x0, yy), 1, K, w, h, paint: (r, k) => c.blue1)
  name((x0 - 5, yy - h / 2), "x")
  name((wx + N * w + 6, yy - h / 2), "y", anchor: "west")
  content((wx + N * w + 22, yy - h / 2), txt("y[j] = Σ_k x[k] · W[k, j]", fill: c.ink), anchor: "west")
  // dimensions
  dim-v(wx - 8, wy, wy - K * h, "K")
  dim-h(wx, wx + N * w, yy - h - 8, "N", below: true)
  dim-h(x0, x0 + K * w, yy - h - 8, "K", below: true)
  // memory
  let tx = wx + N * w + 16
  content((tx, wy - 2), txt("column j of W = matrix[j, :]", fill: c.ink, weight: 600), anchor: "north-west")
  content((tx, wy - 14), txt("matrix is (N, K), row-major,"), anchor: "north-west")
  content((tx, wy - 26), txt("so a column is contiguous"), anchor: "north-west")
  content((tx, wy - 38), txt("in memory, top to bottom"), anchor: "north-west")
})

// ============================================================================
// Thread view
// ============================================================================

/// thread_naive: one block owns block_n columns of W and walks down K one
/// tile at a time; each thread owns one column and one fp32 accumulator.
#let fig-thread-naive() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, K, N, xw) = (20, 15, 8, 8, 15)
  let (wx, wy) = (196, 0)
  let band = (2, 3)
  let tile = (2, 3)
  let yy = wy - K * h - 14
  let x0 = wx - 30 - K * xw
  // W: tiles of this block already summed, the current tile, the rest
  let pw(k, n) = if n in band {
    if k in tile { c.orange1 } else if k < 2 { c.grey2 } else { none }
  } else { none }
  grid-cells((wx, wy), K, N, w, h, paint: pw)
  rect((wx + 2 * w, wy), (wx + 4 * w, wy - K * h), stroke: (paint: c.teal, thickness: .8pt, dash: "dashed"))
  rect((wx + 2 * w, wy - 2 * h), (wx + 4 * w, wy - 4 * h), stroke: 1.2pt + c.orange)
  for n in band {
    let x = wx + n * w + w / 2
    arrow((x, wy - 2 * h - 3), (x, wy - 4 * h + 3), color: c.orange, w: 1pt)
  }
  name((wx + N * w + 6, wy - K * h + 2), "W", anchor: "south-west")
  dim-h(wx + 2 * w, wx + 4 * w, wy + 6, "block_n", color: c.teal)
  dim-v(wx - 8, wy - 2 * h, wy - 4 * h, "block_k", color: c.blue)
  dim-v(wx - 70, wy, wy - K * h, "K")
  let tx = wx + N * w + 14
  content((tx, wy - 2 * h - 1), alloc("matrix_shared · alloc_shared"), anchor: "north-west")
  content((tx, wy - 2 * h - 13), txt("the current tile, one per block"), anchor: "north-west")
  content((tx, wy - 4 * h - 8), txt("thread t0, t1: one column each,", fill: c.ink), anchor: "north-west")
  content((tx, wy - 4 * h - 20), txt("summed one tile at a time"), anchor: "north-west")
  content((tx, wy - 4 * h - 32), txt("(T.serial over K / block_k tiles)"), anchor: "north-west")
  // y: one accumulator per thread
  grid-cells((wx, yy), 1, N, w, h,
    paint: (r, n) => if n in band { c.teal1 } else { none },
    body: (r, n) => if n in band { txt("t" + str(n - 2), fill: c.ink, weight: 600) })
  name((wx + N * w + 6, yy - h / 2), "y", anchor: "west")
  content((wx + N * w + 20, yy - h / 2 + 5), alloc("accumulator · alloc_local"), anchor: "west")
  content((wx + N * w + 20, yy - h / 2 - 7), txt("one fp32 per thread"), anchor: "west")
  dim-h(wx, wx + N * w, yy - h - 8, "N", below: true)
  // x: the slice for the current tile
  grid-cells((x0, yy), 1, K, xw, h, paint: (r, k) => if k in tile { c.blue1 } else if k < 2 { c.grey2 } else { none })
  name((x0 - 5, yy - h / 2), "x")
  dim-h(x0 + 2 * xw, x0 + 4 * xw, yy + 6, "block_k", color: c.blue)
  dim-h(x0, x0 + K * xw, yy - h - 8, "K", below: true)
  content((x0, yy - h - 30), alloc("vector_shared · alloc_shared"), anchor: "west")
  // legend
  let ly = yy - h - 52
  legend(0, ly, "summed", box-swatch(0, ly, c.grey2, stroke: cell-stroke))
  legend(80, ly, "current tile", box-swatch(80, ly, c.orange1, stroke: cell-stroke))
  legend(180, ly, "columns of this block", line((180, ly), (191, ly), stroke: (paint: c.teal, thickness: .8pt, dash: "dashed")))
})

/// One warp's loads under the two thread layouts, scaled down: a warp of 8
/// lanes and a sector of 8 elements (on the GPU: 32 lanes, 16 fp16 values).
/// A sector is 8 cells down one column, since columns are contiguous.
#let fig-coalescing() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, xw) = (13, 11, 11)
  let panel(px0, title, sub, lane, vec-lane, foot) = {
    let wx = px0 + 8 * xw + 22
    let wy = 116
    content((px0, 150), txt(title, size: 8.5pt, fill: c.blue, weight: 700), anchor: "west")
    content((px0, 137), txt(sub), anchor: "west")
    // W: one sector per column
    let touched(n) = range(8).any(k => lane(k, n) != none)
    grid-cells((wx, wy), 8, 8, w, h,
      paint: (k, n) => if lane(k, n) != none { c.orange } else if touched(n) { c.orange1 } else { none },
      body: (k, n) => if lane(k, n) != none { txt(str(lane(k, n)), size: 6.5pt, fill: palette.paper, weight: 600) })
    for n in range(8) {
      rect((wx + n * w, wy), (wx + (n + 1) * w, wy - 8 * h), stroke: .8pt + c.muted)
    }
    arrow((wx + 8 * w + 6, wy - 2), (wx + 8 * w + 6, wy - 8 * h + 2), color: c.muted, w: .6pt)
    name((wx + 8 * w + 10, wy - 4 * h), "W", anchor: "west", size: 8.5pt)
    // y and x
    let yy = wy - 8 * h - 10
    grid-cells((wx, yy), 1, 8, w, h)
    name((wx + 8 * w + 5, yy - h / 2), "y", anchor: "west", size: 8.5pt)
    grid-cells((px0, yy), 1, 8, xw, h,
      paint: (r, k) => if vec-lane(k) != none { c.blue1 } else { none },
      body: (r, k) => if vec-lane(k) != none { txt(vec-lane(k), size: 6.5pt, fill: c.ink) })
    name((px0 - 4, yy - h / 2), "x", size: 8.5pt)
    for (i, l) in foot.enumerate() {
      content((px0, yy - h - 12 - i * 12), txt(l, fill: if i == 0 { c.ink } else { c.muted }, weight: if i == 0 { 600 } else { 400 }), anchor: "west")
    }
  }
  panel(
    0, "threads = (block_n, block_k)", "tid_n = threadIdx.x: lanes spread along N",
    (k, n) => if k == 0 { n } else { none },
    k => if k == 0 { "*" } else { none },
    ("8 sectors fetched", "1 element of each used", "x: 1 element (*), broadcast to all"),
  )
  panel(
    262, "threads = (block_k, block_n)", "tid_k = threadIdx.x: lanes go down a column",
    (k, n) => if n == 0 { k } else { none },
    k => str(k),
    ("1 sector fetched", "every element used", "x: 8 adjacent elements"),
  )
})

/// thread_split_k on one tile: reduce_threads threads share each column, each
/// walking tile_k contiguous elements, then add into one shared fp32 slot.
#let fig-thread-split-k() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, xw) = (24, 10, 9)
  let (wx, wy) = (200, 0)
  let owner(k) = thread-fill.at(calc.quo(k, 4))
  grid-cells((wx, wy), 16, 4, w, h, paint: (k, n) => owner(k))
  for n in range(4) {
    for t in range(4) {
      let x = wx + n * w + w / 2
      arrow((x, wy - t * 4 * h - 3), (x, wy - (t + 1) * 4 * h + 3), color: c.ink, w: .7pt)
    }
    content((wx + n * w + w / 2, wy + 4), txt(str(n), fill: c.ink), anchor: "south")
  }
  content((wx - 6, wy + 4), txt("tid_n", size: 7.5pt), anchor: "south-east")
  for t in range(4) {
    content((wx - 6, wy - t * 4 * h - 2 * h), txt("tid_k = " + str(t), size: 7.5pt), anchor: "east")
  }
  dim-v(wx + 4 * w + 10, wy, wy - 4 * h, "tile_k", right: true)
  dim-v(wx + 4 * w + 54, wy, wy - 16 * h, "block_k = reduce_threads × tile_k", right: true)
  // shared reduction slots, which become y
  let yy = wy - 16 * h - 30
  grid-cells((wx, yy), 1, 4, w, h + 4, paint: (r, n) => c.teal1)
  for n in range(4) {
    let x = wx + n * w + w / 2
    arrow((x, wy - 16 * h - 3), (x, yy + 3), color: c.teal, w: .8pt)
  }
  content((wx + 4 * w + 8, wy - 16 * h - 15), txt("atomic_add", size: 7.5pt, fill: c.teal, weight: 600), anchor: "west")
  content((wx + 4 * w + 8, yy - h / 2 - 2), alloc("reduced[tid_n] · alloc_shared, fp32"), anchor: "west")
  content((wx + 4 * w + 8, yy - h / 2 - 15), txt("4 adds each, then written to y"), anchor: "west")
  // x: each thread reads its own slice
  let x0 = wx - 26 - 16 * xw
  grid-cells((x0, yy), 1, 16, xw, h + 4, paint: (r, k) => owner(k))
  name((x0 - 5, yy - h / 2 - 2), "x")
  dim-h(x0, x0 + 16 * xw, yy - h - 12, "block_k", below: true)
})

/// Block access vs cyclic access of 16 elements of one column by 4 threads.
#let fig-block-cyclic() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h) = (28, 12)
  let column(x, owner) = for i in range(16) {
    rect((x, -i * h), (x + w, -(i + 1) * h), fill: thread-fill.at(owner(i)), stroke: .5pt + palette.paper)
    content((x + w / 2, -i * h - h / 2), txt(str(i), size: 6.5pt, fill: c.ink))
  }
  let brace(x, i0, i1, body) = {
    line((x, -i0 * h - 2), (x, -i1 * h + 2), stroke: .7pt + c.line)
    content((x - 4, -(i0 + i1) * h / 2), txt(body, size: 7pt, fill: c.ink), anchor: "east")
  }
  let panel(x0, title, formula, owner, brace-label, a, b) = {
    let cx = x0 + 64
    content((x0, 34), tag(title, fill: c.blue), anchor: "west")
    content((x0, 20), txt(formula), anchor: "west")
    column(cx, owner)
    for s in range(4) { brace(cx - 6, s * 4, (s + 1) * 4, brace-label(s)) }
    content((cx + w + 10, -4), txt(a, fill: c.ink, weight: 600), anchor: "north-west")
    content((cx + w + 10, -16), txt(b, size: 7.5pt), anchor: "north-west")
  }
  panel(0, "Block access", "k = tid_k · tile_k + i", i => calc.quo(i, 4), s => "tid_k = " + str(s),
    "contiguous per thread", "one vector load each")
  panel(262, "Cyclic access", "k = tid_k + i · reduce_threads", i => calc.rem(i, 4), s => "i = " + str(s),
    "contiguous per step", "coalesced if tid_k is threadIdx.x")
  for t in range(4) { legend(t * 80, -16 * h - 18, "tid_k = " + str(t), box-swatch(t * 80, -16 * h - 18, thread-fill.at(t))) }
})

/// thread_vectorized_split_k at its default config: threads = (2, 32), so
/// lane = 2 · tid_k + tid_n, and each lane loads 8 fp16 (16 bytes) at once.
#let fig-vectorized-warp() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, xw) = (30, 9, 6)
  let (wx, wy) = (250, 0)
  let warp-fill(j) = if j < 16 { c.blue1 } else { c.orange1 }
  for n in range(2) {
    for j in range(32) {
      rect((wx + n * w, wy - j * h), (wx + (n + 1) * w, wy - (j + 1) * h), fill: warp-fill(j), stroke: cell-stroke)
      content((wx + n * w + w / 2, wy - j * h - h / 2), txt(str(calc.rem(j, 16) * 2 + n), size: 5.5pt, fill: c.ink))
    }
    content((wx + n * w + w / 2, wy + 4), txt(str(n), fill: c.ink), anchor: "south")
  }
  content((wx - 6, wy + 4), txt("tid_n", size: 7.5pt), anchor: "south-east")
  name((wx - 8, wy - 20 * h), "W")
  dim-v(wx - 8, wy, wy - h, "tile_k = 8 fp16 = 16 B")
  dim-v(wx - 120, wy, wy - 32 * h, "block_k = 32 × 8 = 256")
  // warps
  let bx = wx + 2 * w + 10
  for (i, label) in ("warp 0", "warp 1").enumerate() {
    let (y0, y1) = (wy - i * 16 * h - 2, wy - (i + 1) * 16 * h + 2)
    line((bx, y0), (bx, y1), stroke: .7pt + c.line)
    content((bx + 6, (y0 + y1) / 2 + 12), txt(label, fill: c.ink, weight: 600), anchor: "west")
    content((bx + 6, (y0 + y1) / 2), txt("16 lanes × 16 B"), anchor: "west")
    content((bx + 6, (y0 + y1) / 2 - 12), txt("= 256 contiguous bytes"), anchor: "west")
    content((bx + 6, (y0 + y1) / 2 - 24), txt("in each column"), anchor: "west")
  }
  // y and x
  let yy = wy - 32 * h - 12
  grid-cells((wx, yy), 1, 2, w, h + 3, paint: (r, n) => c.teal1)
  name((wx + 2 * w + 6, yy - h / 2), "y", anchor: "west")
  let x0 = wx - 26 - 32 * xw
  grid-cells((x0, yy), 1, 32, xw, h + 3, paint: (r, j) => warp-fill(j))
  name((x0 - 4, yy - h / 2), "x")
  content((x0, yy - h - 16), txt("Numbers are lanes: lane = 2 · tid_k + tid_n, since tid_n is threadIdx.x."), anchor: "west")
})

// ============================================================================
// Block view
// ============================================================================

/// block_split_k: one block per (block_k, block_n) tile; the blocks of a
/// column band add their partial sums into one fp32 output slice with atomics.
#let fig-block-split-k() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (tw, th, KT, NT, xw) = (32, 20, 6, 4, 18)
  let (wx, wy) = (166, 0)
  let (hn, hk) = (3, 2)
  // grid of tiles, one block each
  grid-cells((wx, wy), KT, NT, tw, th,
    paint: (k, n) => if n == hn { c.orange1 } else { c.grey1 },
    body: (k, n) => txt(str(n) + ", " + str(k), size: 6.5pt, fill: c.ink))
  rect((wx + hn * tw, wy - hk * th), (wx + (hn + 1) * tw, wy - (hk + 1) * th), stroke: 1.2pt + c.orange)
  content((wx, wy + 4), txt("tile = block (pid_n, pid_k)", size: 7.5pt), anchor: "south-west")
  name((wx - 6, wy - KT * th / 2), "W")
  // fp32 output
  let yy = wy - KT * th - 26
  grid-cells((wx, yy), 1, NT, tw, 12, paint: (r, n) => if n == hn { c.teal1 } else { none })
  let ax = wx + hn * tw + tw / 2
  arrow((ax, wy - KT * th - 3), (ax, yy + 3), color: c.teal, w: 1pt)
  content((ax - 8, wy - KT * th - 13), txt("atomic_add, one per tile", size: 7.5pt, fill: c.teal, weight: 600), anchor: "east")
  name((wx + NT * tw + 6, yy - 6), "y", anchor: "west")
  content((wx + NT * tw + 18, yy - 6), txt("(fp32, zeroed)", size: 7.5pt), anchor: "west")
  // x, one chunk per pid_k
  let x0 = wx - 24 - KT * xw
  grid-cells((x0, yy), 1, KT, xw, 12, paint: (r, k) => if k == hk { c.blue1 } else { none })
  name((x0 - 5, yy - 6), "x")
  content((x0, yy - 24), txt("all 32 × 112 blocks are independent", size: 7.5pt), anchor: "west")
  // inside one block, in the same layout
  let (zw, zh, vw) = (12, 10, 9)
  let zx = wx + NT * tw + 120
  let zy = wy + 6
  let vx = zx - 14 - 8 * vw
  let zyy = zy - 8 * zh - 12
  content((vx, zy + 16), txt("block (3, 2)", size: 8.5pt, fill: c.orange, weight: 700), anchor: "west")
  grid-cells((zx, zy), 8, 4, zw, zh, paint: (k, n) => c.orange1)
  for n in range(4) {
    let x = zx + n * zw + zw / 2
    arrow((x, zy - 3), (x, zy - 8 * zh + 3), color: c.orange, w: .8pt)
  }
  content((zx + 4 * zw + 6, zy - 2), alloc("matrix_shared"), anchor: "north-west")
  grid-cells((zx, zyy), 1, 4, zw, zh, paint: (r, n) => c.teal1)
  content((zx + 4 * zw + 6, zyy - zh / 2), alloc("accumulator · fragment"), anchor: "west")
  grid-cells((vx, zyy), 1, 8, vw, zh, paint: (r, k) => c.blue1)
  content((vx, zyy - zh - 4), alloc("vector_shared"), anchor: "north-west")
  content((vx, zyy - zh - 20), txt("T.Parallel(block_n): a column each", size: 7pt), anchor: "north-west")
  content((vx, zyy - zh - 32), txt("T.serial(block_k): down the column", size: 7pt), anchor: "north-west")
  // zoom guides
  let guide = (paint: c.grey2, thickness: .6pt, dash: "dashed")
  line((wx + (hn + 1) * tw, wy - hk * th), (vx - 6, zy + 8), stroke: guide)
  line((wx + (hn + 1) * tw, wy - (hk + 1) * th), (vx - 6, zyy - zh - 2), stroke: guide)
})

// ============================================================================
// Results
// ============================================================================

// Median latency in µs on an RTX A6000, N = 4096, K = 14336, FP16:
// (kernel, default config, autotuned). `none` rows are group headings.
#let gemv-results = (
  ("Thread view", none, none),
  ("thread_naive", 1709.056, 817.152),
  ("thread_naive_split_k", 614.400, 181.248),
  ("thread_coalesced_naive_split_k", 169.984, 169.984),
  ("thread_split_k", 606.208, 168.960),
  ("thread_coalesced_split_k", 167.936, 166.912),
  ("thread_vectorized_split_k", 166.912, 166.816),
  ("thread_tvm_reduce_split_k", 165.888, 165.888),
  ("thread_shared_memory_split_k", 175.840, 171.008),
  ("thread_intra_block_split_k", 281.600, 210.944),
  ("Block view", none, none),
  ("block_naive", 319.488, 171.008),
  ("block_split_k", 171.008, 169.984),
  ("block_split_k_v2", 174.080, 172.032),
  ("block_pipelined", 201.728, 166.912),
  ("block_alloc_reducer", 215.040, 169.984),
)
// Bytes of matrix, vector and output in FP16.
#let gemv-bytes = (4096 * 14336 + 14336 + 4096) * 2
#let gb-per-s(us) = gemv-bytes / us / 1e3

/// One decimal, also for whole numbers: 170 -> "170.0".
#let fmt1(v) = { let s = str(calc.round(v, digits: 1)); if s.contains(".") { s } else { s + ".0" } }

/// Algorithmic bandwidth of every kernel, default config and autotuned,
/// against the A6000's 768 GB/s and torch.compile.
#let fig-results() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, s) = (160, 300 / 800)
  let px(v) = x0 + v * s
  let rh = 17
  // legend
  legend(x0, 22, "default config", box-swatch(x0, 22, c.grey2))
  legend(x0 + 100, 22, "autotuned", box-swatch(x0 + 100, 22, c.blue))
  let y = 0
  let rows = ()
  for (name, d, t) in gemv-results {
    if d == none {
      y -= 4
      rows.push((y, name, none, none))
      y -= 14
    } else {
      rows.push((y, name, d, t))
      y -= rh
    }
  }
  let bottom = y + 2
  for v in (0, 200, 400, 600, 800) {
    line((px(v), 8), (px(v), bottom), stroke: if v == 0 { .6pt + c.line } else { grid-stroke })
    content((px(v), bottom - 4), txt(str(v), size: 7pt), anchor: "north")
  }
  content((px(400), bottom - 16), txt("GB/s: bytes of W, x and y divided by the time", size: 7pt), anchor: "north")
  // limits
  line((px(768), 8), (px(768), bottom), stroke: (paint: c.ink, thickness: .8pt, dash: "dashed"))
  content((px(768) + 3, 8), txt("768 peak", size: 7pt, fill: c.ink), anchor: "south-west")
  let torch = gb-per-s(168.96)
  line((px(torch), 8), (px(torch), bottom), stroke: (paint: c.orange, thickness: .8pt, dash: "dashed"))
  content((px(torch) - 3, 8), txt("torch.compile", size: 7pt, fill: c.orange), anchor: "south-east")
  for (ry, name, d, t) in rows {
    if d == none {
      content((x0 - 8, ry - 5), txt(name, size: 7.5pt, fill: c.ink, weight: 700), anchor: "east")
    } else {
      content((x0 - 8, ry - 7), txt(name, size: 7pt), anchor: "east")
      rect((x0, ry - 1), (px(gb-per-s(d)), ry - 6), fill: c.grey2, stroke: none)
      rect((x0, ry - 7), (px(gb-per-s(t)), ry - 13), fill: c.blue, stroke: none)
      let lab = if d == t { fmt1(t) + " µs" } else { fmt1(d) + " → " + fmt1(t) + " µs" }
      content((px(800) + 10, ry - 7), txt(lab, size: 7pt, fill: c.ink), anchor: "west")
    }
  }
})
