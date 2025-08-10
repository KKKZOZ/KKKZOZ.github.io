---
title: "Git Operations: Rebase, Squash, and Cherry-Pick"
tags:
  - Dev
date: 2025-05-31
showtoc: true
weight: 10
draft: true
---

## What about jj-vcs

### jj rebase -> git rebase

```bash
jj rebase -s <source_commit_id> -d <destination_commit_id>
```

For example, `jj rebase -s M -d O` would transform your history like this (letters followed by an apostrophe are post-rebase versions):

```bash
O           N'
|           |
| N         M'
| |         |
| M         O
| |    =>   |
| | L       | L
| |/        | |
| K         | K
|/          |/
J           J
```

### jj squash -> git squash

```bash
@  xrnotmor kkkzoz@qq.com 2025-05-31 19:20:11 4f515fd4
│  D
○  xwvsolxp kkkzoz@qq.com 2025-05-31 19:19:57 811e63a7
│  C
○  urtyqupy kkkzoz@qq.com 2025-05-31 19:19:45 22f25b64
│  B
○  mwtsztxw kkkzoz@qq.com 2025-05-31 19:19:27 a552b9bc
│  A
◆  zzzzzzzz root() 00000000
```

可以用 `jj squash --from ur::xr --to mw -m "A-D"`

### jj duplicate -> git cherry-pick

```bash
jj duplicate <commit_id>
```

会在当前工作副本的位置创建一个新的提交，该提交包含与 `<commit_id>` 相同的变更内容

或者使用一个组合:

```bash
jj new <commit_id>
jj rebase -s <newly_created_commit> -d

```
