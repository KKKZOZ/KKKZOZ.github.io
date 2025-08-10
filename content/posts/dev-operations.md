---
title: "Dev Operations"
tags:
  - Dev
date: 2025-04-17
showtoc: true
weight: 10
---

> This blog post will primarily document and summarize some issues I usually encounter in Unix environments, including but not limited to command line and Git operations.

> ![NOTE] UPDATE
>
> - Contents related to git have been integrated to [Git Essentials](./dev/git-essentials.md).

## Remote

### Address

> 很常见很弱智的一个错误, 但就是架不住偶尔会犯一次

在开启 http server 之类的操作时, 如果填的地址是 `localhost:9000`, 那么只有本机可以访问

如果想在其他主机上访问, 需要填为 `:9000`

### Bash Shell

Shell 分类:

- 登录 (Login) vs 非登录 (Non-Login):
  - 登录 Shell: 通常是你通过验证身份（输入用户名和密码，或使用 SSH 密钥）后第一个启动的 Shell。比如：
    - 直接在物理控制台登录
    - 通过 ssh user@host 远程登录
    - 使用 su - 或 sudo -i 切换用户（注意那个 - 或 -i 很关键，它们表示模拟一次完整的登录）
  - 非登录 Shell: 不是通过上述登录过程直接启动的 Shell。比如：
    - 在图形界面中已经登录后，打开一个新的终端窗口
    - 在 Shell 中执行一个脚本 (bash script.sh)
    - 在已有 Shell 中再启动一个新的 Shell (bash)
- 交互式 (Interactive) vs 非交互式 (Non-Interactive):
  - 交互式 Shell: Shell 的标准输入、输出和错误都连接到终端，并且你可以在其中输入命令并看到输出。简单说，就是你正在与之交互的 Shell
  - 非交互式 Shell: Shell 不是直接连接到终端进行交互的。最常见的例子是运行 Shell 脚本。Shell 从脚本文件读取命令，并将输出（如果未重定向）发送到标准输出，但它不期望用户实时输入命令

根据这两种分类, 可以组合出三种**常见的** shell 类型:

- 交互式登录 Shell: (你的 SSH 登录场景)
  - 启动方式：控制台登录, `ssh user@host`, `su - <user>`, `sudo -i <user>`
  - 读取配置文件 (Bash 为例):
    - /etc/profile (系统全局，所有用户)。
    - 然后查找并执行第一个找到的文件：
      - ~/.bash_profile (用户特定)
      - ~/.bash_login (用户特定)
      - ~/.profile
- 交互式非登录 Shell: (你在 GUI 中打开新终端，或手动 source ~/.bashrc 的场景)
  - 启动方式：在 GUI 中打开新终端，在已有 Shell 中输入 bash
  - 读取配置文件 (Bash 为例):
    - ~/.bashrc (用户特定，仅 Bash)
- 非交互式非登录 Shell: (运行脚本的常见场景)
  - 启动方式: `bash script.sh`
  - 这种 shell **默认不读交互式配置**
  - 只有当 `BASH_ENV` 被设置了，并且其值是一个有效且可读的文件路径，那么 Bash 会执行（source） 这个文件里的命令，然后才开始执行脚本本身（script.sh）的命令
  - 必要的环境变量都可以通过环境继承，也就是从父 Shell 导出的环境变量，所以通常不需要特殊配置

> [!QUESTION] 为什么要有这种区分？

这种设计背后的逻辑是：

- 登录时执行一次的操作: 有些设置（比如基础的 PATH、设置一些只需要在会话开始时设定一次的环境变量、检查邮件等）适合在登录时执行一次即可。这些通常放在 .profile (或 .bash_profile, .bash_login) 中
- 每次交互式 Shell 启动时都需要执行的操作: 另一些设置（比如命令别名 alias、Shell 函数、自定义的提示符 PS1、shopt 选项等）是你希望在每一个交互式 Shell 中都可用的，无论它是登录 Shell 还是之后打开的非登录 Shell。这些通常放在 .bashrc 中

> [!IMPORTANT]
> 通常情况下, ~/.bash_profile 中都会添加逻辑来调用 `~/.bashrc`

> [!NOTE]
> 在 Ubuntu 中, `.bash_profile` 的优先级**高于** `.profile`

`.profile` 的前几句:

```shell
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login exists.
```

> [!QUESTION] What about fish shell?

- Fish 主要使用 ~/.config/fish/config.fish 这一个文件
- 无论 Fish Shell 是以登录、非登录、交互式还是非交互式模式启动，它都会读取并执行 ~/.config/fish/config.fish 文件
- 条件判断在内部:

