// Figures for content/posts/ml-systems/gpu-server-topology.typ, drawn with cetz.
// Every board is a dual-socket server seen from the top: memory above each
// CPU, the CPU's PCIe host bridges (HB) on its on-die fabric, UPI between the
// sockets, and the PCIe tree below. The path a GPU-to-GPU transfer takes is
// drawn in orange, next to the `nvidia-smi topo -m` cells it produces.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend

// ============================================================================
// Shared pieces
// ============================================================================

#let txt(body, size: 8.5pt, fill: c.muted, weight: 400, style: "normal") = text(
  size: size, fill: fill, weight: weight, style: style, body,
)
#let head(body, fill: c.ink) = text(size: 8pt, weight: 700, tracking: .6pt, fill: fill, upper(body))

// Geometry of a CPU package: top edge at y = 0, fabric (and UPI) at `fab`.
#let cpu-h = 58
#let fab = -40
#let hb-w = 40
#let hb-h = 16
#let hb-bottom = fab - hb-h / 2
#let gpu-w = 48
#let gpu-h = 26
#let sw-w = 72
#let sw-h = 18

#let hot-w = 2pt
#let cold = .9pt + c.line

/// One socket: memory strip, package, on-die fabric and host bridges.
/// `hbs`: x of each host bridge; `hot-hbs`: those on the path;
/// `hot-fab`: (x0, x1), the stretch of fabric the path uses.
#let cpu(x, w, name, node, hbs: (), hot-hbs: (), hot-fab: none) = {
  import cetz.draw: *
  // memory
  line((x + w / 2, 14), (x + w / 2, 0), stroke: 1pt + c.grey2)
  rect((x + 14, 28), (x + w - 14, 14), fill: c.grey1, stroke: .6pt + c.grey2, radius: 2)
  content((x + w / 2, 21), txt("DDR · node " + str(node), size: 7pt))
  // package
  rect((x, 0), (x + w, -cpu-h), fill: c.blue1, stroke: .8pt + c.blue, radius: 3)
  content((x + 8, -11), txt(name, size: 9pt, fill: c.ink, weight: 700), anchor: "west")
  content((x + w - 8, -11), txt("NUMA " + str(node), size: 7.5pt, fill: c.blue, weight: 600), anchor: "east")
  line((x + 3, fab), (x + w - 3, fab), stroke: 1.4pt + c.blue2)
  if hot-fab != none { line((hot-fab.at(0), fab), (hot-fab.at(1), fab), stroke: hot-w + c.orange) }
  for hx in hbs {
    let on = hx in hot-hbs
    rect((hx - hb-w / 2, fab + hb-h / 2), (hx + hb-w / 2, fab - hb-h / 2),
      fill: if on { c.orange1 } else { white }, stroke: if on { 1.1pt + c.orange } else { .7pt + c.blue }, radius: 2)
    content((hx, fab), txt("HB", size: 7.5pt, fill: c.ink, weight: 600))
  }
}

/// The socket-to-socket link, from the right edge of CPU0 to the left edge of CPU1.
#let upi(x0, x1, hot: false) = {
  import cetz.draw: *
  line((x0, fab), (x1, fab), stroke: 2.4pt + if hot { c.orange } else { c.ink })
  content(((x0 + x1) / 2, fab + 8), txt("UPI", size: 7.5pt, fill: c.ink, weight: 600))
}

#let gpu(x, y, name, hot: false) = {
  import cetz.draw: *
  rect((x - gpu-w / 2, y + gpu-h / 2), (x + gpu-w / 2, y - gpu-h / 2),
    fill: if hot { c.orange1 } else { white }, stroke: if hot { 1.1pt + c.orange } else { .8pt + c.ink }, radius: 2)
  content((x, y), txt(name, size: 8.5pt, fill: c.ink, weight: 700))
}

#let nic(x, y, name) = {
  import cetz.draw: *
  rect((x - gpu-w / 2, y + gpu-h / 2), (x + gpu-w / 2, y - gpu-h / 2), fill: c.teal1, stroke: .8pt + c.teal, radius: 2)
  content((x, y), txt(name, size: 8.5pt, fill: c.ink, weight: 700))
}

#let switch(x, y, hot: false) = {
  import cetz.draw: *
  rect((x - sw-w / 2, y + sw-h / 2), (x + sw-w / 2, y - sw-h / 2),
    fill: if hot { c.orange1 } else { c.grey1 }, stroke: if hot { 1.1pt + c.orange } else { .7pt + c.line }, radius: 2)
  content((x, y), txt("PCIe switch", size: 7.5pt, fill: c.ink, weight: 600))
}

/// A PCIe link from a point on a parent's bottom edge down to a child's top edge.
#let pcie(a, b, hot: false) = {
  import cetz.draw: *
  let (x1, y1) = a
  let (x2, y2) = b
  let s = if hot { hot-w + c.orange } else { cold }
  if x1 == x2 { line(a, b, stroke: s) } else {
    let ym = (y1 + y2) / 2
    line(a, (x1, ym), (x2, ym), b, stroke: s)
  }
}

/// Draw PCIe links, cold ones first so the path stays on top.
#let wires(..ls) = {
  for (a, b, hot) in ls.pos().filter(l => not l.at(2)) { pcie(a, b) }
  for (a, b, hot) in ls.pos().filter(l => l.at(2)) { pcie(a, b, hot: true) }
}
#let top(x, y) = (x, y + gpu-h / 2)
#let sw-top(x, y) = (x, y + sw-h / 2)
#let sw-bot(x, y) = (x, y - sw-h / 2)

/// A small `nvidia-smi topo -m` matrix; `o` is its top-left corner.
#let mat(o, names, rows, hot: ()) = {
  import cetz.draw: *
  let (x, y) = o
  let (lw, cw, ch) = (34, 34, 18)
  content((x, y + 12), txt("nvidia-smi topo -m", size: 7.5pt, weight: 600), anchor: "west")
  for (j, n) in names.enumerate() {
    content((x + lw + (j + .5) * cw, y - ch / 2), txt(n, size: 7.5pt, fill: c.ink, weight: 700))
  }
  for (i, row) in rows.enumerate() {
    let yy = y - (i + 1) * ch
    content((x + lw - 5, yy - ch / 2), txt(names.at(i), size: 7.5pt, fill: c.ink, weight: 700), anchor: "east")
    for (j, v) in row.enumerate() {
      let on = (i, j) in hot
      let fill = if i == j { c.grey1 } else if on { c.orange1 } else { c.panel }
      rect((x + lw + j * cw, yy), (x + lw + (j + 1) * cw, yy - ch), fill: fill, stroke: .8pt + white)
      content((x + lw + (j + .5) * cw, yy - ch / 2),
        txt(v, size: 7.5pt, fill: if on { c.orange } else if i == j { c.muted } else { c.ink }, weight: if on { 700 } else { 400 }))
    }
  }
}

/// A full matrix from a function of (i, j); the diagonal is X.
#let grid-of(n, f) = range(n).map(i => range(n).map(j => if i == j { "X" } else { f(i, j) }))
#let names(n) = range(n).map(i => "GPU" + str(i))

// ============================================================================
// Overview: one board, every kind of path
// ============================================================================

