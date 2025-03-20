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

所以设置镜像时通常需要同时配置这两种仓库: 配置软件仓库以获取安装脚本，同时配置 bottles 仓库来获取预编译包

### 安装步骤

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

> 完整流程是：

> - 通过 HOMEBREW_API_DOMAIN 获取软件的 Formula
> - Formula 中包含了 bottle 的信息，Homebrew 会从 HOMEBREW_BOTTLE_DOMAIN 检查和下载预编译包
> - 如果找不到合适的预编译包，才会根据 Formula 中的指令编译源码
>
> HOMEBREW_BREW_GIT_REMOTE
>
> - 这个变量指向 Homebrew 的核心代码仓库
> - 它不直接对应你列出的三个步骤，而是用于更新 Homebrew 自身的代码

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

### Brew 相关问题

#### brew update and brew upgrade

- brew update
  - 更新 Homebrew 自身和所有的 tap（软件仓库）
  - 获取所有可用软件包的最新版本信息
  - 相当于 `git pull`，只是获取最新的软件包信息
  - **不会**更新已安装的软件包
  - 建议在执行 `brew upgrade` 之前先运行此命令

- brew upgrade
  - 将已安装的软件包更新到最新版本
  - 实际执行软件包的升级操作
  - 如果不指定具体软件包名称，会更新所有已安装的软件包
  - 可以指定特定软件包升级，如：`brew upgrade node`

最佳实践是：

```bash
# 1. 先更新 Homebrew 和软件包信息
brew update

# 2. 然后再升级需要的软件包
brew upgrade           # 升级所有软件包
# 或
brew upgrade 软件包名  # 升级指定软件包
```

- 如果想查看哪些包可以更新，可以使用：`brew outdated`
- 如果想查看已安装的包：`brew list`
- 如果不想更新某些包，可以将其锁定：`brew pin 软件包名`

#### 为什么有的 brew install 需要加 --cask

##### 普通包（Formula）

- 通常是命令行工具或库
- 直接使用 `brew install 包名` 安装
- 安装后的文件通常在 `/usr/local/bin` 或 `/opt/homebrew/bin` 目录下
- 例如：git, python, node 等

##### Cask 包

- 主要是 macOS 图形界面应用程序（GUI 应用）
- 使用 `brew install --cask 包名` 安装
- 它会下载预编译的应用程序包（通常是 .dmg 或 .pkg 文件）,安装后的应用会出现在 `/Applications` 目录下
- 例如：chrome, visual-studio-code, docker-desktop 等

##### 举例对比

```bash
# 命令行工具安装
brew install git
brew install python

# GUI 应用安装
brew install --cask google-chrome
brew install --cask visual-studio-code
```

- 如果是图形界面应用（比如能在 Mac App Store 找到的那种），一般用 `--cask`
- 如果是命令行工具，一般直接 `brew install`

#### Homebrew 中 Tap 和 Core

让我解释一下 Homebrew 中 Tap 和 Core 的区别：

##### Core（核心仓库）

- 是 Homebrew 的官方默认仓库
- 位于 `homebrew/core`
- 包含最常用、最基础的软件包
- 经过严格审核和测试
- 更新可能相对较慢，因为需要经过审核流程

##### Tap（第三方仓库）

- 是除了 Core 之外的额外软件源
- 可以由任何人创建和维护
- 更新更频繁，因为不需要经过 Homebrew 官方审核
- 通常由软件的开发者自己维护

##### 以 lazygit 为例

```bash
# 从 Core 安装
brew install lazygit  # 更稳定，但可能不是最新版

# 从开发者的 Tap 安装
brew install jesseduffield/lazygit/lazygit  # 更新更快，版本更新
```

格式说明：

- `jesseduffield/lazygit/lazygit` 的结构是：
  - `用户名/仓库名/软件包名`

- 如果你需要最新功能，选择 Tap 版本
- 如果你更注重稳定性，选择 Core 版本
- 如果软件作者建议使用他们的 Tap（如 lazygit 的例子），最好遵循他们的建议

## How to install Java?

1. 查看可用的 OpenJDK 版本

