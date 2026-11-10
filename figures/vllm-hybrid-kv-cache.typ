// Figures for content/posts/ml-systems/vllm-hybrid-kv-cache.typ, drawn with cetz.
// Numbers are from vLLM's startup log for Qwen3.8-27B at TP=2 with FP8 KV.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, txt

// ============================================================================
// One pool for attention KV and GDN state
// ============================================================================

#let fig-kv-pool() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let page(x, fill, stroke, title, l1, l2) = {
    rect((x, 0), (x + 222, -54), fill: fill, stroke: .8pt + stroke, radius: 3)
    content((x + 10, -12), txt(title, size: 8.5pt, fill: c.ink, weight: 700), anchor: "west")
    content((x + 10, -28), txt(l1, size: 7.5pt), anchor: "west")
    content((x + 10, -42), txt(l2, size: 7.5pt, fill: c.ink, weight: 600), anchor: "west")
  }
  page(0, c.orange1, c.orange, "Attention page, one layer",
    [1568 tokens × 2 KV heads × 256 × (K, V) × 1 B], [1,605,632 B])
  content((246, -27), text(size: 14pt, fill: c.muted, "="))
  page(270, c.teal1, c.teal, "GDN page, one layer",
    [24 heads × 128 × 128 × 4 B + 30 KiB conv state], [1,603,584 B, padded by 0.13%])

  // The pool: one block = one page in each of a group's 16 layers.
  let (w, h, y0) = (16, 18, -96)
  let kinds = ("a",) * 2 + ("g",) * 6 + ("a",) * 7 + ("g",) * 6 + ("f",) * 9
  let gdn = ("G1", "G1", "G2", "G2", "G3", "G3")
  content((0, y0 + 10), txt([Block pool on one GPU. A block is one page in each of a group’s 16 layers: 25.7 MB.], size: 7.5pt, fill: c.ink), anchor: "west")
  let gi = 0
  for (i, k) in kinds.enumerate() {
    let x = i * w
    let (fill, stroke) = if k == "a" { (c.orange1, c.orange) } else if k == "g" { (c.teal1, c.teal) } else { (white, c.grey2) }
    rect((x + .8, y0), (x + w - .8, y0 - h), fill: fill, stroke: .7pt + stroke, radius: 1.5)
    let label = if k == "a" { "A" } else if k == "g" { gdn.at(calc.rem(gi, 6)) } else { none }
    if k == "g" { gi += 1 }
    if label != none { content((x + w / 2, y0 - h / 2), txt(label, size: 6pt, fill: c.ink, weight: 600)) }
  }
  // Which blocks belong to which request.
  let brace(i0, i1, body) = {
    let (xa, xb, y) = (i0 * w + 1, i1 * w - 1, y0 - h - 6)
    line((xa, y + 3), (xa, y), (xb, y), (xb, y + 3), stroke: .6pt + c.line)
    content(((xa + xb) / 2, y - 4), txt(body, size: 7pt), anchor: "north")
  }
  brace(0, 8, [3,000 tokens: 2 + 6 blocks])
  brace(8, 21, [10,000 tokens: 7 + 6 blocks])
  brace(21, 30, [free])

  let ly = y0 - h - 40
  legend(0, ly, [A: the 16 full-attention layers, one block per 1568 tokens], box-swatch(0, ly, c.orange1, stroke: .7pt + c.orange))
  legend(0, ly - 16, [G1–G3: three groups of 16 GDN layers, a fixed number of blocks per sequence], box-swatch(0, ly - 16, c.teal1, stroke: .7pt + c.teal))
})

// ============================================================================
// Layer pattern and per-sequence state of each kind
// ============================================================================

