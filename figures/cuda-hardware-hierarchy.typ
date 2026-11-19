// Figures for content/posts/ml-systems/gpu-kernels/cuda-hardware-hierarchy.typ, drawn with cetz.
// Numbers are for the RTX A6000 (GA102, compute capability 8.6) unless a
// figure says otherwise.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "@tola-modules/nasapunk:0.0.0": cetz
#import "@tola-modules/nasapunk:0.0.0": arrow, box-swatch, c, legend
#import "@tola-modules/nasapunk:0.0.0": palette

// ============================================================================
// Shared pieces
// ============================================================================

#let paper = palette.paper
#let dashed = (paint: c.grey2, thickness: .6pt, dash: "dashed")
#let dotted = (paint: c.grey2, thickness: .5pt, dash: "dotted")

#let txt(body, size: 8.5pt, fill: c.muted, weight: 400, style: "normal") = text(
  size: size, fill: fill, weight: weight, style: style, body,
)
#let head(body, fill: c.ink) = text(size: 8pt, weight: 700, tracking: .6pt, fill: fill, upper(body))

/// A rectangle with its top-left corner at (x, y), w wide and h tall, and an
/// optional centred label (several lines allowed).
#let cell(x, y, w, h, body: none, fill: c.grey1, stroke: .6pt + c.line, size: 7.5pt, ink: c.ink, weight: 600, radius: 1.5) = {
  // No `import cetz.draw: *` here: it would shadow `fill` and `stroke`.
  cetz.draw.rect((x, y), (x + w, y - h), fill: fill, stroke: stroke, radius: radius)
  if body != none {
    cetz.draw.content((x + w / 2, y - h / 2), align(center, txt(body, size: size, fill: ink, weight: weight)))
  }
}

#let tones = (
  blue: (c.blue1, .7pt + c.blue),
  blue2: (c.blue2, .7pt + c.blue),
  orange: (c.orange1, .9pt + c.orange),
  teal: (c.teal1, .7pt + c.teal),
  grey: (c.grey1, .6pt + c.grey2),
)

/// A labelled hardware unit in one of `tones`.
#let unit(x, y, w, h, body, tone: "blue", size: 7.5pt, weight: 600) = {
  let (f, s) = tones.at(tone)
  cell(x, y, w, h, body: body, fill: f, stroke: s, size: size, weight: weight)
}

// ============================================================================
// The chip and one SM
// ============================================================================

/// GA102 as CUDA sees it: 84 SMs in 7 GPCs, one L2, 12 memory controllers,
/// GDDR6. Schematic, not the floor plan (on the die, L2 sits in the middle).
#let fig-gpu() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, sw, sh, gx, gy) = (50, 30, 14, 3, 5)
  let x1 = x0 + 12 * (sw + gx) - gx
  content((0, 12), head("RTX A6000 · GA102"), anchor: "west")
  content((x1, 12), txt("7 GPCs × 12 SMs = 84 SMs", size: 7.5pt), anchor: "east")
  for g in range(7) {
    let y = -g * (sh + gy)
    content((0, y - sh / 2), txt("GPC " + str(g), size: 7.5pt), anchor: "west")
    for s in range(12) {
      let hot = g == 0 and s == 0
      unit(x0 + s * (sw + gx), y, sw, sh, "SM", tone: if hot { "orange" } else { "blue" }, size: 6.5pt)
    }
  }
  let yl = -7 * (sh + gy) - 6
  let ym = yl - 20 - 12
  let yd = ym - 14 - 12
  let mw = (x1 - x0 - 11 * 3) / 12
  for k in range(12) {
    let cx = x0 + k * (mw + 3) + mw / 2
    line((cx, yl - 20), (cx, ym), stroke: .6pt + c.line)
    line((cx, ym - 14), (cx, yd), stroke: .6pt + c.line)
  }
  content((0, yl - 10), txt("L2", size: 7.5pt), anchor: "west")
  unit(x0, yl, x1 - x0, 20, "L2 cache · 6 MB · shared by all 84 SMs", tone: "blue2", size: 8pt)
  content((0, ym - 7), txt("MC", size: 7.5pt), anchor: "west")
  for k in range(12) {
    unit(x0 + k * (mw + 3), ym, mw, 14, "32-bit", tone: "grey", size: 6.5pt, weight: 400)
  }
  content((0, yd - 10), txt("DRAM", size: 7.5pt), anchor: "west")
  unit(x0, yd, x1 - x0, 20, "device memory · 48 GB GDDR6 · 384-bit bus · 768 GB/s", tone: "grey", size: 8pt)
})

