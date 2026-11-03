// Figures for content/posts/tools/git-essentials.typ, drawn with cetz.
// Commit graphs run left to right (older on the left); hashes are the ones
// used in the post's examples.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, curve-arrow, legend, tag, txt

#let _tones = (
  blue: (c.blue1, c.blue, c.ink),
  orange: (c.orange1, c.orange, c.ink),
  teal: (c.teal1, c.teal, c.ink),
  grey: (c.grey1, c.grey2, c.muted),
  white: (white, c.hair, c.ink),
  dark: (c.ink, c.ink, white),
  danger: (c.orange1, c.danger, c.danger),
)

/// A rectangle with centred text.
#let _box(a, b, body, tone: "white", name: none, size: 7pt, weight: 600, radius: 3, dash: none) = {
  import cetz.draw: *
  let (fill, stroke, ink) = _tones.at(tone)
  rect(a, b, fill: fill, stroke: (paint: stroke, thickness: .7pt, dash: dash), radius: radius, name: name)
  content((a, 50%, b), align(center, txt(body, size: size, fill: ink, weight: weight)))
}

// ---- commit graph pieces ---------------------------------------------------

#let _commit-tones = (
  grey: (c.grey1, c.line), blue: (c.blue1, c.blue), orange: (c.orange1, c.orange),
  teal: (c.teal1, c.teal), ghost: (white, c.grey2),
)

/// A commit dot with its hash below (or above, `label-up: true`).
#let _commit(p, label, tone: "grey", label-up: false) = {
  import cetz.draw: *
  let (fill, stroke) = _commit-tones.at(tone)
  circle(p, radius: 5.5, fill: fill, stroke: (paint: stroke, thickness: .9pt, dash: if tone == "ghost" { "dashed" } else { none }))
  let (x, y) = p
  content((x, if label-up { y + 9 } else { y - 9 }), txt(label, size: 6pt, fill: if tone == "ghost" { c.grey2 } else { c.muted }), anchor: if label-up { "south" } else { "north" })
}

/// Parent-to-child edge between two commit centres.
#let _link(a, b, ghost: false) = {
  import cetz.draw: *
  let (ax, ay) = a
  let (bx, by) = b
  let d = calc.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
  let (ux, uy) = ((bx - ax) / d, (by - ay) / d)
  line((ax + ux * 5.5, ay + uy * 5.5), (bx - ux * 5.5, by - uy * 5.5),
    stroke: (paint: if ghost { c.grey2 } else { c.line }, thickness: .9pt, dash: if ghost { "dashed" } else { none }))
}

/// A branch name tag; `side` is where it sits relative to the commit.
#let _ref(p, body, side: "up", tone: "dark") = {
  import cetz.draw: *
  let (x, y) = p
  let (pos, anc) = (
    up: ((x, y + 10), "south"), down: ((x, y - 20), "north"),
    right: ((x + 10, y), "west"), left: ((x - 10, y), "east"),
  ).at(side)
  let (fill, stroke, ink) = _tones.at(tone)
  content(pos, anchor: anc, box(fill: fill, stroke: .6pt + stroke, radius: 2pt, inset: (x: 4pt, y: 2.5pt),
    text(size: 6.5pt, weight: 600, fill: ink, body)))
}

// ============================================================================
// Working directory, staging area, repository
// ============================================================================

/// The three places a change lives in, and the commands that move it.
#let fig-three-areas() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let areas = (
    ([Working Directory], [工作目录：磁盘上的文件 \ 可以是干净的，也可以是脏的], "white"),
    ([Staging Area / Index], [暂存区：下一次提交的快照 \ 属于整个仓库，不属于某个分支], "blue"),
    ([Repository], [`.git` 中的提交历史 \ HEAD 指向当前分支的最新提交], "teal"),
  )
  let (w, h, g) = (140, 52, 66)
  let x0(i) = i * (w + g)
  for (i, (title, sub, tone)) in areas.enumerate() {
    let (fill, stroke, _) = _tones.at(tone)
    rect((x0(i), 0), (x0(i) + w, -h), fill: fill, stroke: .7pt + stroke, radius: 3)
    content((x0(i) + w / 2, -12), txt(title, size: 7.5pt, fill: c.ink, weight: 600))
    content((x0(i) + w / 2, -32), align(center, txt(sub, size: 6.5pt)))
  }
  // forward
  for (i, cmd) in ((0, [`git add`]), (1, [`git commit`])) {
    let (a, b) = (x0(i) + w + 3, x0(i + 1) - 3)
    arrow((a, -14), (b, -14), color: c.ink)
    content(((a + b) / 2, -10), txt(cmd, size: 6.5pt, fill: c.ink), anchor: "south")
  }
  // backward
  for (i, cmd) in ((0, [`git restore <file>`]), (1, [`git reset <file>`])) {
    let (a, b) = (x0(i + 1) - 3, x0(i) + w + 3)
    arrow((a, -38), (b, -38), color: c.muted, dash: "dashed")
    content(((a + b) / 2, -42), txt(cmd, size: 6pt), anchor: "north")
  }
  content((0, -h - 14), txt([实线：把改动向右推进一层；虚线：用右边那一层的内容覆盖左边（`restore` 默认取暂存区，`reset <file>` 取 HEAD）], size: 6.5pt), anchor: "north-west")
})

