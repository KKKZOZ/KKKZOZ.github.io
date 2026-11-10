// Figures for content/posts/ml-systems/ml-compilers/torchinductor-fusion.typ, drawn with cetz.
// The running example is the model in the post:
//   t = x * 1.1 + bias; a = relu(t); s = a * a + a * 0.1
//   m = s.mean(dim=1, keepdim=True); y = (s - m) * gamma + beta
// on x: f32[1024, 1024] and bias / gamma / beta: f32[1024]. Names (op0, buf0, ...)
// are the ones in the Inductor logs.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, curve-arrow, legend, line-swatch, pill, tag, txt

// A box of fixed width with centred content, for text that has to wrap.
#let cell(pos, body, w: 108, anchor: "north") = cetz.draw.content(
  pos, box(width: w * 1pt, align(center, body)), anchor: anchor,
)

// A rounded rectangle with a bold title and a muted subtitle.
#let card(x, y, w, h, title, sub, bg: white, edge: c.blue, name: none) = {
  import cetz.draw: *
  rect((x, y), (x + w, y - h), fill: bg, stroke: .8pt + edge, radius: 3, name: name)
  content((x + w / 2, y - 12), txt(title, size: 8pt, fill: c.ink, weight: 700))
  content((x + w / 2, y - 22), box(width: (w - 10) * 1pt, align(center, txt(sub, size: 6.5pt))), anchor: "north")
}

// ============================================================================
// Why fuse: HBM round trips with and without fusion
// ============================================================================

