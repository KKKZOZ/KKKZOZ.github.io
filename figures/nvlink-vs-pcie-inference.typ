// Figures for content/posts/ml-systems/nvlink-vs-pcie-inference.typ, drawn with cetz.
// All numbers are measured (vllm-032 experiment records). One colour per link
// throughout: orange for A100 NVLink, blue for A100 PCIe across sockets, grey
// (dashed) for the RTX A6000 across sockets.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, seg, tag, txt

#let grid-stroke = (paint: c.hair, thickness: .5pt, dash: "dotted")
#let axis-stroke = .6pt + c.line

/// Legend swatch for a data line: a plain stroke, no arrow head.
#let line-swatch(x, y, color, dash: none) = cetz.draw.line((x, y), (x + 12, y), stroke: (paint: color, thickness: 1.5pt, dash: dash))

/// One decimal, also for whole numbers: 8 -> "8.0".
#let fmt1(v) = { let s = str(v); if s.contains(".") { s } else { s + ".0" } }

/// A line through `pts` with a dot on each point.
#let series(pts, color, dash: none, dots: true) = {
  import cetz.draw: *
  line(..pts, stroke: (paint: color, thickness: 1.5pt, dash: dash, join: "round"))
  if dots { for p in pts { circle(p, radius: 1.8, fill: color, stroke: .8pt + white) } }
}

// ============================================================================
// NCCL transports and NCCL_P2P_LEVEL
// ============================================================================

// One socket of the transport figure, drawn at x offset `ox`: DDR above,
// cores and memory controller on the on-die fabric, a PCIe host bridge below
// it, and the GPU on that bridge. `tr-base` draws the package and its wiring,
// `tr-parts` the boxes, so that a path drawn between the two runs under them.
#let tr = (fab: -58, hb-t: -72, hb-b: -92, pkg-b: -104, gpu-y: -140, mc-x: 172, hb-x: 112, core-x: 56)

#let tr-base(ox, name) = {
  import cetz.draw: *
  line((ox + tr.mc-x, 14), (ox + tr.mc-x, 0), stroke: 1pt + c.grey2)
  rect((ox, 0), (ox + 228, tr.pkg-b), fill: c.blue1, stroke: .8pt + c.blue, radius: 3)
  content((ox + 8, -10), txt(name, size: 8.5pt, fill: c.ink, weight: 700), anchor: "west")
  line((ox + tr.core-x, -42), (ox + tr.core-x, tr.fab), stroke: .8pt + c.blue2)
  line((ox + tr.mc-x, -42), (ox + tr.mc-x, tr.fab), stroke: .8pt + c.blue2)
  line((ox + 6, tr.fab), (ox + 222, tr.fab), stroke: 2.4pt + c.blue2)
  content((ox + 8, tr.fab - 8), txt("on-die fabric", size: 6.5pt, style: "italic"), anchor: "west")
  line((ox + tr.hb-x, tr.fab), (ox + tr.hb-x, tr.hb-t), stroke: 1.2pt + c.blue2)
  line((ox + tr.hb-x, tr.hb-b), (ox + tr.hb-x, tr.gpu-y + 13), stroke: .9pt + c.line)
  content((ox + tr.hb-x + 8, (tr.pkg-b + tr.gpu-y + 13) / 2), txt("PCIe", size: 6.5pt, style: "italic"), anchor: "west")
}