// ============================================================================
// Remote and upstream
// ============================================================================

/// upstream maps a local branch to a remote-tracking branch; remote maps a
/// name to a URL. One upstream per branch, any number of remotes.
#let fig-upstream() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let h = 34
  _box((0, 0), (110, -h), [本地分支 \ `main`], tone: "blue", name: "local")
  _box((190, 0), (320, -h), [remote-tracking 分支 \ `origin/main`], tone: "white", name: "track")
  _box((400, 0), (548, -h), [remote `origin` \ github.com/user/repo.git], tone: "teal", name: "origin", size: 6.5pt)
  arrow((112, -h / 2), (188, -h / 2), color: c.blue, w: 1pt)
  content((150, -h / 2 + 4), txt("upstream", size: 6.5pt, fill: c.blue, weight: 600), anchor: "south")
  content((150, -h / 2 - 4), txt([`push -u` \ `--set-upstream-to`], size: 6pt), anchor: "north")
  arrow((322, -h / 2), (398, -h / 2), color: c.teal, w: 1pt)
  content((360, -h / 2 + 4), txt("remote", size: 6.5pt, fill: c.teal, weight: 600), anchor: "south")
  content((360, -h / 2 - 4), txt([`git remote add`], size: 6pt), anchor: "north")

  let y = -70
  _box((400, y), (548, y - h), [remote `backup` \ gitlab.com/user/repo.git], tone: "grey", name: "backup", size: 6.5pt)
  line((55, -h - 2), (55, y - h / 2), (396, y - h / 2), stroke: (paint: c.muted, thickness: .7pt, dash: "dashed"),
    mark: (end: "stealth", fill: c.muted, scale: .5))
  content((225, y - h / 2 + 4), txt([`git push backup main`：手动推送，upstream 不变], size: 6.5pt), anchor: "south")
  content((0, y - h - 12), txt([无参数的 `git push` / `git pull` 走 upstream。一个本地分支只有一个 upstream，remote 可以有多个。], size: 6.5pt), anchor: "north-west")
})

// ============================================================================
// Three-way merge
// ============================================================================

/// Each branch is compared with the common ancestor, not with the other
/// branch: a side that did not change takes the other side's change.
#let fig-three-way() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let cols = ([共同祖先], [分支 A], [分支 B], [合并结果])
  let (lw, cw, g, rh) = (44, 110, 8, 26)
  let cx(i) = lw + i * (cw + g)
  for (i, t) in cols.enumerate() {
    content((cx(i) + cw / 2, 6), txt(t, size: 7pt, fill: c.ink, weight: 600), anchor: "south")
  }
  let rows = (
    ("Hello", ("Hello World", true), ("Hello", false), ([取 A：添加 World], "teal")),
    ("Hello World", ("Hello", true), ("Hello World", false), ([取 A：删除 World], "teal")),
    ("Hello", ("Hello World", true), ("Hello Universe", true), ([冲突，需要人工决定], "danger")),
  )
  for (r, (base, (a, ac), (b, bc), (res, rt))) in rows.enumerate() {
    let y = -r * (rh + 10)
    content((0, y - rh / 2), txt("场景 " + str(r + 1), size: 7pt, fill: c.ink, weight: 600), anchor: "west")
    _box((cx(0), y), (cx(0) + cw, y - rh), raw("print(\"" + base + "\")"), tone: "white", size: 6.5pt, weight: 500)
    _box((cx(1), y), (cx(1) + cw, y - rh), raw("print(\"" + a + "\")"), tone: if ac { "orange" } else { "grey" }, size: 6.5pt, weight: 500)
    _box((cx(2), y), (cx(2) + cw, y - rh), raw("print(\"" + b + "\")"), tone: if bc { "blue" } else { "grey" }, size: 6.5pt, weight: 500)
    _box((cx(3), y), (cx(3) + cw, y - rh), res, tone: rt, size: 6.5pt)
  }
  let ly = -3 * (rh + 10) - 4
  legend(lw, ly, "A 相对祖先有改动", box-swatch(lw, ly, c.orange1, stroke: .7pt + c.orange))
  legend(lw + 120, ly, "B 相对祖先有改动", box-swatch(lw + 120, ly, c.blue1, stroke: .7pt + c.blue))
  legend(lw + 240, ly, "与祖先相同", box-swatch(lw + 240, ly, c.grey1, stroke: .7pt + c.grey2))
})

