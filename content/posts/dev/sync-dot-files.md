---
title: "Sync Dot Files with Chezmoi"
tags:
    - Dev
date: 2025-10-04
toc: true
weight: 10
---

Keeping dotfiles consistent across multiple machines (macOS, Ubuntu, etc.) is a common challenge. Traditionally, tools like GNU Stow were used to symlink files from a repository into `$HOME`. Today, **[chezmoi](https://www.chezmoi.io/)** provides a more powerful, template-driven approach that integrates seamlessly with Git and makes managing dotfiles across systems straightforward.

This post will walk you through:

* Installing chezmoi
* Setting it up on your first machine
* Committing to a remote repository
* Applying and syncing your configuration on other hosts
* Handling OS-specific configuration differences

---

## 1. Installing chezmoi

On **macOS** (via Homebrew):

```bash
brew install chezmoi
```

On **Ubuntu**:

```bash
sudo apt install chezmoi
# or the installer script
sh -c "$(curl -fsLS get.chezmoi.io)"
```

---

## 2. Initializing chezmoi on Your Primary Machine

Start by letting chezmoi manage your existing dotfiles.

```bash
chezmoi init
```

Add files or directories into chezmoi’s source state:

> You can also use `chezmoi add` to sync changes made to the underlying git repository.

```bash
chezmoi add ~/.zshrc
chezmoi add ~/.config/fish
```

Apply changes to ensure consistency between source and home directory:

> `chezmoi apply` will overwrite files in `$HOME` to match the source state.

```bash
chezmoi apply
```

Check what files are managed:

```bash
chezmoi managed
```

Check for differences:

```bash
chezmoi diff
```

---

## 3. Version Control with Git

chezmoi stores its source state under `~/.local/share/chezmoi`. This directory is just a Git repository.

Initialize and push to GitHub (or any Git host):

```bash
chezmoi cd          # enter the source directory
git init
git branch -M main
git remote add origin git@github.com:yourname/dotfiles.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

From now on, you can use either raw `git` commands inside `chezmoi cd`, or simply prefix with `chezmoi git`:

```bash
chezmoi git status
chezmoi git commit -m "update zshrc"
chezmoi git push
```

---

## 4. Setting Up Another Machine

On a new machine, simply:

```bash
brew install chezmoi        # macOS
# or
sudo apt install chezmoi    # Ubuntu

chezmoi init --apply git@github.com:yourname/dotfiles.git
```

This clones your remote repository and applies all dotfiles into `$HOME`.

When you make changes in the future:

* **On any machine**:

  * Edit a file via `chezmoi edit ~/.zshrc` (or `chezmoi add` if you edited directly).
  * Commit and push with `chezmoi git …`.
* **On other machines**:

  * Pull and apply updates with:

    ```bash
    chezmoi update
    ```

---

## 5. Handling Machine- or OS-Specific Configuration

chezmoi uses Go templates (`*.tmpl`) to allow conditional logic:

```toml
[user]
    name = "Your Name"
    email = "you@example.com"

{{ if eq .chezmoi.os "darwin" }}
[core]
    editor = "nano"
{{ else if eq .chezmoi.os "linux" }}
[core]
    editor = "vim"
{{ end }}
```

You can also use **host-specific** files:

```txt
dot_zshrc.tmpl
host-macbook/
  dot_config/fish/config.fish
host-ubuntu/
  dot_config/fish/config.fish
```

---

## 6. Useful Commands Cheat Sheet

* Add a file/directory:

  ```bash
  chezmoi add ~/.config/nvim
  ```

* Edit (opens source file directly):

  ```bash
  chezmoi edit ~/.zshrc
  ```

* Apply to home directory:

  ```bash
  chezmoi apply
  ```

* Show diffs:

  ```bash
  chezmoi diff
  ```

* Pull and apply from remote:

  ```bash
  chezmoi update
  ```

---

## 7. Summary

With chezmoi, your workflow looks like this:

1. **On your primary machine**

   * Initialize chezmoi
   * Add and commit your dotfiles
   * Push to a remote Git repository

2. **On any new machine**

   * Install chezmoi
   * `chezmoi init --apply <git repo>`
   * Run `chezmoi update` whenever you want to sync

3. **When making changes**

   * Modify dotfiles via `chezmoi edit`
   * Commit and push from one machine
   * Pull updates with `chezmoi update` on others

This setup provides a reproducible, Git-backed way of managing dotfiles across macOS, Ubuntu, and beyond, with built-in support for templates, secrets, and host-specific configs.

---

👉 Do you want me to extend this into a **ready-to-publish markdown article** (with frontmatter and headings), so you can drop it directly into a blog or static site generator like Hugo/Jekyll?
