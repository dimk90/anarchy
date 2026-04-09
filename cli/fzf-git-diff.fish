function fzf-git-diff --description "Search git diff files with fzf"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo 'fzf-git-diff: Not in a git repository.' >&2
        return 1
    end
    set -f preview_cmd 'git diff --color=always -- {}'
    if set --query fzf_diff_highlighter
        set preview_cmd "$preview_cmd | $fzf_diff_highlighter"
    end
    git diff --name-only | \
        fzf --ansi --multi --prompt="Git Diff> " \
            --preview=$preview_cmd
end
