function fzf-history --description "Search command history with fzf"
    set -f --export SHELL (command --search fish)
    if test -z "$fish_private_mode"
        builtin history merge
    end
    if not set --query fzf_history_time_format
        set -f fzf_history_time_format "%m-%d %H:%M:%S"
    end
    set -f time_prefix_regex '^.*? │ '
    builtin history --show-time="$fzf_history_time_format │ " | \
        fzf --scheme=history --prompt="History> " \
            --preview="string replace --regex '$time_prefix_regex' '' -- {} | fish_indent --ansi" \
            --preview-window="bottom:3:wrap" \
            --preview-border="top" \
            $fzf_history_opts | \
        string replace --regex $time_prefix_regex ''
end
