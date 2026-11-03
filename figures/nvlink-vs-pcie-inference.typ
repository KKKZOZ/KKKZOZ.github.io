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
// Bandwidth along the path between two GPUs on different sockets
// ============================================================================

/// Each link as a pipe whose height is its rated bandwidth per direction. The
/// orange band is the measured peer copy; the dashed box in a PCIe pipe is the
/// ~80% a large copy normally reaches.
#let fig-link-path() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let k = 1.4 // pt per GB/s
  let (gw, cw, nh) = (56, 60, 54)
  let xs = (0, gw + 120, gw + 120 + cw + 80, gw + 120 + cw + 80 + cw + 120)
  let node-w = (gw, cw, cw, gw)
  let rows = (
    ("Machine 1: RTX A6000, Xeon Gold 6248R", ("GPU0", "CPU0", "CPU1", "GPU1"),
      (("PCIe 3.0 x16", 15.75, true), ("UPI 10.4 GT/s,\none of two links", 20.8, false), ("PCIe 3.0 x16", 15.75, true)),
      9.75, "peer copy: 9.75 GB/s"),
    ("Machine 2: A100 GPU1 and GPU2, Xeon Platinum 8368", ("GPU1", "CPU0", "CPU1", "GPU2"),
      (("PCIe 4.0 x16", 31.5, true), ("UPI 11.2 GT/s,\none of three links", 22.4, false), ("PCIe 4.0 x16", 31.5, true)),
      18.5, "peer copy: 18.5 GB/s"),
  )
  for (r, (title, names, links, flow, flow-label)) in rows.enumerate() {
    let y = -r * 128
    content((0, y + 52), txt(title, size: 7.5pt, fill: c.ink, weight: 700), anchor: "west")
    // Pipes between the nodes.
    for (i, (name, bw, pcie)) in links.enumerate() {
      let (xa, xb) = (xs.at(i) + node-w.at(i), xs.at(i + 1))
      let h = bw * k
      rect((xa, y + h / 2), (xb, y - h / 2), fill: c.blue1, stroke: .7pt + c.blue)
      if pcie {
        let hn = .8 * h
        rect((xa, y + hn / 2), (xb, y - hn / 2), fill: none, stroke: (paint: c.blue, thickness: .7pt, dash: "dashed"))
      }
      let mid = (xa + xb) / 2
      content((mid, y + h / 2 + 3), align(center, txt([#name\ *#bw GB/s*], size: 7pt, fill: c.ink)), anchor: "south")
    }
    // The measured copy, end to end.
    let fh = flow * k
    rect((xs.at(0) + gw / 2, y + fh / 2), (xs.at(3) + gw / 2, y - fh / 2), fill: c.orange, stroke: none)
    // Nodes on top.
    for (i, n) in names.enumerate() {
      let x = xs.at(i)
      rect((x, y + nh / 2), (x + node-w.at(i), y - nh / 2), fill: white, stroke: .8pt + c.ink, radius: 3)
      content((x + node-w.at(i) / 2, y), txt(n, size: 8pt, fill: c.ink, weight: 700))
    }
    content((xs.at(3) + gw / 2, y - nh / 2 - 4), txt(flow-label, size: 7pt, fill: c.ink, weight: 600), anchor: "north-east")
  }
  let ly = -2 * 128 + 52
  legend(0, ly, [rated, per direction], box-swatch(0, ly, c.blue1, stroke: .7pt + c.blue))
  legend(130, ly, [80% of PCIe: what a large copy normally reaches], box-swatch(130, ly, none, stroke: (paint: c.blue, thickness: .7pt, dash: "dashed")))
  legend(400, ly, [measured], box-swatch(400, ly, c.orange))
})

// Host copies and peer copies on both machines, against what a large copy
// over the GPU's PCIe link normally reaches (80% of the rated speed).
// Host copies: pinned memory registered with cudaHostRegister, CPU thread and
// pages bound to one NUMA node, 256 MiB, median of three runs. (low, high) over
// the two GPUs measured; the bar is drawn to the high end.
#let copy-groups = (
  ("Machine 1", "RTX A6000 · PCIe 3.0", 12.6, (
    ("host → GPU, own node", 8.23, 8.26, "h2d"),
    ("host → GPU, other node", 8.43, 8.45, "h2d"),
    ("GPU → host, own node", 8.66, 8.71, "d2h"),
    ("GPU → host, other node", 8.01, 8.03, "d2h"),
    ("GPU → GPU, other socket", 9.75, 10.25, "p2p"),
  )),
  ("Machine 2", "A100 · PCIe 4.0", 25.2, (
    ("host → GPU, own node", 24.58, 24.63, "h2d"),
    ("host → GPU, other node", 24.58, 24.64, "h2d"),
    ("GPU → host, own node", 25.93, 26.03, "d2h"),
    ("GPU → host, other node", 25.89, 26.01, "d2h"),
    ("GPU → GPU, other socket", 18.4, 18.5, "p2p"),
  )),
)

#let fig-host-copy() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, s, bh, rh, gap) = (180, 11, 14, 19, 40)
  let tone = (h2d: (c.blue1, c.blue), d2h: (c.teal1, c.teal), p2p: (c.blue, c.blue))
  let y = 0
  let top = 0
  let bottom = 0
  for (gi, (name, sub, optimal, rows)) in copy-groups.enumerate() {
    let gy0 = y
    let gy1 = gy0 - (rows.len() - 1) * rh - bh
    // What a large copy normally reaches over this link, under the bars.
    let ox = x0 + optimal * s
    line((ox, gy0 + 6), (ox, gy1 - 4), stroke: (paint: c.danger, thickness: .9pt, dash: "dashed"))
    content((ox, gy0 + 8), txt("optimal " + str(optimal), size: 7.5pt, fill: c.danger, weight: 700), anchor: "south")
    for (lab, lo, hi, kind) in rows {
      content((x0 - 8, y - bh / 2), txt(lab, size: 7.5pt, fill: c.ink), anchor: "east")
      let (fill, stroke) = tone.at(kind)
      rect((x0, y), (x0 + hi * s, y - bh), fill: fill, stroke: .6pt + stroke)
      let val = if lo == hi { str(lo) } else { str(lo) + "–" + str(hi) }
      content((x0 + hi * s - 5, y - bh / 2), txt(val, size: 7.5pt, fill: if kind == "p2p" { white } else { c.ink }, weight: 600), anchor: "east")
      y -= rh
    }
    // Group label on the far left.
    content((0, (gy0 + gy1) / 2 + 6), txt(name, size: 9pt, fill: c.ink, weight: 700), anchor: "west")
    content((0, (gy0 + gy1) / 2 - 7), txt(sub, size: 7pt), anchor: "west")
    if gi == 0 { top = gy0 + 22 }
    y -= gap
    bottom = gy1
  }
  line((x0, top), (x0, bottom - 4), stroke: axis-stroke)
  content((x0 + 27 * s, bottom - 10), txt("GB/s, one way", size: 7.5pt), anchor: "north-east")
})

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

