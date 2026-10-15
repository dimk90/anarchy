# bash completion for pi - AI coding assistant
# Updated for pi 1.2.0

_pi_models() {
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1"/"$2}'
}

_pi_providers() {
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -u
}

_pi_mcp() {
    #
    # Complete MCP commands without connecting to configured servers.
    #
    # Parameters:
    #   $1 - cur - current word.
    #   $2 - prev - previous word.
    #   $3 - mcp_cmd - completed MCP command, or an empty string.
    #
    # Example:
    #   _pi_mcp '--' 'list' 'list'
    #
    local cur="$1" prev="$2" mcp_cmd="$3"
    local opts="-h --help"

    case "$prev" in
        --exposure)
            mapfile -t COMPREPLY < <(compgen -W "codemode deferred direct hidden" -- "$cur"); return ;;
        --cwd)
            mapfile -t COMPREPLY < <(compgen -d -- "$cur"); return ;;
        --url|--env|--header|--bearer-token-env-var|--oauth-client-id|--oauth-client-secret|--oauth-callback-port|--oauth-client-name|--description|--timeout)
            return ;;
    esac

    if [[ "$cur" == -* ]]; then
        case "$mcp_cmd" in
            add)
                opts+=" -l --local --url --env --cwd --header --bearer-token-env-var
--oauth-client-id --oauth-client-secret --oauth-callback-port --oauth-client-name
--exposure --description" ;;
            remove) opts+=" -l --local" ;;
            list)   opts+=" --json" ;;
            login)  opts+=" --timeout" ;;
        esac
        mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
    elif [[ -z "$mcp_cmd" ]]; then
        mapfile -t COMPREPLY < <(compgen -W "add remove list login logout" -- "$cur")
    fi
}

_pi() {
    local cur prev words cword
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -n : || return
    else
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    fi

    local subcommands="install remove uninstall update list config auth mcp"
    local tools="read bash powershell edit write grep find ls codemode tool_search
list_mcp_resources list_mcp_resource_templates read_mcp_resource"

    # Pi dispatches subcommands only at the first argument
    local subcmd="" nested_cmd="" i
    if ((cword > 1)); then
        case "${words[1]}" in
            install|remove|uninstall|update|list|config|auth|mcp)
                subcmd="${words[1]}" ;;
        esac
    fi
    ((cword > 2)) && nested_cmd="${words[2]}"
    for ((i=1; i < cword; i++)); do
        if [[ "${words[i]}" == -- ]]; then
            mapfile -t COMPREPLY < <(compgen -f -- "$cur")
            return
        fi
    done
    if [[ "$subcmd" == mcp ]]; then
        _pi_mcp "$cur" "$prev" "$nested_cmd"
        return
    fi

    # Value completion based on the previous option
    case "$prev" in
        --provider)
            mapfile -t COMPREPLY < <(compgen -W "$(_pi_providers)" -- "$cur"); return ;;
        --model)
            mapfile -t COMPREPLY < <(compgen -W "$(_pi_models)" -- "$cur"); return ;;
        --mode)
            mapfile -t COMPREPLY < <(compgen -W "text json rpc" -- "$cur"); return ;;
        --thinking)
            mapfile -t COMPREPLY < <(compgen -W "off minimal low medium high xhigh max" -- "$cur"); return ;;
        --tui-mode)
            mapfile -t COMPREPLY < <(compgen -W "regular fullscreen" -- "$cur"); return ;;
        --tools|-t|--exclude-tools|-xt)
            local prefix="${cur%,*}"
            [[ "$cur" == *,* ]] && prefix+="," || prefix=""
            local tool_cur="${cur##*,}"
            if [[ "$prev" == --tools || "$prev" == -t ]] && [[ "$tool_cur" == [+-]* ]]; then
                prefix+="${tool_cur:0:1}"
                tool_cur="${tool_cur:1}"
            fi
            mapfile -t COMPREPLY < <(compgen -P "$prefix" -W "$tools" -- "$tool_cur"); return ;;
        --session-dir)
            mapfile -t COMPREPLY < <(compgen -d -- "$cur"); return ;;
        --extension|-e)
            if [[ -z "$subcmd" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "builtin:llama.cpp builtin:codemode builtin:tool-search builtin:mcp" -- "$cur")
            fi
            mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <(compgen -f -- "$cur")
            if declare -F __ltrim_colon_completions >/dev/null 2>&1; then
                __ltrim_colon_completions "$cur"
            fi
            return ;;
        --skill|--prompt-template|--theme|--session|--fork|--export|--system-prompt|--append-system-prompt)
            mapfile -t COMPREPLY < <(compgen -f -- "$cur"); return ;;
        --api-key|--models|--name|-n|--session-id|--list-models)
            return ;;
        --use-theme|--min-expiry|--delete)
            return ;;
    esac

    case "$subcmd" in
        install|remove|uninstall)
            if [[ "$cur" == -* ]]; then
                mapfile -t COMPREPLY < <(compgen -W "-l --local -a --approve -na --no-approve -h --help" -- "$cur")
            else
                mapfile -t COMPREPLY < <(compgen -f -- "$cur")
            fi
            return ;;
        update)
            if [[ "$cur" == -* ]]; then
                mapfile -t COMPREPLY < <(compgen -W "--self --extensions --models --all --extension --force -a --approve -na --no-approve -h --help" -- "$cur")
            else
                mapfile -t COMPREPLY < <(compgen -W "self pi" -- "$cur")
            fi
            return ;;
        list)
            [[ "$cur" == -* ]] && mapfile -t COMPREPLY < <(compgen -W "-a --approve -na --no-approve -h --help" -- "$cur")
            return ;;
        config)
            [[ "$cur" == -* ]] && mapfile -t COMPREPLY < <(compgen -W "-l --local -a --approve -na --no-approve -h --help" -- "$cur")
            return ;;
        auth)
            if [[ "$cur" == -* ]]; then
                local auth_opts="--provider --model -h --help"
                case "$nested_cmd" in
                    print-bearer-token) auth_opts+=" --min-expiry" ;;
                    check)              auth_opts+=" --json --credentials --no-refresh" ;;
                esac
                mapfile -t COMPREPLY < <(compgen -W "$auth_opts" -- "$cur")
            elif [[ -z "$nested_cmd" ]]; then
                mapfile -t COMPREPLY < <(compgen -W "print-api-key print-bearer-token check" -- "$cur")
            fi
            return ;;
    esac

    if [[ "$cur" == -* ]]; then
        # --delete/--force/--purge come from the session-manager extension
        local opts="--provider --model --models --api-key --system-prompt \
--append-system-prompt --mode --print -p --continue -c --resume -r \
--session --session-id --fork --session-dir --no-session --name -n \
--no-tools -nt --no-builtin-tools -nbt --tools -t --exclude-tools -xt \
--thinking --extension -e --no-extensions -ne --no-mcp --skill --no-skills -ns \
--prompt-template --no-prompt-templates -np --theme --use-theme --no-themes \
--no-context-files -nc --export --list-models --verbose --tui-mode \
--approve -a --no-approve -na --offline \
--delete --force --purge --help -h --version -v"
        mapfile -t COMPREPLY < <(compgen -W "$opts" -- "$cur")
        return
    fi

    # Subcommands are valid only at the first argument
    if ((cword == 1)); then
        mapfile -t COMPREPLY < <(compgen -W "$subcommands" -- "$cur")
    fi
    mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <(compgen -f -- "$cur")
}

complete -F _pi pi
