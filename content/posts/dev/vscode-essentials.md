---
title: "VSCode Essentials"
tags:
  - Dev
date: 2025-08-06
showtoc: true
weight: 10
---

> Essential Understandings about VSCode.
>
> This post will continue to update to cover every major update of VSCode.

## Concepts

### Workspace

VSCode 的工作区有两种:

1. 单文件夹工作区 (Single-Folder Workspace)

这是最常见、最简单的一种。当你使用 `File` -> `Open Folder` 打开一个文件夹时，这个文件夹就成为了你的当前工作区。VSCode 的所有操作和配置（比如在 `.vscode` 目录下的文件）都是相对于这个根文件夹的。

2. 多根工作区 (Multi-root Workspace)

一个多根工作区可以包含多个不同位置的文件夹，但它们都在同一个 VSCode 窗口中管理。

场景：想象一个复杂的项目，它的前端代码在一个仓库（比如 `my-webapp`），后端代码在另一个完全独立的仓库（比如 `my-api-server`）。你希望同时能看到并编辑这两个项目的代码。

操作：

+ 先打开其中一个文件夹（例如 `my-webapp`）。
+ 然后点击 `File` -> `Add Folder to Workspace`，并选择 `my-api-server`.
+ 此时文件浏览器里会同时出现这两个文件夹。
+ 最后，点击 `File` -> `Save Workspace As...`, VSCode 会创建一个后缀为 `.code-workspace` 的文件。

以后只需要直接打开这个 `.code-workspace` 文件，就能恢复包含多个项目文件夹的工作环境。

总结：所以，“工作区”是你当前在 VSCode 中的项目上下文。它可以是一个简单的文件夹，也可以是一个由 `.code-workspace` 文件定义的、包含多个文件夹的集合。

> [!TIP]
> 使用命令行打开 VSCode 时
>
> + `code .` 打开当前文件夹作为工作区
> + `code my-project.code-workspace` 打开指定的多根工作区

### Profiles

一个 Profile 是 VSCode 一套完整的、可命名的、独立的配置集合。它像一个“快照”，保存了你为了特定“任务类型”而定制的整个编辑器环境。

一个 Profile 包含了以下内容：

+ Settings：所有在 settings.json 中能定义的配置项，比如字体大小、主题、特定语言的格式化规则等。
+ Extensions：你可以精确控制在这个 Profile 中，哪些扩展是启用的，哪些是禁用的。
+ Keyboard Shortcuts：你可以为不同 Profile 定义完全不同的快捷键绑定。
+ UI 状态：包括侧边栏、面板的布局，甚至哪些视图是可见的。
+ 任务和启动配置：每个 Profile 可以有自己独立的 tasks.json 和 launch.json。

核心思想：让你能够为不同类型的工作（而不是不同的项目）创建截然不同的工作环境。例如：

+ C++ Profile: 启用 C/C++, CMake, Debugger 扩展，使用暗色主题，显示调试侧边栏。
+ Python Profile: 启用 Python, Pylance, Jupyter 扩展，禁用 C++ 扩展。
+ Blog Profile: 禁用所有编程扩展，启用 Markdown Linter, Word Count 扩展，使用亮色主题，并开启“禅模式”布局。

> [!NOTE]
> Profiles 和 Workspaces 是两个正交的、互不隶属的概念。
>
> + Workspace：定义了你正在处理什么项目（即“内容”）。它关心的是你打开了哪些文件夹、项目的具体配置（例如 .vscode/settings.json）。
> + Profile：定义了你如何处理这个项目（即“环境”或“工具集”）。它关心的是编辑器本身的外观、行为和启用的工具。

> [!QUESTION] 如何为 Workspace 指定默认的 Profile？
>
> + 如果是 Multi-root Workspace, 可以在 `.code-workspace` 文件中指定。
> + 如果是 Single-Folder Workspace, 可以在 VSCode 的 `Profiles` 界面中设置。

### 设置优先级

![vscode-settings](/images/vscode-settings.png)

VSCode 提供了多级别的设置, 优先级从低到高依次为：