/// One GA102 SM: four partitions, each with its own scheduler, register file
/// and execution units, sharing one 128 KB SRAM for L1 and shared memory,
/// whose shared part is spread over 32 four-byte banks.
#let fig-sm() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (W, pw, gap, x0) = (528, 122, 8, 8)
  rect((0, 0), (W, -226), fill: none, stroke: .8pt + c.blue, radius: 3)
  content((8, -11), txt("SM", size: 9pt, fill: c.ink, weight: 700), anchor: "west")
  content((W - 8, -11), txt("resident at once: ≤ 48 warps · ≤ 16 blocks · 65,536 registers", size: 7.5pt), anchor: "east")
  for p in range(4) {
    let x = x0 + p * (pw + gap)
    rect((x, -22), (x + pw, -158), fill: c.panel, stroke: .6pt + c.line, radius: 2)
    content((x + 6, -30), txt("partition " + str(p), size: 7pt, fill: c.ink, weight: 600), anchor: "west")
    unit(x + 4, -38, pw - 8, 22, [warp scheduler \ 1 instruction / clock], tone: "orange", size: 6.5pt)
    unit(x + 4, -64, pw - 8, 26, [register file · 64 KB \ 16,384 × 32-bit], tone: "teal", size: 6.5pt)
    let hw = (pw - 12) / 2
    unit(x + 4, -94, hw, 18, "16 FP32", size: 6.5pt)
    unit(x + 8 + hw, -94, hw, 18, "16 FP32/INT32", size: 6.5pt)
    unit(x + 4, -116, hw, 18, "4 LD/ST", tone: "grey", size: 6.5pt)
    unit(x + 8 + hw, -116, hw, 18, "4 SFU", tone: "grey", size: 6.5pt)
    unit(x + 4, -138, pw - 8, 16, "tensor core", tone: "grey", size: 6.5pt)
  }
  // the shared SRAM, and the 32 banks shared memory is spread over
  let (by, bx0, bx1) = (-168, x0, W - x0)
  rect((bx0, by), (bx1, by - 48), fill: c.blue1, stroke: .7pt + c.blue, radius: 1.5)
  content((W / 2, by - 9), txt("L1 data cache + shared memory · 128 KB, one SRAM · shared memory up to 100 KB, L1 the rest",
    size: 7pt, fill: c.ink, weight: 600))
  content((W / 2, by - 20), txt("shared memory: 32 banks, each 4 bytes wide, one word per bank per cycle", size: 7pt, fill: c.ink))
  let bw = (bx1 - bx0 - 16) / 32
  for b in range(32) {
    cell(bx0 + 8 + b * bw + .5, by - 28, bw - 1, 14, body: str(b), fill: paper, stroke: .5pt + c.blue, size: 5.5pt, weight: 400)
  }
  arrow((W / 2, -226), (W / 2, -242), color: c.line)
  content((W / 2 + 6, -235), txt("to L2", size: 7pt), anchor: "west")
})

// ============================================================================
// From launch to warps
// ============================================================================

