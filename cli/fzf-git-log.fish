function fzf-git-log --description "Search git log with fzf"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-log: Not in a git repository.' >&2
        return 1
    end
    if not set --query fzf_git_log_format
        set -f fzf_git_log_format '%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'
    end
    set -f preview_cmd 'git show --color=always --stat --patch {1}'
    if set --query fzf_diff_highlighter
        set preview_cmd "$preview_cmd | $fzf_diff_highlighter"
    end
    git log --no-show-signature --color=always --format=format:$fzf_git_log_format --date=short | \
        fzf --ansi --multi --scheme=history --prompt="Git Log> " \
            --preview=$preview_cmd \
            $fzf_git_log_opts
end
