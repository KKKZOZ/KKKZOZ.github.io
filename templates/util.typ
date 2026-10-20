// Small helpers shared by the templates.
// Import: #import "/templates/util.typ": cls, to-string, og-tags

/// Join CSS classes, skipping `none` and empty strings; arrays are flattened.
/// `cls("base", if active { "active" })` gives "base active" or "base".
#let cls(..args) = {
  let flatten(items) = {
    let result = ()
    for item in items {
      if type(item) == array { result += flatten(item) } else { result.push(item) }
    }
    result
  }
  let raw = flatten(args.pos()).filter(x => x != none and x != "").map(x => str(x)).join(" ")
  raw.split(" ").filter(x => x != "").join(" ")
}

/// Plain text of `it`: `to-string[Hello *world*]` gives "Hello world".
#let to-string(it) = {
  if it == none { "" } else if type(it) == str { it } else if type(it) != content { str(it) } else if it.has("text") {
    if type(it.text) == str { it.text } else { to-string(it.text) }
  } else if it.has("children") { it.children.map(to-string).join() } else if it.has("body") {
    to-string(it.body)
  } else if it == [ ] { " " } else { "" }
}

#let _og-meta(prop, content) = {
  if content == none or content == "" { return none }
  let c = if type(content) == datetime { content.display("[year]-[month]-[day]") } else { to-string(content) }
  // og:/article: entries use `property`, which html.meta does not take.
  if prop.starts-with("og:") or prop.starts-with("article:") {
    html.elem("meta", attrs: (property: prop, content: c))
  } else {
    html.meta(name: prop, content: c)
  }
}

/// Open Graph article entries and a Twitter card; missing values are omitted.
#let og-tags(
  title: none,
  description: none,
  site-name: none,
  author: none,
  published: none,
  tags: (),
) = {
  _og-meta("og:title", title)
  _og-meta("og:description", description)
  _og-meta("og:type", "article")
  _og-meta("og:site_name", site-name)
  _og-meta("article:author", author)
  _og-meta("article:published_time", published)
  for tag in tags { _og-meta("article:tag", tag) }
  _og-meta("twitter:card", "summary_large_image")
  _og-meta("twitter:title", title)
  _og-meta("twitter:description", description)
}