/// A grid of 12 blocks, placed whole on SMs; one block cut into 8 warps.
#let fig-mapping() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // grid
  content((0, 12), head("grid · 12 blocks"), anchor: "west")
  let (bw, bh, g) = (34, 22, 4)
  for i in range(12) {
    let (r, k) = (calc.quo(i, 4), calc.rem(i, 4))
    unit(k * (bw + g), -r * (bh + g), bw, bh, "B" + str(i), tone: if i == 4 { "orange" } else { "blue" }, size: 7pt)
  }
  // SMs, with an illustrative placement
  let sx = 210
  content((sx, 12), head("SMs"), anchor: "west")
  for s in range(3) {
    let y = -s * 32
    rect((sx, y), (sx + 150, y - 26), fill: c.panel, stroke: .7pt + c.line, radius: 2)
    content((sx + 6, y - 13), txt("SM " + str(s), size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
    for j in range(4) {
      let b = s + 3 * j
      unit(sx + 38 + j * 27, y - 4, 24, 18, "B" + str(b), tone: if b == 4 { "orange" } else { "blue" }, size: 6.5pt)
    }
  }
  arrow((156, -37), (202, -37), color: c.ink)
  content((179, -30), txt("whole blocks", size: 6.5pt))
  // block B4 as warps
  let wx = 404
  content((wx, 12), head("B4 · 256 threads"), anchor: "west")
  for w in range(8) {
    unit(wx, -w * 12, 140, 10, "warp " + str(w) + " · threads " + str(32 * w) + "–" + str(32 * w + 31),
      tone: if calc.rem(w, 2) == 0 { "teal" } else { "blue" }, size: 6.5pt, weight: 400)
  }
  arrow((364, -45), (398, -45), color: c.orange)
  content((381, -38), txt("32 each", size: 6.5pt))
})

/// A 16 x 16 block: the linear thread index runs along x first, so each warp
/// is two rows. Each cell shows the thread's lane, tid % 32.
#let fig-warp-slice() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, ch) = (40, 18, 12)
  content((x0 + 8 * cw, 22), txt("threadIdx.x", size: 7.5pt, fill: c.ink, weight: 600))
  content((12, -8 * ch), std.rotate(-90deg, reflow: true, txt("threadIdx.y", size: 7.5pt, fill: c.ink, weight: 600)))
  for x in range(16) { content((x0 + (x + .5) * cw, 9), txt(str(x), size: 6.5pt)) }
  for y in range(16) {
    content((x0 - 5, -(y + .5) * ch), txt(str(y), size: 6.5pt), anchor: "east")
    for x in range(16) {
      let tid = y * 16 + x
      let w = calc.quo(tid, 32)
      let hot = tid == 37
      let fill = if hot { c.orange1 } else if calc.rem(w, 2) == 0 { c.blue1 } else { c.teal1 }
      rect((x0 + x * cw, -y * ch), (x0 + (x + 1) * cw, -(y + 1) * ch), fill: fill, stroke: .5pt + paper)
      content((x0 + (x + .5) * cw, -(y + .5) * ch), txt(str(calc.rem(tid, 32)), size: 6pt,
        fill: if hot { c.orange } else { c.ink }, weight: if hot { 700 } else { 400 }))
    }
  }
  let xr = x0 + 16 * cw + 6
  for w in range(8) {
    let yt = -w * 2 * ch
    line((xr, yt - 1.5), (xr + 4, yt - 1.5), (xr + 4, yt - 2 * ch + 1.5), (xr, yt - 2 * ch + 1.5), stroke: .6pt + c.line)
    content((xr + 9, yt - ch), txt("warp " + str(w) + " · tid " + str(32 * w) + "–" + str(32 * w + 31), size: 7.5pt, fill: c.ink),
      anchor: "west")
  }
  let yb = -16 * ch - 16
  rect((x0, yb + 4), (x0 + 11, yb - 4), fill: c.orange1, stroke: .6pt + c.orange)
  content((x0 + 16, yb), txt[threadIdx = (5, 2) → tid = 2 · 16 + 5 = 37 → warp 37 / 32 = 1, lane 37 % 32 = 5], anchor: "west")
})

