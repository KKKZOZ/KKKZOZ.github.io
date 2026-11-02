// Figures for the Sequence Modeling series (content/posts/ml-systems/sequence-modeling/),
// drawn with cetz. One section per post, in series order.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.
// Colours: blue = projections / parameters, orange = recurrent state,
// teal = activations and gates, ink squares = elementwise × / +.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, cells, curve-arrow, legend, line-swatch, pill, seg, tag, txt

// ============================================================================
// Shared pieces
// ============================================================================

/// Math or text label; `fill` defaults to ink.
#let lbl(pos, body, anchor: "center", size: 9pt, fill: c.ink, name: none) = cetz.draw.content(
  pos, txt(body, size: size, fill: fill), anchor: anchor, name: name,
)

/// A small caption line under a part of a figure.
#let note(pos, body, anchor: "north", fill: c.muted, size: 7pt) = cetz.draw.content(
  pos, align(center, txt(body, size: size, fill: fill)), anchor: anchor,
)

/// A rounded box for a whole module (an RNN cell, a layer, ...).
#let mbox(a, b, name: none, fill: c.blue1, stroke: .7pt + c.blue, body: none, size: 8pt) = {
  cetz.draw.rect(a, b, name: name, fill: fill, stroke: stroke, radius: 4)
  if body != none {
    cetz.draw.content(((a.at(0) + b.at(0)) / 2, (a.at(1) + b.at(1)) / 2), txt(body, size: size, fill: c.ink, weight: 600))
  }
}

/// Elementwise × or + (a dark square, as in the usual LSTM diagrams).
#let op(pos, sym, name: none, s: 7) = {
  import cetz.draw: *
  let (x, y) = pos
  rect((x - s, y - s), (x + s, y + s), fill: c.ink, stroke: none, radius: 2, name: name)
  content(pos, text(size: 9pt, weight: 700, fill: white, sym))
}

/// An activation: σ gates are orange, tanh / SiLU are teal.
#let act(pos, body, name: none, gate: false, r: 11) = {
  import cetz.draw: *
  circle(pos, radius: r, fill: if gate { c.orange } else { c.teal }, stroke: none, name: name)
  content(pos, text(size: if gate { 9pt } else { 6.5pt }, weight: 600, fill: white, body))
}

/// A junction dot on a line.
#let junction(pos, color: c.line) = cetz.draw.circle(pos, radius: 1.8, fill: color, stroke: none)

/// A line without a head.
#let wire(..pts, color: c.line, w: .7pt, dash: none) = arrow(..pts, color: color, w: w, dash: dash, head: false)

#let dashed(color) = (paint: color, thickness: .7pt, dash: "dashed")

// ============================================================================
// [01] RNN
// ============================================================================

/// The recurrent cell folded and unrolled: h is the only path between steps.
#let fig-rnn-unroll() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (w, h) = (52, 30)
  let cell(x, name) = mbox((x - w / 2, -h / 2), (x + w / 2, h / 2), name: name, body: "RNN")

  // folded
  cell(26, "f")
  lbl((26, -50), $x_t$)
  arrow((26, -42), "f.south")
  arrow("f.north", (26, 40))
  lbl((26, 48), $y_t$, fill: c.muted)
  curve-arrow((52, 7), (52, -7), (92, 34), (92, -34), color: c.orange, w: 1pt)
  lbl((84, 0), $h$, anchor: "west", fill: c.orange)
  content((128, 6), txt("按 t 展开", size: 7pt), anchor: "south")
  arrow((108, 0), (148, 0), color: c.muted)

  // unrolled
  let xs = (216, 300, 384, 468)
  lbl((164, 4), $h_0$, anchor: "south", fill: c.orange)
  arrow((158, 0), (xs.at(0) - w / 2, 0), color: c.orange, w: 1pt)
  for (i, x) in xs.enumerate() {
    let n = str(i + 1)
    cell(x, "c" + n)
    lbl((x, -50), $x_#n$)
    arrow((x, -42), "c" + n + ".south")
    arrow("c" + n + ".north", (x, 40))
    lbl((x, 48), $y_#n$, fill: c.muted)
    let x1 = if i < xs.len() - 1 { xs.at(i + 1) - w / 2 } else { x + w / 2 + 36 }
    arrow((x + w / 2, 0), (x1, 0), color: c.orange, w: 1pt)
    lbl(((x + w / 2 + x1) / 2, 3), $h_#n$, anchor: "south", size: 8pt, fill: c.orange)
  }

  // one module, called once per step
  let (x0, x1, yb) = (xs.at(0) - w / 2, xs.last() + w / 2, -64)
  line((x0, yb + 4), (x0, yb), (x1, yb), (x1, yb + 4), stroke: dashed(c.blue))
  note(((x0 + x1) / 2, yb - 4), [同一个 module 的 4 次调用：$W_(x h)$、$W_(h h)$、$W_(h y)$ 在所有时间步共享])
  legend(0, yb - 28, "隐藏状态：相邻时间步之间唯一的通道", line-swatch(0, yb - 28, c.orange, w: 1pt))
  legend(250, yb - 28, $y_t$ + "：可选输出", line-swatch(250, yb - 28, c.line))
})

/// One step of the vanilla RNN: two projections, a sum, tanh.
#let fig-rnn-cell() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  rect((52, -58), (372, 80), fill: c.panel, stroke: none, radius: 6)
  content((60, 74), tag("RNN cell · 每个时间步调用一次", fill: c.muted), anchor: "north-west")

  lbl((0, 0), $h_(t-1)$, anchor: "west", fill: c.orange)
  pill((110, 0), $W_(h h)$, name: "whh")
  pill((110, -36), $W_(x h)$, name: "wxh")
  lbl((110, -84), $x_t$)
  arrow((30, 0), "whh.west", color: c.orange, w: 1pt)
  arrow((110, -76), "wxh.south")

  op((190, 0), "+", name: "add")
  arrow("whh.east", "add.west")
  arrow("wxh.east", (190, -36), "add.south")
  lbl((190, 34), $b_h$, size: 8pt)
  arrow((190, 26), "add.north")

  act((256, 0), "tanh", name: "tanh")
  arrow("add.east", "tanh.west")
  note((256, -14), [压到 $[-1, 1]$])

  junction((320, 0), color: c.orange)
  arrow("tanh.east", (420, 0), color: c.orange, w: 1pt)
  lbl((424, 0), $h_t$, anchor: "west", fill: c.orange)
  note((400, -6), "传给 t + 1")

  pill((320, 44), $W_(h y)$, name: "why")
  arrow((320, 0), "why.south", color: c.orange)
  arrow("why.north", (320, 92))
  lbl((320, 100), $y_t$, fill: c.muted)
  note((326, 72), [$+ b_y$], anchor: "west")
})