#let fig-board() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gy = -132
  cpu(0, 230, "CPU0", 0, hbs: (60, 175))
  cpu(280, 170, "CPU1", 1, hbs: (320, 410))
  upi(230, 280)
  content((117.5, fab + 10), txt("on-die fabric", size: 7pt, style: "italic"))
  wires(
    ((60, hb-bottom), sw-top(60, -84), false),
    (sw-bot(60, -84), top(30, gy), false),
    (sw-bot(60, -84), top(90, gy), false),
    ((175, hb-bottom), top(175, gy), false),
    ((320, hb-bottom), top(320, gy), false),
    ((410, hb-bottom), top(410, gy), false),
  )
  switch(60, -84)
  gpu(30, gy, "GPU0")
  gpu(90, gy, "GPU1")
  gpu(175, gy, "GPU2")
  gpu(320, gy, "GPU3")
  nic(410, gy, "NIC0")
  content((183, -84), txt("PCIe x16", size: 7pt, style: "italic"), anchor: "west")

  let ly = -170
  let swatch(x, s) = line((x, ly), (x + 12, ly), stroke: s)
  legend(0, ly, "PCIe", swatch(0, cold))
  legend(64, ly, "on-die fabric", swatch(64, 1.4pt + c.blue2))
  legend(176, ly, "UPI (socket link)", swatch(176, 2.4pt + c.ink))
  legend(310, ly, "HB = PCIe host bridge", box-swatch(310, ly, white, stroke: .7pt + c.blue))
})

/// Inside one CPU: cores and the memory controller on the on-die fabric, and
/// two host bridges, each turning fabric traffic into PCIe through its root
/// ports. GPU0 <-> GPU1 turns around inside one host bridge (PHB); GPU1 <->
/// NIC0 crosses the fabric between two (NODE).
#let fig-host-bridge() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, f, dy) = (500, -62, -196)
  let (hb-t, hb-b, rp-y) = (-82, -146, -128)
  let (rp-w, rp-h) = (58, 16)
  let node-w = 2pt
  // memory
  rect((345, 34), (475, 16), fill: c.grey1, stroke: .6pt + c.grey2, radius: 2)
  content((410, 25), txt("DDR · NUMA node 0", size: 7pt))
  line((410, 16), (410, -14), stroke: 1pt + c.grey2)
  // package
  rect((0, 0), (w, -160), fill: c.blue1, stroke: .8pt + c.blue, radius: 3)
  content((10, -12), txt("CPU0", size: 9pt, fill: c.ink, weight: 700), anchor: "west")
  for x in (130, 170, 210, 250) {
    rect((x - 16, -24), (x + 16, -44), fill: white, stroke: .7pt + c.blue, radius: 2)
    content((x, -34), txt("core", size: 7pt, fill: c.ink))
    line((x, -44), (x, f), stroke: .8pt + c.blue2)
  }
  content((272, -34), txt("…", size: 9pt, fill: c.ink), anchor: "west")
  rect((345, -14), (475, -44), fill: white, stroke: .7pt + c.blue, radius: 2)
  content((410, -29), txt("memory controller", size: 7.5pt, fill: c.ink, weight: 600))
  line((410, -44), (410, f), stroke: .8pt + c.blue2)
  line((6, f), (w - 6, f), stroke: 2.4pt + c.blue2)
  content((10, f + 9), txt("on-die fabric", size: 7pt, style: "italic"), anchor: "west")
  // host bridges
  // HB1's labels sit right, clear of the NODE path.
  for (x0, x1, name, right, up) in ((24, 236, "PCIe host bridge 0", false, 60), (264, 476, "PCIe host bridge 1", true, 380)) {
    line((up, f), (up, hb-t), stroke: 1.2pt + c.blue2)
    rect((x0, hb-t), (x1, hb-b), fill: white, stroke: .8pt + c.blue, radius: 2)
    let (lx, side) = if right { (x1 - 8, "east") } else { (x0 + 8, "west") }
    content((lx, hb-t - 9), txt(name, size: 7.5pt, fill: c.ink, weight: 700), anchor: side)
    content((lx, hb-t - 19), txt("fabric ↔ PCIe", size: 7pt, style: "italic"), anchor: side)
  }
  // paths, under the root ports: PHB turns inside HB0, NODE rides the fabric
  line((80, dy + gpu-h / 2), (80, -111), (176, -111), (176, dy + gpu-h / 2), stroke: hot-w + c.orange)
  line((188, dy + gpu-h / 2), (188, f), (304, f), (304, dy + gpu-h / 2), stroke: node-w + c.blue)
  for x in (80, 182, 310, 420) {
    rect((x - rp-w / 2, rp-y + rp-h / 2), (x + rp-w / 2, rp-y - rp-h / 2), fill: c.grey1, stroke: .7pt + c.line, radius: 2)
    content((x, rp-y), txt("root port", size: 7pt, fill: c.ink, weight: 600))
  }
  // links out of the package
  line((420, rp-y - rp-h / 2), (420, dy + gpu-h / 2), stroke: cold)
  content((84, -172), txt("x16", size: 7pt, style: "italic"), anchor: "west")
  gpu(80, dy, "GPU0", hot: true)
  gpu(182, dy, "GPU1", hot: true)
  nic(310, dy, "NIC0")
  rect((420 - gpu-w / 2, dy + gpu-h / 2), (420 + gpu-w / 2, dy - gpu-h / 2), fill: c.grey1, stroke: .8pt + c.line, radius: 2)
  content((420, dy), txt("NVMe", size: 8.5pt, fill: c.ink, weight: 700))

  let ly = dy - 34
  let swatch(y, s) = line((0, y), (12, y), stroke: s)
  legend(0, ly, "GPU0 ↔ GPU1: through one host bridge → PHB", swatch(ly, hot-w + c.orange))
  legend(0, ly - 16, "GPU1 ↔ NIC0: host bridge → fabric → host bridge → NODE", swatch(ly - 16, node-w + c.blue))
})

// ============================================================================
// The matrix itself
// ============================================================================

/// The opening matrix (machine 2), with its four parts numbered.
#let fig-anatomy() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let n = 4
  let cols = (("", 40),) + range(n).map(k => ("GPU" + str(k), 38)) + (("CPU Affinity", 100), ("NUMA Affinity", 84), ("GPU NUMA ID", 80))
  let link(i, j) = if i == j { "X" } else if calc.quo(i, 2) == calc.quo(j, 2) { "NV12" } else { "SYS" }
  let rows = range(n).map(i => ("GPU" + str(i),) + range(n).map(j => link(i, j))
    + (if i < 2 { ("0,2,4,6,8,10", "0") } else { ("1,3,5,7,9,11", "1") }) + ("N/A",))
  let xs = (0,)
  for (_, w) in cols { xs.push(xs.last() + w) }
  let rh = 20
  let fills = (none,) + (c.blue1,) * n + (c.teal1, c.orange1, c.grey1)
  for (j, (h, w)) in cols.enumerate() {
    content(((xs.at(j) + xs.at(j + 1)) / 2, -rh / 2), txt(h, size: 8pt, fill: c.ink, weight: 700))
  }
  for (i, r) in rows.enumerate() {
    let y = -(i + 1) * rh
    for (j, v) in r.enumerate() {
      let fill = if j == i + 1 { c.grey1 } else { fills.at(j) }
      if fill != none { rect((xs.at(j), y), (xs.at(j + 1), y - rh), fill: fill, stroke: .8pt + white) }
      content(((xs.at(j) + xs.at(j + 1)) / 2, y - rh / 2),
        txt(v, size: 8pt, fill: if j == i + 1 { c.muted } else { c.ink }, weight: if j == 0 { 700 } else { 400 }))
    }
  }
  // numbered markers under each region
  let yb = -(n + 1) * rh - 3
  let mark(x, k) = {
    line((x, yb), (x, yb - 9), stroke: .7pt + c.line)
    circle((x, yb - 18), radius: 8, fill: c.ink, stroke: none)
    content((x, yb - 18), txt(str(k), size: 8pt, fill: white, weight: 700))
  }
  let mid(j0, j1) = (xs.at(j0) + xs.at(j1)) / 2
  line((xs.at(1) + 2, yb), (xs.at(n + 1) - 2, yb), stroke: .7pt + c.line)
  mark(mid(1, n + 1), 1)
  mark(mid(n + 1, n + 2), 2)
  mark(mid(n + 2, n + 3), 3)
  mark(mid(n + 3, n + 4), 4)
})

