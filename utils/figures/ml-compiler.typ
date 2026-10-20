// Detailed figures for content/posts/ml-systems/ml-compilers/overview.typ, drawn with cetz.
// Each `fig-*` function returns one canvas; coordinates are in points
// (1pt per unit, y grows upward) and every figure stays under ~560pt wide,
// so it renders at true scale in the 760px column.

#import "/utils/cetz.typ" as cetz
#import "/templates/base.typ": palette

// ============================================================================
// Style
// ============================================================================

#let c = (
  ink: palette.ink, muted: palette.muted, blue: palette.blue, orange: palette.orange,
  teal: palette.hint-emphasis, danger: palette.danger,
  line: rgb("#7D8987"), hair: rgb("#B7C5C5"), panel: rgb("#F5F7F6"),
  blue1: rgb("#E1ECEF"), blue2: rgb("#A3C3CE"),
  orange1: rgb("#FBECE3"), orange2: rgb("#EBB39B"),
  teal1: rgb("#DCEAE6"), teal2: rgb("#95BFB6"),
  grey1: rgb("#ECEFEE"), grey2: rgb("#C9D0CE"),
)

#let txt(body, size: 8pt, fill: c.muted, weight: 400, style: "normal") = text(
  size: size, fill: fill, weight: weight, style: style, body,
)
#let tag(body, fill: c.orange) = text(size: 7.5pt, weight: 600, tracking: .8pt, fill: fill, upper(body))

/// A line with an arrow head (unless `head: false`).
#let arrow(..pts, color: c.line, w: .7pt, dash: none, head: true) = cetz.draw.line(
  ..pts,
  stroke: (paint: color, thickness: w, dash: dash),
  mark: if head { (end: "stealth", fill: color, scale: .5) } else { none },
)

/// A curved arrow from `a` to `b` with control points `c1`, `c2`.
#let curve-arrow(a, b, c1, c2, color: c.line, w: .7pt, dash: none) = cetz.draw.bezier(
  a, b, c1, c2,
  stroke: (paint: color, thickness: w, dash: dash),
  mark: (end: "stealth", fill: color, scale: .5),
)

#let pill-tones = (
  blue: (fill: white, stroke: .7pt + c.blue, text: c.ink),
  orange: (fill: c.orange1, stroke: .7pt + c.orange, text: c.ink),
  teal: (fill: c.teal1, stroke: .7pt + c.teal, text: c.ink),
  dark: (fill: c.ink, stroke: .7pt + c.ink, text: white),
  pale: (fill: c.blue1, stroke: .7pt + c.blue, text: c.ink),
  muted: (fill: white, stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed"), text: c.muted),
)

/// A rounded op / step label; anchors come from its bounding box.
#let pill(pos, body, name: none, tone: "blue", anchor: "center", size: 8pt) = {
  let t = pill-tones.at(tone)
  cetz.draw.content(pos, name: name, anchor: anchor, box(
    fill: t.fill, stroke: t.stroke, radius: 7pt, inset: (x: 6pt, y: 3.5pt),
    text(size: size, weight: 600, fill: t.text, body),
  ))
}

/// A rows x cols grid of cells; `o` is the top-left corner, rows grow downward.
#let cells(o, rows, cols, w, h, paint: (r, k) => c.grey1) = {
  import cetz.draw: *
  let (x, y) = o
  for r in range(rows) {
    for k in range(cols) {
      rect((x + k * w, y - r * h), (x + (k + 1) * w, y - (r + 1) * h), fill: paint(r, k), stroke: .5pt + white)
    }
  }
}

// Gantt segments: tone -> (fill, text color).
#let seg-tones = (
  blue1: (c.blue1, c.ink), blue2: (c.blue2, c.ink), blue: (c.blue, white),
  orange: (c.orange, white), orange1: (c.orange1, c.ink),
  teal1: (c.teal1, c.ink), teal2: (c.teal2, c.ink), grey: (c.grey1, c.muted), ink: (c.ink, white),
)

