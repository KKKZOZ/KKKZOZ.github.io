---
title: "Note: WSL2 Mirrored 网络模式下异常情况总结"
tags:
  - Dev
date: 2023-11-25
toc: true
---

## Background

前段时间看到了 [Windows Subsystem for Linux September 2023 update - Windows Command Line](https://devblogs.microsoft.com/commandline/windows-subsystem-for-linux-september-2023-update/) 这篇文章后，发现了 WSL 2 的新网络模式挺有意思的：

> Networking improvements are a consistent top ask for WSL, and this feature aims to improve the networking experience in WSL! This is a complete overhaul on the traditional NAT networking architecture of WSL, to an entirely new networking mode called “Mirrored”. The goal of this mode is to mirror the network interfaces that you have on Windows into Linux, to add new networking features and improve compatibility.
>
> Here are the current benefits to enabling this mode:
>
> - IPv6 support
> - Connect to Windows servers from within Linux using the localhost address 127.0.0.1
> - Connect to WSL directly from your local area network (LAN)
> - Improved networking compatibility for VPNs
> - Multicast support

于是果断升级了了 Preview 版的 WSL 2，但是最近在使用时遇到了两个问题，还是花了一段时间来解决，所以还是在这里记录一下。

## SSH Connect

我之前买了一台 M2 的 Mac Mini 放在寝室里面用，为了把那台内存 24GB 的拯救者也用上，就打算有些使用 VSCode 的工作就直接通过 SSH 连过去用，本来以为把 WSL 的网络模式设为 Miorred 后就能直连，但其实至少还有以下几步：

- 在 WSL 中安装 SSH (注意不需要在 Windows 中进行 SSH 的相关配置)
  - 这里如果要设置开机启动的话还要多一步，因为 systemctl 不能直接在 WSL 中使用
- 设置端口，配置 SSH Keys

然后我用 Mac Mini 在局域网中直连却被拒绝了，去网上一顿搜才发现是 HyperV 的防火墙还要设置：

```bash
New-NetFirewallHyperVRule -Name "WSL 2" -Action Allow -Direction Inbound -LocalAddress Any -RemoteAddress Any -Protocol Any -LocalPort Any -RemotePort Any
```

如果是只想放行一个端口的话也行：

```bash
New-NetFirewallHyperVRule -DisplayName "allow WSL ssh" -Direction Inbound -LocalPorts 2222 -Action Allow
```

这样就能随便连啦。

## Docker Forwarding Ports

把 WSL2 的网络模式更改后，一直没咋使用 Docker，有段时间嫌它占资源，甚至都没允许它开机启动，最近突然需要用它临时开几个数据库用用，突然发现容器能正常运行，但是连接总是被拒绝。

急着用的那段时间我猜到了是这个新的网络模式的锅，毕竟在那篇博客里说了微软家的亲儿子 VSCode 使用这个新网络模式时都会有不兼容的情况，所以赶紧换回了原来的 NAT 模式。

今天没事了我又去研究了一下，我一开始以为是 HyperV 防火墙的锅，放行了对应的端口后还是连接不上，又去网上一顿找，找到了这篇帖子：[WSL 2.0: `networkingMode=mirrored` makes Docker unable to forward ports · Issue #10494 · microsoft/WSL](https://github.com/microsoft/WSL/issues/10494)。

---

> 2024/01/22 更新

此问题可以通过升级 Docker Desktop 至 4.25.0 及更高版本解决。我当前的 `.wslconfig` 恢复为了：

```config
# Settings apply across all Linux distros running on WSL 2
[wsl2]
memory=8GB
swap=4GB
[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
networkingMode=mirrored
dnsTunneling=true
firewall=false
autoProxy=true
# hostAddressLoopback=true
# ignoredPorts=5432,3306,27017,6379
```

---

这篇帖子的大概意思就是说，现在 WSL 的团队还在和 Docker 那边的开发团队合作解决这个问题，目前只有临时的解决方案，后续的具体解决办法可以跟踪这个 issue，这里摘抄一名哥们的总结：

### Option1 - without docker desktop

Edit `%USERPROFILE%\.Wslconfig` file (create it, if doesn't exist) and add this section

```config
[experimental]
NetworkingMode=mirrored
HostAddressLoopback=true
```

Restart WSL, then in your distro, edit `/etc/docker/daemon.json` and add

```json
{
  "iptables": false
}
```

Then `sudo systemctl restart docker`.

With this, both normal port usage like `python3 -m http.server` and docker port usage like `docker run -p "8080:8080" --rm -t mendhak/http-https-echo:26` are accessible from Windows side. The disadvantage is that `iptables` is now disabled.

### Option 2 - with Docker Desktop

Edit `%USERPROFILE%\.wslconfig` file (create it, if doesn't exist) and add this section

```config
[experimental]
NetworkingMode=mirrored
HostAddressLoopback=true
IgnoredPorts = 8000,8080
```

Restart WSL and ensure Docker Desktop is running. With this, the normal port usage stops working if it uses a port listed above. Eg the Python http. Server isn't accessible over 8000 anymore (at least in my testing). Instead use a different port, like `python3 -m http. server 8001`. Docker ports will work as normal as long as the port is listed in the ignoredPorts above, like `docker run -p "8080:8080" --rm -t mendhak/http-https-echo:26`

**_The disadvantage here is you have to know which ports you'll be using with Docker._** And it doesn't look like ignoredPorts accepts ranges of ports either so it can get pretty tedious.

目前我使用的是第二种方案，因为平常就使用 Docker 去运行一些数据库，所以需要暴露的端口相对固定，所以直接这么配置：

```config
ignoredPorts=5432,3306,27017,6379
```

And ignoredPorts only applies to docker containers it seems, not simple python http servers, unless I messed up?
Did anyone run into the ignoredPorts issue as I did, for non-Docker applications?