```shell
if status is-interactive
    # Commands for interactive sessions only (e.g., set prompt, aliases)
    echo "Fish is interactive"
end

if status is-login
    # Commands for login sessions only
    echo "Fish is a login shell"
end
```

> 这就是很多时候将 fish shell 作为 login shell 时, 什么 ssh, rsync 都无法正常运行的原因 -- 在不属于交互式的 shell 中输出了交互式 shell 中的东西, 导致协议失效
>
> 日常使用中 `is-interactive` 这个判断使用得最多

- Universal Variables： Fish 有一个“通用变量” (`set -U`) 的概念，这种变量的设置会跨所有 Fish 会话自动共享和持久化（存储在 `~/.config/fish/fish_variables` 文件中），通常用于设置像 PATH 这样的全局配置，而无需每次启动都重新设置。例如，添加路径推荐使用：

```shell
# Add ~/.local/bin to PATH persistently for all fish sessions
fish_add_path ~/.local/bin
```

> [!SUMMARY]
> 关键字:
>
> - **自动共享**
> - **持久保存**

## CommandLine

### 可执行文件存放位置

> [!QUESTION] 如果我有一个可执行文件，我应该把它放在哪里

- `/usr/local/bin`
  - 最推荐的位置
  - 所有用户都可访问
  - 该目录默认在 `PATH` 中
  - 适合系统级的第三方软件
- `$HOME/.local/bin`
  - 用户级安装的推荐位置
  - 只对当前用户可用
  - 需要确保该目录在 `PATH` 中

要将文件复制到 /usr/local/bin，使用:

```bash
sudo cp 程序名 /usr/local/bin/
sudo chmod +x /usr/local/bin/程序名
```

> [!EXPERIMENT] Behind The Scenes
> 当你用 `sudo cp` 复制文件到 `/usr/local/bin/` 时，复制后的文件所有者会变成 root，且文件的权限会继承源文件的权限
> `chmod +x` 会同时修改三个组的权限：
>
> 1. 所有者权限（owner/user）
> 2. 组权限（group）
> 3. 其他用户权限（others）
>
> `chmod +x` 实际上等同于 `chmod ugo+x` 或 `chmod a+x`（`a` 表示 `all`）

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

### .bash_profile 和 .bashrc 有什么区别

`.bash_profile`:

- 用户登录时加载一次
- 适用于登录shell（login shell）
- 通常用于设置环境变量，如 PATH、JAVA_HOME 等
- 典型场景：SSH 远程登录、图形界面登录时

`.bashrc`:

- 每次打开新的终端窗口时都会加载
- 适用于交互式非登录 shell（non-login shell）
- 通常用于设置命令别名、shell 函数等交互相关的配置
- 典型场景：在已登录系统后打开新终端窗口

为确保配置生效，`.bash_profile` 中通常会包含这样的代码来源引 `.bashrc`：

```bash
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

```

> 所以个人的配置应该写到哪个文件里呢？

建议如下配置：

写在 `.bashrc` 中：

- 命令别名 (alias)
- shell 函数
- 命令补全设置
- 其他交互式使用的配置

写在 `.bash_profile` 中：

- PATH 环境变量
- JAVA_HOME, MAVEN_HOME 等程序路径
- 其他需要被所有子程序继承的环境变量

> [!TIP] Summary
> 推荐做法：
>
> - 将所有个人配置写在 `.bashrc` 中
> - 在 `.bash_profile` 中只保留环境变量，并源引 `.bashrc`
> - 这样既确保环境变量只设置一次，又能让交互式配置在每个新终端中生效

### 如何在 ssh 中合并多条命令

SSH 中合并多条命令有以下几种方法：

1. 使用分号分隔：

```bash
ssh user@host "command1; command2; command3"

# 可以使用换行符和引号包围多行命令
ssh user@host "cd /path/to/dir;
ls -l;
df -h"
```

2. 使用 && 确保前一条命令成功才执行下一条：

```bash
ssh user@host "command1 && command2 && command3"
```

> [!summary]
> 几种常见分隔符的对比：
>
> `A ; B`: 无论 A 成功失败，B 都执行
> `A && B`: 只有 A 成功，B 才执行
> `A || B`: 只有 A 失败，B 才执行

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

```ascii
实际终端设备        PTY主设备(master)    PTY从设备(slave)     应用程序
(keyboard/screen) <--> (/dev/ptmx) <--> (/dev/pts/N) <--> (如 bash, sudo)
```

- PTY 是一对虚拟设备：主设备(master)和从设备(slave)
- 主设备负责与实际终端设备通信
- 从设备为应用程序提供一个类似实际终端的接口

SSH 终端分配过程：

