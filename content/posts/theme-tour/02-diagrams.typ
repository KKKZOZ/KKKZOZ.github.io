#import "@tola/source:0.0.0": tola-meta
#import "/utils/diagram.typ": diagram, divider, edge, flow, n, node, timeline

#tola-meta((
  title: "[Tour 02] Diagrams and Timelines",
  date: "2025-07-04",
  summary: "Part two of a sample series: diagrams and timelines from utils/diagram.typ.",
  tags: ("example", "series", "diagram"),
  series: "Theme Tour",
))

Diagrams are drawn by Typst at build time and embedded as inline SVG. Their
colors come from the theme palette, so they follow the day / night switch.

= Flow

A chain of nodes. Content between two nodes labels the edge; `divider` draws
a boundary across the flow.

#flow(
  n([Source], sub: [`content/*.typ`]),
  [tola-meta],
  n([Site program], sub: [`site.typ`], tone: "accent"),
  divider[Typst][Output],
  n([HTML pages], sub: [`public/`], tone: "dark"),
  [build hook],
  n[Search index],
)

```typst
#import "/utils/diagram.typ": flow, n, divider
#flow(n[Source], [label], n([Site program], tone: "accent"), divider[A][B], n[HTML])
```

= Diagram

Nodes on a grid, joined by edges.

#diagram(
  node("repo", (0, 0), [Repo]),
  node("ci", (1, 0), [CI], tone: "accent"),
  node("pages", (2, 0), [Pages], tone: "dark"),
  node("log", (1, 1), [Build log], tone: "muted"),
  edge("repo", "ci", label: [push]),
  edge("ci", "pages"),
  edge("ci", "log", dashed: true),
)

= Timeline

#timeline(
  (version: [0.1], items: ([First layout],)),
  (version: [1.0], items: ([Search], [Night theme]), note: [RELEASE], major: true),
  (version: [1.1], items: ([Series navigation],)),
)
