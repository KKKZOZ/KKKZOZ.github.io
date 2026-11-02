// Detailed figures for content/posts/ml-systems/qwen3-5.typ, drawn with cetz.
// Each `fig-*` function returns one canvas; coordinates are in points
// (1pt per unit, y grows upward) and every figure stays under ~560pt wide,
// so it renders at true scale in the 760px column.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, cells, legend, pill, txt

/// A circled operator: residual add or elementwise product.
#let op(pos, sym) = {
  import cetz.draw: *
  circle(pos, radius: 7, fill: white, stroke: .7pt + c.ink)
  content(pos, txt(sym, size: 9pt, fill: c.ink, weight: 600))
}

/// A rectangle from `a` to `b` holding a few centred lines of text.
#let block(a, b, lines, bg: c.blue1, edge: c.blue) = {
  import cetz.draw: *
  rect(a, b, fill: bg, stroke: .7pt + edge, radius: 3)
  let (cx, cy) = ((a.at(0) + b.at(0)) / 2, (a.at(1) + b.at(1)) / 2)
  for (i, l) in lines.enumerate() {
    content((cx, cy + (lines.len() - 1) * 5.5 - i * 11), l)
  }
}

// ============================================================================
// Overview and decoder layer
// ============================================================================

/// Embedding -> three linear layers and one full layer, repeated -> norm -> lm_head.
#let fig-hybrid-stack() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  pill((34, 0), "Embedding", name: "emb", tone: "dark")
  content((34, -20), txt("[B, T] → [B, T, H]", size: 7pt))
  arrow("emb.east", (80, 0))
  for i in range(8) {
    let full = calc.rem(i + 1, 4) == 0
    let x = 84 + i * 34
    rect((x, -12), (x + 30, 12), fill: if full { c.orange1 } else { c.teal1 }, stroke: .7pt + if full { c.orange } else { c.teal }, radius: 3)
    content((x + 15, 0), txt(if full { "full" } else { "lin" }, fill: c.ink, weight: 600))
    content((x + 15, -20), txt(str(i + 1), size: 7pt))
  }
  content((366, 0), txt("…", size: 10pt, fill: c.ink))
  content((366, -20), txt("L", size: 7pt))
  arrow((378, 0), (400, 0))
  pill((426, 0), "RMSNorm", name: "norm")
  arrow("norm.east", (472, 0))
  pill((500, 0), "lm_head", name: "head", tone: "orange")
  content((500, -20), txt("logits", size: 7pt))
  line((84, 18), (84, 24), (220, 24), (220, 18), stroke: .7pt + c.blue)
  content((152, 34), txt("repeating unit · full_attention_interval = 4", fill: c.blue))
  legend(84, -44, "linear_attention · Gated DeltaNet", box-swatch(84, -44, c.teal1, stroke: .7pt + c.teal))
  legend(310, -44, "full_attention · gated attention", box-swatch(310, -44, c.orange1, stroke: .7pt + c.orange))
})

