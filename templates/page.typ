// The HTML document every page is written into, and the plain page layout.
// Import: #import "/templates/page.typ": html-document, page

#import "@tola/site:0.0.0": site
#import "/templates/base.typ": base, endnotes
#import "/templates/data.typ": post-index
#import "/templates/layout.typ" as layout

/// Write `body` to `output` as a complete page. `title: none` is the home
/// page; `head` is appended to the shared head entries; `posts` feeds
/// `post-index` for helpers inside the body.
#let html-document(output, title, body, head: none, posts: ()) = document(
  output,
  format: "html",
  title: if title != none { title } else { site.title },
)[
  #show: base
  #html.html(lang: site.language.tag)[
    #layout.head(title, extra: head)
    #html.body({
      post-index.update(posts)
      body
    })
  ]
]

/// Plain page (home, about, archive, ...): site chrome around prose.
#let page(output, title, body, posts: ()) = html-document(
  output,
  title,
  layout.shell(html.div(class: "prose", { body; endnotes() })),
  posts: posts,
)