#let fig-fusion-traffic() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let hbm(y) = {
    rect((0, y), (520, y - 22), fill: c.grey1, stroke: none, radius: 2)
    content((6, y - 11), tag("HBM", fill: c.muted), anchor: "west")
  }
  let tensor(x, y, name, fill: white) = {
    rect((x - 15, y - 4), (x + 15, y - 18), fill: fill, stroke: .6pt + c.line, radius: 2)
    content((x, y - 11), txt(raw(name), size: 7pt, fill: c.ink))
  }

  // Eager: three kernels, every intermediate goes through HBM.
  content((0, 20), tag("Eager：3 个 kernel", fill: c.ink), anchor: "west")
  content((520, 20), txt([读 3 次、写 3 次；`t1`、`t2` 各写回一次再读出来]), anchor: "east")
  let (kx, tx) = ((130, 270, 410), (60, 200, 340, 480))
  for (i, k) in ("A", "B", "C").enumerate() {
    pill((kx.at(i), -10), [Kernel #k], tone: "blue", name: "k" + str(i))
  }
  hbm(-60)
  for (i, n) in ("x", "t1", "t2", "y").enumerate() {
    tensor(tx.at(i), -60, n, fill: if i == 1 or i == 2 { c.orange1 } else { white })
  }
  for i in range(3) {
    arrow((tx.at(i) + 6, -64), (kx.at(i) - 22, -20), color: c.blue)
    arrow((kx.at(i) + 22, -20), (tx.at(i + 1) - 6, -64), color: c.orange)
  }
  content((70, -36), txt("load", size: 6.5pt, fill: c.blue), anchor: "east")
  content((172, -36), txt("store", size: 6.5pt, fill: c.orange), anchor: "west")

  // Fused: one kernel, intermediates stay in registers.
  let y0 = -124
  content((0, y0 + 20), tag("Fused：1 个 kernel", fill: c.ink), anchor: "west")
  content((520, y0 + 20), txt([读 1 次、写 1 次；中间结果留在寄存器里]), anchor: "east")
  rect((96, y0 + 4), (444, y0 - 26), fill: c.teal1, stroke: .8pt + c.teal, radius: 4)
  for (i, k) in ("A", "B", "C").enumerate() {
    pill((160 + i * 110, y0 - 11), [#k], tone: "blue", name: "f" + str(i))
  }
  arrow("f0.east", "f1.west", color: c.teal)
  arrow("f1.east", "f2.west", color: c.teal)
  content((215, y0 - 7), txt("寄存器", size: 6.5pt, fill: c.teal), anchor: "south")
  content((325, y0 - 7), txt("寄存器", size: 6.5pt, fill: c.teal), anchor: "south")
  hbm(y0 - 60)
  tensor(60, y0 - 60, "x")
  tensor(480, y0 - 60, "y")
  arrow((66, y0 - 64), (110, y0 - 26), color: c.blue)
  arrow((430, y0 - 26), (474, y0 - 64), color: c.orange)
})

// ============================================================================
// The four Inductor stages, what the example becomes, and where "fusion" happens
// ============================================================================

#let fig-pipeline() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let stages = (
    ("Graph Preprocessing", [What to compute?], [FX Graph]),
    ("Lowering", [How to represent?], [Inductor IR]),
    ("Scheduling", [How to organize?], [SchedulerNode]),
    ("Codegen", [How to emit?], [Triton + wrapper]),
  )
  let example = (
    [10 个 ATen op，pass 后不变],
    [2 个 `ComputedBuffer`：\ `buf0`（行和）、`buf1`（`y`）],
    [`op0`、`op1` → \ `op0_op1`],
    [1 个 Triton kernel，\ 1 次 launch],
  )
  let fusion = (
    [pattern matching \ 改写子图],
    [`Pointwise` 内联进 \ 使用者的 `inner_fn`],
    [`SchedulerNode` 合并成 \ `FusedSchedulerNode`],
    [kernel 内 CSE，\ 删除 kernel 内部 buffer],
  )
  let (x0, w, gap) = (58, 112, 12)
  for (i, (title, q, out)) in stages.enumerate() {
    let x = x0 + i * (w + gap)
    rect((x, 0), (x + w, -52), fill: if i == 2 { c.orange1 } else { white },
      stroke: .8pt + if i == 2 { c.orange } else { c.blue }, radius: 3)
    content((x + w / 2, -12), txt(title, size: 8pt, fill: c.ink, weight: 700))
    content((x + w / 2, -27), txt(q, size: 7pt, style: "italic"))
    content((x + w / 2, -41), txt([输出：#out], size: 7pt, fill: c.ink))
    if i > 0 { arrow((x - gap, -26), (x, -26)) }
    cell((x + w / 2, -64), txt(example.at(i), size: 7pt, fill: c.ink), w: w)
    cell((x + w / 2, -100), txt(fusion.at(i), size: 7pt, fill: c.teal), w: w)
  }
  content((0, -26), txt([FX \ GraphModule], size: 7pt, fill: c.ink), anchor: "west")
  arrow((44, -26), (x0, -26))
  content((0, -72), tag("本例", fill: c.ink), anchor: "west")
  content((0, -108), tag("融合", fill: c.teal), anchor: "west")
  line((0, -58), (x0 + 4 * w + 3 * gap, -58), stroke: .5pt + c.hair)
  line((0, -94), (x0 + 4 * w + 3 * gap, -94), stroke: .5pt + c.hair)
})

// ============================================================================
// The example after lowering: two SchedulerNodes, s inlined into both
// ============================================================================

#let fig-example-ir() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let lane(y, x1, title) = {
    rect((52, y + 16), (x1, y - 16), fill: c.panel, stroke: .6pt + c.hair, radius: 4)
    content((56, y + 19), txt(title, size: 7pt, fill: c.ink), anchor: "south-west")
  }
  let chain(y, p) = {
    pill((100, y), [x·1.1 + bias], tone: "blue", size: 7pt, name: p + "t")
    pill((180, y), [relu], tone: "blue", size: 7pt, name: p + "a")
    pill((262, y), [a·a + a·0.1], tone: "blue", size: 7pt, name: p + "s")
    arrow(p + "t.east", p + "a.west")
    arrow(p + "a.east", p + "s.west")
  }
  // op0: the reduction.
  lane(0, 392, [*op0* · `Reduction` · 每行求和，写 `buf0`])
  chain(0, "u")
  pill((350, 0), [sum(dim=1)], tone: "teal", size: 7pt, name: "sum")
  arrow("us.east", "sum.west")
  pill((436, 0), raw("buf0"), tone: "orange", size: 7pt, name: "buf0")
  arrow("sum.east", "buf0.west", color: c.orange)
  content((436, -10), txt("[1024, 1]", size: 6.5pt), anchor: "north")

  // op1: the pointwise epilogue.
  let y1 = -72
  lane(y1, 482, [*op1* · `Pointwise` · 读 `buf0`，写 `buf1`])
  chain(y1, "l")
  pill((350, y1), [s − buf0/1024], tone: "blue", size: 7pt, name: "sub")
  pill((436, y1), [·γ + β], tone: "blue", size: 7pt, name: "aff")
  arrow("ls.east", "sub.west")
  arrow("sub.east", "aff.west")
  pill((516, y1), raw("buf1"), tone: "orange", size: 7pt, name: "buf1")
  arrow("aff.east", "buf1.west", color: c.orange)
  content((516, y1 - 10), txt("= y", size: 6.5pt), anchor: "north")
  curve-arrow("buf0.south", "sub.north", (436, -40), (350, -36), color: c.orange)

  // Inputs shared by both nodes.
  pill((0, -36), [x, bias], tone: "dark", size: 7pt, name: "in")
  arrow("in.north", "ut.west")
  arrow("in.south", "lt.west")
  pill((436, y1 - 40), [γ, β], tone: "dark", size: 7pt, name: "gb")
  arrow("gb.north", "aff.south")

  // The duplicated computation of s.
  rect((60, 13), (304, y1 - 13), stroke: (paint: c.teal, thickness: .8pt, dash: "dashed"), radius: 4)
  content((182, y1 - 20), txt([`s` 有两个使用者，但没有 realize：两个节点各自内联一份], size: 7pt, fill: c.teal), anchor: "north")
})

// ============================================================================
// Lowering: how GraphLowering dispatches one FX node
// ============================================================================

