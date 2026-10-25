#import "@tola/source:0.0.0": tola-meta
#import "/templates/layout.typ" as layout
#import "/utils/ui.typ": img

#tola-meta((title: "About"))

#layout.page-head("About")

#img("/assets/images/about/avatar.jpg", alt: "Avatar", width: "30%")

- Liu Jinyi
- Studying at UCAS!
- Software Engineering
- How to reach me
  - kkkzoz AT qq DOT com
  - liujinyi24 AT otcaix DOT iscas DOT ac DOT cn

// Folded rather than shown on hover, so it also opens on touch screens.
#html.elem("details", {
  html.elem("summary", [WeChat (click to show)])
  img("/assets/images/about/wechat-qrcode.jpg", alt: "WeChat QR code", width: "200px")
})
