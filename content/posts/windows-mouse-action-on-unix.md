---
title: "From Clicks to Commands: A Windows User's Survival Guide"
tags:
  - Dev
  - Tutorial
date: 2024-11-26
toc: true
---

> WIP 🚧

这篇 Blog 主要记录了一些在 Unix 终端环境下对应的 Windows 下的常见的鼠标操作

主要面向 Linux 和 MacOS 的新手们，所以有些信息会被简化或者忽略

可为什么要用终端/命令行呢？

就像“为什么使用 Vim”一样，原因有很多，对于我来说，它足够简单，足够快，支持许多的自定义，是 Programmable 的

> 在程序员的世界里，你真的能够做到（抖个机灵哈哈哈）：
>
> 如果你觉得终端难用，就去定制你的 Shell 配置；如果你觉得命令不够方便，就写个函数或别名把它封装得更好；如果你觉得工具功能太弱，就用脚本扩展它的能力；如果你觉得操作繁琐，就从自动化开始，一点点改善工作流程，而不是一昧地抱怨，排斥，逃向 GUI。

# Left Click

首先需要学习的肯定是鼠标左键的双击 --- 打开某个文件夹，以及打开某个文件夹后的结果：查看这个文件夹的内容

对应到终端中：

- `cd` 跳转到某个文件夹
- `ls` 展示文件夹的内容

```bash
> ls
Applications                    Playground
DataGripProjects                Projects
Desktop                         Public
Documents                       Scripts
Downloads                       Temp
Dropbox                         Virtual Machines.localized
Library                         Zotero
Movies                          dotfiles-main
Music                           go
Pictures

> cd Projects

```

> 在使用 `cd` 命令时，不用把文件夹的名字输入完整
> 比如想要 `cd Projects`，只需要输入 `cd Pro`，然后按下键盘上的 Tab 键，就能触发自动补全

如果你想进入一个层级比较深的文件夹，恰好你又不记得路径，是不是就需要 `cd` 和 `ls` 来回用，比如先 `cd Projects`，再 `ls`，再 `cd Oreo`，再 `ls`，再 `cd pkg`，再 `ls` ...

我们可以自己写一个简单的小函数，将这两个命令结合起来：

```bash
cdl() {
    cd "$1" && ls
}
```

# Right Click

鼠标右键涉及的命令就比较多了，建议先掌握基础的：

- 重命名
- 复制
- 移动
- 删除
- 新建

剩余的操作等有需要之后再来查也不迟

## Basic Operations

## 重命名

```bash
mv old-file-name new-file-name
```

> 可以发现，重命名和剪切/移动都是 `mv` 命令

如果你是一个新手，不习惯这样的操作的话，可以给该命令加一个别名

```bash
alias rename=mv

# 然后就可以使用 rename old-file-name new-file-name 
```

## 复制

```bash
cp source-file destination-file    # 复制文件
cp -r source-dir destination-dir   # 复制目录
```

- `cp` => `c`o`p`y
- 默认情况下，cp 命令只会复制文件，不会复制目录
- `-r` 参数告诉 cp 命令递归地复制目录及其内部的所有内容

## 剪切/移动

```bash
mv source-file destination-file    # 移动文件
mv source-dir destination-dir      # 移动目录
```

- `mv` => `m`o`v`e

## 删除

```bash
rm file-name           # 删除文件
rm -r directory-name   # 删除目录
rm -rf directory-name  # 强制删除目录及其内容
```

- `rm` => `r`e`m`ove

## 新建

### 新建文件

```bash
touch new-file.txt     # 创建空文件
```

### 新建文件夹

```bash
mkdir new-directory    # 创建单个目录
mkdir -p path/to/dir   # 创建多层目录
```

- `mkdir` => `m`a`k`e `dir`ectory

`-p` 选项表示 "parents"，它有两个作用：

- 如果要创建的目录已经存在，不会报错
- 如果父目录不存在，会自动创建所有必需的父目录

## 属性

### 查看文件/目录属性

```bash
ls -l file-name       # 查看文件详细信息
stat file-name        # 查看文件详细状态
```

一个简单的例子：