/// `hot`: parts on a path, among "hb", "mc", "ddr", "gpu".
#let tr-parts(ox, node, gpu-name, hot: ()) = {
  import cetz.draw: *
  let on(k) = k in hot
  let part(x0, y0, x1, y1, body, k, cold-fill: white, cold-stroke: .7pt + c.blue) = {
    rect((ox + x0, y0), (ox + x1, y1), fill: if on(k) { c.orange1 } else { cold-fill },
      stroke: if on(k) { 1.1pt + c.orange } else { cold-stroke }, radius: 2)
    content((ox + (x0 + x1) / 2, (y0 + y1) / 2), body)
  }
  part(tr.mc-x - 46, 34, tr.mc-x + 46, 14,
    txt(if on("ddr") { [DDR · node #node · *buffer*] } else { [DDR · node #node] }, size: 7pt, fill: c.ink),
    "ddr", cold-fill: c.grey1, cold-stroke: .6pt + c.grey2)
  part(tr.core-x - 34, -22, tr.core-x + 34, -42, txt("cores", size: 7.5pt, fill: c.ink, weight: 600), "cores")
  part(tr.mc-x - 42, -22, tr.mc-x + 42, -42, txt("memory controller", size: 7pt, fill: c.ink, weight: 600), "mc")
  part(tr.hb-x - 46, tr.hb-t, tr.hb-x + 46, tr.hb-b, txt("PCIe host bridge", size: 7pt, fill: c.ink, weight: 600), "hb")
  part(tr.hb-x - 30, tr.gpu-y + 13, tr.hb-x + 30, tr.gpu-y - 13, txt(gpu-name, size: 8.5pt, fill: c.ink, weight: 700),
    "gpu", cold-stroke: .8pt + c.ink)
}

/// A numbered marker on a path.
#let tr-step(pos, n, color) = {
  import cetz.draw: *
  circle(pos, radius: 6, fill: color, stroke: 1pt + white)
  content(pos, text(size: 6.5pt, weight: 700, fill: white, str(n)))
}

/// Both sockets and UPI, with `paths` drawn under the parts.
#let tr-board(dy, title, note, hot0, hot1, paths) = {
  import cetz.draw: *
  group({
    translate((0, dy))
    content((0, 52), tag(title, fill: c.ink), anchor: "west")
    tr-base(0, "CPU0")
    tr-base(292, "CPU1")
    line((228, tr.fab), (292, tr.fab), stroke: 2.4pt + c.ink)
    content((260, tr.fab + 8), txt("UPI", size: 7.5pt, fill: c.ink, weight: 600))
    paths
    tr-parts(0, 0, "GPU0", hot: hot0)
    tr-parts(292, 1, "GPU1", hot: hot1)
    content((0, tr.gpu-y - 26), txt(note, size: 7.5pt, fill: c.ink), anchor: "west")
  })
}

/// P2P and SHM between two GPUs on different sockets.
#let fig-transports() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = 2pt
  let (g, f, m, hb) = (tr.gpu-y, tr.fab, tr.mc-x, tr.hb-x)
  tr-board(0, "P2P", [One transfer: host bridge, fabric, UPI, fabric, host bridge. No core, memory controller or DRAM.],
    ("hb", "gpu"), ("hb", "gpu"), {
      line((hb, g), (hb, f), (292 + hb, f), (292 + hb, g), stroke: w + c.orange)
    })
  // SHM: the buffer is drawn in node 0's memory, so the read crosses UPI.
  tr-board(-240, "SHM", [Two transfers through a buffer in host memory, here on node 0. The data crosses PCIe twice and passes through DRAM.],
    ("hb", "mc", "ddr", "gpu"), ("hb", "gpu"), {
      line((hb, g), (hb, f), (m - 3, f), (m - 3, 24), stroke: w + c.orange)
      line((m + 3, 24), (m + 3, f), (292 + hb, f), (292 + hb, g), stroke: w + c.blue)
      tr-step((hb - 14, (tr.pkg-b + g + 13) / 2), 1, c.orange)
      tr-step((292 + hb - 14, (tr.pkg-b + g + 13) / 2), 2, c.blue)
    })
  let ly = -240 + tr.gpu-y - 50
  let sw(x, y, col) = line((x, y), (x + 12, y), stroke: 2pt + col)
  legend(0, ly, [1: GPU0 writes into the buffer], sw(0, ly, c.orange))
  legend(170, ly, [2: GPU1 reads it out], sw(170, ly, c.blue))
})

