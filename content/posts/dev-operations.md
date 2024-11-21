---
title: "Dev Operations"
tags:
  - Dev
categories:
  - Pieces
date: 2024-11-06
toc: true
---

## 写在前面

本篇博客主要会记录和总结一些我平时在 Unix 环境下遇到的一些问题，包括但不局限于命令行，Git 操作等

## CommandLine

### Input/Output Redirection and Process Substitution

#### 输入/输出重定向

- 使用 `<` 将文件或数据传递给命令的标准输入
- 使用 `>` 将命令的标准输出写入到一个文件中
  - `>>` 表示追加到文件中

```bash
# 将 file.txt 的内容传递给 sort 命令进行排序
sort < file.txt
# 将 ls 的输出重定向到 output.txt 文件
ls > output.txt
# 使用 >> 将 echo 的输出追加到 output.txt 文件
echo "New entry" >> output.txt

```

#### 进程替换

**进程替换**（Process Substitution）是 Bash 提供的一种技术，用于将一个命令的输出作为文件名或标准输入来使用。这通常用于将命令的输出传递给其他接受文件或输入流的命令，允许我们实现更灵活的操作。

Bash 提供两种进程替换语法：

- `<(command)`：将命令 `command` 的输出重定向为输入流，可以把它当作一个“文件”来使用。
- `>(command)`：将输出重定向为命令 `command` 的输入流。

进程替换常见的使用场景包括将命令的输出传递给 `read`、`diff`、`cat` 等命令，尤其是那些期待文件路径或输入流的命令。

进程替换的工作原理是将命令的输出或输入重定向到一个临时文件或文件描述符（例如 `/dev/fd/63`），并返回该文件描述符的路径，使得调用的命令能够读取或写入这个文件描述符。

当使用 `<(command)` 或 `>(command)` 时，Bash 会自动创建一个临时文件描述符，并将其传递给外部命令。

因此，**进程替换的实际效果就是使用命令的输出（或输入）而无需创建中间文件**。

```bash
# 假设我们想比较两个命令的输出，可以使用 `diff` 命令与进程替换来实现：
diff <(ls /path/to/dir1) <(ls /path/to/dir2)

# 进程替换可以用于将多个值传递给 `read` 命令，允许直接从命令输出中读取多个变量
read -r var1 var2 < <(echo "hello world")

# 更实用的一个例子是在脚本中，实现函数返回值的效果
read -r native_latency native_p99 < <(run_iot_test "native" "$thread")
```

详细解释一下最后一个例子：

- `read` 从标准输入中读取数据
- 我们可以用类似于 `read <` 的形式利用输入重定向从文件中读取数据
- `run_iot_test` 函数中的最后一个语句为 `echo "$latency $p99"`，所以我们使用一个单独的 `<()` 来将这个函数的标准输出重新定向到一个临时文件中

看起来像是把一个程序的标准输出喂到了另一个程序的标准输入中，为什么不能使用管道呢？

考虑下面这个简单脚本：

```bash
#!/bin/bash

echo "hello world" | read -r var1 var2

echo -n $var1
echo -n $var2
```

`read` 是在一个子 shell 中执行的，因此变量 var1 和 var2 的赋值在子 shell 中完成，而子 shell 中的变量无法传递回父 shell，因此在最后的 echo 中无法获得 var1 和 var2 的值

要想在同一个 shell 中将输出重定向到另一个程序的标准输入中，可以使用进程替换的方法

> 也可以使用 **Here String** `<<<$()` > `<<< $(...)` 将命令的输出视为**一个单行字符串**输入。这种方式将命令的输出在进行重定向之前先执行命令替换（即 $(command)），然后将整个结果作为一行输入传递给 read。
> 如果 `command` 输出的是多行数据，这种写法只会读取第一行的内容，而后续的行将被忽略

### Why `rm "$tar_dir/iot-*.txt"` didn't work?

这句语句本来是打算删除 `$tar_dir` 文件夹下所有符合 `iot-*.txt` 模式的文件

但最终执行时却并没有生效，原因如下：

在 Shell（如 Bash）中，引号会影响通配符（如 \*）的展开方式。具体来说：

- 双引号 `"`：会保留大多数特殊字符的字面意义，但仍允许变量展开（如 $tar_dir）
- 单引号 `'`：会将所有内容视为字面值，包括变量和通配符
- 无引号：允许变量和通配符被展开

在这个例子中，双引号导致通配符无法被展开，我们可以修改这个操作

```bash
rm "$tar_dir"/iot-*.txt
```

## Git

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

以上操作针对于本地提交，如果更改已经被 `git push` 到了远端仓库中，则

```bash
git push --force-with-lease origin main
```

- `--force-with-lease` 比 `-f` 更安全，它会在其他人修改了远程分支时拒绝推送

### How to untrack a file in a git repo?

1. Add the File to .gitignore

比如说需要忽略所有的 `.bak` 文件

```gitignore
.bak
```

2. Remove the File from Git's Tracking

```bash
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

```bash
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

## Regex

### Extract a number

要求从下面这个 `iot-oreo-8.txt` 文件中提取出 TXN 对应的 P99 Latency，即`57727`

```txt
# 省略许多行
TXN    - Takes(s): 34.1, Count: 9105, OPS: 266.6, Avg(us): 27405, Min(us): 21312, Max(us): 60639, 50th(us): 23071, 90th(us): 54943, 95th(us): 56511, 99th(us): 57727, 99.9th(us): 59263, 99.99th(us): 60383
TXN_ERROR - Takes(s): 34.1, Count: 895, OPS: 26.2, Avg(us): 22831, Min(us): 21104, Max(us): 56383, 50th(us): 22479, 90th(us): 23423, 95th(us): 23791, 99th(us): 25167, 99.9th(us): 56319, 99.99th(us): 56383
```

首先使用 `rg` 匹配到对应行：

```bash
rg '^TXN\s' iot-oreo-8.txt
```

- `^` 代表匹配以 `TXN` 开头的
- `\s` 表示匹配一个空格，与 `TXN_ERROR` 做区分

得到：

```txt
TXN    - Takes(s): 34.1, Count: 9105, OPS: 266.6, Avg(us): 27405, Min(us): 21312, Max(us): 60639, 50th(us): 23071, 90th(us): 54943, 95th(us): 56511, 99th(us): 57727, 99.9th(us): 59263, 99.99th(us): 60383
```

然后我们再来考虑如何匹配到 `99th(us)`

```bash
rg '^TXN\s' iot-oreo-8.txt | rg -o '\s99th\(us\): [0-9]+'
```

- `-o` 表示只输出匹配的部分(否则会输出整个行)

得到：

```txt
 99th(us): 57727
```

最后再从这段文字中提取出数据

```bash
rg '^TXN\s' iot-oreo-8.txt | rg -o '\s99th\(us\): [0-9]+' | choose 1
```

- `choose 1` 表示从当前行中选取第 2 个字段
- 也可以使用 `cut`，但要注意这段文字最前面的空格，应该使用 `cut -d' ' -f3`

得到:

```
57727
```
