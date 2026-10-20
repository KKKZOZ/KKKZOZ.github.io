#import "@tola/source:0.0.0": tola-meta
#import "/utils/cetz.typ" as cetz

#tola-meta((
  title: "Mask Alignment Example",
  date: "2026-10-19",
  summary: "Aligning flexible neurons across tokens shrinks the union of activated neurons.",
  tags: ("sparsity", "example"),
))

Token 1 must keep neuron 1; token 2 must keep neuron 2.
Neurons 3 and 4 are *flexible for both*; 5–8 must drop.

#cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let mask-row(x, y, label, mask) = {
    content((x - 12, y + 12), text(13pt, label), anchor: "east")
    for i in range(8) {
      let active = i + 1 in mask
      let flexible = i + 1 in (3, 4)
      rect(
        (x + i * 27, y),
        (x + i * 27 + 24, y + 24),
        fill: if active {
          if flexible { rgb("#8A5B13") } else { rgb("#286379") }
        } else if flexible { rgb("#F5E6CB") } else { rgb("#F0F3F2") },
        stroke: .5pt + rgb("#C5C9BE"),
      )
      content((x + i * 27 + 12, y + 12), text(12pt, fill: if active { white } else { rgb("#65716F") }, str(i + 1)))
    }
  }
  content((105, 108), text(16pt, weight: "bold")[Independent])
  content((460, 108), text(16pt, weight: "bold")[Aligned])
  mask-row(0, 62, [Token 1], (1, 3))
  mask-row(0, 28, [Token 2], (2, 4))
  mask-row(0, -14, [Union], (1, 2, 3, 4))
  mask-row(355, 62, [Token 1], (1, 3))
  mask-row(355, 28, [Token 2], (2, 3))
  mask-row(355, -14, [Union], (1, 2, 3))
  line((235, 42), (270, 42), mark: (end: ">"), stroke: 1.2pt)
  content((105, -38), text(14pt)[4 distinct neurons])
  content((460, -38), text(14pt)[3 distinct neurons])
  for (x, color, label) in (
    (-55, rgb("#286379"), [Must keep]),
    (100, rgb("#8A5B13"), [Flexible: selected]),
    (300, rgb("#F5E6CB"), [Flexible: omitted]),
    (490, rgb("#F0F3F2"), [Must drop]),
  ) {
    rect((x, -75), (x + 13, -62), fill: color, stroke: .5pt + rgb("#C5C9BE"))
    content((x + 20, -68.5), text(11pt, label), anchor: "west")
  }
})

- Prefer flexible neurons already selected by another token.
- Here, each token still keeps two neurons; their masks remain distinct.
