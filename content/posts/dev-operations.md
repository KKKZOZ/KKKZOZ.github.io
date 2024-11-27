---
title: "Dev Operations"
tags:
  - Dev
categories:
  - Pieces
date: 2024-11-25
toc: true
---

## 写在前面

本篇博客主要会记录和总结一些我平时在 Unix 环境下遇到的一些问题，包括但不局限于命令行，Git 操作等

## CommandLine

### How to use `rsync`

> rsync 是一个文件同步和传输工具

```bash
# 复制目录
rsync -av /source/folder/ /destination/folder/

# 带进度条
rsync -avP /source/folder/ /destination/folder/

# 本地到远程
rsync -avz /local/folder/ user@remote:/remote/folder/

# 远程到本地
rsync -avz user@remote:/remote/folder/ /local/folder/

# 使用 --exclude
rsync -av --exclude='*.txt' source/ destination/

# 多个排除
rsync -av --exclude='*.txt' --exclude='*.pdf' source/ destination/
```

### 设置项目级 ROOT 环境变量实现快速目录导航

> 原问题：如何实现在不同的项目中设置不同的 ROOT 环境变量，以便于我在某个项目中的子文件夹中能够迅速跳转到项目根目录

使用 direnv：

```bash
# 安装 direnv
sudo apt install direnv  # Ubuntu/Debian
brew install direnv      # MacOS

# 在 shell 配置文件（~/.bashrc 或 ~/.zshrc）中添加：
eval "$(direnv hook bash)"  # 或 zsh

# 在项目根目录创建 .envrc 文件
echo 'export ROOT=$PWD' > .envrc
direnv allow
```

然后就可以在项目中的任意一个位置通过 `cd $ROOT` 跳转到项目根目录了

direnv 的常用场景包括：

1. 项目特定的环境变量：

```bash
# Node.js 项目
export NODE_ENV=development
export PORT=3000

# Python 项目
export PYTHONPATH=$PWD/src
export FLASK_ENV=development
```

2. 工具路径和版本管理：

```bash
# 指定项目 Node 版本
use node 16.14.0

# 指定 Python 虚拟环境
layout python3

# Go 项目配置
export GOPATH=$PWD/.go
layout go
```

3. API 密钥和配置：

```bash
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export DATABASE_URL="postgresql://user:pass@localhost:5432/db"
```

4. 项目别名和快捷命令：

```bash
alias run="npm run"
alias test="pytest"
alias db="psql $DATABASE_URL"
```

5. 路径简写：

```bash
export SRC=$PWD/src
export DOCS=$PWD/docs
export CONFIG=$PWD/config

PATH_add scripts
PATH_add bin
```

### 如何在脚本中实现自动输入 sudo 密码

```bash
echo "password" | sudo -S command
```

- `-S` 选项告诉 `sudo` 从标准输入读取密码
- `|` 管道符将 `echo` 的输出传给 `sudo` 命令

如果使用 `ssh` 在远程执行脚本的话：

```bash
ssh -t $node1 "echo '$PASSWORD' | sudo -S command"
```

- 没有 `-t` 时，可能会遇到 "sudo: no tty present and no askpass program specified" 这样的错误
- `-t` 选项强制 SSH 分配一个伪终端(pseudo-terminal, PTY)

PTY (Pseudo Terminal) 和 SSH 的工作原理：

PTY 和 SSH 直接建立的终端的主要区别在于它们的工作方式和用途：

1. SSH 默认终端（不带 `-t`）：

```bash
本地机器         SSH通道          远程机器
程序 --> SSH客户端 -----> SSH服务器 --> 远程程序
     (标准输入输出重定向)      (无终端环境)

# 特点：
- 只是简单的标准输入输出重定向
- 不支持终端特性（如光标控制）
- 适合运行非交互式命令
```

2. PTY 终端（带 `-t`）：

```bash
本地机器          SSH通道          远程机器
终端模拟器 --> SSH客户端 -----> SSH服务器 --> PTY --> 远程程序
     (完整终端环境模拟)        (完整终端环境)

# 特点：
- 完整的终端环境模拟
- 支持所有终端特性
- 适合交互式程序
```