/// RNN vs Transformer: dependency between positions, and what decoding keeps.
#let fig-rnn-vs-transformer() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let n = 6
  let xs(x0) = range(n).map(i => x0 + 20 + i * 42)

  let panel(x0, title, sub) = {
    content((x0, 48), tag(title, fill: c.ink), anchor: "south-west")
    content((x0, 34), txt(sub, size: 7pt), anchor: "south-west")
  }

  // RNN: a chain, one step per position
  let x0 = 0
  panel(x0, "RNN", [必须等 $h_(t-1)$：6 个位置，6 步])
  for (i, x) in xs(x0).enumerate() {
    let k = str(i + 1)
    lbl((x, -36), $x_#k$, size: 8pt)
    arrow((x, -28), (x, -10))
    rect((x - 11, -9), (x + 11, 9), fill: c.orange1, stroke: .7pt + c.orange, radius: 2, name: "h" + k)
    lbl((x, 0), $h_#k$, size: 7.5pt)
    content((x, 13), txt("step " + k, size: 6pt, fill: c.orange), anchor: "south")
    if i > 0 { arrow("h" + str(i) + ".east", "h" + k + ".west", color: c.orange) }
  }

  // Transformer: every output reads every earlier input at once
  let x0 = 290
  panel(x0, "Transformer", "所有位置一次矩阵乘：1 步")
  let ps = xs(x0)
  for (i, x) in ps.enumerate() {
    for j in range(i + 1) { wire((ps.at(j), -28), (x, -9), color: c.hair, w: .5pt) }
  }
  for (i, x) in ps.enumerate() {
    let k = str(i + 1)
    lbl((x, -36), $x_#k$, size: 8pt)
    rect((x - 11, -9), (x + 11, 9), fill: white, stroke: .7pt + c.blue, radius: 2)
    lbl((x, 0), $o_#k$, size: 7.5pt)
  }
  line((ps.first() - 11, 18), (ps.last() + 11, 18), stroke: .7pt + c.blue)
  content(((ps.first() + ps.last()) / 2, 21), txt("step 1（causal mask 下并行）", size: 6pt, fill: c.blue), anchor: "south")

  // decoding: what has to be kept around at step t
  let yb = -104
  let bars(x0, hs, fill, stroke, body) = {
    let p = xs(x0)
    line((p.first() - 16, yb), (p.last() + 16, yb), stroke: .5pt + c.line)
    for (i, x) in p.enumerate() {
      rect((x - 9, yb), (x + 9, yb + hs.at(i)), fill: fill, stroke: stroke)
      content((x, yb - 3), txt("t=" + str(i + 1), size: 6pt), anchor: "north")
    }
    content((p.first() - 16, yb + 50), txt(body, size: 7pt, fill: c.ink), anchor: "south-west")
  }
  bars(0, range(n).map(_ => 10), c.orange1, .7pt + c.orange, [推理时保存：一个固定大小的 $h_t$，$O(1)$])
  bars(290, range(n).map(i => 7 * (i + 1)), c.blue1, .7pt + c.blue, [推理时保存：KV cache，随 $t$ 线性增长])
})

// ============================================================================
// [02] LSTM
// ============================================================================

/// The LSTM cell: cell state on top (only × and +), hidden state below,
/// four gates reading the concatenation [h_{t-1}, x_t].
#let fig-lstm-cell() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (yc, yg, yh) = (100, 40, 0)
  let (xf, xi, xg, xo, xn) = (120, 170, 220, 280, 370)
  rect((44, -22), (414, 124), fill: c.panel, stroke: none, radius: 10)

  // cell state
  lbl((4, yc + 6), $c_(t-1)$, anchor: "south-west", fill: c.orange)
  arrow((0, yc), (476, yc), color: c.orange, w: 1.2pt)
  lbl((476, yc + 6), $c_t$, anchor: "south-east", fill: c.orange)
  op((xf, yc), "×", name: "mf")
  op((xg, yc), "+", name: "add")
  content((300, yc + 6), txt("细胞状态：只有 × 和 +", size: 7pt, fill: c.orange), anchor: "south")

  // hidden state and the input join
  lbl((4, yh + 6), $h_(t-1)$, anchor: "south-west", fill: c.blue)
  wire((0, yh), (xo, yh), color: c.blue, w: 1.2pt)
  wire((70, -52), (70, yh), color: c.ink, w: 1.2pt)
  line((62, yh), (78, yh), stroke: 1.6pt + c.ink)
  lbl((78, -50), $x_t$, anchor: "west")
  note((70, -58), [拼接 $[h_(t-1), x_t]$])

  // gates
  for x in (xf, xi, xg, xo) { wire((x, yh), (x, yg - 11), color: c.blue) }
  act((xf, yg), "σ", name: "f", gate: true)
  act((xi, yg), "σ", name: "i", gate: true)
  act((xg, yg), "tanh", name: "g")
  act((xo, yg), "σ", name: "o", gate: true)
  for (x, body) in ((xf, [遗忘门 $f_t$]), (xi, [输入门 $i_t$]), (xg, [候选 $tilde(c)_t$]), (xo, [输出门 $o_t$])) {
    note((x, -28), body, fill: c.ink)
  }

  // forget: c_{t-1} * f_t
  arrow("f.north", "mf.south", color: c.teal)
  // write: i_t * c~_t, added to the cell state
  op((xg, 70), "×", name: "mi")
  arrow("g.north", "mi.south", color: c.teal)
  arrow("i.north", (xi, 70), "mi.west", color: c.teal)
  arrow("mi.north", "add.south", color: c.ink)

  // read: h_t = o_t * tanh(c_t)
  junction((xn, yc), color: c.orange)
  act((xn, 70), "tanh", name: "tc", r: 10)
  op((xn, yg), "×", name: "mo")
  arrow((xn, yc), "tc.north", color: c.orange)
  arrow("tc.south", "mo.north", color: c.teal)
  arrow("o.east", "mo.west", color: c.teal)
  arrow("mo.south", (xn, yh), (476, yh), color: c.blue, w: 1.2pt)
  lbl((476, yh + 6), $h_t$, anchor: "south-east", fill: c.blue)
  note((440, yh - 6), "输出，传给 t + 1")

  let ly = -84
  legend(0, ly, "逐元素 × / +", box-swatch(0, ly, c.ink))
  legend(112, ly, "σ：门，值在 [0, 1]", box-swatch(112, ly, c.orange))
  legend(250, ly, "tanh：内容，值在 [-1, 1]", box-swatch(250, ly, c.teal))
})

