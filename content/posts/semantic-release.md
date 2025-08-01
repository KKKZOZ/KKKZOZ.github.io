---
title: "Semantic Release in Practice"
tags:
  - Dev
date: 2025-06-26
showtoc: true
draft: true
weight: 10
---

> 之前在维护 [`hugo-admonitions`](https://github.com/KKKZOZ/hugo-admonitions) 项目时, 一直都是手动打 tag, 然后发布新版本, 现在想尝试一下 `semantic-release` 的自动化发布流程

## 关键文件

几份关键文件:

+ `.github/workflows/release.yml`: 负责在 main 分支有新提交时自动执行 semantic-release
+ `.github/workflows/commitlint.yml`: 负责在提交 PR 时检查 commit message 是否符合规范
+ `release.config.js`: semantic-release 的配置
+ `commitlint.config.js`: 用于配置 commit message 的规范
+ `./husky/commit-msg`: 用于在提交时检查 commit message 是否符合规范

### `.github/workflows/release.yml`

```yml
name: 📦 Release

on:
  push:
    branches:
      - main
  pull_request:
    types: [closed]
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - name: Install dependencies
        run: npm ci

      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: npx semantic-release
```

### `.github/workflows/commitlint.yml`

```yml
name: 🚨 Commit Message Lint

on:
    push:
        branches-ignore:
            - 'dependabot/**'
    pull_request:

jobs:
    commitlint:
        name: Validate commit messages
        runs-on: ubuntu-latest
        steps:
            - name: Checkout repository
              uses: actions/checkout@v3
              with:
                  fetch-depth: 0

            - name: Setup Node.js
              uses: actions/setup-node@v3
              with:
                  node-version: '20'

            - name: Install dependencies
              run: npm ci

            - name: Lint commit messages
              if: github.event_name == 'pull_request'
              run: |
                  npx commitlint \
                    --from="${{ github.event.pull_request.base.sha }}" \
                    --to="${{ github.event.pull_request.head.sha }}"
            - name: Lint commit messages (push)
              if: github.event_name == 'push'
              run: |
                  npx commitlint \
                    --from="${{ github.event.before }}" \
                    --to="${{ github.sha }}"

```

### `release.config.js`

```js
module.exports = {
  branches: ['main'],

  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    '@semantic-release/changelog',
    '@semantic-release/github'
  ]
};
```

### `commitlint.config.js`

```js
module.exports = {
    extends: ['@commitlint/config-conventional'],
};
```

### `./husky/commit-msg`

```bash
npx --no-install commitlint --edit "$1"

```

## 安装

如果不是 nodejs 项目, 可以直接采用下面的这份 `package.json`:

```json
{
  "scripts": {
    "prepare": "husky"
  },
  "devDependencies": {
    "@commitlint/cli": "^19.8.1",
    "@commitlint/config-conventional": "^19.8.1",
    "@semantic-release/changelog": "^6.0.3",
    "@semantic-release/commit-analyzer": "^13.0.1",
    "@semantic-release/github": "^11.0.3",
    "@semantic-release/npm": "^12.0.1",
    "@semantic-release/release-notes-generator": "^14.0.3",
    "husky": "^9.1.7",
    "semantic-release": "^24.2.5"
  }
}

```

## 说明

在 `semantic-release` 中，版本号的增量完全由“语义化提交”（Conventional Commits）规范驱动，借助 `@semantic-release/commit-analyzer` 插件自动计算“下一个版本”应当是 major、minor 还是 patch。

1. 语义化提交基本格式  

   ```text
   <type>[optional scope]: <description>
   [optional body]
   [optional footer(s)]
   ```

   + type：必选，用来表明改动类别，例如 `feat`、`fix`、`docs`…  
   + scope：可选，标识改动影响的模块/子系统，如 `feat(parser): …`  
   + footer：可选，用来写 BREAKING CHANGE 或关联 Issue/PR

2. 默认类型→版本映射  
   `@semantic-release/commit-analyzer` 插件默认使用 [conventional-changelog-angular](https://github.com/conventional-changelog/conventional-changelog/tree/master/packages/conventional-changelog-angular) 预设：  
   + feat → **minor**  
   + fix → **patch**  
   + perf → **patch**  
   + 其他类型（docs, style, refactor, test, chore, build, ci 等）→ **no release**  

3. BREAKING CHANGE → **major**  
   任何 commit 的 footer 或 body 中包含关键字 `BREAKING CHANGE:`，或在 type 后面加 “！”（即 `feat!:`、`fix!:` 之类）都被视为大破坏性变更，触发 **major** 发布。  
   例：  

   ```text
   feat!: drop Node.js 10 支持
   
   BREAKING CHANGE: API X 的入参 Y 类型由 string 改为 number
   ```

   以上即使只有一个 feat，也会被算作 **1.0.0**（假设上一个版本是 0.x.x）。

4. 多类型提交时取最高级别  
   如果一次发布周期里既有 feat 又有 fix，semantic-release 会取“最重大”的那一个版本等级：  
   + 出现 breaking change → major  
   + 否则出现 feat → minor  
   + 否则出现 fix/perf → patch  
   + 否则不发布

5. 自定义规则（releaseRules）  
   你可以在 `release.config.js` 或 `package.json` 的 `release` 字段中，用 `releaseRules` 覆盖或扩展默认映射：  

   ```js
   module.exports = {
     plugins: [
       ['@semantic-release/commit-analyzer', {
         preset: 'angular',
         releaseRules: [
           // 原生 feat → minor, fix → patch 会保留
           {type: 'docs', release: 'patch'},    // 文档改动也触发 patch
           {type: 'refactor', release: 'patch'},// 重构也触发 patch
           {scope: 'no-release', release: false}// 某个 scope 不触发发布
         ]
       }],
       // … 其它插件
     ]
   };
   ```

   这样：  
   + `docs: update README` → patch  
   + `refactor(parser): …` → patch  
   + `feat(no-release): X` → **不发布**

6. 预设之外的插件协同  
   + `@semantic-release/release-notes-generator`：把按照上面分类的 commits 整理到 CHANGES.md 或 GitHub Release Notes  
   + `@semantic-release/changelog`：自动更新本地 `CHANGELOG.md`  
   + `@semantic-release/github`：打 tag、在 GitHub Release 页面创建 Release  

7. “第一次发布”的起点  
   + 如果仓库里 **有** 符合 tag pattern（默认 `v*.*.*`）的历史 tag，semantic-release 会把最近的那个当作“上次发布”的版本基准。  
   + 如果仓库里 **没有** 任何符合规则的 tag，就当做从零开始，第一次发布会走 **1.0.0**（除非你在配置里改了 `tagFormat` 或 `initialVersion`）。

8. 小结示例  

   假设上次 tag 是 `v2.3.4`，本次待发布提交有：  
   + `fix: 修复内存泄漏`  
   + `feat(parser): 支持新的语法`  
   + `docs: 更新示例`  

   计算流程：  
   1) 检查 breaking → 无  
   2) 检查 feat → 有 → **minor**  
   3) 再 patch commit 会合并到这次 release 的 notes，但不影响版本等级  
   结果：**v2.4.0**

   如果同时还有一条  
   `refactor!: 重构整个核心模块`（带 `!`）  
   那就变成 **major** → **v3.0.0**

## 实例

See [here](https://github.com/KKKZOZ/github-workflows)
