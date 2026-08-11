---
title: "CLI Notes"
tags:
  - Dev
date: 2026-03-17
showtoc: true
weight: 10
---

> 记录一些我在使用 cli 时简单整理的一些东西

## Setup

### Docker

```shell
curl -fsSL https://get.docker.com -o get-docker.sh
sudo DOWNLOAD_URL=https://mirrors.ustc.edu.cn/docker-ce sh get-docker.sh
```

```shell
sudo groupadd docker # optional
sudo usermod -aG docker $USER
newgrp docker

sudo systemctl start docker
```

### apt

替换镜像源：

For 24.04:

```shell
sed -i "s@http://.*archive.ubuntu.com@https://mirrors.aliyun.com/@g" /etc/apt/sources.list.d/ubuntu.sources
sed -i "s@http://.*security.ubuntu.com@https://mirrors.aliyun.com/@g" /etc/apt/sources.list.d/ubuntu.sources
sed -i "s@http://ports.ubuntu.com@https://mirrors.aliyun.com@g" /etc/apt/sources.list.d/ubuntu.sources
```

For 22.04:

```shell
sed -i "s@http://.*archive.ubuntu.com@https://mirrors.aliyun.com/@g" /etc/apt/sources.list
sed -i "s@http://.*security.ubuntu.com@https://mirrors.aliyun.com/@g" /etc/apt/sources.list
```

## Network

```shell
# 查看网关
ip route

# 查看 ip 地址
ip addr

# 查看每个进程的网速
sudo apt install nethogs
nethogs
```

### apt

sudo 会为了安全重置环境变量, 加上 -E 参数来保留当前的环境变量

> 比如让 `http_proxy` 之类的生效

```shell
sudo -E apt update
```

## fish

### `fish_add_path`

```fish
fish_add_path /Applications/Obsidian.app/Contents/MacOS
```

可以通过下面几种方式来查看这种方式管理的路径

```fish
echo $fish_user_paths

printf '%s\n' $fish_user_paths

printf '%s\n' $PATH
```

这些持久化的 universal variables 实际上存放在 `~/.config/fish/fish_variables` 中

### unset environment variables

```shell
# set/export
set -x XXX

# unset
set -e XXX
```

## uv

### mirror

在 `pyproject.toml` 中添加

```toml
[[tool.uv.index]]
name = "aliyun"
url = "https://mirrors.aliyun.com/pypi/simple/"
default = true
```

### uv pip install

+ `uv pip install xxx -v` 可以确定是否走了 mirror
+ `uv pip install xxx` 会在当前目录及其父目录查找 pyproject.toml 或 uv.toml，并读取其中的 `[tool.uv]` 配置，所以在 pyproject.toml 中配置了 index 就能正常使用

### 查看包的版本

```shell
uv pip show transformers

uv pip list | grep transformers
```

## Git

### worktree

```shell
# Navigate to your main repository
cd /path/to/your/project

# Add a new worktree in a parallel directory and create a new branch for the AI
git worktree add ../project-ai-workspace -b ai-feature-branch

# Verify the worktrees are active
git worktree list

# Expected Output:
# /path/to/your/project           <hash> [main]
# /path/to/your/project-ai-workspace <hash> [ai-feature-branch]
```

```shell
# Navigate back to your primary working directory
cd /path/to/your/project

# Fetch the local branch changes (no network fetch needed since they share the local .git)
git merge ai-feature-branch --no-commit

# Or simply checkout the branch in your main IDE to review
git checkout ai-feature-branch
```

## Cost

```shell
npx ccusage@latest --offline
npx @ccusage/codex@latest --offline

bunx ccusage@latest --offline
bunx @ccusage/codex@latest --offline
```

## v2raya

```shell
docker run -d \
  --restart=always \
  --privileged \
  --network=host \
  --name v2raya \
  -e V2RAYA_LOG_FILE=/tmp/v2raya.log \
  -e V2RAYA_V2RAY_BIN=/usr/local/bin/xray \
  -e V2RAYA_NFTABLES_SUPPORT=off \
  -e IPTABLES_MODE=legacy \
  -v /lib/modules:/lib/modules:ro \
  -v /etc/resolv.conf:/etc/resolv.conf \
  -v /etc/v2raya:/etc/v2raya \
  mzz2017/v2raya
```