/// Two panels with linear time axes: small messages in µs, large ones in ms.
/// Message size doubles per step along x.
#let fig-allreduce() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (pw, ph, gap, x0) = (220, 150, 56, 40)
  let all = ((ar-a6000, c.muted, "dashed"), (ar-a100-pcie, c.blue, none), (ar-nvlink, c.orange, none))
  let panels = (
    // (first index, last index, unit divisor, y max, y step, unit, title, ticks, guides)
    (0, 8, 1, 60, 20, "µs", "Small messages",
      ((0, "1 KiB"), (2, "4 KiB"), (4, "16 KiB"), (6, "64 KiB"), (8, "256 KiB")),
      ((calc.log(10240, base: 2) - 10, [decode, 1 token:\ 10 KiB]), (calc.log(163840, base: 2) - 10, [16 tokens:\ 160 KiB]))),
    (10, 17, 1000, 20, 5, "ms", "Large messages",
      ((10, "1 MiB"), (12, "4 MiB"), (14, "16 MiB"), (16, "64 MiB"), (17, "128 MiB")),
      ((calc.log(80 * 1048576, base: 2) - 10, [prefill chunk:\ 80 MiB]),)),
  )
  for (p, (i0, i1, div, ymax, ystep, unit, title, ticks, guides)) in panels.enumerate() {
    let ox = x0 + p * (pw + gap)
    let px(i) = ox + (i - i0) / (i1 - i0) * pw
    let py(v) = v / div / ymax * ph
    for k in range(int(ymax / ystep) + 1) {
      let v = k * ystep
      line((ox, v / ymax * ph), (ox + pw, v / ymax * ph), stroke: if v == 0 { axis-stroke } else { grid-stroke })
      content((ox - 5, v / ymax * ph), txt(str(v) + " " + unit, size: 7pt), anchor: "east")
    }
    for (i, lab) in ticks {
      line((px(i), 0), (px(i), -3), stroke: axis-stroke)
      content((px(i), -6), txt(lab, size: 7pt), anchor: "north")
    }
    content((ox + pw / 2, ph + 26), txt(title, size: 7.5pt, fill: c.ink, weight: 700))
    for (i, lab) in guides {
      line((px(i), 0), (px(i), ph + 2), stroke: (paint: c.muted, thickness: .6pt, dash: "dashed"))
      content((px(i), ph + 4), align(center, txt(lab, size: 6.5pt, fill: c.ink)), anchor: "south")
    }
    for (vals, col, dash) in all {
      let pts = range(i0, i1 + 1).map(i => (px(i), py(vals.at(i))))
      series(pts, col, dash: dash)
      let v = vals.at(i1) / div
      content((ox + pw + 5, py(vals.at(i1))), txt(str(calc.round(v, digits: 1)) + " " + unit, size: 7pt, fill: c.ink, weight: 600), anchor: "west")
    }
  }
  content((x0 + pw + gap / 2, -22), txt("message size", size: 7.5pt), anchor: "north")
  let ly = -44
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

