---
title: "Server Management"
tags:
  - Dev
date: 2026-01-08
showtoc: true
weight: 10
---

> 组内有三台 Ubuntu 的服务器是我在管，这里记录一些常用操作

## 创建用户相关

```shell
sudo adduser [username]

# 查看一个用户所属的所有组
groups [username]

# 查看一个组里面有哪些用户
getent group groupname

# 创建组
sudo groupadd <groupname>

# 将一个用户添加到某个组里面
sudo usermod -aG groupname username
```

## 硬盘管理相关

```shell
# 查看整体使用情况
df -h

# 查看某个路径下的文件夹大小(注意不包括文件)
du -h -d 1 | sort -hr
```