```ascii
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

### 在使用 tar 命令解压文件时，如果文件夹已经存在，是在此基础上添加，还是说会自动清空这个文件夹，再解压？

如果解压的文件与目标文件夹中的文件同名：

- 会直接覆盖已存在的文件
- 不会提示确认

如果是新文件：

- 会直接添加到目标文件夹中
- 原有的其他文件保持不变

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

### Docker 常见操作

#### 通过命令行向 Docker 容器上传和下载文件

```shell
# 上传文件
docker cp <本地文件路径> <容器名称或ID>:<容器内的目标路径>

# 下载文件
docker cp <容器名称或ID>:<容器内的文件路径> <本地目标路径>
```

> 和 scp 的用法类似

#### 进入 Docker 容器内部并启动一个交互式 shell

```shell
docker exec -it <container id or name> /bin/bash
```

- `-it`: 表示以交互模式（-i）和终端（-t）运行
  - `-i`: 让容器的标准输入（STDIN）保持打开状态，允许用户输入数据
  - `-t`: 为容器分配一个终端设备（TTY） ，使 Shell 能正确显示终端控制字符（如颜色、光标移动、Ctrl+C 中断等）

### 如何使用 docker 限制一个容器能使用的核心数和内存大小

- 限制 CPU:

```shell
# 限制使用 2 个 CPU 核心
docker run --cpus=2 镜像名称

# 或者使用 CPU 份额(默认1024)
docker run --cpu-shares=512 镜像名称

# 指定只能在 CPU 0 和 CPU 1 上运行
docker run --cpuset-cpus="0,1" 镜像名称
```

- 限制内存

```shell
# 限制最大内存使用为 2GB
docker run -m 2g 镜像名称
# 或者使用 MB 单位
docker run --memory=2048m 镜像名称

# 设置 swap 限制为 1GB
docker run --memory-swap=1g 镜像名称
```

> [!INFO]
>
> - 对于正在运行的容器，可以使用 docker update 命令来动态调整资源限制，不需要停止容器
> - 资源限制的更新是即时生效的，但不会影响容器内已经运行的进程

使用 docker update 更新资源限制时：

- 新启动的进程会受到这些新限制的约束
- 容器内已经运行的进程不会被强制终止或重启
  - 已分配的内存不会被立即回收
  - 如果进程已经使用了超过新限制的资源，它可以继续使用这些资源

> [!SUMMARY]
>
> - 提高限制：进程可以立即使用新增的资源
> - 降低限制：已使用的资源不会被强制回收，只会限制新的资源申请

### Docker 容器分类

#### 守护式容器（Daemon Containers）

- 特征：
  - 必须有一个前台进程（foreground process）持续运行
  - 如果主进程退出，容器就会停止
  - 通常使用 PID 1 进程
- 常见用途：
  - Web 服务器（Nginx, Apache）
  - 数据库（MySQL, PostgreSQL）
  - 消息队列（RabbitMQ, Redis）
  - 应用服务器（Node.js, Java）

Dockerfile 示例：

```dockerfile
FROM nginx
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### 任务型容器（Task Containers）

- 特征：
  - 运行完特定任务就退出
  - 通常结合 `docker run --rm` 使用，完成后自动删除容器
  - 经常用于 CI/CD 流程
- 常见用途：
  - 数据备份
  - 代码编译
  - 数据处理
  - 定时任务

Dockerfile 示例：

```dockerfile
FROM python
COPY script.py /
CMD ["python", "script.py"]
```

#### 运行方式的区别

守护式容器：

```bash
# 后台运行
docker run -d nginx

# 查看日志
docker logs container_id

# 进入容器
docker exec -it container_id bash
```

任务型容器：

```bash
# 运行并自动删除
docker run --rm alpine echo "Hello World"

# 用作构建环境
docker run --rm -v $(pwd):/app node npm run build
```

> [!QUESTION] 如何让任务型容器长久运行呢？
>
> `docker run -d ubuntu tail -f /dev/null`
>
> `tail -f` 命令的工作原理：
>
> - 它会监视文件的变化
> - 当文件没有变化时，进程会进入睡眠状态
> - 几乎不消耗 CPU 资源
>
> `/dev/null` 的特点：
>
> - 这是一个特殊的设备文件
> - 它永远不会有新内容
>
> 所以 `tail -f` 在监视它时会一直处于等待状态

### 服务器拉取不了镜像怎么办？使用 docker save 和 docker load

常见的加镜像源，挂梯子的办法这里就不说了，这里介绍一个「一次性」的方法

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

> 在 Docker 中，同一个镜像标签（例如 `apache/kvrocks:latest`）在本地只会存储一个平台的版本。当你使用 --platform 拉取镜像时，Docker 会替换掉本地已有的同名镜像。

## Miscellaneous

### PassKey