// ============================================================================
// Conflict markers
// ============================================================================

/// The conflicted file from the post's example, with the regions VS Code
/// labels Current and Incoming.
#let fig-conflict() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let lines = (
    ("def greet():", none),
    ("<<<<<<< HEAD", "cur-mark"),
    ("    print(\"Hello World\")", "cur"),
    ("=======", "sep"),
    ("    print(\"Hello Universe\")", "inc"),
    (">>>>>>> feature", "inc-mark"),
  )
  let fills = ("cur-mark": c.teal2, cur: c.teal1, sep: c.grey1, inc: c.blue1, "inc-mark": c.blue2)
  let (w, lh) = (240, 17)
  let top = 0
  content((6, top + 4), txt([Accept Current Change | Accept Incoming Change | Accept Both Changes], size: 6pt), anchor: "south-west")
  for (i, (code, kind)) in lines.enumerate() {
    let y = top - i * lh
    if kind != none { rect((0, y), (w, y - lh), fill: fills.at(kind), stroke: none) }
    content((6, y - lh / 2), raw(code), anchor: "west")
  }
  rect((0, top), (w, top - lines.len() * lh), fill: none, stroke: .6pt + c.hair)

  // annotations
  let bx = w + 12
  let bracket(r0, r1, color, body) = {
    let (y0, y1) = (top - r0 * lh - 2, top - (r1 + 1) * lh + 2)
    line((bx, y0), (bx + 4, y0), (bx + 4, y1), (bx, y1), stroke: .8pt + color)
    content((bx + 10, (y0 + y1) / 2), txt(body, size: 6.5pt, fill: c.ink), anchor: "west")
  }
  bracket(1, 2, c.teal, [*Current Change*：当前分支 HEAD（`main`）的内容])
  bracket(3, 3, c.muted, [分隔符])
  bracket(4, 5, c.blue, [*Incoming Change*：被合并进来的 `feature` 的内容])
})

// ============================================================================
// Hunk header
// ============================================================================

/// `@@ -1,4 +1,6 @@`, part by part.
#let fig-hunk() = context cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let mono(s) = text(font: "IBM Plex Mono", size: 15pt, weight: 600, s)
  let wd(s) = measure(mono(s)).width.pt()
  let s = "@@ -1,4 +1,6 @@"
  let x0 = 0
  let at(i) = x0 + wd(s.slice(0, i))
  // colour the old / new ranges
  content((x0, 0), mono(s), anchor: "west")
  let spans = (
    (3, 5, c.danger, [起始行 1]), (6, 7, c.danger, [共 4 行]),
    (8, 10, c.teal, [起始行 1]), (11, 12, c.teal, [共 6 行]),
  )
  for (k, (a, b, color, body)) in spans.enumerate() {
    let (xa, xb) = (at(a), at(b))
    line((xa + 1, -12), (xb - 1, -12), stroke: 1.2pt + color)
    let y = if calc.rem(k, 2) == 0 { -22 } else { -40 }
    line(((xa + xb) / 2, -13), ((xa + xb) / 2, y + 2), stroke: .6pt + color)
    content(((xa + xb) / 2, y), txt(body, size: 6.5pt, fill: color, weight: 600), anchor: "north")
  }
  let group(a, b, color, body) = {
    let (xa, xb) = (at(a), at(b))
    line((xa, 12), (xa, 15), (xb, 15), (xb, 12), stroke: .7pt + color)
    content(((xa + xb) / 2, 18), txt(body, size: 6.5pt, fill: color, weight: 600), anchor: "south")
  }
  group(3, 7, c.danger, [旧文件 `a/`])
  group(8, 12, c.teal, [新文件 `b/`])
})

