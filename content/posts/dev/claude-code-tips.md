---
title: "Claude Code Tips"
tags:
  - Dev
date: 2025-09-10
showtoc: true
weight: 10
draft: true
---

## Planning mode

Make use of the planning mode (shift-tab twice). This is a great way to get Claude to really think things through and design out the work before it dives in.

Ask Claude to write its final plan (from planning mode) along with a detailed todo list into a Markdown plan document when I’m at the “I approve this plan, go ahead and implement” stage before it leaves planning mode.

> It’s also an opportunity to clearly state which phases/tasks from the plan you want Claude to implement until it stops.

Ask Claude to update the Markdown doc as it works to update the status of which steps it completed, but I find it’s a mixed bag getting Claude to do a thorough job of updating it as it goes. But you can prompt Claude later to update the doc to reflect the state of the implemented work.

## Prompting

“Think” prompt keyword: Claude has some special behavior for spending more time (and tokens if you worry about that) thinking and researching and coming up with a plan or solution. "think" < "think hard" < "think harder" < "ultrathink." These are useful, I like using them. I ramp up the thinking level depending on the complexity of the task we’re planning together.

## Claude control

Feel free to type in something for Claude while it’s in the middle of working. If you see Claude make a wrong assumption, or you want to add a task to the current work, or want to give it more debug info, you are welcome to enter it in and Claude will pick up your additional prompt shortly after and incorporate it. Very handy.

`claude -r`: super useful command line option when launching Claude. This lets you rejoin an earlier Claude session. This is very handy if you rebooted or Claude crashed, or if you want to ask Claude to do a task in some earlier session where it built up very useful context on a particular topic.

## Configurations

CLAUDE.md is handy for instructions you want Claude to (nearly) always keep in mind.

`.claude/commands/` is very helpful. You can write prompt-like instructions into markdown files in this directory in your project, and then it automatically creates each as a new “/“ command in your project’s Claude sessions. Example commands I use: `/commit` (`.claude/commands/commit.md`) to git add my unstaged files, draft a commit message and git commit everything. Or /bl (.claude/commands/bl.md) with instructions to do a clean build, clear the existing output log files, launch my app, and then check the results of the log file output.

> [!NOTE] Project vs Global commands
>
> You can create those .claude/commands/ in your project's .claude directory, or you can create commands that will work across all of your Claude projects by putting them in your home directory's ~/.claude/commands directory.

## References

- [My Claude Code tips for newer users : r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/comments/1mpeefp/my_claude_code_tips_for_newer_users/)