/// Logical CPU numbers of the first machine, coloured by socket.
#let fig-cpus() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, w, h) = (0, 32, 22)
  content((x0, 14), head("logical CPU number"), anchor: "west")
  for k in range(12) {
    let even = calc.even(k)
    rect((x0 + k * w, 0), (x0 + (k + 1) * w, -h), fill: if even { c.blue1 } else { c.orange1 },
      stroke: .8pt + white)
    content((x0 + (k + .5) * w, -h / 2), txt(str(k), size: 9pt, fill: if even { c.blue } else { c.orange }, weight: 700))
  }
  // a range that looks like "half the machine"
  let y = -h - 6
  line((x0 + 1, y), (x0 + 1, y - 5), (x0 + 6 * w - 1, y - 5), (x0 + 6 * w - 1, y), stroke: .8pt + c.ink)
  line((x0 + 3 * w, y - 5), (x0 + 3 * w, y - 11), stroke: .8pt + c.ink)
  content((x0 + 3 * w, y - 14), txt([taskset -c 0-5: three CPUs on *each* socket], size: 8pt, fill: c.ink), anchor: "north")
  let ly = y - 44
  legend(x0, ly, "node 0 · CPU0 · local to GPU0", box-swatch(x0, ly, c.blue1))
  legend(x0 + 200, ly, "node 1 · CPU1 · local to GPU1", box-swatch(x0 + 200, ly, c.orange1))
})

// ============================================================================
// One figure per legend entry
// ============================================================================

/// One PCIe switch: an x16 uplink to the CPU, five x16 devices below it.
#let fig-pcie-switch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (sy, dy) = (-90, -160)
  let xs = (80, 170, 260, 350, 440)
  // CPU root port
  rect((180, 0), (340, -28), fill: c.blue1, stroke: .8pt + c.blue, radius: 3)
  content((260, -14), txt("CPU0 · root port", size: 8pt, fill: c.ink, weight: 700))
  line((260, -28), (260, sy + 14), stroke: 2.4pt + c.ink)
  content((268, -45), txt("x16 uplink: shared by everything below", size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
  // downstream links
  for x in xs { line((x, sy - 14), (x, dy + gpu-h / 2), stroke: cold) }
  // peer-to-peer turns around inside the switch
  line((80, dy + gpu-h / 2), (80, sy), (170, sy), (170, dy + gpu-h / 2), stroke: hot-w + c.orange)
  line((350, dy + gpu-h / 2), (350, sy + 4), (440, sy + 4), (440, dy + gpu-h / 2), stroke: hot-w + c.teal)
  rect((40, sy + 14), (480, sy - 14), fill: none, stroke: .8pt + c.line, radius: 3)
  content((260, sy - 3), txt("PCIe switch", size: 8pt, fill: c.ink, weight: 700))
  for x in xs { content((x + 4, dy + 26), txt("x16", size: 7pt), anchor: "west") }
  for k in range(4) { gpu(xs.at(k), dy, "GPU" + str(k), hot: k < 2) }
  nic(440, dy, "NIC0")
  let ly = dy - 32
  let swatch(y, s) = line((40, y), (52, y), stroke: s)
  legend(40, ly, "GPU0 ↔ GPU1: peer-to-peer, never reaches the CPU", swatch(ly, hot-w + c.orange))
  legend(40, ly - 16, "GPU3 ↔ NIC0: GPUDirect RDMA, also stays in the switch", swatch(ly - 16, hot-w + c.teal))
})

/// A vertical link from (x1, y1) to (x2, y2), with one horizontal jog midway.
// No `import cetz.draw: *` in these two: it would shadow `stroke`.
#let el(x1, y1, x2, y2, stroke) = if x1 == x2 { cetz.draw.line((x1, y1), (x2, y2), stroke: stroke) } else {
  let ym = (y1 + y2) / 2
  cetz.draw.line((x1, y1), (x1, ym), (x2, ym), (x2, y2), stroke: stroke)
}

/// A labelled box centred at (x, y), for the server overviews.
#let node-box(x, y, w, h, body, fill: white, stroke: .8pt + c.ink, size: 7.5pt, weight: 700) = {
  cetz.draw.rect((x - w / 2, y + h / 2), (x + w / 2, y - h / 2), fill: fill, stroke: stroke, radius: 2)
  cetz.draw.content((x, y), txt(body, size: size, fill: c.ink, weight: weight))
}

/// Two DGX A100-like nodes, after NVIDIA's DGX A100 topology diagram: two
/// CPUs, each with two PCIe switch groups; in a group the 2 NICs sit on the
/// upper switch and the 2 GPUs on the lower one (the two levels the real
/// `topo -m` shows). NVMe drives and the storage NIC are left out.
#let fig-cluster() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gc = (70, 206, 342, 478)
  let cpu-x = (138, 410)
  let bar(y, body, fill, stroke) = {
    rect((10, y + 10), (538, y - 10), fill: fill, stroke: stroke, radius: 2)
    content((274, y), txt(body, size: 7.5pt, fill: c.ink, weight: 700))
  }
  // one node; s = 1 above the network, -1 below it
  let node(name, s) = {
    let Y(d) = s * d
    rect((0, Y(238)), (548, Y(22)), fill: none, stroke: (paint: c.grey2, thickness: .8pt, dash: "dashed"), radius: 4)
    content((8, Y(228)), head(name, fill: c.muted), anchor: "west")
    // links first, boxes on top
    for (k, g) in gc.enumerate() {
      for x in (g - 28, g + 28) {
        line((x, Y(171)), (x, Y(194)), stroke: 1.4pt + c.teal)
        el(x, Y(149), g, Y(129), cold)
      }
      line((g, Y(111)), (g, Y(89)), stroke: cold)
      for x in (g - 26, g + 26) {
        el(g, Y(71), x, Y(51), cold)
        line((x, Y(29)), (x, Y(12)), stroke: 1pt + c.ink)
      }
    }
    for (k, x) in cpu-x.enumerate() {
      line((gc.at(2 * k) + 32, Y(80)), (x - 24, Y(80)), stroke: cold)
      line((x + 24, Y(80)), (gc.at(2 * k + 1) - 32, Y(80)), stroke: cold)
    }
    line((cpu-x.at(0), Y(93)), (cpu-x.at(0), Y(100)), (cpu-x.at(1), Y(100)), (cpu-x.at(1), Y(93)), stroke: 1.4pt + c.blue)
    content((274, Y(100)), box(fill: white, inset: (x: 3pt, y: 1pt), txt("UPI or xGMI", size: 6.5pt, fill: c.blue, weight: 600)))
    bar(Y(204), "NVSwitch × 6", c.teal1, .8pt + c.teal)
    for (k, g) in gc.enumerate() {
      node-box(g - 28, Y(160), 48, 22, "GPU" + str(2 * k))
      node-box(g + 28, Y(160), 48, 22, "GPU" + str(2 * k + 1))
      node-box(g, Y(120), 64, 18, "PCIe switch", fill: c.grey1, stroke: .7pt + c.line, size: 6.5pt, weight: 600)
      node-box(g, Y(80), 64, 18, "PCIe switch", fill: c.grey1, stroke: .7pt + c.line, size: 6.5pt, weight: 600)
      node-box(g - 26, Y(40), 44, 22, "NIC" + str(2 * k), fill: c.teal1, stroke: .8pt + c.teal)
      node-box(g + 26, Y(40), 44, 22, "NIC" + str(2 * k + 1), fill: c.teal1, stroke: .8pt + c.teal)
    }
    for (k, x) in cpu-x.enumerate() {
      node-box(x, Y(80), 48, 26, "CPU" + str(k), fill: c.blue1, stroke: .8pt + c.blue)
    }
  }
  bar(0, "InfiniBand network", c.grey1, .8pt + c.ink)
  node("node A", 1)
  node("node B", -1)
})

