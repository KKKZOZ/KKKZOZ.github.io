// Figures for content/posts/ml-systems/gpu-kernels/triton-builtin-tutorial.typ,
// drawn with cetz. Same conventions as /utils/figure.typ: 1pt per unit,
// y grows upward, every figure under ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, seg, tag, txt

// One fill per program, for figures that colour work by owner.
#let prog-fill = (c.teal2, c.orange2, c.blue2, c.grey2)

/// 10 blocks of work: one program per block vs 4 programs looping over them.
#let fig-grid-mapping() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = 40
  let row(y, owner, fill) = for b in range(10) {
    rect((b * w, y), (b * w + w, y + 28), fill: fill(b), stroke: .5pt + white)
    content((b * w + w / 2, y + 19), txt("B" + str(b), fill: c.ink, weight: 600))
    content((b * w + w / 2, y + 8), txt(owner(b), size: 6.5pt, fill: c.ink))
  }
  let brace(x0, x1, y, body) = {
    line((x0 + 3, y), (x1 - 3, y), stroke: .7pt + c.line)
    content(((x0 + x1) / 2, y - 8), txt(body))
  }

  content((0, 160), tag("Fixed-size grid · grid = (10,)", fill: c.blue), anchor: "west")
  content((0, 146), txt("each program handles one block, then exits"), anchor: "west")
  row(106, b => "P" + str(b), b => c.blue1)
  content((10 * w + 10, 120), txt("10 programs"), anchor: "west")

  content((0, 80), tag("Grid-stride loop / persistent kernel · grid = (4,)", fill: c.blue), anchor: "west")
  content((0, 66), txt("program p handles blocks p, p + 4, p + 8, …"), anchor: "west")
  row(26, b => "P" + str(calc.rem(b, 4)), b => prog-fill.at(calc.rem(b, 4)))
  content((10 * w + 10, 40), txt("4 programs"), anchor: "west")
  brace(0, 4 * w, 20, "round 0")
  brace(4 * w, 8 * w, 20, "round 1")
  brace(8 * w, 10 * w, 20, "round 2")

  for p in range(4) { legend(p * 56, -8, "P" + str(p), box-swatch(p * 56, -8, prog-fill.at(p))) }
})

/// Load / compute / store of consecutive iterations, serial vs pipelined.
#let fig-pipeline() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = 36
  let tones = ("blue1", "orange1", "teal1")
  let names = ("L", "C", "S")
  // Stage s of iteration i, starting at time slot t0.
  let step(i, t0, s, y) = seg((t0 + s) * w, (t0 + s + 1) * w, y, tones.at(s), body: names.at(s) + str(i), h: 18)

  content((0, 196), tag("Without pipelining", fill: c.blue), anchor: "west")
  for i in range(3) { for s in range(3) { step(i, i * 3, s, 180) } }
  content((9 * w + 8, 171), txt("3 iterations · 9 slots"), anchor: "west")

  content((0, 146), tag("Software pipelined · num_stages = 3", fill: c.blue), anchor: "west")
  for i in range(5) {
    let y = 130 - i * 22
    for s in range(3) { step(i, i, s, y) }
  }
  content((7 * w + 8, 33), txt("5 iterations · 7 slots"), anchor: "west")
  // One slot in steady state: three iterations, three different stages.
  rect((2 * w - 2, 133), (3 * w + 2, 15), stroke: (paint: c.orange, thickness: .8pt, dash: "dashed"))
  content((5 * w + 8, 121), txt("same slot: load i+2, compute i+1, store i", fill: c.orange), anchor: "west")

  arrow((0, 6), (9 * w + 6, 6))
  content((9 * w + 10, 6), txt("time"), anchor: "west")

  let ly = -10
  legend(0, ly, "Load", box-swatch(0, ly, c.blue1))
  legend(64, ly, "Compute", box-swatch(64, ly, c.orange1))
  legend(146, ly, "Store", box-swatch(146, ly, c.teal1))
})

/// Program ids on a 12 x 8 grid of C blocks: row-major vs grouped ordering.
#let fig-grouped-pid() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h, M, N, G) = (24, 15, 12, 8, 4)
  let group-fill = (c.blue1, c.teal1, c.grey1)
  let grid(x0, pid-of, fill-of, title, sub, note) = {
    content((x0, 42), tag(title, fill: c.blue), anchor: "west")
    content((x0, 28), txt(sub), anchor: "west")
    for m in range(M) {
      for n in range(N) {
        let p = pid-of(m, n)
        let hot = p < 16
        rect(
          (x0 + n * w, -m * h), (x0 + (n + 1) * w, -(m + 1) * h),
          fill: if hot { c.orange2 } else { fill-of(m, n) }, stroke: .5pt + white,
        )
        content((x0 + n * w + w / 2, -m * h - h / 2), txt(str(p), size: 6.5pt, fill: c.ink, weight: if hot { 600 } else { 400 }))
      }
    }
    content((x0, -M * h - 12), txt(note, fill: c.ink), anchor: "west")
  }
  grid(
    0, (m, n) => m * N + n, (m, n) => c.grey1,
    "Row-major", "pid_m = pid // num_pid_n",
    "pid 0–15 read 2 rows of A, 8 cols of B",
  )
  let x1 = 256
  grid(
    x1, (m, n) => calc.quo(m, G) * G * N + n * G + calc.rem(m, G), (m, n) => group-fill.at(calc.quo(m, G)),
    "Grouped · GROUP_SIZE_M = 4", "column-major inside each group",
    "pid 0–15 read 4 rows of A, 4 cols of B",
  )
  for g in range(3) {
    content((x1 + N * w + 6, -(g * G + G / 2) * h), txt("group " + str(g)), anchor: "west")
  }
  legend(0, -M * h - 32, "pid 0–15", box-swatch(0, -M * h - 32, c.orange2))
})