/// Pre-Norm decoder layer: two residual connections, mixer picked per layer.
#let fig-decoder-layer() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  content((0, 0), txt("x", size: 10pt, fill: c.ink, weight: 700))
  pill((62, 0), "RMSNorm", name: "n1")
  pill((162, 0), "token mixer", name: "mix", tone: "pale")
  op((240, 0), "+")
  pill((312, 0), "RMSNorm", name: "n2")
  pill((404, 0), "SwiGLU MLP", name: "mlp", tone: "pale")
  op((474, 0), "+")
  content((504, 0), txt("y", size: 10pt, fill: c.ink, weight: 700))
  arrow((7, 0), "n1.west")
  arrow("n1.east", "mix.west")
  arrow("mix.east", (233, 0))
  arrow((247, 0), "n2.west")
  arrow("n2.east", "mlp.west")
  arrow("mlp.east", (467, 0))
  arrow((481, 0), (496, 0))
  content((62, -16), txt("input_layernorm", size: 7pt))
  content((312, -16), txt("post_attention_layernorm", size: 7pt))
  // residual paths
  circle((18, 0), radius: 1.6, fill: c.line, stroke: none)
  arrow((18, 0), (18, 30), (240, 30), (240, 7))
  circle((256, 0), radius: 1.6, fill: c.line, stroke: none)
  arrow((256, 0), (256, 30), (474, 30), (474, 7))
  content((129, 38), txt("residual", style: "italic"))
  content((365, 38), txt("residual", style: "italic"))
  // which mixer a layer gets
  arrow("mix.south", (162, -34), head: false)
  arrow((110, -34), (214, -34), head: false)
  arrow((110, -34), (110, -46))
  arrow((214, -34), (214, -46))
  pill((110, -54), "Gated DeltaNet", tone: "teal")
  pill((214, -54), "Gated Attention", tone: "orange")
  content((110, -72), txt("3 of every 4 layers", size: 7pt))
  content((214, -72), txt("every 4th layer", size: 7pt))
  content((162, -88), txt("chosen by layer_types[i]"))
})

// ============================================================================
// Linear attention
// ============================================================================

/// Gated DeltaNet: four projections, causal conv, gates, recurrent state S, output gate.
#let fig-gdn-flow() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  content((0, -55), txt("x", size: 10pt, fill: c.ink, weight: 700))
  arrow((6, -55), (12, -55), head: false)
  arrow((12, 0), (12, -110), head: false)
  for (y, name, id) in ((0, "in_proj_qkv", "pq"), (-40, "in_proj_b", "pb"), (-70, "in_proj_a", "pa"), (-110, "in_proj_z", "pz")) {
    pill((56, y), name, name: id, size: 7.5pt)
    arrow((12, y), id + ".west")
  }
  // q / k / v
  pill((152, 0), "Conv1d + SiLU", name: "conv", tone: "teal")
  content((152, -16), txt("cache: conv_states", size: 7pt, fill: c.orange))
  pill((258, 0), "split + L2 norm", name: "split")
  arrow("pq.east", "conv.west")
  arrow("conv.east", "split.west")
  arrow("split.east", (318, 0))
  // gates
  pill((152, -40), $beta = sigma(b)$, name: "beta")
  arrow("pb.east", "beta.west")
  arrow("beta.east", (318, -40))
  pill((152, -70), "decay g", name: "g")
  content((152, -86), txt("−exp(A_log) · softplus(a + dt_bias)", size: 6.5pt))
  arrow("pa.east", "g.west")
  arrow("g.east", (318, -70))
  // the recurrent core
  rect((318, -84), (422, 12), fill: c.blue1, stroke: .7pt + c.blue, radius: 3)
  content((370, 2), txt("gated delta rule", fill: c.ink, weight: 600))
  cells((352, -12), 4, 4, 9, 9, paint: (r, k) => c.orange2)
  content((370, -30), txt("S", size: 10pt, fill: c.ink, weight: 700))
  content((370, -58), txt("[Nv, Dk, Dv]", size: 7pt))
  content((370, -72), txt("chunk / recurrent", size: 7pt))
  content((370, 22), txt("cache: recurrent_states", size: 7pt, fill: c.orange))
  // output gate and projection
  pill((472, -36), "gated RMSNorm", name: "norm", tone: "teal")
  arrow((422, -36), "norm.west")
  arrow("pz.east", (472, -110), "norm.south")
  content((300, -104), txt("z", size: 9pt, fill: c.ink, weight: 700))
  pill((472, 2), "out_proj", name: "out")
  arrow("norm.north", "out.south")
  arrow("out.north", (472, 24))
  content((472, 32), txt("y", size: 10pt, fill: c.ink, weight: 700))
})

// ============================================================================
// Full attention
// ============================================================================

