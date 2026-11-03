// Figures for content/posts/ml-systems/ml-compilers/vllm-torch-compile.typ,
// drawn with cetz. Timelines are schematic: lengths show order, not measured cost.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, pill, tag, txt

// A rectangle with centred text. Tones: blue (compiled / graph-safe),
// orange (Attention / eager boundary), grey (plain), dark (vLLM control).
#let _tones = (
  blue: (c.blue1, c.blue, c.ink),
  orange: (c.orange1, c.orange, c.ink),
  grey: (c.grey1, c.grey2, c.muted),
  teal: (c.teal1, c.teal, c.ink),
  dark: (c.ink, c.ink, white),
  white: (white, c.hair, c.ink),
)
#let _box(a, b, body, tone: "blue", name: none, size: 7pt, weight: 600, radius: 3) = {
  import cetz.draw: *
  let (fill, stroke, ink) = _tones.at(tone)
  rect(a, b, fill: fill, stroke: .7pt + stroke, radius: radius, name: name)
  content((a, 50%, b), align(center, txt(body, size: size, fill: ink, weight: weight)))
}

// ============================================================================
// Transformers backend: FX for structure, AST for the rewrite
// ============================================================================

/// The Transformers backend traces each module class with a custom tracer,
/// matches fusible structures on the FX graph, then rewrites the source.
#let fig-hf-fx() = context cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let steps = (
    ([HF `nn.Module`], [Hugging Face `forward`], "grey"),
    ([`_AllLeafTracer`], [子模块全部视为 leaf \ `_SizedProxy` 处理 shape 解包], "blue"),
    ([`fx.Graph`], [trace 中途失败时 \ 保留 partial graph], "blue"),
    ([`get_fuser()`], [按 module class 匹配 \ vLLM 中对应的 fuser], "blue"),
    ([AST rewrite], [改写 `forward` 源码 \ 并替换 module], "orange"),
  )
  let (w, g, h) = (88, 18, 26)
  let x0(i) = i * (w + g)
  for (i, (body, sub, tone)) in steps.enumerate() {
    _box((x0(i), 0), (x0(i) + w, -h), body, tone: tone, size: 7.5pt)
    content((x0(i) + w / 2, -h - 6), align(center, txt(sub, size: 6.5pt)), anchor: "north")
    if i > 0 { arrow((x0(i) - g + 2, -h / 2), (x0(i) - 2, -h / 2)) }
  }
  // FX is only used to look at the structure; the rewrite happens on source.
  let (a, b) = (x0(1), x0(3) + w)
  line((a, 8), (a, 12), (b, 12), (b, 8), stroke: .7pt + c.blue)
  content(((a + b) / 2, 15), txt("FX：只用于结构匹配", fill: c.blue, weight: 600), anchor: "south")
  let (a, b) = (x0(4), x0(4) + w)
  line((a, 8), (a, 12), (b, 12), (b, 8), stroke: .7pt + c.orange)
  content(((a + b) / 2, 15), txt("真正的修改", fill: c.orange, weight: 600), anchor: "south")

  // matched patterns
  let y = -h - 48
  content((0, y), tag("可融合结构", fill: c.muted), anchor: "west")
  let pats = ([GLU · `gate_proj` + `up_proj`], [QKV · `q/k/v_proj`], [RMSNorm · 按 dataflow 识别], [MoE · router / experts])
  let x = 92
  for p in pats {
    let wd = measure(txt(p, size: 7pt)).width.pt() + 14
    rect((x, y + 8), (x + wd, y - 8), fill: c.panel, stroke: .5pt + c.hair, radius: 8)
    content((x + wd / 2, y), txt(p, size: 7pt, fill: c.ink))
    x += wd + 8
  }
})

// ============================================================================
// Stitching codegen
// ============================================================================