/// The ladder NCCL_P2P_LEVEL cuts, and where the measured pairs sit on it.
#let fig-p2p-level() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw) = (128, 64)
  let levels = (("NVL", "NVLink"), ("PIX", "one switch"), ("PXB", "switches"), ("PHB", "one CPU"), ("SYS", "two CPUs"))
  let cx(k) = x0 + (k + .5) * cw
  for (k, (l, d)) in levels.enumerate() {
    content((cx(k), 30), txt(l, size: 8.5pt, fill: c.ink, weight: 700))
    content((cx(k), 18), txt(d, size: 7pt))
  }
  content((x0 - 8, 30), txt("nearest", size: 7pt), anchor: "east")
  content((x0 + 5 * cw + 8, 30), txt("farthest", size: 7pt), anchor: "west")
  for k in range(6) {
    line((x0 + k * cw, 10), (x0 + k * cw, -118), stroke: grid-stroke)
  }
  // Which levels may use P2P.
  let bar(y, k1, label, note, fill, stroke) = {
    rect((x0 + 3, y), (x0 + (k1 + 1) * cw - 3, y - 14), fill: fill, stroke: .7pt + stroke, radius: 2)
    content((x0 - 8, y - 7), txt(label, size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
    content((x0 + (k1 + 1) * cw + 8, y - 7), txt(note, size: 7pt), anchor: "west")
  }
  bar(0, 2, "Default", [P2P up to `PXB`], c.blue1, c.blue)
  bar(-20, 4, [`NCCL_P2P_LEVEL=SYS`], [P2P up to `SYS`], c.orange1, c.orange)
  // The measured pairs.
  let pairs = (
    ("A100 GPU0–1", 0, "P2P in both"),
    ("A6000 GPU0–1", 4, "SHM → P2P"),
    ("A100 GPU1–2", 4, "SHM → P2P"),
  )
  for (i, (name, k, note)) in pairs.enumerate() {
    let y = -60 - i * 20
    content((x0 - 8, y), txt(name, size: 7.5pt, fill: c.ink), anchor: "east")
    line((x0, y), (cx(k), y), stroke: (paint: c.grey2, thickness: .6pt, dash: "dotted"))
    circle((cx(k), y), radius: 3.5, fill: if k <= 2 { c.blue } else { c.orange }, stroke: 1pt + white)
    content((x0 + 5 * cw + 8, y), txt(note, size: 7pt, fill: c.ink), anchor: "west")
  }
  content((x0 - 8, -44), txt("Measured pairs", size: 7pt), anchor: "east")
})

// ============================================================================
// One pool for attention KV and GDN state
// ============================================================================

#let fig-kv-pool() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let page(x, fill, stroke, title, l1, l2) = {
    rect((x, 0), (x + 222, -54), fill: fill, stroke: .8pt + stroke, radius: 3)
    content((x + 10, -12), txt(title, size: 8.5pt, fill: c.ink, weight: 700), anchor: "west")
    content((x + 10, -28), txt(l1, size: 7.5pt), anchor: "west")
    content((x + 10, -42), txt(l2, size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
  }
  page(0, c.orange1, c.orange, "Attention page, one layer",
    [1568 tokens × 2 KV heads × 256 × (K, V) × 1 B], [1,605,632 B])
  content((246, -27), text(size: 14pt, fill: c.muted, "="))
  page(270, c.teal1, c.teal, "GDN page, one layer",
    [24 heads × 128 × 128 × 4 B + 30 KiB conv state], [1,603,584 B, padded by 0.13%])

  // The pool: one block = one page in each of a group's 16 layers.
  let (w, h, y0) = (16, 18, -96)
  let kinds = ("a",) * 2 + ("g",) * 6 + ("a",) * 7 + ("g",) * 6 + ("f",) * 9
  let gdn = ("G1", "G1", "G2", "G2", "G3", "G3")
  content((0, y0 + 10), txt([Block pool on one GPU. A block is one page in each of a group’s 16 layers: 25.7 MB.], size: 7.5pt, fill: c.ink), anchor: "west")
  let gi = 0
  for (i, k) in kinds.enumerate() {
    let x = i * w
    let (fill, stroke) = if k == "a" { (c.orange1, c.orange) } else if k == "g" { (c.teal1, c.teal) } else { (white, c.grey2) }
    rect((x + .8, y0), (x + w - .8, y0 - h), fill: fill, stroke: .7pt + stroke, radius: 1.5)
    let label = if k == "a" { "A" } else if k == "g" { gdn.at(calc.rem(gi, 6)) } else { none }
    if k == "g" { gi += 1 }
    if label != none { content((x + w / 2, y0 - h / 2), txt(label, size: 6pt, fill: c.ink, weight: 600)) }
  }
  // Which blocks belong to which request.
  let brace(i0, i1, body) = {
    let (xa, xb, y) = (i0 * w + 1, i1 * w - 1, y0 - h - 6)
    line((xa, y + 3), (xa, y), (xb, y), (xb, y + 3), stroke: .6pt + c.line)
    content(((xa + xb) / 2, y - 4), txt(body, size: 7pt), anchor: "north")
  }
  brace(0, 8, [3,000 tokens: 2 + 6 blocks])
  brace(8, 21, [10,000 tokens: 7 + 6 blocks])
  brace(21, 30, [free])

  let ly = y0 - h - 40
  legend(0, ly, [A: the 16 full-attention layers, one block per 1568 tokens], box-swatch(0, ly, c.orange1, stroke: .7pt + c.orange))
  legend(0, ly - 16, [G1–G3: three groups of 16 GDN layers, a fixed number of blocks per sequence], box-swatch(0, ly - 16, c.teal1, stroke: .7pt + c.teal))
})

