#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout

#tola-meta((
  title: "[FM 01] Pre-flight Checks",
  date: "2025-03-12",
  summary: "Part one of a sample series: checklists, callouts and footnotes.",
  tags: ("example", "series"),
  series: "Flight Manual",
))

This post and the next one form a series. Posts that share a `series` name
get a series box under the title, ordered by date; a leading `[FM 01]` tag is
dropped from the titles listed there.

= Checklist

+ Confirm the build passes with `tola build`.
+ Review drafts: links to them render as plain text until they publish.
+ Check both themes with the day / night switch in the header.

#callout(kind: "success", title: [GO FOR LAUNCH])[All three items are green.]

#callout(kind: "warning")[A broken link, image or section anchor fails the
build. That is deliberate#footnote[See `[build.references]` in `tola.toml`.].]

= Notes

Footnotes are collected at the end of the post, and each one links back to
where it was cited#footnote[Like this one.].