/// Compile time (left): the split graph's pieces go to Inductor, Attention
/// stays a custom op, and codegen.py emits one straight-line function that
/// calls them in order. Run time (right): that function is all that runs.
#let fig-stitching() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (h, bw) = (22, 92)
  let xs = (48, 160, 272)
  let row(y, i, body, tone, name) = _box((xs.at(i) - bw / 2, y), (xs.at(i) + bw / 2, y - h), body, tone: tone, name: name)

  content((0, 22), tag("编译期", fill: c.ink), anchor: "south-west")
  row(0, 1, [split `GraphModule`], "grey", "split")
  row(-44, 0, [subgraph 0], "blue", "s0")
  row(-44, 1, [Attention \ custom op], "orange", "attn")
  row(-44, 2, [subgraph 1], "blue", "s1")
  for t in ("s0", "attn", "s1") {
    arrow("split.south", t + ".north")
  }
  row(-88, 0, [Inductor], "white", "i0")
  row(-88, 2, [Inductor], "white", "i1")
  row(-132, 0, [compiled \ callable 0], "blue", "c0")
  row(-132, 2, [compiled \ callable 1], "blue", "c1")
  arrow("s0.south", "i0.north")
  arrow("s1.south", "i1.north")
  arrow("i0.south", "c0.north")
  arrow("i1.south", "c1.north")
  arrow("attn.south", (xs.at(1), -176), dash: "dashed")
  content((xs.at(1) + 4, -110), txt("不编译，原样调用", size: 6.5pt, fill: c.orange), anchor: "west")

  _box((xs.at(0) - bw / 2, -176), (xs.at(2) + bw / 2, -200), [vLLM stitching codegen（`codegen.py`）：exec() + partial() 绑定 submodules], tone: "dark", name: "codegen")
  arrow("c0.south", (xs.at(0), -176))
  arrow("c1.south", (xs.at(2), -176))
  content((xs.at(1), -206), txt([生成一个 straight-line Python 函数：只决定调用顺序与数据传递，不生成 Tensor kernel], size: 6.5pt), anchor: "north")

  // run time
  let rx = 352
  let rw = 196
  content((rx, 22), tag("运行时 · execution_fn", fill: c.ink), anchor: "south-west")
  rect((rx, 6), (rx + rw, -200), fill: c.panel, stroke: none, radius: 3)
  let calls = (
    ([`x = __vllm_submods__[0](x)`], [Inductor 生成的 Triton / CUDA kernel], "blue"),
    ([`x = unified_attention_with_output(x, …)`], [vLLM Attention backend], "orange"),
    ([`x = __vllm_submods__[1](x)`], [Inductor 生成的 Triton / CUDA kernel], "blue"),
  )
  for (i, (code, what, tone)) in calls.enumerate() {
    let y = -6 - i * 62
    content((rx + 10, y), txt(str(i + 1), size: 8pt, fill: c.orange, weight: 700), anchor: "north-west")
    _box((rx + 24, y), (rx + rw - 10, y - 22), code, tone: tone, size: 6.5pt, weight: 500)
    content((rx + 24, y - 28), txt(what, size: 6.5pt), anchor: "north-west")
    if i < 2 { arrow((rx + 16, y - 14), (rx + 16, y - 56)) }
  }
  content((rx + 10, -192), txt([没有 FX interpreter，也没有 `nn.Module.__call__`], size: 6.5pt), anchor: "west")
  arrow("codegen.east", (rx - 4, -188), color: c.ink)
})

// ============================================================================
// Shape policy
// ============================================================================

