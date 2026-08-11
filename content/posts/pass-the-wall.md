---
title: "Pass the Wall"
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

## Xray Container

如果想在服务器的 docker container 里使用代理，如果只使用远程端口转发非常不方便，我们可以开启一个 Xray 容器来使用代理。

```shell

mkdir xray
touch xray/config.json

```

然后把下面的配置写入 `xray/config.json` 里:

```json
{
  "log": { "loglevel": "info" },

  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 10809,
      "protocol": "http",
      "settings": {}
    }
  ],

  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            // let GPT generate it for you
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "publicKey": "2O1Q7AJJC5sTUGsnxn_xE4APz-SNeFUEIHfAO00463g",
          "serverName": "yahoo.com",
          "shortId": "c35f90d2",
          "fingerprint": "chrome"
        }
      }
    },
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" }
  ],

  "dns": {
    "servers": ["223.5.5.5", "119.29.29.29", "1.1.1.1", "8.8.8.8"]
  },

  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "direct" },

      { "type": "field", "domain": ["geosite:cn"], "outboundTag": "direct" },
      { "type": "field", "ip": ["geoip:cn"], "outboundTag": "direct" },

      { "type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "block" },

      { "type": "field", "network": "tcp,udp", "outboundTag": "proxy" }
    ]
  }
}
```

然后运行 Xray 容器:

```shell
docker network create proxy

docker run -d -p 10809:10809 --name xray --network proxy --restart=always -v ./xray:/etc/xray teddysun/xray
```

> [!NOTE]
> 注意这里的 `-p 10809:10809`，如果你要修改的话，需要把 `config.json` 里的 `inbounds` 的 `port` 一起修改。

然后你就能愉快的使用代理了，在服务器里设置环境变量:

```shell
export http_proxy="http://localhost:10809"
export https_proxy="http://localhost:10809"
export HTTP_PROXY="http://localhost:10809"
export HTTPS_PROXY="http://localhost:10809"

export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com,$(hostname)"
export NO_PROXY="localhost,127.0.0.1,localaddress,.localdomain.com,$(hostname)"
```

如果需要让其他容器使用这个代理，可以把其他容器加入到 `proxy` 这个网络里:

```shell
docker network connect proxy [other-container-name]
```

在容器里设置代理环境变量:

```shell
export http_proxy="http://xray:10809"
export https_proxy="http://xray:10809"
export HTTP_PROXY="http://xray:10809"
export HTTPS_PROXY="http://xray:10809"

export no_proxy="localhost,127.0.0.1,localaddress,.localdomain.com,$(hostname)"
export NO_PROXY="localhost,127.0.0.1,localaddress,.localdomain.com,$(hostname)"
```

> [!SUMMARY]
> 不需要透明代理的话，这样设置是最简单的
>
> 如果需要透明代理(比如 TUN 模式)，可以直接在宿主机上使用 Xray 的 TUN 功能

## FRP

FRP (Fast Reverse Proxy) 是一个高性能的反向代理应用，主要用于内网穿透。它允许你将内网服务暴露到公网上，方便远程访问。

具有公网 IP 的服务器上运行 FRP 的服务端 (frps)，而在内网机器上运行 FRP 的客户端 (frpc)。

### frps 配置

```toml
bindPort = 7000

auth.method = "token"
auth.token = "your_secure_token"

allowPorts = [
  { start = 6000, end = 6299 }
]
```

然后通过以下命令启动 frps:

```shell
docker run -d \
  --name frps \
  --restart unless-stopped \
  -p 7000:7000 \
  -p 6000-6299:6000-6299 \
  -v $(pwd)/frps.toml:/etc/frp/frps.toml \
  snowdreamtech/frps
```

### frpc 配置

```toml
serverAddr = "your_frps_server_ip"
serverPort = 7000
auth.method = "token"
auth.token = "your_secure_token"

[[proxies]]
name = "ssh"
type = "tcp"
localPort = 22
remotePort = 6000
```

然后通过以下命令启动 frpc:

```shell
docker run -d \
  --name frpc \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/frpc.toml:/etc/frp/frpc.toml \
  snowdreamtech/frpc
```

查看一下日志，确保正常启动了

```shell
docker logs frpc

start frpc service for config file [/etc/frp/frpc.toml]
try to connect to server...
login to server success
proxy [ssh] start success
```

然后就可以通过下面的命令来访问：

```shell
ssh -p 6000 kkkzoz@[your_frps_server_ip]
```

## Docker

### Docker save/load

```shell
docker save snowdreamtech/frpc:latest > frpc-image.tar
docker load < frpc-image.tar
```

### Docker http-proxy

> 假设已经在本地 10809 端口开启了代理

注意这么设置的是 Docker daemon 的代理，只会用于：

+ docker pull / push
+ docker build（RUN apt / curl / wget）
+ daemon 自身的 HTTP 请求

**容器本身的 Proxy 不会受影响**

```shell
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo vim /etc/systemd/system/docker.service.d/http-proxy.conf
```

写入以下内容

```conf
[Service]
Environment="HTTP_PROXY=http://localhost:10809"
Environment="HTTPS_PROXY=http://localhost:10809"
Environment="NO_PROXY=localhost,127.0.0.1"
```

然后执行

```shell
sudo systemctl daemon-reexec
sudo systemctl restart docker
```

## Network Proxy

工位上的主机网络带宽被限制了，在白天只有 1MB/s

但是所机房的服务器网络带宽没有被限（通常有 20MB/s），而且工位的主机访问所机房服务器的速度也很快

所以我们就可以通过流量转发的方式，把工位主机的网络流量转发到所机房服务器上，达到网络加速的效果

在服务器上：

```shell
docker run -d \
    --name gost-server \
    --restart=always \
    --net=host \
    ginuerzh/gost \
    -L admin:123456@:1080
```

在工位主机上：

```shell
export http_proxy="http://admin:123456@124.16.138.62:1080"
export https_proxy="http://admin:123456@124.16.138.62:1080"
export HTTP_PROXY="http://admin:123456@124.16.138.62:1080"
export HTTPS_PROXY="http://admin:123456@124.16.138.62:1080"
```

如果有图形界面，可以在系统设置 -> 网络 中设置代理，这样浏览器之类的也会走这个代理

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