/// Rows of an 8-GPU, 10-NIC `nvidia-smi topo -m`: 8 GPU columns, 10 NIC
/// columns and NUMA. `rows`: (name, cells) pairs, cells being the 19 cells
/// as one space-separated string; `none` leaves a gap. `groups`: (first,
/// last, label, colour) headings over the columns. PXB is orange, PIX teal
/// and NODE blue, as in `fig-pxb-group` and `fig-host-bridge`.
#let topo-table(title, rows, groups) = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (lw, gw, nw, ch, gap) = (32, 26, 27, 17, 6)
  let colx(j) = if j < 8 { lw + j * gw } else if j < 18 { lw + 8 * gw + gap + (j - 8) * nw } else { lw + 8 * gw + 2 * gap + 10 * nw }
  let colw(j) = if j < 8 { gw } else if j < 18 { nw } else { 30 }
  let names = range(8).map(i => "GPU" + str(i)) + range(10).map(k => "NIC" + str(k)) + ("NUMA",)
  content((0, 30), txt(title, size: 7.5pt, weight: 600), anchor: "west")
  for (a, b, label, col) in groups {
    content(((colx(a) + colx(b) + colw(b)) / 2, 14), head(label, fill: col))
  }
  for (j, n) in names.enumerate() {
    content((colx(j) + colw(j) / 2, -ch / 2), txt(n, size: 6pt, fill: c.ink, weight: 700))
  }
  let y = -ch
  for row in rows {
    if row == none { y -= gap; continue }
    let (name, cells) = row
    content((lw - 4, y - ch / 2), txt(name, size: 6.5pt, fill: c.ink, weight: 700), anchor: "east")
    for (j, v) in cells.split(" ").map(v => if v == "-" { "" } else { v }).enumerate() {
      let (fill, ink) = if v == "X" { (c.grey1, c.muted) } else if v == "PXB" { (c.orange1, c.orange) } else if v == "PIX" { (c.teal1, c.teal) } else if v == "NODE" { (c.blue1, c.blue) } else if j == 18 { (c.grey1, c.ink) } else { (c.panel, c.ink) }
      rect((colx(j), y), (colx(j) + colw(j), y - ch), fill: fill, stroke: .8pt + white)
      content((colx(j) + colw(j) / 2, y - ch / 2), txt(v, size: 6.5pt,
        fill: ink, weight: if v in ("PXB", "PIX", "NODE") { 700 } else { 400 }))
    }
    y -= ch
  }
})

/// A real 8 x A100 SXM4 server (2 x EPYC 7543, NPS=4): the GPU rows of
/// `nvidia-smi topo -m` and the first two NIC rows, from an NVIDIA developer
/// forum post. NIC8/9 are the two ports of the storage NIC.
#let fig-real-topo() = {
  let numa = (3, 3, 1, 1, 7, 7, 5, 5)
  // Each GPU pair shares a NIC pair: GPU 2m, 2m+1 with NIC 2m, 2m+1 (m < 4).
  let pair(j) = if j < 8 { calc.quo(j, 2) } else if j < 16 { calc.quo(j - 8, 2) } else { none }
  let rel(i, j) = if j == 18 { if i < 8 { str(numa.at(i)) } else { "-" } } else if j == i { "X" } else if i < 8 and j < 8 { "NV12" } else if pair(i) != pair(j) { "SYS" } else if i < 8 or j < 8 { "PXB" } else { "PIX" }
  let row(i) = (if i < 8 { "GPU" + str(i) } else { "NIC" + str(i - 8) }, range(19).map(j => rel(i, j)).join(" "))
  topo-table(
    "nvidia-smi topo -m, 8 × A100 SXM4: GPU rows and two NIC rows",
    range(8).map(row) + (none,) + range(8, 10).map(row),
    ((0, 7, "GPU", c.ink), (8, 15, "compute NIC", c.orange), (16, 17, "storage", c.muted)),
  )
}

/// Why GPU0 -> NIC0 is PXB: the NICs sit on the upper switch, the GPUs one
/// switch further down.
#let fig-pxb-group() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (ay, by, dy, gy) = (-70, -125, -125, -185)
  rect((150, 0), (290, -26), fill: c.blue1, stroke: .8pt + c.blue, radius: 3)
  content((220, -13), txt("CPU0", size: 8.5pt, fill: c.ink, weight: 700))
  line((220, -26), (220, ay + 10), stroke: cold)
  line((370, ay - 10), (370, dy + 13), stroke: cold)
  line((270, ay - 10), (270, by + 9), stroke: cold)
  for x in (240, 300) { line((x, by - 9), (x, gy + gpu-h / 2), stroke: cold) }
  // NIC0 <-> NIC1: one switch
  line((86, dy + gpu-h / 2), (86, ay - 4), (154, ay - 4), (154, dy + gpu-h / 2), stroke: hot-w + c.teal)
  // GPU0 -> NIC0: two switches
  line((240, gy + gpu-h / 2), (240, by), (270, by), (270, ay + 3), (74, ay + 3), (74, dy + gpu-h / 2), stroke: hot-w + c.orange)
  rect((40, ay + 10), (400, ay - 10), fill: none, stroke: .8pt + c.line, radius: 2)
  content((396, ay), txt("PCIe switch", size: 7pt), anchor: "east")
  rect((205, by + 9), (335, by - 9), fill: none, stroke: .8pt + c.line, radius: 2)
  content((331, by), txt("PCIe switch", size: 7pt), anchor: "east")
  nic(80, dy, "NIC0")
  nic(160, dy, "NIC1")
  rect((346, dy + 13), (394, dy - 13), fill: c.grey1, stroke: .8pt + c.line, radius: 2)
  content((370, dy), txt("NVMe", size: 8pt, fill: c.ink, weight: 700))
  gpu(240, gy, "GPU0", hot: true)
  gpu(300, gy, "GPU1")
  let ly = gy - 34
  let swatch(y, col) = line((40, y), (52, y), stroke: hot-w + col)
  legend(40, ly, "GPU0 ↔ NIC0: two switches → PXB", swatch(ly, c.orange))
  legend(40, ly - 16, "NIC0 ↔ NIC1: one switch → PIX", swatch(ly - 16, c.teal))
})