#let fig-lowering-dispatch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let steps = (
    ("GraphLowering.run()", [外面包一层计时，直接调用父类]),
    ("Interpreter.run()", [按顺序遍历 FX node，维护 `env`]),
    ("GraphLowering.run_node(n)", [记录 origins，处理 stream 边界和 fallback；之后约束 stride、决定是否 realize]),
    ("Interpreter.run_node(n)", [从 `env` 取出参数：前面 node 的 lowering 结果]),
    ("getattr(self, n.op)", [按 `n.op` 分派到同名方法]),
  )
  for (i, (name, note)) in steps.enumerate() {
    let y = -i * 30
    pill((86, y), raw(name), tone: if i == 2 { "orange" } else { "blue" }, size: 7pt, name: "s" + str(i))
    if i > 0 { arrow("s" + str(i - 1) + ".south", "s" + str(i) + ".north") }
    content((180, y), box(width: 340pt, txt(note, size: 7pt)), anchor: "west")
  }
  let ops = (
    ("placeholder", true, [`InputBuffer`]),
    ("call_function", true, [查 `lowerings`]),
    ("get_attr", true, [常量]),
    ("output", true, [graph 输出]),
    ("call_method", false, [`AssertionError`]),
    ("call_module", false, [`AssertionError`]),
  )
  let yo = -176
  for (i, (op, ok, what)) in ops.enumerate() {
    let x = 44 + i * 88
    pill((x, yo), raw(op), tone: if ok { "teal" } else { "muted" }, size: 7pt, name: "o" + str(i))
    arrow("s4.south", "o" + str(i) + ".north", color: if ok { c.line } else { c.grey2 })
    content((x, yo - 11), txt(what, size: 6.5pt, fill: if ok { c.muted } else { c.danger }), anchor: "north")
  }
})

// ============================================================================
// Inductor IR: aliases share a StorageBox, a view wraps it
// ============================================================================

#let fig-storage-alias() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let code = ("a = torch.tensor([[1, 2], [3, 4]])", "b = a", "a.add_(10)", "c = a.permute(1, 0)")
  rect((0, 8), (172, 8 - 14 * code.len() - 8), fill: c.panel, stroke: none, radius: 3)
  for (i, l) in code.enumerate() {
    content((8, -i * 14), txt(raw(l), size: 7pt, fill: c.ink), anchor: "west")
  }
  let box-at(pos, body, name, tone: "blue") = pill(pos, raw(body), tone: tone, size: 7pt, name: name)
  box-at((240, 0), "TensorBox(a)", "a")
  box-at((240, -34), "TensorBox(b)", "b")
  box-at((240, -96), "TensorBox(c)", "c")
  box-at((350, -17), "StorageBox(S)", "S", tone: "orange")
  box-at((350, -96), "PermuteView", "v", tone: "teal")
  box-at((474, 10), "Pointwise(load)", "old", tone: "muted")
  box-at((474, -44), "Pointwise(+10)", "new")
  arrow("a.east", "S.west")
  arrow("b.east", "S.west")
  arrow("c.east", "v.west")
  arrow("v.north", "S.south")
  arrow("S.east", "old.west", color: c.grey2, dash: "dashed")
  arrow("S.east", "new.west", color: c.orange)
  content((350, -107), txt([reindex: `[j, i]` → `[i, j]`], size: 6.5pt), anchor: "north")
  content((415, -4), text(size: 11pt, fill: c.danger, sym.times))
  content((474, -56), txt([`add_` 就地替换 `S.data`], size: 6.5pt, fill: c.orange), anchor: "north")
  content((296, -2), txt(".data", size: 6pt), anchor: "south")
  content((240, -46), txt([别名共用一个 `StorageBox`], size: 6.5pt), anchor: "north")
})

// ============================================================================
// Scheduler.fuse_nodes: rounds of fuse_nodes_once
// ============================================================================

#let fig-fuse-loop() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let steps = (
    ([① 分组], [按读写的 buffer 把节点分组]),
    ([② 配对], [组内两两配对，每个节点只看后面 64 个]),
    ([③ 筛选], [`can_fuse(n1, n2)`：合法且有共享数据]),
    ([④ 排序], [按 `score_fusion` 从高到低]),
    ([⑤ 贪心合并], [逐对重新 `can_fuse`，查环，合成 `FusedSchedulerNode`]),
  )
  let (w, gap, h) = (94, 12, 58)
  for (i, (t, s)) in steps.enumerate() {
    let x = i * (w + gap)
    card(x, 0, w, h, t, s, bg: if i == 4 { c.orange1 } else { white }, edge: if i == 4 { c.orange } else { c.blue })
    if i > 0 { arrow((x - gap, -h / 2), (x, -h / 2)) }
  }
  let xr = 4 * (w + gap) + w
  // Loop back: another round while the node count keeps dropping.
  line((xr - w / 2, -h), (xr - w / 2, -h - 22), (w / 2, -h - 22),
    stroke: .7pt + c.orange)
  arrow((w / 2, -h - 22), (w / 2, -h), color: c.orange)
  content(((xr) / 2, -h - 26), txt([下一轮：节点数还在减少就继续，最多 10 轮；节点数不变或只剩 1 个时停止], size: 7pt, fill: c.orange), anchor: "north")
  content((xr / 2, -h - 42), txt([之后若开启 `loop_ordering_after_fusion`，再做一轮允许重排循环的融合], size: 7pt), anchor: "north")
  content((0, 14), tag("fuse_nodes_once", fill: c.ink), anchor: "west")
})