Passkey，中文常称为“通行密钥”或“密码密钥”，是一种更安全、更便捷的网站和应用程序登录验证方式，旨在取代传统的密码。它由万维网联盟（W3C）和 FIDO 联盟共同推动，并获得了苹果、谷歌、微软等科技巨头的支持。

**Passkey 的核心原理：**

Passkey 的核心技术基于**公钥加密技术 (Public-Key Cryptography)**，也称为非对称加密。其工作原理如下：

1. **创建 Passkey：**
    - 当你在一个支持 Passkey 的网站或应用上注册或选择使用 Passkey 时，你的设备（如智能手机、电脑或硬件安全密钥）会生成一对密钥：一个**私钥 (Private Key)** 和一个**公钥 (Public Key)**。
    - **私钥**安全地存储在你的本地设备上，并且永远不会离开该设备。它受到你设备的保护机制（如生物识别信息——指纹或面容 ID，或设备 PIN 码）的保护。
    - **公钥**则会发送到你注册的网站或应用的服务器上，并与你的账户关联。

2. **使用 Passkey 登录：**
    - 当你尝试登录时，网站或应用会向你的设备发送一个“挑战”（一段随机数据）。
    - 你的设备会使用存储在本地的**私钥**对这个“挑战”进行签名（加密）。
    - 签名后的“挑战”会发送回网站或应用的服务器。
    - 服务器使用之前存储的你的**公钥**来验证这个签名。
    - 如果验证成功，就证明你确实拥有对应的私钥（即你是设备的合法拥有者），从而允许你登录。在这个过程中，你通常只需要通过设备的生物识别或 PIN 码来授权使用私钥。

总结来说，Passkey 是一种基于成熟加密技术的新一代身份验证标准，它通过将私钥安全地存储在用户设备上，并利用生物识别或设备 PIN 进行解锁，从而提供了比传统密码更安全、更便捷的登录体验，并能有效抵御网络钓鱼等常见的网络攻击。

### 如何查看服务器的网络配置

使用 `ip` 命令:

```shell
# 查看 IP 和掩码
ip address

# 简单查看 IPv4 地址
ip address | rg "inet "

# 查看网关
ip r
```

- 一般来说, 最常见的接口为 `eth0`, 在 `ip address` 和 `ip r` 命令中找对应的行就行

```shell
> ip address
2: enp61s0f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 6c:92:bf:c4:19:ee brd ff:ff:ff:ff:ff:ff
    inet 124.16.138.60/24 brd 124.16.138.255 scope global noprefixroute enp61s0f0
       valid_lft forever preferred_lft forever
    inet6 2400:dd01:100f:2:eb57:d4f4:552a:1b52/64 scope global noprefixroute dynamic
       valid_lft 2591855sec preferred_lft 604655sec
    inet6 fe80::319f:41fe:b48:a825/64 scope link noprefixroute
       valid_lft forever preferred_lft forever

> ip r
default dev utun8 scope link
default via 10.207.255.254 dev eth0 # This one
default dev bridge100 scope link
1.0.0.0/8 dev utun8 scope link
```

### VSCode Remote Tunnel Access

VS Code 中的 Remote Tunnel Access (远程隧道访问) 是一种 无需 SSH 或其他复杂配置就能 安全、便捷地连接到远程计算机进行开发的功能。它可以让你从任何地方、使用任何设备上的 VS Code 客户端，无缝访问远程机器上的文件、终端、运行代码和使用扩展，就好像你在本地操作一样。

简单来说，Remote Tunnel Access 就像为你建立了一条 "隧道"，让你安全地穿过网络障碍（比如防火墙、NAT 等），直接连接到你的远程机器。

与传统的 Remote SSH 等方式的区别和优势:

- 更简单易用: Remote Tunnel Access 无需复杂的 SSH 密钥配置、端口转发或网络配置。 只需在远程主机和客户端都登录 VS Code 账号即可轻松连接。

- 网络穿透性更强: Tunnel 连接是 出站连接，这意味着它可以 轻松穿透防火墙和 NAT，即使你的远程主机在受限的网络环境中也能访问。 这对于访问家里的电脑、公司内网的机器、或者位于不同网络环境下的服务器非常方便。

- 更安全: Tunnel 连接是 加密的，并由 Microsoft 的服务进行管理，保证了连接的安全性。 你无需担心暴露 SSH 端口或者复杂的安全配置。

- 跨平台和跨设备: 客户端和远程主机可以是不同的操作系统 (Windows, macOS, Linux)。你可以在任何安装了 VS Code 的设备上连接到远程主机。

### Extract a number using regex

要求从下面这个 `iot-oreo-8.txt` 文件中提取出 TXN 对应的 P99 Latency，即 `57727`

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

```shell
57727
```
