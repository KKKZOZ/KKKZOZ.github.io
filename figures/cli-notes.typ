// Figures for content/posts/tools/cli-notes.typ, drawn with cetz through
// /utils/diagram.typ.

#import "/utils/diagram.typ": diagram, edge, node

/// Which startup files Bash reads for each kind of shell.
#let fig-bash-startup() = diagram(
  col: 140,
  row: 64,
  node("login", (0, 0), [Interactive login], sub: [`ssh user@host` · `su -` · `sudo -i`], width: 190pt),
  node("inter", (0, 1.25), [Interactive non-login], sub: [new terminal tab · `bash`], width: 190pt),
  node("script", (0, 2.5), [Non-interactive], sub: [`bash script.sh`], width: 190pt),
  node("profile", (1.9, 0), [`/etc/profile`, then the first of], sub: [`~/.bash_profile` · `~/.bash_login` · `~/.profile`], tone: "accent"),
  node("bashrc", (1.9, 1.25), [`~/.bashrc`], sub: [alias · functions · `PS1`], tone: "accent"),
  node("env", (1.9, 2.5), [`$BASH_ENV`], sub: [only if set; otherwise nothing], tone: "muted"),
  edge("login", "profile", label: [reads]),
  edge("inter", "bashrc", label: [reads]),
  edge("script", "env", label: [reads]),
  edge("profile", "bashrc", dashed: true, label: [usually sources it]),
)

/// `ssh host cmd` vs `ssh -t host cmd`: plain pipes vs a pseudo-terminal.
#let fig-ssh-pty() = diagram(
  col: 128,
  row: 70,
  node("c0", (0, 0), [`ssh host cmd`], tone: "dark"),
  node("d0", (1, 0), [`sshd`]),
  node("p0", (2.6, 0), [command], sub: [stdin / stdout are pipes \ no `TERM`, no tty], tone: "muted"),
  node("c1", (0, 1.2), [`ssh -t host cmd`], tone: "dark"),
  node("d1", (1, 1.2), [`sshd`]),
  node("pty", (2, 1.2), [PTY], sub: [`/dev/ptmx` ↔ `/dev/pts/N`], tone: "accent"),
  node("p1", (3.2, 1.2), [`sudo` · `vim` · `top`], sub: [sees a terminal \ `TERM=xterm-256color`]),
  edge("c0", "d0"),
  edge("d0", "p0"),
  edge("c1", "d1"),
  edge("d1", "pty"),
  edge("pty", "p1"),
)