/// A bar from x0 to x1 whose top edge is at y.
#let seg(x0, x1, y, tone, body: none, h: 16) = {
  import cetz.draw: *
  let (fill, ink) = seg-tones.at(tone)
  rect((x0, y), (x1, y - h), fill: fill, stroke: .5pt + white)
  if body != none { content(((x0 + x1) / 2, y - h / 2), txt(body, size: 7pt, fill: ink, weight: 600)) }
}

/// A legend entry: swatch drawn by `swatch` at (x, y), label to its right.
#let legend(x, y, body, swatch) = {
  import cetz.draw: *
  swatch
  content((x + 16, y), txt(body), anchor: "west")
}
#let box-swatch(x, y, fill, stroke: none) = cetz.draw.rect((x, y + 4), (x + 11, y - 4), fill: fill, stroke: stroke)
#let line-swatch(x, y, color, dash: none, w: 1pt) = arrow((x, y), (x + 12, y), color: color, dash: dash, w: w)

// ============================================================================
// IR pipeline: one SiluAndMul through the layers
// ============================================================================

/// Tensor IR: slices become IndexMaps, silu decomposes into elementwise ops.
#let fig-tensor-ir() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  cells((0, 0), 1, 16, 30, 12, paint: (r, k) => if k < 8 { c.blue1 } else { c.orange1 })
  content((-6, -6), txt("x", size: 9pt, fill: c.ink, weight: 700), anchor: "east")
  content((120, 4), txt("k ∈ [0, 2048)", fill: c.blue), anchor: "south")
  content((360, 4), txt("k ∈ [2048, 4096)", fill: c.orange), anchor: "south")

  // silu, decomposed
  rect((6, -46), (426, -82), stroke: (paint: c.blue2, thickness: .7pt, dash: "dashed"), radius: 4)
  content((12, -86), txt("silu(x) = x · σ(x)", fill: c.blue, weight: 600), anchor: "north-west")
  let y = -68
  pill((40, y), "neg", name: "neg")
  pill((118, y), "exp", name: "exp")
  pill((200, y), "add 1.0", name: "add")
  pill((292, y), "reciprocal", name: "rcp")
  pill((388, y), "multiply", name: "mul1")
  for (a, b) in (("neg", "exp"), ("exp", "add"), ("add", "rcp"), ("rcp", "mul1")) {
    arrow(a + ".east", b + ".west")
  }
  pill((470, -118), "multiply", name: "mul2", tone: "orange")
  arrow("mul1.south", (388, -118), "mul2.west")

  // IndexMaps read x in place: no slice copies
  let im = (color: c.teal, dash: "dashed")
  arrow((40, -12), "neg.north", ..im)
  content((46, -24), txt("x[i, j, k]", fill: c.teal), anchor: "west")
  arrow((214, -12), (214, -28), (388, -28), "mul1.north", ..im)
  arrow((470, -12), "mul2.north", ..im)
  content((476, -36), txt("x[i, j, k + 2048]", fill: c.teal), anchor: "west")

  cells((422, -146), 1, 8, 12, 10, paint: (r, k) => c.teal1)
  arrow("mul2.south", (470, -146))
  content((470, -160), txt("mul · f32[1, 32, 2048]", fill: c.ink), anchor: "north")

  legend(0, -152, "IndexMap", line-swatch(0, -152, c.teal, dash: "dashed"))
  legend(96, -152, "Elementwise", box-swatch(96, -152, white, stroke: .7pt + c.blue))
  legend(212, -152, "Reduction（本例无）", box-swatch(212, -152, white, stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed")))
})