/// Lanes vs threads: lane 5 exists in every warp, as a different thread; in a
/// divergent branch some lanes are inactive while their threads still exist.
#let fig-lanes() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, ch) = (66, 14, 14)
  content((x0 - 6, 9), txt("lane", size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
  for l in range(32) {
    content((x0 + (l + .5) * cw, 9), txt(str(l), size: 6pt,
      fill: if l == 5 { c.orange } else { c.muted }, weight: if l == 5 { 700 } else { 400 }))
  }
  let row(y, label, sub, base, active: l => true, hot: true) = {
    content((x0 - 6, y - ch / 2 + (if sub == none { 0 } else { 4 })), txt(label, size: 7.5pt, fill: c.ink, weight: 600), anchor: "east")
    if sub != none { content((x0 - 6, y - ch / 2 - 5), txt(sub, size: 6.5pt), anchor: "east") }
    for l in range(32) {
      let on = active(l)
      let h = hot and l == 5
      let fill = if h { c.orange1 } else if on { c.blue1 } else { paper }
      rect((x0 + l * cw, y), (x0 + (l + 1) * cw, y - ch), fill: fill,
        stroke: if on { .5pt + paper } else { dashed })
      content((x0 + (l + .5) * cw, y - ch / 2), txt(str(base + l), size: 6pt,
        fill: if h { c.orange } else if on { c.ink } else { c.muted }, weight: if h { 700 } else { 400 }))
    }
  }
  row(0, "warp 0", none, 0)
  row(-20, "warp 1", none, 32)
  rect((x0 + 5 * cw - 1, 1), (x0 + 6 * cw + 1, -20 - ch - 1), stroke: 1.1pt + c.orange)
  row(-52, "warp 1", raw("if (tid < 44)"), 32, active: l => l < 12, hot: false)
  let yb = -52 - ch - 16
  box-swatch(x0, yb, c.blue1)
  content((x0 + 16, yb), txt("cell = thread id (tid)"), anchor: "west")
  box-swatch(x0 + 150, yb, c.orange1, stroke: .6pt + c.orange)
  content((x0 + 166, yb), txt("lane 5: thread 5 in warp 0, thread 37 in warp 1"), anchor: "west")
  rect((x0, yb - 14 + 4), (x0 + 11, yb - 14 - 4), fill: paper, stroke: dashed)
  content((x0 + 16, yb - 14), txt("inactive lane: threads 44–63 exist, their lanes skip this instruction"), anchor: "west")
})

