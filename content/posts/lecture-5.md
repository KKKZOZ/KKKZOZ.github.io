---
title: "Missing Semester - Lecture 5"
tags:
- Course
categories:
- [Course]
date: 2024-10-17
---

## Job Control

Signals can do other things beyond killing a process. For instance, SIGSTOP pauses a process. In the terminal, typing Ctrl-Z will prompt the shell to send a SIGTSTP signal, short for Terminal Stop.

We can then continue the paused job in the foreground or in the background using `fg` or `bg`.

One more thing to know is that the & suffix in a command will run the command in the background, giving you the prompt back.

```bash
sleep 60 &   
sleep 30 &
wait      
ls

# wait will take 60s
```



## Terminal Multiplexers
tmux has the following hierarchy of objects:

- **Sessions** - a session is an independent workspace with one or more windows
  - `tmux` starts a new session.
  - `tmux new -s NAME` starts it with that name.
  - `tmux ls` lists the current sessions
  - `tmux kill-session` to kill a session
  - Within tmux typing `<C-A> d` detaches the current session
  - `tmux a` attaches the last session. You can use `-t` flag to specify which

- **Windows** - Equivalent to tabs in editors or browsers, they are visually separate parts of the same session

  - `<C-A> c` Creates a new window. To close it you can just terminate the shells doing `<C-d>`

  - `<C-A> N` Go to the *N* th window. 
  - `<C-A> ,` Rename the current window
  - `<C-A> w` List current windows

- **Panes** - Like vim splits, panes let you have multiple shells in the same visual display.

  - `<C-A> "` Split the current pane horizontally
  - `<C-A> %` Split the current pane vertically
  - `<C-A> <direction>` Move to the pane in the specified *direction*. Direction here means arrow keys.
  - `<C-A> [` Start scrollback. You can then press `<space>` to start a selection and `<enter>` to copy that selection.

## Remote Machines

To `ssh` into a server you execute a command as follows

```bash
ssh foobar@192.168.1.42
```

An often overlooked feature of `ssh` is the ability to run commands directly. `ssh foobar@server ls` will execute `ls` in the home folder of foobar.

```bash
# ls run remotely and grep run locally
ssh foobar@server ls | grep PATTERN
# both run on the remote server
ssh foobar@server 'ls | grep PATTERN'
```

## SSH Keys

Key-based authentication using public-key cryptography is a method where a **client** can prove its identity to a **server** without sending the secret (private key) over the network.

How It Works:

1. **Public and Private Keys**: The client generates a pair of cryptographic keys:
   - A **private key** that is kept secret on the client machine.
   - A **public key** that is shared with the server.
2. **Server Setup**: The server stores the client’s **public key** in a file, typically `~/.ssh/authorized_keys`, which allows the server to recognize that client.
3. **Authentication Process**:
   - When the client attempts to connect to the server (e.g., via SSH), the server generates a **challenge** (a random piece of data).
   - The client uses its **private key** to sign the challenge, creating a **digital signature**.
   - The server uses the client’s **public key** (which it already has) to verify that the signature is valid.
   - If the verification succeeds, it proves that the client has the corresponding private key without the client ever sending the private key itself.

`ssh` will look into `.ssh/authorized_keys` to determine which clients it should let in. To copy a public key over you can use:

```bash
cat .ssh/id_ed25519.pub | ssh foobar@remote 'cat >> ~/.ssh/authorized_keys'
# a simple solution
ssh-copy-id -i .ssh/id_ed25519 foobar@remote
```

### SSH Alias Configuration

> How can i change `ssh root@123.123.123.123` to sth like `ssh s2-root` or `ssh root@s2`

```bash
vim ~/.ssh/config
```

Add the following configuration for your server:

```bash
Host s2-root
    HostName 123.123.123.123
    User root	
```



## Copying files over SSH

- [`scp`](https://www.man7.org/linux/man-pages/man1/scp.1.html) when copying large amounts of files/directories, the secure copy `scp` command is more convenient since it can easily recurse over paths. The syntax is `scp path/to/local_file remote_host:path/to/remote_file`

```bash
# Copy a Directory from Local to Remote
scp -r /path/to/local/directory username@remote_host:/path/to/remote/directory/
```

+ [`rsync`](https://www.man7.org/linux/man-pages/man1/rsync.1.html) improves upon `scp` by detecting identical files in local and remote, and preventing copying them again. It also provides more fine grained control over symlinks, permissions

### Port Forwarding

The most common scenario is local port forwarding, where a service in the remote machine listens in a port and you want to link a port in your local machine to forward to the remote port. For example, if we execute `jupyter notebook` in the remote server that listens to the port `8888`. Thus, to forward that to the local port `9999`, we would do `ssh -L 9999:localhost:8888 foobar@remote_server` and then navigate to `localhost:9999` in our local machine.
