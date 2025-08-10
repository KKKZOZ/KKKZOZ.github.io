---
title: "Git Essentials"
tags:
  - Dev
date: 2025-08-08
showtoc: true
weight: 10
---

> Essential Understandings about Git.

## Basic Concept

### Working Directory & Staging Area & Branch

- **Working Directory**
  - 是你当前正在进行工作的、实实在在的磁盘文件集合
  - 可以是“干净的”，即与仓库中某个版本完全一致；也可以是“脏的”，即包含了修改过或未跟踪的文件
- **Staging Area**
  - 是一个临时区域，用于保存即将提交到版本库的文件快照
  - 通过 `git add` 命令将工作目录中的修改添加到暂存区
- **Branch**
  - 是 Git 中用于并行开发的核心概念
  - 每个分支都是一个独立的开发线，可以在上面进行修改而不影响其他分支

### Remote & Upstream

### Tag

git tag 是一个指向某个特定提交 (commit) 的指针，主要用来标记项目历史中重要的时间点。最常见的用途就是标记软件的版本发布点，例如 v1.0、v2.1.3 等。

与分支 (branch) 不同，分支的指针会随着新的提交而不断向前移动，而标签则会永远固定在它被创建时指向的那个提交上。

常用操作如下：

```shell

# 列出所有标签
git tag

# 按模式列出标签
git tag -l "v0.4.*"

# 创建标签
git tag -a v0.4.0 -m "Version 0.4.0"

# 推送特定标签
git push origin v1.5

# 推送所有标签
git push origin --tags

# 删除本地标签：
git tag -d v1.4

# 删除远程标签：
git push origin --delete v1.4

```

> [!QUESTION] `git tag -a` 是什么

`git tag -a` 中的 `-a` 选项表示创建一个"附注标签"(annotated tag)。这是 Git 中两种主要标签类型之一, 另一种是轻量标签(lightweight tag)。

附注标签(Annotated Tag):

- 使用 -a 选项创建
- 存储完整的对象，包含标签名、电子邮件、日期、标签信息等
- 可以使用 GPG 签名和验证
- 通常用于发布版本等重要节点
- 创建命令: `git tag -a v1.4.0 -m "Version 1.4"`

轻量标签(Lightweight Tag):

- 不使用 `-a`、`-s` 或 `-m` 选项
- 只是特定提交的引用
- 本质上是一个不会改变的分支
- 创建命令: `git tag v1.4-lw`

## Multi Branch Development

### Git Checkout

假设从 branch a 切换到 branch b:

- Changes not staged for commit:
  - 会被带到 branch b. Git 会尝试将这些修改应用在 branch b 上。
  - 前提是：这个切换动作不会导致你的修改丢失。如果 branch b 上同一个文件的内容和 branch a 不一样，Git 会阻止你切换，并提示你这个修改会被覆盖。

- Untracked files:
  - 原封不动地出现在 branch b 的工作区里。
  - Git 在切换分支时，通常不会关心也不触碰这些它不负责管理的文件。

> [!NOTE]
> Staging Area 是属于整个仓库的, 不是某个特定分支的。所以在切换分支时, Staging Area 会保持不变, 看起来像是被"带"到了另一个分支。
> [!HINT]
> 把单次提交看做为针对于父提交新增的改动 (delta) 可能会好理解一点:
>
> - 应用一个提交到目标提交上, 就是把这个提交新增的改动应用到目标对应的快照上, 形成一次新提交

### Git Rebase

> [!NOTE] 核心思想
> **线性化历史**：将一个分支的提交「平滑地」移动到另一个分支的最前端，去除多余的 merge 提交，形成干净的、线性的提交序列。

> [!HINT]
> 把单次提交看做为针对于父提交新增的改动 (delta) 可能会好理解一点:
>
> - 应用一个提交到目标提交上, 就是把这个提交新增的改动应用到目标对应的快照上, 形成一次新提交

常见场景:

- 保持分支历史整洁：feature 分支开发过程中不断从 main 分支拉取更新，希望最终合并时无杂乱的 merge 提交。
- 冲突提前解决：在本地预先处理冲突，避免在 Pull Request 合并时出现惊喜。
- 同步上游仓库：fork 后想把上游主仓库最新改动合并到自己分支。

具体示例:

场景：feature 分支基于较早的 main，现在要把 main 更新带过来。

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
# 把 main 的更新带到 feature 分支
# 重写的是 feature 分支的历史
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

