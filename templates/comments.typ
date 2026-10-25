// giscus comments under a post, configured by `comments` in config.typ.
// assets/scripts/comments.js loads the giscus client with the page's current
// theme and keeps it in step with the day / night toggle.
// Import: #import "/templates/comments.typ": comments-box

#import "@tola/address:0.0.0": asset-url
#import "/templates/config.typ": comments
#import "/templates/layout.typ": label

#let comments-box() = if comments != none {
  html.section(class: "comments", aria-label: "Comments", {
    label("Comments", class: "accent")
    html.elem("div", attrs: (
      class: "giscus-mount",
      data-repo: comments.repo,
      data-repo-id: comments.repo-id,
      data-category: comments.category,
      data-category-id: comments.category-id,
      data-mapping: comments.mapping,
    ))
    html.script("", src: asset-url("/assets/scripts/comments.js"), defer: true)
  })
}
