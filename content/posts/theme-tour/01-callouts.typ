#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": callout

#tola-meta((
  title: "[Tour 01] Callouts and Footnotes",
  date: "2025-03-12",
  summary: "Part one of a sample series: checklists, callouts and footnotes.",
  tags: ("example", "series"),
  series: "Theme Tour",
))

This post and the next one form a series. Posts that share a `series` name
get a series box under the title, ordered by date; a leading `[Tour 01]` tag is
dropped from the titles listed there.

= Checklist

+ Confirm the build passes with `tola build`.
+ Review drafts: links to them render as plain text until they publish.
+ Check both themes with the day / night switch in the header.

#callout(kind: "success", title: [READY])[All three checks pass.]

#callout(kind: "warning")[A broken link, image or section anchor fails the
build. That is deliberate#footnote[See `[build.references]` in `tola.toml`.].]

= Notes

Footnotes are collected at the end of the post, and each one links back to
where it was cited#footnote[Like this one.].