/// The register file, logically: one row per (warp, register), one column per
/// lane. A thread's registers are its lane's column in its warp's rows.
#let fig-regfile() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, rh) = (78, 9, 10)
  let x1 = x0 + 32 * cw
  content((x0, 26), head("register file · logical view"), anchor: "west")
  content((x0 - 6, 9), txt("lane", size: 7pt, fill: c.ink, weight: 600), anchor: "east")
  for l in range(32) {
    content((x0 + (l + .5) * cw, 9), txt(str(l), size: 5.5pt,
      fill: if l == 5 { c.orange } else { c.muted }, weight: if l == 5 { 700 } else { 400 }))
  }
  // (warp, register label); none = elided rows
  let regs = ("R0", "R1", none, "R39")
  let y = 0
  let tops = (:)
  for w in (0, 1) {
    tops.insert(str(w), y)
    for (k, r) in regs.enumerate() {
      let label = (if k == 0 { "warp " + str(w) + " · " } else { "" }) + (if r == none { "⋮" } else { r })
      content((x0 - 6, y - rh / 2), txt(label, size: 7pt, fill: c.ink), anchor: "east")
      for l in range(32) {
        let hot = w == 1 and l == 5
        let fill = if r == none { c.panel } else if hot { c.orange1 } else { c.teal1 }
        rect((x0 + l * cw, y), (x0 + (l + 1) * cw, y - rh), fill: fill, stroke: .4pt + paper)
      }
      if r == none {
        for l in (0, 5, 16, 31) { content((x0 + (l + .5) * cw, y - rh / 2), txt("⋮", size: 6pt)) }
      }
      y -= rh
    }
    y -= 5
  }
  // the rest of the file
  rect((x0, y), (x1, y - 18), fill: paper, stroke: dashed)
  content(((x0 + x1) / 2, y - 9), txt("warps 2–7 of this block, other blocks' warps, free registers", size: 7pt))
  content((x0 - 6, y - 9), txt("…", size: 7pt, fill: c.ink), anchor: "east")
  // thread 37's column
  let t1 = tops.at("1")
  rect((x0 + 5 * cw - 1, t1 + 1), (x0 + 6 * cw + 1, t1 - 4 * rh - 1), stroke: 1.1pt + c.orange)
  // notes
  let note(yy, body) = content((x1 + 14, yy), block(width: 160pt, txt(body, size: 7.5pt)), anchor: "west")
  line((x1 + 2, -rh / 2), (x1 + 10, -rh / 2), stroke: .6pt + c.line)
  note(-rh / 2, [one row = one register of one warp: 32 lanes × 4 B = 128 B])
  line((x0 + 6 * cw + 2, t1 - 2 * rh), (x1 + 10, t1 - 2 * rh), stroke: .6pt + c.orange)
  note(t1 - 2 * rh, [thread 37 = warp 1, lane 5: its 40 registers are one column of warp 1's rows])
  note(y - 9, [256 threads × 40 registers = 10,240 of the SM's 65,536])
})

// ============================================================================
// Occupancy and issue
// ============================================================================

/// The 48 warp slots of one SM under four launch configurations.
#let fig-occupancy() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (sw, sh, gap) = (10, 14, 50)
  let cases = (
    ("256 threads · 32 registers", 6, 8, "6 blocks × 8 warps · limit: 48 warps"),
    ("32 threads · 32 registers", 16, 1, "16 blocks × 1 warp · limit: 16 blocks"),
    ("256 threads · 64 registers", 4, 8, "4 blocks × 8 warps · limit: 4 × 16,384 = 65,536 registers"),
    ("256 threads · 32 registers · 40 KB shared memory", 2, 8, "2 blocks × 8 warps · limit: 2 × (40 + 1) KB ≤ 100 KB"),
  )
  for (i, (cfg, nb, wpb, res)) in cases.enumerate() {
    let y = -i * gap
    content((0, y), txt(cfg, size: 8pt, fill: c.ink, weight: 600), anchor: "south-west")
    for s in range(48) {
      let b = calc.quo(s, wpb)
      let used = b < nb
      let fill = if not used { none } else if calc.rem(b, 2) == 0 { c.blue1 } else { c.teal1 }
      rect((s * sw, y - 3), ((s + 1) * sw, y - 3 - sh), fill: fill, stroke: if used { .5pt + paper } else { dotted })
    }
    content((48 * sw + 8, y - 3 - sh / 2), txt(str(nb * wpb) + " / 48", size: 8pt, fill: c.ink, weight: 700), anchor: "west")
    content((0, y - sh - 6), txt(res, size: 7.5pt), anchor: "north-west")
  }
})

