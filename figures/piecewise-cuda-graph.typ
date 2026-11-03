// Figures for content/posts/ml-systems/ml-compilers/piecewise-cuda-graph.typ,
// drawn with cetz. The model is the simplified 3-Attention Transformer used
// in the post; timings in the launch figure are illustrative, not measured.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, curve-arrow, legend, pill, tag, txt

// Op tones: CUDA-Graph-safe ops are blue, Attention (eager) is orange.
#let _op(x0, x1, y, h, body, attn: false) = {
  import cetz.draw: *
  let (fill, stroke) = if attn { (c.orange1, c.orange) } else { (c.blue1, c.blue) }
  rect((x0, y), (x1, y - h), fill: fill, stroke: .7pt + stroke, radius: 3)
  content(((x0 + x1) / 2, y - h / 2), align(center, txt(body, size: 7pt, fill: c.ink, weight: 600)))
}

// ============================================================================
// Partitioning
// ============================================================================

/// One op sequence, bracketed by layer above and by piece below: pieces
/// straddle layer boundaries because the cut follows Attention.
#let fig-partition() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let ops = (
    ("Embed", false), ("Norm\nQKV", false), ("Attn0", true), ("O-proj\nMLP", false),
    ("Norm\nQKV", false), ("Attn1", true), ("O-proj\nMLP", false),
    ("Norm\nQKV", false), ("Attn2", true), ("O-proj\nMLP", false), ("Final\nNorm", false),
  )
  let (w, g, h) = (44, 5, 28)
  let x0(i) = i * (w + g)
  let x1(i) = x0(i) + w
  let mid(a, b) = (x0(a) + x1(b)) / 2
  for (i, (body, attn)) in ops.enumerate() { _op(x0(i), x1(i), 0, h, body, attn: attn) }

  // layer l = Norm·QKV, Attn, O-proj·MLP
  let ya = 10
  for l in range(3) {
    let (a, b) = (1 + 3 * l, 3 + 3 * l)
    line((x0(a), ya - 4), (x0(a), ya), (x1(b), ya), (x1(b), ya - 4), stroke: .7pt + c.muted)
    content((mid(a, b), ya + 3), txt("Layer " + str(l), fill: c.muted, weight: 600), anchor: "south")
  }
  content((mid(0, 0), ya + 3), tag("按 layer", fill: c.muted), anchor: "south")

  // pieces: the ops between two Attentions
  let yb = -h - 10
  for (j, (a, b)) in ((0, 1), (3, 4), (6, 7), (9, 10)).enumerate() {
    line((x0(a), yb + 4), (x0(a), yb), (x1(b), yb), (x1(b), yb + 4), stroke: .7pt + c.blue)
    content((mid(a, b), yb - 3), align(center, {
      txt("piece " + str(j), fill: c.blue, weight: 600)
      linebreak()
      txt("CUDA Graph", size: 6.5pt)
    }), anchor: "north")
  }
  for i in (2, 5, 8) {
    content((mid(i, i), yb - 3), align(center, {
      txt("boundary", fill: c.orange, weight: 600)
      linebreak()
      txt("eager", size: 6.5pt, fill: c.orange)
    }), anchor: "north")
  }
  content((x1(10), -h - 46), txt("3 个 Attention → 3 个 eager boundary + 4 个 safe piece", style: "italic"), anchor: "north-east")
})

// ============================================================================
// Launch timeline
// ============================================================================

