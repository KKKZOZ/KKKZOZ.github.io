// Figures for content/posts/languages/java-threadlocal.typ, drawn with cetz.
// Field names follow OpenJDK: Thread.threadLocals is a ThreadLocalMap whose
// entries hold the ThreadLocal weakly (as the key) and the value strongly.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, box-swatch, c, legend, line-swatch, tag, txt

#let _strong(a, b, color: c.line) = arrow(a, b, color: color, w: .8pt)
#let _weak(a, b) = arrow(a, b, color: c.muted, dash: "dashed", w: .7pt)

// ============================================================================
// Where the values live
// ============================================================================

/// Two threads, two ThreadLocals. Each thread has its own map; the
/// ThreadLocal objects are only the keys, shared by every thread.
#let fig-threadlocal-map() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let (tw, mid0, mid1) = (206, 226, 324)
  let rows = (("A", -58), ("B", -84))
  // shared ThreadLocal objects, between the two threads
  content(((mid0 + mid1) / 2, -14), align(center, txt([堆上的 ThreadLocal 对象 \ 通常是 static 字段，所有线程共用], size: 6pt)), anchor: "north")
  for (n, y) in rows {
    rect((mid0, y + 10), (mid1, y - 10), fill: c.orange1, stroke: .7pt + c.orange, radius: 3)
    content(((mid0 + mid1) / 2, y), txt([`ThreadLocal` #n], size: 7pt, fill: c.ink, weight: 600))
  }
  // threads; Thread 1's columns are mirrored so both key columns face the middle
  let threads = (("Thread 1", 0, ("0", "1"), true), ("Thread 2", mid1 + 20, ("2", "3"), false))
  for (name, x, vals, mirror) in threads {
    rect((x, 0), (x + tw, -112), fill: c.panel, stroke: .7pt + c.blue, radius: 3)
    content((x + 8, -5), tag(name, fill: c.blue), anchor: "north-west")
    content((x + tw - 8, -5), txt([字段 `threadLocals`], size: 6pt), anchor: "north-east")
    let (mx0, mx1) = (x + 10, x + tw - 10)
    rect((mx0, -22), (mx1, -102), fill: white, stroke: .6pt + c.hair, radius: 2)
    content((mx0 + 6, -26), txt([`ThreadLocalMap` · `Entry[]`], size: 6.5pt, fill: c.ink, weight: 600), anchor: "north-west")
    let kw = 104
    let (k0, k1, v0, v1) = if mirror { (mx1 - 6 - kw, mx1 - 6, mx0 + 6, mx1 - 12 - kw) } else { (mx0 + 6, mx0 + 6 + kw, mx0 + 12 + kw, mx1 - 6) }
    content(((k0 + k1) / 2, -42), txt("key（弱引用）", size: 6pt), anchor: "south")
    content(((v0 + v1) / 2, -42), txt("value", size: 6pt), anchor: "south")
    for (i, (n, y)) in rows.enumerate() {
      rect((k0, y + 10), (k1, y - 10), fill: c.orange1, stroke: none, radius: 2)
      content(((k0 + k1) / 2, y), txt([ThreadLocal #n], size: 6.5pt, fill: c.ink))
      rect((v0, y + 10), (v1, y - 10), fill: c.blue1, stroke: none, radius: 2)
      content(((v0 + v1) / 2, y), txt([#vals.at(i)], size: 7pt, fill: c.ink, weight: 600))
      if mirror { _weak((k1 + 2, y), (mid0 - 2, y)) } else { _weak((k0 - 2, y), (mid1 + 2, y)) }
    }
  }
  content(((mid0 + mid1) / 2, -122), txt([`A.get()` 在 Thread 2 中执行：取 `Thread.currentThread().threadLocals`，以 A 为 key 查表，得到 2], size: 6.5pt), anchor: "north")
})

// ============================================================================
// Memory leak
// ============================================================================

/// Once the outside strong reference to the ThreadLocal is gone, GC clears
/// the weak key, but a pooled thread still reaches the value.
#let fig-threadlocal-leak() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let b(a, z, body, fill: white, stroke: c.hair, ink: c.ink, dash: none, name: none) = {
    rect(a, z, fill: fill, stroke: (paint: stroke, thickness: .7pt, dash: dash), radius: 3, name: name)
    content((a, 50%, z), align(center, txt(body, size: 6.5pt, fill: ink, weight: 600)))
  }
  // stack side
  content((0, 14), tag("栈 / 静态字段", fill: c.muted), anchor: "south-west")
  b((0, 0), (96, -24), [`ThreadLocal` 引用], stroke: c.grey2, dash: "dashed", ink: c.muted)
  content((48, -30), txt("用完后被置空或出作用域", size: 6pt, fill: c.danger), anchor: "north")
  // ThreadLocal object
  b((170, 0), (276, -24), [`ThreadLocal` 对象 \ 已被 GC], fill: white, stroke: c.grey2, dash: "dashed", ink: c.muted)
  _strong((98, -12), (168, -12), color: c.grey2)
  for (dx, dy) in ((3, 3), (3, -3)) { line((133 - dx, -12 - dy), (133 + dx, -12 + dy), stroke: 1pt + c.danger) }

  // thread side
  let y = -76
  content((0, y + 14), tag("线程池中的线程（长期存活）", fill: c.blue), anchor: "south-west")
  b((0, y), (96, y - 24), [`Thread`], fill: c.blue1, stroke: c.blue)
  b((128, y), (224, y - 24), [`ThreadLocalMap`], fill: c.blue1, stroke: c.blue)
  rect((256, y + 6), (420, y - 30), fill: c.panel, stroke: .6pt + c.hair, radius: 3)
  content((262, y + 4), txt("Entry", size: 6pt), anchor: "north-west")
  b((264, y - 8), (330, y - 26), [key = null], fill: white, stroke: c.grey2, ink: c.muted)
  b((340, y - 8), (412, y - 26), [value], fill: c.orange1, stroke: c.orange)
  b((460, y - 8), (548, y - 26), [value 对象 \ 无法回收], fill: c.orange1, stroke: c.danger, ink: c.danger)
  _strong((98, y - 12), (126, y - 12), color: c.blue)
  _strong((226, y - 12), (254, y - 12), color: c.blue)
  _strong((414, y - 17), (458, y - 17), color: c.danger)
  // the weak key used to point at the ThreadLocal
  _weak((297, y - 8), (240, -26))
  content((280, -44), txt("弱引用：外部强引用消失后，下一次 GC 回收 ThreadLocal", size: 6pt), anchor: "west")

  content((0, y - 44), txt([Thread → ThreadLocalMap → Entry → value 这条强引用链一直存在：线程不退出、也没有调用 `remove()`，value 就不会被回收；线程被复用时，下一个任务还会读到这个旧值。], size: 6.5pt), anchor: "north-west")
})