// ============================================================================
// All-reduce time against message size
// ============================================================================

// nccl-tests all_reduce_perf, BF16, 2 GPUs, CUDA Graph, out-of-place, mean of
// three runs; 1 KiB to 128 MiB in powers of two. Cross-socket pairs run with
// NCCL_P2P_LEVEL=SYS (P2P transport).
#let ar-nvlink = (6.58, 6.78, 7.06, 7.72, 7.92, 8.09, 8.23, 8.37, 10.77, 14.17, 35.32, 41.00, 52.81, 75.87, 131.12, 235.15, 432.27, 822.15)
#let ar-a100-pcie = (7.01, 7.26, 7.61, 8.45, 8.95, 10.87, 15.22, 33.96, 41.26, 58.26, 96.75, 168.54, 322.70, 633.53, 1249.24, 2497.91, 4967.69, 9886.57)
#let ar-a6000 = (6.58, 6.74, 7.38, 8.81, 10.76, 14.81, 23.32, 40.63, 53.68, 86.66, 149.27, 287.00, 585.39, 1175.72, 2346.34, 4661.30, 9344.24, 18674.10)

#let fig-allreduce() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, w, h) = (46, 400, 200)
  let (e0, e1) = (10, 27)
  let (l0, l1) = (.6, 4.4)
  let px(e) = x0 + (e - e0) / (e1 - e0) * w
  let py(v) = (calc.log(v, base: 10) - l0) / (l1 - l0) * h
  for (v, lab) in ((10, "10 µs"), (100, "100 µs"), (1000, "1 ms"), (10000, "10 ms")) {
    line((x0, py(v)), (x0 + w, py(v)), stroke: grid-stroke)
    content((x0 - 5, py(v)), txt(lab, size: 7pt), anchor: "east")
  }
  line((x0, 0), (x0 + w, 0), stroke: axis-stroke)
  for (e, lab) in ((10, "1 KiB"), (12, "4 KiB"), (14, "16 KiB"), (16, "64 KiB"), (18, "256 KiB"), (20, "1 MiB"), (22, "4 MiB"), (24, "16 MiB"), (26, "64 MiB")) {
    line((px(e), 0), (px(e), -3), stroke: axis-stroke)
    content((px(e), -6), txt(lab, size: 7pt), anchor: "north")
  }
  content((x0 + w / 2, -22), txt("message size", size: 7.5pt), anchor: "north")
  // The messages tensor parallelism sends.
  for (e, lab) in ((calc.log(10240, base: 2), "decode, one token: 10 KiB"), (calc.log(80 * 1048576, base: 2), "prefill, 8192 tokens: 80 MiB")) {
    line((px(e), 0), (px(e), h + 2), stroke: (paint: c.muted, thickness: .6pt, dash: "dashed"))
    content((px(e), h + 6), txt(lab, size: 7pt, fill: c.ink), anchor: "south")
  }
  let all = ((ar-a6000, c.muted, "dashed", "A6000 PCIe"), (ar-a100-pcie, c.blue, none, "A100 PCIe"), (ar-nvlink, c.orange, none, "A100 NVLink"))
  for (vals, col, dash, lab) in all {
    series(vals.enumerate().map(((i, v)) => (px(e0 + i), py(v))), col, dash: dash, dots: false)
    content((px(e1) + 6, py(vals.last())), txt(lab, size: 7pt, fill: c.ink, weight: 600), anchor: "west")
  }
  let ly = -46
  legend(x0, ly, [A100, NVLink pair], line-swatch(x0, ly, c.orange))
  legend(x0 + 120, ly, [A100, across sockets], line-swatch(x0 + 120, ly, c.blue))
  legend(x0 + 250, ly, [RTX A6000, across sockets], line-swatch(x0 + 250, ly, c.muted, dash: "dashed"))
})