/// CPU launches vs GPU execution for the ops around one Attention, in a
/// launch-bound regime (small decode batch): each kernel is shorter on the
/// GPU than its launch on the CPU.
#let fig-launch-timeline() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // launch cost, graph launch cost, safe kernel, attention kernel (time units)
  let (L, G, ds, da) = (18, 22, 6, 8)
  let sx = 2.2
  let t0 = 86
  let X(t) = t0 + t * sx
  let s = (ds, false)
  let a = (da, true)
  // CPU items: ("k", kernels) is one eager launch, ("g", kernels) one graph replay
  let modes = (
    ("Eager", (("k", (s,)),) * 4 + (("k", (a,)),) * 2 + (("k", (s,)),) * 4),
    ("Piecewise", (("g", (s,) * 4), ("k", (a,)), ("k", (a,)), ("g", (s,) * 4))),
    ("Full", (("g", (s,) * 4 + (a,) * 2 + (s,) * 4),)),
  )
  let lh = 11
  let span = 196
  for (m, (name, items)) in modes.enumerate() {
    let y = -m * 40
    let (yc, yg) = (y, y - lh - 4)
    content((0, y - lh - 2), txt(name, size: 8pt, fill: c.ink, weight: 600), anchor: "west")
    content((t0 - 6, yc - lh / 2), txt("CPU", size: 6.5pt), anchor: "east")
    content((t0 - 6, yg - lh / 2), txt("GPU", size: 6.5pt), anchor: "east")
    rect((X(0), yc), (X(span), yc - lh), fill: c.panel, stroke: none)
    rect((X(0), yg), (X(span), yg - lh), fill: c.panel, stroke: none)

    let (tc, tg) = (0, 0)
    for (kind, ks) in items {
      let cost = if kind == "g" { G } else { L }
      rect((X(tc), yc), (X(tc + cost), yc - lh), fill: if kind == "g" { c.blue } else { c.grey2 }, stroke: .5pt + white)
      tc += cost
      let start = calc.max(tc, tg)
      let first = start
      for (d, attn) in ks {
        rect((X(start), yg), (X(start + d), yg - lh), fill: if attn { c.orange } else { c.blue2 }, stroke: .4pt + white)
        start += d
      }
      if kind == "g" {
        rect((X(first), yg + 1.5), (X(start), yg - lh - 1.5), fill: none, stroke: .7pt + c.blue)
      }
      tg = start
    }
    let n = items.len()
    content((X(tc) + 5, yc - lh / 2), txt(str(n) + " 次 launch", size: 6.5pt, fill: c.ink), anchor: "west")
    line((X(tg), yg + 2), (X(tg), yg - lh - 2), stroke: 1pt + c.ink)
  }

  let ly = -3 * 40 + 4
  legend(t0, ly, "kernel launch", box-swatch(t0, ly, c.grey2))
  legend(t0 + 86, ly, "graph replay", box-swatch(t0 + 86, ly, c.blue))
  legend(t0 + 170, ly, "safe kernel", box-swatch(t0 + 170, ly, c.blue2))
  legend(t0 + 248, ly, "Attention kernel", box-swatch(t0 + 248, ly, c.orange))
  legend(t0 + 344, ly, "GPU 空闲", box-swatch(t0 + 344, ly, c.panel))
})

// ============================================================================
// FX-level split vs Inductor-level partition
// ============================================================================

/// Where the cut happens in each pipeline, and what that does to a fusion
/// that spans the Attention boundary (Attention + output quant).
#let fig-two-paths() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let stages(y, names, cut, prefix) = {
    let xs = (54, 180, 318, 462)
    for (i, body) in names.enumerate() {
      pill((xs.at(i), y), body, name: prefix + str(i), tone: if i == cut { "orange" } else if i == 0 { "dark" } else { "blue" }, size: 7pt)
      if i > 0 { arrow(prefix + str(i - 1) + ".east", prefix + str(i) + ".west") }
    }
  }
  let boundary(x, y, h) = line((x, y + 4), (x, y - h - 4), stroke: (paint: c.orange, thickness: .8pt, dash: "dashed"))
  let (w, h) = (52, 20)

  // FX-level split
  let y = 0
  content((0, y), tag("FX-level split", fill: c.ink), anchor: "south-west")
  stages(y - 16, ([Dynamo FX Graph], [`split_graph()`], [Inductor（逐 piece）], [CUDA Graph capture]), 1, "a")
  let ys = y - 52
  _op(0, w, ys, h, "GEMM")
  _op(60, 112, ys, h, "Attn", attn: true)
  _op(120, 172, ys, h, "Quant")
  _op(180, 232, ys, h, "GEMM")
  boundary(56, ys, h)
  boundary(116, ys, h)
  curve-arrow((86, ys + 1), (146, ys + 1), (100, ys + 14), (132, ys + 14), color: c.danger, dash: "dashed")
  for (dx, dy) in ((3, 3), (3, -3)) {
    line((116 - dx, ys + 11 - dy), (116 + dx, ys + 11 + dy), stroke: 1pt + c.danger)
  }
  content((250, ys - h / 2), txt[Attn 与 Quant 在 Inductor 之前已分属不同 piece， \ 跨边界的 fusion pass 匹配不到完整 pattern], anchor: "west")

  // Inductor-level partition
  let y = -110
  content((0, y), tag("Inductor-level partition", fill: c.ink), anchor: "south-west")
  stages(y - 16, ([Dynamo FX Graph], [Inductor passes · fusion], [按 `cudagraph_unsafe` 分区], [CUDA Graph capture]), 2, "b")
  let ys = y - 52
  _op(0, w, ys, h, "GEMM")
  _op(60, 172, ys, h, "Attn + Quant（fused）", attn: true)
  _op(180, 232, ys, h, "GEMM")
  boundary(56, ys, h)
  boundary(176, ys, h)
  content((250, ys - h / 2), txt[先在完整 graph 上完成 fusion，再切分： \ N 个 unsafe op 留在外面 → N + 1 个 partition], anchor: "west")

  let ly = ys - h - 16
  legend(0, ly, "CUDA-Graph-safe op", box-swatch(0, ly, c.blue1, stroke: .7pt + c.blue))
  legend(120, ly, "unsafe op（eager）", box-swatch(120, ly, c.orange1, stroke: .7pt + c.orange))
  legend(232, ly, "分区边界", line((236, ly + 5), (236, ly - 5), stroke: (paint: c.orange, thickness: .8pt, dash: "dashed")))
})