/// Loop IR: one iteration reads two elements of x and writes one output.
#let fig-loop-ir() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, r0, k0) = (8, 8, 2, 5)
  cells((0, 0), 6, 32, w, h, paint: (r, k) => if r == r0 and k == k0 { c.blue } else if r == r0 and k == k0 + 16 {
    c.orange
  } else if k < 16 { c.blue1 } else { c.orange1 })
  cells((410, 0), 6, 16, w, h, paint: (r, k) => if r == r0 and k == k0 { c.teal } else { c.teal1 })
  let row = (paint: c.ink, thickness: .6pt, dash: "dotted")
  rect((-2, -r0 * h), (258, -(r0 + 1) * h), stroke: row)
  rect((408, -r0 * h), (540, -(r0 + 1) * h), stroke: row)
  content((-6, -20), txt("a0", fill: c.ink), anchor: "east")
  content((64, -52), txt("chunk_0", fill: c.blue), anchor: "north")
  content((192, -52), txt("chunk_1", fill: c.orange), anchor: "north")
  content((474, -52), txt("mul[0, a0, a1]", fill: c.teal), anchor: "north")

  // fused loop body: two loads -> elementwise chain -> one store
  rect((298, -4), (374, -44), radius: 4, fill: c.panel, stroke: .5pt + c.hair)
  content((336, 2), txt("for a0, a1:", fill: c.ink), anchor: "south")
  let dot(p, fill) = circle(p, radius: 3.2, fill: fill, stroke: none)
  let chain = ((322, -16), (334, -16), (346, -16), (358, -24))
  line((308, -16), ..chain, stroke: .6pt + c.line)
  line((308, -32), (358, -24), stroke: .6pt + c.line)
  dot((308, -16), c.blue)
  dot((308, -32), c.orange)
  for p in chain.slice(0, 3) { dot(p, c.blue2) }
  dot((358, -24), c.teal)
  content((336, -48), txt("无中间 tensor"), anchor: "north")

  let pick = (k0 + .5) * w
  curve-arrow((pick, -16), (298, -14), (pick, 26), (262, 26), color: c.blue)
  curve-arrow((pick + 128, -16), (298, -32), (pick + 128, 14), (276, 4), color: c.orange)
  curve-arrow((374, -24), (410 + pick, -16), (398, -24), (410 + pick, 24), color: c.teal)
})

/// Tile IR: each worker owns four consecutive positions (unroll x4).
#let fig-tile-ir() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h) = (10.5, 12)
  let hot(k) = calc.rem(k, 24) >= 4 and calc.rem(k, 24) < 8
  cells((0, 0), 1, 48, w, h, paint: (r, k) => if k < 24 { if hot(k) { c.blue } else { c.blue1 } } else {
    if hot(k) { c.orange } else { c.orange1 }
  })
  for g in range(13) { line((g * 4 * w, 3), (g * 4 * w, -h - 3), stroke: (if g == 6 { 1pt } else { .6pt }) + c.line) }
  content((126, 6), txt("chunk_0 · x[0, a0, 4·a1 + u]", fill: c.blue), anchor: "south")
  content((378, 6), txt("chunk_1 · x[0, a0, 4·a1 + u + 2048]", fill: c.orange), anchor: "south")

  let oy = -74
  cells((0, oy), 1, 24, w, h, paint: (r, k) => if hot(k) { c.teal } else { c.teal1 })
  for g in range(7) { line((g * 4 * w, oy + 3), (g * 4 * w, oy - h - 3), stroke: .6pt + c.line) }
  content((258, oy - 6), txt("mul[0, a0, ·]", fill: c.teal), anchor: "west")
  for u in range(4) {
    let x = (4 + u + .5) * w
    arrow((x, -h), (x, oy), color: c.blue, w: .6pt)
    arrow((x + 24 * w, -h), (x, oy), color: c.orange, w: .6pt)
  }

  // zoom into the worker: four independent lanes
  let (zx, zy, zw) = (20, -108, 34)
  line((4 * w, oy - h), (zx, zy), stroke: (paint: c.grey2, thickness: .5pt, dash: "dashed"))
  line((8 * w, oy - h), (zx + 4 * zw, zy), stroke: (paint: c.grey2, thickness: .5pt, dash: "dashed"))
  for u in range(4) {
    rect((zx + u * zw, zy), (zx + (u + 1) * zw, zy - 18), fill: c.teal, stroke: .8pt + white)
    content((zx + (u + .5) * zw, zy - 9), txt("u" + str(u), fill: white, weight: 600))
  }
  content((zx + 2 * zw, zy - 24), txt("worker a1 = 1 · 4 个独立 lane", fill: c.ink), anchor: "north")
})