+ **Default Settings**：VSCode 内置的默认设置, **只读**
+ **Application Settings**：全局设置, 适用于所有工作区, 新创建 Profile 时可以选择是从 Application Settings 继承还是从零开始
+ **User Settings**: Profile 级别的设置
+ **Workspace Settings**：工作区级别的设置, 只对当前工作区生效

这么多配置文件, 如何判断你目前打开的是哪个配置文件呢？

可以通过 Editor 上方的路径来判断:

> On MacOS.

+ **Default Settings**: `/defaultSettings.json`
+ **Application Settings**: `~/Library/Application Support/Code/User/settings.json`
+ **User Settings**: `~/Library/Application Support/Code/User/profiles/451e71b8/settings.json`
+ **Workspace Settings**: `.vscode/settings.json`
  + 注意只有这个是相对路径

> Profile 是最近一两年才引入的概念, 要是 User Settings 能改为 Profile Settings 就更好了

优先级高的设置会覆盖优先级低的设置。

在 Plugin 界面, 我们就能区分 Profile 和 Workspace 的设置:

当你禁用一个插件时, 会有两个选项:

+ Disable: 只在当前 Profile 中禁用
+ Disable (Workspace): 在当前工作区中禁用

这样的 Settings Hierarchy 可以让我们非常灵活地对 VSCode 进行设置:

+ 自定义每个 Profile 的行为: 修改 **User Settings**
+ 自定义每个 Workspace 的行为: 修改 **Workspace Settings**
+ 在不同的 Profile 之间共享设置: 修改 **Application Settings**
+ 在不同的工作区之间共享设置: 修改 **User Settings**

```ascii
┌─────────────────────────────────────────────────────────────────┐
│                    Application Settings                         │
│             (Shared across different Profiles)                  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
            ┌───────────────────────────────────┐
            │          User Settings            │
            │     (Customize Profile behavior)  │
            │    (Shared across Workspaces)     │
            └─────────────────┬─────────────────┘
                              │
                ┌─────────────┼─────────────────┐
                ▼             ▼                 ▼
          ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
          │ Workspace A │ │ Workspace B │ │ Workspace C │
          │  Settings   │ │  Settings   │ │  Settings   │
          │ (Customize  │ │ (Customize  │ │ (Customize  │
          │ Workspace   │ │ Workspace   │ │ Workspace   │
          │ behavior)   │ │ behavior)   │ │ behavior)   │
          └─────────────┘ └─────────────┘ └─────────────┘
```

### .vscode 文件夹

`.vscode` 文件夹是 VSCode 工作区的配置目录。它通常位于工作区根目录下，包含了与该工作区相关的所有配置文件。

常见的文件有三个:

+ `settings.json`: 工作区级别的设置
+ `tasks.json`: 工作区级别的任务配置
+ `launch.json`: 工作区级别的调试配置

#### settings.json

核心用途：配置 VSCode 编辑器本身以及扩展插件的行为。它掌管着整个项目的“环境”。

> [!QUESTION] 什么时候修改它？
> 当你想改变开发环境或插件的工作方式时。

+ “我希望保存文件时自动格式化代码。” (`editor.formatOnSave`)
+ “我希望 CMake 把文件编译到 build_release 目录而不是默认的 build 目录。” (`cmake.buildDirectory`)
+ “我想告诉 C++ 插件我的编译器装在了哪里，让智能提示（IntelliSense）正常工作。” (`C_Cpp.default.compilerPath`)
+ “我想为这个项目设置一个特定的主题和字体大小。” (`workbench.colorTheme`)

Example:

```json
{
    // 告诉 CMake 扩展，编译输出目录叫什么名字
    "cmake.buildDirectory": "${workspaceFolder}/build_debug",
    // 告诉 C/C++ 扩展，代码格式化的风格
    "C_Cpp.default.cppStandard": "c++17",
    // 告诉编辑器，保存时自动格式化
    "editor.formatOnSave": true
}
```

#### tasks.json

核心用途：自动化命令行工具的执行。它定义了一个个可以被调用的“任务”。

> [!QUESTION] 什么时候修改它？
> 当你想在 VSCode 中一键执行某个终端命令或脚本时。