/// The fused gate projection in the code: one [B, 4H] tensor, chunked in four.
#let fig-lstm-gates() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  lbl((0, 22), $x_t$, anchor: "west")
  note((0, 14), "[B, input]", anchor: "north-west")
  lbl((0, -22), $h_(t-1)$, anchor: "west", fill: c.blue)
  note((0, -30), "[B, H]", anchor: "north-west")
  pill((96, 22), raw("W_ih"), name: "wih")
  pill((96, -22), raw("W_hh"), name: "whh")
  arrow((44, 22), "wih.west")
  arrow((44, -22), "whh.west")
  op((158, 0), "+", name: "add")
  arrow("wih.east", (158, 22), "add.north")
  arrow("whh.east", (158, -22), "add.south")

  let (x0, w) = (196, 76)
  arrow("add.east", (x0, 0))
  let parts = (("forget", "σ", $f_t$, true), ("input", "σ", $i_t$, true), ("output", "σ", $o_t$, true), ("cell", "tanh", $tilde(c)_t$, false))
  for (k, (name, f, out, gate)) in parts.enumerate() {
    let x = x0 + k * w
    seg(x, x + w, 9, if gate { "orange1" } else { "teal1" }, body: name + "_gate", h: 18)
    act((x + w / 2, -44), f, gate: gate, r: 10)
    arrow((x + w / 2, -9), (x + w / 2, -33))
    arrow((x + w / 2, -55), (x + w / 2, -70))
    lbl((x + w / 2, -80), out)
  }
  content((x0 + 2 * w, 14), txt("gates · [B, 4H]", size: 7pt, fill: c.ink), anchor: "south")
  content((x0 - 6, -21), txt("chunk(4, dim=1)", size: 6.5pt, fill: c.muted), anchor: "east")
  note((x0 + 2 * w, -94), "两次 matmul 算出全部 4 组 pre-activation，切开后各过各的激活")
})