// ============================================================================
// Vertical and horizontal fusion
// ============================================================================

#let fig-fusion-kinds() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // Vertical: producer -> consumer.
  content((0, 26), tag("Vertical", fill: c.ink), anchor: "west")
  pill((90, 0), raw("node1"), tone: "blue", name: "p")
  pill((90, -56), raw("node2"), tone: "blue", name: "q")
  arrow("p.south", "q.north", color: c.orange)
  content((98, -28), txt([写 `buf0[d0]` → 读 `buf0[d0]`], size: 7pt, fill: c.orange), anchor: "west")
  rect((30, 14), (236, -70), stroke: (paint: c.teal, thickness: .8pt, dash: "dashed"), radius: 5)
  cell((133, -80), txt([node1 是 node2 的祖先。node2 对 node1 输出的每次读，index 都要与写的 index 相同], size: 7pt), w: 230)

  // Horizontal: siblings with a common read.
  let x0 = 290
  content((x0, 26), tag("Horizontal", fill: c.ink), anchor: "west")
  pill((x0 + 120, 0), raw("arg0_1"), tone: "dark", name: "x")
  pill((x0 + 60, -56), raw("node1"), tone: "blue", name: "a")
  pill((x0 + 180, -56), raw("node2"), tone: "blue", name: "b")
  arrow("x.south", "a.north")
  arrow("x.south", "b.north")
  rect((x0 + 18, -42), (x0 + 222, -70), stroke: (paint: c.teal, thickness: .8pt, dash: "dashed"), radius: 5)
  cell((x0 + 120, -80), txt([互不依赖，但读同一个 buffer。共享数据要达到 `score_fusion_memory_threshold`（10），且在原图中不能离得太远], size: 7pt), w: 240)
})

// ============================================================================
// The example in the Scheduler: op0 + op1 -> op0_op1
// ============================================================================

#let fig-example-fusion() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let node(y, title, lines, name) = {
    rect((0, y), (190, y - 62), fill: white, stroke: .8pt + c.blue, radius: 3, name: name)
    content((8, y - 11), txt(title, size: 8pt, fill: c.ink, weight: 700), anchor: "west")
    for (i, l) in lines.enumerate() {
      content((8, y - 26 - i * 12), txt(l, size: 6.8pt), anchor: "west")
    }
  }
  node(0, [op0 · Reduction], (
    [`group.iteration = (1024, 1024)`],
    [读 `arg0_1[1024*d0 + d1]`、`arg1_1[d1]`],
    [写 `buf0[d0]`（行和）],
  ), "op0")
  node(-84, [op1 · Pointwise], (
    [`group.iteration = (1048576, 1)`],
    [读 `arg0_1`、`arg1_1`（同上）、`arg2_1`、`arg3_1`],
    [读 `buf0[d0]`，写 `buf1`],
  ), "op1")
  arrow((95, -62), (95, -84), color: c.orange)
  content((101, -73), txt([`buf0`：op1 依赖 op0 → vertical], size: 6.8pt, fill: c.orange), anchor: "west")

  // Fused node: one program per row.
  let x0 = 250
  rect((x0, 0), (x0 + 290, -146), fill: c.orange1, stroke: .8pt + c.orange, radius: 3)
  content((x0 + 8, -11), txt([op0_op1 · FusedSchedulerNode], size: 8pt, fill: c.ink, weight: 700), anchor: "west")
  content((x0 + 8, -25), txt([1048576 = 1024 × 1024：op1 的循环可以拆成 op0 的 (行, 列)], size: 6.8pt), anchor: "west")
  // A small grid standing for the [1024, 1024] iteration space.
  let (gx, gy, cw, ch, rows, cols) = (x0 + 14, -38, 11, 8, 8, 16)
  for r in range(rows) {
    for k in range(cols) {
      let hot = r == 2
      rect((gx + k * cw, gy - r * ch), (gx + (k + 1) * cw, gy - (r + 1) * ch),
        fill: if hot { c.teal2 } else { white }, stroke: .4pt + c.hair)
    }
  }
  content((gx + cols * cw + 6, gy - 2.5 * ch), txt([一个 program \ 处理一行], size: 6.8pt, fill: c.teal), anchor: "west")
  let ly = gy - rows * ch - 10
  for (i, s) in ([① load 这一行的 `x`，算出 `s`], [② 行内求和 → `buf0`，留在寄存器里], [③ 用同一行的 `s` 算 `y`，写回 `buf1`]).enumerate() {
    content((gx, ly - i * 12), txt(s, size: 6.8pt, fill: c.ink), anchor: "west")
  }
  arrow((190, -31), (x0, -60), color: c.line)
  arrow((190, -115), (x0, -90), color: c.line)
})

// ============================================================================
// TVM on the same model: pattern kinds and post-dominator groups
// ============================================================================