/// Top: who decides which dimensions are dynamic. Bottom: how num_tokens is
/// routed once `compile_sizes: [1, 2, 4, 8]` is set.
#let fig-shape-policy() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let parts = (
    ([`dynamic=False`], [关闭 PyTorch 的 \ 自动 dynamic-shape 推断], "grey"),
    ([`mark_dynamic` / `mark_unbacked`], [按 `dynamic_arg_dims` \ 显式标记动态维度], "blue"),
    ([compile ranges · `compile_sizes`], [vLLM 决定 general range \ 与高频 specialization], "blue"),
  )
  let (w, g, h) = (150, 26, 22)
  for (i, (body, sub, tone)) in parts.enumerate() {
    let x = i * (w + g)
    _box((x, 0), (x + w, -h), body, tone: tone, size: 7pt)
    content((x + w / 2, -h - 5), align(center, txt(sub, size: 6.5pt)), anchor: "north")
    if i > 0 { content((x - g / 2, -h / 2), txt("+", size: 11pt, fill: c.muted, weight: 700)) }
  }

  // num_tokens routing
  let y0 = -96
  content((0, y0 + 18), tag("num_tokens 的路由", fill: c.ink), anchor: "west")
  let ticks = (("1", 60), ("2", 100), ("3", 140), ("4", 180), ("8", 240), ("…", 290), ("37", 340), ("…", 400), ("max", 470))
  let X(v) = ticks.find(t => t.at(0) == v).at(1)
  // general kernel spans the whole range
  _box((40, y0), (500, y0 - 18), [general kernel（symbolic shape，覆盖 scheduler 允许的整个 token range）], tone: "white", size: 7pt, weight: 500)
  content((34, y0 - 9), txt("general", size: 6.5pt), anchor: "east")
  // specialized kernels
  let ys = y0 - 34
  content((34, ys - 9), txt("specialized", size: 6.5pt), anchor: "east")
  for v in ("1", "2", "4", "8") {
    _box((X(v) - 16, ys), (X(v) + 16, ys - 18), [size #v], tone: "blue", size: 6.5pt)
  }
  // axis
  let ya = ys - 34
  line((40, ya), (500, ya), stroke: .7pt + c.line, mark: (end: "stealth", fill: c.line, scale: .5))
  for (lab, x) in ticks {
    if lab != "…" { line((x, ya + 3), (x, ya - 3), stroke: .7pt + c.line) }
    content((x, ya - 6), txt(lab, size: 6.5pt, fill: c.ink), anchor: "north")
  }
  content((504, ya), txt("num_tokens", size: 6.5pt), anchor: "west")
  // requests
  let hit(v, y-top, color) = {
    circle((X(v), ya), radius: 2.6, fill: color, stroke: none)
    line((X(v), ya + 3), (X(v), y-top), stroke: (paint: color, thickness: .8pt, dash: "dashed"))
  }
  hit("1", ys - 18, c.orange)
  hit("8", ys - 18, c.orange)
  hit("3", y0 - 18, c.orange)
  hit("37", y0 - 18, c.orange)
  content((270, ya - 22), txt[`1`、`8` 命中 specialized kernel；`3`、`37` 由 general kernel 覆盖], anchor: "north")
})

// ============================================================================
// Compilation lifecycle
// ============================================================================

/// Plain torch.compile compiles on the first call and on guard misses, inside
/// a request; vLLM finishes every compilation and capture before serving.
#let fig-lifecycle() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (lx, h) = (112, 18)
  let seg(x0, x1, y, tone, body) = _box((lx + x0, y), (lx + x1, y - h), body, tone: tone, size: 6.5pt, radius: 2)
  let req(x, y) = _box((lx + x, y), (lx + x + 22, y - h), [req], tone: "grey", size: 6.5pt, weight: 500, radius: 2)

  // plain torch.compile
  let y = 0
  content((0, y - h / 2), txt([普通 `torch.compile`], fill: c.ink, weight: 600), anchor: "west")
  seg(0, 46, y, "grey", [load])
  line((lx + 50, y + 8), (lx + 50, y - h - 8), stroke: (paint: c.ink, thickness: .8pt, dash: "dashed"))
  content((lx + 50, y + 10), txt("开始 serving", size: 6.5pt, fill: c.ink, weight: 600), anchor: "south")
  seg(84, 190, y, "orange", [首个请求：trace + compile])
  req(192, y)
  req(218, y)
  seg(244, 330, y, "orange", [guard miss：重新编译])
  req(332, y)
  req(358, y)
  for x in (84, 244) {
    line((lx + x, y + 4), (lx + x, y + 12), stroke: .7pt + c.danger)
  }
  content((lx + 88, y + 14), txt("请求在这里被阻塞", size: 6.5pt, fill: c.danger), anchor: "south-west")

  // vLLM
  let y = -54
  content((0, y - h / 2), txt("vLLM", fill: c.ink, weight: 600), anchor: "west")
  seg(0, 46, y, "grey", [load])
  seg(48, 104, y, "blue", [Dynamo trace])
  seg(106, 176, y, "blue", [general compile])
  seg(178, 238, y, "blue", [compile_sizes])
  seg(240, 300, y, "teal", [CUDA Graph \ capture])
  line((lx + 304, y + 8), (lx + 304, y - h - 8), stroke: (paint: c.ink, thickness: .8pt, dash: "dashed"))
  content((lx + 304, y + 10), txt("开始 serving", size: 6.5pt, fill: c.ink, weight: 600), anchor: "south")
  for i in range(4) { req(308 + i * 26, y) }
  // cache hit skips the Inductor part
  let (a, b) = (lx + 106, lx + 238)
  line((a, y - h - 4), (a, y - h - 8), (b, y - h - 8), (b, y - h - 4), stroke: .7pt + c.blue)
  content(((a + b) / 2, y - h - 11), txt("cache hit 时直接加载 artifact，跳过 Inductor 编译", size: 6.5pt, fill: c.blue), anchor: "north")
})

