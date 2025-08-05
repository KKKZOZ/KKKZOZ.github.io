---
title: "jj-vcs Tutorial"
tags:
  - Dev
date: 2025-04-04
showtoc: true
weight: 10
---


## Basic Operations

### Interact with Changes

`jj-vcs` treats each unit of work as a "change." You can interact with changes through commands that create, switch, and record them.

```shell
# Create a change whose ancestor is <change-id>
# This operation will check out to the new change
# You can disable the behavior by add "--no-edit"
jj new <change-id>

# Update the change description or other metadata
jj desc -m "<message>"

# Update current change's description and create a new change on top
jj commit -m "<message>"

# "Check out" the change
jj edit <change-id>
```

### Show Repo Status

```shell
# Show the current change
jj st

# Show the current change's log
jj log
```

## Workflows

### The Squash Workflow

> If you are familiar and comfortable with git's index, you can try this workflow to get yourself started with `jj-vcs`.
>
> you can think of `jj squash` as a way to move changes from the index into a commit.

The workflow goes like this:

- We describe the work we want to do.
- We create a new empty change on top of that one.
- As we produce work we want to put into our change, we use `jj squash` to move changes from @ into the change where we described what to do.

```shell
jj desc -m "the goal we want to achieve"
jj new

# Editing your code, then
jj squash

# All your changes are stored in the "goal" commit
```

### Working with GitHub

#### Repo init

> Suppose you already create an empty repository on GitHub, and you want to use `jj-vcs` to manage it.

```shell
jj git init --colocate

jj git remote add origin git@github.com:KKKZOZ/jj-vcs-test.git

jj bookmark set main -r @

jj git push --allow-new --branch main

# Or
jj git push --allow-new

```

- jj 默认情况下拒绝在远程仓库 (origin) 上创建一个新的、它不认识的 "远程书签"
- 创建之后可以直接使用 `jj git push`

#### Git Push

推送当前的更改:

对应到 `git` 中:

- `git add --all`
- `git commit -m "commit message"`
- `git push`

```shell
# Suppose you are already in the change you want to commit
# And the remote branch name is main
jj desc -m "<commit message>"

jj bookmark set <branch-name> -r @

jj git push
```

#### Git Pull

同步远端的更改:

对应到 `git` 中:

- `git fetch`

```shell
jj git fetch
```

> 目前暂时没有对应 `git pull` 的 jj 命令

> [!NOTE]
> 如果你在 IDE 或者 VSCode 中打开了对应的仓库, 这些应用默认会定期执行 `git fetch`, 所以有些时候你可以发现你只需要执行类似于 `jj st`, `jj log` 之类的命令就能同步远端的更改

执行完后的 `jj log` 大概是这样:

```shell
❯ jj log
@  xtrxlwqk kkkzoz@qq.com 2025-04-23 18:58:29 96c6d123
│  (empty) (no description set)
│ ◆  tyxpntnk 1206668472@qq.com 2025-04-23 19:00:39 main b1d6f198
├─╯  Create README.md
◆  qzpuxqzw kkkzoz@qq.com 2025-04-23 18:39:26 git_head() 9b53401e
│  project setup
~
```

- 和 `git` 最不一样的地方就是**远端更新会在另一个 "branch" 上**

后续可以使用 `jj rebase`

```shell
> jj rebase -d t

> jj log
jj log
@  xtrxlwqk kkkzoz@qq.com 2025-04-23 19:13:01 29370139
│  (empty) (no description set)
◆  tyxpntnk 1206668472@qq.com 2025-04-23 19:00:39 main git_head() b1d6f198
│  Create README.md
~
```

> [!QUESTION] Where is my commit, why is it not visible in jj log?
> you should be aware that jj log only shows a subset of the commits in the repo by default.
> Most commits that exist on a remote are not shown. **Local commits and their immediate parents (for context) are shown.** The thinking is that you are more likely to interact with this set of commits.

可以使用 `jj log -r ..` 查看完整的记录

如果你和远端相差不止一个 change, 比如像下面这样:

```shell
> jj log
@  tmmvvzkn kkkzoz@qq.com 2025-04-23 19:38:07 726f6ed6
│  iteration 2
○  xtrxlwqk kkkzoz@qq.com 2025-04-23 19:37:34 git_head() a8a86bfd
│  iteration 1
│ ◆  xzwwyvxu 1206668472@qq.com 2025-04-23 19:38:47 main e17f2a78
├─╯  new feature
◆  tyxpntnk 1206668472@qq.com 2025-04-23 19:00:39 b1d6f198
│  Create README.md
~
```