#let fig-tvm-groups() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let op(pos, body, kind, name, tone: "blue") = {
    pill(pos, body, tone: tone, size: 7pt, name: name)
    content((pos.at(0), pos.at(1) - 10), txt(kind, size: 6pt), anchor: "north")
  }
  // Group 1: everything up to s.
  rect((0, 30), (268, -64), fill: c.blue1, stroke: none, radius: 5)
  content((4, 33), txt([*组 1*], size: 7pt, fill: c.ink), anchor: "south-west")
  op((30, 0), [·1.1], "ElemWise", "m1")
  op((84, 0), [+bias], "Broadcast", "b")
  op((136, 0), [relu], "ElemWise", "r")
  op((186, 16), [a·a], "ElemWise", "p")
  op((186, -30), [a·0.1], "ElemWise", "q")
  op((240, 0), [p + q], "ElemWise", "s")
  arrow("m1.east", "b.west")
  arrow("b.east", "r.west")
  arrow("r.east", "p.west")
  arrow("r.east", "q.west")
  arrow("p.east", "s.west")
  arrow("q.east", "s.west")

  // Group 2: the reduction alone.
  rect((290, 30), (360, -20), fill: c.teal1, stroke: none, radius: 5)
  content((294, 33), txt([*组 2*], size: 7pt, fill: c.ink), anchor: "south-west")
  op((325, 6), [mean], "CommReduce", "mean", tone: "teal")

  // Group 3: the epilogue.
  rect((290, -36), (540, -82), fill: c.orange1, stroke: none, radius: 5)
  content((294, -86), txt([*组 3*], size: 7pt, fill: c.ink), anchor: "north-west")
  op((330, -54), [s − m], "Broadcast", "sub")
  op((410, -54), [·γ], "Broadcast", "g")
  op((490, -54), [+β], "Broadcast", "be")
  arrow("s.east", "mean.west", color: c.orange)
  arrow("s.east", "sub.west", color: c.orange)
  arrow("mean.south", "sub.north", color: c.orange)
  arrow("sub.east", "g.west")
  arrow("g.east", "be.west")
  content((276, -16), txt([`s`], size: 7pt, fill: c.orange))

  // Why s stops: its post-dominator is sub, and the path through mean is a reduction.
  content((0, -100), box(width: 540pt, txt([`s` 的直接 post-dominator 是 `s − m`，但 `s → mean → s − m` 这条路径经过 CommReduce，不满足"中间节点都不超过 Injective"的条件，所以 `s` 不融合；`mean` 作为 CommReduce 不主动向后融合。橙色箭头上的数据都要经过 HBM。], size: 7pt)), anchor: "north-west")
})

// ============================================================================
// The whole torch.compile stack, from Python to PTX
// ============================================================================

#let fig-compile-stack() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let items = (
    ([Python], [函数 / nn.Module]),
    ([FX Graph], [`torch.*` op \ + Guards]),
    ([ATen FX Graph], [`aten.*` op \ forward / backward]),
    ([Inductor IR], [TensorBox → StorageBox → Buffer]),
    ([Triton DSL], [kernel + Python wrapper]),
    ([Triton IR], [TTIR / TTGIR]),
    ([PTX], [→ cubin]),
  )
  let (w, gap, h) = (66, 12, 50)
  for (i, (t, s)) in items.enumerate() {
    let x = i * (w + gap)
    let hot = i == 3 or i == 4
    card(x, 0, w, h, t, s, bg: if hot { c.orange1 } else { white }, edge: if hot { c.orange } else { c.blue })
    if i > 0 { arrow((x - gap, -h / 2), (x, -h / 2)) }
  }
  // Which component produces which artifact.
  let span(i0, i1, body, tone) = {
    let (xa, xb) = (i0 * (w + gap), i1 * (w + gap) + w)
    rect((xa, 30), (xb, 14), fill: tone, stroke: none, radius: 3)
    content(((xa + xb) / 2, 22), txt(body, size: 7pt, fill: c.ink, weight: 600))
  }
  span(1, 1, [TorchDynamo], c.blue1)
  span(2, 2, [AOTAutograd], c.blue1)
  span(3, 3, [TorchInductor], c.orange1)
  span(4, 4, [Inductor Codegen], c.orange1)
  span(5, 6, [Triton JIT], c.teal1)
  content((4 * (w + gap) - gap / 2, -h - 10), txt([本文关注的部分：从 ATen FX Graph 到生成的 Triton 代码], size: 7pt, fill: c.orange), anchor: "north")
})

// ============================================================================
// The example model as a dataflow graph
// ============================================================================

