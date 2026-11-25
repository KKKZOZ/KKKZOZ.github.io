// Figures for content/posts/ml-systems/cpu-gemv-bandwidth.typ, drawn with cetz.
// Ported from group-meeting slides: the canvases keep their slide geometry
// (10-14pt text, up to ~800pt wide) and `fig` scales each one down to the
// text column. Colours come from the theme palette so that every figure
// follows the day / night switch; computed tints (lighten / darken) would not.
// 1pt per unit, y grows upward.

#import "@preview/cetz:0.5.2" as cz
#import "@tola-modules/nasapunk:0.0.0": cetz
#let svg-frame = cetz.svg-frame
#import "@tola-modules/nasapunk:0.0.0": c
#import "@tola-modules/nasapunk:0.0.0": palette

#let c-blue = c.blue
#let c-blue-l = c.blue2
#let c-blue-p = c.blue1
#let c-orange = c.orange
#let c-orange-l = c.orange2
#let c-orange-p = c.orange1
#let c-red = c.danger
#let c-muted = c.muted
#let c-rule = palette.rule
#let c-brown = palette.warning
#let c-brown-l = palette.accent-line
#let c-sand = palette.sand
#let c-sand-d = c.grey2
#let c-teal = c.teal1
#let c-gray = c.grey1

/// A slide-sized drawing scaled to the text column, as inline SVG in HTML.
#let fig(s, body) = svg-frame(scale(s, reflow: true, body))
#let canvas(body) = cz.canvas(length: 1pt, body)
#let panel-title(body) = text(12pt, weight: "bold", body)

/// Horizontal bars: (label, value, fill, note); sx = pt per unit; `opt`
/// draws the optimal latency as a dashed line.
#let hbars(rows, sx, opt: none, opt-label: none) = canvas({
  import cz.draw: *
  let n = rows.len()
  for (i, (label, v, color, note)) in rows.enumerate() {
    let y = (n - 1 - i) * 24
    content((-8, y + 9), text(12pt, label), anchor: "east")
    rect((0, y), (v * sx, y + 18), fill: color, stroke: .6pt + c-muted)
    content((v * sx + 5, y + 9), text(11pt, note), anchor: "west")
  }
  line((0, -4), (0, n * 24), stroke: .6pt + c-muted)
  if opt != none {
    line((opt * sx, -6), (opt * sx, n * 24 + 2), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
    content((opt * sx, -15), text(10pt, weight: "bold", fill: c-red, opt-label))
  }
})

// ============================================================================
// Memory bandwidth
// ============================================================================

#let fig-ddr() = fig(85%, canvas({
  import cz.draw: *
  let p = 64
  content((-8, 62), text(11pt, weight: "bold")[clock], anchor: "east")
  let pts = ()
  for i in range(4) {
    pts += ((i * p, 50), (i * p, 74), (i * p + p / 2, 74), (i * p + p / 2, 50))
  }
  pts.push((4 * p, 50))
  line(..pts, stroke: 1.2pt + c-blue)
  content((2 * p, 88), text(10pt, fill: c-blue)[2400 MHz I/O clock])
  for i in range(8) {
    line((i * p / 2, 46), (i * p / 2, 22), stroke: (paint: c-rule, dash: "dotted", thickness: .6pt))
  }
  content((-8, 10), text(11pt, weight: "bold")[data], anchor: "east")
  for i in range(8) {
    let x = i * p / 2
    let even = calc.rem(i, 2) == 0
    rect((x + 1, 0), (x + p / 2 - 1, 20), fill: if even { c-orange } else { c-orange-l }, stroke: none)
    content((x + p / 4, 10), text(9pt, fill: if even { white } else { black })[D#i])
  }
  content((2 * p, -14), text(10pt, fill: c-orange)[one transfer on every rising *and* falling edge])
}))

// sticks: array of (channel, slot, label); channel 0 = A, 1 = B
#let channel-diagram(sticks) = canvas({
  import cz.draw: *
  rect((30, 110), (230, 140), radius: 5pt, fill: c-blue, stroke: none)
  content((130, 125), text(11pt, fill: white)[memory controller])
  let used = 0
  for (ch, cx) in ((0, 80), (1, 180)) {
    let on = sticks.any(s => s.at(0) == ch)
    if on { used += 1 }
    line((cx, 110), (cx, 68), stroke: if on { 1.6pt + c-blue } else {
      (paint: c-rule, thickness: 1.2pt, dash: "dashed")
    })
    content(
      (cx + 4, 89),
      text(10pt, fill: if on { c-blue } else { c-muted })[Ch #("AB".at(ch)) · #if on [64-bit] else [idle]],
      anchor: "west",
    )
    for (slot, y) in ((0, 48), (1, 26)) {
      let st = sticks.find(s => s.at(0) == ch and s.at(1) == slot)
      if st != none {
        rect((cx - 40, y), (cx + 40, y + 18), fill: c-sand, stroke: .5pt + c-muted)
        content((cx, y + 9), text(10pt, weight: "bold", st.at(2)))
      } else {
        rect((cx - 40, y), (cx + 40, y + 18), fill: white, stroke: (paint: c-rule, thickness: .6pt, dash: "dashed"))
        content((cx, y + 9), text(9pt, fill: c-muted)[empty])
      }
    }
  }
  content((130, 6), text(12pt)[#(used * 64)-bit · *#(used * 38.4) GB/s*])
})

#let fig-channels() = fig(78%, grid(
  columns: 2,
  column-gutter: 36pt,
  row-gutter: 10pt,
  align: center,
  panel-title[1 × 64 GB (single channel)], panel-title[2 × 32 GB (dual channel)],
  channel-diagram(((0, 0, [64 GB]),)), channel-diagram(((0, 0, [32 GB]), (1, 0, [32 GB]))),
))

#let fig-four-sticks() = fig(78%, grid(
  columns: 2,
  column-gutter: 36pt,
  row-gutter: 10pt,
  align: (center, left),
  panel-title[4 × 32 GB], panel-title[Peak bandwidth at DDR5-4800],
  channel-diagram(((0, 0, [32 GB]), (0, 1, [32 GB]), (1, 0, [32 GB]), (1, 1, [32 GB]))),
  align(horizon, canvas({
    import cz.draw: *
    let sx = 2.4
    let rows = (
      ([1 × 64 GB], 38.4, c-gray, [64 GB]),
      ([2 × 32 GB], 76.8, c-blue, [64 GB]),
      ([4 × 32 GB], 76.8, c-blue, [*128 GB*]),
    )
    for (i, (label, v, fill, cap)) in rows.enumerate() {
      let y = (rows.len() - 1 - i) * 30
      content((-6, y + 10), text(11pt, label), anchor: "east")
      rect((0, y), (v * sx, y + 20), fill: fill, stroke: .5pt + c-muted)
      content((v * sx + 4, y + 10), text(11pt)[*#v* GB/s #text(fill: c-muted)[· #cap]], anchor: "west")
    }
  })),
))