/// q_proj emits [query | gate] per head; chunk splits each head's last dim.
#let fig-q-gate() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let w = 22
  content((97, 40), txt("q_proj(x).view(B, T, Nq, 2D)", fill: c.ink, weight: 600))
  for h in range(4) {
    let x = h * 50
    rect((x, -10), (x + w, 10), fill: c.blue1, stroke: .5pt + c.blue)
    content((x + w / 2, 0), text(9pt, $q_#h$))
    rect((x + w, -10), (x + 2 * w, 10), fill: c.orange1, stroke: .5pt + c.orange)
    content((x + 1.5 * w, 0), text(9pt, $g_#h$))
    content((x + w, 20), txt("head " + str(h), size: 7pt))
  }
  arrow((204, 0), (250, 16))
  arrow((204, 0), (250, -16))
  content((227, 30), txt("chunk(2, -1)", size: 7pt))
  for h in range(4) {
    let x = 258 + h * w
    rect((x, 6), (x + w, 26), fill: c.blue1, stroke: .5pt + c.blue)
    content((x + w / 2, 16), text(9pt, $q_#h$))
    rect((x, -26), (x + w, -6), fill: c.orange1, stroke: .5pt + c.orange)
    content((x + w / 2, -16), text(9pt, $g_#h$))
  }
  content((354, 16), txt("query_states [B, T, Nq, D]", fill: c.ink), anchor: "west")
  content((354, -16), txt("gate → [B, T, Nq·D]", fill: c.ink), anchor: "west")
  content((97, -26), txt("each head carries its own query and gate"))
})

/// GQA: one K/V head serves a group of query heads.
#let fig-gqa() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  for g in range(2) {
    let (bg, edge) = if g == 0 { (c.blue1, c.blue) } else { (c.orange1, c.orange) }
    let kx = g * 120 + 58
    for j in range(4) {
      let x = g * 120 + j * 30
      arrow((kx, 20), (x + 13, 60), head: false)
      rect((x, 60), (x + 26, 80), fill: bg, stroke: .5pt + edge)
      content((x + 13, 70), text(9pt, $q_#(g * 4 + j)$))
    }
    rect((kx - 16, 0), (kx + 16, 20), fill: bg, stroke: .5pt + edge)
    content((kx, 10), text(9pt, $"kv"_#g$))
  }
  content((250, 70), txt("query heads · Nq = 8", fill: c.ink), anchor: "west")
  content((250, 40), txt("repeat_kv: each K/V head serves Nq / Nkv = 4", fill: c.blue), anchor: "west")
  content((250, 10), txt("K/V heads · Nkv = 2 · what the cache stores", fill: c.ink), anchor: "west")
})

/// Full attention: gated query, Q/K norm, partial RoPE, KV cache, GQA, output gate.
#let fig-full-attn-flow() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  content((0, -30), txt("x", size: 10pt, fill: c.ink, weight: 700))
  arrow((6, -30), (12, -30), head: false)
  arrow((12, 15), (12, -90), head: false)
  block((22, -10), (82, 40), (txt("q_proj", fill: c.ink, weight: 600),), bg: white)
  arrow((12, 15), (22, 15))
  pill((52, -50), "k_proj", name: "kp")
  arrow((12, -50), "kp.west")
  pill((52, -90), "v_proj", name: "vp")
  arrow((12, -90), "vp.west")
  // query
  pill((122, 0), "q_norm", name: "qn", tone: "teal")
  pill((184, 0), "RoPE", name: "qr")
  arrow((82, 0), "qn.west")
  arrow("qn.east", "qr.west")
  arrow("qr.east", (400, 0))
  content((300, 8), txt("Nq heads", size: 7pt))
  // key / value
  pill((122, -50), "k_norm", name: "kn", tone: "teal")
  pill((184, -50), "RoPE", name: "kr")
  arrow("kp.east", "kn.west")
  arrow("kn.east", "kr.west")
  arrow("kr.east", (230, -50))
  arrow("vp.east", (230, -90))
  block((230, -104), (300, -36), (txt("KV cache", fill: c.ink, weight: 600), txt("append", size: 7pt)), bg: c.orange1, edge: c.orange)
  content((265, -26), txt("cache: keys, values", size: 7pt, fill: c.orange))
  content((265, -114), txt("Nkv heads, grows with T", size: 7pt))
  arrow((300, -50), (320, -50))
  arrow((300, -90), (320, -90))
  block((320, -104), (380, -36), (txt("repeat_kv", fill: c.ink, weight: 600),), bg: white)
  content((350, -114), txt("Nkv → Nq", size: 7pt))
  arrow((380, -50), (400, -50))
  arrow((380, -90), (400, -90))
  block((400, -104), (470, 12), (txt("causal", fill: c.ink, weight: 600), txt("attention", fill: c.ink, weight: 600), txt("SDPA / FA", size: 7pt)))
  // output gate
  op((495, -46), "×")
  arrow((470, -46), (488, -46))
  arrow((82, 30), (495, 30), (495, -39))
  content((300, 38), txt("gate", size: 7pt))
  content((500, 0), txt("σ(gate)", size: 7pt), anchor: "west")
  pill((535, -46), "o_proj", name: "o")
  arrow((502, -46), "o.west")
  arrow("o.south", (535, -76))
  content((535, -86), txt("y", size: 10pt, fill: c.ink, weight: 700))
})

/// Per-layer cache size: fixed for linear layers, growing with T for full layers.
#let fig-cache-growth() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  arrow((30, 0), (360, 0), head: false)
  arrow((30, 0), (30, 150))
  content((30, 160), txt("cache per layer"))
  for i in range(8) {
    let full = calc.rem(i + 1, 4) == 0
    let x = 44 + i * 40
    if full {
      rect((x, 0), (x + 28, 60), fill: c.orange1, stroke: .7pt + c.orange)
      rect((x, 60), (x + 28, 132), stroke: (paint: c.grey2, thickness: .7pt, dash: "dashed"))
      arrow((x + 14, 66), (x + 14, 124), color: c.orange)
    } else {
      rect((x, 0), (x + 28, 26), fill: c.teal1, stroke: .7pt + c.teal)
      rect((x, 26), (x + 28, 32), fill: c.teal2, stroke: .7pt + c.teal)
    }
    content((x + 14, -10), txt(str(i + 1), size: 7pt))
  }
  content((372, 96), txt("full: keys + values", fill: c.ink), anchor: "west")
  content((372, 82), txt("grows linearly with T", fill: c.orange), anchor: "west")
  content((372, 32), txt("linear: conv_states + S", fill: c.ink), anchor: "west")
  content((372, 18), txt("fixed, independent of T", fill: c.blue), anchor: "west")
})

// ============================================================================
// FFN
// ============================================================================

/// SwiGLU MLP: down_proj(silu(gate_proj(x)) * up_proj(x)).
#let fig-swiglu() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  content((0, 30), txt("x", size: 10pt, fill: c.ink, weight: 700))
  arrow((6, 30), (14, 30), head: false)
  arrow((14, 0), (14, 60), head: false)
  pill((66, 60), "gate_proj", name: "gate")
  content((66, 76), txt("H → I", size: 7pt))
  pill((66, 0), "up_proj", name: "up")
  content((66, -16), txt("H → I", size: 7pt))
  arrow((14, 60), "gate.west")
  arrow((14, 0), "up.west")
  pill((150, 60), "SiLU", name: "silu", tone: "teal")
  arrow("gate.east", "silu.west")
  op((200, 30), "⊙")
  arrow("silu.east", (200, 60), (200, 37))
  arrow("up.east", (200, 0), (200, 23))
  pill((262, 30), "down_proj", name: "down")
  content((262, 46), txt("I → H", size: 7pt))
  arrow((207, 30), "down.west")
  arrow("down.east", (330, 30))
  content((338, 30), txt("y", size: 10pt, fill: c.ink, weight: 700))
})
