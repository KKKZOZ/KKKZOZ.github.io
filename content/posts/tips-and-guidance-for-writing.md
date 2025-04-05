---
title: "Tips and guidance for writing"
tags:
  - Reading Note
date: 2025-03-31
showtoc: true
---

> Reading Note[^1]

## General Advice on Technical Writing

One of the most crucial aspects of writing a good technical paper is what I call maintaining user state. Like a good operating system, the writer should ensure that the (mental) state of the user (i.e. reader) is kept coherent.

it means that the paper systematically builds up the reader's understanding and knowledge of the work, starting from a reasonable initial state. This means you need to put yourself into the reader's shoes (or, rather, brain) and ensure that they can follow at each instance:

- **Make reasonable assumptions about the initial state (i.e. prior knowledge).** A common fault of theses and papers is too much assumed knowledge. You're breathing this stuff daily, and somehow assume everyone else does. They don't.
- Make sure the paper/report is self-contained. While it is important to reference prior work (yours as well as others), don't expect the reader to have read all those papers!
- Ensure that at any point in the paper, you don't expect more knowledge from the reader than the union of the initial state and what you've told them so far. Remember, the reader normally reads the work sequentially. It doesn't help them if a term you're using right now is explained ten pages later. Define-before-use isn't just important in programming, it's important in writing just the same.
- Small, strategic doses of redundancy help. A good approach is for each section:
  - Say what you're going to say,
  - say it
  - say what you just said
  - You (1) start the section with a brief (1–3 sentence) overview what the section is about. Then (2) you provide the material. Finally (3) you summarize (in 1–3 sentences) the main takeaways, so the reader knows what they are expected to remember.

> [!NOTE]
> Use this in the main sections of a paper (not the intro, related work section or conclusion), but be really concise. In a thesis you're well advised to use it not only on the main chapters, but also the top-level sections of the chapters (and maybe even long secondary sections).

- Occasionally you have circular dependencies: Explaining A requires understanding B, and explaining B requires understanding A. What do you do here? The usual way out of this is to first give a brief, informal explanation of all terms, and follow it up with a rigorous definition/explanation later.
- Be consistent in your own terminology. This again sounds too obvious to mention, but is violated all the time. For example, don't use two different terms interchangeably, unless they really have the same meaning, and you have made that point explicitly.

## About Thesis Writing

### General advice

Do not expect that the teacher keeps marking up the same mistake repeatedly, usually he only marks it up once. So when correcting a mistake, think about whether it might be part of a pattern.

### Structure and coherence

Abstract

A short (1–3 paragraph) summary of the work. Should state the problem, major assumptions, basic idea of solution, results. Avoid non-standard terms and acronyms. The abstract must be able to be read completely on its own, detached from any other work (e.g. in collections of paper abstracts). Don't use references in an abstract.

Introduction

Introduce the problem (gently!) Try to give the reader an appreciation of the difficulty, and an idea of how you will go about it. It's like the overture of an opera: it plays on all the relevant themes.

Make sure you clearly state the vision/aims of your work, what problem you are trying to solve, and why it is important. Especially, make clear you highlight the challenges you need to overcome. Having made it through the intro, the reader should have a clear idea of what to expect in the remainder of the work. This applies to the problem, the author's hypothesis, and (at a very high level) the approach taken.

Remember, the intro is the first thing that is being read, and will have a major influence on the how the reader approaches your work. If you bore them now, you've most likely lost them already.

It's also important that you provide enough context and indication the limitations/assumptions of your work to avoid uprising (and disappointing) your reader.

Literature review (often called “related work”)

This is really important. If you cannot demonstrate that you know, and understand, what others have done, you only demonstrate that you're clueless.

In this part you demonstrate that you are aware of what's going on in the field, and how it relates to your particular problem.

The way to convince the reader that your work hasn't been done before is to explain what has been done, what's different about what has been done, and, if you're good, why it hasn't been done already.

Design of your solution

Discuss design tradeoffs **before** you present the design you have settled on, don't use the backward approach of “I'm doing it this way. I could have done it that way, but...” This smells of having been added as an afterthought. Show that you have thought things through, and convincingly show how and why you have arrived at the best solution.

Importantly, be forthright about the limitations and assumptions of your design. Also, make sure you justify any shortcuts/limitations convincingly

Experiments

