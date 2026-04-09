# fzf aliases - bash equivalents of fzf.fish hotkey functions

fzf-fd() {
    fd --color=always --hidden --follow --exclude .git | \
        fzf --ansi --multi --prompt="Directory> " --preview="if [ -d {} ]; then ls -A -F {}; else bat --style=numbers --color=always {} 2>/dev/null || cat {}; fi";
}

fzf-ps() {
    ps -eo pid,ppid,user,%cpu,%mem,start,command | \
        fzf --multi --prompt="Processes> " --header-lines=1 --preview="ps -o pid,ppid,user,%cpu,rss,start,command -p {1} 2>/dev/null || echo 'Process {1} has exited.'" --preview-window="bottom:4:wrap";
}

fzf-history() {
    history | fzf --tac --scheme=history --prompt="History> " --preview-window="bottom:3:wrap";
}

fzf-env() {
    env | sort | cut -d= -f1 | \
        fzf --prompt="Variables> " \
            --preview='printenv {}' \
            --preview-window="wrap" \
            --multi;
}

fzf-git-log() {
    git log --color=always --format=format:'%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)' --date=short | \
        fzf --ansi --multi --scheme=history --prompt="Git Log> " --preview="git show --color=always --stat --patch {1}";
}

fzf-git-status() {
    git -c color.status=always status --short | \
        fzf --ansi --multi --prompt="Git Status> " --nth="2.." --preview="git diff --color=always -- {2..}";
}
