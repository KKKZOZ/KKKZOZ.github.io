---
title: "Mac Development Environment Setup"
tags:
  - Dev
categories:
  - Pieces
date: 2024-11-21
toc: true
---

## How to install Homebrew?

> [参考资料](https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/)

### homebrew 软件仓库和 homebrew bottles 软件仓库有什么不一样

homebrew 仓库类型主要有两种，它们用途不同：

1. homebrew 软件仓库(brew git remote)

- 包含所有软件包的安装脚本(Ruby 格式的 Formula)
- 主要仓库是 homebrew-core
- 仓库相对较小，包含的是软件包的描述文件

2. homebrew bottles 软件仓库

- 存放预编译的二进制软件包
- 类似于 Linux 下的 .deb 或 .rpm 包
- 仓库较大，因为包含实际的软件二进制文件
- 使用 bottles 可以避免从源码编译，加快安装速度

举例说明:
当你运行 `brew install wget` 时:

1. Homebrew 先从软件仓库获取 wget 的 Formula
2. 然后检查 bottles 仓库是否有对应的预编译包
3. 如果有 bottle 就直接下载安装，否则就按照 Formula 的指示编译源码

所以设置镜像时通常需要同时配置这两种仓库。需要配置软件仓库以获取安装脚本，同时配置 bottles 仓库以获取预编译包。

1. 前置条件

在终端中执行

```bash
xcode-select --install
```

1. 设置环境变量

首先设置环境变量，方便使用国内镜像进行安装

```bash
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_INSTALL_FROM_API=1
```

2. 安装 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://github.com/Homebrew/install/raw/master/install.sh)"
```

3. 设置镜像

```bash
# 将下面这段内容添加到 ~/.zshrc 中
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
```

如果你使用的是 fish:

```bash
# 在 ~/.config/fish/config.fish 中添加以下内容
set -x HOMEBREW_BREW_GIT_REMOTE "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
set -x HOMEBREW_API_DOMAIN "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
set -x HOMEBREW_BOTTLE_DOMAIN "https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
```

最后在终端中执行：

```bash
brew update
```
