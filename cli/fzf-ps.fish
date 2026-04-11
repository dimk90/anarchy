function fzf-ps --description "Search processes with fzf"
    set -f ps_cmd (command -v ps || echo "ps")
    set -f ps_preview_fmt (string join ',' 'pid' 'ppid=PARENT' 'user' '%cpu' 'rss=RSS_IN_KB' 'start=START_TIME' 'command')
    $ps_cmd -A -opid,command | \
        fzf --multi --prompt="Processes> " --ansi \
            --header-lines=1 \
            --preview="$ps_cmd -o '$ps_preview_fmt' -p {1} || echo 'Process {1} has exited.'" \
            --preview-window="bottom:4:wrap" \
            --preview-border="top" \
            $fzf_processes_opts
end