// ============================================================================
// git reset modes
// ============================================================================

/// HEAD is on C and moves to B. What each mode does to the index and the
/// working directory, and where C's changes end up.
#let fig-reset() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let cols = ([提交历史（HEAD）], [暂存区], [工作目录], [C 的改动在哪])
  let xs = (72, 210, 300, 390)
  let ws = (110, 64, 64, 150)
  for (i, t) in cols.enumerate() {
    content((xs.at(i) + ws.at(i) / 2, 8), txt(t, size: 7pt, fill: c.ink, weight: 600), anchor: "south")
  }
  let rows = (
    ("reset 之前", "C", "C", "C", [已提交，在 C 中], "teal"),
    ("--soft", "B", "C", "C", [暂存区（staged）], "blue"),
    ("--mixed", "B", "B", "C", [工作目录（unstaged）], "orange"),
    ("--hard", "B", "B", "B", [丢失（只能靠 reflog）], "danger"),
  )
  let rh = 24
  for (r, (mode, head, idx, wd, where, tone)) in rows.enumerate() {
    let y = -r * (rh + 8)
    content((0, y - rh / 2), txt(if r == 0 { mode } else { raw(mode) }, size: 7pt, fill: c.ink, weight: 600), anchor: "west")
    // history: A - B - C with HEAD
    let cy = y - rh / 2
    let pts = ((xs.at(0) + 12, cy), (xs.at(0) + 42, cy), (xs.at(0) + 72, cy))
    for (k, lab) in ("A", "B", "C").enumerate() {
      let ghost = head == "B" and lab == "C"
      if k > 0 { _link(pts.at(k - 1), pts.at(k), ghost: ghost) }
      let (fill, stroke) = _commit-tones.at(if ghost { "ghost" } else if lab == head { "teal" } else { "grey" })
      circle(pts.at(k), radius: 6, fill: fill, stroke: (paint: stroke, thickness: .9pt, dash: if ghost { "dashed" } else { none }))
      content(pts.at(k), txt(lab, size: 6pt, fill: if ghost { c.grey2 } else { c.ink }, weight: 600))
    }
    let hx = pts.at(if head == "B" { 1 } else { 2 }).at(0)
    content((hx, cy + 8), txt("HEAD", size: 5.5pt, fill: c.orange, weight: 700), anchor: "south")
    // index / working dir contents
    let cell(i, v) = {
      let changed = v == "C"
      _box((xs.at(i), y), (xs.at(i) + ws.at(i), y - rh), "= " + v, tone: if changed { "teal" } else { "grey" }, size: 7pt)
    }
    cell(1, idx)
    cell(2, wd)
    _box((xs.at(3), y), (xs.at(3) + ws.at(3), y - rh), where, tone: tone, size: 6.5pt)
  }
  content((xs.at(1), -4 * (rh + 8) - 2), txt([“= C” 表示内容与提交 C 一致；`reset` 从左到右依次重置，模式越强走得越远。], size: 6.5pt), anchor: "north-west")
})

// ============================================================================
// merge vs rebase
// ============================================================================