/// Where one GPU's traffic goes, by destination.
#let fig-destinations() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (nv, gy, sy, ny) = (0, -55, -110, -165)
  let (g0, g1) = (90, 210)
  // cold wiring (GPU0's own links are drawn by its paths)
  for x in (g1,) {
    line((x, nv - 10), (x, gy + gpu-h / 2), stroke: 1.4pt + c.teal)
    line((x, gy - gpu-h / 2), (x, sy + 10), stroke: cold)
    line((x, sy - 10), (x, ny + gpu-h / 2), stroke: cold)
  }
  // three destinations from GPU0
  line((g0 - 6, gy + gpu-h / 2), (g0 - 6, nv), (g1, nv), (g1, gy + gpu-h / 2), stroke: hot-w + c.teal,
    mark: (end: "stealth", fill: c.teal, scale: .5))
  line((g0 - 6, gy - gpu-h / 2), (g0 - 6, -212), stroke: hot-w + c.orange,
    mark: (end: "stealth", fill: c.orange, scale: .5))
  line((g0 + 6, gy - gpu-h / 2), (g0 + 6, sy - 3), (370, sy - 3), stroke: hot-w + c.ink,
    mark: (end: "stealth", fill: c.ink, scale: .5))
  rect((40, nv + 10), (260, nv - 10), fill: none, stroke: .8pt + c.teal, radius: 2)
  content((150, nv + 14), txt("NVSwitch", size: 7.5pt, fill: c.teal, weight: 700), anchor: "south")
  rect((40, sy + 10), (300, sy - 10), fill: none, stroke: .8pt + c.line, radius: 2)
  content((296, sy + 14), txt("PCIe switch", size: 7.5pt), anchor: "south-east")
  rect((370, sy + 16), (480, sy - 16), fill: c.blue1, stroke: .8pt + c.blue, radius: 3)
  content((425, sy), txt("CPU0 · host memory", size: 7.5pt, fill: c.ink, weight: 700))
  gpu(g0, gy, "GPU0", hot: true)
  gpu(g1, gy, "GPU1")
  nic(g0, ny, "NIC0")
  nic(g1, ny, "NIC1")
  content((g0 + 4, -206), txt("to another node", size: 7.5pt), anchor: "west")
  let ly = -238
  let swatch(y, col) = line((0, y), (12, y), stroke: hot-w + col)
  legend(0, ly, "GPU in the same node: NVLink, through NVSwitch", swatch(ly, c.teal))
  legend(0, ly - 16, "GPU in another node: PCIe switch → NIC → network", swatch(ly - 16, c.orange))
  legend(0, ly - 32, "host memory: PCIe switch → CPU", swatch(ly - 32, c.ink))
})

/// GPUDirect RDMA between two nodes: GPU -> NIC inside each node's PCIe
/// switch, NIC -> NIC over the network; no CPU or host memory on the path.
#let fig-gdr() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (cy, sy, dy) = (0, -80, -140)
  let hs = hot-w + c.orange
  // one node; `gx`, `nx`: GPU and NIC centres
  let node(ox, name, gx, nx) = {
    let mx = ox + 105
    rect((ox, 22), (ox + 210, -166), fill: none, stroke: (paint: c.grey2, thickness: .8pt, dash: "dashed"), radius: 4)
    content((ox + 8, 14), head(name, fill: c.muted), anchor: "west")
    rect((ox + 40, cy), (ox + 170, cy - 28), fill: c.blue1, stroke: .8pt + c.blue, radius: 3)
    content((mx, cy - 14), txt("CPU0 · host memory", size: 7.5pt, fill: c.ink, weight: 700))
    line((mx, cy - 28), (mx, sy + 10), stroke: cold)
    line((gx, sy - 10), (gx, dy + gpu-h / 2), stroke: cold)
    line((nx, sy - 10), (nx, dy + gpu-h / 2), stroke: cold)
    rect((ox + 20, sy + 10), (ox + 190, sy - 10), fill: none, stroke: .8pt + c.line, radius: 2)
    content((ox + 24, sy + 12), txt("PCIe switch", size: 7pt), anchor: "south-west")
  }
  node(0, "node A", 55, 155)
  node(350, "node B", 495, 395)
  // the network
  line((155 + gpu-w / 2, dy), (395 - gpu-w / 2, dy), stroke: hs)
  rect((240, dy + 12), (320, dy - 12), fill: c.grey1, stroke: .8pt + c.ink, radius: 2)
  content((280, dy), txt("network switch", size: 7pt, fill: c.ink, weight: 700))
  content((280, dy - 22), txt("② InfiniBand / RoCE", size: 7.5pt, fill: c.orange, weight: 600))
  // inside each node, the transfer turns around in the PCIe switch
  line((55, dy + gpu-h / 2), (55, sy), (155, sy), (155, dy + gpu-h / 2), stroke: hs)
  line((395, dy + gpu-h / 2), (395, sy), (495, sy), (495, dy + gpu-h / 2), stroke: hs,
    mark: (end: "stealth", fill: c.orange, scale: .5))
  gpu(55, dy, "GPU0", hot: true)
  nic(155, dy, "NIC0")
  nic(395, dy, "NIC0")
  gpu(495, dy, "GPU0", hot: true)
  content((105, -100), txt("① NIC reads GPU", size: 7.5pt, fill: c.orange, weight: 600))
  content((445, -100), txt("③ NIC writes GPU", size: 7.5pt, fill: c.orange, weight: 600))
})

/// PIX: two GPUs behind one PCIe switch.
#let fig-pix() = cetz.canvas(length: 1pt, {
  let (sy, gy) = (-84, -132)
  cpu(0, 150, "CPU0", 0, hbs: (75,))
  cpu(196, 150, "CPU1", 1)
  upi(150, 196)
  wires(
    ((75, hb-bottom), sw-top(75, sy), false),
    (sw-bot(75, sy), top(45, gy), true),
    (sw-bot(75, sy), top(105, gy), true),
  )
  switch(75, sy, hot: true)
  gpu(45, gy, "GPU0", hot: true)
  gpu(105, gy, "GPU1", hot: true)
  mat((380, -30), names(2), grid-of(2, (i, j) => "PIX"), hot: ((0, 1), (1, 0)))
})

/// PXB: four GPUs on two leaf switches under one parent switch.
#let fig-pxb() = cetz.canvas(length: 1pt, {
  let (s0, s1, gy) = (-84, -128, -174)
  let gx = (32, 88, 142, 198)
  cpu(0, 230, "CPU0", 0, hbs: (115,))
  cpu(276, 90, "CPU1", 1)
  upi(230, 276)
  wires(
    ((115, hb-bottom), sw-top(115, s0), false),
    (sw-bot(115, s0), sw-top(60, s1), true),
    (sw-bot(115, s0), sw-top(170, s1), true),
    (sw-bot(60, s1), top(gx.at(0), gy), true),
    (sw-bot(60, s1), top(gx.at(1), gy), false),
    (sw-bot(170, s1), top(gx.at(2), gy), true),
    (sw-bot(170, s1), top(gx.at(3), gy), false),
  )
  switch(115, s0, hot: true)
  switch(60, s1, hot: true)
  switch(170, s1, hot: true)
  for (k, x) in gx.enumerate() { gpu(x, gy, "GPU" + str(k), hot: k in (0, 2)) }
  let f(i, j) = if calc.quo(i, 2) == calc.quo(j, 2) { "PIX" } else { "PXB" }
  mat((386, -30), names(4), grid-of(4, f), hot: ((0, 2), (2, 0)))
})

