function fzf-env --description "Search environment variables with fzf"
    set -f --export SHELL (command --search fish)
    set -f tmpfile (mktemp)
    set --show >$tmpfile
    set -f all_variable_names (string match --invert history (set --names))
    printf '%s\n' $all_variable_names | \
        fzf --prompt="Variables> " \
            --preview="_fzf_extract_var_info {} $tmpfile" \
            --preview-window="wrap" \
            --multi \
            $fzf_variables_opts
    rm -f $tmpfile
end
