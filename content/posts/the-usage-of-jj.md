---
title: "The Usage of jj"
tags:
  - Dev
date: 2025-04-04
showtoc: true
---


## Basic Operations

```shell
# Create a change whose ancestor is <chang-id>
jj new <change-id>


# "Check out" the change
jj edit <change-id>

```

## Workflows

### The Squash Workflow

> Using as you have an "git index".

The workflow goes like this:

- We describe the work we want to do.
- We create a new empty change on top of that one.
- As we produce work we want to put into our change, we use `jj squash` to move changes from @ into the change where we described what to do.

```shell
jj desc -m "the goal we want to achieve"
jj new

# Editing your code, then
jj squash

# All your changes are stored in the "goal" commit
```

### The Edit Workflow