#let fig-model-graph() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let n(pos, body, name, tone: "blue") = pill(pos, body, name: name, tone: tone, size: 7pt)
  rect((0, 60), (1, 59), stroke: none)  // headroom for the shape label
  n((12, 0), [x], "x", tone: "dark")
  n((58, 0), [·1.1], "m1")
  n((112, 0), [+bias], "b")
  n((164, 0), [relu], "r")
  n((214, 22), [a·a], "p")
  n((214, -22), [a·0.1], "q")
  n((264, 0), [p + q], "s")
  n((320, 34), [mean], "mean", tone: "teal")
  n((376, 0), [s − m], "sub")
  n((428, 0), [·γ], "g")
  n((476, 0), [+β], "be")
  n((524, 0), [y], "y", tone: "orange")
  for (a, b) in (("x", "m1"), ("m1", "b"), ("b", "r"), ("r", "p"), ("r", "q"), ("p", "s"), ("q", "s"),
    ("s", "sub"), ("sub", "g"), ("g", "be"), ("be", "y")) {
    arrow(a + ".east", b + ".west")
  }
  arrow("s.north-east", "mean.west", color: c.teal)
  arrow("mean.east", "sub.north", color: c.teal)
  content((214, 34), txt("两个分支", size: 6.5pt), anchor: "south")
  content((320, 46), txt("[1024, 1]", size: 6.5pt, fill: c.teal), anchor: "south")
  content((140, -14), txt("[1024, 1024]", size: 6.5pt), anchor: "north")
  content((264, -14), txt([`s` 有两个使用者], size: 6.5pt, fill: c.orange), anchor: "north")
  let ly = -46
  legend(0, ly, [Pointwise / Broadcast], box-swatch(0, ly, white, stroke: .7pt + c.blue))
  legend(140, ly, [Reduction], box-swatch(140, ly, c.teal1, stroke: .7pt + c.teal))
  legend(240, ly, [graph 输入 / 输出], box-swatch(240, ly, c.ink))
})

// ============================================================================
// Lazy inner_fn composition, and where a Reduction realizes
// ============================================================================

#let fig-inner-fn() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let p(x, y, body, name, tone: "blue") = pill((x, y), raw(body), name: name, tone: tone, size: 7pt)
  let rows = (
    ("c = a + b", "Pointwise", [`add_fn(i) = add(a[i], b[i])`], false),
    ("d = relu(c)", "Pointwise", [`relu_fn(i) = relu(add_fn(i))` \ `= relu(add(a[i], b[i]))`：`c` 被内联], false),
    ("e = sum(d)", "Reduction", [`sum over r: relu(add(a[r], b[r]))` \ 输出 shape 变了，立即 realize → `buf0`], true),
    ("f = e * 2", "Pointwise", [`mul_fn() = mul(load(buf0), 2)` \ 读的是 buffer，不再往前内联], false),
  )
  for (i, (code, kind, fn, realized)) in rows.enumerate() {
    let y = -i * 40
    content((0, y), txt(raw(code), size: 7pt, fill: c.ink), anchor: "west")
    p(110, y, "TensorBox", "t" + str(i))
    p(196, y, "StorageBox", "s" + str(i))
    arrow("t" + str(i) + ".east", "s" + str(i) + ".west")
    if realized {
      p(282, y, "ComputedBuffer", "cb", tone: "orange")
      p(370, y, kind, "k" + str(i), tone: "teal")
      arrow("s" + str(i) + ".east", "cb.west")
      arrow("cb.east", "k" + str(i) + ".west")
    } else {
      p(282, y, kind, "k" + str(i), tone: "muted")
      arrow("s" + str(i) + ".east", "k" + str(i) + ".west")
    }
    content((410, y), box(width: 150pt, txt(fn, size: 6.5pt)), anchor: "west")
  }
  arrow("k1.north", "k0.south", color: c.teal, dash: "dashed")
  arrow("k2.north-west", "k1.south-east", color: c.teal, dash: "dashed")
  arrow("k3.north", "cb.south", color: c.orange, dash: "dashed")
  content((286, -20), txt([调用 `inner_fn`], size: 6pt, fill: c.teal), anchor: "west")
  content((286, -100), txt([`load(buf0)`], size: 6pt, fill: c.orange), anchor: "west")
  let ly = -150
  legend(0, ly, [未 realize：只有 `inner_fn`，没有内存], box-swatch(0, ly, white, stroke: (paint: c.grey2, dash: "dashed")))
  legend(210, ly, [realize 后：`StorageBox.data` 换成 `ComputedBuffer`，成为一个 SchedulerNode], box-swatch(210, ly, c.orange1, stroke: .7pt + c.orange))
})

// ============================================================================
// Scheduler construction: node kinds and the init sequence
// ============================================================================

