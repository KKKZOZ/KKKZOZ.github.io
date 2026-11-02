// Figures for content/posts/ml-systems/ml-compilers/torch-compile-walkthrough.typ,
// drawn with cetz. They follow `fn(a, b, c) = ((a + b) * c.relu()).sum(dim=-1)`
// on f32[4, 128] inputs; names and indices are the ones in the logs.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, cells, curve-arrow, legend, line-swatch, pill, tag, txt

// ============================================================================
// TorchDynamo / AOTAutograd
// ============================================================================

/// The Dynamo FX graph: one pill per node, its target underneath.
#let fig-fx-graph() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let node(pos, name, target, tone, id) = {
    pill(pos, raw(name), name: id, tone: tone, size: 7.5pt)
    content((pos.at(0), pos.at(1) - 11), txt(target, size: 6.5pt), anchor: "north")
  }
  node((0, 0), "%l_a_", "placeholder", "dark", "a")
  node((0, -44), "%l_b_", "placeholder", "dark", "b")
  node((0, -88), "%l_c_", "placeholder", "dark", "c")
  node((128, -22), "%add", "operator.add", "blue", "add")
  node((128, -88), "%relu", "Tensor.relu", "teal", "relu")
  node((248, -55), "%mul", "operator.mul", "blue", "mul")
  node((368, -55), "%sum_1", "Tensor.sum · dim=-1", "teal", "sum")
  node((480, -55), "output", "return (sum_1,)", "orange", "out")

  arrow("a.east", "add.west")
  arrow("b.east", "add.west")
  arrow("c.east", "relu.west")
  arrow("add.east", "mul.west")
  arrow("relu.east", "mul.west")
  arrow("mul.east", "sum.west")
  arrow("sum.east", "out.west", color: c.orange)
  content((308, -51), txt("[4, 128]", size: 6.5pt), anchor: "south")
  content((428, -51), txt("[4]", size: 6.5pt, fill: c.orange), anchor: "south")

  let ly = -122
  legend(0, ly, "placeholder", box-swatch(0, ly, c.ink))
  legend(100, ly, "call_function", box-swatch(100, ly, white, stroke: .7pt + c.blue))
  legend(200, ly, "call_method", box-swatch(200, ly, c.teal1, stroke: .7pt + c.teal))
  legend(300, ly, "output", box-swatch(300, ly, c.orange1, stroke: .7pt + c.orange))
})

/// AOTAutograd: each Dynamo node becomes one ATen overload.
#let fig-aot-map() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let rows = (
    ("L_a_ · L_b_ · L_c_", "arg0_1 · arg1_1 · arg2_1", "f32[4, 128]"),
    ("l_a_ + l_b_", "aten.add.Tensor", "f32[4, 128]"),
    ("l_c_.relu()", "aten.relu.default", "f32[4, 128]"),
    ("add * relu", "aten.mul.Tensor", "f32[4, 128]"),
    ("mul.sum(dim=-1)", "aten.sum.dim_IntList(mul, [-1])", "f32[4]"),
  )
  let (xl, xr, xs, rh) = (70, 300, 470, 30)
  rect((0, 36), (1, 35), stroke: none)  // headroom for the heads
  content((xl, 18), tag("Dynamo FX Graph", fill: c.ink), anchor: "south")
  content((xr, 18), tag("ATen FX Graph", fill: c.ink), anchor: "south")
  content((xs, 18), tag("meta", fill: c.ink), anchor: "south")
  for (i, (l, r, s)) in rows.enumerate() {
    let y = -i * rh
    let tone = if i == 0 { "dark" } else if i == rows.len() - 1 { "orange" } else { "blue" }
    pill((xl, y), raw(l), name: "l" + str(i), tone: if i == 0 { "dark" } else { "blue" }, size: 7pt)
    pill((xr, y), raw(r), name: "r" + str(i), tone: tone, size: 7pt)
    arrow("l" + str(i) + ".east", "r" + str(i) + ".west")
    content((xs, y), txt(s, size: 7pt, fill: if i == rows.len() - 1 { c.orange } else { c.muted }), anchor: "center")
  }
  content((xr, -(rows.len() - 1) * rh - 18), txt("dim 被规范化进 overload 的参数，Python 方法调用变成 aten op", style: "italic"), anchor: "north")
})