PTY (Pseudo Terminal) 的概念：

```
实际终端设备        PTY主设备(master)    PTY从设备(slave)     应用程序
(keyboard/screen) <--> (/dev/ptmx) <--> (/dev/pts/N) <--> (如 bash, sudo)
```

- PTY 是一对虚拟设备：主设备(master)和从设备(slave)
- 主设备负责与实际终端设备通信
- 从设备为应用程序提供一个类似实际终端的接口

SSH 终端分配过程：

```
本地机器                     远程机器
ssh client                  sshd
    |                         |
    |--- SSH连接请求 --------->|
    |<-- 认证握手 ------------>|
    |                         |
[带-t选项]:                    |
    |-- 请求PTY分配 ---------> |
    |                     创建PTY
    |                         |
    |<-- PTY信息 ------------- |
    |                         |
    |-- 启动shell或命令 ----->  |-- PTY从设备 --> 目标程序
```

为什么某些命令需要 PTY：

```bash
# sudo 需要 PTY 的原因：
- 安全考虑：确保是真实用户在操作
- 密码输入：需要控制终端来安全读取密码
- 信号处理：正确处理 Ctrl+C 等终端信号

# 示例：sudo 的行为差异
ssh server "sudo ls"          # 可能失败：no tty present
ssh -t server "sudo ls"       # 正常工作：有PTY支持
```

实际应用中的区别：

```bash
# 不需要 PTY 的命令
ssh server "ls -l"
ssh server "echo hello"

# 需要 PTY 的命令
ssh -t server "sudo apt update"
ssh -t server "vim file.txt"
ssh -t server "top"
```

环境变量对比：

```bash
# 不带 -t
$ ssh server "env | grep TERM"
# 可能为空或基础值

# 带 -t
$ ssh -t server "env | grep TERM"
TERM=xterm-256color
```

> `TERM` 环境变量指定了当前终端的类型，它告诉程序如何正确地处理终端输出，比如颜色、光标移动等特性
> `TERM=xterm-256color` 表示终端支持：
>
> - 256色显示
> - 光标定位
> - 清屏
> - 粗体/斜体
> - 鼠标事件
> - 特殊键(方向键等)

举一个最简单的例子：

```bash
# 不带 -t（无或基础 TERM）
$ ssh server "ls --color"
# 可能无颜色显示，因为程序检测不到终端支持颜色

# 带 -t（TERM=xterm-256color）
$ ssh -t server "ls --color"
# 显示完整的颜色输出
```

实际有什么影响呢？

```bash
# 不带 -t
$ ssh server "vim file.txt"
# 失败，因为 vim 需要知道终端类型来处理光标、颜色等

# 带 -t
$ ssh -t server "vim file.txt"
# 正常工作，vim 知道如何在 xterm-256color 终端下工作
```

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

## Docker

### 服务器拉取不了镜像怎么办？使用 docker save 和 docker load

常见的加镜像源，挂梯子的办法这里就不说了，这里介绍一个“一次性”的方法

```bash
# 在能访问互联网的笔记本上
docker pull redis:latest
docker save redis:latest > redis.tar
# 或者压缩以减小体积
docker save redis:latest | gzip > redis.tar.gz

# 通过 scp 或其他方式传输到目标机器
scp redis.tar.gz remote:/path/to/

# 在目标机器上
docker load < redis.tar.gz
```

注意，上面这个简单的例子适用于笔记本和远端服务器架构相同的情况，比如都是 `x86`

如果你的笔记本是 M 芯片系列的 MacBook，你的架构是 `arm64`，直接套用上述方法会报错，需要修改一下 `docker pull` 的操作：

```bash
# 显式指定 linux/amd64 平台
docker pull --platform linux/amd64 apache/kvrocks

# 查看镜像确认架构
docker inspect apache/kvrocks | grep Architecture
```

后续操作不变

> 在 Docker 中，同一个镜像标签（例如 apache/kvrocks:latest）在本地只会存储一个平台的版本。当你使用 --platform 拉取镜像时，Docker 会替换掉本地已有的同名镜像。

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
