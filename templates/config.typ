// Site values that have no `[site]` key in tola.toml.
// Import: #import "/templates/config.typ": doc-prefix, mission, social-links, ...

/// Prefix of post document numbers: KKZ-TN-001, KKZ-TN-002, ...
#let doc-prefix = "KKZ-TN"

/// Width of the text column in CSS pixels, shared by the header, listings
/// and post text. Wider posts float their table of contents beside the text
/// only on windows with room for both (layout.typ `toc-float-at`).
#let content-width = 760

/// Optional orange code shown in the header next to the site title, e.g.
/// "RESEARCH NOTES"; `none` hides it.
#let mission = none

/// Links in the footer, as (label, URL) pairs, e.g. ("Email",
/// "mailto:you@example.com"). They carry `rel="me"`, so Mastodon and other
/// IndieWeb profiles that link back to the site can verify them.
#let social-links = (
  ("GitHub", "https://github.com/KKKZOZ"),
)

/// Preview image when a page is shared: `auto` draws one from the site's
/// title and description (templates/social.typ); `(src: "/assets/…", alt:
/// "…")` uses a file under assets/ (1200 × 630 suits most sites); `none`
/// gives a text-only card. Needs `origin` in tola.toml, as image URLs are
/// absolute.
#let social-image = auto

/// Font for Chinese, Japanese and Korean text in figures and the preview
/// image drawn by Typst, e.g. "Sarasa Gothic SC" once it is installed on the
/// build machine. `none` uses any system font that has the glyphs. Pages
/// themselves use the browser's fonts (assets/styles/site.css).
#let cjk-font = "Sarasa Gothic SC"

/// Syntax colours for code: a name from @tola/code's `code-themes`
/// (`tola help "@tola/code" code-themes`), or `auto` for Typst's own
/// colours. `code-theme` is the day look, `code-dark-theme` the night one.
#let code-theme = auto
#let code-dark-theme = "github-dark"

/// Extra <head> content on every page, such as an analytics script.
/// `html.elem` takes any attribute; Plausible, for example:
/// ```typst
/// #let head-extra = html.elem("script", attrs: (
///   defer: "", src: "https://plausible.io/js/script.js", data-domain: "example.com",
/// ))
/// ```
/// Insightflare analytics, loaded only on the live host so `tola dev`
/// visits are not counted.
#let head-extra = html.script("if(location.hostname===\"blog.kkkzoz.top\"){let s=document.createElement(\"script\");s.defer=true;s.src=\"https://insightflare.1206668472.workers.dev/script.js?siteId=a2308d7a-3c61-4541-987c-e675aa991a6f\";document.head.append(s)}")

/// giscus comments under each post (templates/comments.typ), from the repo's
/// Discussions; the values come from https://giscus.app. `none` turns
/// comments off.
#let comments = (
  repo: "kkkzoz/kkkzoz.github.io",
  repo-id: "MDEwOlJlcG9zaXRvcnkzOTU4ODgxODY=",
  category: "Announcements",
  category-id: "DIC_kwDOF5jGOs4Cr9zt",
  // Discussion per page path, as the Hugo site used: posts that kept their
  // path keep their comments.
  mapping: "pathname",
)
