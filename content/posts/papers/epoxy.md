---
title: "Paper Note: Epoxy: ACID Transactions Across Diverse Data Stores"
tags:
- Paper Note
date: 2023-11-22
toc: true
---

## Summary

一句话总结，就是：**Re-implement the multi-version concurrency control mechanism of Postgres on shim layers.**

因为这篇文章在组会上做了汇报，所以我就直接贴 PPT 了。

## Content

![1](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%873.png)

![2](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%874.png)

![3](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%875.png)

![4](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%876.png)

![5](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%877.png)

![6](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%878.png)

![7](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%879.png)

![8](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8710.png)

![9](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8711.png)

![10](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8712.png)

![11](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8713.png)

![12](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8714.png)

![13](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8715.png)

![14](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8716.png)

![15](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8717.png)

![16](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8718.png)

![17](https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8719.png)
