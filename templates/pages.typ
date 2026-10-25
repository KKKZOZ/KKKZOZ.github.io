// Pages built from the post list rather than written as sources: home,
// archive, tags, search and the 404 page. site.typ emits each one.
// Import: #import "/templates/pages.typ" as pages

#import "@tola/address:0.0.0": asset-url, output-url
#import "@tola/site:0.0.0": site
#import "/templates/layout.typ" as layout
#import "/templates/page.typ": page
#import "/templates/post.typ": doc-number, pad

/// Number of posts listed on the home page.
#let shown = 10

#let home(posts) = page("index.html", none, posts: posts, {
  layout.hero(subtitle: site.description, meta: str(posts.len()) + " posts")
  html.div(class: "section-label", layout.label(class: "accent")[Recent posts])
  // By `weight`; the sort is stable, so equal weights stay newest first.
  // Other listings and the feed keep date order.
  layout.post-list(posts.sorted(key: p => p.weight).slice(0, calc.min(posts.len(), shown)))
  if posts.len() > shown {
    html.div(class: "more-link", html.a(class: "label", href: output-url("archive/index.html"))[All #posts.len() posts →])
  }
})

/// Four-cell summary under a listing's title, styled as the post's document
/// control block: (label, value) pairs.
#let index-stats(cells) = html.elem("dl", attrs: (class: "doc-control index-stats"), for (key, value) in cells {
  html.div(class: "doc-cell", {
    html.elem("dt", attrs: (class: "label"), key)
    html.elem("dd", value)
  })
})

/// Segments in the tallest bar of the archive's density chart.
#let density-steps = 8

/// The archive as a flight log: a summary, a posts-per-month density chart
/// (one row per year, linking to its section), then the years, numbered
/// in mission time from the first post's year (T+00).
#let archive(posts) = page("archive/index.html", "Archive", posts: posts, {
  let years = layout.posts-by-year(posts)
  let month-of(p) = int(layout.fmt-date(p.date).slice(5, 7))
  let counts = years.map(((year, items)) => range(1, 13).map(m => items.filter(p => month-of(p) == m).len()))
  let peak = calc.max(1, ..counts.flatten())
  let first-year = int(years.at(-1, default: ("0", ())).at(0))
  let mission-time(year) = "T+" + pad(int(year) - first-year, 2)
  layout.page-head("Archive", sub: "All posts")
  index-stats((
    ("Entries", str(posts.len())),
    ("Span", if years.len() > 0 { years.at(-1).at(0) + "–" + years.at(0).at(0) } else { "—" }),
    ("First entry", if posts.len() > 0 { layout.fmt-date(posts.at(-1).date) } else { "—" }),
    ("Latest entry", if posts.len() > 0 { layout.fmt-date(posts.at(0).date) } else { "—" }),
  ))
  html.div(class: "section-label", id: "log", layout.label(class: "accent")[Density / posts per month])
  html.div(class: "density", {
    for ((year, items), months) in years.zip(counts) {
      html.a(class: "density-row", href: "#y" + year, {
        html.span(class: "density-year", year)
        html.span(class: "density-bars", for (m, n) in months.enumerate() {
          let steps = if n == 0 { 0 } else { calc.max(1, calc.round(n / peak * density-steps)) }
          html.span(
            class: "density-bar",
            style: "--steps: " + str(steps),
            title: year + "-" + pad(m + 1, 2) + " · " + str(n) + if n == 1 { " post" } else { " posts" },
          )
        })
        html.span(class: "density-count", str(items.len()))
      })
    }
    html.div(class: "density-row density-axis", role: "presentation", {
      html.span()
      html.span(class: "density-bars", for m in "JFMAMJJASOND".clusters() { html.span(m) })
      html.span()
    })
  })
  for (year, items) in years {
    html.section(class: "index-section", {
      layout.index-heading(year, items.len(), id: "y" + year, code: mission-time(year), back: "#log")
      layout.index-rows(items, date-format: d => layout.fmt-date(d).slice(5), code: p => doc-number(posts, p.output))
    })
  }
})

/// Tags as a telemetry channel index: a traffic summary, a directory with a
/// level meter per tag (scaled to the busiest one), then one section per
/// tag, its posts listed with their document numbers.
#let tags(posts) = page("tags/index.html", "Tags", posts: posts, {
  let groups = layout.posts-by-tag(posts)
  let channel(i) = "CH-" + pad(i + 1, 2)
  let peak = groups.at(0, default: (none, ())).at(1).len()
  layout.page-head("Tags", sub: "Channel index")
  index-stats((
    ("Channels", str(groups.len())),
    ("Links", str(groups.map(((t, ps)) => ps.len()).sum(default: 0))),
    ("Posts", str(posts.len())),
    ("Peak", if peak > 0 { groups.at(0).at(0) } else { "—" }),
  ))
  html.div(class: "section-label", id: "channels", layout.label(class: "accent")[Directory / by traffic])
  html.ol(class: "channel-grid", for (i, (tag, items)) in groups.enumerate() {
    let level = str(calc.round(items.len() / peak * 100, digits: 1)) + "%"
    html.li(html.a(class: "channel", href: layout.tag-href(tag), title: tag, style: "--level: " + level, {
      html.span(class: "channel-code", channel(i))
      html.span(class: "channel-name", tag)
      html.span(class: "channel-count", str(items.len()))
    }))
  })
  for (i, (tag, items)) in groups.enumerate() {
    html.section(class: "index-section", {
      layout.index-heading(tag, items.len(), id: layout.tag-slug(tag), code: channel(i), back: "#channels")
      layout.index-rows(items, code: p => doc-number(posts, p.output))
    })
  }
})

#let search() = page("search/index.html", "Search", {
  layout.page-head("Search", sub: "Query / archive")
  // Wired up by assets/scripts/search.js against the Pagefind index, which
  // the `search` build hook writes to /pagefind/.
  html.div(class: "search", {
    html.elem("label", attrs: (class: "search-bar", "for": "search-input"), {
      html.span(class: "search-prompt", aria-hidden: true, "Query >")
      html.elem("input", attrs: (
        id: "search-input",
        type: "search",
        placeholder: "keywords, 关键词 …",
        autocomplete: "off",
        spellcheck: "false",
        aria-label: "Search posts",
      ))
    })
    html.div(id: "search-status", class: "label search-status", aria-live: "polite", "Standing by")
    html.ol(id: "search-results", class: "search-results")
  })
  html.elem("script", attrs: (type: "module", src: asset-url("/assets/scripts/search.js")))
})

/// The "Loss of signal" page, served for addresses the site does not publish.
#let not-found() = page("404.html", "Signal Lost", {
  html.section(class: "lost", {
    html.div({
      layout.label("Error 404 / LOS", class: "accent")
      html.h1(class: "post-title", "Loss of signal")
      html.p(class: "lost-text", "This page is not on any known trajectory. It may have moved, or never launched.")
      html.div(class: "lost-telemetry", {
        layout.label({ "Requested "; html.span(id: "lost-path", "—") })
        layout.label("Status: no carrier")
      })
      html.a(class: "lost-home label", href: output-url("index.html"), "← Signal lost · Return to base")
    })
    html.div(class: "lost-mark", role: "presentation", layout.lost-signal-mark())
  })
  // Echo the requested path; the page itself is static.
  html.script("document.getElementById('lost-path').textContent = location.pathname;")
})
