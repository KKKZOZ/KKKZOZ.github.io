// Detailed figures for content/posts/ml-systems/math/probability-and-statistics.typ,
// drawn with cetz. Each `fig-*` function returns one canvas; coordinates are in
// points (1pt per unit, y grows upward) and every figure stays under ~560pt
// wide, so it renders at true scale in the 760px column.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, tag, txt

/// L1 walks the axes, L2 takes the straight line; squaring shrinks small
/// weights and amplifies large ones.
#let fig-l1-l2() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let u = 26
  content((0, 150), tag("one vector, two lengths", fill: c.blue), anchor: "west")
  for i in range(1, 6) { line((i * u, 0), (i * u, 4.5 * u), stroke: .4pt + c.hair) }
  for j in range(1, 5) { line((0, j * u), (5.5 * u, j * u), stroke: .4pt + c.hair) }
  arrow((0, 0), (5.8 * u, 0))
  arrow((0, 0), (0, 4.8 * u))
  content((5.8 * u + 4, 0), text(9pt, $w_1$), anchor: "west")
  content((0, 4.8 * u + 8), text(9pt, $w_2$))
  line((0, 0), (3 * u, 0), (3 * u, 4 * u), stroke: 2pt + c.orange)
  line((0, 0), (3 * u, 4 * u), stroke: 2pt + c.blue)
  circle((3 * u, 4 * u), radius: 2.5, fill: c.ink, stroke: none)
  content((3 * u + 5, 4 * u + 4), text(9pt, $w = (3, 4)$), anchor: "south-west")
  content((1.5 * u, -10), text(9pt, fill: c.orange, $|w_1| = 3$))
  content((3 * u + 5, 2 * u), text(9pt, fill: c.orange, $|w_2| = 4$), anchor: "west")
  content((1.5 * u - 4, 2 * u + 4), text(9pt, fill: c.blue, $5$), anchor: "south-east")
  content((75, -30), text(9pt, fill: c.orange, $norm(w)_1 = |3| + |4| = 7$))
  content((75, -46), text(9pt, fill: c.blue, $norm(w)_2 = sqrt(3^2 + 4^2) = 5$))
  // per-element cost: |w| against w^2
  let (ox, sx, sy) = (320, 34, 26)
  content((ox - 78, 150), tag("cost of one element", fill: c.blue), anchor: "west")
  arrow((ox - 2.3 * sx, 0), (ox + 2.3 * sx, 0))
  arrow((ox, 0), (ox, 4.6 * sy))
  for x in (-2, -1, 1, 2) {
    line((ox + x * sx, 0), (ox + x * sx, -3), stroke: .6pt + c.line)
    content((ox + x * sx, -11), txt(if x < 0 { "−" + str(-x) } else { str(x) }, size: 7pt))
  }
  for x in (-1, 1) {
    line((ox + x * sx, 0), (ox + x * sx, sy), stroke: (paint: c.grey2, dash: "dashed", thickness: .6pt))
  }
  line((ox - 2 * sx, 2 * sy), (ox, 0), (ox + 2 * sx, 2 * sy), stroke: 1.6pt + c.orange)
  line(..range(-20, 21).map(i => (ox + i / 10 * sx, calc.pow(i / 10, 2) * sy)), stroke: 1.6pt + c.blue)
  content((ox + 2 * sx + 5, 4 * sy), text(9pt, fill: c.blue, $w_i^2$), anchor: "west")
  content((ox + 2 * sx + 5, 2 * sy), text(9pt, fill: c.orange, $|w_i|$), anchor: "west")
  content((ox, -30), txt("|w| < 1: squaring shrinks it"))
  content((ox, -46), txt("|w| > 1: squaring amplifies it"))
})

/// The same two groups rank differently under L1 and L2.
#let fig-pruning-groups() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 50
  let groups = (
    ("group A · eight × 0.5", (0.5,) * 8, "4.00", "1.41", 2),
    ("group B · 1.8 + seven × 0.05", (1.8,) + (0.05,) * 7, "2.15", "1.80", 1),
  )
  for (g, (title, ws, l1, l2, low)) in groups.enumerate() {
    let x0 = g * 230
    content((x0, 112), tag(title, fill: c.blue), anchor: "west")
    for (i, v) in ws.enumerate() {
      rect((x0 + i * 18, 0), (x0 + i * 18 + 14, v * s), fill: c.blue2, stroke: .5pt + c.blue)
    }
    content((x0 + if g == 0 { 70 } else { 7 }, ws.at(0) * s + 8), txt(str(ws.at(0)), size: 7pt))
    line((x0 - 4, 0), (x0 + 144, 0), stroke: .7pt + c.line)
    for (y, name, val) in ((-14, 1, l1), (-30, 2, l2)) {
      let pruned = low == name
      content((x0, y), anchor: "west", text(8pt, fill: if pruned { c.danger } else { c.ink })[
        $norm(w)_#name = #val$#if pruned [ · lower, pruned by $L_#name$]
      ])
    }
  }
})

/// P vs Q per outcome, and each outcome's term in the KL sum.
#let fig-kl-example() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let p = (0.5, 0.2, 0.2, 0.1)
  let q = (0.4, 0.3, 0.2, 0.1)
  legend(0, 126, "P · true", box-swatch(0, 126, c.blue2, stroke: .5pt + c.blue))
  legend(84, 126, "Q · predicted", box-swatch(84, 126, c.orange2, stroke: .5pt + c.orange))
  for k in range(4) {
    let x = k * 54
    rect((x, 0), (x + 18, p.at(k) * 200), fill: c.blue2, stroke: .5pt + c.blue)
    rect((x + 20, 0), (x + 38, q.at(k) * 200), fill: c.orange2, stroke: .5pt + c.orange)
    content((x + 9, p.at(k) * 200 + 7), txt(str(p.at(k)), size: 7pt))
    content((x + 29, q.at(k) * 200 + 7), txt(str(q.at(k)), size: 7pt))
    content((x + 19, -10), text(9pt, $x_#(k + 1)$))
  }
  line((-6, 0), (4 * 54 - 10, 0), stroke: .7pt + c.line)
  // contributions P ln(P / Q)
  let (ox, oy) = (260, 40)
  let terms = (0.1116, -0.0811, 0, 0)
  content((ox, 126), text(9pt, $P(x) ln(P(x) \/ Q(x))$), anchor: "west")
  for (k, t) in terms.enumerate() {
    let x = ox + k * 40
    if t != 0 {
      rect((x, oy), (x + 24, oy + t * 400), fill: if t > 0 { c.orange } else { c.teal }, stroke: none)
    }
    let label = if t < 0 { "−" + str(-t) } else { str(t) }
    content((x + 12, oy + t * 400 + if t < 0 { -8 } else { 8 }), txt(label, size: 7pt))
    content((x + 12, -10), text(9pt, $x_#(k + 1)$))
  }
  line((ox - 6, oy), (ox + 4 * 40 - 10, oy), stroke: .7pt + c.line)
  content((ox + 4 * 40, oy + 22), txt("Σ = 0.0305 nats", size: 9pt, fill: c.ink, weight: 600), anchor: "west")
  content((ox + 4 * 40, oy + 6), txt("single terms can be negative,", size: 7pt), anchor: "west")
  content((ox + 4 * 40, oy - 6), txt("the sum never is (KL ≥ 0)", size: 7pt), anchor: "west")
})