/// One scheduler, a load with a 10-cycle latency: with 4 warps the others
/// fill the wait, with 2 the scheduler idles.
#let fig-issue() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, cw, rh, n) = (78, 26, 14, 16)
  content((x0 - 8, 22), txt("cycle", size: 7pt), anchor: "east")
  for t in range(n) { content((x0 + (t + .5) * cw, 22), txt(str(t), size: 6.5pt)) }

  // warps: ((cycle, instruction), ...), (first, last) waiting cycle
  let panel(y0, title, warps) = {
    content((0, y0 + 6), txt(title, size: 8pt, fill: c.ink, weight: 700), anchor: "west")
    let busy = range(n).map(_ => none)
    for (w, (issues, wait)) in warps.enumerate() {
      let y = y0 - 4 - w * (rh + 3)
      content((x0 - 8, y - rh / 2), txt("warp " + str(w), size: 7.5pt, fill: c.ink), anchor: "east")
      rect((x0, y), (x0 + n * cw, y - rh), fill: c.panel, stroke: none)
      let (a, b) = wait
      rect((x0 + a * cw + 1, y - 2), (x0 + (b + 1) * cw - 1, y - rh + 2), fill: c.orange1, stroke: .5pt + c.orange)
      if b - a >= 3 {
        content((x0 + (a + b + 1) / 2 * cw, y - rh / 2), txt("waiting for LD", size: 6.5pt, fill: c.ink))
      }
      for (t, ins) in issues {
        cell(x0 + t * cw + 1, y - 1, cw - 2, rh - 2, body: ins, fill: c.blue1, stroke: .6pt + c.blue, size: 6.5pt)
        busy.at(t) = w
      }
    }
    let ys = y0 - 4 - warps.len() * (rh + 3) - 4
    content((x0 - 8, ys - rh / 2), txt("issued", size: 7.5pt, fill: c.ink, weight: 700), anchor: "east")
    for t in range(n) {
      let w = busy.at(t)
      if w == none {
        cell(x0 + t * cw + 1, ys - 1, cw - 2, rh - 2, body: "idle", fill: none, stroke: dashed, size: 6pt, ink: c.muted, weight: 400)
      } else {
        cell(x0 + t * cw + 1, ys - 1, cw - 2, rh - 2, body: "W" + str(w), fill: c.ink, stroke: none, size: 6.5pt, ink: paper)
      }
    }
  }
  let prog(t0) = ((t0, "I1"), (t0 + 1, "I2"), (t0 + 2, "LD"))
  panel(0, "4 warps", (
    (prog(0) + ((12, "I3"), (13, "I4"), (14, "I5")), (3, 11)),
    (prog(3) + ((15, "I3"),), (6, 14)),
    (prog(6), (9, 15)),
    (prog(9), (12, 15)),
  ))
  panel(-118, "2 warps", (
    (prog(0) + ((12, "I3"), (13, "I4"), (14, "I5")), (3, 11)),
    (prog(3) + ((15, "I3"),), (6, 14)),
  ))
})

// ============================================================================
// Memory
// ============================================================================

/// Where each kind of memory sits and who can see it.
#let fig-memory() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let sm(x, name) = {
    rect((x, 0), (x + 190, -98), fill: none, stroke: .8pt + c.blue, radius: 3)
    content((x + 8, -10), txt(name, size: 8.5pt, fill: c.ink, weight: 700), anchor: "west")
    unit(x + 8, -20, 174, 22, "registers · 256 KB", tone: "teal", size: 7pt)
    unit(x + 8, -50, 56, 34, [shared \ block A], tone: "blue", size: 7pt)
    unit(x + 66, -50, 56, 34, [shared \ block B], tone: "blue", size: 7pt)
    unit(x + 124, -50, 58, 34, [L1 cache], tone: "grey", size: 7pt)
    content((x + 95, -91), txt("one 128 KB SRAM", size: 6.5pt))
  }
  sm(0, "SM 0")
  content((210, -49), txt("⋯", size: 12pt, fill: c.ink))
  sm(230, "SM 83")
  for x in (95, 325) { line((x, -98), (x, -112), stroke: .7pt + c.line) }
  unit(0, -112, 420, 20, "L2 cache · 6 MB", tone: "blue2", size: 7.5pt)
  line((210, -132), (210, -144), stroke: .7pt + c.line)
  unit(0, -144, 420, 20, "device memory · 48 GB GDDR6 (global, local, constant)", tone: "grey", size: 7.5pt)
  let (sx, rows) = (436, (
    (-31, "one thread"),
    (-67, [one block (shared) \ its SM (L1)]),
    (-122, "all SMs"),
    (-154, "all threads + host copies"),
  ))
  content((sx, 4), txt("visible to", size: 7.5pt, fill: c.ink, weight: 700), anchor: "west")
  for (y, body) in rows { content((sx, y), txt(body, size: 7.5pt), anchor: "west") }
})

