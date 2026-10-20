#import "@tola/source:0.0.0": tola-meta
#import "/utils/ui.typ": img

#tola-meta((
  title: "Paper Note: Epoxy: ACID Transactions Across Diverse Data Stores",
  date: "2023-11-22",
  tags: ("Paper Note",),
))

= Summary
一句话总结，就是：#strong[Re-implement the multi-version concurrency control mechanism of Postgres on shim layers.]

因为这篇文章在组会上做了汇报，所以我就直接贴 PPT 了。

= Content
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%873.png", alt: "1")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%874.png", alt: "2")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%875.png", alt: "3")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%876.png", alt: "4")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%877.png", alt: "5")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%878.png", alt: "6")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%879.png", alt: "7")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8710.png", alt: "8")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8711.png", alt: "9")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8712.png", alt: "10")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8713.png", alt: "11")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8714.png", alt: "12")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8715.png", alt: "13")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8716.png", alt: "14")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8717.png", alt: "15")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8718.png", alt: "16")
#img("https://kkkzoz-1304409899.cos.ap-chengdu.myqcloud.com/img/%E5%B9%BB%E7%81%AF%E7%89%8719.png", alt: "17")
