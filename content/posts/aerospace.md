---
title: "Aerospace"
tags:
  - Dev
date: 2024-12-24
showtoc: true
weight: 10
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

```shell
h_tiles (root node)
└── v_tiles
    └── window 1
```

it will be immediately transformed into

```shell
v_tiles (new root node)
└── window 1
```

## Shortcuts

### Between Workspaces

- Switch Workspaces

```toml
alt-1 = 'workspace 1'
alt-2 = 'workspace 2'
alt-3 = 'workspace 3'
# ...
alt-b = 'workspace B'
alt-c = 'workspace C'
alt-d = 'workspace D'
```

- Move Node to Workspaces

```toml
alt-shift-1 = 'move-node-to-workspace 1'
alt-shift-2 = 'move-node-to-workspace 2'
alt-shift-3 = 'move-node-to-workspace 3'
# ...
alt-shift-b = 'move-node-to-workspace B'
alt-shift-c = 'move-node-to-workspace C'
alt-shift-d = 'move-node-to-workspace D'
```

### In a Workspace

- Focus Different Node

```toml
alt-h = 'focus left'
alt-j = 'focus down'
alt-k = 'focus up'
alt-l = 'focus right'
```

- Change Node Position

```toml
alt-shift-h = 'move left'
alt-shift-j = 'move down'
alt-shift-k = 'move up'
alt-shift-l = 'move right'
```

- Resize Node

```toml
alt-shift-minus = 'resize smart -50'
alt-shift-equal = 'resize smart +50'
```