#let fig-speed-grades() = fig(80%, canvas({
  import cz.draw: *
  let sx = 1.75
  let rows = (
    ([DDR4-3200], 51.2, c-gray, []),
    ([DDR5-4800], 76.8, c-blue, [our Ultra 9]),
    ([DDR5-5600], 89.6, c-teal, [285K, 2 × UDIMM]),
    ([DDR5-6400], 102.4, c-sand, [285K official max, 2 × CUDIMM]),
    ([DDR5-7200], 115.2, c-teal, []),
    ([DDR5-8000], 128, c-sand, [285K 200S Boost (overclock)]),
    ([DDR5-9600], 153.6, c-teal, []),
  )
  for (i, (label, v, fill, note)) in rows.enumerate() {
    let y = (rows.len() - 1 - i) * 20
    content((-6, y + 7), text(11pt, label), anchor: "east")
    rect((0, y), (v * sx, y + 14), fill: fill, stroke: .5pt + c-muted)
    content((v * sx + 4, y + 7), text(10pt)[*#v* #text(fill: c-orange, note)], anchor: "west")
  }
  content((0, -14), text(10pt, fill: c-muted)[dual-channel peak, GB/s], anchor: "west")
}))

#let dimm-diagram(ckd) = canvas({
  import cz.draw: *
  let clk = if ckd { c-orange } else { c-muted }
  rect((0, 0), (300, 72), radius: 3pt, fill: c-teal, stroke: .6pt + c-muted)
  rect((10, 0), (290, 7), fill: c-sand-d, stroke: none)
  let chip-x = range(8).map(i => if i < 4 { 10 + i * 32 } else { 168 + (i - 4) * 32 })
  for x in chip-x {
    rect((x, 36), (x + 26, 64), fill: c-gray, stroke: .5pt + c-muted)
    content((x + 13, 50), text(7pt)[DRAM])
  }
  line((150, 7), (150, if ckd { 40 } else { 22 }), stroke: 1.2pt + c-muted)
  if ckd {
    rect((139, 40), (161, 60), radius: 2pt, fill: c-orange, stroke: none)
    content((150, 50), text(7pt, fill: white, weight: "bold")[CKD])
    line((143, 40), (143, 22), (23, 22), stroke: 1.4pt + clk)
    line((157, 40), (157, 22), (277, 22), stroke: 1.4pt + clk)
  } else {
    line((23, 22), (277, 22), stroke: 1.2pt + clk)
  }
  for x in chip-x { line((x + 13, 22), (x + 13, 36), stroke: (if ckd { 1.4pt } else { 1.2pt }) + clk) }
  content((150, -9), text(9pt, fill: c-muted)[clock from the CPU's memory controller])
  content((150, -28), text(10pt, weight: "bold")[clock at the DRAM chips])
  let (y0, a) = (-62, 12)
  let pts = if ckd {
    let p = ()
    for i in range(5) {
      p += ((30 + i * 48, y0), (30 + i * 48, y0 + 2 * a), (54 + i * 48, y0 + 2 * a), (54 + i * 48, y0))
    }
    p
  } else {
    range(241).map(k => {
      let t = k / 240 * 5 * 2 * calc.pi
      (30 + k, y0 + a + a * calc.tanh(1.5 * calc.sin(t)) / calc.tanh(1.5))
    })
  }
  line(..pts, stroke: 1.4pt + clk)
})

#let fig-dimm() = fig(78%, grid(
  columns: 2,
  column-gutter: 36pt,
  row-gutter: 10pt,
  align: center,
  panel-title[UDIMM (unbuffered DIMM)], panel-title[CUDIMM (clocked UDIMM)],
  dimm-diagram(false), dimm-diagram(true),
))

#let fig-cas() = fig(85%, canvas({
  import cz.draw: *
  let w = 9
  content((-8, 8), text(11pt, weight: "bold")[READ], anchor: "east")
  for i in range(40) { rect((i * w, 0), (i * w + w - 1, 16), fill: c-gray, stroke: .3pt + c-muted) }
  rect((40 * w, 0), (44 * w, 16), fill: c-orange, stroke: none)
  content((42 * w, 8), text(9pt, fill: white)[data])
  line((0, 26), (40 * w - 1, 26), mark: (start: "|", end: "|"), stroke: .8pt + c-blue)
  content((20 * w, 36), text(11pt, fill: c-blue)[40 cycles × 0.417 ns (2400 MHz) = *16.7 ns*])
}))

#let fig-bus-steps() = fig(78%, canvas({
  import cz.draw: *
  let bw = 140
  let gap = 110
  let box-at(i, title, val, fill) = {
    let x = i * (bw + gap)
    rect((x, 0), (x + bw, 46), radius: 5pt, fill: fill, stroke: .7pt + c-rule)
    content((x + bw / 2, 32), text(10pt, title))
    content((x + bw / 2, 13), text(13pt, weight: "bold", val))
  }
  box-at(0, [285K · 6400 · 128-bit], [102.4 GB/s], white)
  box-at(1, [6400 · *256-bit*], [204.8 GB/s], c-teal)
  box-at(2, [*8533* · 256-bit (M4 Pro)], [273 GB/s], c-sand)
  for (i, lbl) in ((0, [× 2 bus width]), (1, [× 1.33 rate])) {
    let x = i * (bw + gap) + bw
    line((x + 8, 20), (x + gap - 8, 20), mark: (end: ">", fill: c-orange), stroke: 1.4pt + c-orange)
    content((x + gap / 2, 34), text(11pt, weight: "bold", fill: c-orange, lbl))
  }
}))

