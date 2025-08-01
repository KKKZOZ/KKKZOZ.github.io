@default:
    just --list

alias p := publish
alias r := run
alias b := build-index
alias l := lint

@publish:
    just lint
    jj st
    jj desc -m "$(date +'%Y-%m-%d') Update"
    jj bookmark set hugo -r @
    jj git push
    # git add --all
    # git commit -m "$(date +%Y-%m-%d) update"
    # git push

@build-index:
    python3 build-paper-index.py "$(fd -t d . './content/posts' | fzf)"

@run:
    hugo server --disableFastRender

@lint:
    markdownlint-cli2 --fix "**/*.md" "#themes"