// Figures for content/posts/tools/macos-setup.typ, drawn with cetz through
// /utils/diagram.typ.

#import "/utils/diagram.typ": diagram, edge, node

/// What each Homebrew mirror variable serves during update and install.
#let fig-brew-mirrors() = diagram(
  col: 150,
  row: 70,
  node("install", (0, 0), [`brew install wget`], tone: "dark"),
  node("formula", (0, 1), [Fetch the Formula], sub: [`HOMEBREW_API_DOMAIN`]),
  node("bottle", (-.75, 2.25), [Download the bottle], sub: [`HOMEBREW_BOTTLE_DOMAIN` \ prebuilt binary], tone: "accent"),
  node("build", (.75, 2.25), [Build from source], sub: [steps in the Formula], tone: "muted"),
  node("update", (1.75, 0), [`brew update`], tone: "dark"),
  node("self", (1.75, 1), [Update Homebrew itself], sub: [`HOMEBREW_BREW_GIT_REMOTE`]),
  edge("install", "formula"),
  edge("formula", "bottle", route: "ortho", label: [bottle exists], label-side: "above"),
  edge("formula", "build", route: "ortho", label: [no bottle], label-side: "above"),
  edge("update", "self"),
)