使用 `brew search` 命令列出可用的 OpenJDK 版本：

```shell
brew search openjdk
```

这将显示一个列表，包括长期支持 (LTS) 版本，例如：

```shell
==> Formulae
openjdk             openjdk@17          openjdk@8           openjph
openjdk@11          openjdk@21          openj9              openvdb
```

版本 8、11、17 和 21 是常见的 LTS 版本

1. 安装所需的版本

选择要安装的 Java 版本（例如，`openjdk@17` 表示 Java 17）。然后使用 `brew install` 进行安装：

```shell
brew install openjdk@17
```

1. 配置环境变量

根据你使用的 shell，配置环境变量的方式有所不同。

3.1 Fish Shell 配置

如果你使用的是 Fish shell，请将以下几行添加到你的 `~/.config/fish/config.fish` 文件中：

```fish
# 将 JAVA_HOME 设置为 OpenJDK 17 安装目录
set -x JAVA_HOME /opt/homebrew/opt/openjdk@17

# 将 OpenJDK 17 的 bin 目录添加到 PATH 的最前面
set -gx PATH /opt/homebrew/opt/openjdk@17/bin $PATH
```

3.2 Zsh Shell 配置

如果你使用的是 Zsh shell，请将以下几行添加到你的 `~/.zshrc` 文件中：

```zsh
# 将 JAVA_HOME 设置为 OpenJDK 17 安装目录
export JAVA_HOME="/opt/homebrew/opt/openjdk@17"

# 将 OpenJDK 17 的 bin 目录添加到 PATH 的最前面
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
```

1. 验证安装

编辑完配置文件 (`config.fish` 或 `.zshrc`) 后，**需要使配置生效**:

- 对于 `config.fish` 可以执行 `source ~/.config/fish/config.fish`
- 对于 `.zshrc` 可以执行 `source ~/.zshrc` 或者**重新启动终端**：

关闭终端窗口并打开一个新窗口。

现在，检查 Java 版本：

```shell
java --version
```

## 为什么有些时候我在 macos 上长按 jkhl 时会出现类似于希腊字母的选项，我只是想输入jjjjjj之类的

> (玩 Vim 玩得)

这是 macOS 的特殊字符输入功能。当你长按某些键时，会弹出带有变音符号和特殊字符的菜单。这个功能主要是为了输入带重音符号的字母（如é, ü等）

要禁用这个功能，在终端中执行以下命令：

```bash
defaults write -g ApplePressAndHoldEnabled -bool false
```

执行后需要重启系统才能生效

## MacOS 相册的底层组织逻辑

- **Remove from Album**（从相册中移除）  
  - **作用**：仅将选中的照片从当前相册中移除，**不影响照片在图库（Library）和其他相册中的存在**
  - **适用场景**：当你想整理相册结构（例如清理某个主题相册），但保留照片本身时使用

- **Delete Photos**（删除照片）  
  - **作用**：将照片**从整个图库中彻底删除**，并移至「最近删除」相册，30 天后永久清除
  - **影响**：所有包含该照片的相册（包括智能相册）中均不再显示该照片
  - **适用场景**：当照片不再需要，且希望释放存储空间时使用

苹果「照片」应用的核心设计基于以下原则：

- **中央化的图库（Library）**  
  所有照片和视频统一存储在图库中，作为唯一的“主数据源”。相册（Albums）仅是**对图库中文件的引用集合**，而非实际存储位置
  - **类比**：图库是数据库的主表，相册是关联表，仅保存对主表记录的引用

- **虚拟化的相册管理**  
  - **用户创建的相册**：手动选择的照片合集，移除操作仅删除引用
  - **智能相册**：基于规则（如日期、关键词）自动生成的动态合集，无法手动移除照片，只能修改规则。
  - **系统相册**：如「所有照片」「最近删除」等，具有特殊逻辑（如「最近删除」保留文件 30 天）

### **总结**

- **Remove from Album** = 整理相册结构，不删原图
- **Delete Photos** = 彻底删除照片，释放存储空间
- 底层逻辑：图库是核心，相册是“视图”，操作需区分引用与实体数据