/// PHB: two GPUs on two root ports of the same host bridge.
#let fig-phb() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gy = -104
  cpu(0, 150, "CPU0", 0, hbs: (75,), hot-hbs: (75,))
  cpu(196, 150, "CPU1", 1)
  upi(150, 196)
  wires(((66, hb-bottom), top(45, gy), true), ((84, hb-bottom), top(105, gy), true))
  content((92, -64), txt("2 root ports", size: 7pt, style: "italic"), anchor: "west")
  gpu(45, gy, "GPU0", hot: true)
  gpu(105, gy, "GPU1", hot: true)
  mat((380, -30), names(2), grid-of(2, (i, j) => "PHB"), hot: ((0, 1), (1, 0)))
})

/// NODE: two GPUs on two host bridges of the same CPU.
#let fig-node() = cetz.canvas(length: 1pt, {
  let gy = -104
  cpu(0, 170, "CPU0", 0, hbs: (45, 125), hot-hbs: (45, 125), hot-fab: (45, 125))
  cpu(216, 130, "CPU1", 1)
  upi(170, 216)
  wires(((45, hb-bottom), top(45, gy), true), ((125, hb-bottom), top(125, gy), true))
  gpu(45, gy, "GPU0", hot: true)
  gpu(125, gy, "GPU1", hot: true)
  mat((380, -30), names(2), grid-of(2, (i, j) => "NODE"), hot: ((0, 1), (1, 0)))
})

// Two GPUs per socket, each on its own host bridge.
#let gx4 = (40, 110, 236, 306)
#let f-node-sys(i, j) = if calc.quo(i, 2) == calc.quo(j, 2) { "NODE" } else { "SYS" }

/// SYS: GPU1 on CPU0 to GPU2 on CPU1.
#let fig-sys() = cetz.canvas(length: 1pt, {
  let gy = -104
  cpu(0, 150, "CPU0", 0, hbs: (40, 110), hot-hbs: (110,), hot-fab: (110, 150))
  cpu(196, 150, "CPU1", 1, hbs: (236, 306), hot-hbs: (236,), hot-fab: (196, 236))
  upi(150, 196, hot: true)
  wires(..gx4.enumerate().map(((k, x)) => ((x, hb-bottom), top(x, gy), k in (1, 2))))
  for (k, x) in gx4.enumerate() { gpu(x, gy, "GPU" + str(k), hot: k in (1, 2)) }
  mat((372, -30), names(4), grid-of(4, f-node-sys), hot: ((1, 2), (2, 1)))
})

/// NV#: four SXM GPUs, NVLink between every pair, two per socket over PCIe.
#let fig-nv() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gy = -104
  cpu(0, 150, "CPU0", 0, hbs: (40, 110))
  cpu(196, 150, "CPU1", 1, hbs: (236, 306))
  upi(150, 196)
  wires(..gx4.map(x => ((x, hb-bottom), top(x, gy), false)))
  let nv = 1.6pt + c.teal
  let yb = gy - gpu-h / 2
  // adjacent pairs: straight links
  for (i, j) in ((0, 1), (1, 2), (2, 3)) {
    line((gx4.at(i) + gpu-w / 2, gy), (gx4.at(j) - gpu-w / 2, gy), stroke: nv)
  }
  // the others: arcs under the row; GPU0 <-> GPU2 is the highlighted one
  let arc(i, j, di, dj, depth, hot: false) = {
    let a = (gx4.at(i) + di, yb)
    let b = (gx4.at(j) + dj, yb)
    bezier(a, b, (a.at(0), yb - depth), (b.at(0), yb - depth), stroke: if hot { hot-w + c.orange } else { nv })
  }
  arc(1, 3, 8, 8, 30)
  arc(0, 3, -10, 14, 52)
  arc(0, 2, 6, -6, 30, hot: true)
  for (k, x) in gx4.enumerate() { gpu(x, gy, "GPU" + str(k), hot: k in (0, 2)) }
  content((173, yb - 50), txt("NVLink: 4 links on every pair", size: 7.5pt, fill: c.teal, weight: 600))
  mat((372, -30), names(4), grid-of(4, (i, j) => "NV4"), hot: ((0, 2), (2, 0)))
})

#let nv = 1.6pt + c.teal
#let chip(x, y, body, w: 40, h: 22, hot: false) = {
  import cetz.draw: *
  rect((x - w / 2, y + h / 2), (x + w / 2, y - h / 2), fill: if hot { c.orange1 } else { white },
    stroke: if hot { 1.1pt + c.orange } else { .8pt + c.ink }, radius: 2)
  content((x, y), txt(body, size: 7.5pt, fill: c.ink, weight: 700))
}

/// Three ways to spend an A100's 12 NVLinks, and the NV# each one gives.
#let fig-nv-wiring() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let panel(x, title, note, result) = {
    content((x, 0), head(title), anchor: "west")
    content((x, -142), txt(note, size: 7.5pt), anchor: "north-west")
    content((x, -172), txt(result, size: 9pt, fill: c.teal, weight: 700), anchor: "west")
  }

  // bridge pair: all 12 links go to the one partner
  for dy in (-8, 0, 8) { line((48, -75 + dy), (102, -75 + dy), stroke: nv) }
  chip(25, -75, "GPU0", w: 46, h: 30)
  chip(125, -75, "GPU1", w: 46, h: 30)
  content((75, -100), txt("3 bridges × 4", size: 7.5pt, fill: c.teal, weight: 600))
  panel(0, "bridge pair", [PCIe cards. All 12 links \ go to the one partner.], "NV12")

  // NVSwitch, 8 GPUs: links go to switches, any peer can use all 12
  let xs = (207, 247, 287, 327)
  for x in xs {
    line((x, -35), (x, -75), stroke: nv)
    line((x, -115), (x, -75), stroke: nv)
  }
  rect((190, -66), (344, -84), fill: c.teal1, stroke: .8pt + c.teal, radius: 2)
  content((267, -75), txt("6 × NVSwitch", size: 7.5pt, fill: c.ink, weight: 700))
  for (k, x) in xs.enumerate() {
    chip(x, -35, "GPU" + str(k), w: 34, h: 20)
    chip(x, -115, "GPU" + str(k + 4), w: 34, h: 20)
  }
  panel(190, "NVSwitch, 8 GPUs", [2 links to each switch. \ Any one peer gets all 12.], "every pair: NV12")

  // direct, 4 GPUs: 12 links split over 3 peers
  let p = ((405, -35), (505, -35), (405, -115), (505, -115))
  for (i, j) in ((0, 1), (2, 3), (0, 2), (1, 3), (0, 3), (1, 2)) { line(p.at(i), p.at(j), stroke: nv) }
  for (k, q) in p.enumerate() { chip(..q, "GPU" + str(k)) }
  for q in ((455, -28), (455, -122), (396, -75), (514, -75)) {
    content(q, txt("4", size: 7.5pt, fill: c.teal, weight: 700))
  }
  panel(380, "direct, 4 GPUs", [12 links ÷ 3 peers. \ GPU0→GPU1 can use only 4.], "every pair: NV4")
})