/// One warp loading 4-byte floats: lanes on top, memory below in 32-byte
/// sectors. Touched sectors are outlined; the words actually used are orange.
#let fig-coalesce() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, lw, lh, mh) = (46, 14, 11, 12)
  let W = 32 * lw
  // nw: words drawn; f: lane -> word
  let panel(y0, code, note, nw, f) = {
    content((x0, y0 + 4), txt(code, size: 8pt, fill: c.ink, weight: 700), anchor: "south-west")
    content((x0 + W, y0 + 4), txt(note, size: 7.5pt), anchor: "south-east")
    content((x0 - 6, y0 - lh / 2), txt("lanes", size: 7pt), anchor: "east")
    let ym = y0 - lh - 30
    content((x0 - 6, ym - mh / 2), txt("memory", size: 7pt), anchor: "east")
    let ww = W / nw
    let words = range(32).map(f)
    let touched = words.map(w => calc.quo(w, 8)).dedup()
    for l in range(32) {
      let wx = x0 + (words.at(l) + .5) * ww
      line((x0 + (l + .5) * lw, y0 - lh), (wx, ym), stroke: .35pt + c.line)
    }
    for l in range(32) {
      rect((x0 + l * lw, y0), (x0 + (l + 1) * lw, y0 - lh), fill: c.blue1, stroke: .5pt + paper)
    }
    for s in range(calc.quo(nw, 8)) {
      let on = s in touched
      rect((x0 + s * 8 * ww, ym), (x0 + (s + 1) * 8 * ww, ym - mh), fill: if on { c.panel } else { none },
        stroke: if on { .8pt + c.ink } else { dotted })
    }
    for w in words {
      rect((x0 + w * ww + .3, ym - .8), (x0 + (w + 1) * ww - .3, ym - mh + .8), fill: c.orange, stroke: none)
    }
  }
  panel(0, raw("x[i]"), "4 sectors · 128 B moved for 128 B used · 100%", 32, l => l)
  panel(-82, raw("x[2 * i]"), "8 sectors · 256 B moved · 50%", 64, l => 2 * l)
  panel(-164, raw("x[i + 1]"), "5 sectors · 160 B moved · 80%", 40, l => l + 1)
  panel(-246, raw("x[idx[i]]  (scattered)"), "32 sectors · 1024 B moved · 12.5%", 256,
    l => calc.rem(l * 13 + 7, 32) * 8 + calc.rem(l * 3, 8))
  let yb = -246 - lh - 30 - mh - 16
  rect((x0, yb + 4), (x0 + 11, yb - 4), fill: c.panel, stroke: .8pt + c.ink)
  content((x0 + 16, yb), txt("32-byte sector fetched"), anchor: "west")
  rect((x0 + 140, yb + 4), (x0 + 151, yb - 4), fill: c.orange, stroke: none)
  content((x0 + 156, yb), txt("4-byte word a lane asked for"), anchor: "west")
})