此时需要更改我们的 `jj rebase` 指令:

```shell
> jj rebase -s xt -d main
Rebased 2 commits onto destination
Working copy  (@) now at: tmmvvzkn 4e13c26d iteration 2
Parent commit (@-)      : xtrxlwqk a91a6c31 iteration 1
Added 0 files, modified 1 files, removed 0 files
> jj log
@  tmmvvzkn kkkzoz@qq.com 2025-04-23 20:05:12 4e13c26d
│  iteration 2
○  xtrxlwqk kkkzoz@qq.com 2025-04-23 20:05:12 git_head() a91a6c31
│  iteration 1
◆  xzwwyvxu 1206668472@qq.com 2025-04-23 19:38:47 main e17f2a78
│  new feature
~
```

- 当使用 `-s` 指定一个提交时，jj 会选择这个提交及其所有后代作为源进行 rebase
- 其他情况(`-b` 或者 `-r`) 可以参照[这里](https://jj-vcs.github.io/jj/latest/cli-reference/#jj-rebase)

#### Create a PR

```shell
# Create a new change
jj new

# Implement the feature
...

# Describe it
jj desc -m "<commit message>"


# Push to remote
jj git push -c @

Creating bookmark push-ypunlqtzukkp for revision ypunlqtzukkp
Changes to push to origin:
  Add bookmark push-ypunlqtzukkp to 05b31f99cd92
remote: Resolving deltas: 100% (5/5), completed with 1 local object.
remote:
remote: Create a pull request for 'push-ypunlqtzukkp' on GitHub by visiting:
remote:      https://github.com/KKKZOZ/jj-vcs-test/pull/new/push-ypunlqtzukkp
remote:

# Ready to go!

```

- `-c @` 的意思是 create a new branch, from the revision @

## Advance Operations

### Squash

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

The most direct `jj squash`: merge current change (@) into its parent:

> You can use `-m <MESSAGE>` to provide a description for the merged revision directly, instead of opening a text editor to enter it.

```shell
@  suvuslnm kkkzoz@qq.com 2025-05-31 19:22:56 81fabb20
│  (empty) (no description set)
○  xwvsolxp kkkzoz@qq.com 2025-05-31 19:22:54 d6e7a10e
│  C
○  urtyqupy kkkzoz@qq.com 2025-05-31 19:19:45 22f25b64
│  B
○  mwtsztxw kkkzoz@qq.com 2025-05-31 19:19:27 a552b9bc
│  A
◆  zzzzzzzz root() 00000000
```

You can use `jj squash -r <rev>` to specify which change to merge into its parent:

```shell
jj squash -r u
❯ jj log
@  xrnotmor kkkzoz@qq.com 2025-05-31 19:23:59 9bea0f3d
│  D
○  xwvsolxp kkkzoz@qq.com 2025-05-31 19:23:59 ea4deb9c
│  C
○  mwtsztxw kkkzoz@qq.com 2025-05-31 19:23:56 548a20de
│  A
◆  zzzzzzzz root() 00000000

```

You can also use `jj squash --from u::xr --to m -m "A-D"`

```shell
❯ jj squash --from u::xr --to m -m "A-D"
Working copy  (@) now at: rvkxwott fa6c9a22 (empty) (no description set)
Parent commit (@-)      : mwtsztxw 0fad5eb1 A-D
❯ jlog
@  rvkxwott kkkzoz@qq.com 2025-05-31 19:50:29 fa6c9a22
│  (empty) (no description set)
○  mwtsztxw kkkzoz@qq.com 2025-05-31 19:50:29 0fad5eb1
│  A-D
◆  zzzzzzzz root() 00000000
```

You can also squash non-consecutive revisions:

```shell
❯ jj squash --from xw::xr --to m -m "A,C,D"
Rebased 1 descendant commits
Working copy  (@) now at: ptmomxys 6769fa46 (empty) (no description set)
Parent commit (@-)      : urtyqupy 996fe48a B
❯ jj log
@  ptmomxys kkkzoz@qq.com 2025-05-31 19:51:48 6769fa46
│  (empty) (no description set)
○  urtyqupy kkkzoz@qq.com 2025-05-31 19:51:48 996fe48a
│  B
○  mwtsztxw kkkzoz@qq.com 2025-05-31 19:51:48 12a76d5a
│  A,C,D
◆  zzzzzzzz root() 00000000
```

### Revsets

> `jj-vcs` supports a functional language for selecting a set of revisions. Expressions in this language are called "revsets".

Suppose we have the following linear commit history, from oldest to newest:

R ← A ← B ← C ← D ← E

(where R is the root/earliest commit, and E is the latest commit)

- `x..`: `(x, E]`
- `x::`: `[x, E]`
- `..x`: `(R, x]`
- `::x`: `[R, x]`
- `x..y`: `(x, y]`
- `x::y`: `[x, y]`

Metal model:

- `..` 都是左开右闭区间
- `::` 都是闭区间

## Common FAQ

### How to untrack a file in jj?

```shell
jj file untrack my_secret.txt
```

即使该文件之前已经被 jj-vcs 跟踪，执行此命令后，jj-vcs 将不再记录该文件的后续更改

### How do I resume working on an existing change?

当你想修改的不是当前最新的提交 (@),而是历史中的某个旧提交时, 有两种方案:

> 场景: 假设你的提交历史是 A -> B -> C，你现在想修改提交 A

1. `jj new <rev>` then `jj squash`
2. `jj edit <rev>`

#### `jj new <rev>` then `jj squash`

1. `jj new <rev>`:
    - 这个命令会在你指定的旧提交 `<rev>` (这里是 `A`) 的基础上创建一个**新的、空的**提交（我们称之为 `A'`）。
    - 你的工作区会切换到这个新的提交 `A'`。
    - 重要的是，原来的提交 `A` 以及其后续的 `B` 和 `C` 仍然存在并且没有被直接修改。你的 `jj log` 可能会看起来像这样（具体展现形式可能略有不同，但概念如此）：

        ```shell
        A -> B -> C
        \
         A'(@)  <-- 你现在在这里工作
        ```

    - 你现在可以在 `A'` 上进行你想要的修改。这些修改是独立的，不会立即影响 `A`, `B`, `C`。

2. `jj squash`:
    - 当你完成了在 `A'` 上的所有修改后，`jj squash` 命令会将 `A'` 中的**所有**更改合并回你最初想要修改的那个旧提交 `A`。
    - 这实际上是“重写”了提交 `A`，形成了一个新的版本（我们称之为 `A_updated`），这个 `A_updated` 包含了原始 `A` 的内容加上你在 `A'` 中所做的修改。
    - 由于 `A` 被更新成了 `A_updated`，jj 的自动变基机制会启动，将后续的提交 `B` 和 `C` 变基到 `A_updated` 之上，形成 `B'` 和 `C'`。
    - 最终的提交历史会变成： `A_updated -> B' -> C'`。

> [!SUMMARY] 这种方法的优点
>
> - **清晰性**: 你在一个全新的提交 (`A'`) 上工作，所做的修改非常明确。你可以很容易地看到你具体改了什么（通过比较 `A'` 和 `A`，或者查看 `A'` 本身的内容）。
> - **隔离性**: 在你明确执行 `jj squash` 之前，原始的提交链 (`A -> B -> C`) 是不受影响的。这给了你一个“实验”的空间。

#### `jj edit <rev>`

- 这个命令会直接将你的工作区切换到指定的旧提交 `<rev>` (这里是 `A`)。
- 你**直接在提交 `A` 上进行修改**。
- 当你进行修改并保存后，这些修改会**立即更新**提交 `A`。也就是说，原始的 `A` 被一个新的 `A_modified` 替换掉。
- 同样，jj 的自动变基机制会启动，将后续的 `B` 和 `C` 变基到 `A_modified` 之上，形成 `B'` 和 `C'`。
- 最终的提交历史会变成： `A_modified -> B' -> C'`。

**潜在问题：**

- **难以分辨具体修改**: 因为你是直接修改提交 `A`，而不是在一个新的提交中进行。如果你做了很多细小的修改，之后可能很难清楚地回忆起或分辨出你到底在这次 `edit` 操作中具体改变了 `A` 的哪些部分。不像 `jj new` + `jj squash` 那样，你有一个明确的 `A'` 来展示所有的增量修改。
- 因为 `jj edit` 是直接修改，没有一个“草稿”阶段，所以出错的风险相对高一些。
