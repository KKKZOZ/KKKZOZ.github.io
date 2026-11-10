// Figures for content/posts/languages/cpp-notes.typ, drawn with cetz.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, c

#let txt(body, size: 9pt, fill: c.muted, weight: 400) = text(size: size, fill: fill, weight: weight, body)
#let head(body, fill: c.ink) = text(size: 9pt, weight: 700, fill: fill, body)

/// `&ctx` is the address of the variable `ctx`, not its (NULL) value.
#let fig-pointer() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, ch) = (120, 24)
  let cell(x, name, ty, value, addr, addr-fill: c.muted) = {
    rect((x, 0), (x + w, -ch), fill: white, stroke: .8pt + c.line)
    content((x + w / 2, -ch / 2), value)
    content((x, 5), txt(name, fill: c.ink, weight: 700) + h(6pt) + txt(ty, size: 8pt), anchor: "south-west")
    content((x, -ch - 5), txt(addr, size: 8pt, fill: addr-fill), anchor: "north-west")
  }
  rect((-12, 46), (346, -50), fill: c.panel, stroke: none, radius: 4pt)
  content((-4, 42), head("STACK", fill: c.muted), anchor: "north-west")
  rect((362, 46), (512, -50), fill: c.panel, stroke: none, radius: 4pt)
  content((370, 42), head("HEAP", fill: c.muted), anchor: "north-west")

  cell(0, "params.ctx", "ggml_context **", txt("0x7fff1234", fill: c.blue, weight: 600), "at 0x7fff1200")
  cell(210, "ctx", "ggml_context *",
    txt(strike[NULL]) + h(8pt) + txt("0x6000a0c0", fill: c.orange, weight: 600),
    "at 0x7fff1234", addr-fill: c.blue)
  cetz.draw.content((437, -12), name: "obj", box(
    fill: c.orange1, stroke: (paint: c.orange, thickness: .8pt, dash: "dashed"), radius: 4pt,
    inset: (x: 7pt, y: 5pt), text(size: 9pt, weight: 600, fill: c.ink, "ggml_context"),
  ))

  arrow((w + 4, -12), (206, -12), color: c.blue, w: .9pt)
  content(((w + 210) / 2, -8), txt("value = &ctx", size: 8pt, fill: c.blue), anchor: "south")
  arrow((334, -12), "obj.west", color: c.orange, w: .9pt, dash: "dashed")
  content((368, -8), txt("after init", size: 8pt, fill: c.orange), anchor: "south")

  content((-12, -64), txt([① `gguf_init_from_file` receives `&ctx`: not NULL, but the address of the variable `ctx` on the stack.], fill: c.ink), anchor: "north-west")
  content((-12, -80), txt([② Inside, `*params.ctx = ggml_init(...)` overwrites `ctx` itself.], fill: c.ink), anchor: "north-west")
})
