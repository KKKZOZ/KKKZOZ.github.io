---
title: "Paper Note: Epoxy: ACID Transactions Across Diverse Data Stores"
tags:
- PaperNote
categories:
- [Distributed]
- [Transactions]
date: 2023-11-22
toc: true
---

## Summary

一句话总结，就是：**Re-implement the multi-version concurrency control mechanism of Postgres on shim layers.**

因为这篇文章在组会上做了汇报，所以我就直接贴 PPT 了。

## Content


![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%873.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%874.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%875.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%876.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%877.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%878.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%879.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8710.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8711.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8712.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8713.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8714.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8715.png)

![](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8716.png)

![幻灯片17](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8717.png)

![幻灯片18](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8718.png)

![幻灯片19](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8719.png)