/// Backprop through time: RNN multiplies by W_hh^T diag(tanh') each step,
/// the LSTM cell state only by f_t.
#let fig-lstm-gradient() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let xs = (40, 170, 300, 430)
  let row(y, title, sub, stroke, node, lab, ws, factor) = {
    content((0, y + 40), tag(title, fill: c.ink), anchor: "south-west")
    content((0, y + 27), txt(sub, size: 7pt), anchor: "south-west")
    for (i, x) in xs.enumerate() {
      rect((x - 16, y - 10), (x + 16, y + 10), fill: node, stroke: stroke, radius: 2)
      lbl((x, y), lab(i), size: 8pt)
      if i < xs.len() - 1 {
        arrow((x + 16, y), (xs.at(i + 1) - 16, y), color: c.line)
        // the gradient flows back underneath
        let (a, b) = (xs.at(i + 1) - 18, x + 18)
        arrow((a, y - 20), (b, y - 20), color: c.danger, w: ws.at(i) * 1pt)
        content(((a + b) / 2, y - 24), txt(factor(i), size: 6.5pt, fill: c.danger), anchor: "north")
      }
    }
  }
  row(0, "Vanilla RNN", [每回传一步都要乘 $W_(h h)^top dot.op "diag"(tanh')$，连乘后指数衰减或爆炸],
    .7pt + c.blue, c.blue1, i => $h_#i$, (.4, .9, 1.6), i => $times W_(h h)^top dot.op tanh'$)
  row(-110, "LSTM 细胞状态", [$c_t = f_t * c_(t-1) + dots$：沿主干回传只乘 $f_t$，没有矩阵和 $tanh'$；$f_t approx 1$ 时几乎无损],
    .7pt + c.orange, c.orange1, i => $c_#i$, (1.4, 1.4, 1.4), i => $times f_#(i + 1)$)
  legend(0, -160, "前向", line-swatch(0, -160, c.line))
  legend(70, -160, "反向梯度（线宽 ≈ 大小）", line-swatch(70, -160, c.danger, w: 1.2pt))
})

// ============================================================================
// [03] Mamba
// ============================================================================

/// Discretization: a continuous x(t) held constant over each step Δ (ZOH),
/// which turns the ODE into a recurrence over tokens.
#let fig-ssm-zoh() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let f(t) = 34 + 16 * calc.sin(t / 42) + 7 * calc.sin(t / 13 + 1)
  let (t0, d, n) = (30, 64, 6)
  let ts = range(n).map(k => t0 + k * d)

  // axes
  arrow((t0 - 10, 0), (t0 + n * d + 16, 0), color: c.line)
  content((t0 + n * d + 18, 0), txt($t$, size: 8pt), anchor: "west")
  // continuous signal
  line(..range(0, n * d + 1, step: 4).map(t => (t0 + t, f(t))), stroke: (paint: c.muted, thickness: .7pt, dash: "dotted"))
  content((t0 + n * d, f(n * d) + 6), txt([连续 $x(t)$], size: 7pt), anchor: "south-east")
  // zero-order hold
  for (k, t) in ts.enumerate() {
    let v = f(t - t0)
    rect((t, 0), (t + d, v), fill: c.blue1, stroke: none)
    line((t, v), (t + d, v), stroke: 1.2pt + c.blue)
    if k > 0 { line((t, f(t - t0 - d)), (t, v), stroke: .5pt + c.blue) }
    circle((t, v), radius: 2.2, fill: c.blue, stroke: none)
    line((t, 0), (t, -4), stroke: .5pt + c.line)
    content((t + d / 2, v / 2), txt($x_#(k + 1)$, size: 8pt, fill: c.blue), anchor: "center")
  }
  // one step
  let (a, b) = (ts.at(1), ts.at(2))
  line((a, -12), (b, -12), stroke: .6pt + c.orange, mark: (start: "|", end: "|", scale: .5))
  content(((a + b) / 2, -16), txt($Delta$, size: 8pt, fill: c.orange), anchor: "north")
  content((ts.at(3), 74), txt([ZOH：$[t, t + Delta)$ 内输入保持不变], size: 7pt, fill: c.blue), anchor: "south")

  // the recurrence it turns into
  let y = -64
  for (k, t) in ts.enumerate() {
    let x = t + d / 2
    rect((x - 13, y - 9), (x + 13, y + 9), fill: c.orange1, stroke: .7pt + c.orange, radius: 2, name: "h" + str(k))
    content((x, y), txt($h_#(k + 1)$, size: 7.5pt, fill: c.ink))
    arrow((x, -26), (x, y + 9), color: c.blue)
    if k > 0 {
      arrow("h" + str(k - 1) + ".east", "h" + str(k) + ".west", color: c.orange)
      content((x - d / 2, y + 2), txt($macron(A)$, size: 7pt, fill: c.orange), anchor: "south")
    }
  }
  content((ts.at(0) + d / 2 + 4, -34), txt($macron(B) x_t$, size: 7pt, fill: c.blue), anchor: "north-west")
  note((t0 + n * d / 2, y - 16), [$h_t = macron(A) h_(t-1) + macron(B) x_t$，$macron(A) = exp(Delta A)$，$macron(B) = (macron(A) - I) A^(-1) B$], fill: c.ink)
})

/// Selectivity: Δ_t is computed from each token and acts as a forget / write gate.
#let fig-mamba-selective() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let toks = ("The", "cat", ",", "um", "sat", "down", ".")
  let deltas = (1.0, 1.8, .08, .05, 1.5, 1.2, .15)
  let (x0, w) = (90, 64)
  let h = 34
  content((0, 0), txt("token", size: 7pt), anchor: "west")
  content((0, -44), txt($Delta_t$, size: 8pt, fill: c.orange), anchor: "west")
  content((0, -56), txt("步长 / 写入", size: 6.5pt), anchor: "west")
  content((0, -96), txt($macron(A)_t$, size: 8pt, fill: c.blue), anchor: "west")
  content((0, -108), txt("保留旧状态", size: 6.5pt), anchor: "west")
  for (k, (tok, dl)) in toks.zip(deltas).enumerate() {
    let x = x0 + k * w + w / 2
    let small = dl < .5
    pill((x, 0), raw(tok), tone: if small { "muted" } else { "pale" }, size: 7.5pt)
    // Δ_t bar
    let bh = dl / 1.8 * h
    rect((x - 12, -64), (x + 12, -64 + bh), fill: c.orange1, stroke: .7pt + c.orange)
    // Ā_t = exp(Δ A) with A = -1
    let keep = calc.exp(-dl)
    rect((x - 12, -116), (x + 12, -116 + keep * h), fill: c.blue1, stroke: .7pt + c.blue)
    content((x, -119), txt(str(calc.round(keep, digits: 2)), size: 6pt), anchor: "north")
  }
  line((x0, -64), (x0 + toks.len() * w, -64), stroke: .5pt + c.line)
  line((x0, -116), (x0 + toks.len() * w, -116), stroke: .5pt + c.line)
  let xs(k) = x0 + k * w + w / 2
  note(((xs(2) + xs(3)) / 2, -136), [$Delta_t approx 0$：$macron(A)_t approx 1$，$macron(B)_t = Delta_t B_t approx 0$ \ 跳过这个 token，状态原样保留], fill: c.muted)
  note(((xs(4) + xs(5)) / 2, -136), [$Delta_t$ 大：$macron(A)_t$ 变小、$macron(B)_t$ 变大 \ 忘掉旧内容，写入当前 token], fill: c.muted)
  note((xs(0), -136), [$macron(A)_t = exp(Delta_t A)$ \ 图中取 $A = -1$], fill: c.muted)
})

/// The reduction tree of a parallel prefix sum over 8 elements.
#let fig-prefix-scan() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (x0, w, dy) = (110, 62, 46)
  let xs = range(8).map(i => x0 + i * w)
  // (level, first, last): the node covers x_first..x_last
  let node(lv, a, b) = {
    let x = (xs.at(a) + xs.at(b)) / 2
    let body = if a == b { $x_#a$ } else { $x_(#a : #b)$ }
    pill((x, lv * dy), body, name: "n" + str(a) + "-" + str(b), tone: if a == 0 { "orange" } else if lv == 0 { "pale" } else { "blue" }, size: 7.5pt)
  }
  for lv in range(4) {
    let span = calc.pow(2, lv)
    for g in range(calc.div-euclid(8, span)) {
      let (a, b) = (g * span, g * span + span - 1)
      if lv > 0 {
        let h = calc.div-euclid(span, 2)
        let me = "n" + str(a) + "-" + str(b)
        for (p, q) in ((a, a + h - 1), (a + h, b)) {
          arrow("n" + str(p) + "-" + str(q) + ".north", ((xs.at(a) + xs.at(b)) / 2, lv * dy - 9), color: if p == 0 { c.orange } else { c.line })
        }
      }
      node(lv, a, b)
    }
  }
  let rows = ("输入", "第 1 层 · 4 次 ⊕ 并发", "第 2 层 · 2 次 ⊕ 并发", "第 3 层 · 1 次 ⊕")
  for (lv, body) in rows.enumerate() { content((0, lv * dy), txt(body, size: 7pt, fill: c.ink), anchor: "west") }
  note((x0 + 3.5 * w, -18), [串行 $y_t = y_(t-1) + x_t$ 要 7 步；树只要 $log_2 8 = 3$ 层。橙色已经是前缀 $y_0, y_1, y_3, y_7$，\ 其余前缀再做一轮 down-sweep（同样 $O(log N)$ 层）补齐。把 ⊕ 换成 Mamba 的 $times.o$，节点里存的就是 $(A_(i -> j), B_(i -> j))$], fill: c.muted)
})

/// The MambaBlock of the pseudocode, top to bottom.
#let fig-mamba-block() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (xa, xd, xb, xc, xr, xs) = (20, 110, 200, 290, 370, 430)
  let shape(pos, body) = content(pos, txt(body, size: 6.5pt), anchor: "west")
  // zones
  rect((-30, -12), (400, -232), fill: c.panel, stroke: none, radius: 6)
  content((-24, -18), tag("循环外 · 并行：非线性和数据依赖", fill: c.muted), anchor: "north-west")
  rect((-30, -244), (400, -300), fill: c.orange1, stroke: none, radius: 6)
  content((-24, -250), tag("循环内 · 只有逐元素乘加", fill: c.orange), anchor: "north-west")

  lbl((xb, 4), $x$, anchor: "south")
  shape((xb + 8, 10), "[B, L, D]")
  pill((xb, -28), "conv1d", name: "conv")
  shape((xb + 32, -28), "depthwise · causal，补局部上下文")
  pill((xb, -60), "SiLU", name: "silu", tone: "teal")
  arrow((xb, 2), "conv.north")
  arrow("conv.south", "silu.north")

  pill((xb, -108), "x_proj", name: "xp")
  arrow("silu.south", "xp.north")
  shape((xb + 30, -108), [$D -> 1 + 2N$])
  // split into Δ_raw, B, C
  let ys = -136
  wire("xp.south", (xb, ys))
  wire((xd, ys), (xc, ys))
  arrow((xd, ys), (xd, -150))
  arrow((xc, ys), (xc, -258))
  pill((xd, -160), "dt_proj", name: "dt")
  pill((xd, -192), "softplus", name: "sp", tone: "teal")
  arrow("dt.south", "sp.north")
  content((xd + 4, -141), txt($Delta_"raw"$, size: 7pt, fill: c.ink), anchor: "west")
  content((xb + 4, -141), txt($B$, size: 7pt, fill: c.ink), anchor: "west")
  content((xc + 4, -141), txt($C$, size: 7pt, fill: c.ink), anchor: "west")
  shape((xc + 6, -160), "[B, L, N] · 每个 token 一组")

  pill((xa, -160), "A_log", name: "alog", tone: "dark")
  pill((xa, -192), "−exp", name: "nexp")
  arrow("alog.south", "nexp.north")
  shape((xa - 46, -176), "[D, N]")

  // discretize
  rect((-10, -208), (240, -228), fill: white, stroke: .7pt + c.blue, radius: 3)
  content((115, -218), txt([$macron(A) = exp(Delta A)$　　$macron(B) = Delta B$　　[B, L, D, N]], size: 7pt, fill: c.ink))
  arrow("nexp.south", (xa, -208))
  arrow("sp.south", (xd, -208))
  arrow((xb, ys), (xb, -208))

  // selective scan
  rect((-10, -264), (390, -292), fill: white, stroke: .7pt + c.orange, radius: 3, name: "scan")
  content((190, -278), txt([selective scan：$h_t = macron(A)_t dot.o h_(t-1) + macron(B)_t x_t$，$y_t = C_t h_t$], size: 7.5pt, fill: c.ink))
  arrow((115, -228), (115, -264), color: c.blue)
  // x_conv goes to the scan as its input
  arrow("silu.east", (xr, -60), (xr, -264))
  content((xr + 4, -70), txt($x_"conv"$, size: 7pt, fill: c.ink), anchor: "west")

  // skip connection
  op((190, -326), "+", name: "add")
  arrow((190, -292), "add.north", color: c.orange)
  arrow((xb, 2), (xs, 2), (xs, -326), "add.east", color: c.line, dash: "dashed")
  content((xs - 4, -318), txt($D dot.op x$, size: 7pt, fill: c.ink), anchor: "east")
  arrow("add.south", (190, -348))
  lbl((190, -352), "output [B, L, D]", anchor: "north", size: 7.5pt)
})