/// 64-layer strip (every fourth layer full attention), then one repeating
/// unit, layers 4-7, with the state each layer keeps for a sequence.
/// Sizes are for the whole model, before TP splits the heads.
#let fig-layer-state() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let is-attn(i) = calc.rem(i, 4) == 3
  let tone(attn) = if attn { (c.orange1, c.orange) } else { (c.teal1, c.teal) }

  // The 64 layers.
  let (x0, w, h) = (14, 8, 14)
  content((x0, 14), txt([Qwen3.8-27B: 64 decoder layers, 48 GDN and 16 full attention], size: 7.5pt, fill: c.ink), anchor: "west")
  for i in range(64) {
    let (fill, stroke) = tone(is-attn(i))
    rect((x0 + i * w + .6, 0), (x0 + (i + 1) * w - .6, -h), fill: fill, stroke: .5pt + stroke, radius: 1)
    if i == 0 or is-attn(i) {
      content((x0 + i * w + w / 2, -h - 7), txt(str(i), size: 5.5pt))
    }
  }
  // Zoom into layers 4-7.
  let (za, zb) = (x0 + 4 * w, x0 + 8 * w)
  rect((za - .4, 1.4), (zb + .4, -h - 1.4), stroke: 1pt + c.ink, radius: 1.5)
  let yd = -62
  line((za, -h - 14), (0, yd + 4), stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed"))
  line((zb, -h - 14), (532, yd + 4), stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed"))

  // One repeating unit: three GDN layers, then one full-attention layer.
  let (cw, gap) = (124, 12)
  for k in range(4) {
    let i = 4 + k
    let attn = is-attn(i)
    let (fill, stroke) = tone(attn)
    let x = k * (cw + gap)
    rect((x, yd), (x + cw, yd - 30), fill: fill, stroke: .8pt + stroke, radius: 3)
    content((x + 8, yd - 10), txt([Layer #i · #if attn [full attention] else [GDN]], size: 8pt, fill: c.ink, weight: 700), anchor: "west")
    content((x + 8, yd - 22), txt(if attn [softmax attention, GQA] else [linear attention], size: 7pt), anchor: "west")

    let ys = yd - 42
    if not attn {
      // Recurrent state S: one 128 x 128 matrix per head, 48 heads.
      for j in range(3) {
        let o = (2 - j) * 4
        rect((x + 8 + o, ys - o), (x + 52 + o, ys - 44 - o), fill: if j == 2 { c.teal2 } else { c.teal1 }, stroke: .6pt + c.teal)
      }
      content((x + 30, ys - 22), txt([S], size: 9pt, fill: c.ink, weight: 700))
      content((x + 66, ys - 4), txt([state S], size: 7pt, fill: c.ink, weight: 600), anchor: "west")
      content((x + 66, ys - 16), txt([48 heads], size: 7pt), anchor: "west")
      content((x + 66, ys - 27), txt([× 128 × 128], size: 7pt), anchor: "west")
      content((x + 66, ys - 38), txt([FP32: *3 MiB*], size: 7pt), anchor: "west")
      // Conv state: the last 3 inputs over 10,240 channels.
      let yc = ys - 60
      for r in range(3) {
        rect((x + 8, yc - r * 3.2), (x + 116, yc - (r + 1) * 3.2), fill: c.teal1, stroke: .4pt + c.teal)
      }
      content((x + 8, yc - 18), txt([conv state: 3 × 10,240], size: 7pt, fill: c.ink, weight: 600), anchor: "west")
      content((x + 8, yc - 29), txt([BF16: *60 KiB*], size: 7pt), anchor: "west")
    } else {
      // K and V: one row per past token, the column grows with the sequence.
      let rows = 7
      let rh = 6.5
      for (j, name) in ("K", "V").enumerate() {
        let xc = x + 8 + j * 24
        content((xc + 10, ys - 4), txt(name, size: 7.5pt, fill: c.ink, weight: 700))
        for r in range(rows) {
          rect((xc, ys - 10 - r * rh), (xc + 20, ys - 10 - (r + 1) * rh), fill: c.orange1, stroke: .4pt + c.orange)
        }
        rect((xc, ys - 10 - rows * rh), (xc + 20, ys - 10 - rows * rh - 26), stroke: (paint: c.grey2, thickness: .6pt, dash: "dashed"))
      }
      arrow((x + 58, ys - 10), (x + 58, ys - 10 - rows * rh - 24), color: c.orange)
      content((x + 66, ys - 4), txt([per token], size: 7pt, fill: c.ink, weight: 600), anchor: "west")
      content((x + 66, ys - 16), txt([4 KV heads], size: 7pt), anchor: "west")
      content((x + 66, ys - 27), txt([× 256 × 2], size: 7pt), anchor: "west")
      content((x + 66, ys - 38), txt([FP8: *2 KiB*], size: 7pt), anchor: "west")
      content((x + 66, ys - 64), txt([grows with], size: 7pt, fill: c.orange), anchor: "west")
      content((x + 66, ys - 75), txt([the sequence], size: 7pt, fill: c.orange), anchor: "west")
    }
  }

  // Totals over the 16 repeating units.
  let yb = yd - 156
  let brace(xa, xb, body) = {
    line((xa, yb + 4), (xa, yb), (xb, yb), (xb, yb + 4), stroke: .6pt + c.line)
    content(((xa + xb) / 2, yb - 5), txt(align(center, body), size: 7.5pt, fill: c.ink), anchor: "north")
  }
  brace(0, 3 * cw + 2 * gap, [× 16 units = 48 GDN layers \ *147 MiB per sequence*, for 100 tokens or 128K])
  brace(3 * (cw + gap), 4 * cw + 3 * gap, [× 16 layers \ *32 KiB per token*])
})
