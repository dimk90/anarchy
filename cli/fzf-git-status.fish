function fzf-git-status --description "Search git status with fzf"
    set -f --export SHELL (command --search fish)
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-status: Not in a git repository.' >&2
        return 1
    end
    set -f preview_cmd '_fzf_preview_changed_file {}'
    if set --query fzf_diff_highlighter
        set preview_cmd "$preview_cmd | $fzf_diff_highlighter"
    end
    git -c color.status=always status --short | \
        fzf --ansi --multi --prompt="Git Status> " \
            --preview=$preview_cmd \
            --nth="2.." \
            $fzf_git_status_opts
end
