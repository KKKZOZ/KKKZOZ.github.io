---
title: "Software Router"
tags:
  - Dev
date: 2026-01-05
showtoc: true
weight: 10
---

记录一下折腾软路由的过程，我主要是用于旁路由

> 很早之前买了一个电犀牛的 R66s，大三大四还有研一在用，回所后吃灰了一段时间

第一步是刷机，可以从[这里](https://github.com/haiibo/OpenWrt)获取镜像

刷到内存卡上，然后用网线连接路由器的 LAN 和你的电脑

默认管理后台是 <http://192.168.1.1>

打开后主要设置网络接口，把软路由 LAN 口的属性固定下来：

```config
IP: 一个固定的 IP
网关：实际路由器的 IP
DNS：实际路由器的 IP
```

最重要的一点，记得关闭这个口的 DHCP

设置好后，在 PassWall 或者类似的插件中设置一下，然后把软路由的 LAN 口连接到路由器的 LAN 口就行了

对于要上网的设备来说，还是正常连接路由器，然后手动设置 IP

```config
IP: 一个固定的 IP
网关：软路由的 IP
DNS：软路由的 IP
```