/// The post's rebase example, merged and rebased: merge adds one commit with
/// two parents; rebase recreates the feature commits on top of main.
#let fig-merge-rebase() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 36
  let panel(ox, title, sub) = {
    content((ox, 44), tag(title, fill: c.ink), anchor: "south-west")
    content((ox, 40), txt(sub, size: 6.5pt), anchor: "north-west")
  }
  let (ym, yf) = (-12, -50)

  // start
  let ox = 0
  panel(ox, "Start", [feature 基于较早的 main])
  let P(i, y) = (ox + 10 + i * s, y)
  _link(P(0, ym), P(1, ym)); _link(P(1, ym), P(2, ym))
  _link(P(0, ym), P(1, yf)); _link(P(1, yf), P(2, yf))
  _commit(P(0, ym), "a0b1")
  _commit(P(1, ym), "f5e7", tone: "blue", label-up: true)
  _commit(P(2, ym), "g6h8", tone: "blue", label-up: true)
  _commit(P(1, yf), "b1d4", tone: "orange")
  _commit(P(2, yf), "c3f2", tone: "orange")
  _ref(P(2, ym), [main], side: "right")
  _ref(P(2, yf), [feature], side: "right")

  // merge
  let ox = 186
  panel(ox, "git merge main", [多一个有两个 parent 的 merge commit])
  let P(i, y) = (ox + 10 + i * s, y)
  _link(P(0, ym), P(1, ym)); _link(P(1, ym), P(2, ym))
  _link(P(0, ym), P(1, yf)); _link(P(1, yf), P(2, yf))
  _link(P(2, yf), P(3, yf)); _link(P(2, ym), P(3, yf))
  _commit(P(0, ym), "a0b1")
  _commit(P(1, ym), "f5e7", tone: "blue", label-up: true)
  _commit(P(2, ym), "g6h8", tone: "blue", label-up: true)
  _commit(P(1, yf), "b1d4", tone: "orange")
  _commit(P(2, yf), "c3f2", tone: "orange")
  _commit(P(3, yf), "M", tone: "teal")
  _ref(P(2, ym), [main], side: "right")
  _ref(P(3, yf), [feature], side: "right")

  // rebase
  let ox = 372
  panel(ox, "git rebase main", [feature 的提交被重建在 main 之后])
  let P(i, y) = (ox + 10 + i * s, y)
  _link(P(0, ym), P(1, ym)); _link(P(1, ym), P(2, ym))
  _link(P(2, ym), P(3, ym)); _link(P(3, ym), P(4, ym))
  _link(P(0, ym), P(1, yf), ghost: true); _link(P(1, yf), P(2, yf), ghost: true)
  _commit(P(0, ym), "a0b1")
  _commit(P(1, ym), "f5e7", tone: "blue", label-up: true)
  _commit(P(2, ym), "g6h8", tone: "blue", label-up: true)
  _commit(P(3, ym), "b1d4′", tone: "orange", label-up: true)
  _commit(P(4, ym), "c3f2′", tone: "orange", label-up: true)
  _commit(P(1, yf), "b1d4", tone: "ghost")
  _commit(P(2, yf), "c3f2", tone: "ghost")
  _ref(P(2, ym), [main], side: "down")
  _ref(P(4, ym), [feature], side: "down")
  content((P(2, yf).at(0) + 12, yf), txt("旧提交不再被引用", size: 6pt, fill: c.grey2), anchor: "west")
})

// ============================================================================
// cherry-pick
// ============================================================================

/// Only c3b2 is applied to main, as a new commit c3b2′ with a different parent.
#let fig-cherry-pick() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 46
  let (yd, ym) = (0, -46)
  let P(i, y) = (10 + i * s, y)
  _link(P(0, ym), P(1, yd)); _link(P(1, yd), P(2, yd)); _link(P(2, yd), P(3, yd))
  _link(P(0, ym), P(1, ym)); _link(P(1, ym), P(2, ym))
  _commit(P(0, ym), "a0b1")
  _commit(P(1, yd), "b2a1", tone: "blue", label-up: true)
  _commit(P(2, yd), "c3b2", tone: "orange", label-up: true)
  _commit(P(3, yd), "d4c3", tone: "blue", label-up: true)
  _commit(P(1, ym), "z8y7", tone: "grey")
  _commit(P(2, ym), "c3b2′", tone: "orange")
  _ref(P(3, yd), [develop], side: "right")
  _ref(P(2, ym), [main], side: "right")
  curve-arrow((P(2, yd).at(0) + 4, yd - 7), (P(2, ym).at(0) + 4, ym + 7), (P(2, yd).at(0) + 22, yd - 18), (P(2, ym).at(0) + 22, ym + 18), color: c.orange, dash: "dashed")
  content((P(2, yd).at(0) + 74, (yd + ym) / 2), txt([`git cherry-pick c3b2` \ 只搬运这一个提交的改动 \ 新提交的 hash 与 parent 都不同], size: 6.5pt), anchor: "west")
})

// ============================================================================
// Rebase as delta replay
// ============================================================================