// ============================================================================
// Peer copy bandwidth
// ============================================================================

#let fig-copy-bw() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, s, bh, gap) = (130, 1.25, 14, 10)
  for v in (0, 100, 200, 300) {
    line((x0 + v * s, 4), (x0 + v * s, -3 * (bh + gap) + 6), stroke: if v == 0 { axis-stroke } else { grid-stroke })
    content((x0 + v * s, -3 * (bh + gap) + 2), txt(str(v) + " GB/s", size: 7pt), anchor: "north")
  }
  let rows = (
    ("RTX A6000, across sockets", 9.75, c.muted),
    ("A100, across sockets", 18.5, c.blue),
    ("A100, NVLink pair", 278.6, c.orange),
  )
  for (i, (lab, v, col)) in rows.enumerate() {
    let y = -i * (bh + gap)
    content((x0 - 8, y - bh / 2), txt(lab, size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
    rect((x0, y), (x0 + v * s, y - bh), fill: col, stroke: none, radius: 1.5)
    content((x0 + v * s + 5, y - bh / 2), txt(str(v) + " GB/s", size: 7.5pt, fill: c.ink), anchor: "west")
  }
})

// ============================================================================
// RTX A6000: TP=1 and TP=2
// ============================================================================

// Steady decode speed of one request (tok/s), 1K..128K input, 128 output
// tokens, MTP on, FP8 KV, FlashInfer; rows are concurrency 2, 4, 8. From the
// per-chunk token intervals in raw.json, leaving out every interval over
// 0.2 s (a step stalled by another request's prefill).
#let a6-tp2 = (
  (64.0, 90.1, 80.3, 87.5, 89.8, 86.4, 79.5, 83.9),
  (58.6, 83.0, 73.8, 80.1, 81.8, 79.1, 66.7, 67.6),
  (50.6, 71.8, 63.3, 68.5, 68.8, 62.7, 52.8, 47.9),
)
#let a6-tp1 = (
  (44.8, 62.2, 56.0, 60.7, 60.9, 58.4, 51.7, 52.2),
  (41.8, 59.2, 53.6, 57.8, 56.7, 53.5, 44.1, 40.8),
  (36.1, 53.7, 47.6, 51.0, 49.4, 44.0, 34.6, 29.6),
)

