// Figures for content/posts/tools/docker-network.typ, drawn with cetz.
// Container names, networks and ports are the ones used in the post.
// Same conventions as /utils/figure.typ: 1pt per unit, y grows upward, < ~560pt wide.

#import "/utils/cetz.typ" as cetz
#import "/utils/figure.typ": arrow, c, curve-arrow, tag, txt

#let _box(a, b, body, fill: white, stroke: c.hair, ink: c.ink, size: 7pt, weight: 600, dash: none, name: none) = {
  // bind before the import: cetz.draw exports `fill` and `stroke` functions
  let (bg, bd) = (fill, stroke)
  import cetz.draw: *
  rect(a, b, fill: bg, stroke: (paint: bd, thickness: .7pt, dash: dash), radius: 3, name: name)
  content((a, 50%, b), align(center, txt(body, size: size, fill: ink, weight: weight)))
}
#let _ok = text(fill: c.teal, weight: 700)[✓]
#let _no = text(fill: c.danger, weight: 700)[✗]

// ============================================================================
// Default bridge vs user-defined bridge
// ============================================================================

/// Both bridges connect the containers; only the user-defined one runs
/// Docker's embedded DNS, so only there can containers find each other by name.
#let fig-bridges() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  let panel(ox, title, net, dns) = {
    let w = 260
    content((ox, 18), tag(title, fill: c.ink), anchor: "south-west")
    rect((ox, 12), (ox + w, -150), fill: c.panel, stroke: none, radius: 3)
    // bridge bar
    _box((ox + 14, -100), (ox + w - 14, -120), net, fill: c.blue1, stroke: c.blue, size: 6.5pt)
    // containers
    for (i, (name, ip)) in (("busybox1", "172.17.0.3"), ("busybox2", "172.17.0.x")).enumerate() {
      let x = ox + 24 + i * 128
      _box((x, 0), (x + 92, -34), [#name \ #text(weight: 400, size: 6pt)[#ip]], name: "c" + str(i))
      line((x + 46, -34), (x + 46, -100), stroke: .7pt + c.blue)
    }
    if dns {
      _box((ox + 100, -128), (ox + 160, -146), [内置 DNS \ 127.0.0.11], fill: c.teal1, stroke: c.teal, size: 6pt)
    }
  }
  panel(0, "默认 bridge", [`docker0` · bridge · 172.17.0.0/16], false)
  panel(290, "自定义 bridge", [`my_bridge`（`docker network create`）], true)

  // pings, busybox2 -> busybox1
  let ping(ox, y, body, mark) = {
    arrow((ox + 152, y), (ox + 118, y), color: c.ink)
    content((ox + 135, y - 3), txt([#body #mark], size: 6.5pt, fill: c.ink), anchor: "north")
  }
  ping(0, -50, [`ping 172.17.0.3`], _ok)
  ping(0, -74, [`ping busybox1`], _no)
  ping(290, -50, [`ping 172.17.0.3`], _ok)
  ping(290, -74, [`ping busybox1`], _ok)
  content((130, -128), txt("没有 DNS：只能用 IP 互访", size: 6.5pt, fill: c.danger), anchor: "north")
  content((290 + 196, -134), txt("容器名 → IP", size: 6.5pt, fill: c.teal), anchor: "west")
})

// ============================================================================
// Compose: container ports vs host ports
// ============================================================================

/// Inside `myapp_default` services reach each other by name on the container
/// port; the host goes through the published HOST_PORT.
#let fig-compose() = cetz.canvas(length: 1pt, {
  import cetz.draw: *
  // host
  rect((0, 20), (548, -170), fill: none, stroke: .7pt + c.line, radius: 4)
  content((8, 16), tag("宿主机", fill: c.ink), anchor: "north-west")
  _box((14, -28), (124, -62), [宿主机上的程序 \ #text(weight: 400, size: 6pt)[浏览器 / psql]], fill: c.grey1, stroke: c.grey2, name: "hostapp")
  _box((14, -117), (124, -151), [宿主机上的服务 \ #text(weight: 400, size: 6pt)[`host.docker.internal`]], fill: c.grey1, stroke: c.grey2, name: "hostsvc")

  // network
  rect((214, 4), (536, -160), fill: c.panel, stroke: (paint: c.blue, thickness: .7pt, dash: "dashed"), radius: 3)
  content((222, 0), tag("network myapp_default", fill: c.blue), anchor: "north-west")
  _box((248, -26), (360, -66), [`web` \ #text(weight: 400, size: 6pt)[容器端口 8000]], fill: c.blue1, stroke: c.blue, name: "web")
  _box((410, -26), (522, -66), [`db`（postgres） \ #text(weight: 400, size: 6pt)[容器端口 5432]], fill: c.blue1, stroke: c.blue, name: "db")
  // web -> db by service name on container port
  arrow((362, -46), (408, -46), color: c.blue, w: .9pt)
  content((385, -76), align(center, txt([`postgres://db:5432` \ 服务名 + CONTAINER_PORT], size: 6pt, fill: c.blue)), anchor: "north")

  // port publishing
  let pub(y, label, above: true) = {
    rect((206, y + 8), (222, y - 8), fill: c.orange1, stroke: .7pt + c.orange, radius: 2)
    content((200, if above { y + 4 } else { y - 4 }), txt(label, size: 6.5pt, fill: c.orange, weight: 600), anchor: if above { "south-east" } else { "north-east" })
  }
  pub(-46, [8000:8000])
  pub(-104, [8001:5432], above: false)
  arrow((126, -40), (204, -46), color: c.orange)
  arrow((224, -46), (246, -46), color: c.orange)
  arrow((126, -52), (204, -104), color: c.orange)
  line((224, -104), (466, -104), (466, -68), stroke: .7pt + c.orange, mark: (end: "stealth", fill: c.orange, scale: .5))
  content((300, -107), txt([宿主机：`postgres://localhost:8001`（HOST_PORT）], size: 6pt, fill: c.orange), anchor: "north-west")

  // container -> host
  line((262, -68), (262, -134), (126, -134), stroke: (paint: c.teal, thickness: .7pt, dash: "dashed"), mark: (end: "stealth", fill: c.teal, scale: .5))
  content((268, -134), txt([容器访问宿主机：`host.docker.internal`], size: 6pt, fill: c.teal), anchor: "west")
})
