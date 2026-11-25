# AGENTS.md

A personal technical blog built with Tola from Typst sources. Posts live in `content/posts/<category>/<slug>.typ`, their figures in `figures/<slug>.typ`, and shared components (`callout`, `hint`, `term`, `xref`, `cols`, ...) come from the NASApunk theme: `#import "@tola-modules/nasapunk:0.0.0": callout, img`. The theme is a Tola module fetched from Git and pinned in `tola.lock` (`mise run theme:update` upgrades it); its options are in `tola.toml`, and the blog's own additions (comments, analytics, extra CSS) in `site.typ` and `assets/`. To change the theme itself, work in the theme repo (https://github.com/KKKZOZ/tola-theme-nasapunk).

`content/posts/ml-systems/gpu-server-topology.typ` and `content/posts/ml-systems/nvlink-vs-pcie-inference.typ` show the voice the blog aims for. Read one before writing; take the spirit, not a template.

## Principles

**Respect the reader's attention.** The reader is technical and wants to understand something real. Get to it: start from something concrete, such as the question, and cut whatever doesn't help them understand.

**Earn every claim.** A statement is worth what backs it: a measurement, a derivation, a pointer into the source, a log line. Show enough that a careful reader could check it. Precision does the work that adjectives would otherwise try to do.

**Make the structure visible.** A page of dense prose with many numbers is hard to read, even when every sentence is good. Let the reader see the point before the evidence: a paragraph or a section leads with its claim. Let the shape of the text follow the shape of the idea: comparisons can sit side by side, steps can be numbered, parallel cases can be listed, a sentence that packs several conditions and outcomes can become a list or a table, and the one sentence that matters in a paragraph can be emphasised. Use these where they make reading easier, not by default.

**Show the mechanism.** When something follows from a computation or a piece of code, show a small version of it, such as a formula, a few lines of pseudocode or a worked example with small numbers, so the reader sees why, not only what. Show the steps, not only the result: where each term of a formula comes from, the intermediate line of a derivation, and for an algorithm, commented pseudocode traced step by step on a small example.

**Keep the voice plain and calm.** No hype, no filler, no performed enthusiasm. Write the way a careful engineer explains something to a colleague: direct sentences, each saying one complete thing, with the words that link them (because, so, when, which) left in. Split a long sentence into several complete ones rather than compressing it into fragments. Bold lead-ins, step titles, headings and takeaways are plain, complete statements too ("When σ is small, the error grows much less than the overlap loss"), not clipped slogans ("Accurate enough, not more", "Warming works", "Same bytes, 69% more error").

**Leave the post in its own language.** About half the posts are in Chinese. Keep each in the language it is written in. Paper notes under `content/posts/papers/` get an English `summary`; other posts' summaries follow their body.

**Fit in with what is there.** Before inventing a new pattern, look at how existing posts and the theme's components ([wiki](https://github.com/KKKZOZ/tola-theme-nasapunk/wiki/Components)) handle it. Comments in code, figures and config are in English.

## Explaining

A few habits that keep a post easy to follow, especially an explainer:

- **Define before use.** Every symbol, term and metric gets a plain definition where it first appears, in the text or in a figure, not only in a terms box. Name concrete things rather than vague categories.
- **Order by dependency.** Introduce an idea after what it depends on, close to where it is used. A section that solves a problem states it first: what is given, what is chosen, what is minimised.
- **Do not show a result ahead of its method.** If a fix or an improvement comes from a method explained later, say so where it first appears.
- **Let figures carry their own labels.** A reader should find every symbol from the text in the figure. The caption adds only what the figure cannot show and does not repeat it.
- **Prefer exact wording to shorthand.** Spell out phrases that drop a word or can be read two ways.
- **Name the baseline of every comparison.** "8 pp lower" or "1.3×" needs "than what" in the same sentence.
- **When comparing methods, say what each optimises** and what it gives up, and close with a short summary of when to use which.
- **Keep explainers self-contained.** Leave out project data and internal context; open with the subject itself. The question-and-answer summary table belongs to weekly reports only.

## Weekly Progress

Weekly progress reports (`content/posts/weekly/`) are mostly experiments, and readers come to them without the context the experiments were run in. Present each experiment in three steps, so that no result appears before the reader knows what it answers:

1. **What we want to know.** One question, often in bold: *Do real Stage 1 formats miss near the threshold, as the noise model predicts?*
2. **What we did.** The setup that makes the numbers meaningful: model, data, what is varied and what is held fixed (and why, e.g. "the exact attention output as input, so only the weight format differs"), and what is measured.
3. **What we found.** The result, tied back to the question.

A lead-in like "Measured on Qwen3-8B (8K context, layers 1–35), the misses follow the picture above:" skips the first two steps. Rewrite it as a question and a method, then the figure or table, then the result.

The habits under Explaining matter most here: define each term where it first appears, and name the baseline of every comparison.

## Seeing the result

`tola dev` serves the site at `http://127.0.0.1:5277/`. Large posts can take up to a minute to rebuild. Look at the rendered page after a change, not only at the source.