/// Kernel IR / CUDA: 16384 workers -> 64 blocks x 256 threads -> float4 store.
#let fig-kernel-map() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (bw, bh) = (100, 4.5)
  cells((0, 0), 32, 2, bw, bh, paint: (r, k) => if r == 2 and k == 1 { c.orange } else if calc.rem(r, 2) == 0 {
    c.blue1
  } else { rgb("#D2E2E7") })
  content((50, 4), txt("a1 0–255"), anchor: "south")
  content((150, 4), txt("a1 256–511"), anchor: "south")
  content((-4, -2), txt("a0 = 0"), anchor: "east")
  content((-4, -142), txt("31"), anchor: "east")
  content((100, -150), txt("64 blocks × 256 threads = 16384 workers", fill: c.ink), anchor: "north")

  // zoom: block 5 = 256 threads
  let (zx, tw) = (250, 7)
  let zoom = (paint: c.grey2, thickness: .5pt, dash: "dashed")
  line((200, -2 * bh), (zx, 0), stroke: zoom)
  line((200, -3 * bh), (zx, -16 * tw), stroke: zoom)
  cells((zx, 0), 16, 16, tw, tw, paint: (r, k) => if r == 2 and k == 5 { c.orange } else { c.orange1 })
  content((zx + 56, 4), txt("blockIdx.x = 5", fill: c.orange, weight: 600), anchor: "south")
  content((zx + 56, -116), txt("threadIdx.x = 0…255"), anchor: "north")

  // thread 37 -> four consecutive outputs
  let (ox, oy) = (400, -11)
  arrow((zx + 5.5 * tw, -2.5 * tw), (ox, -2.5 * tw), color: c.ink)
  for u in range(4) {
    rect((ox + u * 18, oy), (ox + (u + 1) * 18, oy - 14), fill: c.teal, stroke: .8pt + white)
  }
  content((ox + 36, oy + 4), tag("float4 store", fill: c.teal), anchor: "south")
  content((ox + 36, oy - 18), txt("mul[2, 1172:1176]", fill: c.teal), anchor: "north")
  let lines = ("gid = 5·256 + 37 = 1317", "a0  = 1317 / 512 = 2", "a1  = 1317 % 512 = 293")
  for (i, l) in lines.enumerate() {
    content((ox - 6, -52 - i * 13), txt(l, fill: c.ink), anchor: "north-west")
  }
})

// ============================================================================
// Eager mode
// ============================================================================

/// The dispatcher walks the dispatch keys of `a` from high to low priority.
#let fig-dispatch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let keys = (
    ("Autocast", false), ("Autograd", true), ("ADInplaceOrView", true), ("CUDA", true), ("CPU", false),
  )
  let (bh, px) = (28, 240)
  content((0, 6), tag("Dispatch key · 高 → 低"), anchor: "south-west")
  content((150, 6), txt("a 的 keyset"), anchor: "south")
  for (i, (k, on)) in keys.enumerate() {
    let y = -i * bh
    rect((0, y), (480, y - bh), fill: if calc.rem(i, 2) == 0 { c.panel } else { white }, stroke: none)
    content((8, y - bh / 2), txt(k, size: 8.5pt, fill: if on { c.ink } else { c.muted }, weight: 600), anchor: "west")
    rect((145, y - bh / 2 + 5), (155, y - bh / 2 - 5), fill: if on { c.ink } else { white }, stroke: .7pt + if on { c.ink } else { c.grey2 })
  }
  line((0, -5 * bh), (480, -5 * bh), stroke: .5pt + c.hair)

  // the call: stops at Autograd and CUDA, falls through ADInplaceOrView
  pill((px, 12), "torch.mul(a, b)", name: "call", tone: "dark")
  let mid(i) = -i * bh - bh / 2
  arrow("call.south", (px, mid(3) + 5), color: c.ink, w: 1pt)
  circle((px, mid(0)), radius: 3.5, fill: white, stroke: .7pt + c.grey2)
  content((px + 10, mid(0)), txt("未启用，跳过"), anchor: "west")
  circle((px, mid(1)), radius: 4, fill: c.orange, stroke: none)
  arrow((px + 5, mid(1)), (300, mid(1)), color: c.orange)
  pill((302, mid(1)), "grad_fn = MulBackward0", anchor: "west", tone: "orange")
  content((px - 6, mid(1) - 13), txt("redispatch", style: "italic"), anchor: "east")
  circle((px, mid(2)), radius: 3.5, fill: white, stroke: .7pt + c.ink)
  content((px + 10, mid(2)), txt("fallthrough"), anchor: "west")
  circle((px, mid(3)), radius: 4, fill: c.orange, stroke: none)
  arrow((px + 5, mid(3)), (300, mid(3)), color: c.orange)
  pill((302, mid(3)), "CUDA mul kernel", anchor: "west", name: "k", tone: "orange")
  arrow("k.east", (430, mid(3)), color: c.orange)
  // a small GPU chip
  rect((432, mid(3) + 9), (458, mid(3) - 9), fill: c.ink, radius: 2, stroke: none)
  for d in (-5, 0, 5) {
    line((436 + 9 + d, mid(3) + 9), (436 + 9 + d, mid(3) + 12), stroke: .8pt + c.ink)
    line((436 + 9 + d, mid(3) - 9), (436 + 9 + d, mid(3) - 12), stroke: .8pt + c.ink)
  }
  content((445, mid(3)), txt("GPU", size: 6pt, fill: white, weight: 700))
})

