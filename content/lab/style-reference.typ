#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout, gallery, hint, img, related, xref

#tola-meta((
  title: "Style Reference",
  date: "2026-10-18",
  summary: "Every element the template styles, on one page.",
))

= Typography

Body text is IBM Plex Mono; headings are Rajdhani. *Strong text* takes the
emphasis color and _emphasis_ goes blue. Bold italic turns teal
whichever way it is nested: *_strong then emph_* and _*emph then strong*_.
Links look like #link("https://typst.app")[this], inline code like `tola serve`.

== Lists

- Prefer flexible neurons already selected by another token.
- Keep must-keep neurons fixed.

+ Collect per-token masks.
+ Align flexible slots.
+ Take the union.

== Math

Inline $a^2 + b^2 = c^2$ sits on the baseline, and display math is centered:

$ sum_(i=1)^n |m_i| >= |union.big_(i=1)^n m_i| $

= Blocks

#callout[Callouts default to *note*.]
#callout(kind: "info")[Neutral context with _emphasis_.]
#callout(kind: "warning")[Check the cache before trusting latency numbers.]
#callout(kind: "success", title: [GO FOR LAUNCH])[Custom titles keep the code tag.]
#callout(kind: "danger")[Do not mutate the shared mask in place.]

#hint[An open engineering annotation: *key term* and _aside_ in mono italic.]

#quote(block: true)[A plain blockquote for citations.]

```python
def union(masks):
    return set().union(*masks)
```

= Links Between Posts

Plain Typst links work with any site path:
#link("/posts/ml-systems/mask-alignment/")[the mask example]. To link a post by its title,
use `xref` with a permalink or the last segment of one: #xref("mask-alignment"). Override the
text with `body`: #xref("mask-alignment", body: [this figure]).
Tola checks these links at build time, and `xref` fails loudly if the post is missing.

```typst
#import "/utils/ui.typ": xref, related
#xref("mask-alignment")
#related("mask-alignment", "/posts/ml-systems/ml-compilers/overview/")
```

#related("mask-alignment", "overview")

= Images

Put files under `assets/images/` and reference them site-absolute. `img`
emits a real `<img>` tag; Typst's own `image()` would inline the file as base64.

#img(
  "/assets/images/telemetry.png",
  alt: "Three decaying telemetry curves on a dark grid",
  caption: [Full column width with a caption.],
)

#img("/assets/images/telemetry.png", alt: "Telemetry curves", width: "55%", caption: [`width: "55%"` centers a smaller figure.])

#gallery(
  columns: 2,
  caption: [`gallery` places images side by side, with optional per-image labels.],
  ("/assets/images/telemetry.png", "Channel A"),
  ("/assets/images/telemetry.png", "Channel B"),
)

#img("/assets/images/telemetry.png", alt: "Telemetry curves", bleed: true, caption: [`bleed: true` extends past the text column on wide screens.])

```typst
#import "/utils/ui.typ": img, gallery
#img("/assets/images/x.png", alt: "...", caption: [...], width: "60%")
#gallery(columns: 3, "/assets/images/a.png", ("/assets/images/b.png", "Label"))
```

= Table

#table(
  columns: 3,
  table.header[Strategy][Neurons][Note],
  [Independent], [4], [Each token picks freely],
  [Aligned], [3], [Shares flexible slots],
  [Oracle], [2], [_Lower bound_],
)