// ============================================================================
// Inductor IR objects
// ============================================================================

/// The object model on the running example: three FX nodes and what their
/// `.data` chains hold, with the field values the lowering actually produced.
#let fig-ir-model() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (xt, xv, xs, bx0, bx1) = (34, 116, 196, 252, 556)
  let xc = (bx0 + bx1) / 2
  let note(pos, body, anchor: "north", fill: c.muted) = content(pos, align(center, txt(body, size: 6.5pt, fill: fill)), anchor: anchor)
  let line-at(x, y, body, size: 6.5pt, fill: c.muted, weight: 400) = content((x, y), txt(body, size: size, fill: fill, weight: weight), anchor: "north-west")
  let state(y, body, fill) = content((bx1 - 8, y), txt(body, size: 6.5pt, fill: fill, weight: 600), anchor: "north-east")
  let dashed = (paint: c.grey2, thickness: .7pt, dash: "dashed")

  rect((0, 50), (1, 49), stroke: none)  // headroom for the heads
  rect((0, -196), (1, -197), stroke: none)  // and for the bottom border
  for (x, body) in ((xt, "这个值是谁"), (xv, "怎么索引"), (xs, "数据在哪"), (xc, "数据是什么")) {
    content((x, 30), txt(body, fill: c.ink, weight: 600), anchor: "south")
  }

  // the View column is empty in this example
  rect((xv - 24, 22), (xv + 24, -176), fill: c.panel, stroke: none, radius: 4)
  note((xv, -160), "本例\n没有 View")

  let row(i, y, node, color) = {
    pill((xt, y), "TensorBox", name: "t" + str(i), size: 7pt)
    note((xt, y - 10), node, fill: c.ink)
    pill((xs, y), "StorageBox", name: "s" + str(i), tone: "pale", size: 7pt)
    arrow("t" + str(i) + ".east", "s" + str(i) + ".west", color: c.ink)
    arrow("s" + str(i) + ".east", (bx0 - 2, y), color: color, dash: if color == c.grey2 { "dashed" } else { none })
  }

  // arg0_1: a graph input is already a Buffer
  let y0 = 0
  row(0, y0, "arg0_1", c.ink)
  rect((bx0, y0 + 14), (bx1, y0 - 16), fill: c.ink, stroke: none, radius: 4)
  line-at(bx0 + 10, y0 + 9, "InputBuffer · name = arg0_1", size: 7.5pt, fill: white, weight: 600)
  line-at(bx0 + 10, y0 - 3, "FixedLayout(size=[4, 128], stride=[128, 1])", fill: c.grey2)
  state(y0 + 9, "graph 输入", c.grey2)

  // add: an unrealized Pointwise, only an inner_fn
  let y1 = -52
  row(1, y1, "add", c.grey2)
  rect((bx0, y1 + 16), (bx1, y1 - 30), fill: white, stroke: dashed, radius: 4)
  line-at(bx0 + 10, y1 + 11, "Pointwise · ranges = [4, 128]", size: 7.5pt, fill: c.ink, weight: 600)
  line-at(bx0 + 10, y1 - 1, "inner_fn(i0, i1) = load(arg0_1, idx) + load(arg1_1, idx)")
  line-at(bx0 + 10, y1 - 12, "idx = 128·i0 + i1")
  state(y1 + 11, "未 realize · 没有内存", c.muted)

  // sum_1: the Reduction was realized into buf0 and is kept as its .data
  let y2 = -128
  row(2, y2, "sum_1", c.orange)
  rect((bx0, y2 + 30), (bx1, y2 - 62), fill: c.orange1, stroke: .7pt + c.orange, radius: 4)
  line-at(bx0 + 10, y2 + 25, "ComputedBuffer · name = buf0", size: 7.5pt, fill: c.ink, weight: 600)
  line-at(bx0 + 10, y2 + 13, "FixedLayout(size=[4], stride=[1])")
  state(y2 + 25, "realize 后", c.orange)
  rect((bx0 + 8, y2), (bx1 - 8, y2 - 54), fill: white, stroke: dashed, radius: 3)
  line-at(bx0 + 16, y2 - 4, ".data = Reduction · reduction_type = sum", size: 7pt, fill: c.ink, weight: 600)
  line-at(bx0 + 16, y2 - 16, "ranges = [4] · reduction_ranges = [128]")
  line-at(bx0 + 16, y2 - 27, "inner_fn(i0, r0) = (load(arg0_1, idx) + load(arg1_1, idx))")
  line-at(bx0 + 16, y2 - 38, "                   * relu(load(arg2_1, idx))，idx = 128·i0 + r0")
})

