# fzf aliases - bash equivalents of fzf.fish hotkey functions

fzf-fd() {
    # load ll alias directly because bash -c will skip loading of .bashrc
    ll_cmd=$(alias ll 2>/dev/null | sed -E "s/^alias ll='(.*)'/\1/")

    fd --color=always --hidden --follow -E .git -E .env -E .venv -E .cache | \
        fzf --prompt="Directory> " --preview="bash -c 'if [ -d \"\$0\" ]; then ${ll_cmd:-ls} --color=always \"\$0\"; else bat --color=always \"\$0\" 2>/dev/null || cat \"\$0\"; fi' {}";
}

fzf-ps() {
    ps -eo pid,ppid,user,%cpu,%mem,start,command | \
        fzf --prompt="Processes> " --header-lines=1 --preview="ps -o pid,ppid,user,%cpu,rss,start,command -p {1} 2>/dev/null || echo 'Process {1} has exited.'" --preview-window="bottom:4:wrap" --preview-border="top";
}

fzf-history() {
    history | fzf --tac --scheme=history --prompt="History> " --preview-window="bottom:3:wrap" --preview-border="top";
}

fzf-env() {
    env | sort | cut -d= -f1 |      \
        fzf --prompt="Variables> "  \
            --preview='printenv {}' \
            --preview-window="wrap" \
            --multi;
}

fzf-git-log() {
    git log --color=always --format=format:'%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)' --date=short | \
        fzf --scheme=history --prompt="Git Log> " --preview="git show --color=always --stat --patch {1}";
}

fzf-git-status() {
    git -c color.status=always status --short | \
        fzf --prompt="Git Status> " --nth="2.." --preview="git diff --color=always -- {2..}";
}