#let fig-scheduler-init() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  content((0, 18), tag("create_scheduler_node", fill: c.ink), anchor: "west")
  let maps = (
    ([`node.is_no_op()`], "NopKernelSchedulerNode", [不生成 kernel，只维护调度语义], "muted"),
    ([`ComputedBuffer` / `TemplateBuffer`], "SchedulerNode", [普通计算与模板 kernel：可以融合], "orange"),
    ([`ExternKernel`], "ExternKernelSchedulerNode", [cuBLAS 等外部调用], "blue"),
    ([其他], "NotImplementedError", [], "muted"),
  )
  for (i, (src, dst, note, tone)) in maps.enumerate() {
    let y = -i * 34
    content((0, y), txt(src, size: 7pt, fill: c.ink), anchor: "west")
    pill((210, y), raw(dst), tone: tone, size: 6.8pt, name: "m" + str(i))
    arrow((128, y), "m" + str(i) + ".west")
    content((210, y - 10), txt(note, size: 6.3pt), anchor: "north")
  }

  let x0 = 340
  content((x0, 18), tag("Scheduler._init", fill: c.ink), anchor: "west")
  let steps = (
    ("compute_dependencies", [从 MemoryDep 建出读写依赖]),
    ("topological_sort_schedule", [按依赖排出合法顺序]),
    ("dead_node_elimination", [删掉不影响输出的节点]),
    ("compute_ancestors", [记下每个节点的祖先：查环、分辨 vertical]),
    ("compute_input_distances", [到 graph 输入的距离]),
    ("fuse_nodes", [融合，见下一节]),
  )
  for (i, (f, note)) in steps.enumerate() {
    let y = -i * 22
    pill((x0 + 4, y), raw(f), tone: if i == 5 { "orange" } else { "blue" }, size: 6.5pt, anchor: "west", name: "i" + str(i))
    if i > 0 { arrow((x0 + 14, y + 22 - 7), (x0 + 14, y + 7)) }
  }
  content((x0 + 4, -6 * 22 - 2), box(width: 200pt, txt([`compute_ancestors` 给融合的合法性检查用：node2 不能是 node1 的祖先，融合后也不能成环], size: 6.3pt)), anchor: "north-west")
})

// ============================================================================
// Rounds of fusion: op1 -> op2 -> op3
// ============================================================================

#let fig-fusion-rounds() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let chain(y, items, hot) = {
    let x = 0
    for (i, (body, w)) in items.enumerate() {
      rect((x, y + 11), (x + w, y - 11), fill: if i == hot { c.orange1 } else { white },
        stroke: .8pt + if i == hot { c.orange } else { c.blue }, radius: 5)
      content((x + w / 2, y), txt(body, size: 7pt, fill: c.ink, weight: 600))
      if i + 1 < items.len() { arrow((x + w, y), (x + w + 16, y)) }
      x += w + 16
    }
  }
  chain(0, (([op1], 46), ([op2], 46), ([op3], 46)), none)
  chain(-48, (([Fused(op1, op2)], 104), ([op3], 46)), 0)
  chain(-96, (([Fused(Fused(op1, op2), op3)], 168),), 0)
  arrow((70, -13), (70, -35), color: c.orange)
  arrow((70, -61), (70, -83), color: c.orange)
  content((76, -24), txt([合并分数最高的 (op1, op2)], size: 6.8pt, fill: c.orange), anchor: "west")
  content((76, -72), txt([(op2, op3) 变成 (Fused(op1, op2), op3)，重新 `can_fuse`], size: 6.8pt, fill: c.orange), anchor: "west")
  let x0 = 300
  content((x0, 14), tag("每轮", fill: c.ink), anchor: "west")
  let notes = (
    [候选只在一轮开始时算一次；],
    [合并后，候选里的旧节点用 `get_fused_node` 换成它所在的新节点，],
    [所以同一轮里可以接连合并；],
    [开始时不是候选的新组合要等下一轮。],
    [节点数不再减少、或只剩 1 个时停止，最多 10 轮。],
  )
  for (i, s) in notes.enumerate() {
    content((x0, -4 - i * 15), txt(s, size: 6.8pt), anchor: "west")
  }
})

// ============================================================================
// Comparing two candidates with FusionScore
// ============================================================================

#let fig-fusion-score() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let q(y, num, body, out) = {
    rect((0, y), (250, y - 30), fill: white, stroke: .8pt + c.blue, radius: 3)
    content((10, y - 15), txt([#num #body], size: 7.3pt, fill: c.ink), anchor: "west")
    arrow((250, y - 15), (276, y - 15), color: c.orange)
    content((282, y - 15), txt(out, size: 7.3pt, fill: c.orange), anchor: "west")
  }
  content((0, 16), tag("A、B 两个候选谁先融合", fill: c.ink), anchor: "west")
  q(0, [①], [`template_score` 不同？], [大的先：普通 2 > epilogue 1 > prologue 0])
  arrow((125, -30), (125, -44))
  content((130, -37), txt("相同", size: 6.5pt), anchor: "west")
  q(-44, [②], [`memory_score` 相差 16 倍以上？], [省字节多的先])
  arrow((125, -74), (125, -88))
  content((130, -81), txt("否", size: 6.5pt), anchor: "west")
  q(-88, [③], [依次比较这四项], [第一个不同的项决定])
  let ks = ([`node_type_score`], [`memory_score`], [`buffer_overlap_score`], [`proximity_score`])
  for (i, k) in ks.enumerate() {
    pill((40 + i * 128, -138), k, tone: if i == 0 { "orange" } else { "blue" }, size: 6.8pt, name: "k" + str(i))
    if i > 0 { content((40 + i * 128 - 64, -138), txt(">", size: 9pt, fill: c.muted)) }
  }
  arrow((125, -118), (125, -127))
  content((0, -156), txt([同类节点（都是或都不是 reduction）优先于省的字节数，除非字节数相差悬殊（②）], size: 6.8pt), anchor: "north-west")
})

