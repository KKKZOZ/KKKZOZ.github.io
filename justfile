@default:
    just --list

alias p := publish
alias r := run

@publish:
    jj st
    jj desc -m "$(date +'%Y-%m-%d') Update"
    jj bookmark set hugo -r @
    jj git push
    # git add --all
    # git commit -m "$(date +%Y-%m-%d) update"
    # git push

@run:
    hugo server --disableFastRender