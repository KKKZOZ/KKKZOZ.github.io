#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": img

#tola-meta((
  title: "Test Mermaid",
  date: "2025-08-13",
  tags: ("Dev",),
  draft: true,
  weight: 0,
))

hi

```mermaid
---
config:
    theme: neutral
---
flowchart TB
   user --> dashboard
   click dashboard "https://github.com/skoblenick/skoblenick/blob/main/README.md" _blank
```

= SVG
#img("/assets/images/mermaid-1.svg")
#link("/assets/images/embeds/a.html")[here]
