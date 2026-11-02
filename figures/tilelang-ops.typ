// Detailed figures for content/posts/ml-systems/gpu-kernels/tilelang-production-ready-ops.typ,
// drawn with cetz. Each `fig-*` function returns one canvas; coordinates are in
// points (1pt per unit, y grows upward) and every figure stays under ~560pt
// wide, so it renders at true scale in the 760px column.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, pill, tag, txt

/// A rectangle from `a` to `b` holding a few centred lines of text.
#let block(a, b, lines, bg: c.blue1, edge: c.blue) = {
  import cetz.draw: *
  rect(a, b, fill: bg, stroke: .7pt + edge, radius: 3)
  let (cx, cy) = ((a.at(0) + b.at(0)) / 2, (a.at(1) + b.at(1)) / 2)
  for (i, l) in lines.enumerate() {
    content((cx, cy + (lines.len() - 1) * 6 - i * 12), l)
  }
}

// ============================================================================
// Kernel caching
// ============================================================================

/// Workload, schedule and runtime arguments bind one after another.
#let fig-binding-stages() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let stage(a, b, bound, step) = {
    arrow(a, b)
    let mid = ((a.at(0) + b.at(0)) / 2, 0)
    content((mid.at(0), 10), txt(bound, fill: c.ink, weight: 600))
    content((mid.at(0), -10), txt(step, style: "italic"))
  }
  pill((56, 0), "_rms_norm_kernel", name: "f")
  content((56, -22), txt("factory, cached by lru_cache", size: 7pt))
  stage((108, 0), (196, 0), "M, N, eps, dtype", "① workload")
  pill((232, 0), "JITImpl", name: "impl", tone: "orange")
  content((232, -22), txt("one fixed problem", size: 7pt))
  stage((262, 0), (350, 0), "block_m, threads", "② schedule")
  pill((390, 0), "JITKernel", name: "kern", tone: "teal")
  content((390, -22), txt("one compiled variant", size: 7pt))
  stage((424, 0), (500, 0), "x, weight", "③ runtime")
  pill((516, 0), "y", tone: "dark")
})

/// The call path and the cache consulted at each step.
#let fig-lookup-chain() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let rows = (
    ("forward(x, weight)", "dark"),
    ("M from x.shape", "blue"),
    ("_get_kernel(M)", "pale"),
    ("_rms_norm_kernel(M, N, eps, dtype)", "orange"),
    ("JITImpl(block_m, threads)", "teal"),
    ("JITKernel(x, weight) → launch", "blue"),
  )
  for (i, (body, tone)) in rows.enumerate() {
    pill((110, -i * 36), body, name: "r" + str(i), tone: tone)
    if i > 0 { arrow("r" + str(i - 1) + ".south", "r" + str(i) + ".north") }
  }
  let caches = (
    (2, "L3 · per Op · self._kernel_cache", "M → RMSNormKernel", c.blue1, c.blue),
    (3, "L2 · per process · lru_cache(32)", "(M, N, eps, dtype) → JITImpl", c.orange1, c.orange),
    (4, "L1 · TileLang · memory + disk", "(workload, schedule, target) → JITKernel", c.teal1, c.teal),
  )
  for (i, title, map, bg, edge) in caches {
    let y = -i * 36
    arrow("r" + str(i) + ".east", (270, y), dash: "dashed", head: false)
    block((270, y - 15), (510, y + 15), (txt(title, fill: c.ink, weight: 600), txt(map, size: 7pt)), bg: bg, edge: edge)
  }
  content((270, -200), txt("lookup order L3 → L2 → L1: a hit skips all the work below it", style: "italic"))
})

