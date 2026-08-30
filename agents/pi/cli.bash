# bash completion for pi - AI coding assistant
# Generated for pi 0.80.x

_pi_models() {
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1"/"$2}'
}

_pi_providers() {
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -u
}

_pi() {
    local cur prev words cword
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion || return
    else
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    fi

    local subcommands="install remove uninstall update list config"
    local tools="read bash edit write grep find ls"

    # Detect an active subcommand
    local subcmd="" i
    for ((i=1; i < cword; i++)); do
        case "${words[i]}" in
            install|remove|uninstall|update|list|config)
                subcmd="${words[i]}"; break ;;
        esac
    done

    # Value completion based on the previous option
    case "$prev" in
        --provider)
            COMPREPLY=( $(compgen -W "$(_pi_providers)" -- "$cur") ); return ;;
        --model)
            COMPREPLY=( $(compgen -W "$(_pi_models)" -- "$cur") ); return ;;
        --mode)
            COMPREPLY=( $(compgen -W "text json rpc" -- "$cur") ); return ;;
        --thinking)
            COMPREPLY=( $(compgen -W "off minimal low medium high xhigh" -- "$cur") ); return ;;
        --tools|-t|--exclude-tools|-xt)
            COMPREPLY=( $(compgen -W "$tools" -- "$cur") ); return ;;
        --session-dir)
            COMPREPLY=( $(compgen -d -- "$cur") ); return ;;
        --extension|-e|--skill|--prompt-template|--theme|--session|--fork|--export|--append-system-prompt)
            COMPREPLY=( $(compgen -f -- "$cur") ); return ;;
        --api-key|--system-prompt|--models|--name|-n|--session-id|--list-models)
            return ;;
    esac

    case "$subcmd" in
        install|remove|uninstall)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "-l --local -a --approve -na --no-approve" -- "$cur") )
            else
                COMPREPLY=( $(compgen -f -- "$cur") )
            fi
            return ;;
        update)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--self --extensions --all --extension --force -a --approve -na --no-approve" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "self pi" -- "$cur") )
            fi
            return ;;
        list|config)
            return ;;
    esac

    if [[ "$cur" == -* ]]; then
        local opts="--provider --model --models --api-key --system-prompt \
--append-system-prompt --mode --print -p --continue -c --resume -r \
--session --session-id --fork --session-dir --no-session --name -n \
--no-tools -nt --no-builtin-tools -nbt --tools -t --exclude-tools -xt \
--thinking --extension -e --no-extensions -ne --skill --no-skills -ns \
--prompt-template --no-prompt-templates -np --theme --no-themes \
--no-context-files -nc --export --list-models --help -h --version -v"
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        return
    fi

    # First non-option word: suggest subcommands plus files (@files, prompts)
    COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
    COMPREPLY+=( $(compgen -f -- "$cur") )
}

complete -F _pi pi
