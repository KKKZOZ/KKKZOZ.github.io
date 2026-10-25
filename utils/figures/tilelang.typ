// Detailed figures for content/posts/ml-systems/gpu-kernels/tilelang-programming-model.typ,
// drawn with cetz. Each `fig-*` function returns one canvas; coordinates are in
// points (1pt per unit, y grows upward) and every figure stays under ~560pt
// wide, so it renders at true scale in the 760px column.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": box-swatch, c, legend, tag, txt

// One fill per GPU thread, for figures that colour work by owner.
#let thread-fill = (c.teal2, c.orange2, c.blue2, c.grey2)

/// 4 threads copy 16 cells: contiguous chunks (vectorisable) vs strided rounds.
#let fig-copy-partition() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = 24
  let cells(y, owner) = for i in range(16) {
    rect((i * w, y), (i * w + w, y + 22), fill: thread-fill.at(owner(i)), stroke: .5pt + white)
    content((i * w + w / 2, y + 11), txt(str(i), fill: c.ink))
  }
  let brace(x0, x1, y, body) = {
    line((x0 + 3, y), (x1 - 3, y), stroke: .7pt + c.line)
    content(((x0 + x1) / 2, y - 9), txt(body, fill: c.ink))
  }
  content((0, 128), tag("Kernel 1 · block view", fill: c.blue), anchor: "west")
  content((0, 114), txt("thread t takes cells 4t … 4t + 3"), anchor: "west")
  cells(80, i => calc.quo(i, 4))
  for t in range(4) { brace(t * 4 * w, (t + 1) * 4 * w, 74, "t" + str(t)) }
  content((16 * w + 10, 91), txt("1 × uint2 load / thread"), anchor: "west")
  content((0, 44), tag("Kernel 2 · thread view", fill: c.blue), anchor: "west")
  content((0, 30), txt("in round i, thread t takes cell 4i + t"), anchor: "west")
  cells(-4, i => calc.rem(i, 4))
  for r in range(4) { brace(r * 4 * w, (r + 1) * 4 * w, -10, "i = " + str(r)) }
  content((16 * w + 10, 7), txt("4 scalar loads / thread"), anchor: "west")
  for t in range(4) { legend(t * 56, -40, "t" + str(t), box-swatch(t * 56, -40, thread-fill.at(t))) }
})

/// Who owns local, shared and fragment buffers.
#let fig-alloc-scopes() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let threads(x0) = for t in range(4) {
    rect((x0 + t * 36, 0), (x0 + t * 36 + 30, 18), fill: thread-fill.at(t), stroke: none, radius: 3)
    content((x0 + t * 36 + 15, 9), txt("t" + str(t), fill: c.ink, weight: 600))
  }
  let link(x0, t, x1) = line((x0 + t * 36 + 15, 18), (x1, 46), stroke: .7pt + c.line)
  let head(x0, name, sub) = {
    content((x0, 98), tag(name, fill: c.blue), anchor: "west")
    content((x0, 84), txt(sub), anchor: "west")
  }
  // local
  head(0, "alloc_local", "private")
  threads(0)
  for t in range(4) {
    link(0, t, t * 36 + 15)
    rect((t * 36, 46), (t * 36 + 30, 68), fill: c.grey1, stroke: .5pt + c.line)
    content((t * 36 + 15, 57), txt("reg", fill: c.ink))
  }
  content((0, -12), txt("invisible to other threads", size: 7pt), anchor: "west")
  // shared
  let x0 = 180
  head(x0, "alloc_shared", "one copy per block")
  threads(x0)
  for t in range(4) { link(x0, t, x0 + t * 36 + 15) }
  rect((x0, 46), (x0 + 138, 68), fill: c.blue1, stroke: .7pt + c.blue)
  content((x0 + 69, 57), txt("shared memory", fill: c.ink, weight: 600))
  content((x0, -12), txt("all threads, same address", size: 7pt), anchor: "west")
  // fragment
  let x0 = 360
  let seg = 138 / 4
  head(x0, "alloc_fragment", "distributed")
  threads(x0)
  rect((x0 - 4, 42), (x0 + 142, 72), stroke: (paint: c.grey2, dash: "dashed", thickness: .7pt))
  for t in range(4) {
    link(x0, t, x0 + t * seg + seg / 2)
    rect((x0 + t * seg, 46), (x0 + t * seg + seg, 68), fill: thread-fill.at(t), stroke: .5pt + white)
    content((x0 + t * seg + seg / 2, 57), text(9pt, $a_#t$))
  }
  content((x0, -12), txt("one logical tile, held in registers", size: 7pt), anchor: "west")
})

/// Where tile ops and elementwise ops may appear.
#let fig-op-scopes() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  rect((0, 0), (360, 176), fill: c.panel, stroke: .7pt + c.line, radius: 3)
  content((10, 162), txt("Block scope · T.Kernel body", size: 9pt, fill: c.ink, weight: 700), anchor: "west")
  content((10, 145), txt("tile ops: T.copy T.clear T.fill T.gemm", fill: c.ink), anchor: "west")
  content((10, 131), txt("collective: all threads of the block cooperate"), anchor: "west")
  rect((14, 12), (346, 118), fill: c.blue1, stroke: .7pt + c.blue, radius: 3)
  content((24, 104), txt("T.Parallel · thread-level boundary", size: 9pt, fill: c.ink, weight: 700), anchor: "west")
  content((24, 88), txt("elementwise only: arithmetic, assignment", fill: c.ink), anchor: "west")
  content((24, 74), txt("each thread runs on its own, no coordination"), anchor: "west")
  rect((28, 22), (332, 60), fill: c.teal1, stroke: .7pt + c.teal, radius: 3)
  content((38, 48), txt("T.serial", size: 9pt, fill: c.ink, weight: 700), anchor: "west")
  content((38, 33), txt("sequential loop inside one thread"), anchor: "west")
  // the illegal nesting
  content((400, 150), tag("does not compile", fill: c.danger), anchor: "west")
  rect((400, 60), (550, 130), fill: c.blue1, stroke: .7pt + c.blue, radius: 3)
  content((410, 118), txt("T.Parallel", fill: c.ink, weight: 700), anchor: "west")
  rect((416, 72), (526, 100), fill: c.orange1, stroke: .7pt + c.danger, radius: 3)
  content((471, 86), txt("T.copy", size: 9pt, fill: c.ink, weight: 600))
  line((533, 80), (543, 92), stroke: 1.4pt + c.danger)
  line((533, 92), (543, 80), stroke: 1.4pt + c.danger)
  content((400, 44), txt("a collective op inside", size: 7pt), anchor: "west")
  content((400, 32), txt("a thread-level boundary", size: 7pt), anchor: "west")
})