+ “我想创建一个‘clean’任务，一键删除所有编译好的文件。” (执行 `rm -rf build` 或 `cmake --build . --target clean`)
+ “我想写一个任务来自动运行我的 Python 测试脚本。” (执行 `python run_tests.py`)
+ “我想把‘编译’和‘运行测试’这两个动作绑在一起成为一个新任务。”

Example:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
        "label": "Clean Build Directory",
        "type": "shell",
        "command": "rm -rf ${workspaceFolder}/build_debug"
        }
    ]
}
```

> 常见的 type 有 shell 和 process, 许多扩展也会贡献自己的任务类型, 比如 cmake, npm 等.

#### launch.json

核心用途：专门配置如何启动和调试你的程序。

> [!QUESTION] 什么时候修改它？
> 当你需要控制可执行程序的运行方式时。

+ “我想给我的程序传递几个命令行参数再启动。” ("args")
+ “我的程序需要读取一个文件，我想让它在特定的目录下运行。” ("cwd")
+ “我想在程序启动前自动设置一些环境变量。” ("environment")
+ “我的项目里有多个可执行文件，我想为每一个都创建一个独立的启动选项。” (创建多个 configuration 对象)
+ “我想把调试器附加到一个已经在运行的进程上。” ("request": "attach")

Example:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug my_app",
      "type": "cppdbg",
      "request": "launch",
      "program": "${command:cmake.launchTargetPath}",
      // 为你的程序指定命令行参数
      "args": ["--input", "data.txt"],
      // 指定程序运行时的当前工作目录
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

#### 三者的关系

这三者不是完全独立的，它们之间存在调用和依赖关系，这也是它们经常一起出现的原因。

**最经典的关系是：`launch.json` 调用 `tasks.json`.**

你可以在 `launch.json` 中，通过 `preLaunchTask` 字段，指定在**启动调试之前**需要先执行 `tasks.json` 中定义的一个任务。

**场景**：我想在每次按 `F5` 调试程序前，都确保程序是最新编译的。

1. **`tasks.json`**：定义一个名为 `build` 的编译任务。

```json
// tasks.json
{
    "label": "build",
    "type": "shell",
    "command": "cmake --build ${workspaceFolder}/build_debug"
}
```

2. **`launch.json`**：在启动配置中，引用这个 `build` 任务。

```json
// launch.json
{
    "name": "Debug my_app",
    "type": "cppdbg",
    "request": "launch",
    "program": "...",
    "args": [],
    "preLaunchTask": "build" // <-- 在启动前，先执行名为 "build" 的任务
}
```

**工作流**：你按下 `F5` -\> `launch.json` 生效 -\> 它发现 `preLaunchTask` -\> 去 `tasks.json` 里找到名为 `build` 的任务并执行 -\> `build` 任务调用 `cmake` 命令进行编译 -\> 编译成功后 -\> `launch.json` 继续执行，启动调试器加载最新编译好的程序。

而这一切的背后，编译目录等信息又是由 `settings.json` 提供的。

#### 总结

| 文件名 | 核心作用 | 修改时机 |
| :--- | :--- | :--- |
| **`settings.json`** | 配置 **环境** 和 **插件** | 想改变编辑器或扩展的行为时 |
| **`tasks.json`** | 定义 **动作** 和 **命令** | 想自动化执行终端/脚本命令时 |
| **`launch.json`** | 配置 **运行** 和 **调试** | 想控制可执行程序的启动方式时 |

## Update

### July 2025 (version 1.103)[^1]

+ Chat
  + GitHub Copilot 更新了 GPT5 模型, 我怀疑本月更新是专门等到 GPT5 发布之后才推送的。
  + 在 Chat 中引入了 checkpoints, 支持返回到聊天对话中的特定点, 同时同步工作区的更改。
  + Chat Agent 模式支持 task lists, 可以实时看到 agent 的整体规划和进度。
  + 终于支持在 Chat 界面渲染数学公式了
+ MCP 部分我一直没用过, 跳过
+ Misc.
  + VSCode 支持 Git worktree 了, 在多分支开发中非常方便
  + 能够在 Status Bar 中展示 AI statistics

[^1]: [July 2025 (version 1.103)](https://code.visualstudio.com/updates/v1_103)
