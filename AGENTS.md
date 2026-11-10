# AGENTS.md

A personal technical blog built with Tola from Typst sources. Posts live in `content/posts/<category>/<slug>.typ`, their figures in `figures/<slug>.typ`, and shared components (`callout`, `hint`, `term`, `xref`, `cols`, ...) in `utils/ui.typ`.

`content/posts/ml-systems/gpu-server-topology.typ` and `content/posts/ml-systems/nvlink-vs-pcie-inference.typ` show the voice the blog aims for. Read one before writing; take the spirit, not a template.

## Principles

**Respect the reader's attention.** The reader is technical and wants to understand something real. Get to it: start from something concrete, such as the output, the code or the question, and cut whatever doesn't help them understand.

**Earn every claim.** A statement is worth what backs it: a measurement, a derivation, a pointer into the source, a log line. Show enough that a careful reader could check it. Precision does the work that adjectives would otherwise try to do.

**Make the structure visible.** A page of dense prose with many numbers is hard to read, even when every sentence is good. Let the reader see the point before the evidence, and let the shape of the text follow the shape of the idea: comparisons can sit side by side, steps can be numbered, parallel cases can be listed, and the one sentence that matters in a paragraph can be emphasised. Use these where they make reading easier, not by default.

**Show the mechanism.** When something follows from a computation or a piece of code, show a small version of it, such as a formula, a few lines of pseudocode or a worked example with small numbers, so the reader sees why, not only what.

**Keep the voice plain and calm.** Short, direct sentences; no hype, no filler, no performed enthusiasm. Write the way a careful engineer explains something to a colleague.

**Leave the post in its own language.** About half the posts are in Chinese. Keep each in the language it is written in. Paper notes under `content/posts/papers/` get an English `summary`; other posts' summaries follow their body.

**Fit in with what is there.** Before inventing a new pattern, look at how existing posts and `utils/ui.typ` handle it. Comments in code, figures and config are in English.

## Seeing the result

`tola dev` serves the site at `http://127.0.0.1:5277/`. Large posts can take up to a minute to rebuild. Look at the rendered page after a change, not only at the source.
