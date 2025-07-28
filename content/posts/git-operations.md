---
title: "Git Operations: Rebase, Squash, and Cherry-Pick"
tags:
  - Dev
date: 2025-05-31
showtoc: true
---

> In multi-branch development, simply using git merge is not enough!

> [!HINT]
> 把单次提交看做为针对于父提交新增的改动 (delta) 可能会好理解一点:
>
> - 应用一个提交到目标提交上, 就是把这个提交新增的改动应用到目标对应的快照上, 形成一次新提交

### git rebase

#### 核心思想

**线性化历史**：将一个分支的提交「平滑地」移动到另一个分支的最前端，去除多余的 merge 提交，形成干净的、线性的提交序列。

#### 常见场景

保持分支历史整洁：feature 分支开发过程中不断从 main 分支拉取更新，希望最终合并时无杂乱的 merge 提交。

冲突提前解决：在本地预先处理冲突，避免在 Pull Request 合并时出现惊喜。

同步上游仓库：fork 后想把上游主仓库最新改动合并到自己分支。

#### 具体示例

1）场景：feature 分支基于较早的 main，现在要把 main 更新带过来。

```bash
* c3f2a1b (feature) Add feature X part 2
* b1d4e5f (feature) Add feature X part 1
| * g6h8i9j (main) Fix typo in README
| * f5e7d6c (main) Add new logo
|/
* a0b1c2d Initial commit
```

执行:

```bash
git checkout feature
git rebase main
```

结果：

```bash
* c3f2a1b' (feature) Add feature X part 2
* b1d4e5f' (feature) Add feature X part 1
* g6h8i9j (main) Fix typo in README
* f5e7d6c (main) Add new logo
* a0b1c2d Initial commit
```

> 如果 feature 和 main 都改了同一行，rebase 时就要本地解决冲突，git rebase --continue。

## git squash

### 核心思想

- 压缩提交：将多个相关的小提交合并成一个更有意义的、可读性更高的提交。
- 语义化历史：用更高层次的「故事」去组织一系列琐碎改动。

### 常见场景

Clean up：在 feature 分支开发完成前，把「调试」「格式调整」「小改动」等合并成一个或少数几个提交。

Pull Request 美化：在提交 PR 之前，对自己的提交历史做整理，便于 reviewer 一眼看懂主要改动。

### 具体示例

假设我们在 feature 分支上做了三个小改动：

```bash
* d4a1c32 (feature) tweak UI padding
* 7c9e4b0 (feature) fix typo in function name
* f2b8a11 (feature) initial layout for settings
* 17b221f Initial commit
```

执行交互式 rebase：

```bash
git checkout feature
git rebase -i HEAD~3
```

这会打开一个编辑器，显示：

```bash
pick f2b8a11 initial layout for settings
pick 7c9e4b0 fix typo in function name
pick d4a1c32 tweak UI padding
```

将你想要合并到前一个提交的那些提交的 pick 改为 squash（或 s）：

```bash
pick f2b8a11 initial layout for settings
s 7c9e4b0 fix typo in function name
s d4a1c32 tweak UI padding
```

最后得到一个合并后的提交：

```bash
* 5e6f7a8 (feature) Add settings layout with UI tweaks and typo fixes
* 17b221f Initial commit
```

## git cherry-pick

### 核心思想

- 有选择地搬运提交：从一个分支上挑出一个或多个特定提交，应用到当前分支。
- 零散补丁：无需合并整条分支，只要搬过来需要的改动。

### 常见场景

> [!SUMMARY]
> 常见场景: **在不同分支之间同步同一个改动**

热修复：在 main 分支上进行紧急修复后，需要把这个补丁同步到旧的 release 分支。

功能回退：某个功能做在 dev 分支，后来决定暂时不用，但又想把其中某次单独改动保留到 main。

跨分支复用：不同 feature 分支里有类似需求，把一个分支的提交搬到另一个分支使用。

### 具体示例

你在 develop 分支或某个功能分支上修复了一个严重错误，并且需要立即将这个修复应用到你的 release 分支，而不想合并整个 develop 分支

```bash
* d4c3b2a (develop) Add cool new feature
* c3b2a1f (develop) Fix critical bug #123  <-- 我们需要这个提交
* b2a1f0e (develop) Start new feature
| * z8y7x6w (main) Last release
|/
* a0b1c2d Initial commit
```

你只想将 Fix critical bug #123 (提交 c3b2a1f) 应用到 main 分支:

```bash
git checkout main
git cherry-pick c3b2a1f
```

main 分支的历史记录将如下所示:

```bash
* c3b2a1f' (main) Fix critical bug #123
* z8y7x6w (main) Last release
| * d4c3b2a (develop) Add cool new feature
| * c3b2a1f (develop) Fix critical bug #123
| * b2a1f0e (develop) Start new feature
|/
* a0b1c2d Initial commit
```

## How to understand?

我们在描述这三种操作时, 总会提到 "把提交应用到xxx"

然后提交是一个快照, 把一个快照应用到另一个快照, 是什么意思呢?

可以把 cherry-pick、rebase 这类“在快照模型下”的操作，都看成三个核心步骤：

- 从某个已有提交 A 去算出它相对于它父提交 P 的差异（diff）
- 把这个 diff 补丁“贴”到你当前 HEAD 指向的提交上，得到一个新的提交

> HEAD 可以认为是指向当前分支的最新提交

先以最简单的 cherry-pick 为例：

- P → A 是 original branch 上的一次提交，tree(P) 到 tree(A) 的差异我们记作 ΔPA。
- 当前分支 HEAD 指向 B，tree(B) 是当前的快照。

执行 cherry-pick A：

- Git 读取 commit A 的 parent P 和它自己的 tree A，计算 ΔPA = tree(A) – tree(P)。
- 在工作区把 ΔPA 应用到 tree(B)，得到新快照 tree(B′) = tree(B) + ΔPA。
- 创建一个新提交 C，内容是 tree(B′)、父提交指向 B，并把 HEAD 移到 C。

结果：你在当前分支上多了一个“等价于 A 改动”的新提交 C，但它的 hash、parent 都和 A 不同，保持了分支的独立历史。

再以 git rebase 为例:

假设你在 feature 分支上，有一系列提交 P → A → B → C（父链关系依次是 P→A→B→C），而 master 分支 HEAD 在 M。你想把 feature 上的改动“搬”到 M 之后。

执行 rebase：

- Git 先把 A、B、C 这三次“快照差异”依次提取出来：
  - ΔPA = tree(A) – tree(P)
  - ΔAB = tree(B) – tree(A)
  - ΔBC = tree(C) – tree(B)
- 然后依次把这三份补丁 ΔPA、ΔAB、ΔBC “贴”到 master 的快照 tree(M)：
  - tree(M₁) = tree(M) + ΔPA → commit A′ (父 = M)
  - tree(M₂) = tree(M₁) + ΔAB → commit B′ (父 = A′)
  - tree(M₃) = tree(M₂) + ΔBC → commit C′ (父 = B′)
- 最后把 feature 分支的指针移动到 C′，并把 HEAD 切到新的 feature。

这样，你不仅把改动“同步”到新的基线 M 上，而且生成了一组全新的快照（A′/B′/C′），保持线性历史，删掉了原来的 P→A→B→C 旧链

## What about jj-vcs

### jj rebase -> git rebase

```bash
jj rebase -s <source_commit_id> -d <destination_commit_id>
```

For example, jj rebase -s M -d O would transform your history like this (letters followed by an apostrophe are post-rebase versions):

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
