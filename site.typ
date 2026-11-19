// The site program: the NASApunk theme's `render-site`, given the settings
// that are Typst values rather than TOML options (tola.toml).

#import "@tola/address:0.0.0": asset-url
#import "@tola-modules/nasapunk:0.0.0": render-site

/// giscus comments from the repo's Discussions; the values come from
/// https://giscus.app. Discussion per page path, as the Hugo site used:
/// posts that kept their path keep their comments.
#let giscus = (
  repo: "kkkzoz/kkkzoz.github.io",
  repo-id: "MDEwOlJlcG9zaXRvcnkzOTU4ODgxODY=",
  category: "Announcements",
  category-id: "DIC_kwDOF5jGOs4Cr9zt",
  mapping: "pathname",
)

/// The comments section under a post. assets/scripts/comments.js loads the
/// giscus client with the page's current theme and keeps it in step with
/// the day / night toggle. lab/ test pages take no comments.
#let comments(post) = if not post.output.starts-with("lab/") {
  html.section(class: "comments", aria-label: "Comments", {
    html.div(class: "label accent", "Comments")
    html.elem("div", attrs: (
      class: "giscus-mount",
      data-repo: giscus.repo,
      data-repo-id: giscus.repo-id,
      data-category: giscus.category,
      data-category-id: giscus.category-id,
      data-mapping: giscus.mapping,
    ))
    html.script("", src: asset-url("/assets/scripts/comments.js"), defer: true)
  })
}

#render-site(
  head-extra: {
    // The blog's additions to the theme's stylesheet; loaded after it.
    html.link(rel: "stylesheet", href: asset-url("/assets/styles/blog.css"))
    // Insightflare analytics, loaded only on the live host so `tola dev`
    // visits are not counted.
    html.script("if(location.hostname===\"blog.kkkzoz.top\"){let s=document.createElement(\"script\");s.defer=true;s.src=\"https://insightflare.1206668472.workers.dev/script.js?siteId=a2308d7a-3c61-4541-987c-e675aa991a6f\";document.head.append(s)}")
  },
  post-footer-extra: comments,
)
