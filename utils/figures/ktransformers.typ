// Figures for content/posts/papers/llm/ktransformers-deep-dive.typ, ported from
// the KTransformers slides. Colours are restricted to the ones that
// assets/styles/site.css maps to night values, so every figure follows the
// day / night switch.
// Import: #import "/utils/figures/ktransformers.typ": diagram

#import "@preview/cetz:0.5.2"
#import "/utils/cetz.typ": svg-frame

#let c-teal = rgb("#DCEAE6")
#let c-teal2 = rgb("#95BFB6")
#let c-sand = rgb("#F5E6CB")
#let c-sand2 = rgb("#DEBBA6")
#let c-panel = rgb("#D2E2E7")
#let c-gray = rgb("#F0F3F2")
#let c-grey2 = rgb("#C9D0CE")
#let c-blue = rgb("#286379")
#let c-blue1 = rgb("#E1ECEF")
#let c-blue1b = rgb("#D2E2E7")
#let c-blue2 = rgb("#A3C3CE")
#let c-brown = rgb("#8A5B13")
#let c-orange = rgb("#CB4B22")
#let c-orange2 = rgb("#EBB39B")
#let c-tint = rgb("#FBECE3")
#let c-red = rgb("#A73434")
#let c-muted = rgb("#65716F")
#let c-rule = rgb("#C5C9BE")