/// After lowering: one row per FX node, its `.data` chain left to right,
/// as the probe prints it.
#let fig-inductor-objects() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let rh = 28
  let y(i) = -i * rh
  let (xt, xs, xd, xe) = (110, 220, 340, 432)
  // (FX node, kind, .data label, role); kind: input / pointwise / output
  let rows = (
    ("arg0_1", "input", "InputBuffer arg0_1", "a"),
    ("arg1_1", "input", "InputBuffer arg1_1", "b"),
    ("arg2_1", "input", "InputBuffer arg2_1", "c"),
    ("add", "pointwise", "Pointwise [4, 128]", "a + b"),
    ("relu", "pointwise", "Pointwise [4, 128]", "relu(c)"),
    ("mul", "pointwise", "Pointwise [4, 128]", "add * relu"),
    ("sum_1", "output", "ComputedBuffer buf0", "Σ mul，沿 dim -1"),
  )
  let last = rows.len() - 1
  for (i, _) in rows.enumerate() {
    if calc.rem(i, 2) == 0 { rect((-4, y(i) + rh / 2), (556, y(i) - rh / 2), fill: c.panel, stroke: none) }
  }
  rect((0, rh / 2 + 20), (1, rh / 2 + 19), stroke: none)  // headroom for the heads
  content((0, rh / 2 + 4), tag("FX node", fill: c.ink), anchor: "south-west")
  for (x, body) in ((xt, "TensorBox"), (xs, "StorageBox"), (xd, ".data")) {
    content((x, rh / 2 + 4), tag(body, fill: c.ink), anchor: "south")
  }

  for (i, (node, kind, body, role)) in rows.enumerate() {
    let yy = y(i)
    content((0, yy), txt(node, size: 7.5pt, fill: c.ink), anchor: "west")
    pill((xt, yy), "TensorBox", name: "tb" + str(i), size: 7pt)
    pill((xs, yy), "StorageBox", name: "s" + str(i), tone: "pale", size: 7pt)
    let tone = if kind == "input" { "dark" } else if kind == "pointwise" { "muted" } else { "orange" }
    pill((xd, yy), body, name: "d" + str(i), tone: tone, size: 7pt)
    arrow("tb" + str(i) + ".east", "s" + str(i) + ".west")
    arrow("s" + str(i) + ".east", "d" + str(i) + ".west")
    content((xe + 8, yy), txt(role, size: 7pt), anchor: "west")
  }
  // the three unrealized Pointwise are inlined into the Reduction's inner_fn
  let (top, bot) = (y(3) + 8, y(last) - 8)
  line((xe, top), (xe, bot), stroke: .7pt + c.orange)
  for yy in (top, bot) { line((xe, yy), (xe + 4, yy), stroke: .7pt + c.orange) }
  content((xd, y(last) - 16), txt("data = Reduction，inner_fn 内联了上面 3 个 Pointwise", fill: c.orange), anchor: "north")

  let ly = y(last) - 40
  legend(0, ly, "未 realize：只有 inner_fn，没有内存", box-swatch(0, ly, white, stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed")))
  legend(210, ly, "真实 buffer（有 name 和 layout）", box-swatch(210, ly, c.orange1, stroke: .7pt + c.orange))
  legend(410, ly, "graph 输入", box-swatch(410, ly, c.ink))
})

