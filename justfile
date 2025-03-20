@default:
    just --list

alias p := publish
alias r := run

@publish:
    git add --all
    git commit -m "update"
    git push

@run:
    hugo server --disableFastRender