// ============================================================================
// Piecewise execution
// ============================================================================

/// Inductor regions replay as CUDA Graphs; Attention runs normally between them.
#let fig-piecewise-exec() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let parts = (
    ([Inductor region], [CUDA Graph replay], "blue", 96),
    ([Attention], [normal / custom], "orange", 64),
    ([Inductor region], [CUDA Graph replay], "blue", 96),
    ([Attention], [normal / custom], "orange", 64),
    ([Inductor region], [CUDA Graph replay], "blue", 96),
  )
  let x = 0
  for (body, sub, tone, w) in parts {
    _box((x, 0), (x + w, -22), body, tone: tone, size: 7pt)
    content((x + w / 2, -28), txt(sub, size: 6.5pt, fill: if tone == "orange" { c.orange } else { c.blue }), anchor: "north")
    x += w + 6
  }
  let x1 = x - 6
  arrow((0, -46), (x1, -46))
  content((x1, -50), txt("forward 的执行顺序", size: 6.5pt), anchor: "north-east")
})

// ============================================================================
// CUDA Graph dispatch
// ============================================================================

/// Three inputs decide, per batch, which execution path the dispatcher takes.
#let fig-dispatch() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let ins = (
    ([compiler decision], [哪些 op 属于 safe region]),
    ([runtime batch info], [batch 组成、token 数、mode]),
    ([CUDA Graph availability], [有没有可 replay 的 graph]),
  )
  let (iw, ih) = (118, 22)
  for (i, (body, sub)) in ins.enumerate() {
    let y = -i * 46
    _box((0, y), (iw, y - ih), body, tone: "white", size: 7pt, name: "in" + str(i))
    content((iw / 2, y - ih - 3), txt(sub, size: 6.5pt), anchor: "north")
  }
  let (dx, dy) = (160, -46)
  _box((dx, dy + 14), (dx + 104, dy - 14 - ih), [`CudagraphDispatcher`], tone: "dark", size: 7pt, name: "disp")
  for i in range(3) {
    let y = -i * 46 - ih / 2
    arrow((iw + 2, y), (dx - 2, dy - ih / 2 + (1 - i) * 12))
  }

  // outcomes, each with what it replays
  let ox = 312
  let outs = (
    ([`FULL`], ((none, "blue", 220),), [整个模型（含 Attention）一次 replay]),
    ([`PIECEWISE`], ((none, "blue", 56), (none, "orange", 22), (none, "blue", 56), (none, "orange", 22), (none, "blue", 56)), [safe region replay，Attention 在边界处执行]),
    ([eager fallback], ((none, "grey", 220),), [没有匹配的 graph：普通执行]),
  )
  for (i, (name, segs, note)) in outs.enumerate() {
    let y = 4 - i * 46
    content((ox, y), txt(name, size: 7pt, fill: c.ink, weight: 600), anchor: "north-west")
    let x = ox
    for (_, tone, w) in segs {
      let (fill, stroke, _) = _tones.at(tone)
      rect((x, y - 14), (x + w, y - 26), fill: fill, stroke: .6pt + stroke, radius: 2)
      x += w + 2
    }
    content((ox, y - 30), txt(note, size: 6.5pt), anchor: "north-west")
    arrow((dx + 106, dy - ih / 2 + (1 - i) * 10), (ox - 6, y - 20))
  }
  content((ox + 120, -142), txt([`FULL_AND_PIECEWISE`：两条路径都准备，运行时按 batch 选择], size: 6.5pt), anchor: "north")
})