/// rebase extracts each commit's diff against its parent and applies the
/// diffs, in order, on top of M.
#let fig-replay() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let s = 64
  let (ym, yf) = (0, -56)
  let P(i, y) = (14 + i * s, y)
  let delta(a, b, body, color, up: true) = {
    let ((ax, ay), (bx, by)) = (a, b)
    content(((ax + bx) / 2, (ay + by) / 2 + if up { 5 } else { -5 }), txt(body, size: 6.5pt, fill: color, weight: 600), anchor: if up { "south" } else { "north" })
  }
  // master: P - M - A' - B' - C'
  _link(P(0, ym), P(1, ym))
  for i in range(1, 4) { _link(P(i, ym), P(i + 1, ym)) }
  // old feature: P - A - B - C
  _link(P(0, ym), P(1, yf), ghost: true)
  for i in range(1, 3) { _link(P(i, yf), P(i + 1, yf), ghost: true) }
  _commit(P(0, ym), "P")
  _commit(P(1, ym), "M", tone: "blue")
  for (i, n) in ("A", "B", "C").enumerate() {
    _commit(P(i + 1, yf), n, tone: "ghost")
    _commit(P(i + 2, ym), n + "′", tone: "orange")
  }
  let ds = ("ΔPA", "ΔAB", "ΔBC")
  delta(P(0, ym), P(1, yf), ds.at(0), c.grey2, up: false)
  delta(P(1, yf), P(2, yf), ds.at(1), c.grey2, up: false)
  delta(P(2, yf), P(3, yf), ds.at(2), c.grey2, up: false)
  for i in range(3) { delta(P(i + 1, ym), P(i + 2, ym), ds.at(i), c.orange) }
  // replay arrows
  for i in range(3) {
    let (ax, ay) = P(i + 1, yf)
    let (bx, by) = P(i + 2, ym)
    arrow((ax + 6, ay + 5), (bx - 5, by - 8), color: c.orange, dash: "dashed")
  }
  _ref(P(1, ym), [master], side: "up")
  _ref(P(4, ym), [feature], side: "right")
  content((P(3, yf).at(0) + 12, yf), txt("旧链 P→A→B→C 不再被 feature 引用", size: 6pt, fill: c.grey2), anchor: "west")
  content((P(4, ym).at(0) + 12, ym - 22), txt([tree(A′) = tree(M) + ΔPA \ tree(B′) = tree(A′) + ΔAB \ tree(C′) = tree(B′) + ΔBC], size: 6.5pt, fill: c.ink), anchor: "north-west")
})

// ============================================================================
// git worktree
// ============================================================================

/// One repository, several checked-out directories.
#let fig-worktree() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  _box((150, 0), (400, -36), [`.git` 仓库：objects · refs · 配置 \ 所有 worktree 共享，不重复存储], tone: "teal", name: "git")
  let wts = (
    ([`repo/`], [`main`], [主 worktree：`.git` 是目录]),
    ([`../feature-A/`], [`feature-A`], [`.git` 文件 → `.git/worktrees/feature-A`]),
    ([`../hotfix/`], [`hotfix`], [`.git` 文件 → `.git/worktrees/hotfix`]),
  )
  let (w, g) = (168, 12)
  for (i, (dir, br, note)) in wts.enumerate() {
    let x = i * (w + g)
    let y = -76
    rect((x, y), (x + w, y - 58), fill: white, stroke: .7pt + c.blue, radius: 3)
    content((x + 8, y - 10), txt(dir, size: 7pt, fill: c.ink, weight: 600), anchor: "west")
    content((x + w - 8, y - 10), box(fill: c.ink, radius: 2pt, inset: (x: 4pt, y: 2pt), text(size: 6pt, weight: 600, fill: white, br)), anchor: "east")
    for (k, part) in ("HEAD", "暂存区", "工作文件").enumerate() {
      let px = x + 8 + k * 52
      rect((px, y - 22), (px + 48, y - 38), fill: c.blue1, stroke: none, radius: 2)
      content((px + 24, y - 30), txt(part, size: 6pt, fill: c.ink))
    }
    content((x + 8, y - 48), txt(note, size: 6pt), anchor: "west")
    line((x + w / 2, y), (x + w / 2, -56), (275, -56), (275, -38), stroke: .7pt + c.line)
  }
  content((275, -150), txt([每个 worktree 有独立的 HEAD、暂存区和工作文件；同一个分支不能同时在两个 worktree 中检出。], size: 6.5pt), anchor: "north")
})