#let figs = (
  "tile-layout": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let u = 26
    // original row-major weight
    content((2 * u, 4 * u + 16), text(13pt, weight: "bold")[Row-major $W$])
    for r in range(4) {
      rect((0, r * u), (4 * u, r * u + u), fill: c-gray, stroke: .5pt + c-rule)
      line((8, r * u + u / 2), (4 * u - 8, r * u + u / 2), mark: (end: ">"), stroke: .5pt + c-muted)
    }
    rect((0, 0), (4 * u, 4 * u), stroke: .8pt + c-muted)
    line((4 * u + 20, 2 * u), (4 * u + 90, 2 * u), mark: (end: ">"), stroke: 1.2pt + c-blue)
    content((4 * u + 55, 2 * u + 14), text(11pt, fill: c-blue)[at load time])
    // tiled layout
    let x0 = 4 * u + 110
    content((x0 + 2 * u, 4 * u + 16), text(13pt, weight: "bold")[Tiled $W$])
    for c in range(4) {
      for r in range(4) {
        let idx = c * 4 + r
        rect((x0 + c * u, (3 - r) * u), (x0 + c * u + u, (3 - r) * u + u), fill: if c == 0 { c-sand } else { c-teal }, stroke: .5pt + c-muted)
        content((x0 + c * u + u / 2, (3 - r) * u + u / 2), text(10pt)[#idx])
      }
    }
    // memory strip
    let x1 = x0 + 4 * u + 60
    content((x1 + 110, 4 * u + 16), text(13pt, weight: "bold")[Memory])
    for i in range(6) {
      rect((x1 + i * 36, 2.5 * u), (x1 + i * 36 + 36, 3.5 * u), fill: if i < 4 { c-sand } else { c-teal }, stroke: .5pt + c-muted)
      content((x1 + i * 36 + 18, 3 * u), text(10pt)[T#i])
    }
    content((x1 + 6 * 36 + 14, 3 * u), text(12pt)[…])
    content((x1 + 110, 2.5 * u - 12), text(10pt, fill: c-muted)[each tile 1 KB, 64 B-aligned])
    for i in range(6) {
      rect((x1 + i * 22, 0.3 * u), (x1 + i * 22 + 22, 1.1 * u), fill: white, stroke: .5pt + c-muted)
      content((x1 + i * 22 + 11, 0.7 * u), text(9pt)[s#i])
    }
    content((x1 + 110, 0.3 * u - 12), text(10pt, fill: c-muted)[group scales stored separately])
  }),
  "loop-nest": scale(85%, reflow: true, cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let zoom = (paint: c-muted, dash: "dashed", thickness: .6pt)
    let tier(x, w, body, fill) = {
      rect((x, -42), (x + w, -26), fill: fill, stroke: none, radius: 2pt)
      content((x + w / 2, -34), text(10pt, weight: "bold", fill: white, body))
    }
    let title(x, body) = content((x, 178), text(12pt, weight: "bold", body))
    let c-acc = c-blue1b
    // ① expert weight, split into column tasks
    title(64, [① task = column strip])
    for i in range(4) {
      rect((i * 32, 0), (i * 32 + 32, 160), fill: if i == 3 { c-sand } else { c-gray }, stroke: .6pt + c-muted)
      content((i * 32 + 16, -12), text(10pt, fill: c-muted)[T#(i + 1)])
    }
    content((48, 80), text(16pt)[$W$])
    tier(0, 128, [DRAM], c-muted)
    line((128, 160), (190, 160), stroke: zoom)
    line((128, 0), (190, 0), stroke: zoom)
    // ② strip split into row blocks
    title(210, [② L2 block])
    for j in range(4) {
      rect((190, j * 40), (230, j * 40 + 40), fill: if j == 2 { c-teal } else { c-sand }, stroke: .6pt + c-muted)
    }
    tier(190, 40, [L2], c-blue)
    line((230, 120), (280, 140), stroke: zoom)
    line((230, 80), (280, 20), stroke: zoom)
    // ③④ block made of AMX tiles
    title(340, [③④ AMX tiles])
    for c in range(4) {
      for r in range(4) {
        let hot = r == 3 and c >= 2
        rect((280 + c * 30, 20 + r * 30), (310 + c * 30, 50 + r * 30), fill: if hot { c-teal2 } else { c-teal }, stroke: .5pt + c-muted)
      }
    }
    content((340, 6), text(10pt, fill: c-muted)[tile = 16 rows #sym.times 64 B])
    tier(280, 120, [L2], c-blue)
    line((400, 140), (504, 124), stroke: zoom)
    line((400, 110), (504, 100), stroke: zoom)
    // ⑤ register blocking
    title(527, [⑤ 8 tile registers])
    let reg(x, y, body, fill) = {
      rect((x, y), (x + 44, y + 24), fill: fill, stroke: .6pt + c-muted)
      content((x + 22, y + 12), text(10pt, body))
    }
    reg(504, 100, [B2], c-teal2)
    reg(556, 100, [B3], c-teal2)
    reg(450, 66, [A0], c-sand)
    reg(450, 36, [A1], c-sand)
    reg(504, 66, [C4], c-acc)
    reg(556, 66, [C5], c-acc)
    reg(504, 36, [C6], c-acc)
    reg(556, 36, [C7], c-acc)
    content((494, 122), text(10pt, fill: c-brown)[$X$ from L3], anchor: "east")
    line((472, 112), (472, 92), mark: (end: ">"), stroke: .7pt + c-brown)
    content((527, 18), text(10pt)[$C_(i j) += A_i B_j$: 4 loads, 4 multiplies])
    tier(450, 150, [tile registers], c-orange)
  })),
  "ari-tiles": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let rh = 4.5
    for (i, m) in (1, 4, 8, 16).enumerate() {
      let x = i * 72
      content((x + 25, 16 * rh + 12), text(12pt, weight: "bold")[$m$ = #m])
      for r in range(16) {
        let y = (15 - r) * rh
        rect((x, y), (x + 50, y + rh), fill: if r < m { c-sand2 } else { c-gray }, stroke: .3pt + c-rule)
      }
      rect((x, 0), (x + 50, 16 * rh), stroke: .8pt + c-muted)
      content((x + 25, -12), text(11pt, weight: "bold", fill: if m <= 4 { c-red } else { c-blue })[#calc.round(m / 16 * 100)% used])
    }
    content((133, -32), text(10pt, fill: c-muted)[one AMX input tile = 16 token rows; $m$ = tokens routed to the expert])
    // schematic cost curves
    let x0 = 340
    let sx(m) = x0 + (m - 1) * 30
    line((x0 - 6, 0), (sx(8) + 16, 0), mark: (end: ">"), stroke: .6pt + c-muted)
    line((x0 - 6, 0), (x0 - 6, 88), mark: (end: ">"), stroke: .6pt + c-muted)
    content((sx(8) + 18, -10), text(10pt, fill: c-muted)[$m$], anchor: "east")
    content((x0 - 10, 86), text(10pt, fill: c-muted)[latency], anchor: "east")
    for m in range(1, 9) {
      content((sx(m), -9), text(9pt, fill: c-muted)[#m])
    }
    line((sx(1), 50), (sx(8), 50), stroke: 1.6pt + c-blue)
    content((sx(8) + 4, 50), text(10pt, fill: c-blue)[AMX: whole tiles], anchor: "west")
    line((sx(1), 28), (sx(8), 80), stroke: (paint: c-orange, thickness: 1.6pt, dash: "dashed"))
    content((sx(8) + 4, 80), text(10pt, fill: c-orange)[AVX-512: #sym.prop $m$], anchor: "west")
    let mc = 1 + (50 - 28) / ((80 - 28) / 7)
    line((sx(mc), 0), (sx(mc), 50), stroke: (paint: c-red, dash: "dotted", thickness: .9pt))
    content((sx(mc) - 4, 30), text(10pt, weight: "bold", fill: c-red)[#sym.approx 4], anchor: "east")
    content((sx(4.5), -28), text(10pt, fill: c-muted)[schematic, shape of Fig. 7])
  }),
  "fused-moe": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let bar(x1, x2, y, body, fill) = {
      rect((x1, y), (x2, y + 26), fill: fill, stroke: .6pt + c-muted)
      content(((x1 + x2) / 2, y + 13), text(11pt, body))
    }
    let barrier(x, y) = line((x, y - 4), (x, y + 30), stroke: 1.6pt + c-red)
    content((-10, 63), text(13pt, weight: "bold")[Per-expert], anchor: "east")
    let x = 0
    for e in range(3) {
      for (n, f) in (([G#(e + 1)], c-sand), ([U#(e + 1)], c-sand), ([D#(e + 1)], c-teal)) {
        bar(x, x + 40, 50, n, f)
        barrier(x + 43, 50)
        x += 46
      }
    }
    content((x + 6, 63), text(11pt, fill: c-red)[9 barriers], anchor: "west")
    content((-10, 13), text(13pt, weight: "bold")[Fused], anchor: "east")
    bar(0, 230, 0, [Gate + Up · all experts], c-sand)
    barrier(234, 0)
    bar(238, 400, 0, [Down · all experts], c-teal)
    barrier(404, 0)
    content((412, 13), text(11pt, fill: c-blue)[2 barriers], anchor: "west")
  }),
  "async-timeline": scale(90%, reflow: true, cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let bar(x1, x2, y, body, fill, dash: none) = {
      rect((x1, y), (x2, y + 22), fill: fill, stroke: (paint: c-muted, thickness: .6pt, dash: dash))
      content(((x1 + x2) / 2, y + 11), text(10pt, body))
    }
    // naive
    content((-12, 150), text(13pt, weight: "bold")[Naive], anchor: "east")
    content((-12, 128), text(10pt, fill: c-muted)[GPU], anchor: "east")
    content((-12, 100), text(10pt, fill: c-muted)[CPU], anchor: "east")
    bar(0, 100, 117, [Attn], c-panel)
    bar(102, 124, 117, [G], c-sand)
    bar(126, 166, 117, [launch], white, dash: "dashed")
    bar(168, 240, 117, [Shared], c-teal)
    bar(242, 330, 117, [idle], c-gray)
    bar(332, 372, 117, [launch], white, dash: "dashed")
    bar(374, 474, 117, [Attn], c-panel)
    bar(126, 166, 89, [submit], c-sand)
    bar(168, 330, 89, [routed experts], c-teal)
    bar(332, 372, 89, [sync], c-sand)
    for xb in (146, 352) {
      line((xb, 80), (xb, 146), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
    }
    content((249, 160), text(10pt, fill: c-red)[host barriers break the graph])
    // KTransformers
    content((-12, 52), text(13pt, weight: "bold")[KT], anchor: "east")
    content((-12, 30), text(10pt, fill: c-muted)[GPU], anchor: "east")
    content((-12, 2), text(10pt, fill: c-muted)[CPU], anchor: "east")
    bar(0, 100, 19, [Attn], c-panel)
    bar(102, 124, 19, [G], c-sand)
    bar(126, 140, 19, [], c-orange2)
    bar(142, 214, 19, [Shared], c-teal)
    bar(216, 292, 19, [wait], c-gray)
    bar(294, 308, 19, [], c-orange2)
    bar(310, 410, 19, [Attn], c-panel)
    bar(140, 292, -9, [routed experts], c-teal)
    rect((-4, 14), (414, 46), stroke: (paint: c-blue, dash: "dashed", thickness: 1pt))
    content((418, 30), text(10pt, fill: c-blue)[single CUDA Graph], anchor: "west")
    rect((440, -8), (452, 4), fill: c-orange2, stroke: .6pt + c-muted)
    content((456, -2), text(10pt)[`cudaLaunchHostFunc`], anchor: "west")
  })),
  "async-callbacks": scale(92%, reflow: true, cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let hf = c-orange2
    let node(x1, x2, y, body, fill, h: 24) = {
      rect((x1, y), (x2, y + h), fill: fill, stroke: .6pt + c-muted)
      content(((x1 + x2) / 2, y + h / 2), text(10pt, body))
    }
    let arr(a, b, paint: black, dash: none) = line(a, b, mark: (end: ">"), stroke: (paint: paint, thickness: .8pt, dash: dash))
    // lanes
    content((-12, 172), text(11pt, weight: "bold")[GPU stream], anchor: "east")
    content((-12, 100), text(11pt, weight: "bold")[Host callback], anchor: "east")
    content((-12, 20), text(11pt, weight: "bold")[CPU workers], anchor: "east")
    for y in (140, 66) {
      line((-100, y), (550, y), stroke: (paint: c-rule, dash: "dotted"))
    }
    // GPU stream, captured once
    node(0, 56, 160, [Attn], c-panel)
    node(60, 96, 160, [Gate], c-sand)
    node(100, 146, 160, [Send], c-gray)
    node(150, 198, 160, [submit], hf)
    node(202, 280, 160, [Shared], c-teal)
    node(284, 400, 160, [sync: stream waits], hf)
    node(404, 470, 160, [Recv + add], c-gray)
    node(474, 540, 160, [Attn #sym.arrow], c-panel)
    rect((-4, 154), (544, 190), stroke: (paint: c-blue, dash: "dashed", thickness: 1pt))
    content((270, 200), text(10pt, weight: "bold", fill: c-blue)[one CUDA Graph, replayed once per decode step])
    // host callbacks
    node(116, 232, 88, [push tasks, return], hf)
    node(284, 400, 88, [wait until all done], hf)
    arr((174, 160), (174, 112), paint: c-orange, dash: "dashed")
    arr((320, 160), (320, 112), paint: c-orange, dash: "dashed")
    arr((380, 112), (380, 160), paint: c-blue)
    content((384, 136), text(9pt, fill: c-blue)[release], anchor: "west")
    // lock-free queue
    for i in range(6) {
      rect((130 + i * 16, 36), (146 + i * 16, 52), fill: if i < 4 { c-teal } else { white }, stroke: .6pt + c-muted)
    }
    content((178, 26), text(9pt, fill: c-muted)[lock-free queue])
    arr((174, 88), (174, 53))
    // workers
    node(250, 360, 34, [W1: $e_1, e_5$], c-teal, h: 16)
    node(250, 372, 14, [W2: $e_2, e_6$], c-teal, h: 16)
    node(250, 352, -6, [W3: $e_3, e_7$], c-teal, h: 16)
    arr((226, 44), (248, 30))
    content((310, -20), text(9pt, fill: c-muted)[AMX / AVX-512 expert kernels])
    arr((372, 22), (330, 88), paint: c-blue)
    content((360, 60), text(9pt, fill: c-blue)[done], anchor: "west")
  })),
  "numa-load": scale(88%, reflow: true, cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let names = ("a", "b", "c", "d", "e", "f", "g", "h")
    let sel = ("a", "b", "c", "e")
    let hot = c-orange2
    let socket(x, y, title) = {
      rect((x, y), (x + 140, y + 74), fill: c-gray, stroke: .7pt + c-muted, radius: 3pt)
      content((x + 70, y + 64), text(11pt, weight: "bold", title))
    }
    let load(x, y, units, max) = {
      rect((x, y), (x + units * 30, y + 14), fill: c-blue2, stroke: .5pt + c-muted)
      if units < max {
        rect((x + units * 30, y), (x + max * 30, y + 14), stroke: (paint: c-muted, dash: "dashed", thickness: .5pt))
        content((x + (units + max) * 15, y + 7), text(8pt, fill: c-muted)[idle])
      }
    }
    content((300, 170), text(11pt)[token routed to experts #box(fill: hot, inset: 2pt)[a, b, c, e]])
    // expert parallel
    content((150, 150), text(13pt, weight: "bold", fill: c-red)[Expert parallel])
    for s in range(2) {
      let x = s * 160
      socket(x, 50, [Socket #s])
      for i in range(4) {
        let n = names.at(s * 4 + i)
        rect((x + 12 + i * 32, 60), (x + 36 + i * 32, 84), fill: if n in sel { hot } else { white }, stroke: .6pt + c-muted)
        content((x + 24 + i * 32, 72), text(10pt)[#n])
      }
      load(x + 10, 22, if s == 0 { 3 } else { 1 }, 3)
    }
    content((150, 4), text(10pt, fill: c-red)[latency = 3 units, socket 1 mostly idle])
    // tensor parallel
    content((510, 150), text(13pt, weight: "bold", fill: c-blue)[Tensor parallel (KT)])
    for s in range(2) {
      let x = 360 + s * 160
      socket(x, 50, [Socket #s])
      for i in range(8) {
        let n = names.at(i)
        let ex = x + 10 + calc.rem(i, 4) * 32
        let ey = if i < 4 { 80 } else { 56 }
        let half(l, local) = rect((ex + l * 12, ey), (ex + l * 12 + 12, ey + 18),
          fill: if local { if n in sel { hot } else { white } } else { none },
          stroke: (paint: c-muted, thickness: .5pt, dash: if local { none } else { "dotted" }))
        half(0, s == 0)
        half(1, s == 1)
        content((ex + if s == 0 { 6 } else { 18 }, ey + 9), text(8pt)[#n])
      }
      load(x + 10, 22, 2, 2)
    }
    content((510, 4), text(10pt, fill: c-blue)[latency = 2 units + one reduce])
  })),
  "numa-split": scale(88%, reflow: true, cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let box(x1, x2, y, body, fill) = {
      rect((x1, y), (x2, y + 26), fill: fill, stroke: .6pt + c-muted)
      content(((x1 + x2) / 2, y + 13), text(10pt, body))
    }
    let arr(a, b) = line(a, b, mark: (end: ">"), stroke: .8pt)
    box(0, 30, 20, [$x$], white)
    for (s, y, fill) in ((0, 40, c-teal), (1, 0, c-sand)) {
      arr((30, 33), (60, y + 13))
      box(60, 190, y, [$x [W_g^((s)) | W_u^((s))]$], fill)
      arr((190, y + 13), (210, y + 13))
      box(210, 290, y, [SiLU #sym.dot.o], fill)
      arr((290, y + 13), (310, y + 13))
      box(310, 410, y, [$h^((s)) W_d^((s))$], fill)
      arr((410, y + 13), (430, y + 13))
      box(430, 480, y, [$y^((s))$], fill)
      arr((480, y + 13), (512, 33))
      content((-8, y + 13), text(10pt, weight: "bold")[S#s], anchor: "east")
    }
    circle((520, 33), radius: 8, fill: white, stroke: .8pt)
    content((520, 33), text(10pt)[+])
    arr((528, 33), (552, 33))
    content((560, 33), text(11pt)[$y$], anchor: "west")
    content((125, 76), text(9pt, fill: c-muted)[column half])
    content((250, 76), text(9pt, fill: c-muted)[local, no comm.])
    content((360, 76), text(9pt, fill: c-muted)[row half])
    content((520, 56), text(10pt, fill: c-muted)[reduce])
  })),
  "defer-compare": scale(86%, reflow: true, cetz.canvas(length: 1pt, {
      import cetz.draw: *
      let c-def = c-orange2
      let panel(x0, title, deferred) = {
        let cx = x0 + 70
        let blk(y, body, fill) = {
          rect((x0 + 20, y), (x0 + 120, y + 24), fill: fill, stroke: .7pt + c-muted)
          content((cx, y + 12), text(11pt, body))
        }
        let plus(y) = {
          circle((cx, y), radius: 6, fill: white, stroke: .7pt)
          content((cx, y), text(9pt)[+])
        }
        let up(y1, y2) = line((cx, y1), (cx, y2), mark: (end: ">"), stroke: .8pt)
        content((cx, 252), text(13pt, weight: "bold", fill: if deferred { c-red } else { c-blue }, title))
        // MoE layer k with its top-4 routed experts
        rect((x0, 0), (x0 + 140, 54), fill: c-gray, stroke: .7pt + c-muted)
        content((cx, 9), text(10pt)[$"MoE"_k$ · top-4])
        for (i, n) in ("a", "b", "c", "d").enumerate() {
          let late = deferred and i >= 2
          let ex = x0 + 14 + i * 30
          rect((ex, 20), (ex + 22, 42), fill: if late { c-def } else { c-teal }, stroke: (paint: if late { c-red } else { c-muted }, thickness: .8pt))
          content((ex + 11, 31), text(11pt)[#n])
          if late {
            line((ex + 11, 42), (ex + 11, 64), (x0 + 150, 64), stroke: 1.4pt + c-red)
          } else {
            line((ex + 11, 42), (cx - 4, 72), mark: (end: ">"), stroke: .8pt)
          }
        }
        // the next two layers
        plus(78)
        up(84, 96)
        blk(96, [$"Attn"_(k+1)$], c-panel)
        up(120, 134)
        blk(134, [$"MoE"_(k+1)$], c-gray)
        up(158, 178)
        plus(184)
        up(190, 202)
        blk(202, [$"Attn"_(k+2)$], c-panel)
        if deferred {
          line((x0 + 150, 64), (x0 + 150, 184), (cx + 7, 184), mark: (end: ">", fill: c-red), stroke: 1.4pt + c-red)
          content((x0 + 155, 108), text(10pt, fill: c-red)[CPU runs], anchor: "west")
          content((x0 + 155, 94), text(10pt, fill: c-red)[c, d here], anchor: "west")
          content((cx, -16), text(10pt, fill: c-red)[c, d reach $"Attn"_(k+2)$])
        } else {
          content((cx, -16), text(10pt, fill: c-blue)[a–d reach $"Attn"_(k+1)$])
        }
      }
      panel(0, [Standard], false)
      panel(178, [Expert Deferral], true)
    })),
  "defer-unrolled": scale(90%, reflow: true, cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let ys = 60
    let c-def = c-orange2
    let blocks = (
      (0, [$"MoE"_(k-1)$], c-teal),
      (120, [$"Attn"_k$], c-panel),
      (240, [$"MoE"_k$], c-teal),
      (360, [$"Attn"_(k+1)$], c-panel),
      (480, [$"MoE"_(k+1)$], c-teal),
    )
    // column guides
    for (x, _, _) in blocks {
      rect((x + 4, -80), (x + 116, ys + 70), fill: if calc.rem(int(x / 120), 2) == 1 { c-gray } else { none }, stroke: none)
    }
    line((-30, ys), (610, ys), stroke: 2pt + c-muted, mark: (end: ">"))
    content((-34, ys), text(10pt, fill: c-muted)[residual], anchor: "east")
    for (x, name, fill) in blocks {
      rect((x + 10, ys + 28), (x + 90, ys + 58), fill: fill, stroke: .7pt + c-muted)
      content((x + 50, ys + 43), text(11pt, name))
      line((x + 20, ys), (x + 20, ys + 28), mark: (end: ">"), stroke: .7pt)
      line((x + 84, ys + 28), (x + 103, ys + 7), mark: (end: ">"), stroke: .7pt)
      circle((x + 106, ys), radius: 6, fill: white, stroke: .7pt)
      content((x + 106, ys), text(9pt)[+])
    }
    // deferred experts: read I at their own layer, add one MoE later
    for (x0, lbl) in ((0, [$R^"def"_(k-1)$]), (240, [$R^"def"_k$])) {
      let bx = x0 + 130
      rect((bx, ys - 52), (bx + 80, ys - 26), fill: c-def, stroke: 1pt + c-red)
      content((bx + 40, ys - 39), text(11pt, lbl))
      bezier((x0 + 20, ys - 2), (bx, ys - 39), (x0 + 20, ys - 39), stroke: 1.4pt + c-red, mark: (end: ">", fill: c-red))
      bezier((bx + 80, ys - 39), (x0 + 345, ys - 6), (x0 + 345, ys - 39), stroke: 1.4pt + c-red, mark: (end: ">", fill: c-red))
    }
    content((50, ys - 22), text(9pt, fill: c-red)[$I_(k-1)$])
    content((290, ys - 22), text(9pt, fill: c-red)[$I_k$])
    // aligned timeline
    content((-12, -29), text(11pt, weight: "bold")[GPU], anchor: "east")
    content((-12, -61), text(11pt, weight: "bold")[CPU], anchor: "east")
    let bar(x1, x2, y, body, fill) = {
      rect((x1, y), (x2, y + 22), fill: fill, stroke: .6pt + c-muted)
      content(((x1 + x2) / 2, y + 11), text(10pt, body))
    }
    bar(10, 50, -40, [S], c-teal)
    bar(130, 230, -40, [attention], c-panel)
    bar(250, 290, -40, [S], c-teal)
    bar(370, 470, -40, [attention], c-panel)
    bar(490, 530, -40, [S], c-teal)
    bar(10, 110, -72, [imm], c-sand)
    bar(130, 230, -72, [def $k-1$], c-def)
    bar(250, 350, -72, [imm], c-sand)
    bar(370, 470, -72, [def $k$], c-def)
    bar(490, 590, -72, [imm], c-sand)
    content((300, -4), text(10pt, fill: c-muted)[same columns = same time])
  })),
  "defer-timeline": scale(92%, reflow: true, cetz.canvas(length: 1pt, {
      import cetz.draw: *
      let s = 0.11
      let te = 260
      let w = 700
      let c-def = c-orange2
      let seg(x1, x2, y, fill, body: none, dash: none) = {
        rect((x1 * s, y), (x2 * s, y + 14), fill: fill, stroke: (paint: c-muted, thickness: .5pt, dash: dash))
        if body != none { content(((x1 + x2) / 2 * s, y + 7), text(8pt, body)) }
      }
      let top = 230
      // GPU-only window: CPU cannot start immediate experts yet
      rect((0, -4), (w * s, top + 36), fill: c-blue1, stroke: none)
      line((w * s, -4), (w * s, top + 36), stroke: (paint: c-blue, dash: "dashed", thickness: .8pt))
      content((w * s / 2, top + 64), text(9pt, weight: "bold", fill: c-blue)[free CPU time])
      content((w * s / 2, top + 54), text(8pt, fill: c-blue)[attn + gate + send])
      for (i, d) in (0, 2, 3, 4).enumerate() {
        let y = top - i * 74
        let start = calc.max(w, d * te)
        let total = start + (8 - d) * te
        content((w * s + 6, y + 44), text(10pt, weight: "bold")[#(8 - d) immediate + #d deferred], anchor: "west")
        content((-4, y + 27), text(8pt, fill: c-muted)[GPU], anchor: "east")
        content((-4, y + 7), text(8pt, fill: c-muted)[CPU], anchor: "east")
        seg(0, 560, y + 20, c-panel, body: [attention])
        seg(560, 690, y + 20, c-grey2)
        seg(690, 830, y + 20, c-blue2)
        seg(830, total, y + 20, c-gray, body: [wait for CPU])
        if d > 0 { seg(0, d * te, y, c-def, body: [def ×#d]) }
        if d * te < w {
          seg(d * te, w, y, white, dash: "dashed", body: if d == 0 { text(fill: c-red)[idle] } else { none })
        }
        seg(start, total, y, c-sand, body: [immediate ×#(8 - d)])
        let label = ("0": [#sym.approx 2.8 ms], "2": [#sym.arrow.b 19%], "3": [#sym.arrow.b 26%], "4": [#sym.arrow.b 26%]).at(str(d))
        content((total * s + 4, y + 17), text(10pt, weight: "bold", fill: if d == 3 { c-red } else { black }, label), anchor: "west")
      }
      line((0, -10), (2800 * s, -10), stroke: .5pt + c-muted)
      for t in (0, 500, 1000, 1500, 2000, 2500) {
        line((t * s, -10), (t * s, -13), stroke: .5pt + c-muted)
        content((t * s, -20), text(8pt, fill: c-muted)[#t])
      }
      content((1400 * s, -33), text(9pt, fill: c-muted)[µs · DeepSeek-V3 layer, redrawn from Fig. 10 (approx.)])
      for (i, (fill, body)) in ((c-panel, [attention]), (c-grey2, [gate + send]), (c-blue2, [shared]), (c-orange2, [deferred]), (c-sand, [immediate])).enumerate() {
        let lx = (-10, 60, 150, 212, 284).at(i)
        rect((lx, -54), (lx + 10, -44), fill: fill, stroke: .5pt + c-muted)
        content((lx + 13, -49), text(8pt, body), anchor: "west")
      }
    })),
  // ---------------- Background ----------------
  "phases": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let panel(x0, title, rows, n, col, notes) = {
      content((x0 + 100, 160), text(13pt, weight: "bold", fill: col, title))
      content((x0 + 25, 132), text(11pt)[$X$])
      content((x0 + 140, 132), text(11pt)[$W$])
      rect((x0, 120 - rows), (x0 + 50, 120), fill: c-sand, stroke: .6pt + c-muted)
      content((x0 - 6, 120 - rows / 2), anchor: "east", text(10pt, fill: c-muted, n))
      content((x0 + 65, 100), text(14pt)[#sym.times])
      rect((x0 + 80, 60), (x0 + 200, 120), fill: c-teal, stroke: .6pt + c-muted)
      for (i, body) in notes.enumerate() {
        content((x0 + 100, -8 - i * 18), text(11pt, body))
      }
    }
    panel(0, [Prefill], 110, [$N$ tokens], c-blue, ([GEMM: each weight reused $N$ times], [compute-bound · high ARI]))
    panel(330, [Decode], 8, [1 token], c-orange, ([GEMV: each weight used once], [memory-bound · low ARI]))
    line((285, -40), (285, 165), stroke: (paint: c-rule, dash: "dashed"))
  }),
  "moe-routing": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let sel = (3, 41, 77, 102, 150, 171, 203, 240)
    let s = 13
    let x0 = 160
    let arr(a, b) = line(a, b, mark: (end: ">"), stroke: .8pt)
    rect((0, 40), (50, 66), fill: c-panel, stroke: .6pt + c-muted)
    content((25, 53), text(10pt)[token])
    rect((72, 40), (122, 66), fill: c-sand, stroke: .6pt + c-muted)
    content((97, 53), text(10pt)[gate])
    arr((50, 53), (72, 53))
    arr((122, 58), (x0 - 4, 128))
    arr((122, 50), (x0 - 4, 50))
    // shared expert, always on
    rect((x0, 116), (x0 + 70, 140), fill: c-blue2, stroke: .8pt + c-blue)
    content((x0 + 35, 128), text(10pt, weight: "bold")[shared])
    content((x0 + 84, 128), anchor: "west", text(10pt, fill: c-blue)[every token])
    // 256 routed experts, top-8 selected
    for i in range(256) {
      let r = int(i / 32)
      let c = calc.rem(i, 32)
      let hot = i in sel
      rect((x0 + c * s, 91 - r * s), (x0 + c * s + s - 2, 91 - r * s + s - 2),
        fill: if hot { c-orange2 } else { c-gray }, stroke: .3pt + c-rule)
    }
    content((x0 + 208, -12), text(10pt, fill: c-muted)[256 routed experts, router picks *top-8*])
  }),
  "memory-wall": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let sx = 0.22
    let rows = (
      ([DS-3 BF16], 1342, c-orange2, [1.34 TB]),
      ([DS-3 Int4], 336, c-sand2, [#sym.approx 0.34 TB]),
      ([A100], 40, c-teal2, [40 GB]),
      ([RTX 4080], 16, c-teal2, [16 GB]),
      ([Host DRAM], 2048, c-blue2, [2 TB (2 #sym.times 1 TB)]),
    )
    for (i, (name, v, fill, lbl)) in rows.enumerate() {
      let y = (4 - i) * 28 - if i >= 2 { 10 } else { 0 }
      content((-8, y + 9), anchor: "east", text(11pt, name))
      rect((0, y), (calc.max(v * sx, 2), y + 18), fill: fill, stroke: .5pt + c-muted)
      content((calc.max(v * sx, 2) + 6, y + 9), anchor: "west", text(10pt, weight: "bold", lbl))
    }
    line((0, -6), (0, 140), stroke: .6pt + c-muted)
  }),
  "offload-modes": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let dev(x0, y, title, body, fill) = {
      rect((x0, y), (x0 + 250, y + 48), fill: fill, stroke: .7pt + c-muted, radius: 3pt)
      content((x0 + 10, y + 33), anchor: "west", text(11pt, weight: "bold", title))
      content((x0 + 10, y + 14), anchor: "west", text(10pt, body))
    }
    let experts(x0, y) = for i in range(4) {
      rect((x0 + 168 + i * 18, y + 17), (x0 + 182 + i * 18, y + 31), fill: c-orange2, stroke: .5pt + c-muted)
    }
    // weight offloading
    content((125, 190), text(13pt, weight: "bold", fill: c-red)[Weight offloading])
    dev(0, 120, [GPU], [attn + all experts], c-teal)
    dev(0, 0, [CPU + DRAM], [stores experts], c-sand)
    experts(0, 0)
    line((200, 48), (200, 120), mark: (end: ">", fill: c-red), stroke: 3pt + c-red)
    content((190, 92), anchor: "east", text(10pt, fill: c-red)[expert weights])
    content((190, 76), anchor: "east", text(10pt, weight: "bold", fill: c-red)[PCIe 32 GB/s])
    content((125, -16), text(10pt, fill: c-muted)[new experts cross PCIe every step])
    // computation offloading
    let x0 = 320
    content((x0 + 125, 190), text(13pt, weight: "bold", fill: c-blue)[Computation offloading])
    dev(x0, 120, [GPU], [attn + shared experts], c-teal)
    dev(x0, 0, [CPU + DRAM], [computes routed experts], c-sand)
    experts(x0, 0)
    line((x0 + 60, 120), (x0 + 60, 48), mark: (end: ">"), stroke: .9pt)
    line((x0 + 110, 48), (x0 + 110, 120), mark: (end: ">"), stroke: .9pt)
    content((x0 + 66, 84), anchor: "west", text(9pt)[act.])
    content((x0 + 116, 84), anchor: "west", text(9pt)[out])
    content((x0 + 125, -16), text(10pt, fill: c-blue)[experts read from DRAM: 440 GB/s])
  }),
  "cpu-gauge": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let sx = 6
    let rows = (
      ([theoretical AMX], 73.7, c-gray, []),
      ([PyTorch AVX-512], 1.8, c-blue2, [1.8]),
      ([PyTorch AMX], 5.4, c-orange2, [5.4 = *7%*]),
      ([KT AMX (§3.2)], 21.3, c-teal2, [21.3 = 29%]),
    )
    for (i, (name, v, fill, lbl)) in rows.enumerate() {
      let y = (3 - i) * 24
      content((-8, y + 8), anchor: "east", text(10pt, name))
      rect((0, y), (v * sx, y + 16), fill: fill, stroke: (paint: c-muted, thickness: .5pt, dash: if i == 3 { "dashed" } else { none }))
      content((v * sx + 6, y + 8), anchor: "west", text(10pt, lbl))
    }
    content((73.7 * sx - 4, 3 * 24 + 8), anchor: "east", text(10pt, weight: "bold")[73.7 TFLOPS])
  }),
  "launch-overhead": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let w = 300
    for (i, (name, p, note)) in (([Fiddler], 73, [#sym.approx 7,000 launches #sym.times 16 µs]), ([Llama.cpp], 21, [#sym.approx 3,000 launches #sym.times 5 µs])).enumerate() {
      let y = (1 - i) * 46
      content((-8, y + 11), anchor: "east", text(11pt, weight: "bold", name))
      rect((0, y), (w * p / 100, y + 22), fill: c-orange2, stroke: .5pt + c-muted)
      rect((w * p / 100, y), (w, y + 22), fill: c-teal, stroke: .5pt + c-muted)
      content((w * p / 200, y + 11), text(10pt, weight: "bold")[#p%])
      content((w + 8, y + 11), anchor: "west", text(10pt, fill: c-muted, note))
    }
    rect((0, -26), (10, -16), fill: c-orange2, stroke: .5pt + c-muted)
    content((14, -21), anchor: "west", text(9pt)[launch overhead])
    rect((140, -26), (150, -16), fill: c-teal, stroke: .5pt + c-muted)
    content((154, -21), anchor: "west", text(9pt)[rest of GPU time])
  }),
  "numa-bg": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    for s in range(2) {
      let x = s * 180
      rect((x, 60), (x + 120, 110), fill: c-gray, stroke: .7pt + c-muted, radius: 3pt)
      content((x + 60, 92), text(11pt, weight: "bold")[Socket #s])
      content((x + 60, 74), text(9pt, fill: c-muted)[36 cores])
      rect((x, 0), (x + 120, 34), fill: c-sand, stroke: .6pt + c-muted)
      content((x + 60, 17), text(9pt)[DRAM 1 TB])
      line((x + 60, 34), (x + 60, 60), mark: (start: ">", end: ">"), stroke: 1.6pt + c-blue)
      content((x + 66, 47), anchor: "west", text(9pt, fill: c-blue)[220 GB/s])
    }
    line((120, 85), (180, 85), mark: (start: ">", end: ">"), stroke: (paint: c-red, thickness: 1.2pt, dash: "dashed"))
    content((150, 122), text(9pt, fill: c-red)[cross-socket])
    content((150, 98), text(9pt, weight: "bold", fill: c-red)[125 GB/s])
    // one MoE layer, decode
    let x0 = 390
    let sy = 16
    line((x0 - 10, 0), (x0 + 200, 0), stroke: .6pt + c-muted)
    for (i, (name, v, fill, dash)) in (([1 socket], 6.9, c-panel, none), ([2 sockets], 5.8, c-orange2, none), ([ideal 2×], 3.45, none, "dashed")).enumerate() {
      let x = x0 + i * 66
      rect((x, 0), (x + 44, v * sy), fill: fill, stroke: (paint: c-muted, thickness: .6pt, dash: dash))
      content((x + 22, v * sy + 9), text(10pt, weight: "bold")[#v ms])
      content((x + 22, -11), text(9pt, name))
    }
    content((x0 + 99, 140), text(10pt, fill: c-muted)[one MoE layer, decode (Fiddler)])
  }),
  "roadmap": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let rows = (
      ([CPU compute underused], [prefill], [AMX layout + kernel, AVX-512 switch, fused MoE], [§3.2]),
      ([Kernel launch + sync], [decode], [Async scheduling in one CUDA Graph], [§3.3]),
      ([Cross-NUMA traffic], [decode], [NUMA-aware tensor parallel], [§3.3]),
      ([CPU and GPU take turns], [decode], [Expert Deferral], [§4]),
    )
    content((120, 4 * 46 + 6), text(12pt, weight: "bold", fill: c-red)[Bottleneck])
    content((490, 4 * 46 + 6), text(12pt, weight: "bold", fill: c-blue)[KTransformers])
    for (i, (b, ph, t, sec)) in rows.enumerate() {
      let y = (3 - i) * 46
      rect((0, y), (240, y + 34), fill: c-tint, stroke: .6pt + c-muted, radius: 3pt)
      content((10, y + 17), anchor: "west", text(11pt, b))
      rect((242 - 58, y + 9), (236, y + 25), fill: if ph == [prefill] { c-sand } else { c-teal }, stroke: none, radius: 2pt)
      content((210, y + 17), text(9pt, ph))
      line((248, y + 17), (288, y + 17), mark: (end: ">"), stroke: 1pt)
      rect((296, y), (690, y + 34), fill: c-blue1, stroke: .6pt + c-muted, radius: 3pt)
      content((306, y + 17), anchor: "west", text(11pt, t))
      content((682, y + 17), anchor: "east", text(10pt, weight: "bold", fill: c-blue, sec))
    }
  }),
  // ---------------- Evaluation ----------------
  "testbed": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    for s in range(2) {
      let x = s * 230
      rect((x, 60), (x + 170, 108), fill: c-gray, stroke: .7pt + c-muted, radius: 3pt)
      content((x + 85, 92), text(10pt, weight: "bold")[Xeon Plat. 8452Y])
      content((x + 85, 74), text(9pt, fill: c-muted)[36 cores · AMX])
      rect((x, 0), (x + 170, 34), fill: c-sand, stroke: .6pt + c-muted)
      content((x + 85, 17), text(9pt)[1 TB DDR5 · 220 GB/s])
      line((x + 85, 34), (x + 85, 60), mark: (start: ">", end: ">"), stroke: 1.2pt + c-blue)
    }
    line((170, 84), (230, 84), mark: (start: ">", end: ">"), stroke: (paint: c-red, dash: "dashed", thickness: 1pt))
    content((200, 96), text(9pt, fill: c-red)[125 GB/s])
    rect((60, 150), (340, 196), fill: c-teal, stroke: .7pt + c-muted, radius: 3pt)
    content((200, 180), text(10pt, weight: "bold")[A100 40 GB  |  RTX 4080 16 GB])
    content((200, 162), text(9pt, fill: c-muted)[server-grade  |  consumer-grade])
    line((120, 150), (85, 108), mark: (start: ">", end: ">"), stroke: 1.2pt + c-muted)
    content((108, 132), anchor: "east", text(9pt)[PCIe 4.0 · 32 GB/s])
  }),
  "model-split": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let sx = 0.62
    let rows = (([DS-3], 671, 17), ([DS-2], 236, 13), ([QW-2], 57, 8))
    for (i, (name, tot, gpu)) in rows.enumerate() {
      let y = (2 - i) * 34
      content((-8, y + 10), anchor: "east", text(11pt, weight: "bold", name))
      rect((0, y), (gpu * sx, y + 20), fill: c-teal2, stroke: .5pt + c-muted)
      rect((gpu * sx, y), (tot * sx, y + 20), fill: c-sand, stroke: .5pt + c-muted)
      content((tot * sx + 6, y + 10), anchor: "west", text(10pt)[*#(tot)B*, #calc.round(gpu / tot * 100, digits: 1)% on GPU])
    }
    rect((0, -24), (10, -14), fill: c-teal2, stroke: .5pt + c-muted)
    content((14, -19), anchor: "west", text(9pt)[GPU: attention, shared experts, ...])
    rect((260, -24), (270, -14), fill: c-sand, stroke: .5pt + c-muted)
    content((274, -19), anchor: "west", text(9pt)[CPU: routed experts])
  }),
  "decode-bars": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let fills = (c-panel, c-sand2, c-teal2, c-blue2)
    let names = ([Fiddler], [Llama.cpp], [KT], [KT + Deferral])
    let bw = 15
    let panel(x0, title, groups, top, ticks) = {
      let sy = 120 / top
      content((x0 + 150, 150), text(12pt, weight: "bold", title))
      line((x0, 0), (x0 + 300, 0), stroke: .6pt + c-muted)
      for t in ticks {
        line((x0, t * sy), (x0 + 300, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
        content((x0 - 4, t * sy), anchor: "east", text(9pt, fill: c-muted)[#t])
      }
      for (g, (name, vals)) in groups.enumerate() {
        let gx = x0 + 18 + g * 100
        for (k, v) in vals.enumerate() {
          if v != none {
            rect((gx + k * bw, 0), (gx + k * bw + bw - 2, v * sy), fill: fills.at(k), stroke: .5pt + c-muted)
          }
        }
        let gain = calc.round((vals.at(3) / vals.at(2) - 1) * 100)
        content((gx + 3 * bw + 6, vals.at(3) * sy + 9), text(9pt, weight: "bold", fill: c-blue)[+#gain%])
        content((gx + 2 * bw, -10), text(10pt, name))
      }
    }
    panel(0, [BF16 / FP16], (([DS-3], (2.4, 4.7, 5.87, 7.8)), ([DS-2], (3.5, 7.0, 11.9, 17.25)), ([QW-2], (5.6, 13.0, 22.9, 25.7))), 27, (0, 10, 20))
    panel(360, [Quantized], (([DS-3 i4], (none, 9.0, 16.2, 23.0)), ([DS-2 i8], (none, 10.0, 17.6, 25.5)), ([QW-2 i8], (none, 19.2, 37.0, 44.0))), 46, (0, 20, 40))
    content((-26, 60), angle: 90deg, text(9pt, fill: c-muted)[tokens/s])
    for (k, name) in names.enumerate() {
      let lx = 80 + k * 130
      rect((lx, -38), (lx + 10, -28), fill: fills.at(k), stroke: .5pt + c-muted)
      content((lx + 14, -33), anchor: "west", text(9pt, name))
    }
  }),
  "defer-vs-skip": cetz.canvas(length: 1pt, {
    import cetz.draw: *
    let sx = 34
    let sy = 4.2
    let lo = -30
    let skip = (0, .2, .1, -.6, -2.3, -5.9, -13.3, -28.6, -88.7)
    let deferv = (0, .2, .1, .2, .2, .1, -.5, -1.9, -6.7)
    let pt(i, v) = (i * sx, calc.max(v, lo) * sy)
    for t in (0, -10, -20, -30) {
      line((0, t * sy), (8 * sx, t * sy), stroke: (paint: c-rule, dash: "dotted", thickness: .4pt))
      content((-4, t * sy), anchor: "east", text(9pt, fill: c-muted)[#t%])
    }
    for i in range(9) { content((i * sx, lo * sy - 10), text(9pt, fill: c-muted)[#i]) }
    content((4 * sx, lo * sy - 26), text(10pt, fill: c-muted)[experts skipped / deferred])
    line((6 * sx, 6), (6 * sx, lo * sy), stroke: (paint: c-orange, dash: "dashed", thickness: .8pt))
    content((6 * sx, 14), text(9pt, weight: "bold", fill: c-orange)[default (2+6)])
    for (vals, col, name) in ((skip, c-red, [skipping]), (deferv, c-blue, [deferral])) {
      line(..vals.enumerate().map(((i, v)) => pt(i, v)), stroke: 1.6pt + col)
      for (i, v) in vals.enumerate() { circle(pt(i, v), radius: 2.6, fill: col, stroke: none) }
    }
    line(pt(8, lo), (8 * sx, lo * sy - 4), stroke: 1.6pt + c-red)
    content((8 * sx + 6, lo * sy + 4), anchor: "west", text(9pt, weight: "bold", fill: c-red)[−88.7%])
    content((6 * sx + 6, -13.3 * sy), anchor: "west", text(9pt, weight: "bold", fill: c-red)[−13.3%])
    content((6 * sx - 4, -0.5 * sy - 10), anchor: "east", text(9pt, weight: "bold", fill: c-blue)[−0.5%])
    content((8 * sx + 6, -6.7 * sy), anchor: "west", text(9pt, fill: c-blue)[−6.7%])
    content((10, -60), anchor: "west", text(10pt, fill: c-blue)[● deferral])
    content((10, -76), anchor: "west", text(10pt, fill: c-red)[● skipping])
  }),
)

/// One figure by name, as an inline SVG in HTML export.
#let diagram(name) = svg-frame(figs.at(name))
