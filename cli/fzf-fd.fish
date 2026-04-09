function fzf-fd --description "Search files with fd and fzf"
    set -f --export SHELL (command --search fish)
    set -f fd_cmd (command -v fdfind || command -v fd || echo "fd")
    $fd_cmd --color=always --hidden --follow --exclude .git $fzf_fd_opts 2>/dev/null | \
        fzf --ansi --multi --prompt="Directory> " \
            --preview="_fzf_preview_file {}" \
            $fzf_directory_opts
end