/// Hardware-aware scan: only the small inputs and y cross HBM; the
/// [B, L, D, N] tensors live in SRAM only.
#let fig-mamba-hw() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // memory levels
  rect((0, 40), (540, 120), fill: c.orange1, stroke: none, radius: 6)
  content((8, 114), tag("SRAM · 小而快 · kernel 内", fill: c.orange), anchor: "north-west")
  rect((0, -70), (540, 10), fill: c.blue1, stroke: none, radius: 6)
  content((8, -64), tag("HBM · 大而慢", fill: c.blue), anchor: "south-west")

  let ins = (($x$, "[B, L, D]"), ($Delta$, "[B, L, D]"), ($A$, "[D, N]"), ($B$, "[B, L, N]"), ($C$, "[B, L, N]"))
  for (i, (name, shape)) in ins.enumerate() {
    let x = 40 + i * 56
    pill((x, -20), name, name: "in" + str(i), tone: "blue", size: 8pt)
    content((x, -34), txt(shape, size: 6pt), anchor: "north")
    arrow("in" + str(i) + ".north", (x, 52), color: c.blue)
  }
  content((270, 22), txt("读一次", size: 6.5pt, fill: c.blue), anchor: "west")

  pill((150, 74), [离散化 $macron(A)_t, macron(B)_t$], name: "disc", tone: "orange", size: 7.5pt)
  pill((320, 74), [scan：$h_t$ 逐步更新], name: "scan", tone: "orange", size: 7.5pt)
  pill((470, 74), [$y_t = C_t h_t$], name: "y", tone: "orange", size: 7.5pt)
  arrow("disc.east", "scan.west", color: c.orange)
  arrow("scan.east", "y.west", color: c.orange)
  content((320, 92), txt("[B, L, D, N] 的中间量只在这里", size: 6.5pt, fill: c.orange), anchor: "south")

  pill((470, -20), $y$, name: "out", tone: "dark", size: 8pt)
  content((470, -34), txt("[B, L, D]", size: 6pt), anchor: "north")
  arrow("y.south", "out.north", color: c.orange)
  content((474, 22), txt("写一次", size: 6.5pt, fill: c.orange), anchor: "west")

  // what is not done
  arrow((330, 58), (330, -10), color: c.grey2, dash: "dashed")
  content((336, -14), txt([不写回 $macron(A), macron(B), h$], size: 6.5pt), anchor: "north-west")
  line((322, 16), (338, 32), stroke: .9pt + c.danger)
  line((322, 32), (338, 16), stroke: .9pt + c.danger)
})