// A100 output throughput (tok/s, prefill included), 1K..128K input, 128 output
// tokens, MTP off, FP8 KV, FlashInfer, prefix cache; rows are concurrency 1,
// 2, 4, 8. TP=1 on GPU0; TP=2 on GPU0+1 (NVLink) and GPU1+2 (PCIe).
#let a100-tp1 = (
  (40.45, 42.45, 40.03, 41.94, 39.34, 34.14, 31.01, 26.88),
  (70.64, 77.98, 70.08, 78.40, 70.41, 56.05, 50.08, 43.17),
  (114.14, 135.70, 112.94, 137.93, 114.62, 82.29, 71.76, 60.84),
  (166.55, 217.51, 164.02, 223.57, 168.30, 106.83, 90.80, 76.44),
)
#let a100-nv = (
  (61.57, 63.97, 60.95, 63.42, 59.33, 52.02, 46.71, 40.55),
  (109.27, 118.48, 108.64, 118.08, 107.32, 88.14, 77.69, 67.92),
  (184.21, 210.61, 179.76, 212.84, 181.43, 135.29, 116.38, 101.84),
  (279.72, 341.49, 270.67, 352.61, 273.28, 181.50, 152.17, 133.56),
)
#let a100-pcie = (
  (59.15, 62.61, 58.49, 62.00, 57.57, 49.64, 45.09, 39.49),
  (102.01, 114.20, 101.79, 115.07, 102.09, 81.82, 73.08, 65.64),
  (162.90, 194.93, 160.84, 199.87, 166.12, 120.21, 105.16, 96.03),
  (230.14, 300.56, 228.17, 314.81, 238.37, 155.19, 135.31, 123.10),
)

#let fig-a100-tp() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (pw, ph, gap, x0) = (104, 120, 28, 30)
  let labels = ("1K", "2K", "4K", "8K", "16K", "32K", "64K", "128K")
  for (k, (conc, ymax, ystep)) in ((1, 80, 20), (2, 160, 40), (4, 240, 60), (8, 400, 100)).enumerate() {
    let ox = x0 + k * (pw + gap)
    let px(i) = ox + i / 7 * pw
    let py(v) = v / ymax * ph
    for j in range(int(ymax / ystep) + 1) {
      let v = j * ystep
      line((ox, py(v)), (ox + pw, py(v)), stroke: if v == 0 { axis-stroke } else { grid-stroke })
      content((ox - 4, py(v)), txt(str(v), size: 6.5pt), anchor: "east")
    }
    for i in (0, 3, 7) { content((px(i), -5), txt(labels.at(i), size: 7pt), anchor: "north") }
    content((ox + pw / 2, ph + 10), txt("concurrency " + str(conc), size: 7.5pt, fill: c.ink, weight: 700))
    let pts(rows) = rows.at(k).enumerate().map(((i, v)) => (px(i), py(v)))
    series(pts(a100-tp1), c.muted, dash: "dashed")
    series(pts(a100-pcie), c.blue)
    series(pts(a100-nv), c.orange)
  }
  content((x0 + 2 * pw + 1.5 * gap, -18), txt("input tokens", size: 7.5pt), anchor: "north")
  let ly = -40
  let sw(x, y, col, dash: none) = line((x, y), (x + 12, y), stroke: (paint: col, thickness: 2pt, dash: dash))
  legend(x0, ly, [TP=2, NVLink (GPU0 + GPU1)], sw(x0, ly, c.orange))
  legend(x0 + 150, ly, [TP=2, PCIe (GPU1 + GPU2)], sw(x0 + 150, ly, c.blue))
  legend(x0 + 300, ly, [TP=1, GPU0], sw(x0 + 300, ly, c.muted, dash: "dashed"))
})

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

