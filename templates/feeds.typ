// RSS feed and sitemap, built from the post list. Both list absolute
// addresses, so they are published only when the site has an `origin`
// (tola.toml, or `tola build --origin`). site.typ emits them.
// Import: #import "/templates/feeds.typ": feeds, has-feed, feed-output

#import "@tola/site:0.0.0": site
#import "@tola/web:0.0.0": feed, sitemap

/// Newest posts listed in the feed.
#let feed-size = 20

/// `true` puts each post's full text in the feed, `false` only its summary.
#let full-text = true

/// The feed's file, relative to the site root.
#let feed-output = "feed.xml"

/// Whether the feed and sitemap are published; the header and footer link
/// to the feed only then.
#let has-feed = site.url != none

/// The RSS feed of the newest posts, and a sitemap of every listed page.
/// `pages` are the published `(source:, output:)` records, `posts` the post
/// records, newest first.
#let feeds(pages, posts) = if has-feed {
  feed(output: feed-output, entries: posts.slice(0, calc.min(posts.len(), feed-size)).map(p => (
    target: p.output,
    published: p.date,
    summary: p.summary,
    // The post text, by the id post.typ gives it.
    content: if full-text { (document: p.output, id: "post-content") },
  )))

  // Listings and pages written as sources; lab/ test pages stay out.
  let dates = posts.map(p => (p.output, p.date)).to-dict()
  let outputs = ("index.html", "archive/index.html", "tags/index.html")
  outputs += pages.filter(page => not page.source.id.starts-with("lab/")).map(page => page.output)
  sitemap(targets: outputs.map(output => {
    if output in dates { (target: output, lastmod: dates.at(output)) } else { output }
  }))
}
