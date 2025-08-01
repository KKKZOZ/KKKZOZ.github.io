---
title: "Missing Semester - Lecture 1"
tags:
  - Course
  - The Missing Semester
date: 2024-10-09
toc: true
weight: 10
---

## The shell

How does the shell know how to find the `date` or `echo` programs?

The shell is a programming environment, just like Python, and so it has variables,
conditionals, loops, and functions.

If the shell is asked to execute a command that doesn’t match one of its programming keywords,
it consults an _environment variable_ called `$PATH` that lists which directories
the shell should search for programs when it is given a command

## Permissions

Permissions for directories:

- **Read:** Allows the user to list the contents of the directory.
- **Write:** Allows the user to add, remove, or rename files and subdirectories within the directory.
- **Execute:** Allows the user to enter (cd) the directory and access files and subdirectories within, even if they cannot list the directory's contents.

Modifying Permissions:

```bash
chmod [who][operator][permissions] filename
```

- `who`: u (user/owner), g (group), o (others), a (all)
- `operator`: + (add), - (remove), = (set exactly)
- `permissions`: r, w, x

Example:

Add execute permission for the owner:

```bash
chmod u+x script.sh
```

Remove write permission for others:

```bash
chmod o-w report.txt
```

## Connecting Programs

In the shell, programs have two primary “streams” associated with them: their input stream and their output stream.

The simplest form of redirection is < file and > file. These let you rewire the input and output streams of a program to a file respectively:

```bash
echo hello > hello.txt

cat < hello.txt > hello2.txt
```

> When cat is not given any arguments, it prints contents from its input stream to its output stream (like in the second example above).
> You can also use `>>` to append to a file.

The `|` operator lets you “chain” programs such that the output of one is the input of another:

```bash
ls -l / | tail -n1

curl --head --silent google.com | grep --ignore-case content-length | cut --delimiter=' ' -f2
```

## Exercises

### 5

- Double-quoted strings can expand:
  - Variable Expansion: Integrating dynamic values into strings.
  - Command Substitution: Embedding the output of commands within strings.
  - Escape Sequences: Including special characters like newlines and tabs.
- Single-quoted strings are just literal strings.

Summary:

- Single-quoted string: When you need a literal string without any expansions.
- Double-quoted string: When you need to include variables or commands within a string.

### 6,7

When a script file is given `Execute` permission, then it can be invoked by `./script`.

`sh script` does not need the `Execute` permission, it needs `Read` permission.