/// Where the non-linearity sits: inside the RNN recurrence, before the Mamba one.
#let fig-mamba-nonlinear() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let loop-box(x0, x1, y) = {
    rect((x0, y - 22), (x1, y + 22), stroke: dashed(c.orange), radius: 4)
    content((x1 - 4, y + 20), txt("循环体", size: 6.5pt, fill: c.orange), anchor: "north-east")
  }

  // RNN
  let y = 0
  content((0, y + 38), tag("RNN / LSTM", fill: c.ink), anchor: "south-west")
  loop-box(60, 380, y)
  lbl((0, y), $h_(t-1)$, anchor: "west", fill: c.orange)
  pill((110, y), $W_(h h)$, name: "w")
  op((190, y), "+", name: "add")
  act((262, y), "tanh", name: "tanh")
  lbl((440, y), $h_t$, anchor: "east", fill: c.orange)
  arrow((32, y), "w.west", color: c.orange)
  arrow("w.east", "add.west")
  arrow("add.east", "tanh.west")
  arrow("tanh.east", (420, y), color: c.orange)
  lbl((190, y - 40), $W_(x h) x_t$, size: 8pt)
  arrow((190, y - 32), "add.south")
  content((262, y - 14), txt("非线性在循环里", size: 6.5pt, fill: c.teal), anchor: "north")

  // Mamba
  let y = -110
  content((0, y + 62), tag("Mamba", fill: c.ink), anchor: "south-west")
  loop-box(60, 380, y)
  lbl((0, y), $h_(t-1)$, anchor: "west", fill: c.orange)
  op((140, y), "×", name: "mul")
  op((250, y), "+", name: "add2")
  lbl((440, y), $h_t$, anchor: "east", fill: c.orange)
  arrow((32, y), "mul.west", color: c.orange)
  arrow("mul.east", "add2.west", color: c.orange)
  arrow("add2.east", (420, y), color: c.orange)
  content((330, y - 14), txt("只有 × 和 +：满足结合律", size: 6.5pt, fill: c.orange), anchor: "north")
  // the parameters come from x_t before the loop
  lbl((0, y + 46), $x_t$, anchor: "west")
  pill((110, y + 46), "Linear · softplus", name: "gen", tone: "teal", size: 7pt)
  arrow((14, y + 46), "gen.west")
  arrow((140, y + 38), (140, y + 7), color: c.teal)
  lbl((146, y + 30), $macron(A)_t$, anchor: "west", size: 8pt, fill: c.teal)
  arrow("gen.east", (250, y + 46), (250, y + 7), color: c.teal)
  lbl((256, y + 30), $macron(B)_t x_t$, anchor: "west", size: 8pt, fill: c.teal)
  content((330, y + 46), txt("非线性在进入循环之前", size: 6.5pt, fill: c.teal), anchor: "west")
})

/// State size: RNN mixes D channels through W_hh; Mamba keeps a D × N state
/// whose rows evolve independently.
#let fig-mamba-state() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (u, d, n, hl) = (10, 6, 8, 2)
  let yt = 0

  // RNN: W_hh @ h
  content((0, yt + 30), tag("RNN", fill: c.ink), anchor: "south-west")
  content((0, yt + 18), txt([$h_t in RR^D$，$W_(h h)$ 混合所有通道], size: 7pt), anchor: "south-west")
  cells((0, yt), d, d, u, u, paint: (r, k) => if r == hl { c.blue2 } else { c.blue1 })
  content((d * u / 2, yt - d * u - 4), txt($W_(h h)$, size: 8pt, fill: c.ink), anchor: "north")
  content((d * u + 10, yt - d * u / 2), txt($dot.op$, size: 10pt, fill: c.ink))
  cells((d * u + 20, yt), d, 1, u, u, paint: (r, k) => c.orange2)
  content((d * u + 25, yt - d * u - 4), txt($h_(t-1)$, size: 8pt, fill: c.orange), anchor: "north")
  content((d * u + 42, yt - d * u / 2), txt($=$, size: 10pt, fill: c.ink))
  cells((d * u + 52, yt), d, 1, u, u, paint: (r, k) => if r == hl { c.orange } else { c.orange1 })
  note((60, yt - d * u - 22), [输出的每个通道 \ 读取全部 $D$ 个通道])

  // Mamba: a D x N state, one row per channel
  let x0 = 210
  content((x0, yt + 30), tag("Mamba", fill: c.ink), anchor: "south-west")
  content((x0, yt + 18), txt([$h_t in RR^(D times N)$，$macron(A)$ 对角：每行只和自己相乘], size: 7pt), anchor: "south-west")
  // x_t[d] feeds row d
  cells((x0, yt), d, 1, u, u, paint: (r, k) => if r == hl { c.blue } else { c.blue1 })
  content((x0 + 5, yt - d * u - 4), txt($x_t$, size: 8pt, fill: c.ink), anchor: "north")
  let xh = x0 + 30
  cells((xh, yt), d, n, u, u, paint: (r, k) => if r == hl { c.orange2 } else { c.orange1 })
  rect((xh, yt - hl * u), (xh + n * u, yt - (hl + 1) * u), stroke: .8pt + c.orange)
  arrow((x0 + u + 2, yt - hl * u - u / 2), (xh - 2, yt - hl * u - u / 2), color: c.blue)
  content((xh + n * u / 2, yt - d * u - 4), txt($h_t$, size: 8pt, fill: c.orange), anchor: "north")
  // brace labels
  content((xh + n * u / 2, yt + 3), txt([$N$ = d_state], size: 6.5pt), anchor: "south")
  content((xh - 4, yt - d * u - 4), txt($D$, size: 6.5pt), anchor: "north-east")
  // C_t reads every row
  let xc = xh + n * u + 22
  content((xc - 11, yt - d * u / 2), txt($dot.op$, size: 10pt, fill: c.ink))
  cells((xc, yt - 20), n, 1, u * .6, u * .6, paint: (r, k) => c.teal1)
  content((xc + 3, yt - 20 - n * u * .6 - 4), txt($C_t$, size: 8pt, fill: c.teal), anchor: "north")
  let xy = xc + 30
  content((xy - 10, yt - d * u / 2), txt($=$, size: 10pt, fill: c.ink))
  cells((xy, yt), d, 1, u, u, paint: (r, k) => if r == hl { c.blue } else { c.blue1 })
  content((xy + 5, yt - d * u - 4), txt($y_t$, size: 8pt, fill: c.ink), anchor: "north")
  note((xh + 80, yt - d * u - 22), [通道 $d$：$h_t [d] = macron(A)_t [d] dot.o h_(t-1) [d] + macron(B)_t [d] x_t [d]$ \ 行与行之间没有交互；跨通道的混合留给循环外的线性层])
})

// ============================================================================
// [04] Linear Attention
// ============================================================================