/// HBM traffic: eager writes the silu result back to memory; the fused kernel doesn't.
#let fig-eager-traffic() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let slab(x, name, fill, stroke) = {
    rect((x - 20, -101), (x + 20, -115), fill: fill, stroke: .7pt + stroke, radius: 2)
    content((x, -108), txt(name, size: 7pt, fill: c.ink, weight: 600))
  }
  let kernel(x0, x1, body) = {
    rect((x0, -16), (x1, -40), fill: c.blue1, stroke: .7pt + c.blue, radius: 3)
    content(((x0 + x1) / 2, -28), txt(body, size: 7.5pt, fill: c.ink, weight: 600))
  }
  let hbm(ox) = {
    rect((ox, -92), (ox + 250, -124), fill: c.panel, stroke: .5pt + c.hair)
    content((ox + 246, -121), txt("HBM", size: 7pt), anchor: "south-east")
  }
  let read(a, b) = arrow(a, b, color: c.line)
  let write(a, b) = arrow(a, b, color: c.orange)
  let counter(ox, fills, label) = {
    for (i, f) in fills.enumerate() { rect((ox + i * 13, -134), (ox + i * 13 + 10, -144), fill: f, stroke: none) }
    content((ox + fills.len() * 13 + 4, -139), txt(label, fill: c.ink, weight: 600), anchor: "west")
  }

  // eager: silu kernel + mul kernel, tmp round-trips through HBM
  content((0, 4), tag("Eager · 2 次 launch"), anchor: "south-west")
  kernel(28, 92, "silu")
  kernel(158, 222, "mul")
  hbm(0)
  slab(40, "left", c.blue1, c.blue)
  slab(105, "tmp", c.grey1, c.line)
  slab(170, "right", c.orange1, c.orange)
  slab(226, "out", c.teal1, c.teal)
  read((40, -101), (52, -40))
  write((68, -40), (100, -101))
  read((110, -101), (176, -40))
  read((170, -101), (190, -40))
  write((204, -40), (224, -101))
  counter(0, (c.blue1, c.grey2, c.grey2, c.orange1, c.teal1), "5 × N")

  // compiled: one fused kernel, three transfers
  let ox = 300
  content((ox, 4), tag("torch.compile · 1 次 launch"), anchor: "south-west")
  kernel(ox + 50, ox + 200, "fused silu · mul")
  content((ox + 125, -12), txt("中间值留在 register"), anchor: "south")
  hbm(ox)
  slab(ox + 40, "left", c.blue1, c.blue)
  slab(ox + 125, "right", c.orange1, c.orange)
  slab(ox + 210, "out", c.teal1, c.teal)
  read((ox + 40, -101), (ox + 80, -40))
  read((ox + 125, -101), (ox + 125, -40))
  write((ox + 170, -40), (ox + 208, -101))
  counter(ox, (c.blue1, c.orange1, c.teal1), "3 × N")

  legend(380, -160, "read", line-swatch(380, -160, c.line))
  legend(440, -160, "write", line-swatch(440, -160, c.orange))
})

