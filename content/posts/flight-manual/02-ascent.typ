#import "@tola/source:0.0.0": tola-meta
#import "/utils/diagram.typ": diagram, divider, edge, flow, n, node, timeline

#tola-meta((
  title: "[FM 02] Ascent Profile",
  date: "2025-07-04",
  summary: "Part two of a sample series: diagrams and timelines from utils/diagram.typ.",
  tags: ("example", "series", "diagram"),
  series: "Flight Manual",
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
  node("gnd", (0, 0), [Ground]),
  node("relay", (1, 0), [Relay], tone: "accent"),
  node("craft", (2, 0), [Craft], tone: "dark"),
  node("log", (1, 1), [Telemetry log], tone: "muted"),
  edge("gnd", "relay", label: [uplink]),
  edge("relay", "craft"),
  edge("relay", "log", dashed: true),
)

= Timeline

#timeline(
  (version: [T−10], items: ([Pre-flight checks complete],)),
  (version: [T+00], items: ([Liftoff], [Tower cleared]), note: [MAJOR EVENT], major: true),
  (version: [T+02], items: ([Stage separation],)),
)
