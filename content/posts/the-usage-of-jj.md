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
# This operation will check out to the new change
# You can disable the behavior by add "--no-edit"
jj new <change-id>


# Update the change description or other metadata
jj desc -m "<message>"

# Update current change's description and create a new change on top
jj commit -m "<message>"


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

### Working with GitHub

```shell
# Suppose you are already in the change you want to commit
# And the remote branch name is main
jj bookmark set main

jj git push
```