// ============================================================================
// TorchDynamo
// ============================================================================

/// Dynamo's frame hook, guard check and per-code-object cache.
#let fig-dynamo-cache() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  pill((0, 0), "f(x) 被调用", name: "call", tone: "dark")
  pill((0, -46), "eval-frame hook (PEP 523)", name: "hook")
  let (dy, hw, hh) = (-104, 64, 22)
  line((-hw, dy), (0, dy + hh), (hw, dy), (0, dy - hh), close: true, fill: white, stroke: .7pt + c.blue)
  content((0, dy), txt("guards 通过?", size: 8pt, fill: c.ink, weight: 600))
  pill((0, -184), "执行 compiled code", name: "run", tone: "orange")
  arrow("call.south", "hook.north")
  arrow("hook.south", (0, dy + hh))
  arrow((0, dy - hh), "run.north")
  content((6, -146), txt("hit", style: "italic"), anchor: "west")

  pill((220, dy), "symbolic 解释 bytecode", name: "trace")
  pill((220, -144), "FX Graph + guards", name: "graph")
  pill((220, -184), "backend 编译 (Inductor)", name: "comp")
  arrow((hw, dy), "trace.west")
  content((100, dy + 3), txt("miss", style: "italic"), anchor: "south")
  arrow("trace.south", "graph.north")
  arrow("graph.south", "comp.north")
  arrow("comp.west", "run.east")

  // cache entries hang off the code object
  let card(x, y, fill, body) = {
    rect((x, y), (x + 150, y - 22), fill: fill, stroke: .5pt + c.hair)
    line((x + 1.25, y), (x + 1.25, y - 22), stroke: 2.5pt + c.orange)
    if body != none { content((x + 9, y - 11), txt(body, fill: c.ink), anchor: "west") }
  }
  card(150, -25, c.panel, none)
  card(145, -30, white, "x: f16[4, 256] · cuda:1")
  content((145, -20), tag("cache · f.__code__"), anchor: "south-west")
  arrow((hw / 2, dy + hh / 2), (145, -46), color: c.blue, dash: "dashed")
  content((90, -66), txt("查找", style: "italic"), anchor: "east")
  arrow("comp.east", (330, -184), (330, -41), (295, -41), color: c.orange)
  content((334, -112), txt("写入新 entry", style: "italic"), anchor: "west")
})