#let fig-controllers() = fig(80%, canvas({
  import cz.draw: *
  content((130, 168), text(13pt, weight: "bold")[Core Ultra 9 285K])
  rect((60, 110), (200, 150), radius: 5pt, fill: c-blue, stroke: none)
  content((130, 130), text(11pt, fill: white)[memory controller])
  for (cx, ch) in ((80, [A]), (180, [B])) {
    line((cx, 110), (cx, 74), stroke: 1.6pt + c-blue)
    content((cx + 4, 92), text(10pt, fill: c-blue)[Ch #ch · 64-bit], anchor: "west")
    for (j, y) in ((0, 52), (1, 30)) {
      rect((cx - 40, y), (cx + 40, y + 16), fill: if j == 0 { c-sand } else { c-gray }, stroke: .5pt + c-muted)
      content((cx, y + 8), text(9pt)[DIMM #(j + 1)])
    }
  }
  content((130, 8), text(11pt)[2 × 64 = *128-bit*, even with 4 sticks])
  let x0 = 330
  content((x0 + 130, 168), text(13pt, weight: "bold")[M4 Pro])
  rect((x0 + 70, 50), (x0 + 190, 130), radius: 5pt, fill: c-blue, stroke: none)
  content((x0 + 130, 98), text(11pt, fill: white)[SoC])
  content((x0 + 130, 80), text(10pt, fill: white)[CPU + GPU share it])
  for (px, py) in ((x0, 96), (x0, 52), (x0 + 210, 96), (x0 + 210, 52)) {
    let edge = if px == x0 { (px + 50, x0 + 70) } else { (px, x0 + 190) }
    line((edge.at(0), py + 16), (edge.at(1), py + 16), stroke: 1.6pt + c-blue)
    rect((px, py), (px + 50, py + 32), radius: 3pt, fill: c-sand, stroke: .5pt + c-muted)
    content((px + 25, py + 21), text(9pt)[LPDDR5X])
    content((px + 25, py + 9), text(9pt, fill: c-blue)[64-bit])
  }
  content((x0 + 130, 8), text(11pt)[4 × 64 = *256-bit*, in the package])
}))

#let fig-thor-bw() = fig(80%, canvas({
  import cz.draw: *
  let sx = 0.95
  let rows = (
    ([Core Ultra 9 285K], 76.8, c-gray, [DDR5-4800 · 128-bit]),
    ([Jetson AGX Orin], 204.8, c-teal, [LPDDR5-6400 · 256-bit]),
    ([M4 Pro], 273, c-sand, [LPDDR5X-8533 · 256-bit]),
    ([Jetson AGX Thor], 273, c-blue, [LPDDR5X-8533 · 256-bit]),
  )
  for (i, (label, v, fill, spec)) in rows.enumerate() {
    let y = (rows.len() - 1 - i) * 36
    content((-6, y + 13), text(11pt, weight: "bold", label), anchor: "east")
    rect((0, y + 6), (v * sx, y + 22), fill: fill, stroke: .5pt + c-muted)
    content((v * sx + 4, y + 14), text(11pt)[*#v* GB/s], anchor: "west")
    content((0, y), text(9pt, fill: c-muted, spec), anchor: "north-west")
  }
}))

// Dual-socket board; n = populated channels per socket (slot 1 of each).
#let fig-xeon-board(n, stick, bottom) = fig(75%, canvas({
  import cz.draw: *
  let pitch = 38
  let sw = 6 * pitch
  let gap = 80
  for (s, x0) in ((0, 0), (1, sw + gap)) {
    rect((x0, 100), (x0 + sw, 150), radius: 5pt, fill: c-blue, stroke: none)
    content((x0 + sw / 2, 132), text(11pt, weight: "bold", fill: white)[Socket #s · 24 cores])
    content((x0 + sw / 2, 113), text(9pt, fill: white)[6-channel memory controller])
    for ch in range(6) {
      let cx = x0 + pitch * (ch + 0.5)
      let on = ch < n
      line((cx, 100), (cx, 62), stroke: if on { 1.6pt + c-blue } else {
        (paint: c-rule, thickness: 1.2pt, dash: "dashed")
      })
      content((cx + 3, 84), text(8pt, fill: if on { c-blue } else { c-muted }, "ABCDEF".at(ch)), anchor: "west")
      for (slot, y) in ((0, 42), (1, 22)) {
        if on and slot == 0 {
          rect((cx - 16, y), (cx + 16, y + 16), fill: c-sand, stroke: .5pt + c-muted)
          content((cx, y + 8), text(8pt, weight: "bold", stick))
        } else {
          rect((cx - 16, y), (cx + 16, y + 16), fill: white, stroke: (paint: c-rule, thickness: .6pt, dash: "dashed"))
        }
      }
    }
    content((x0 + sw / 2, 6), text(11pt, bottom))
  }
  line((sw + 6, 125), (sw + gap - 6, 125), mark: (start: ">", end: ">", fill: c-orange), stroke: 1.6pt + c-orange)
  content((sw + gap / 2, 137), text(10pt, weight: "bold", fill: c-orange)[UPI])
}))

// ============================================================================
// Core Ultra 9
// ============================================================================

// GB/s vs. threads. probe: (threads, GB/s); ggml: (threads, mid, lo, hi), lo/hi = range over runs
#let u9-probe = ((1, 19), (2, 34), (4, 54), (8, 67), (16, 57), (24, 66))
#let u9-q2 = ((2, 18.6), (4, 26.9), (6, 34.3), (8, 38.4), (10, 46.8), (16, 61.3, 59.3, 63.2), (24, 65.4, 64.5, 66.3))
#let u9-q4 = ((2, 17.2), (4, 25.2), (6, 34.7), (8, 38.0), (10, 46.3), (16, 59.9, 57.8, 62.0), (24, 64.5, 62.2, 66.8))