/// realize(): the StorageBox keeps its identity; its `.data` becomes a ComputedBuffer.
#let fig-realize() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let frame(x0, x1, title) = {
    rect((x0, 10), (x1, -54), fill: c.blue1, stroke: .7pt + c.blue, radius: 4)
    content((x0 + 6, 4), txt(title, size: 7pt, fill: c.blue, weight: 600), anchor: "north-west")
  }

  rect((0, 38), (1, 37), stroke: none)  // headroom for the tags
  content((0, 22), tag("before"), anchor: "south-west")
  pill((36, -22), "TensorBox", name: "tb", size: 7pt)
  content((36, -34), txt("sum_1", size: 7pt), anchor: "north")
  frame(84, 232, "StorageBox")
  pill((158, -28), "Reduction [4] × [128]", tone: "muted", size: 7pt)
  arrow("tb.east", (84, -22))

  arrow((242, -22), (292, -22), color: c.ink, w: 1pt)
  content((267, -18), txt("realize()", fill: c.ink, weight: 600), anchor: "south")

  content((302, 22), tag("after"), anchor: "south-west")
  frame(302, 548, "StorageBox（同一个对象）")
  rect((312, -10), (538, -48), fill: c.orange1, stroke: .7pt + c.orange, radius: 3)
  content((318, -14), txt("ComputedBuffer · name = buf0 · FlexibleLayout", size: 7pt, fill: c.ink, weight: 600), anchor: "north-west")
  pill((425, -37), "data = Reduction [4] × [128]", tone: "muted", size: 7pt)

  content((158, -62), txt("make_reduction() 构造后立即 realize"), anchor: "north")
  content((425, -62), txt("register_buffer() → buf0 · register_operation()"), anchor: "north")
})

/// op0's loop body: (p0, p1) loads a, b, c at 128·p0 + p1 and the sum over
/// p1 lands in buf0[p0]. The index labels are the ones in the loop body.
#let fig-reduction-index() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, r0, k0) = (8, 10, 1, 5)
  let gap = 58
  let names = (("arg0_1 · a", c.blue1, c.blue2, c.blue), ("arg1_1 · b", c.blue1, c.blue2, c.blue), ("arg2_1 · c", c.teal1, c.teal2, c.teal))
  for (i, (label, f1, f2, f3)) in names.enumerate() {
    let oy = -i * gap
    cells((0, oy), 4, 16, w, h, paint: (r, k) => if r == r0 { if k == k0 { f3 } else { f2 } } else { f1 })
    content((134, oy - 2 * h), txt(label, size: 7pt, fill: c.ink), anchor: "west")
  }
  content((-6, -(r0 + .5) * h), txt("p0 = 1", fill: c.ink), anchor: "east")
  content(((k0 + .5) * w, 4), txt("p1", fill: c.ink), anchor: "south")

  // the three loads of one element meet in the inlined expression
  let ex = (k0 + .5) * w
  pill((268, -64), "(a + b) * relu(c)", name: "expr", size: 7.5pt)
  for i in range(3) {
    let ey = -i * gap - (r0 + .5) * h
    curve-arrow((ex + 4, ey), "expr.west", (90, ey), (190, -64), color: if i == 2 { c.teal } else { c.blue }, w: .6pt)
  }

  // the reduction over p1 lands in buf0[p0]
  let bx = 420
  cells((bx, -44), 4, 1, 16, h, paint: (r, k) => if r == r0 { c.orange } else { c.orange1 })
  content((bx + 8, -40), txt("buf0 · f32[4]", fill: c.orange), anchor: "south")
  let by = -44 - (r0 + .5) * h
  arrow("expr.east", (bx - 2, by), color: c.orange, w: 1pt)
  content((372, -52), txt("Σ 沿 p1", fill: c.orange, weight: 600), anchor: "north")
  content((bx + 20, by), txt("index1 = p0", fill: c.orange), anchor: "west")

  let gy = -156
  content((268, gy), tag("op0 · Reduction"), anchor: "north")
  content((268, gy - 14), txt("var_ranges = {p0: 4, p1: 128} · sizes = ([4], [128])", fill: c.ink), anchor: "north")
  content((268, gy - 28), txt("三次 load 都用 index0 = 128·p0 + p1", fill: c.blue), anchor: "north")
})