/// A graph break splits one function into compiled graphs and CPython code.
#let fig-graph-break() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = 16
  let part(k) = if k < 12 { 0 } else if k < 16 { 1 } else { 2 }
  cells((0, 0), 1, 30, w, 14, paint: (r, k) => (c.blue1, c.orange1, c.blue1).at(part(k)))
  content((-6, -7), txt("bytecode", fill: c.ink), anchor: "east")
  content((96, 4), txt("y = x.sin()", fill: c.ink), anchor: "south")
  content((224, 4), txt("print(y)", fill: c.orange), anchor: "south")
  content((368, 4), txt("return y.cos()", fill: c.ink), anchor: "south")
  content((224, -20), tag("graph break"), anchor: "north")

  let y = -64
  pill((96, y), "graph 1 · compiled", name: "g1")
  pill((224, y), "CPython", name: "py", tone: "muted")
  pill((368, y), "__resume_at_N → graph 2", name: "g2")
  for x in (96, 368) { line((x, -14), (x, y + 9), stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed")) }
  line((224, -32), (224, y + 9), stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed"))
  arrow("g1.east", "py.west", color: c.ink)
  arrow("py.east", "g2.west", color: c.ink)
  content((96, y - 14), txt("Dynamo 捕获", style: "italic"), anchor: "north")
  content((368, y - 14), txt("新 frame，Dynamo 再次捕获", style: "italic"), anchor: "north")
})

// ============================================================================
// Compile timing, lazy execution
// ============================================================================

/// JIT compiles on the first request (and on guard failure); AOT before deploy.
#let fig-jit-aot() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (ya, yb, dx) = (0, -50, 170)
  let tri(x, y, fill: c.ink) = line((x - 3.5, y + 7), (x + 3.5, y + 7), (x, y + 1), close: true, fill: fill, stroke: none)
  let reqs = (180, 350, 375, 420, 510)

  content((0, ya + 6), tag("torch.compile", fill: c.ink), anchor: "south-west")
  for x in reqs { tri(x, ya) }
  content((420, ya + 10), txt("新 shape", fill: c.ink), anchor: "south")
  seg(180, 215, ya, "blue2", body: "Dynamo")
  seg(215, 280, ya, "blue", body: "Inductor")
  seg(280, 325, ya, "teal2", body: "autotune")
  seg(325, 333, ya, "orange")
  seg(350, 358, ya, "orange")
  seg(375, 383, ya, "orange")
  seg(420, 436, ya, "blue2")
  seg(436, 470, ya, "blue")
  seg(470, 478, ya, "orange")
  seg(510, 518, ya, "orange")
  content((452, ya - 20), txt("guard 失败 → recompile", style: "italic"), anchor: "north")

  content((0, yb + 6), tag(".aot_compile()", fill: c.ink), anchor: "south-west")
  seg(0, 35, yb, "blue2", body: "Dynamo")
  seg(35, 100, yb, "blue", body: "Inductor")
  seg(100, 145, yb, "teal2", body: "autotune")
  seg(145, 158, yb, "teal1")
  seg(172, 180, yb, "teal1")
  for x in reqs { tri(x, yb) }
  for x in (182, 350, 375, 510) { seg(x, x + 8, yb, "orange") }
  let (xx, xy) = (424, yb - 8)
  line((xx - 5, xy + 5), (xx + 5, xy - 5), stroke: 1.4pt + c.danger)
  line((xx - 5, xy - 5), (xx + 5, xy + 5), stroke: 1.4pt + c.danger)
  content((452, yb - 20), txt("超出 artifact 的 guards", style: "italic"), anchor: "north")

  line((dx, ya + 22), (dx, yb - 22), stroke: (paint: c.orange, thickness: .8pt, dash: "dashed"))
  content((dx, ya + 24), tag("deploy"), anchor: "south")
  arrow((0, -94), (540, -94), color: c.grey2)
  content((540, -98), txt("time"), anchor: "north-east")
  legend(0, -110, "执行", box-swatch(0, -110, c.orange))
  legend(60, -110, "保存 / 加载 artifact", box-swatch(60, -110, c.teal1))
  legend(200, -110, "请求", line((200, -106), (211, -106), (205.5, -113), close: true, fill: c.ink, stroke: none))
})

/// Eager runs each op immediately; lazy grows a graph and runs it on realize().
#let fig-lazy() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let lane(y, body) = content((76, y - 7), txt(body, fill: c.ink), anchor: "east")
  let s = 2
  let at(x) = 84 + x * s

  content((0, 8), tag("Eager"), anchor: "south-west")
  lane(0, "Python")
  lane(-22, "GPU")
  for (i, op) in ("add", "relu", "mul").enumerate() {
    let x = 10 + i * 70
    seg(at(x), at(x + 40), 0, "blue1", body: op, h: 14)
    seg(at(x + 42), at(x + 64), -22, "orange", body: op, h: 14)
    arrow((at(x + 41), -14), (at(x + 43), -22), color: c.grey2, w: .5pt)
  }

  let y = -72
  content((0, y + 8), tag("Lazy"), anchor: "south-west")
  lane(y, "Python")
  lane(y - 22, "GPU")
  for (i, op) in ("add", "relu", "mul").enumerate() {
    let x = 10 + i * 24
    seg(at(x), at(x + 22), y, "blue1", body: op, h: 14)
    // the graph after this op: i + 1 nodes
    let gx = at(x + 11) - i * 5
    for j in range(i + 1) {
      if j > 0 { line((gx + (j - 1) * 10, y + 12), (gx + j * 10, y + 12), stroke: .6pt + c.blue) }
      circle((gx + j * 10, y + 12), radius: 2.6, fill: c.blue2, stroke: none)
    }
  }
  seg(at(86), at(118), y, "ink", body: "realize()", h: 14)
  seg(at(118), at(150), y, "blue2", body: "schedule", h: 14)
  seg(at(152), at(196), y - 22, "orange", body: "fused kernel", h: 14)
  arrow((at(151), y - 14), (at(153), y - 22), color: c.grey2, w: .5pt)
  content((at(214), -40), txt("3 次 launch", style: "italic"), anchor: "north-east")
  content((at(196), y - 40), txt("1 次 launch", style: "italic"), anchor: "north-east")
})

