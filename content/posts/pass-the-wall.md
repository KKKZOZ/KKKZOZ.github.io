---
title: "Pass The Wall"
tags:
  - Dev
date: 2025-03-30
showtoc: true
weight: 10
---

> "Across the Great Wall we can reach every corner in the world."[^1]

## Remote Port Forwarding

> 让云服务器方便快捷地使用本地代理

1. 建立远程端口转发

```shell
ssh -R 1082:127.0.0.1:1082 s2-ljy -p 22
```

2. 配置云服务器的代理环境变量

```shell
export HTTP_PROXY="http://127.0.0.1:1082"
export HTTPS_PROXY="http://127.0.0.1:1082"
```

> [!CAUTION]
> 这是临时设置, 仅对当前终端生效, 如果想永久设置, 请编辑 `~/.bashrc`

### Local vs Remote Port Forwarding

#### Local Port Forwarding

```shell
ssh -L [本地端口]:[目标主机]:[目标端口] [SSH服务器]
```

作用:

+ 在本地机器上监听一个端口，所有发往该端口的流量都会通过 SSH 隧道转发到目标主机:目标端口
+ 适用于访问远程内网服务（如数据库、Web 服务）

Example:

```shell
ssh -L 8080:localhost:80 user@remote-server
```

本地访问 `localhost:8080` → 实际访问的是 `remote-server` 上的 `localhost:80`

#### Remote Port Forwarding

```shell
ssh -R [远程端口]:[目标主机]:[目标端口] [SSH服务器]
```

作用：

+ 在远程 SSH 服务器上监听一个端口，所有发往该端口的流量都会通过 SSH 隧道转发到目标主机:目标端口（通常是你的本地机器）
+ 适用于让外部访问你的本地服务（如本地开发环境暴露给公网）

Example:

```shell
ssh -R 1082:127.0.0.1:1082 s2-ljy -p 22
```

s2-ljy 这台服务器上访问 `localhost:1082` -> 实际访问的是本机的 `localhost:1082`

> [!SUMMARY]
| 特性               | Local Port Forwarding (`-L`)        | Remote Port Forwarding (`-R`)       |
|--------------------|------------------------------------|------------------------------------|
| **监听端口的机器** | 你的本地电脑                       | 远程 SSH 服务器                    |
| **数据流向**       | 本地 → 远程                       | 远程 → 本地                       |
| **典型用途**       | 访问远程内网服务                   | 暴露本地服务给远程                 |
| **示例**           | `ssh -L 8080:localhost:80 user@server` | `ssh -R 9000:localhost:3000 user@server` |

## Configuring Mirrors for Development Tools

### pip

+ 临时使用:

```shell
pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple [some-package]
```

+ 设为默认:

升级 pip 到最新的版本后进行配置:

```shell
python -m pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple --upgrade pip
pip config set global.index-url https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
```

### pyenv

```shell
export PYTHON_BUILD_MIRROR_URL="https://registry.npmmirror.com/-/binary/python"
export PYTHON_BUILD_MIRROR_URL_SKIP_CHECKSUM=1

# Then
pyenv install 3.12
```

### poetry

通过以下命令为单个项目设置首选镜像：

```shell
poetry source add --priority=primary mirrors https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple/
```

### rust

安装 Rust:

```shell
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh | sh
```

设置 crates.io 镜像:

修改  ~/.cargo/config

```toml
[source.crates-io]
replace-with = 'rsproxy-sparse'
[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"
[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"
[net]
git-fetch-with-cli = true
```

### npm

```shell
# 查询当前使用的镜像源
npm get registry

# 设置为淘宝镜像源
npm config set registry https://registry.npmmirror.com/

# 验证
npm get registry
```

### yarn

```shell
# 查询当前使用的镜像源
yarn config get registry

# 设置为淘宝镜像源
yarn config set registry https://registry.npmmirror.com/
```

### pnpm

```shell
# 查询当前使用的镜像源
pnpm get registry

# 设置为淘宝镜像源
pnpm config set registry https://registry.npmmirror.com/
```

### golang

```shell
go env -w GOPROXY=https://goproxy.cn,direct
```

### git

> 不如直接开代理

```shell
git clone https://gitclone.com/github.com/gogs/gogs.git
```

更多配置方式请参阅[官网](https://gitclone.com/docs/feature/gitclone_web)

### maven

`vim ~/.m2/settings.xml`

```xml
<mirrors>
<mirror>
    <id>aliyunmaven</id>
    <mirrorOf>*</mirrorOf>
    <name>阿里云公共仓库</name>
    <url>https://maven.aliyun.com/repository/public</url>
</mirror>
</mirrors>
```

---
[^1]: [China first email](https://baike.baidu.com/item/%E4%B8%AD%E5%9B%BD%E7%AC%AC%E4%B8%80%E5%B0%81%E7%94%B5%E5%AD%90%E9%82%AE%E4%BB%B6/15554560)