> 如果 feature 和 main 都改了同一行，rebase 时就要本地解决冲突，`git rebase --continue`.

#### rebase vs merge

> See [here](https://stackoverflow.com/questions/16666089/whats-the-difference-between-git-merge-and-git-rebase) for reference.

Git rebase is closer to a merge. The difference in rebase is:

- the local commits are removed temporally from the branch.
- run the git pull
- insert again all your local commits.

So that means that all your local commits are moved to the end, after all the remote commits. If you have a merge conflict, you have to solve it too.

![merge-rebase](/images/merge-rebase.png)

`git rebase` helps create **a linear project history** by transferring your feature branch commits to the top of the main branch, effectively "replaying" changes as if they were applied sequentially after the main branch's most recent commits. This linearity makes the history easier to read and understand.

> [!CAUTION]
> DO NOT rebase in public branches!

### Git Squash

> [!NOTE] 核心思想
>
> - 压缩提交：将多个相关的小提交合并成一个更有意义的、可读性更高的提交。
> - 语义化历史：用更高层次的「故事」去组织一系列琐碎改动。

常见场景:

- Clean up：在 feature 分支开发完成前，把「调试」「格式调整」「小改动」等合并成一个或少数几个提交。
- Pull Request 美化：在提交 PR 之前，对自己的提交历史做整理，便于 reviewer 一眼看懂主要改动。

具体示例:

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

### Git Cherry-pick

> [!NOTE] 核心思想
>
> - 有选择地搬运提交：从一个分支上挑出一个或多个特定提交，应用到当前分支。
> - 零散补丁：无需合并整条分支，只要搬过来需要的改动。

常见场景:

> [!SUMMARY]
> 常见场景: **在不同分支之间同步同一个改动**

- 热修复：在 main 分支上进行紧急修复后，需要把这个补丁同步到旧的 release 分支。
- 功能回退：某个功能做在 dev 分支，后来决定暂时不用，但又想把其中某次单独改动保留到 main。
- 跨分支复用：不同 feature 分支里有类似需求，把一个分支的提交搬到另一个分支使用。

具体示例:

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

### Summary

我们在描述 `rebase`, `squash`, `cherry-pick` 这三种操作时, 总会提到 "把提交应用到xxx"

> ![QUESTION] 提交是一个快照, 把一个快照应用到另一个快照, 是什么意思呢?

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

这样，不仅把改动“同步”到新的基线 M 上，而且生成了一组全新的快照（A′/B′/C′），保持线性历史，删掉了原来的 P→A→B→C 旧链

### Git Worktree

`git worktree` 命令允许你在一个 Git 仓库中同时 check out 多个分支到不同的目录。

可以把每个 worktree 看作是一个“链接”到主 `.git` 数据库的独立工作目录。它们共享同一个仓库历史、对象和引用（refs），但各自拥有独立的工作区和暂存区。

> [!QUESTION]- 为什么要使用 Git Worktree?
> 想象一下这个情景：
>
> 你正在一个名为 feature-A 的分支上开发一个复杂的新功能，代码写了一半，还没办法提交。突然，线上出现了一个紧急的 Bug，需要你立刻创建一个 hotfix 分支来修复。
>
>在没有 worktree 的情况下，你可能会这么做：
>
> - `git stash`: 把你当前做到一半的修改暂存起来。但 stash 可能会很乱，如果你忘了暂存了什么，或者之后恢复时有冲突，会很麻烦。
> - `git commit`: 创建一个临时的、不完整的提交（例如 commit message 为 "WIP"）。这会污染你的提交历史。
> - `git clone`: 在另一个地方重新 clone 一遍整个仓库。这既浪费时间又占用大量硬盘空间，而且你还需要手动同步两个仓库的更新。

> 这些方法都有各自的缺点。而 git worktree 正是解决这类问题的优雅方案。

Git Worktree 的主要优点

- 高效和节省空间：它比重新克隆一个完整的仓库快得多，也节省得多。因为所有 worktree 都共享同一个底层的 .git 数据库，不需要重复下载和存储对象。
- 隔离环境：每个 worktree 都有自己独立的工作文件和暂存区。在一个 worktree 中的修改、暂存、提交不会影响到另一个。
- 并行工作：你可以同时在不同的分支上进行不同的任务。比如：
  - 在一个 worktree 中开发新功能。
  - 在另一个 worktree 中修复紧急 Bug。
  - 在第三个 worktree 中进行 Code Review, 或者运行耗时的测试。

常用命令:

```shell
# 语法: git worktree add <路径> <分支名>
# 创建一个名为 "feature-B" 的新分支，并检出到 ../feature-B-worktree 目录
git worktree add ../feature-B-worktree -b feature-B

# 列出所有 worktree
git worktree list

# 移除一个 worktree
git worktree remove ../feature-B-worktree
```

实际操作示例可以看[llm-generated-content](../llm-generated-content.md#q-能否用一个更详细的例子说明-git-worktree)

## Misc

### 如何区分 .gitignore 中忽略的是文件还是文件夹

`.gitignore` 的核心机制是 Path Pattern Matching, 它并不关心被匹配到的是文件还是文件夹，它只关心你写的 pattern 能否匹配上某个路径。

真正的区别在于你如何使用特殊字符（尤其是斜杠 `/`）来约束你的匹配模式。

1. 结尾的斜杠: **只匹配目录**
    - 如果一个模式以 `/` 结尾，那么它只会匹配同名的目录，绝不会匹配文件。
    - `node_modules/`
        - 会匹配：所有名为 `node_modules` 的目录，例如 `./node_modules/`、`./src/node_modules/`。
        - 不会匹配：任何名为 `node_modules` 的文件。
2. 不包含任何斜杠: **匹配任意位置的同名文件或目录**
    - 当一个模式不包含任何斜杠时，它会被当做一个 glob 模式，在整个代码库的任意层级进行匹配。
    - `config.json`
        - 会匹配：
        - 根目录下的文件: `./config.json`
        - 子目录下的文件: `./src/config.json`
        - 甚至会匹配同名目录: `./docs/config.json/` (如果存在)

1. 开头的斜杠: **仅匹配仓库根目录**
    - 如果一个模式以 `/` 开头，它会将匹配范围锁定在 `.gitignore` 文件所在的目录 (通常是仓库的根目录)。
    - `/config.json`
        - 只会匹配：根目录下的 config.json 文件 (./config.json)。
        - 不会匹配：./src/config.json。

> [!TIP]
> 当你忽略一个文件夹时（例如 node_modules/），该文件夹下的所有内容（包括子文件夹和文件）都会被自动忽略

> ![QUESTION]- 如果我要忽略一个 executor 二进制文件, 但不希望忽略 executor 文件夹下的其他文件, 应该怎么写 `.gitignore`?
>
> ```shell
> # 1. 忽略所有名为 "executor" 的路径（包括文件和文件夹）
> executor
># 2. 但是，不要忽略名为 "executor" 的文件夹本身
> !executor/
> ```

### 如何确定一个文件是否被 .gitignore 忽略了

1. 使用 git ls-files 检查特定文件

```shell
git ls-files 文件名
```

- 如果文件被追踪，会显示文件名
- 如果没有输出，说明文件未被追踪

2. 使用 git check-ignore 检查文件是否被忽略

```shell
git check-ignore -v 文件名
```

- 如果有输出，说明文件被 .gitignore 规则忽略
- 如果没有输出且返回值为 1，说明文件没有被忽略规则匹配

### 作为仓库所有者，如何修改别人的 PR?

#### Using gh cli

> 假设这个 PR 编号为 #20

```shell
gh pr checkout 20

# edit the files as needed

git commit -am "fix"
git push
```

#### Using git commands

1. 拉取 Pull Request 的内容

GitHub 为每个 PR 提供了一个特殊的 ref，你可以通过它来获取 PR 的代码，而无需知道对方的分支名或仓库地址。

对于 PR \#20，你可以使用以下命令将其代码拉取到一个新的本地分支（我们称之为 `pr-20`）：

```shell
# 格式: git fetch <主仓库名> pull/<PR号>/head:<新本地分支名>
git fetch origin pull/20/head:pr-20
```

- `origin`: 指向你的主远程仓库（即你 clone 下来的那个）。
- `pull/20/head`: 这是 GitHub 提供的特殊引用，指向 PR \#20 的头指针。
- `:pr-20`: 这会在你的本地创建一个名为 `pr-20` 的新分支，并将拉取下来的代码放在里面。

拉取成功后，切换到这个新分支：

```shell
git checkout pr-20
```

2. 修改和提交

这一步和你的原始流程完全一样。进行你需要的修改，然后提交：

```shell
# Make your changes to the files...
git commit -am "fix"
```

3. 推送修改

当你使用 `gh pr checkout` 时，它会自动设置好本地分支的 upstream，使其指向发起 PR 的那个用户的仓库和分支。这样你直接 `git push` 就能更新 PR。

但用 `git fetch` 创建的 `pr-20` 分支并不知道应该推向哪里。**所以必须手动将其推送到发起 PR 的那个仓库和分支**。

1. **找到贡献者的仓库地址和分支名**
    可以在 GitHub 的 PR 页面上找到这些信息。

      - **Fork URL**: 比如 `https://github.com/some-contributor/the-repo.git`
      - **Branch Name**: 比如 `feature-update`

2. **添加贡献者的仓库为一个新的远程地址（如果还没加过）**
    为了能推送到别人的仓库，需要先将其添加为一个 `remote`。通常用贡献者的用户名来命名。

    ```shell
    # 格式: git remote add <远程名> <仓库地址>
    git remote add some-contributor https://github.com/some-contributor/the-repo.git
    ```

3. **执行推送**
    把本地 `pr-20` 分支的改动，推送到 `some-contributor` 这个远程仓库的 `feature-update` 分支上。

    ```shell
    # 格式: git push <远程名> <本地分支>:<远程分支>
    git push some-contributor pr-20:feature-update
    ```

### How to use `git commit --amend`

`git commit --amend` 通常在以下场景使用：

1. 修复最后一次提交的拼写错误：

```bash
# 原提交信息打错了
git commit -m "fix: add user validaton"  # validation 拼错了
# 修复
git commit --amend -m "fix: add user validation"
```

2. 遗漏了文件或修改：

```bash
# 已经提交
git commit -m "feat: add login page"

# 发现忘了提交某个文件
git add forgotten_file.js
git commit --amend --no-edit
```

3. 合并琐碎修改：

```bash
# 已经提交
git commit -m "feat: implement login logic"

# 发现一个小问题需要修复
vim login.js  # 修复问题
git add login.js
git commit --amend --no-edit  # 直接合并到上一次提交
```

以上操作针对于本地提交，如果更改已经被 `git push` 到了远端仓库中, 则需要:

```bash
git push --force-with-lease origin main
```

即使使用 --force-with-lease，也可能会覆盖别人的工作：

`--force-with-lease` 的工作机制可以在 [[llm-generated-content]](../llm-generated-content.md#q---force-with-lease-的检查机制) 中查阅。

### How to undo last local commit

```shell
# 软重置，保留修改
git reset --soft HEAD~1

# 硬重置，丢弃修改
git reset --hard HEAD~1
```

### How to untrack a file in a git repo?

1. Add the File to .gitignore

比如说需要忽略所有的 `.bak` 文件

```shell
echo ".bak" >> .gitignore
```

2. Remove the File from Git's Tracking

```shell
git rm --cached <file>
# batch process
# untrack all files whose type is bak
fd --extension bak --type f -0 | xargs -0 git rm --cached
```

> 顺带说明一下这里为什么要使用 `-0`
>
> `-0` 表示以空字符 (\0) 作为输入分隔符，而不是默认的空格或换行符
> 如 `my file.bak`，如果不使用 `-0`，可能会被错误地解析为两个独立的文件 `my` 和 `file.bak`

3. Commit the Changes

```shell
git commit -m "Stop tracking .bak files"
```

### What are the best practices for naming git branches?

1. 使用前缀结构

使用前缀来表示分支的类型和用途，这样可以更直观地了解分支的目的。常见的前缀包括：

- `feature/`：用于新功能开发。例如，feature/user-authentication
- `bugfix/` 或 `fix/`：用于修复 bug。例如，bugfix/fix-login-issue
- `hotfix/`：用于紧急修复线上问题。例如，hotfix/urgent-payment-fix
- `release/`：用于发布准备和版本管理。例如，release/v1.0.0
- `test/`：用于测试相关的代码或功能。例如，test/api-performance

2. 使用简洁但具描述性的名字

分支名称应该简短但能准确描述该分支的目的。避免使用太笼统的名称，比如 new-feature，而是采用具描述性的命名，如 feature/user-login-ui.

> - 在 Git 中，建议使用连字符（-）而不是下划线（\_）或空格，这样分支名更易读，并且与常见的命名风格保持一致
> - 分支名称最好使用小写字母，避免使用大写字母或混合大小写，这可以保持风格一致且减少错误