// ============================================================================
// Graph count
// ============================================================================

/// Piecewise keeps one graph per (piece, capture size); Full keeps one per
/// capture size. At runtime a batch is padded to a capture size and that row
/// is replayed.
#let fig-graph-count() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let sizes = (1, 2, 4, 8)
  let (cw, aw, rh, ch) = (44, 16, 20, 15)
  let px = 52
  let col-x(j) = px + j * (cw + aw)
  let pw = col-x(3) + cw
  let fx0 = pw + 48
  let fx1 = fx0 + 124
  let hl = 2  // highlighted row: num_tokens = 3 → size 4
  let row-y(i) = -i * rh

  content((px, 18), tag("Piecewise", fill: c.blue), anchor: "south-west")
  content((fx0, 18), tag("Full", fill: c.blue), anchor: "south-west")
  for j in range(4) { content((col-x(j) + cw / 2, 4), txt("piece " + str(j), size: 6.5pt), anchor: "south") }
  for j in range(3) { content((col-x(j) + cw + aw / 2, 4), txt("Attn", size: 6.5pt, fill: c.orange), anchor: "south") }

  for (i, s) in sizes.enumerate() {
    let y = row-y(i)
    let on = i == hl
    content((px - 8, y - ch / 2), txt("size " + str(s), size: 7pt, fill: if on { c.orange } else { c.muted }, weight: if on { 600 } else { 400 }), anchor: "east")
    for j in range(4) {
      rect((col-x(j), y), (col-x(j) + cw, y - ch), fill: if on { c.blue2 } else { c.blue1 }, stroke: .6pt + c.blue, radius: 2)
    }
    for j in range(3) {
      let x = col-x(j) + cw + aw / 2
      circle((x, y - ch / 2), radius: 2.2, fill: if on { c.orange } else { white }, stroke: .6pt + c.orange)
    }
    rect((fx0, y), (fx1, y - ch), fill: if on { c.blue2 } else { c.blue1 }, stroke: .6pt + c.blue, radius: 2)
  }
  let yb = row-y(3) - ch
  content((pw / 2 + px / 2, yb - 8), txt([4 个 piece × 4 个 size = *16* 个 graph]), anchor: "north")
  content(((fx0 + fx1) / 2, yb - 8), txt([4 个 size = *4* 个 graph]), anchor: "north")

  // the replayed row
  let y = row-y(hl)
  rect((px - 46, y + 3), (fx1 + 4, y - ch - 3), fill: none, stroke: .8pt + c.orange, radius: 3)
  content((fx1 + 10, y - ch / 2), txt([num_tokens = 3 \ → pad 到 size 4], fill: c.orange), anchor: "west")
})
