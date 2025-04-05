---
title: "Aerospace"
tags:
  - Dev
  - Tools
date: 2024-12-24
showtoc: true
---

## Concepts

- Each workspace contains its own single root node
- Each non-leaf node is called a "Container"
- Each container can contain arbitrary number of children nodes
- Windows are the only possible leaf nodes. Windows contain zero children nodes
- Every container has two properties:
  1. [Layout](https://nikitabobko.github.io/AeroSpace/guide#layouts) (Possible values: `tiles`, `accordion`)
  2. Orientation (Possible values: `horizontal`, `vertical`)

Some examples:

![image-20241220165926835](/images/image-20241220165926835.png)

![image-20241220170016430](/images/image-20241220170016430.png)

In total, AeroSpace provides 4 possible layouts:

- `h_tiles` horizontal tiles (in i3, it’s called "horizontal split")
- `v_tiles` vertical tiles (in i3, it’s called "vertical split")
- `h_accordion` horizontal accordion (analog of i3’s "tabbed layout")
- `v_accordion` vertical accordion (analog of i3’s "stacked layout")

Accordion is a layout where windows are placed on top of each other.

- **The horizontal accordion** shows left and right paddings to visually indicate the presence of other windows in those directions.

![image-20241220170411145](/images/image-20241220170411145.png)

- **The vertical accordion** shows top and bottom paddings to visually indicate the presence of other windows in those directions.

![image-20241220170424142](/images/image-20241220170424142.png)

## Normalization

By default, AeroSpace does two types of tree normalizations:

1. Containers that have only one child are "flattened". The root container is an exception, it is allowed to have a single window child. Configured by `enable-normalization-flatten-containers`

> Example 1

According to the first normalization, such layout isn’t possible:

```
h_tiles (root node)
└── v_tiles
    └── window 1
```

it will be immediately transformed into

```
v_tiles (new root node)
└── window 1
```