/// Three PCIe cards seen from above: two bridged, one left on PCIe.
#let fig-nv-bridge() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let cx = (150, 200, 250)
  let card(y, name) = {
    rect((0, y + 7), (290, y - 7), fill: c.grey1, stroke: .8pt + c.ink, radius: 2)
    content((8, y), txt(name, size: 7.5pt, fill: c.ink, weight: 700), anchor: "west")
    for x in cx { rect((x - 16, y + 4), (x + 16, y - 4), fill: c.ink, stroke: none) }
  }
  card(-20, "GPU0 · slot 1")
  card(-70, "GPU1 · slot 2")
  card(-120, "GPU2 · slot 3")
  for (k, x) in cx.enumerate() {
    rect((x - 20, -12), (x + 20, -78), fill: c.teal1, stroke: 1pt + c.teal, radius: 3)
    content((x, -45), txt("4 links", size: 7pt, fill: c.teal, weight: 700))
    content((x, 0), txt("bridge " + str(k + 1), size: 7.5pt, fill: c.teal, weight: 600))
  }
  content((140, -138), txt("NVLink connectors (4 links each) on the card's top edge", size: 7.5pt), anchor: "north")
  content((310, -45), txt([GPU0 ↔ GPU1: 3 × 4 = 12 links \ *NV12*], size: 8.5pt, fill: c.ink), anchor: "west")
  content((310, -120), txt([GPU2: no partner, PCIe only], size: 8.5pt, fill: c.ink), anchor: "west")
})

/// HGX A100 8-GPU: every GPU sends 2 links to each of 6 NVSwitches;
/// GPU0 -> GPU5 spreads over all six.
#let fig-nvswitch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gx = (75, 205, 335, 465)
  let sx = range(6).map(k => 45 + k * 90)
  let (gt, st, gb) = (0, -80, -160)
  let (gw, gh, sw, sh) = (62, 24, 66, 20)
  // GPU k is on top for k < 4, at the bottom otherwise
  let at(k) = if k < 4 { (gx.at(k), gt - gh / 2) } else { (gx.at(k - 4), gb + gh / 2) }
  let sw-end(k, s) = if k < 4 { (sx.at(s), st + sh / 2) } else { (sx.at(s), st - sh / 2) }
  let hot = (0, 5)
  for k in range(8) { if k not in hot { for s in range(6) { line(at(k), sw-end(k, s), stroke: .5pt + c.grey2) } } }
  for k in hot { for s in range(6) { line(at(k), sw-end(k, s), stroke: 1.4pt + c.orange) } }
  for (s, x) in sx.enumerate() {
    rect((x - sw / 2, st + sh / 2), (x + sw / 2, st - sh / 2), fill: c.teal1, stroke: .8pt + c.teal, radius: 2)
    content((x, st), txt("NVSwitch " + str(s), size: 7pt, fill: c.ink, weight: 700))
  }
  for k in range(4) {
    chip(gx.at(k), gt, "GPU" + str(k), w: gw, h: gh, hot: k in hot)
    chip(gx.at(k), gb, "GPU" + str(k + 4), w: gw, h: gh, hot: k + 4 in hot)
  }
  content((0, gb - 30), txt([each line = 2 links · GPU0 → GPU5 uses all six switches: 6 × 2 = *12 links*], size: 8pt, fill: c.ink), anchor: "west")
})

// ============================================================================
// Summary: how far up the tree each code climbs
// ============================================================================

#let fig-ladder() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let levels = ("NVLink", "1 PCIe switch", "2+ switches", "host bridge", "fabric (2 HBs)", "UPI")
  let (x0, w, rh, bh) = (50, 76, 24, 14)
  for (k, l) in levels.enumerate() {
    content((x0 + (k + .5) * w, 10), txt(l, size: 7.5pt, fill: c.ink, weight: 700))
    line((x0 + k * w, 2), (x0 + k * w, -6 * rh - 4), stroke: (paint: c.hair, thickness: .5pt, dash: "dotted"))
  }
  line((x0 + 6 * w, 2), (x0 + 6 * w, -6 * rh - 4), stroke: (paint: c.hair, thickness: .5pt, dash: "dotted"))
  // (code, solid spans, optional spans): spans are [k0, k1) in level columns
  let rows = (
    ("NV#", ((0, 1),), ()),
    ("PIX", ((1, 2),), ()),
    ("PXB", ((1, 3),), ()),
    ("PHB", ((3, 4),), ((1, 3),)),
    ("NODE", ((3, 5),), ((1, 3),)),
    ("SYS", ((3, 6),), ((1, 3),)),
  )
  for (i, (code, solid, maybe)) in rows.enumerate() {
    let y = -(i + .5) * rh
    content((x0 - 8, y), txt(code, size: 9pt, fill: c.ink, weight: 700), anchor: "east")
    for (k0, k1) in maybe {
      rect((x0 + k0 * w + 3, y + bh / 2), (x0 + k1 * w - 3, y - bh / 2), fill: none,
        stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed"), radius: 2)
    }
    for (k0, k1) in solid {
      let fill = if code == "NV#" { c.teal2 } else if code == "SYS" { c.orange2 } else { c.blue2 }
      rect((x0 + k0 * w + 3, y + bh / 2), (x0 + k1 * w - 3, y - bh / 2), fill: fill, stroke: none, radius: 2)
    }
  }
  let ly = -6 * rh - 18
  legend(x0, ly, "always crossed", box-swatch(x0, ly, c.blue2))
  legend(x0 + 130, ly, "crossed if the GPU sits behind switches",
    box-swatch(x0 + 130, ly, none, stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed")))
})

// ============================================================================
// The two machines
// ============================================================================

/// Machine 1: one GPU per socket.
#let fig-ex1() = cetz.canvas(length: 1pt, {
  let gy = -104
  cpu(0, 150, "CPU0", 0, hbs: (75,), hot-hbs: (75,), hot-fab: (75, 150))
  cpu(196, 150, "CPU1", 1, hbs: (271,), hot-hbs: (271,), hot-fab: (196, 271))
  upi(150, 196, hot: true)
  wires(((75, hb-bottom), top(75, gy), true), ((271, hb-bottom), top(271, gy), true))
  gpu(75, gy, "GPU0", hot: true)
  gpu(271, gy, "GPU1", hot: true)
  cetz.draw.content((75, gy - 22), txt("CPUs 0,2,4,6,8,10", size: 7.5pt, fill: c.blue, weight: 600))
  cetz.draw.content((271, gy - 22), txt("CPUs 1,3,5,7,9,11", size: 7.5pt, fill: c.blue, weight: 600))
  mat((380, -30), names(2), grid-of(2, (i, j) => "SYS"), hot: ((0, 1), (1, 0)))
})

/// Machine 2: two NVLink-bridged pairs, one pair per socket.
#let fig-ex2() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gy = -104
  cpu(0, 150, "CPU0", 0, hbs: (40, 110), hot-hbs: (110,), hot-fab: (110, 150))
  cpu(196, 150, "CPU1", 1, hbs: (236, 306), hot-hbs: (236,), hot-fab: (196, 236))
  upi(150, 196, hot: true)
  wires(..gx4.enumerate().map(((k, x)) => ((x, hb-bottom), top(x, gy), k in (1, 2))))
  // three NVLink bridges per pair, 4 links each
  for (i, j) in ((0, 1), (2, 3)) {
    for dy in (-7, 0, 7) {
      line((gx4.at(i) + gpu-w / 2, gy + dy), (gx4.at(j) - gpu-w / 2, gy + dy), stroke: 1.6pt + c.teal)
    }
    content(((gx4.at(i) + gx4.at(j)) / 2, gy - 22), txt("NV12 · 3 bridges", size: 7.5pt, fill: c.teal, weight: 600))
  }
  for (k, x) in gx4.enumerate() { gpu(x, gy, "GPU" + str(k), hot: k in (1, 2)) }
  let f(i, j) = if calc.quo(i, 2) == calc.quo(j, 2) { "NV12" } else { "SYS" }
  mat((372, -30), names(4), grid-of(4, f), hot: ((1, 2), (2, 1)))
})