/// Where the history lives: a growing token list vs a fixed matrix state.
#let fig-la-memory() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let u = 9

  // Transformer: append (k_t, v_t), q_t scores every k_i
  content((0, 46), tag("Transformer", fill: c.ink), anchor: "south-west")
  content((0, 34), txt("历史 = token 列表：每步追加一对 (k, v)", size: 7pt), anchor: "south-west")
  let (x0, n) = (60, 9)
  for (row, y, body) in (("v", 8, $V$), ("k", -14, $K$)) {
    content((x0 - 8, y - u / 2), txt(body, size: 8pt, fill: c.ink), anchor: "east")
    for i in range(n) {
      let last = i == n - 1
      rect((x0 + i * (u + 3), y), (x0 + i * (u + 3) + u, y - u),
        fill: if last { c.orange1 } else if row == "k" { c.blue1 } else { c.teal1 },
        stroke: if last { .7pt + c.orange } else { none })
    }
  }
  let xl = x0 + (n - 1) * (u + 3) + u / 2
  content((xl + 10, -4), txt([追加 $(k_t, v_t)$], size: 6.5pt, fill: c.orange), anchor: "west")
  lbl((x0 + 40, -52), $q_t$, fill: c.blue, name: "q")
  for i in range(n) { wire((x0 + 40, -44), (x0 + i * (u + 3) + u / 2, -14 - u - 1), color: c.hair, w: .5pt) }
  content((x0 + 52, -52), txt([和每个 $k_i$ 打分：显存、读取都随 $t$ 增长], size: 6.5pt), anchor: "west")

  // linear attention: S_t = S_{t-1} + v_t k_t^T, o_t = S_t q_t
  let x1 = 296
  content((x1, 46), tag("Linear attention", fill: c.ink), anchor: "south-west")
  content((x1, 34), txt([历史 = 固定大小的 $S_t in RR^(D_v times D_k)$], size: 7pt), anchor: "south-west")
  let g = 6
  let yt = 14
  cells((x1, yt), g, g, u * .9, u * .9, paint: (r, k) => c.orange1)
  content((x1 + 27, yt - g * u * .9 - 4), txt($S_(t-1)$, size: 8pt, fill: c.orange), anchor: "north")
  content((x1 + 64, yt - 24), txt($+$, size: 10pt, fill: c.ink))
  let xv = x1 + 78
  cells((xv, yt), g, 1, u * .9, u * .9, paint: (r, k) => c.teal1)
  cells((xv + 14, yt), 1, g, u * .9, u * .9, paint: (r, k) => c.blue1)
  content((xv + 4, yt - g * u * .9 - 4), txt($v_t k_t^top$, size: 8pt, fill: c.ink), anchor: "north-west")
  content((xv + 84, yt - 24), txt($=$, size: 10pt, fill: c.ink))
  let xs = xv + 98
  cells((xs, yt), g, g, u * .9, u * .9, paint: (r, k) => c.orange2)
  content((xs + 27, yt - g * u * .9 - 4), txt($S_t$, size: 8pt, fill: c.orange), anchor: "north")
  content((x1, -52), txt([读取 $o_t = S_t q_t$：大小和代价都与 $t$ 无关], size: 6.5pt), anchor: "west")
})

/// Additive write vs delta rule, when a key that is already stored comes back.
#let fig-delta-rule() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let chain(y, title, steps, verdict, good) = {
    content((0, y + 26), tag(title, fill: c.ink), anchor: "south-west")
    let xs = range(steps.len()).map(i => 62 + i * 132)
    let prev = none
    for (i, body) in steps.enumerate() {
      if body == none { continue }
      let last = i == steps.len() - 1
      pill((xs.at(i), y), body, name: "s" + str(i), size: 7pt,
        tone: if not last { "blue" } else if good { "teal" } else { "orange" })
      if prev != none { arrow("s" + str(prev) + ".east", "s" + str(i) + ".west") }
      prev = i
    }
    content((xs.last(), y - 14), txt(verdict, size: 6.5pt, fill: if good { c.teal } else { c.orange }), anchor: "north")
  }
  content((0, 54), txt([状态里已经存了 $k -> v_"old"$，现在同一个 key 带着新值 $v_"new"$ 再次写入（设 $norm(k) = 1$）], size: 7.5pt, fill: c.ink), anchor: "west")
  chain(0, "加法写入 · linear attention", (
    [$S_(t-1) k = v_"old"$], [$S_t = S_(t-1) + v_"new" k^top$], none, [$S_t k = v_"old" + v_"new"$],
  ), [新旧值叠在一起，读不回 $v_"new"$], false)
  chain(-74, "delta rule · DeltaNet", (
    [$"pred" = S_(t-1) k = v_"old"$], [$Delta = v_"new" - "pred"$], [$S_t = S_(t-1) + Delta k^top$], [$S_t k = v_"new"$],
  ), "只写差值：旧值被精确覆盖", true)
})