Benchmarking takes time, for running the experiments, but also for thinking them up in the first place, and for analysing the results (and, inevitably, decide you'll have to do more benchmarks to clear things up).

If you get surprising results, don't just say "surprise, surprise, performance isn't as good as hoped". Find out why. Surprises without explanation indicate either that you are clueless about what's going on, or that you have made a mistake (most likely both).

## About Paper Writing

### Paper vs thesis

- A paper is obviously much more concise. You don't have as much space to explain things. On the other hand, a paper is more directed at the experts, and can assume much more background knowledge.
- A conference paper is pass/fail (with a very high failure rate, > 80% in most systems conferences!) And you typically only get a single shot, if you fail, you'll have to wait for the next conference. As such, a paper tends to be much more critically assessed, and you'll end up investing much more time per page than for a thesis (including your PhD). Remember, you're competing with the best minds in the field, and it is up to you to prove that you're playing on the same level!

### General rules

**Be clear.**

Clarity applies at several levels, from individual words, to sentences, to paragraphs, to sections, to the whole paper. Make sure that at every level, what you are writing conveys a clear and unambiguous message.

**Be concise.**

Obviously, conciseness must not come at the expense of clarity, if shortening means loss of clarity, don't. Also, keep in mind what I said above about maintaining user state, However, experience shows that in most cases the more concise formulation is also the clearer one.

A good method is “Jay's Rule of Thumb“, It means you cover up parts of the text with your thumb. If it doesn't change the meaning, you know where you should cut.

Also, make sure your paper is properly spell-checked and proof-read. If you're not a native English speaker, get someone who is to help with proof-reading. Sloppiness annoys reviewers!

### Structure

#### Abstract

The abstract serves multiple purposes. In any case, it is supposed to give the potential reader a good idea of what to expect in the paper.

For a paper which is submitted to a conference for review, the abstract serves a single purpose: to attract the right reviewers (and many others don't seem to understand this).

This means that you need to word the abstract carefully so it correctly sets the expectations on the content of the paper. Make sure that it allows the reader to judge whether your paper is more theoretical or practical, whether it is in their area of interest and expertise.

Once your paper is accepted, the abstract has a different purpose: it should contain the right keywords to direct searches, and give people an idea of whether it contains something of interest for them.

A core rule for the abstract is **keep it short**!

A good rule of thumb is that an abstract should be like a good elevator pitch, address the following, each in one (at most two) sentences:

- What is the problem you're trying to address?
- Why is it a problem (aka who cares)?
- How are you solving it?
- Which results did you get (aka what did you achieve)?

#### Introduction

This is the **most important part** of the paper, certainly as far as writing is concerned. Here you need to convince the reader that you have identified a real problem (which includes motivating why it is relevant!) and outline your approach to solving it. And make it clear that you have actually solved it!

It is often a good idea to write the intro in two steps. Write it before you write anything else, this will define where the paper is heading. Then, at the very end, go over it very carefully to ensure that it is still consistent with the rest of the paper. In particular, ensure that the intro doesn't promise more than what the paper holds. Reviewers get very angry with bait-and-switch papers (see below)!

Make sure that the intro is concise, yet interesting, highly readable, and complete. **It should not be longer than about a page**, if it does, you're probably putting too much detail in, leave that for later.

Also, **try to put a diagram/figure on the first page.** This immediately makes the paper look more appealing. Obviously, the figure must be related to what you are presenting and help understanding, else it's a useless filler. Good examples are diagrams (eg from measurements) which highlight the problem you're trying to solve, or an indication of your results. And it should be referenced on the first page, else it belongs to where it is referenced.

**Avoid buzzwords, over-the-top statements and outrageous claims.** This applies to the whole paper, but the introduction section is particularly prone to over-selling. This makes the reader suspect and frequently annoyed. Examples of buzzwords are “new”, “novel”, “innovative”, etc. These are useless fillers and should be avoided! If your work isn't novel, you wouldn't be trying to publish it, right?

Then cut to the chase! After getting an idea what you're trying to sell me, I want to know how it works. **At least a general idea of how you solve the problem should be presented in the intro.** I want to see that what you are saying makes sense. It is extremely annoying having to read through lots of cruft to find out how it's supposed to work (especially if you fail to convince the reader that your approach will work). That's typically a death sentence for your paper!

> [!SUMMARY]
> The intro must convey that you meet the general criteria for a systems paper: identified a real problem (motivate that it is real and interesting), come up with a solution (give a rough idea what the solution looks like) and actually solved the problem (high-level summary of results).

#### Background

This is where you go into details about the motivation for your work, and any other background required to understand it.

#### What you've actually done

The best general advise here is to be concise, precise and easy to follow.

Use diagrams where possible to explain things. Good diagrams help the reviewer getting though your paper quickly, without missing important content. If it can be explained with the help of a diagram, it should.

#### Evaluation

This is where the rubber hits the road: You now have to prove that you've actually done it (solved your problem) and done so in a convincing way. This means finding the right evaluation criteria—meaningful benchmarks which demonstrate that you have something useful. It also means looking good on those benchmarks.

I intentionally said “prove”: The evaluation isn't about just going through motions of showing some numbers, it must instill confidence in the reader that your solution really is what you claim it is. If you are not doing your best to show that your solution is up to scratch in every respect, the reviewer will suspect that you're trying to hide something. So, your evaluation needs to be pro-active in a sense that it needs to anticipate what problems the reader might suspect, and deal with them head-on.

Also, keep in mind that any improvement must satisfy a progressive as well as a conservative criterion (and your evaluation must show this). The progressive criterion requires that you demonstrate significant improvement with respect to the problem you have identified. The conservative criterion requires that you demonstrate that you have not worsened the situation in all the other circumstances people may care about.

#### Related work

The most important role of the related-work section is to show that you know the field, and are familiar with all the relevant contributions made by others.

**Don't fall into the trap of trying to make prior work look bad in order to justify your own.** While it is true that some bad work gets published, and occasionally some badness provides the motivation for your work, be very careful there. **State, as neutrally as possible, what the prior work has achieved, and, where relevant, its limitations.**

The normal assumption is that **the prior work is good, and you're taking it further**.

An important aspect of this last advice is that you must have carefully read and understood the work you are citing. Don't cite a paper just because it's the standard reference and everyone cites it.

READ IT CAREFULLY.

#### Conclusions and Future Work

Now the reader knows everything, and this is your last chance to press what you think are your main achievements. Don't over-do it, and be brief! Also, re-visit some of the limitations and what can be done to address them.

### Formatting

- Don't use microscopic fonts in figures! People tend to be a bit more relaxed about enforcing font sizes in figures and tables (I wish the weren't), but it is an annoyance having to review a paper where you need a magnifying glass to read the figures.

These days much reviewing is done on tablets rather than hardcopy (I do all my reviewing this way), and it's easier to magnify things. However, if I have to magnify your figure, it means you're cheating by helping yourself to additional space. I do not like cheats, and most other reviewers don't like them either.

[^1]: [Gernot's Guide to Technical Writing](https://gernot-heiser.org/style-guide.html#thes)
