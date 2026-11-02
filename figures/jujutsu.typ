// Figures for content/posts/tools/jujutsu.typ, drawn with cetz.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward,
// every figure under ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, tag, txt

#let commit-tones = (
  plain: (white, c.line),
  moved: (c.orange1, c.orange),
  dest: (c.blue1, c.blue),
  ghost: (white, c.grey2),
)

/// A commit dot with its name beside it (`side`: east | west | north | south).
#let commit(pos, label, tone: "plain", side: "east") = {
  import cetz.draw: *
  let (fill, stroke) = commit-tones.at(tone)
  circle(pos, radius: 6, fill: fill, stroke: .9pt + stroke)
  let (off, anc) = (
    east: ((10, 0), "west"), west: ((-10, 0), "east"),
    north: ((0, 10), "south"), south: ((0, -10), "north"),
  ).at(side)
  let ink = if tone == "ghost" { c.muted } else { c.ink }
  content((rel: off, to: pos), txt(label, size: 8.5pt, fill: ink, weight: 600), anchor: anc)
}

/// A parent-child edge; draw edges before commits so the dots sit on top.
#let parent(a, b, dash: none) = cetz.draw.line(a, b, stroke: (paint: c.line, thickness: .8pt, dash: dash))

/// `jj rebase -s M -d O`: M and its descendants move onto O.
#let fig-rebase() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // before
  let (J, K, L, M, N, O) = ((0, 0), (30, 30), (60, 60), (30, 90), (30, 120), (0, 150))
  content((0, 178), tag("before", fill: c.blue), anchor: "west")
  parent(J, K)
  parent(K, L)
  parent(K, M)
  parent(M, N)
  parent(J, O)
  rect((18, 78), (52, 132), stroke: (paint: c.orange, thickness: .7pt, dash: "dashed"), radius: 3)
  content((56, 120), txt("-s M: M and its descendants", fill: c.orange, size: 7pt), anchor: "west")
  commit(J, "J")
  commit(K, "K")
  commit(L, "L")
  commit(M, "M", tone: "moved")
  commit(N, "N", tone: "moved")
  commit(O, "O", tone: "dest")
  content((10, 162), txt("-d O", fill: c.blue, size: 7pt), anchor: "west")

  // the command
  arrow((150, 75), (230, 75))
  content((190, 80), text(size: 7.5pt, raw("jj rebase -s M -d O")), anchor: "south")

  // after
  let x0 = 260
  let at(p) = (x0 + p.at(0), p.at(1))
  let (J, K, L, O, M, N) = (at((0, 0)), at((30, 30)), at((30, 60)), at((0, 90)), at((0, 120)), at((0, 150)))
  content((x0, 178), tag("after", fill: c.blue), anchor: "west")
  parent(J, K)
  parent(K, L)
  parent(J, O)
  parent(O, M)
  parent(M, N)
  commit(J, "J")
  commit(K, "K")
  commit(L, "L")
  commit(O, "O", tone: "dest")
  commit(M, "M'", tone: "moved")
  commit(N, "N'", tone: "moved")

  let ly = -26
  legend(0, ly, "rebased commits", box-swatch(0, ly, c.orange1, stroke: .7pt + c.orange))
  legend(130, ly, "destination", box-swatch(130, ly, c.blue1, stroke: .7pt + c.blue))
})

/// Which commits each range form selects on the linear history R ← A ← … ← E.
#let fig-revsets() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let names = ("R", "A", "B", "C", "D", "E")
  let x(i) = 70 + i * 44
  for (i, n) in names.enumerate() {
    content((x(i), 0), txt(n, size: 9pt, fill: c.ink, weight: 700))
    if i > 0 { arrow((x(i) - 9, 0), (x(i - 1) + 9, 0)) }
  }
  content((x(0), -12), txt("root", size: 6.5pt), anchor: "north")
  content((x(5), -12), txt("newest", size: 6.5pt), anchor: "north")
  let rows = (
    ("B..", 3, 5, "(B, E]"),
    ("B::", 2, 5, "[B, E]"),
    ("..D", 1, 4, "(R, D]"),
    ("::D", 0, 4, "[R, D]"),
    ("B..D", 3, 4, "(B, D]"),
    ("B::D", 2, 4, "[B, D]"),
  )
  for (k, (expr, lo, hi, interval)) in rows.enumerate() {
    let y = -38 - k * 20
    content((0, y), text(size: 8.5pt, raw(expr)), anchor: "west")
    line((x(lo), y), (x(hi), y), stroke: 2.5pt + c.blue2)
    for i in range(6) {
      let inside = i >= lo and i <= hi
      circle((x(i), y), radius: 3.6, fill: if inside { c.blue } else { white }, stroke: .7pt + if inside { c.blue } else { c.grey2 })
    }
    content((x(5) + 22, y), txt(interval, fill: c.ink), anchor: "west")
  }
})

/// Two ways to change an old commit A in A → B → C.
#let fig-resume-edit() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let gap = 46
  let chain(x0, y, labels, tones) = {
    for i in range(1, labels.len()) { parent((x0 + (i - 1) * gap, y), (x0 + i * gap, y)) }
    for (i, l) in labels.enumerate() { commit((x0 + i * gap, y), l, tone: tones.at(i), side: "north") }
  }
  let stage-arrow(y, body) = {
    arrow((190, y), (250, y))
    content((220, y + 4), text(size: 7pt, raw(body)), anchor: "south")
  }

  // jj new A, then jj squash
  content((0, 120), tag("jj new A + jj squash", fill: c.blue), anchor: "west")
  parent((20, 84), (66, 50))
  chain(20, 84, ("A", "B", "C"), ("plain", "plain", "plain"))
  commit((66, 50), "A' (@)", tone: "moved", side: "east")
  content((20, 30), txt("edit in the new change A'; A, B, C untouched"), anchor: "west")
  stage-arrow(84, "jj squash")
  chain(280, 84, ("A + A'", "B'", "C'"), ("moved", "ghost", "ghost"))
  content((280, 62), txt("B, C auto-rebased onto the new A"), anchor: "west")

  // jj edit A
  content((0, -10), tag("jj edit A", fill: c.blue), anchor: "west")
  chain(20, -46, ("A (@)", "B", "C"), ("moved", "plain", "plain"))
  content((20, -68), txt("the working copy is A itself"), anchor: "west")
  stage-arrow(-46, "save files")
  chain(280, -46, ("A*", "B'", "C'"), ("moved", "ghost", "ghost"))
  content((280, -68), txt("A rewritten in place, no separate diff"), anchor: "west")
})