/// One layer, one token: the Transformer reads a cache, Gated DeltaNet
/// gates, checks and corrects a fixed state before reading it.
#let fig-la-layers() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let u = 9
  let proj(y, xs) = {
    lbl((0, y), $x_t$, anchor: "west")
    for (yy, body) in xs {
      arrow((14, y), (44, yy))
      lbl((50, yy), body, anchor: "west", size: 8pt, fill: c.blue)
    }
  }

  // Transformer
  let y0 = 0
  content((0, y0 + 54), tag("Transformer layer", fill: c.ink), anchor: "south-west")
  proj(y0, ((y0 + 30, $q_t$), (y0, $k_t$), (y0 - 30, $v_t$)))
  let (xk, n) = (96, 8)
  for (yy, fill) in ((y0, c.blue1), (y0 - 30, c.teal1)) {
    for i in range(n) {
      let last = i == n - 1
      rect((xk + i * (u + 2), yy + u / 2), (xk + i * (u + 2) + u, yy - u / 2),
        fill: if last { c.orange1 } else { fill }, stroke: if last { .7pt + c.orange } else { none })
    }
  }
  let xe = xk + n * (u + 2)
  wire((66, y0), (xk - 2, y0), color: c.blue)
  wire((66, y0 - 30), (xk - 2, y0 - 30), color: c.blue)
  content((xk + 40, y0 + 8), txt($K_"past"$, size: 7pt, fill: c.ink), anchor: "south")
  content((xk + 40, y0 - 38), txt($V_"past"$, size: 7pt, fill: c.ink), anchor: "north")
  content((xe + 6, y0 - 15), txt("KV cache：每步追加", size: 6.5pt, fill: c.orange), anchor: "west")
  pill((260, y0 + 30), [$"scores" = q_t K_"past"^top$], name: "sc", size: 7pt)
  pill((372, y0 + 30), "softmax", name: "sm", tone: "teal", size: 7pt)
  pill((462, y0 + 30), [$"weights" dot.op V_"past"$], name: "wv", size: 7pt)
  arrow((64, y0 + 30), "sc.west")
  arrow((xe + 2, y0), (260, y0), "sc.south")
  arrow("sc.east", "sm.west")
  arrow("sm.east", "wv.west")
  arrow((xe + 2, y0 - 30), (462, y0 - 30), "wv.south")
  arrow("wv.east", (540, y0 + 30), color: c.ink)
  lbl((544, y0 + 30), $o_t$, anchor: "west")
  content((372, y0 + 42), txt("1 × t 行权重：显式的 attention map", size: 6.5pt), anchor: "south")

  // Gated DeltaNet
  let y1 = -150
  content((0, y1 + 70), tag("Gated DeltaNet layer", fill: c.ink), anchor: "south-west")
  lbl((0, y1), $S_(t-1)$, anchor: "west", fill: c.orange)
  op((92, y1), "×", name: "g")
  op((448, y1), "+", name: "add")
  arrow((30, y1), "g.west", color: c.orange, w: 1pt)
  arrow("g.east", "add.west", color: c.orange, w: 1pt)
  content((114, y1 + 3), txt($tilde(S)_(t-1)$, size: 7.5pt, fill: c.orange), anchor: "south-west")
  junction((132, y1), color: c.orange)
  arrow((488, y1), (552, y1), color: c.orange, w: 1pt)
  wire("add.east", (488, y1), color: c.orange, w: 1pt)
  junction((488, y1), color: c.orange)
  content((552, y1 + 3), txt($S_t$, size: 7.5pt, fill: c.orange), anchor: "south-east")
  content((552, y1 - 4), txt("→ t + 1", size: 6.5pt), anchor: "north-east")

  // check, correct, write
  let yw = y1 - 42
  pill((186, yw), [$"pred" = tilde(S)_(t-1) k_t$], name: "pred", size: 7pt)
  pill((296, yw), [$Delta_t = v_t - "pred"$], name: "dl", size: 7pt)
  pill((400, yw), [$eta_t dot.op Delta_t k_t^top$], name: "wr", size: 7pt)
  arrow((132, y1), (132, yw), "pred.west", color: c.orange)
  arrow("pred.east", "dl.west")
  arrow("dl.east", "wr.west")
  arrow("wr.east", (448, yw), "add.south")
  content((186, yw + 11), txt("写入前校验", size: 6.5pt, fill: c.orange), anchor: "south")
  content((400, yw + 11), txt("低秩修正写入", size: 6.5pt, fill: c.orange), anchor: "south")

  // read
  pill((488, y1 + 40), [$o_t = S_t q_t$], name: "rd", tone: "orange", size: 7pt)
  arrow((488, y1), "rd.south", color: c.orange)
  content((488, y1 + 52), txt("最终读取", size: 6.5pt, fill: c.orange), anchor: "south")

  // inputs, all projected from x_t
  let yi = yw - 44
  for (x, body, target) in ((92, $g_t$, "g.south"), (186, $k_t$, "pred.south"), (296, $v_t$, "dl.south"), (400, $eta_t$, "wr.south")) {
    lbl((x, yi), body, size: 8pt, fill: c.blue)
    arrow((x, yi + 8), target, color: c.blue)
  }
  lbl((420, y1 + 40), $q_t$, size: 8pt, fill: c.blue, anchor: "east")
  arrow((422, y1 + 40), "rd.west", color: c.blue)
  content((0, yi - 16), txt([$q_t, k_t, v_t$ 和 $g_t, eta_t$ 都由 $x_t$ 投影得到；没有 KV cache，也没有 attention map], size: 6.5pt), anchor: "west")
})

/// Reading for one query: score every key first, or compress first and read once.
#let fig-la-order() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let u = 9
  let ws = (.05, .1, .4, .15, .05, .25)
  let n = ws.len()

  // softmax attention
  content((0, 40), tag("Softmax attention · 先打分", fill: c.ink), anchor: "south-west")
  lbl((0, 0), $q_t$, anchor: "west", fill: c.blue)
  pill((72, 0), [$k_i^top q_t$], name: "dot", size: 7pt)
  arrow((14, 0), "dot.west")
  content((72, -12), txt([$i = 1..t$，共 $t$ 次], size: 6.5pt), anchor: "north")
  pill((158, 0), "softmax", name: "sm", tone: "teal", size: 7pt)
  arrow("dot.east", "sm.west")
  let xa = 206
  arrow("sm.east", (xa - 2, 0))
  for (i, w) in ws.enumerate() {
    rect((xa + i * (u + 2), u / 2), (xa + i * (u + 2) + u, -u / 2), fill: if w > .2 { c.blue } else if w > .08 { c.blue2 } else { c.blue1 }, stroke: none)
  }
  content((xa + n * (u + 2) / 2, 8), txt($alpha_(t, i)$, size: 7pt, fill: c.ink), anchor: "south")
  pill((360, 0), [$sum_i alpha_(t,i) v_i$], name: "sum", size: 7pt)
  arrow((xa + n * (u + 2) + 2, 0), "sum.west")
  arrow("sum.east", (440, 0), color: c.ink)
  lbl((444, 0), $o_t$, anchor: "west")
  content((xa + 33, -12), txt("可单独查看的一行权重", size: 6.5pt), anchor: "north")

  // linear attention
  let y = -84
  content((0, y + 40), tag("Linear attention · 先压缩", fill: c.ink), anchor: "south-west")
  for i in range(3) {
    let o = i * 5
    cells((o, y + 14 - o), 4, 4, u * .8, u * .8, paint: (r, k) => if i == 2 { c.orange1 } else { c.grey1 })
  }
  content((20, y - 26), txt($v_i k_i^top$, size: 7.5pt, fill: c.ink), anchor: "north")
  arrow((52, y), (96, y))
  content((74, y + 3), txt($sum_(i <= t)$, size: 7pt, fill: c.ink), anchor: "south")
  cells((100, y + 14), 4, 4, u * .8, u * .8, paint: (r, k) => c.orange2)
  content((114, y - 26), txt($S_t$, size: 7.5pt, fill: c.orange), anchor: "north")
  pill((210, y), [$S_t q_t$], name: "rd", tone: "orange", size: 7pt)
  arrow((134, y), "rd.west", color: c.orange)
  lbl((210, y + 26), $q_t$, fill: c.blue, size: 8pt)
  arrow((210, y + 18), "rd.north", color: c.blue)
  arrow("rd.east", (440, y), color: c.ink)
  lbl((444, y), $o_t$, anchor: "west")
  content((330, y + 4), txt([$= sum_(i <= t) v_i (k_i^top q_t)$], size: 7.5pt, fill: c.ink), anchor: "south")
  content((330, y - 6), txt("匹配分数还在，但没有 softmax，也不单独生成", size: 6.5pt), anchor: "north")
})