/// TinyJit: run, then capture, then replay without Python or scheduling.
#let fig-tinyjit() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 2.4
  let at(x) = 60 + x * s
  let rows = ("call 1", "call 2", "call 3+")
  for (i, r) in rows.enumerate() { content((52, -i * 30 - 8), txt(r, fill: c.ink), anchor: "east") }
  for i in range(2) {
    let y = -i * 30
    seg(at(0), at(60), y, "blue1", body: "Python")
    seg(at(60), at(120), y, "blue2", body: "schedule")
    seg(at(120), at(170), y, "orange", body: "kernels")
  }
  rect((at(60) - 2, -30 + 3), (at(170) + 2, -30 - 19), stroke: (paint: c.teal, thickness: .9pt, dash: "dashed"), radius: 3)
  content((at(170) + 8, -38), txt("capture", fill: c.teal, weight: 600), anchor: "west")
  let y = -60
  rect((at(0), y), (at(120), y - 16), fill: none, stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed"))
  content((at(60), y - 8), txt("跳过"), anchor: "center")
  seg(at(120), at(170), y, "orange", body: "replay")
})

// ============================================================================
// llama.cpp
// ============================================================================

/// ggml_gallocr: tensors reuse offsets once their last consumer has run.
#let fig-gallocr() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (sx, sy) = (44, .8)
  let tensors = (
    ("t0", 0, 3, 0, 30, c.blue1, c.blue),
    ("t1", 1, 4, 30, 40, c.orange1, c.orange),
    ("t2", 3, 6, 0, 30, c.teal1, c.teal),
    ("t3", 4, 7, 30, 40, c.blue1, c.blue),
    ("t4", 5, 8, 70, 25, c.orange1, c.orange),
    ("t5", 6, 8, 0, 30, c.teal1, c.teal),
  )
  for (name, a, b, off, size, fill, ink) in tensors {
    rect((a * sx + 1, off * sy + 1), (b * sx - 1, (off + size) * sy - 1), fill: fill, stroke: .7pt + ink, radius: 2)
    content(((a + b) / 2 * sx, (off + size / 2) * sy), txt(name, fill: c.ink, weight: 600))
  }
  arrow((0, 0), (8 * sx + 12, 0), color: c.line)
  arrow((0, 0), (0, 108), color: c.line)
  for i in range(8) { content(((i + .5) * sx, -4), txt("n" + str(i)), anchor: "north") }
  content((8 * sx + 12, -16), txt("执行顺序"), anchor: "north-east")
  content((-4, 104), txt("offset"), anchor: "east")
  let peak = 95 * sy
  line((0, peak), (8 * sx, peak), stroke: (paint: c.ink, thickness: .6pt, dash: "dotted"))
  content((8 * sx + 4, peak), txt("peak", fill: c.ink), anchor: "west")
  let reserve = 112 * sy
  line((0, reserve), (8 * sx, reserve), stroke: (paint: c.orange, thickness: .8pt, dash: "dashed"))
  content((8 * sx + 4, reserve), txt("reserve（worst-case graph）", fill: c.orange), anchor: "west")

  // naive: every tensor gets its own buffer; planned: the peak
  let bx = 480
  let y = 0
  for (_, _, _, _, size, fill, ink) in tensors {
    rect((bx, y * sy), (bx + 20, (y + size) * sy), fill: fill, stroke: .5pt + white)
    y += size
  }
  rect((bx + 40, 0), (bx + 60, peak), fill: c.grey2, stroke: none)
  content((bx + 10, -4), txt("各自分配"), anchor: "north")
  content((bx + 50, -4), txt("复用"), anchor: "north")
  content((bx + 10, y * sy + 2), txt("195", fill: c.ink, weight: 600), anchor: "south")
  content((bx + 50, peak + 2), txt("95", fill: c.ink, weight: 600), anchor: "south")
})