#let fig-a6000-decode() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (pw, ph, gap, x0, ymax) = (148, 120, 22, 30, 100)
  let labels = ("1K", "2K", "4K", "8K", "16K", "32K", "64K", "128K")
  for (k, conc) in (2, 4, 8).enumerate() {
    let ox = x0 + k * (pw + gap)
    let px(i) = ox + i / 7 * pw
    let py(v) = v / ymax * ph
    for v in (0, 25, 50, 75, 100) {
      line((ox, py(v)), (ox + pw, py(v)), stroke: if v == 0 { axis-stroke } else { grid-stroke })
      if k == 0 { content((ox - 5, py(v)), txt(str(v), size: 7pt), anchor: "east") }
    }
    for i in (0, 3, 7) { content((px(i), -5), txt(labels.at(i), size: 7pt), anchor: "north") }
    content((ox + pw / 2, ph + 10), txt("concurrency " + str(conc), size: 7.5pt, fill: c.ink, weight: 700))
    let tp1 = a6-tp1.at(k).enumerate().map(((i, v)) => (px(i), py(v)))
    let tp2 = a6-tp2.at(k).enumerate().map(((i, v)) => (px(i), py(v)))
    series(tp1, c.muted, dash: "dashed")
    series(tp2, c.blue)
    if k == 0 {
      content((px(5), tp2.at(5).at(1) + 10), txt("TP=2", size: 7pt, fill: c.ink, weight: 600))
      content((px(5), tp1.at(5).at(1) - 11), txt("TP=1", size: 7pt, fill: c.ink, weight: 600))
    }
    if k == 2 { content((px(7) - 2, tp1.last().at(1) - 6), txt("preempted", size: 7pt, style: "italic"), anchor: "north-east") }
  }
  content((x0 + 1.5 * pw + gap, -18), txt("input tokens", size: 7.5pt), anchor: "north")
  let ly = -40
  let sw(x, y, col, dash: none) = line((x, y), (x + 12, y), stroke: (paint: col, thickness: 2pt, dash: dash))
  legend(x0, ly, [TP=2, GPU0 + GPU1], sw(x0, ly, c.blue))
  legend(x0 + 130, ly, [TP=1, GPU1], sw(x0 + 130, ly, c.muted, dash: "dashed"))
})

