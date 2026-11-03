// Figures for content/posts/languages/go/profiling.typ, drawn with cetz.
// The call graph excerpt is redrawn from a real pprof output (the post's
// gzip / flate example); the flat/cum tree uses the post's made-up numbers.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, tag, txt

// ============================================================================
// flat vs cum
// ============================================================================

/// The post's call tree as an icicle: each bar is a function's cum, the
/// dark part is its flat; children sit under their caller.
#let fig-flat-cum() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let k = 4.6        // pt per ms
  let (h, g) = (20, 6)
  let x0 = 44
  let X(ms) = x0 + ms * k
  // (row, start, cum, flat-start, flat, name)
  let fns = (
    (0, 0, 100, 90, 10, "main()"),
    (1, 0, 90, 85, 5, "A()"),
    (2, 0, 65, 50, 15, "B()"),
    (2, 65, 20, 65, 20, "C()"),
    (3, 0, 50, 0, 50, "D()"),
  )
  for r in range(4) {
    content((x0 - 8, -r * (h + g) - h / 2), txt("深度 " + str(r), size: 6.5pt), anchor: "east")
  }
  for (r, s, cum, fs, flat, name) in fns {
    let y = -r * (h + g)
    rect((X(s), y), (X(s + cum), y - h), fill: c.blue1, stroke: .6pt + c.blue, radius: 2)
    rect((X(fs), y), (X(fs + flat), y - h), fill: c.orange, stroke: none, radius: 2)
    let label = [*#name* · flat #flat · cum #cum]
    // put the label on the light part when there is room, else on the flat part
    let (lx, ink) = if cum - flat >= 30 { ((X(s) + X(fs)) / 2, c.ink) } else { ((X(fs) + X(fs + flat)) / 2, white) }
    content((lx, y - h / 2), txt(label, size: 6.5pt, fill: ink))
  }
  // axis in ms
  let ya = -4 * (h + g) + 2
  line((X(0), ya), (X(100), ya), stroke: .6pt + c.line)
  for ms in (0, 25, 50, 75, 100) {
    line((X(ms), ya), (X(ms), ya - 3), stroke: .6pt + c.line)
    content((X(ms), ya - 5), txt(str(ms) + " ms", size: 6pt), anchor: "north")
  }
  let ly = ya - 26
  legend(x0, ly, "flat：函数自身的耗时", box-swatch(x0, ly, c.orange))
  legend(x0 + 130, ly, "cum：自身 + 所有子调用（整条色条的长度）", box-swatch(x0 + 130, ly, c.blue1, stroke: .6pt + c.blue))
})

// ============================================================================
// Reading the call graph
// ============================================================================

/// An excerpt of the pprof call graph, with what each visual encodes.
#let fig-callgraph() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // pprof's red / grey, in kit colours so they follow the night theme
  let hot = (fill: c.orange1, stroke: c.danger)
  let cold = (fill: c.grey1, stroke: c.grey2)
  let node(p, w, h, lines, tone, name, big: false) = {
    let t = if tone == "hot" { hot } else { cold }
    rect((p.at(0) - w / 2, p.at(1)), (p.at(0) + w / 2, p.at(1) - h), fill: t.fill, stroke: .8pt + t.stroke, name: name)
    content((p.at(0), p.at(1) - h / 2), align(center, {
      set par(leading: .35em)
      for (i, l) in lines.enumerate() {
        text(size: if big and i >= 3 { 9.5pt } else if big { 8.5pt } else { 6.5pt }, fill: c.ink, l)
        if i < lines.len() - 1 { linebreak() }
      }
    }))
  }
  let edge(a, b, w, color, dash, label, side: "east") = {
    line(a, b, stroke: (paint: color, thickness: w, dash: dash), mark: (end: "stealth", fill: color, scale: .7))
    content((a, 50%, b), anchor: if side == "east" { "west" } else { "east" }, pad(x: 5pt, txt(label, size: 6.5pt, fill: c.ink)))
  }
  let red = c.danger

  node((150, 0), 120, 50, ([gzip], [(\*Writer)], [Write], [0.08ms (0.0025%)], [of 2083.20ms (66.20%)]), "hot", "w")
  node((40, -86), 80, 36, ([flate], [NewWriter], [0 of 72.12ms (2.29%)]), "cold", "nw")
  node((150, -86), 120, 50, ([flate], [(\*compressor)], [write], [0.44ms (0.014%)], [of 2003.08ms (63.66%)]), "hot", "cw")
  node((150, -176), 170, 82, ([flate], [(\*compressor)], [deflate], [1305.64ms (41.49%)], [of 1993.68ms (63.36%)]), "hot", "d", big: true)

  edge((110, -50), (60, -86), .6pt, c.grey2, none, [72.12ms], side: "west")
  edge((150, -50), (150, -86), 2pt, red, "dashed", [2003.08ms])
  edge((150, -136), (150, -176), 3pt, red, none, [1993.68ms])

  // annotations
  let ax = 290
  let note(y, title, body, to: none) = {
    content((ax, y), anchor: "north-west", box(width: 262pt, {
      set par(leading: .45em)
      txt(title, size: 7pt, fill: c.orange, weight: 600)
      linebreak()
      txt(body, size: 6.5pt)
    }))
    if to != none { arrow((ax - 4, y - 6), to, color: c.orange) }
  }
  note(4, [节点标签], [`flat (flat%) of cum (cum%)`：前一个数是函数自身的耗时，`of` 后面是含子调用的总耗时])
  note(-38, [节点颜色], [按 cum 着色：cum 越大越红，接近 0 时为灰色（diff 时负值为绿色）])
  note(-80, [字号], [按 flat 缩放：deflate 自身耗时最多，字最大])
  note(-116, [边的粗细与颜色], [沿这条调用路径消耗的资源，越多越粗、越红])
  note(-152, [虚线边], [两个节点之间有调用被省略（如 Write 并非直接调用 write）])
  note(-196, [实线边], [调用方直接调用被调用方])
})