#let u9-bw-chart(show-ggml) = canvas({
  import cz.draw: *
  let sx = 15
  let sy = 2.1
  let xmax = 25 * sx
  rect((0, 0), (8.5 * sx, 82 * sy), fill: c-gray, stroke: none)
  content((4.25 * sx, 10), text(10pt, fill: c-muted)[8 P-cores])
  content((16.5 * sx, 10), text(10pt, fill: c-muted)[\+ E-cores])
  line((0, 0), (xmax, 0), stroke: .6pt + c-muted)
  line((0, 0), (0, 82 * sy), stroke: .6pt + c-muted)
  for t in (20, 40, 60, 80) {
    line((0, t * sy), (xmax, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
    content((-6, t * sy), text(10pt)[#t], anchor: "east")
  }
  for t in (1, 2, 4, 6, 8, 10, 16, 24) { content((t * sx, -11), text(10pt)[#t]) }
  content((12.5 * sx, -27), text(11pt, fill: c-muted)[threads])
  content((-30, 41 * sy), text(11pt, fill: c-muted)[GB/s], angle: 90deg)
  line((0, 76.8 * sy), (xmax, 76.8 * sy), stroke: (paint: c-red, dash: "dashed", thickness: .9pt))
  content((xmax + 6, 76.8 * sy), text(10pt, fill: c-red)[DDR5-4800 peak 76.8], anchor: "west")
  line(..u9-probe.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1.2pt + c-blue)
  for (t, v) in u9-probe { circle((t * sx, v * sy), radius: 3.5, fill: c-blue, stroke: none) }
  content((8 * sx, 67 * sy + 10), text(10pt, weight: "bold", fill: c-blue)[67])
  let sq(x, y, fill, stroke) = rect((x - 4, y - 4), (x + 4, y + 4), fill: fill, stroke: stroke)
  if show-ggml {
    for (series, dx, fill, stroke) in ((u9-q2, -3, c-orange, none), (u9-q4, 3, white, 1.2pt + c-orange)) {
      line(..series.map(p => (p.at(0) * sx + dx, p.at(1) * sy)), stroke: .9pt + c-orange)
      for p in series {
        let x = p.at(0) * sx + dx
        if p.len() == 4 { line((x, p.at(2) * sy), (x, p.at(3) * sy), stroke: .8pt + c-orange) }
        sq(x, p.at(1) * sy, fill, stroke)
      }
    }
    content((8 * sx + 14, 38 * sy - 2), text(10pt, weight: "bold", fill: c-orange)[38], anchor: "west")
  }
  let ly = 54 * sy
  circle((xmax + 12, ly), radius: 3.5, fill: c-blue, stroke: none)
  content((xmax + 22, ly), text(10pt)[read-only probe], anchor: "west")
  if show-ggml {
    sq(xmax + 12, ly - 18, c-orange, none)
    content((xmax + 22, ly - 18), text(10pt)[ggml Q2_K], anchor: "west")
    sq(xmax + 12, ly - 36, white, 1.2pt + c-orange)
    content((xmax + 22, ly - 36), text(10pt)[ggml Q4_0], anchor: "west")
  }
})

#let fig-u9-ceiling() = fig(80%, u9-bw-chart(false))
#let fig-u9-kernels() = fig(80%, u9-bw-chart(true))

#let fig-u9-optimal() = fig(80%, canvas({
  import cz.draw: *
  let sx = 0.26
  let p95 = text(fill: c-red)[ · p95 6000]
  let groups = (
    (
      [Q2_K],
      493,
      (
        ([M4 Pro · 8T], 334, c-teal, [334]),
        ([Ultra 9 · 8T], 860, c-orange, [860]),
        ([Ultra 9 · 16T], 540, c-sand, [520–560]),
        ([Ultra 9 · 24T], 505, c-sand-d, [500–510#p95]),
      ),
    ),
    (
      [Q4_0],
      845,
      (
        ([M4 Pro · 8T], 332, c-teal, [332]),
        ([Ultra 9 · 8T], 1490, c-orange, [1490]),
        ([Ultra 9 · 16T], 945, c-sand, [910–980]),
        ([Ultra 9 · 24T], 880, c-sand-d, [850–910#p95]),
      ),
    ),
  )
  line((0, -8), (0, 200), stroke: .6pt + c-muted)
  for (gi, (name, floor, bars)) in groups.enumerate() {
    let y0 = (1 - gi) * 108
    content((-120, y0 + 38), text(14pt, weight: "bold", name), anchor: "east")
    for (bi, (label, v, fill, note)) in bars.enumerate() {
      let y = y0 + (3 - bi) * 20
      content((-8, y + 7), text(11pt, label), anchor: "east")
      rect((0, y), (v * sx, y + 14), fill: fill, stroke: .6pt + c-muted)
      content((v * sx + 5, y + 7), text(10pt, note), anchor: "west")
    }
    line((floor * sx, y0 - 6), (floor * sx, y0 + 82), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
    content((floor * sx, y0 + 90), text(10pt, weight: "bold", fill: c-red)[optimal #floor])
  }
  content((420, -12), text(10pt, fill: c-muted)[µs per layer], anchor: "east")
}))

// Per-layer µs vs. threads: (threads, compute floor, bandwidth floor, no prefetch, prefetch)
#let u9-floors-q2 = (
  (1, 1267, 1829, 2148, 2032),
  (2, 633, 1520, 1816, 1496),
  (4, 317, 895, 1256, 877),
  (6, 211, 685, 962, 666),
  (8, 158, 568, 860, 563),
  (10, 127, 513, 701, 517),
  (12, 106, 497, 598, 508),
  (16, 79, 494, 529, 498),
  (20, 63, 494, 501, 509),
)
#let u9-floors-q4 = (
  (1, 2219, 3136, 3367, 3494),
  (2, 1109, 2606, 3322, 2982),
  (4, 555, 1534, 2274, 1613),
  (6, 370, 1175, 1632, 1169),
  (8, 277, 974, 1485, 971),
  (10, 222, 880, 1221, 917),
  (12, 185, 852, 1054, 867),
  (16, 139, 846, 915, 862),
  (20, 111, 847, 864, 865),
)

#let u9-floors-panel(rows, ymax, ticks, legend: false) = canvas({
  import cz.draw: *
  let sx = 11
  let sy = 160 / ymax
  let xmax = 21 * sx
  rect((0, 0), (8.5 * sx, ymax * sy), fill: c-gray, stroke: none)
  content((4.25 * sx, 160 - 9), text(9pt, fill: c-muted)[8 P-cores])
  line((0, 0), (xmax, 0), stroke: .6pt + c-muted)
  line((0, 0), (0, ymax * sy), stroke: .6pt + c-muted)
  for t in ticks {
    line((0, t * sy), (xmax, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
    content((-6, t * sy), text(10pt)[#t], anchor: "east")
  }
  for r in rows { content((r.at(0) * sx, -11), text(10pt)[#r.at(0)]) }
  content((10.5 * sx, -27), text(11pt, fill: c-muted)[threads])
  let pts(i) = rows.map(r => (r.at(0) * sx, r.at(i) * sy))
  let sq(x, y) = rect((x - 3.5, y - 3.5), (x + 3.5, y + 3.5), fill: c-orange, stroke: none)
  line(..pts(1), stroke: (paint: c-orange-l, dash: "dashed", thickness: 1.2pt))
  line(..pts(2), stroke: (paint: c-blue, dash: "dashed", thickness: 1.4pt))
  line(..pts(3), stroke: 1pt + c-muted)
  for p in pts(3) { circle(p, radius: 3.2, fill: white, stroke: 1.1pt + c-muted) }
  line(..pts(4), stroke: 1.2pt + c-orange)
  for p in pts(4) { sq(..p) }
  // gap between no prefetch and the bandwidth floor at 8 threads
  let r8 = rows.find(r => r.at(0) == 8)
  content(
    (8 * sx + 7, r8.at(3) * sy + 8),
    text(10pt, weight: "bold", fill: c-red)[#calc.round(r8.at(3) / r8.at(2), digits: 1)×],
    anchor: "west",
  )
  if legend {
    let lx = 11 * sx
    let ly = ymax * sy - 14
    for (i, (label, kind)) in (
      ([no prefetch], "nopf"),
      ([prefetch], "pf"),
      ([bandwidth floor], "bw"),
      ([compute floor], "comp"),
    ).enumerate() {
      let y = ly - i * 15
      if kind == "nopf" { circle((lx, y), radius: 3.2, fill: white, stroke: 1.1pt + c-muted) }
      if kind == "pf" { sq(lx, y) }
      if kind == "bw" { line((lx - 7, y), (lx + 7, y), stroke: (paint: c-blue, dash: "dashed", thickness: 1.4pt)) }
      if kind == "comp" {
        line((lx - 7, y), (lx + 7, y), stroke: (paint: c-orange-l, dash: "dashed", thickness: 1.2pt))
      }
      content((lx + 12, y), text(10pt, label), anchor: "west")
    }
  }
})

#let fig-u9-floors() = fig(85%, grid(
  columns: 2,
  column-gutter: 36pt,
  row-gutter: 12pt,
  align: center,
  panel-title[Q2_K], panel-title[Q4_0],
  u9-floors-panel(u9-floors-q2, 2600, (500, 1000, 1500, 2000)),
  u9-floors-panel(u9-floors-q4, 4000, (1000, 2000, 3000), legend: true),
))

#let fig-u9-tail() = fig(80%, canvas({
  import cz.draw: *
  let cell(i, y, fill, stroke) = rect((i * 10, y), (i * 10 + 8, y + 14), fill: fill, stroke: stroke)
  let busy = c-orange-l
  content((0, 98), text(12pt, weight: "bold")[24 threads], anchor: "west")
  for i in range(24) { cell(i, 70, if i == 13 { c-red } else { busy }, .4pt + c-muted) }
  content((13 * 10 + 4, 92), text(10pt, fill: c-red)[OS task preempts], anchor: "south")
  content((120, 58), text(10pt)[the other 23 wait at the barrier], anchor: "center")
  content((0, 30), text(12pt, weight: "bold")[23 threads], anchor: "west")
  for i in range(24) { cell(i, 2, if i == 23 { c-gray } else { busy }, .4pt + c-muted) }
  content((23 * 10 + 4, -8), text(10pt, fill: c-blue)[OS runs here], anchor: "north")
  line((0, -24), (78, -24), stroke: .8pt + c-blue)
  content((39, -32), text(9pt, fill: c-muted)[P-cores])
  line((80, -24), (238, -24), stroke: .8pt + c-muted)
  content((159, -32), text(9pt, fill: c-muted)[E-cores])
}))

#let fig-prefetch() = fig(80%, canvas({
  import cz.draw: *
  let rows = 7
  let w = 300
  for r in range(rows) {
    let y = (rows - 1 - r) * 20
    let fill = if r == 2 { c-orange } else if r == 4 { c-blue-l } else if r < 2 { c-gray } else { white }
    rect((0, y), (w, y + 16), fill: fill, stroke: .5pt + c-muted)
    content((-8, y + 8), text(11pt)[row #(r + 1)], anchor: "east")
  }
  content((w / 2, 4 * 20 + 8), text(11pt, weight: "bold", fill: white)[computing row _r_])
  content((w / 2, 2 * 20 + 8), text(11pt)[prefetch row _r_ + _D_ into cache])
  line(
    (w + 10, 4 * 20 + 8),
    (w + 24, 4 * 20 + 8),
    (w + 24, 2 * 20 + 8),
    (w + 10, 2 * 20 + 8),
    mark: (end: ">"),
    stroke: 1pt + c-orange,
  )
  content((w + 30, 3 * 20 + 8), text(11pt, fill: c-orange)[_D_ = 2 rows ahead], anchor: "west")
  content((w / 2, -14), text(10pt, fill: c-muted)[weight matrix; threads take dynamic 64-row chunks (as ggml)])
}))

#let pf-on = ((1, 17.5), (4, 37), (6, 51), (8, 61), (12, 65), (16, 66.5), (20, 66.5))

#let fig-u9-prefetch() = fig(85%, canvas({
  import cz.draw: *
  let sx = 12
  let sy = 1.6
  let xmax = 25 * sx
  rect((0, 0), (8.5 * sx, 75 * sy), fill: c-gray, stroke: none)
  content((4.25 * sx, 10), text(10pt, fill: c-muted)[8 P-cores])
  content((16.75 * sx, 10), text(10pt, fill: c-muted)[\+ E-cores])
  line((0, 0), (xmax, 0), stroke: .6pt + c-muted)
  line((0, 0), (0, 75 * sy), stroke: .6pt + c-muted)
  for t in (20, 40, 60) {
    line((0, t * sy), (xmax, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
    content((-6, t * sy), text(10pt)[#t], anchor: "east")
  }
  for t in (1, 4, 8, 12, 16, 20, 24) { content((t * sx, -11), text(10pt)[#t]) }
  content((12.5 * sx, -27), text(11pt, fill: c-muted)[threads])
  content((-30, 37 * sy), text(11pt, fill: c-muted)[GB/s], angle: 90deg)
  line((0, 67 * sy), (xmax, 67 * sy), stroke: (paint: c-blue, dash: "dashed", thickness: .9pt))
  content((xmax, 67 * sy + 9), text(10pt, fill: c-blue)[read ceiling 67], anchor: "east")
  // ggml Q2_K, same runs as the kernel chart (Q4_0 within 2 GB/s)
  line(..u9-q2.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1pt + c-muted)
  for p in u9-q2 { circle((p.at(0) * sx, p.at(1) * sy), radius: 3.5, fill: white, stroke: 1.2pt + c-muted) }
  line(..pf-on.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1.4pt + c-orange)
  for (t, v) in pf-on { rect((t * sx - 4, v * sy - 4), (t * sx + 4, v * sy + 4), fill: c-orange, stroke: none) }
  line((8 * sx + 8, 39.5 * sy), (8 * sx + 8, 59 * sy), mark: (end: ">"), stroke: 1.2pt + c-red)
  content((8 * sx + 14, 30 * sy), text(11pt, weight: "bold", fill: c-red)[38 → 61], anchor: "west")
  circle((sx * 15, 38 * sy), radius: 3.5, fill: white, stroke: 1.2pt + c-muted)
  content((sx * 15 + 9, 38 * sy), text(10pt)[ggml], anchor: "west")
  rect((sx * 15 - 4, 30 * sy - 4), (sx * 15 + 4, 30 * sy + 4), fill: c-orange, stroke: none)
  content((sx * 15 + 9, 30 * sy), text(10pt)[gemv-probe + prefetch], anchor: "west")
}))

#let fig-u9-best() = fig(74%, canvas({
  import cz.draw: *
  let sx = 0.16
  let cfgs = (
    ([ggml · 8 P-cores], 860, 1490, c-orange, [16]),
    ([8 P-cores + prefetch], 535, 930, c-blue-l, [16]),
    ([16 threads + prefetch], 497, 853, c-blue, [*8*]),
    ([ggml · 20 threads], 490, 855, c-sand, [4]),
    ([M4 Pro · 8 threads], 334, 332, c-teal, []),
  )
  let gx = (0, 300)
  for (gi, (name, opt)) in (([Q2_K], 493), ([Q4_0], 845)).enumerate() {
    let x0 = gx.at(gi)
    content((x0 + 90, 132), text(14pt, weight: "bold", name))
    line((x0, -4), (x0, 118), stroke: .6pt + c-muted)
    for (i, cf) in cfgs.enumerate() {
      let v = cf.at(1 + gi)
      let y = (4 - i) * 24
      rect((x0, y), (x0 + v * sx, y + 18), fill: cf.at(3), stroke: .6pt + c-muted)
      content((x0 + v * sx + 4, y + 9), text(10pt)[#v], anchor: "west")
    }
    line((x0 + opt * sx, -6), (x0 + opt * sx, 122), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
    content((x0 + opt * sx, -14), text(10pt, weight: "bold", fill: c-red)[optimal #opt])
  }
  for (i, cf) in cfgs.enumerate() {
    content((-8, (4 - i) * 24 + 9), text(11pt, cf.at(0)), anchor: "east")
  }
  content((-170, 132), text(10pt, fill: c-muted)[free cores])
  for (i, cf) in cfgs.enumerate() {
    content((-170, (4 - i) * 24 + 9), text(11pt, fill: c-muted, cf.at(4)))
  }
  content((560, -14), text(10pt, fill: c-muted)[µs per layer], anchor: "east")
}))

// ============================================================================
// M4 Pro
// ============================================================================

// GB/s vs. threads, M4 Pro (10 P + 4 E). probe: mean of 2 runs
#let m4-probe = ((1, 86), (2, 103), (4, 169), (6, 198), (8, 204), (10, 222), (12, 223), (14, 223))
#let m4-q2 = ((1, 14), (4, 48), (8, 99), (10, 125), (14, 139))
#let m4-q4 = ((1, 25), (4, 87), (8, 175), (10, 207), (14, 223))
#let m4-tmac = ((1, 30), (4, 102), (8, 187), (10, 201), (14, 214))

#let m4-frame(sx, sy, xmax, ymax) = {
  import cz.draw: *
  rect((0, 0), (10.5 * sx, ymax * sy), fill: c-gray, stroke: none)
  content((5.25 * sx, 10), text(10pt, fill: c-muted)[10 P-cores])
  content((12.5 * sx, 10), text(10pt, fill: c-muted)[\+ 4 E])
  line((0, 0), (xmax, 0), stroke: .6pt + c-muted)
  line((0, 0), (0, ymax * sy), stroke: .6pt + c-muted)
  for t in (50, 100, 150, 200, 250) {
    line((0, t * sy), (xmax, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
    content((-6, t * sy), text(10pt)[#t], anchor: "east")
  }
  for t in (1, 2, 4, 6, 8, 10, 12, 14) { content((t * sx, -11), text(10pt)[#t]) }
  content((7.5 * sx, -27), text(11pt, fill: c-muted)[threads])
  content((-32, ymax * sy / 2), text(11pt, fill: c-muted)[GB/s], angle: 90deg)
}

#let fig-m4-same-time() = fig(85%, canvas({
  import cz.draw: *
  let w = 150
  content((270, 3 * 62 + 4), text(10pt, fill: c-muted)[Q4_0 / Q2_K], anchor: "west")
  for (gi, (name, q2, q4, unit, ratio, rc)) in (
    ([Weight bytes], 31.5, 54, [MiB], [1.7×], c-muted),
    ([Ultra 9 latency], 860, 1490, [µs], [1.7×], c-blue),
    ([M4 Pro latency], 333, 329, [µs], [1.0×], c-orange),
  ).enumerate() {
    let y0 = (2 - gi) * 62
    let m = calc.max(q2, q4)
    content((0, y0 + 46), text(12pt, weight: "bold", name), anchor: "west")
    content((270, y0 + 16), text(15pt, weight: "bold", fill: rc, ratio), anchor: "west")
    for (bi, (label, v, fill)) in (([Q2_K], q2, c-orange), ([Q4_0], q4, c-orange-l)).enumerate() {
      let y = y0 + (1 - bi) * 18
      content((40, y + 7), text(11pt, label), anchor: "east")
      rect((46, y), (46 + v / m * w, y + 14), fill: fill, stroke: .6pt + c-muted)
      content((46 + v / m * w + 4, y + 7), text(10pt)[#v #unit], anchor: "west")
    }
  }
}))

#let fig-m4-ceiling() = fig(80%, canvas({
  import cz.draw: *
  let sx = 22
  let sy = 0.55
  let xmax = 15 * sx
  m4-frame(sx, sy, xmax, 290)
  line((0, 273 * sy), (xmax, 273 * sy), stroke: (paint: c-red, dash: "dashed", thickness: .9pt))
  content((xmax + 6, 273 * sy), text(10pt, fill: c-red)[nominal 273], anchor: "west")
  // Ultra 9 probe for comparison (flat after 8 threads)
  let u9 = u9-probe.filter(p => p.at(0) <= 8)
  line(..u9.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1pt + c-muted)
  line((8 * sx, 67 * sy), (xmax, 67 * sy), stroke: (paint: c-muted, dash: "dashed", thickness: .8pt))
  for (t, v) in u9 { circle((t * sx, v * sy), radius: 3, fill: white, stroke: 1pt + c-muted) }
  content((xmax + 6, 67 * sy), text(10pt, fill: c-muted)[Ultra 9: 67], anchor: "west")
  line(..m4-probe.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1.3pt + c-blue)
  for (t, v) in m4-probe { circle((t * sx, v * sy), radius: 3.5, fill: c-blue, stroke: none) }
  content((xmax + 6, 223 * sy), text(10pt, weight: "bold", fill: c-blue)[M4 Pro: 223], anchor: "west")
  content((1 * sx, 86 * sy + 8), text(10pt, weight: "bold", fill: c-blue)[86], anchor: "south")
  content((1 * sx - 7, 19 * sy), text(10pt, fill: c-muted)[19], anchor: "east")
}))

#let fig-m4-kernels() = fig(72%, grid(
  columns: 2,
  column-gutter: 40pt,
  row-gutter: 12pt,
  align: (center, left),
  panel-title[Effective bandwidth], panel-title[Share of the ceiling, 8 threads],
  canvas({
    import cz.draw: *
    let sx = 22
    let sy = 0.55
    let xmax = 15 * sx
    m4-frame(sx, sy, xmax, 250)
    line(..m4-probe.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: (paint: c-blue, dash: "dashed", thickness: 1.2pt))
    let sq(x, y, fill, stroke) = rect((x - 4, y - 4), (x + 4, y + 4), fill: fill, stroke: stroke)
    for (series, paint, fill, stroke) in (
      (m4-q2, c-orange, c-orange, none),
      (m4-q4, c-orange, white, 1.2pt + c-orange),
      (m4-tmac, c-brown, c-brown, none),
    ) {
      line(..series.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1pt + paint)
      for (t, v) in series {
        if paint == c-brown { circle((t * sx, v * sy), radius: 3.5, fill: fill, stroke: none) } else {
          sq(t * sx, v * sy, fill, stroke)
        }
      }
    }
    let lx = xmax + 12
    line((lx - 6, 200 * sy), (lx + 6, 200 * sy), stroke: (paint: c-blue, dash: "dashed", thickness: 1.2pt))
    content((lx + 12, 200 * sy), text(10pt)[read ceiling], anchor: "west")
    circle((lx, 170 * sy), radius: 3.5, fill: c-brown, stroke: none)
    content((lx + 12, 170 * sy), text(10pt)[T-MAC W2], anchor: "west")
    sq(lx, 140 * sy, white, 1.2pt + c-orange)
    content((lx + 12, 140 * sy), text(10pt)[ggml Q4_0], anchor: "west")
    sq(lx, 110 * sy, c-orange, none)
    content((lx + 12, 110 * sy), text(10pt)[ggml Q2_K], anchor: "west")
  }),
  align(horizon, canvas({
    import cz.draw: *
    let w = 150
    for (i, (label, pct, fill)) in (
      ([ggml Q2_K], 49, c-orange),
      ([ggml Q4_0], 86, c-orange-l),
      ([T-MAC W2], 92, c-brown),
    ).enumerate() {
      let y = (2 - i) * 24
      content((-6, y + 8), text(11pt, label), anchor: "east")
      rect((0, y), (w, y + 16), fill: c-gray, stroke: none)
      rect((0, y), (pct / 100 * w, y + 16), fill: fill, stroke: none)
      content((w + 5, y + 8), text(11pt, weight: "bold")[#pct%], anchor: "west")
    }
  })),
))

#let fig-m4-per-core() = fig(80%, canvas({
  import cz.draw: *
  let sx = 60
  for (i, (label, v, fill, note)) in (
    ([ggml Q2_K], 2.36, c-orange, [31.5 MiB]),
    ([ggml Q4_0], 2.23, c-orange-l, [54 MiB]),
  ).enumerate() {
    let y = (1 - i) * 26
    content((-6, y + 9), text(11pt, label), anchor: "east")
    rect((0, y), (v * sx, y + 18), fill: fill, stroke: .6pt + c-muted)
    content((v * sx + 5, y + 9), text(11pt)[*#v ms* #text(fill: c-muted)[· #note]], anchor: "west")
  }
  line((0, -4), (0, 48), stroke: .6pt + c-muted)
}))

/// Compute floor, bandwidth floor and measured latency per configuration:
/// (name, compute, bandwidth, measured, verdict, verdict colour).
#let floors(groups, sx, unit, col-w, inner-labels: false) = canvas({
  import cz.draw: *
  for (gi, (name, comp, bw, meas, verdict, vc)) in groups.enumerate() {
    let x0 = calc.rem(gi, 2) * col-w
    let y0 = (1 - calc.quo(gi, 2)) * 64
    content((x0 - 8, y0 + 32), text(12pt, weight: "bold", name), anchor: "east")
    content((x0 - 8, y0 + 14), text(10pt, weight: "bold", fill: vc, verdict), anchor: "east")
    for (bi, (label, v, fill)) in (
      ([compute], comp, c-orange-l),
      ([bandwidth], bw, c-blue-l),
      ([measured], meas, c-muted),
    ).enumerate() {
      let y = y0 + (2 - bi) * 17
      rect((x0, y), (x0 + v * sx, y + 13), fill: fill, stroke: none)
      content((x0 + v * sx + 4, y + 6.5), text(10pt)[#label #v], anchor: "west")
    }
  }
  content((2 * col-w - 40, -10), text(10pt, fill: c-muted, unit), anchor: "east")
})

#let fig-m4-floors() = fig(64%, floors(
  (
    ([Q2_K · 8T], 0.295, 0.162, 0.332, [compute-bound], c-orange),
    ([Q4_0 · 8T], 0.278, 0.278, 0.324, [floors meet], c-brown),
    ([Q2_K · 10T], 0.236, 0.149, 0.265, [compute-bound], c-orange),
    ([Q4_0 · 10T], 0.223, 0.255, 0.274, [bandwidth-bound], c-blue),
  ),
  620,
  [ms per layer],
  400,
))

#let fig-m4-best() = fig(78%, canvas({
  import cz.draw: *
  let sx = 120
  let groups = (
    (
      [2-bit],
      (
        ([ggml graph Q2_K · 31.5 MiB], 1.89, 0.288, c-orange),
        ([gemv-probe Q2_K · 31.5 MiB], 1.74, 0.265, c-sand-d),
        ([T-MAC W2 g128 · 25.5 MiB], 1.08, 0.133, c-brown),
        ([T-MAC W2 g128 zp · 27 MiB], 1.02, 0.133, c-brown-l),
      ),
    ),
    (
      [4-bit],
      (
        ([ggml graph Q4_0 · 54 MiB], 1.07, 0.281, c-orange),
        ([gemv-probe Q4_0 · 54 MiB], 1.05, 0.274, c-sand-d),
        ([T-MAC W4 g128 · 49.5 MiB], 1.01, 0.242, c-brown),
        ([T-MAC W4 g32 · 54 MiB], 1.06, 0.278, c-brown-l),
      ),
    ),
  )
  for (gi, (name, bars)) in groups.enumerate() {
    let y0 = (1 - gi) * 96
    content((-200, y0 + 36), text(14pt, weight: "bold", name), anchor: "east")
    for (bi, (label, v, ms, fill)) in bars.enumerate() {
      let y = y0 + (3 - bi) * 20
      content((-8, y + 7), text(11pt, label), anchor: "east")
      rect((0, y), (v * sx, y + 14), fill: fill, stroke: .6pt + c-muted)
      content((v * sx + 5, y + 7), text(10pt)[*#v×* · #ms ms], anchor: "west")
    }
  }
  line((sx, -6), (sx, 184), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
  content((sx, -14), text(10pt, weight: "bold", fill: c-red)[optimal = 1.0×])
}))

#let fig-m4-tmac() = fig(78%, grid(
  columns: 2,
  column-gutter: 40pt,
  row-gutter: 12pt,
  align: (left, center),
  panel-title[Weights per second, 1 thread], panel-title[Share of the read ceiling],
  align(horizon, canvas({
    import cz.draw: *
    let sx = 1.7
    for (i, (label, v, fill)) in (
      ([ggml Q2_K], 42.6, c-orange),
      ([ggml Q4_0], 45.2, c-orange-l),
      ([T-MAC W2], 114, c-brown),
    ).enumerate() {
      let y = (2 - i) * 26
      content((-6, y + 9), text(11pt, label), anchor: "east")
      rect((0, y), (v * sx, y + 18), fill: fill, stroke: .6pt + c-muted)
      content(
        (v * sx + 5, y + 9),
        text(11pt, weight: "bold")[#v G/s#if v > 100 { text(fill: c-brown)[ · 2.7×] }],
        anchor: "west",
      )
    }
  })),
  canvas({
    import cz.draw: *
    let sx = 14
    let sy = 1.1
    let xmax = 15 * sx
    rect((0, 0), (10.5 * sx, 105 * sy), fill: c-gray, stroke: none)
    content((5.25 * sx, 9), text(9pt, fill: c-muted)[10 P-cores])
    line((0, 0), (xmax, 0), stroke: .6pt + c-muted)
    line((0, 0), (0, 105 * sy), stroke: .6pt + c-muted)
    for t in (25, 50, 75) {
      line((0, t * sy), (xmax, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
      content((-6, t * sy), text(10pt)[#t%], anchor: "east")
    }
    line((0, 100 * sy), (xmax, 100 * sy), stroke: (paint: c-blue, dash: "dashed", thickness: .9pt))
    content((-6, 100 * sy), text(10pt, fill: c-blue)[100%], anchor: "east")
    for t in (1, 4, 8, 10, 14) { content((t * sx, -10), text(10pt)[#t]) }
    content((7.5 * sx, -24), text(10pt, fill: c-muted)[threads])
    let q2 = ((1, 16), (4, 28), (8, 49), (10, 56), (14, 62))
    let tm = ((1, 35), (4, 60), (8, 92), (10, 91), (14, 96))
    line(..q2.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1.2pt + c-orange)
    for (t, v) in q2 { rect((t * sx - 4, v * sy - 4), (t * sx + 4, v * sy + 4), fill: c-orange, stroke: none) }
    line(..tm.map(p => (p.at(0) * sx, p.at(1) * sy)), stroke: 1.2pt + c-brown)
    for (t, v) in tm { circle((t * sx, v * sy), radius: 3.5, fill: c-brown, stroke: none) }
    content((14 * sx + 8, 62 * sy), text(10pt, weight: "bold", fill: c-orange)[ggml Q2_K 62%], anchor: "west")
    content((14 * sx + 8, 92 * sy), text(10pt, weight: "bold", fill: c-brown)[T-MAC W2 96%], anchor: "west")
  }),
))

// ============================================================================
// Dual Xeon
// ============================================================================

// mode: "local" | "remote" | "interleave" | "shards"; x0 = left edge of the panel
#let access-mode(x0, mode, title, caption) = {
  import cz.draw: *
  let w = 64
  let xs = (x0, x0 + 110)
  let cx = x0 + 87
  let active = if mode in ("local", "remote") { (true, false) } else { (true, true) }
  let mem = (
    local: ([weights], none),
    remote: (none, [weights]),
    interleave: ([odd pages], [even pages]),
    shards: ([top half], [bottom half]),
  ).at(mode)
  // (from socket, to node)
  let reads = (
    local: ((0, 0),),
    remote: ((0, 1),),
    interleave: ((0, 0), (0, 1), (1, 1), (1, 0)),
    shards: ((0, 0), (1, 1)),
  ).at(mode)
  rect((xs.at(0) + w, 84), (xs.at(1), 100), fill: c-orange-p, stroke: none)
  content((cx, 111), text(8pt, weight: "bold", fill: c-orange)[UPI · 34 GB/s])
  for s in (0, 1) {
    let x = xs.at(s)
    let on = active.at(s)
    rect((x, 80), (x + w, 104), radius: 3pt, fill: if on { c-blue } else { c-gray }, stroke: if on { none } else {
      .5pt + c-rule
    })
    content((x + w / 2, 92), text(9pt, weight: "bold", fill: if on { white } else { c-muted })[Socket #s])
    let m = mem.at(s)
    rect((x, 0), (x + w, 26), fill: if m == none { white } else { c-sand }, stroke: .5pt + c-muted)
    if m != none { content((x + w / 2, 13), text(8pt, m)) }
    content((x + w / 2, -8), text(7pt, fill: c-muted)[node #s])
  }
  for (s, n) in reads {
    let mid = xs.at(s) + w / 2
    if s == n {
      // local read: socket straight down to its own memory
      line((mid, 80), (mid, 26), mark: (end: ">"), stroke: 1.3pt + c-blue)
      let (dx, side) = if s == 0 { (-4, "east") } else { (4, "west") }
      content((mid + dx, 53), text(8pt, fill: c-blue)[108 GB/s], anchor: side)
    } else {
      // remote read: across UPI, then down through the other socket's memory controller
      let dash = (paint: c-orange, thickness: 1.3pt, dash: "dashed")
      let (y, xa, xb) = if s == 0 { (88, xs.at(0) + w, xs.at(1)) } else { (96, xs.at(1), xs.at(0) + w) }
      line((xa, y), (xb, y), mark: (end: ">"), stroke: dash)
      let xd = if n == 1 { xs.at(1) + 12 } else { xs.at(0) + w - 12 }
      line((xd, 80), (xd, 26), mark: (end: ">"), stroke: dash)
    }
  }
  content((cx, -26), text(12pt, weight: "bold", title))
  content((cx, -44), box(width: 170pt, align(center, text(10pt, caption))), anchor: "north")
}

#let fig-xeon-modes() = fig(68%, canvas({
  access-mode(0, "local", [Local], [Threads and weights on socket 0.])
  access-mode(200, "remote", [Remote], [Threads on socket 0, weights on node 1: *every* read crosses UPI.])
  access-mode(
    400,
    "interleave",
    [Shared, interleaved],
    [One pool on both sockets; 4 KiB pages alternate: ≈ *half* the reads cross UPI.],
  )
  access-mode(600, "shards", [Local shards], [Each socket reads only its own half: *no* UPI traffic.])
}))

#let fig-xeon-ceiling() = fig(75%, hbars(
  (
    ([Remote · 1 socket, 8 cores], 31.6, c-orange-l, [31.6]),
    ([Local · 1 socket, 8 cores], 61.2, c-blue-p, [61.2]),
    ([Local · 1 socket, 24 cores], 108.8, c-blue-l, [108.8]),
    ([Shared, interleaved · 2 sockets, 48 cores], 116, c-sand-d, [116]),
    ([Local shards · 2 sockets, 48 cores], 216, c-blue, [*216*]),
  ),
  1.3,
))

#let fig-xeon-floors() = fig(66%, floors(
  (
    ([Q2_K · 1 socket], 194, 304, 600, [2.0× the floors], c-red),
    ([Q2_K · 2 sockets], 97, 285, 989, [3.5× the floors], c-red),
    ([Q4_0 · 1 socket], 325, 520, 662, [1.3× the floors], c-brown),
    ([Q4_0 · 2 sockets], 163, 489, 504, [bandwidth-bound], c-blue),
  ),
  0.25,
  [µs per layer; 1 socket = 24 cores, 2 sockets = 48 cores],
  380,
))

#let numa-layout(shared) = canvas({
  import cz.draw: *
  for (s, x) in ((0, 0), (1, 140)) {
    rect((x, 90), (x + 90, 122), radius: 4pt, fill: c-blue, stroke: none)
    content((x + 45, 106), text(11pt, weight: "bold", fill: white)[Socket #s])
    rect((x, 0), (x + 90, 32), fill: c-sand, stroke: .5pt + c-muted)
    content((x + 45, 16), text(10pt, if shared { [interleaved] } else if s == 0 { [rows 1 … N/2] } else {
      [rows N/2 … N]
    }))
    content((x + 45, -10), text(9pt, fill: c-muted)[memory node #s])
    line((x + 45, 90), (x + 45, 32), mark: (end: ">"), stroke: 1.4pt + c-blue)
  }
  if shared {
    line((80, 90), (150, 32), mark: (end: ">"), stroke: (paint: c-orange, thickness: 1.4pt, dash: "dashed"))
    line((150, 90), (80, 32), mark: (end: ">"), stroke: (paint: c-orange, thickness: 1.4pt, dash: "dashed"))
    content((115, 40), text(9pt, weight: "bold", fill: c-orange)[UPI])
  }
})

#let fig-xeon-shards() = fig(80%, grid(
  columns: 2,
  column-gutter: 60pt,
  row-gutter: 12pt,
  align: center,
  panel-title[Shared (before)], panel-title[Local shards (after)],
  numa-layout(true), numa-layout(false),
))

#let fig-xeon-shards-result() = fig(75%, hbars(
  (
    ([Shared queue · pages interleaved], 994, c-orange, [994]),
    ([Static split · pages interleaved], 416.5, c-sand-d, [417]),
    ([Local shards · static split], 160.4, c-blue, [*160* (6.2×)]),
    ([Local shards · dynamic queue per socket], 163.2, c-blue-l, [163]),
  ),
  0.3,
  opt: 152.6,
  opt-label: [optimal 153],
))
