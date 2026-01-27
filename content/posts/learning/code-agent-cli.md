---
title: "Code Agent CLI Notes"
date: 2026-01-27
toc: true
weight: 10
draft: true
---

## Shell Snapshot

在 OpenAI Codex（尤其是 Codex CLI） 里，shell_snapshot 指的是一个「Shell 环境快照」功能：把你当前 shell 在加载完登录脚本/初始化脚本之后的环境（最典型就是 PATH 等环境变量）记录成快照，后续 Codex 反复执行命令时就可以复用这份环境，从而避免每次都重新跑一遍 ~/.bashrc、~/.zshrc、/etc/profile 之类的初始化流程，减少开销、让重复命令更快