// ============================================================================
// Scheduler
// ============================================================================

/// op0 as the Scheduler sees it: reads (met_dependencies), the write, the
/// empty unmet_dependencies, and how merge_loops() after fusion folds
/// 128·d0 + d1 into one flat c0.
#let fig-scheduler-node() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (xi, ox0, ox1, xb) = (44, 196, 372, 476)
  let ys = (0, -36, -72)

  // upstream SchedulerNodes: none
  rect((0, 64), (1, 63), stroke: none)  // headroom
  pill((xi, 44), "其他 SchedulerNode", name: "up", tone: "muted", size: 7pt)
  arrow("up.east", (ox0 - 2, 22), color: c.grey2, dash: "dashed")
  content((120, 40), txt("unmet_dependencies = []", size: 6.5pt), anchor: "south-west")

  // reads: graph inputs, already available
  for (i, y) in ys.enumerate() {
    pill((xi, y), "arg" + str(i) + "_1 · f32[4, 128]", name: "in" + str(i), tone: "dark", size: 7pt)
    arrow("in" + str(i) + ".east", (ox0 - 2, y), color: c.teal)
  }
  content((xi + 20, -86), align(center, txt("met_dependencies：graph 输入，已就绪\n每个都是 128·d0 + d1, {d0: 4, d1: 128}", size: 6.5pt, fill: c.teal)), anchor: "north")

  // the node itself
  rect((ox0, 30), (ox1, -92), fill: c.blue1, stroke: .7pt + c.blue, radius: 4)
  content((ox0 + 8, 24), txt("op0 · SchedulerNode(ComputedBuffer)", size: 7.5pt, fill: c.ink, weight: 600), anchor: "north-west")
  let field(y, body) = content((ox0 + 8, y), txt(body, size: 6.5pt, fill: c.ink), anchor: "north-west")
  field(6, "sizes = ([4], [128])：输出轴，reduction 轴")
  field(-10, "group.iteration = (4, 128)")
  field(-26, "outputs = [buf0]")
  rect((ox0 + 8, -50), (ox1 - 8, -84), fill: white, stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed"), radius: 3)
  content(((ox0 + ox1) / 2, -55), txt("loop body：load × 3 → add → relu → mul", size: 6.5pt), anchor: "north")
  content(((ox0 + ox1) / 2, -67), txt("→ reduction(sum) → store_reduction", size: 6.5pt), anchor: "north")

  // the write
  pill((xb, -36), "buf0 · f32[4]", name: "out", tone: "orange", size: 7.5pt)
  arrow((ox1 + 2, -36), "out.west", color: c.orange, w: 1pt)
  content(((ox1 + xb) / 2 - 18, -32), txt("writes", size: 6.5pt, fill: c.orange), anchor: "south")
  content(((ox1 + xb) / 2 - 18, -40), txt("d0, {d0: 4}", size: 6.5pt, fill: c.orange), anchor: "north")
  content((xb, -50), txt("FixedLayout([4], [1])", size: 6.5pt), anchor: "north")

  // why a read becomes one flat c0: four contiguous rows end to end
  let gy = -134
  content((0, gy), tag("post-fusion：merge_loops() 后", fill: c.ink), anchor: "north-west")
  let (w, h) = (5, 6)
  let paint(r) = if calc.rem(r, 2) == 0 { c.teal2 } else { c.teal1 }
  cells((0, gy - 18), 4, 16, w, h, paint: (r, k) => paint(r))
  content((84, gy - 30), txt("128·d0 + d1\n{d0: 4, d1: 128}", size: 6.5pt, fill: c.ink), anchor: "west")
  arrow((170, gy - 30), (200, gy - 30), color: c.ink)
  cells((206, gy - 27), 1, 64, w, h, paint: (r, k) => paint(calc.quo(k, 16)))
  content((206 + 32 * w, gy - 37), txt("c0, {c0: 512}：stride 连续，4 行首尾相接", size: 6.5pt, fill: c.ink), anchor: "north")
  rect((0, gy - 54), (1, gy - 55), stroke: none)  // room for the last line
})