// ============================================================================
// Prerequisites: size / stride and the index expressions in MemoryDep
// ============================================================================

#let fig-stride() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (cw, ch) = (26, 18)
  // A logical [3, 4] grid; `val(i, j)` is the label, (hi, hj) is highlighted.
  let grid(x0, y0, val, hi, hj, name) = {
    for i in range(3) {
      for j in range(4) {
        let hot = i == hi and j == hj
        rect((x0 + j * cw, y0 - i * ch), (x0 + (j + 1) * cw, y0 - (i + 1) * ch),
          fill: if hot { c.orange1 } else { white }, stroke: .5pt + if hot { c.orange } else { c.hair },
          name: if hot { name } else { none })
        content((x0 + j * cw + cw / 2, y0 - i * ch - ch / 2), txt(str(val(i, j)), size: 7pt, fill: c.ink))
      }
    }
  }
  // A strip of memory cells, (hk) highlighted.
  let strip(x0, y0, n, hk, name) = {
    for k in range(n) {
      let hot = k == hk
      rect((x0 + k * 22, y0), (x0 + (k + 1) * 22, y0 - 16),
        fill: if hot { c.orange1 } else { c.grey1 }, stroke: .5pt + white, name: if hot { name } else { none })
      content((x0 + k * 22 + 11, y0 - 8), txt(str(k), size: 6.5pt, fill: c.ink))
    }
  }

  // x: contiguous [3, 4].
  content((0, 18), tag("x：size [3, 4]，stride [4, 1]", fill: c.ink), anchor: "west")
  grid(0, 0, (i, j) => 4 * i + j, 1, 2, "xg")
  content((52, -60), txt([格子里是 offset = 4·i + j], size: 6.5pt), anchor: "north")
  strip(170, -10, 12, 6, "xs")
  content((170, 2), txt([内存（一维）], size: 6.5pt), anchor: "west")
  curve-arrow("xg.east", "xs.north", (150, -20), (290, 10), color: c.orange)
  content((300, -32), txt([`x[1, 2]` → offset 6。换成 `[1024, 1024]` 就是日志里的 `1024*d0 + d1`], size: 6.5pt, fill: c.orange), anchor: "west")

  // bias broadcast to [3, 4]: stride 0 on dim 0.
  let y1 = -108
  content((0, y1 + 18), tag("bias 广播成 [3, 4]：stride [0, 1]", fill: c.ink), anchor: "west")
  grid(0, y1, (i, j) => j, 2, 2, "bg")
  content((52, y1 - 60), txt([每一行读同样的 4 个元素], size: 6.5pt), anchor: "north")
  strip(170, y1 - 10, 4, 2, "bs")
  content((170, y1 + 2), txt([内存], size: 6.5pt), anchor: "west")
  curve-arrow("bg.east", "bs.south", (160, y1 - 50), (230, y1 - 50), color: c.orange)
  content((270, y1 - 18), txt([`bias[2, 2]` → offset 2。index 里没有 `d0`：`MemoryDep('arg1_1', d1)`], size: 6.5pt, fill: c.orange), anchor: "west")
})

// ============================================================================
// Prerequisites: why fusing two nodes can create a cycle
// ============================================================================

#let fig-fusion-cycle() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  content((0, 40), tag("原图", fill: c.ink), anchor: "west")
  pill((20, 0), raw("A"), name: "a")
  pill((90, 0), raw("B"), name: "b")
  pill((160, 0), raw("C"), name: "c")
  arrow("a.east", "b.west")
  arrow("b.east", "c.west")
  curve-arrow("a.north", "c.north", (60, 30), (120, 30))
  content((90, -14), txt([A → B → C，另有 A → C], size: 6.8pt), anchor: "north")

  let x0 = 260
  content((x0, 40), tag("把 A 和 C 合成一个 kernel", fill: c.ink), anchor: "west")
  rect((x0, 12), (x0 + 110, -12), fill: c.orange1, stroke: .8pt + c.orange, radius: 6, name: "f")
  content((x0 + 55, 0), txt([Fused(A, C)], size: 7.5pt, fill: c.ink, weight: 600))
  pill((x0 + 200, 0), raw("B"), name: "b2")
  curve-arrow((x0 + 110, 6), "b2.north-west", (x0 + 140, 22), (x0 + 170, 22), color: c.danger)
  curve-arrow("b2.south-west", (x0 + 110, -6), (x0 + 170, -22), (x0 + 140, -22), color: c.danger)
  content((x0 + 155, 22), txt([B 要 A 的结果], size: 6.5pt, fill: c.danger), anchor: "south")
  content((x0 + 155, -22), txt([C 要 B 的结果], size: 6.5pt, fill: c.danger), anchor: "north")
  content((x0 + 110, -40), txt([两个 kernel 互相等待：`will_fusion_create_cycle` 拒绝], size: 6.8pt), anchor: "north")
})