/// Machine 3: another 8-GPU server, NV8, one NUMA node per socket. The GPU
/// rows and the NIC0/NIC1 rows of its `nvidia-smi topo -m`, as printed.
#let fig-ex3() = topo-table(
  "nvidia-smi topo -m, machine 3: GPU rows and two NIC rows",
  (
    ("GPU0", "X NV8 NV8 NV8 NV8 NV8 NV8 NV8 NODE NODE PXB PXB NODE NODE SYS SYS SYS SYS 0"),
    ("GPU1", "NV8 X NV8 NV8 NV8 NV8 NV8 NV8 NODE NODE PXB PXB NODE NODE SYS SYS SYS SYS 0"),
    ("GPU2", "NV8 NV8 X NV8 NV8 NV8 NV8 NV8 NODE NODE NODE NODE PXB PXB SYS SYS SYS SYS 0"),
    ("GPU3", "NV8 NV8 NV8 X NV8 NV8 NV8 NV8 NODE NODE NODE NODE PXB PXB SYS SYS SYS SYS 0"),
    ("GPU4", "NV8 NV8 NV8 NV8 X NV8 NV8 NV8 SYS SYS SYS SYS SYS SYS PXB PXB NODE NODE 1"),
    ("GPU5", "NV8 NV8 NV8 NV8 NV8 X NV8 NV8 SYS SYS SYS SYS SYS SYS PXB PXB NODE NODE 1"),
    ("GPU6", "NV8 NV8 NV8 NV8 NV8 NV8 X NV8 SYS SYS SYS SYS SYS SYS NODE NODE PXB PXB 1"),
    ("GPU7", "NV8 NV8 NV8 NV8 NV8 NV8 NV8 X SYS SYS SYS SYS SYS SYS NODE NODE PXB PXB 1"),
    none,
    ("NIC0", "NODE NODE NODE NODE SYS SYS SYS SYS X PIX NODE NODE NODE NODE SYS SYS SYS SYS -"),
    ("NIC1", "NODE NODE NODE NODE SYS SYS SYS SYS PIX X NODE NODE NODE NODE SYS SYS SYS SYS -"),
  ),
  ((0, 7, "GPU", c.ink), (8, 9, "other", c.muted), (10, 17, "GPU NICs", c.orange)),
)

/// Machine 3 as hardware, drawn like `fig-cluster`: the same switch groups,
/// NIC2-9 paired with the GPUs, and NIC0/NIC1 on CPU0 with no GPU. One NUMA
/// node per CPU, so GPU1 -> NIC4 (two host bridges, one CPU) is NODE.
#let fig-ex3-board() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gc = (70, 206, 342, 478)
  let cpu-x = (138, 410)
  let hot = hot-w + c.orange
  let node = hot-w + c.blue
  // links first, boxes on top
  // Group 0's links up to its upper switch are drawn by the two paths.
  for (k, g) in gc.enumerate() {
    for x in (g - 28, g + 28) {
      line((x, 171), (x, 194), stroke: 1.4pt + c.teal)
      if k > 0 { el(x, 149, g, 129, cold) }
    }
    if k > 0 { line((g, 111), (g, 89), stroke: cold) }
    for x in (g - 26, g + 26) { el(g, 71, x, 51, cold) }
  }
  for (k, x) in cpu-x.enumerate() {
    line((gc.at(2 * k) + 32, 80), (x - 24, 80), stroke: cold)
    line((x + 24, 80), (gc.at(2 * k + 1) - 32, 80), stroke: cold)
  }
  // NIC0 and NIC1 hang off CPU0, below the gap between the groups' NICs.
  line((138, 65), (138, 20), stroke: cold)
  for x in (112, 164) { line((138, 20), (x, 20), (x, 11), stroke: cold) }
  line((cpu-x.at(0), 93), (cpu-x.at(0), 100), (cpu-x.at(1), 100), (cpu-x.at(1), 93), stroke: 1.4pt + c.ink)
  content((274, 100), box(fill: white, inset: (x: 3pt, y: 1pt), txt("UPI or xGMI", size: 6.5pt, fill: c.ink, weight: 600)))
  // GPU0 -> NIC2: two switches (PXB); GPU1 -> NIC4: up to CPU0 and down
  // into the other group (NODE). They share the link between the switches.
  el(42, 149, 67, 129, hot)
  line((67, 111), (67, 89), stroke: hot)
  el(70, 71, 44, 51, hot)
  el(98, 149, 73, 129, node)
  line((73, 111), (73, 89), stroke: node)
  line((102, 80), (114, 80), stroke: node)
  line((162, 80), (174, 80), stroke: node)
  el(206, 71, 180, 51, node)
  // boxes
  rect((10, 214), (538, 194), fill: c.teal1, stroke: .8pt + c.teal, radius: 2)
  content((274, 204), txt("NVSwitch: NV8 between every GPU pair", size: 7.5pt, fill: c.ink, weight: 700))
  for (k, g) in gc.enumerate() {
    node-box(g - 28, 160, 48, 22, "GPU" + str(2 * k), fill: if k == 0 { c.orange1 } else { white }, stroke: if k == 0 { 1.1pt + c.orange } else { .8pt + c.ink })
    node-box(g + 28, 160, 48, 22, "GPU" + str(2 * k + 1), fill: if k == 0 { c.blue1 } else { white }, stroke: if k == 0 { 1.1pt + c.blue } else { .8pt + c.ink })
    node-box(g, 120, 64, 18, "PCIe switch", fill: c.grey1, stroke: .7pt + c.line, size: 6.5pt, weight: 600)
    node-box(g, 80, 64, 18, "PCIe switch", fill: c.grey1, stroke: .7pt + c.line, size: 6.5pt, weight: 600)
    node-box(g - 26, 40, 44, 22, "NIC" + str(2 * k + 2), fill: c.teal1, stroke: .8pt + c.teal)
    node-box(g + 26, 40, 44, 22, "NIC" + str(2 * k + 3), fill: c.teal1, stroke: .8pt + c.teal)
  }
  for x in (112, 164) {
    node-box(x, 0, 44, 22, "NIC" + str(if x < 138 { 0 } else { 1 }), fill: c.grey1, stroke: .8pt + c.line)
  }
  for (k, x) in cpu-x.enumerate() {
    rect((x - 24, 95), (x + 24, 65), fill: c.blue1, stroke: .8pt + c.blue, radius: 2)
    content((x, 84), txt("CPU" + str(k), size: 7.5pt, fill: c.ink, weight: 700))
    content((x, 73), txt("NUMA " + str(k), size: 6pt, fill: c.blue, weight: 600))
  }
  let ly = -32
  let swatch(y, s) = line((10, y), (22, y), stroke: s)
  legend(10, ly, "GPU0 → NIC2: two PCIe switches, below the CPU → PXB", swatch(ly, hot))
  legend(10, ly - 16, "GPU1 → NIC4: through CPU0, one NUMA node → NODE", swatch(ly - 16, node))
  legend(10, ly - 32, "NIC0, NIC1: on CPU0, paired with no GPU", box-swatch(10, ly - 32, c.grey1, stroke: .7pt + c.line))
})
