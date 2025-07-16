---
title: "Modern Python"
tags:
  - Dev
date: 2025-07-06
showtoc: true
draft: true
---

> For self references.

## Grammar

### `__init__.py`

Of course. Here is a brief explanation of `__init__.py`.

The `__init__.py` file serves four main purposes in Python:

1. **It marks a directory as a Python package.** The mere presence of this file (even if it's empty) tells Python that the directory is a package, allowing you to import modules from it. This was mandatory in older Python versions and remains a standard convention.

2. **It simplifies imports for users.** You can use `__init__.py` to expose a clean, public API for your package. By importing selected functions or classes from your sub-modules into `__init__.py`, users can import them directly from the package level.
    + **Instead of:** `from my_package.my_module import my_function`
    + **They can use:** `from my_package import my_function`

3. **It runs package initialization code.** The code inside `__init__.py` is executed automatically the first time a package or one of its modules is imported. This is useful for one-time setup tasks, like setting up logging, defining a package version, or connecting to a database.

4. **It controls wildcard imports.** You can define a list named `__all__` in `__init__.py` to specify which names get imported when a user runs `from my_package import *`. This prevents cluttering the user's namespace with internal functions or modules.

## Ecosystems

### uv

Uv is an extremely fast Python package and project manager, written in Rust.

```shell
# init a project
uv init <project-name>

# create a virtual environment
uv venv

# specify python version
uv venv --python 3.11

# add a dependency
uv add <dependency>

# install all dependencies
uv sync

```

Activate the virtual environment:

```shell
# bash
source .venv/bin/activate

# fish
source .venv/vin/activate.fish
```

### ruff

Ruff is an extremely fast Python linter and code formatter, written in Rust.

```shell
# With pip.
pip install ruff

# Lint all files in the current directory (and any subdirectories).
ruff check

# With automatic fix
ruff check --fix

# Format all files in the current directory (and any subdirectories).
ruff format
```