/// Six RMSNorm Ops in three blocks share two JITImpls and two compiled kernels.
#let fig-transformer-cache() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (py, dy) = (125, 45)
  content((0, 196), tag("L3 · 6 Ops, 12 kernels", fill: c.blue), anchor: "west")
  content((240, 196), tag("L2 · 2 JITImpl", fill: c.orange), anchor: "west")
  content((380, 196), tag("L1 · 2 JITKernel", fill: c.teal), anchor: "west")
  for b in range(3) {
    for (k, name) in ("attention_norm", "ffn_norm").enumerate() {
      let y = 150 - (b * 2 + k) * 30
      block((0, y), (116, y + 24), (txt("B" + str(b) + " · " + name, fill: c.ink),), bg: white)
      rect((120, y + 12), (148, y + 24), fill: c.orange1, stroke: .5pt + c.orange)
      content((134, y + 18), txt("128", size: 6.5pt, fill: c.ink))
      rect((120, y), (148, y + 12), fill: c.teal1, stroke: .5pt + c.teal)
      content((134, y + 6), txt("1", size: 6.5pt, fill: c.ink))
      arrow((148, y + 18), (240, py), color: c.orange, w: .5pt, head: false)
      arrow((148, y + 6), (240, dy), color: c.teal, w: .5pt, head: false)
    }
  }
  block((240, py - 15), (336, py + 15), (txt("JITImpl P", fill: c.ink, weight: 600),), bg: c.orange1, edge: c.orange)
  content((288, py - 25), txt("(128, 4096, 1e-5, bf16)", size: 6.5pt))
  block((240, dy - 15), (336, dy + 15), (txt("JITImpl D", fill: c.ink, weight: 600),), bg: c.teal1, edge: c.teal)
  content((288, dy - 25), txt("(1, 4096, 1e-5, bf16)", size: 6.5pt))
  arrow((336, py), (380, py))
  block((380, py - 15), (476, py + 15), (txt("JITKernel P", fill: c.ink, weight: 600),), bg: c.orange1, edge: c.orange)
  content((428, py - 25), txt("CUDA for config P", size: 6.5pt))
  arrow((336, dy), (380, dy))
  block((380, dy - 15), (476, dy + 15), (txt("JITKernel D", fill: c.ink, weight: 600),), bg: c.teal1, edge: c.teal)
  content((428, dy - 25), txt("CUDA for config D", size: 6.5pt))
  legend(0, -18, "prefill · M = 128", box-swatch(0, -18, c.orange1, stroke: .5pt + c.orange))
  legend(140, -18, "decode · M = 1", box-swatch(140, -18, c.teal1, stroke: .5pt + c.teal))
})

// ============================================================================
// torch.compile
// ============================================================================

/// One global custom op; instance_key finds the calling Op again.
#let fig-instance-registry() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  block((0, 70), (116, 104), (txt("op1", fill: c.ink, weight: 600), txt("N=2048, eps=1e-6", size: 7pt)), bg: white)
  block((0, 10), (116, 44), (txt("op2", fill: c.ink, weight: 600), txt("N=4096, eps=1e-5", size: 7pt)), bg: white)
  block((190, 30), (350, 84), (txt("tilelang_ops::rms_norm", fill: c.ink, weight: 600), txt("(x, weight, instance_key)", size: 7pt)))
  content((270, 96), txt("one global Dispatcher op, no self", size: 7pt))
  arrow((116, 87), (190, 66))
  content((150, 90), txt("\"140001\"", size: 7pt, fill: c.orange))
  arrow((116, 27), (190, 48))
  content((150, 24), txt("\"140002\"", size: 7pt, fill: c.orange))
  arrow((350, 57), (414, 57))
  content((382, 66), txt("get_instance", size: 7pt))
  block((414, 22), (534, 92), (txt("registry", fill: c.ink, weight: 600), txt("\"140001\" → op1", fill: c.ink), txt("\"140002\" → op2", fill: c.ink)), bg: c.orange1, edge: c.orange)
  arrow((474, 22), (474, -14))
  pill((474, -24), "op._eager_forward(x, weight)", tone: "teal")
  content((474, -44), txt("the Op's own caches, then the kernel", size: 7pt))
})

/// What Dynamo records, and the two implementations behind the opaque node.
#let fig-compile-boundary() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  content((0, 262), tag("FX graph · what Dynamo records", fill: c.blue), anchor: "west")
  pill((70, 232), "aten ops", name: "a1", tone: "muted")
  pill((250, 232), "tilelang_ops.rms_norm", name: "op", tone: "dark")
  pill((430, 232), "aten ops", name: "a2", tone: "muted")
  arrow("a1.east", "op.west")
  arrow("op.east", "a2.west")
  rect((0, -24), (500, 190), stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed"), radius: 4)
  arrow((200, 223), (200, 204), (130, 204), (130, 162))
  content((150, 212), txt("trace · FakeTensor", style: "italic"), anchor: "east")
  arrow((300, 223), (300, 204), (370, 204), (370, 162))
  content((350, 212), txt("run · compiled graph", style: "italic"), anchor: "west")
  // trace path
  pill((130, 152), "register_fake", name: "f1")
  pill((130, 104), "torch.empty_like(x)", name: "f2")
  arrow("f1.south", "f2.north")
  content((130, 82), txt("shape / dtype / device only", size: 7pt))
  content((130, 70), txt("no registry, no GPU work", size: 7pt))
  // run path
  pill((370, 152), "_rms_norm_wrapped(x, weight, key)", name: "r1")
  pill((370, 104), "get_instance(key)._eager_forward", name: "r2")
  pill((370, 56), "_get_kernel → JITImpl → JITKernel", name: "r3", tone: "orange")
  pill((370, 8), "launch TileLang kernel → y", name: "r4", tone: "teal")
  arrow("r1.south", "r2.north")
  arrow("r2.south", "r3.north")
  arrow("r3.south", "r4.north")
  content((10, 0), txt("custom-op boundary:", size: 7pt), anchor: "west")
  content((10, -12), txt("Dynamo never traces inside", size: 7pt), anchor: "west")
})