```bash
ls -l

.rw-r--r--@ 3.3k kkkzoz 11 Nov 17:03  1.txt
```

- `.rw-r--r--` 是权限信息
  - 第 1 位 `.` 表示普通文件（如果是 `d` 则表示目录）
  - 后 9 位分为 3 组，每组 3 位:
    - `rw-` (所有者权限): 可读、可写、不可执行
    - `r--` (用户组权限): 只可读
    - `r--` (其他用户权限): 只可读
- `@` 暂时不用管
- `3.3k` 表示文件大小，为 3.3KB
- `kkkzoz` 文件所有者的用户名
- `11` 表示文件的硬链接数量，可以暂时不用管
- `Nov 17:03` 表示文件最后的修改时间
- `1.txt` 文件名

## 压缩/解压

### 压缩

```bash
tar -czf archive.tar.gz files/    # 创建 tar.gz 压缩包
zip -r archive.zip files/         # 创建 zip 压缩包
```

### 解压

```bash
tar -xzf archive.tar.gz          # 解压 tar.gz 文件
unzip archive.zip                # 解压 zip 文件
```

命令行中 `tar.gz` 更为常见，观察 `tar` 命令的参数，无论是压缩还是解压，`-zf` 都有：

- `-z` gzip (使用 gzip 压缩)
- `-f` file (指定归档文件名)
- `-c`: create (创建新的归档文件)
- `-x`: extract (提取/解压)

> Q: gzip 是一种压缩算法和工具，为什么要和 tar 组合使用呢？
> A: tar 和 gzip 组合使用是因为它们的功能互补：
> tar（tape archive）的功能：
>
> - 将多个文件和目录打包成一个文件
> - 保留文件的权限、所有者等信息
> - 但不进行压缩，只是打包
> - 生成的 .tar 文件通常和原始文件大小相近
> gzip 的功能：
> - 只能压缩单个文件
> - 不能压缩目录
> - 压缩后原文件被删除，生成 .gz 文件

`tar -czf archive.tar.gz files/` 和 `tar -xzf archive.tar.gz` 用起来也不是很方便，为什么要这么多参数，什么 cfxz，这咋记？

我们可以简化这两个命令：

```bash
# 解压 tar.gz 文件
alias untar='tar -xzf'

alias _tar='function _tar() { tar -czf "${1%/}.tar.gz" "$1"; }; _tar'

# 新 _tar 命令会把 files 这个文件夹压缩为 files.tar.gz
_tar files/

# untar 会解压这个压缩包
untar archive.tar.gz
```

- TODO: 解压的行为

## 打开方式

### 使用默认程序打开

```bash
xdg-open file-name    # Linux 下使用默认程序打开
open file-name        # macOS 下使用默认程序打开
```

> xdg-open 是 Linux 下的一个通用程序启动器,它会根据文件类型调用合适的默认应用程序来打开文件。它是 freedesktop.org 项目的一部分,属于 xdg-utils 工具集。
>
> 工作原理:
>
> 1. 检查文件的 MIME 类型
> 2. 查找系统中该 MIME 类型对应的默认应用程序
> 3. 启动对应的程序打开文件

## 查找

```bash
find . -name "file-name"     # 在当前目录及子目录中查找文件
```

# Advanced Operations

## 属性

### 查看文件大小

细心的小伙伴可能发现了，对于文件夹来说，`ls -l` 是看不到这个文件夹的具体大小的

我们需要使用 `du` 命令

```bash
# 查看当前目录下各个目录的大小
du -sh *

# 显示深度为 1 的目录大小 (Linux)
du -h --max-depth=1 *

# # 显示深度为 1 的目录大小 (MacOS)
du -h -d 1 *
```

### 修改权限

```bash
chmod 644 file-name   # 修改文件权限
chmod +x file-name    # 添加执行权限
```

### 修改所有者

```bash
chown user:group file-name    # 修改文件所有者和组
```

## 共享

```bash
chmod a+r file-name     # 允许所有用户读取
scp file user@host:/path    # 通过 SSH 发送文件
rsync -av source/ destination/    # 同步文件/目录
```