// Steady decode step, TP=2, 128K input, ms per step averaged over both GPUs.
#let fig-a6000-step() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, s, bh, gap) = (72, 4.5, 18, 10)
  let cats = (("linear layers", "blue2", c.blue2), ("full attention", "blue", c.blue), ("GDN", "teal2", c.teal2), ("other kernels", "grey", c.grey1), ("NCCL", "orange", c.orange))
  // (concurrency, (linear, attention, GDN, other, NCCL), idle, step)
  let rows = (
    (2, (30.11, 8.06, 1.41, 1.05, 5.64), 5.44, 51.69),
    (4, (29.21, 15.88, 2.65, 1.13, 9.34), 5.57, 63.75),
    (8, (30.31, 33.49, 4.90, 1.28, 13.06), 5.71, 88.72),
  )
  for (r, (conc, parts, idle, step)) in rows.enumerate() {
    let y = -r * (bh + gap)
    content((x0 - 8, y - bh / 2), txt("concurrency " + str(conc), size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
    let x = x0
    for (k, v) in parts.enumerate() {
      seg(x, x + v * s, y, cats.at(k).at(1), body: if v * s > 24 { str(calc.round(v, digits: 1)) } else { none }, h: bh)
      x += v * s
    }
    rect((x, y), (x + idle * s, y - bh), fill: none, stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed"))
    content((x + idle * s + 6, y - bh / 2), txt(str(calc.round(step, digits: 1)) + " ms", size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
  }
  let ly = -3 * (bh + gap) - 6
  let xs = (x0, x0 + 90, x0 + 186, x0 + 236, x0 + 330)
  for (k, (name, _, fill)) in cats.enumerate() {
    legend(xs.at(k), ly, name, box-swatch(xs.at(k), ly, fill))
  }
  legend(x0, ly - 16, [no kernel running], box-swatch(x0, ly - 16, none, stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed")))
})

// ============================================================================
// A100: NVLink over PCIe at TP=2
// ============================================================================

// Output throughput gain of GPU0+1 (NVLink) over GPU1+2 (PCIe), in %.
// Columns: concurrency 1, 2, 4, 8, 16.
#let gain-rows = (
  ("1K", (4.1, 7.1, 13.1, 21.5, 33.4)),
  ("2K", (2.2, 3.8, 8.0, 13.6, 25.6)),
  ("4K", (4.2, 6.7, 11.8, 18.6, 28.8)),
  ("8K", (2.3, 2.6, 6.5, 12.0, 22.0)),
  ("16K", (3.1, 5.1, 9.2, 14.6, 22.8)),
  ("32K", (4.8, 7.7, 12.5, 17.0, 22.5)),
  ("64K", (3.6, 6.3, 10.7, 12.5, 16.5)),
  ("128K", (2.7, 3.5, 6.0, 8.5, 8.1)),
)

#let gain-tone(v) = if v < 5 { (c.panel, c.ink) } else if v < 10 { (c.orange1, c.ink) } else if v < 20 { (c.orange2, c.ink) } else { (c.orange, white) }

#let fig-a100-gain() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, ch) = (64, 62, 20)
  content((x0 + 2.5 * cw, 30), txt("concurrency", size: 7.5pt))
  for (k, conc) in (1, 2, 4, 8, 16).enumerate() {
    content((x0 + (k + .5) * cw, 12), txt(str(conc), size: 7.5pt, fill: c.ink, weight: 700))
  }
  content((x0 - 8, 12), txt("input", size: 7.5pt), anchor: "east")
  for (r, (len, vals)) in gain-rows.enumerate() {
    let y = -r * ch
    content((x0 - 8, y - ch / 2), txt(len, size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
    for (k, v) in vals.enumerate() {
      let (fill, ink) = gain-tone(v)
      rect((x0 + k * cw, y), (x0 + (k + 1) * cw, y - ch), fill: fill, stroke: 1pt + white)
      content((x0 + (k + .5) * cw, y - ch / 2), txt("+" + fmt1(v) + "%", size: 7.5pt, fill: ink, weight: 600))
    }
  }
  let lx = x0 + 5 * cw + 24
  for (i, (lab, v)) in (("under 5%", 0), ("5–10%", 5), ("10–20%", 10), ("20% and up", 20)).enumerate() {
    let y = -(i + .5) * ch
    legend(lx, y, lab, box-swatch(lx, y, gain-tone(v).at(0)))
  }
})

// NVLink / PCIe output throughput ratio for the extra scenarios.
#let scenario-groups = (
  ("Qwen3.8-27B W8A16", (
    ("1K, c1", 1.04),
    ("8K, c16, shared prefix", 1.23), ("8K, c16, distinct", 1.37),
    ("32K, c16, shared prefix", 1.22), ("32K, c16, distinct", 1.34),
    ("1K, c128", 1.36),
  )),
  ("Qwen3-32B BF16", (("512, c128", 1.41), ("8K, c32", 1.39))),
  ("Qwen3-4B BF16", (("512, c1", 1.02), ("512, c16", 1.28), ("512, c64", 1.67), ("512, c128", 1.78), ("8K, c32", 1.68))),
)

#let fig-scenarios() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, s, rh, bh) = (150, 360, 15, 10)
  let px(r) = x0 + (r - 1) * s
  let y = 0
  let rows = ()
  for (model, items) in scenario-groups {
    rows.push((y, model, none))
    y -= 17
    for (lab, r) in items {
      rows.push((y, lab, r))
      y -= rh
    }
    y -= 4
  }
  for (r, lab) in ((1.0, "1.0×"), (1.2, "1.2×"), (1.4, "1.4×"), (1.6, "1.6×"), (1.8, "1.8×")) {
    line((px(r), 8), (px(r), y + 6), stroke: if r == 1.0 { axis-stroke } else { grid-stroke })
    content((px(r), y + 2), txt(lab, size: 7pt), anchor: "north")
  }
  for (ry, lab, r) in rows {
    if r == none {
      content((x0 - 8, ry - 6), txt(lab, size: 7.5pt, fill: c.ink, weight: 700), anchor: "east")
    } else {
      content((x0 - 8, ry - bh / 2), txt(lab, size: 7.5pt), anchor: "east")
      rect((x0, ry), (px(r), ry - bh), fill: c.orange, stroke: none, radius: 1.5)
      content((px(r) + 5, ry - bh / 2), txt(str(r) + "×", size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
    }
  }
})