/// Shared memory as 32 bank columns, one 4-byte word per cell, and the words
/// one warp touches under four access patterns.
#let fig-banks() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, bw, bh) = (64, 13, 10)
  let W = 32 * bw
  content((x0 - 6, 9), txt("bank", size: 7pt, fill: c.ink, weight: 600), anchor: "east")
  for b in range(32) { content((x0 + (b + .5) * bw, 9), txt(str(b), size: 5.5pt)) }
  // rows: ((label, first word), ...); cells: word -> label of the lane(s) on it
  let panel(y0, code, result, rows, cells) = {
    content((x0, y0 - 2), txt(code, size: 8pt, fill: c.ink, weight: 700), anchor: "south-west")
    content((x0 + W, y0 - 2), txt(result, size: 7.5pt, fill: c.ink, weight: 600), anchor: "south-east")
    for (r, (label, w0)) in rows.enumerate() {
      let y = y0 - 4 - r * bh
      content((x0 - 6, y - bh / 2), txt(label, size: 6pt), anchor: "east")
      for b in range(32) {
        let hit = if w0 == none { none } else { cells.at(str(w0 + b), default: none) }
        rect((x0 + b * bw, y), (x0 + (b + 1) * bw, y - bh), fill: if hit != none { c.orange1 } else { c.panel },
          stroke: if hit != none { .6pt + c.orange } else { .4pt + paper })
        if hit != none { content((x0 + (b + .5) * bw, y - bh / 2), txt(hit, size: 5.5pt, fill: c.ink)) }
        if w0 == none and b in (0, 16, 31) { content((x0 + (b + .5) * bw, y - bh / 2), txt("⋮", size: 6pt)) }
      }
    }
  }
  let lanes(f) = {
    let d = (:)
    for l in range(32) { d.insert(str(f(l)), str(l)) }
    d
  }
  panel(-14, raw("s[lane]"), "no conflict · 1 pass", (("words 0–31", 0),), lanes(l => l))
  panel(-44, raw("s[2 * lane]"), "2-way conflict · 2 passes", (("words 0–31", 0), ("32–63", 32)), lanes(l => 2 * l))
  panel(-84, raw("s[0]"), "broadcast · 1 pass", (("words 0–31", 0),), ("0": "all"))
  panel(-114, raw("s[32 * lane]"), "32-way conflict · 32 passes",
    (("words 0–31", 0), ("32–63", 32), ("64–95", 64), ("⋮", none), ("992–1023", 992)), lanes(l => 32 * l))
})

/// Reading a 32 x 32 float tile by column, without and with one word of
/// padding per row. Rows of the drawing are 32-word rows of shared memory.
#let fig-padding() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, bw, bh, nr) = (72, 13, 10, 8)
  let W = 32 * bw
  content((x0 - 6, 9), txt("bank", size: 7pt, fill: c.ink, weight: 600), anchor: "east")
  for b in range(32) { content((x0 + (b + .5) * bw, 9), txt(str(b), size: 5.5pt)) }
  // stride: words per tile row
  let panel(y0, code, result, stride) = {
    content((x0, y0 - 2), txt(code, size: 8pt, fill: c.ink, weight: 700), anchor: "south-west")
    content((x0 + W, y0 - 2), txt(result, size: 7.5pt, fill: c.ink, weight: 600), anchor: "south-east")
    for r in range(nr) {
      let y = y0 - 4 - r * bh
      content((x0 - 6, y - bh / 2), txt("words " + str(32 * r) + "–" + str(32 * r + 31), size: 6pt), anchor: "east")
      for b in range(32) {
        let w = 32 * r + b
        let (row, col) = (calc.quo(w, stride), calc.rem(w, stride))
        let hit = col == 0
        let pad = col == 32
        let fill = if hit { c.orange1 } else if pad { c.grey2 } else { c.panel }
        rect((x0 + b * bw, y), (x0 + (b + 1) * bw, y - bh), fill: fill,
          stroke: if hit { .6pt + c.orange } else { .4pt + paper })
        if hit { content((x0 + (b + .5) * bw, y - bh / 2), txt(str(row), size: 5.5pt, fill: c.ink)) }
        if pad { content((x0 + (b + .5) * bw, y - bh / 2), txt("pad", size: 4.5pt, fill: c.ink)) }
      }
    }
    content((x0, y0 - 4 - nr * bh - 3), txt("rows 8–31 continue the same pattern", size: 6.5pt), anchor: "north-west")
  }
  panel(-14, raw("float tile[32][32];  tile[lane][0]"), "all in bank 0 · 32-way conflict", 32)
  panel(-130, raw("float tile[32][33];  tile[lane][0]"), "lane k in bank k · 1 pass", 33)
})