// ============================================================================
// Triton codegen
// ============================================================================

/// The persistent-reduction launch: XBLOCK = 1, so program i owns row i; its
/// [1, 128] tile is spread over 2 warps (64 threads, 2 elements each) and
/// tl.sum leaves one value for out_ptr0[i].
#let fig-triton-programs() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, r0) = (3, 12, 1)
  // the input rows (a, b, c share this layout), one per program
  cells((0, 0), 4, 128, w, h, paint: (r, k) => if r == r0 { if calc.quo(k, 64) == 0 { c.blue2 } else { c.teal2 } } else { c.grey1 })
  content((0, 4), txt("in_ptr0/1/2 · f32[4, 128]，r0_1 + 128·x0", fill: c.ink), anchor: "south-west")
  for r in range(4) {
    content((388, -(r + .5) * h), txt("pid " + str(r), size: 7pt, fill: if r == r0 { c.ink } else { c.muted }, weight: if r == r0 { 600 } else { 400 }), anchor: "west")
  }
  content((424, -(r0 + .5) * h), txt("← program 1：x0 = 1", size: 7pt, fill: c.ink), anchor: "west")

  // program 1's tile: 2 warps x 32 threads, 2 elements per thread
  let (ty, tw) = (-80, 192 / 32)
  rect((0, ty + 12), (396, ty - 40), fill: c.panel, stroke: .5pt + c.hair, radius: 3)
  content((6, ty + 8), txt("program 1 · tile [XBLOCK, R0_BLOCK] = [1, 128] · num_warps = 2", size: 7pt, fill: c.ink, weight: 600), anchor: "north-west")
  for wi in range(2) {
    let x0 = 6 + wi * 192
    cells((x0, ty - 8), 1, 64, w, h, paint: (r, k) => if wi == 0 { c.blue2 } else { c.teal2 })
    for t in range(32) { line((x0 + t * tw, ty - 8), (x0 + t * tw, ty - 8 - h), stroke: .5pt + white) }
    content((x0 + 96, ty - 24), txt("warp " + str(wi) + " · 32 threads × 2 元素", size: 6.5pt, fill: c.ink), anchor: "north")
  }
  curve-arrow((96, -(r0 + 1) * h), (99, ty + 12), (96, -50), (99, -50), color: c.blue)
  curve-arrow((288, -(r0 + 1) * h), (291, ty + 12), (288, -50), (291, -50), color: c.teal)
  content((195, -40), txt("load 整行，没有 reduction 循环", size: 6.5pt, fill: c.ink), anchor: "north")

  // tl.sum → out_ptr0[x0]
  let ox = 470
  cells((ox, ty + 6), 4, 1, 16, h, paint: (r, k) => if r == r0 { c.orange } else { c.orange1 })
  content((ox + 8, ty + 10), txt("out_ptr0 · f32[4]", fill: c.orange), anchor: "south")
  arrow((398, ty - 14), (ox - 4, ty + 6 - 1.5 * h), color: c.orange, w: 1pt)
  content((430, ty - 16), txt("tl.sum(…, 1)", size: 7pt, fill: c.orange), anchor: "north")
  content((ox + 20, ty + 6 - 1.5 * h), txt("x0", size: 7pt, fill: c.ink), anchor: "west")

  content((198, ty - 46), txt("grid = xnumel / XBLOCK = 4 个 program，各自处理一行", style: "italic"), anchor: "north")
})