// ============================================================================
// Roofline
// ============================================================================

// Spec-sheet peaks: dense BF16 tensor FLOPS (W8A16 GEMMs run in BF16) and
// memory bandwidth.
#let gpu-spec = (
  a6000: (name: "RTX A6000", peak: 154.8e12, bw: 768e9),
  a100: (name: "A100 80 GB PCIe", peak: 312e12, bw: 1935e9),
)
// Qwen3.8-27B per token: FLOPs of the linear layers and the output layer, and
// the bytes of those weights (INT8 linear layers, BF16 output layer).
#let model-flop = 51.24e9
#let model-bytes = 26.89e9

#let log10(v) = calc.log(v, base: 10)

/// All-reduce time (µs) for `s` bytes from one of the ar-* arrays: linear
/// between measured sizes, proportional beyond 128 MiB.
#let ar-time(vals, s) = {
  let top = calc.pow(2, 9 + vals.len())
  if s <= 1024 { return vals.first() }
  if s >= top { return vals.last() * s / top }
  let i = int(calc.floor(calc.log(s, base: 2))) - 10
  let lo = calc.pow(2, 10 + i)
  vals.at(i) + (s - lo) / lo * (vals.at(i + 1) - vals.at(i))
}

/// A log axis from 10^e0 to 10^e1 at y = 0, with region shading split at
/// `split` (left `lfill`, right `rfill`) and tick labels from `ticks`.
#let log-strip(x0, w, e0, e1, ticks, split, lfill, rfill, ltext, rtext, hh: 26) = {
  import cetz.draw: *
  let px(v) = x0 + (log10(v) - e0) / (e1 - e0) * w
  rect((x0, 0), (px(split), hh), fill: lfill, stroke: none)
  rect((px(split), 0), (x0 + w, hh), fill: rfill, stroke: none)
  content((x0 + 6, hh / 2), txt(ltext, size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
  content((x0 + w - 6, hh / 2), txt(rtext, size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
  line((x0, 0), (x0 + w, 0), stroke: axis-stroke)
  for (v, lab) in ticks {
    line((px(v), 0), (px(v), -3), stroke: axis-stroke)
    content((px(v), -6), txt(lab, size: 7pt), anchor: "north")
  }
}

/// Where the parts of a step sit against the two GPUs' ridge points.
#let fig-intensity() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, w, e0, e1, hh) = (10, 500, 0, 5, 26)
  let px(v) = x0 + (log10(v) - e0) / (e1 - e0) * w
  log-strip(x0, w, e0, e1,
    ((1, "1"), (10, "10"), (100, "100"), (1000, "1,000"), (10000, "10,000"), (100000, "100,000")),
    161, c.blue1, c.grey1, "memory-bound", "compute-bound", hh: hh)
  content((x0 + w / 2, -20), txt("FLOPs per byte read from memory", size: 7.5pt), anchor: "north")
  // Ridge points.
  for (v, lab, dx, anchor) in ((161, "A100 ridge: 161", -3, "south-east"), (202, "RTX A6000 ridge: 202", 3, "south-west")) {
    line((px(v), 0), (px(v), hh + 12), stroke: (paint: c.ink, thickness: .8pt))
    content((px(v) + dx, hh + 6), txt(lab, size: 7pt, fill: c.ink, weight: 600), anchor: anchor)
  }
  // Decode attention: a range, 12 per query token, 48 with MTP.
  rect((px(12), 0), (px(48), hh), fill: c.teal2, stroke: none)
  // What a step does, below the axis.
  let marks = (
    (1.9, "linear layers,\n1 token per step", -40),
    (30, "decode attention,\n12–48", -40),
    (61, "linear layers, 32 tokens:\nA6000 concurrency 8 + MTP", -74),
    (244, "linear layers, 128 tokens:\nA100 concurrency 128", -40),
    (15600, "linear layers,\n8192-token prefill chunk", -40),
  )
  for (v, lab, y) in marks {
    line((px(v), 0), (px(v), y + 2), stroke: (paint: c.grey2, thickness: .6pt, dash: "dotted"))
    circle((px(v), 0), radius: 2.6, fill: c.blue, stroke: 1pt + white)
    content((px(v), y), txt(lab, size: 7pt, fill: c.ink), anchor: "north")
  }
})

/// One layer at TP=1 and TP=2: compute halves, two all-reduces are added.
#let fig-tp-layer() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, s, bh, gap) = (96, 1.0, 18, 10)
  // Attention (GDN or full) and MLP in proportion to their weights (30% and 70%).
  let (mix, mlp, ar) = (96, 224, 34)
  let rows = (
    ("TP=1", ((mix, "blue2", "Attention"), (mlp, "blue", "MLP"))),
    ("TP=2, free link", ((mix / 2, "blue2", "Attn"), (mlp / 2, "blue", "MLP / 2"))),
    ("TP=2, real link", ((mix / 2, "blue2", "Attn"), (ar, "orange", "AR"), (mlp / 2, "blue", "MLP / 2"), (ar, "orange", "AR"))),
  )
  for (r, (lab, parts)) in rows.enumerate() {
    let y = -r * (bh + gap)
    content((x0 - 8, y - bh / 2), txt(lab, size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
    let x = x0
    for (wdt, tone, body) in parts {
      seg(x, x + wdt, y, tone, body: body, h: bh)
      x += wdt
    }
    let note = (
      [one GPU reads all the weights],
      [each GPU reads half: twice as fast],
      [plus two all-reduces, one after the other],
    ).at(r)
    content((x + 8, y - bh / 2), txt(note, size: 7pt), anchor: "west")
  }
  let ly = -3 * (bh + gap) - 4
  legend(x0, ly, [AR: all-reduce of _B_ × 10 KiB for _B_ tokens. A step is 64 such layers: 128 all-reduces.], box-swatch(x0, ly, c.orange))
})

/// One machine's roofline. Left: the classic roofline of one GPU, with where
/// this machine's runs sit. Right: tokens per second for a step of B tokens,
/// on one GPU, on a TP=2 pair over a free link, and over each real link.
/// `marks`: (label, tokens per step); `links`: (name, ar-* array, colour).
#let fig-gpu-roofline(spec, marks, links) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let per-tok = model-flop / model-bytes
  let (peak, bw) = (spec.peak / 1e12, spec.bw / 1e12)
  let ridge = peak / bw
  let roof(x) = calc.min(peak, x * bw)
  let h = 170

  // Left: TFLOPS against FLOPs per byte.
  let (x0, lw) = (40, 190)
  let (ly0, ly1) = (-0.3, 2.7)
  let px(v) = x0 + log10(v) / 5 * lw
  let py(v) = (log10(v) - ly0) / (ly1 - ly0) * h
  for (v, lab) in ((1, "1"), (10, "10"), (100, "100")) {
    line((x0, py(v)), (x0 + lw, py(v)), stroke: grid-stroke)
    content((x0 - 5, py(v)), txt(lab, size: 7pt), anchor: "east")
  }
  content((x0 - 26, h / 2), txt("TFLOPS", size: 7.5pt), angle: 90deg)
  line((x0, 0), (x0 + lw, 0), stroke: axis-stroke)
  for (v, lab) in ((1, "1"), (10, "10"), (100, "100"), (1000, "1K"), (10000, "10K"), (100000, "100K")) {
    line((px(v), 0), (px(v), -3), stroke: axis-stroke)
    content((px(v), -6), txt(lab, size: 7pt), anchor: "north")
  }
  content((x0 + lw / 2, -20), txt("FLOPs per byte read from memory", size: 7.5pt), anchor: "north")
  content((x0 + lw / 2, h + 12), txt(spec.name + ": " + str(calc.round(peak, digits: 1)) + " TFLOPS, " + str(calc.round(spec.bw / 1e9)) + " GB/s", size: 7.5pt, fill: c.ink, weight: 700))
  // Decode attention over FP8 KV: 12 FLOPs per byte, 48 with MTP.
  rect((px(12), 0), (px(48), h), fill: c.teal1, stroke: none)
  content((px(24), 4), txt([decode\ attention], size: 6.5pt, fill: c.ink), anchor: "south")
  line((px(1), py(bw)), (px(ridge), py(peak)), (px(1e5), py(peak)), stroke: (paint: c.ink, thickness: 1.5pt, join: "round"))
  content((px(ridge) - 4, py(peak) + 4),
    txt(str(calc.round(ridge)) + " FLOPs/B = " + str(calc.round(ridge / per-tok)) + " tokens", size: 7pt, fill: c.ink, weight: 600),
    anchor: "south-east")
  // Where the linear layers of this machine's runs sit.
  for (lab, b) in marks {
    let x = per-tok * b
    circle((px(x), py(roof(x))), radius: 2.6, fill: c.blue, stroke: 1pt + white)
    content((px(x) + 3, py(roof(x)) - 4), txt(lab, size: 7pt, fill: c.ink), anchor: "north-west")
  }

  // Right: tokens per second against tokens per step.
  let (rx0, rw) = (x0 + lw + 64, 216)
  let (ry0, ry1) = (1.2, 5.3)
  let qx(b) = rx0 + calc.log(b, base: 2) / 14 * rw
  let qy(v) = (log10(v) - ry0) / (ry1 - ry0) * h
  for (v, lab) in ((100, "100"), (1000, "1K"), (10000, "10K"), (100000, "100K")) {
    line((rx0, qy(v)), (rx0 + rw, qy(v)), stroke: grid-stroke)
    content((rx0 - 5, qy(v)), txt(lab, size: 7pt), anchor: "east")
  }
  content((rx0 - 30, h / 2), txt("tokens/s", size: 7.5pt), angle: 90deg)
  line((rx0, 0), (rx0 + rw, 0), stroke: axis-stroke)
  for (b, lab) in ((1, "1"), (8, "8"), (64, "64"), (512, "512"), (4096, "4K")) {
    line((qx(b), 0), (qx(b), -3), stroke: axis-stroke)
    content((qx(b), -6), txt(lab, size: 7pt), anchor: "north")
  }
  content((rx0 + rw / 2, -20), txt("tokens per step", size: 7.5pt), anchor: "north")
  content((rx0 + rw / 2, h + 12), txt("Qwen3.8-27B, TP=1 and TP=2", size: 7.5pt, fill: c.ink, weight: 700))
  line((qx(8192), 0), (qx(8192), h), stroke: (paint: c.muted, thickness: .6pt, dash: "dashed"))
  content((qx(8192) - 3, 4), txt([prefill\ chunk], size: 6.5pt), anchor: "south-east")
  let bs = range(57).map(k => calc.pow(2, k / 4))
  // Step time in seconds on `n` GPUs, and of the all-reduces.
  let t-gpu(n, b) = calc.max(model-bytes / n / spec.bw, b * model-flop / n / spec.peak)
  let t-link(vals, b) = 128 * ar-time(vals, b * 10240) * 1e-6
  let curve(f, stroke) = line(..bs.map(b => (qx(b), qy(b / f(b)))), stroke: stroke)
  curve(b => t-gpu(1, b), (paint: c.ink, thickness: 1.2pt, dash: "dotted", join: "round"))
  curve(b => t-gpu(2, b), (paint: c.ink, thickness: 1pt, join: "round"))
  for (name, vals, col) in links {
    curve(b => t-link(vals, b), (paint: col, thickness: 1pt, dash: "dashed", join: "round"))
    curve(b => t-gpu(2, b) + t-link(vals, b), (paint: col, thickness: 1.8pt, join: "round"))
  }

  let sw(x, y, col, th, dash: none) = line((x, y), (x + 12, y), stroke: (paint: col, thickness: th, dash: dash))
  let ly = -44
  legend(x0, ly, [linear layers at a run’s tokens per step], circle((x0 + 6, ly), radius: 2.6, fill: c.blue, stroke: 1pt + white))
  legend(rx0, ly, [TP=1], sw(rx0, ly, c.ink, 1.2pt, dash: "dotted"))
  legend(rx0 + 60, ly, [TP=2, link free], sw(rx0 + 60, ly, c.ink, 1pt))
  for (k, (name, _, col)) in links.enumerate() {
    let y = ly - 16 * (k + 1)
    legend(rx0, y, [TP=2 over #name], sw(rx0, y, col, 1.8pt))
    legend(rx0 + 120, y, [#name all-reduces only], sw(rx0 + 120, y, col, 1pt, dash: "dashed"))
  }
})

#let fig-a6000-roofline() = fig-gpu-roofline(gpu-spec.a6000,
  (("c2", 8), ("c8", 32), ("prefill", 8192)),
  (("PCIe", ar-a6000, c.muted),))

#let fig-a100-roofline() = fig-gpu-roofline(gpu-spec.a100,
  (("c1", 1), ("c16", 16), ("c128", 128), ("prefill", 8192)),
  (("NVLink", ar-nvlink, c.orange), ("PCIe", ar-a100-pcie, c.blue)))
