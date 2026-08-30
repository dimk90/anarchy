# fish completions for pi - AI coding assistant
# Generated for pi 0.84.x

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function __pi_no_subcommand
    set -l cmd (commandline -opc)
    for i in $cmd[2..-1]
        switch $i
            case install remove uninstall update list config auth
                return 1
        end
    end
    return 0
end

function __pi_using_subcommand
    set -l cmd (commandline -opc)
    for i in $cmd[2..-1]
        switch $i
            case $argv
                return 0
        end
    end
    return 1
end

function __pi_auth_no_command
    __pi_using_subcommand auth; or return 1
    not __pi_using_subcommand print-api-key print-bearer-token check
end

function __pi_models
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1"/"$2}'
end

function __pi_providers
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -u
end

function __pi_tools
    printf '%s\n' read bash powershell edit write grep find ls
end

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

complete -c pi -f
complete -c pi -n __pi_no_subcommand -a install   -d 'Install extension source and add to settings'
complete -c pi -n __pi_no_subcommand -a remove    -d 'Remove extension source from settings'
complete -c pi -n __pi_no_subcommand -a uninstall -d 'Alias for remove'
complete -c pi -n __pi_no_subcommand -a update    -d 'Update pi and installed packages'
complete -c pi -n __pi_no_subcommand -a list      -d 'List installed extensions from settings'
complete -c pi -n __pi_no_subcommand -a config    -d 'Open TUI to enable/disable package resources'
complete -c pi -n __pi_no_subcommand -a auth      -d 'Print credentials or check provider readiness'

# install / remove / uninstall options
complete -c pi -n '__pi_using_subcommand install remove uninstall' -s l -l local      -d 'Install project-locally (.pi/settings.json)'
complete -c pi -n '__pi_using_subcommand install remove uninstall' -s a -l approve    -d 'Trust project-local files for this command'
complete -c pi -n '__pi_using_subcommand install remove uninstall' -o na -l no-approve -d 'Ignore project-local files for this command'

# update options
complete -c pi -n '__pi_using_subcommand update' -a 'self pi'          -d 'Update pi itself'
complete -c pi -n '__pi_using_subcommand update' -l self               -d 'Update pi only'
complete -c pi -n '__pi_using_subcommand update' -l extensions         -d 'Update installed packages only'
complete -c pi -n '__pi_using_subcommand update' -l models             -d 'Refresh model catalogs only'
complete -c pi -n '__pi_using_subcommand update' -l all                -d 'Update pi and installed packages'
complete -c pi -n '__pi_using_subcommand update' -l extension -r       -d 'Update one package only'
complete -c pi -n '__pi_using_subcommand update' -l force              -d 'Reinstall pi even if latest'
complete -c pi -n '__pi_using_subcommand update' -s a -l approve       -d 'Trust project-local files'
complete -c pi -n '__pi_using_subcommand update' -o na -l no-approve   -d 'Ignore project-local files'

# list / config options
complete -c pi -n '__pi_using_subcommand list config' -s a -l approve     -d 'Trust project-local files for this command'
complete -c pi -n '__pi_using_subcommand list config' -o na -l no-approve -d 'Ignore project-local files for this command'
complete -c pi -n '__pi_using_subcommand config' -s l -l local            -d 'Edit project overrides (.pi/settings.json)'

# auth commands and options
complete -c pi -n __pi_auth_no_command -a print-api-key      -d 'Print a provider API key'
complete -c pi -n __pi_auth_no_command -a print-bearer-token -d 'Print an OAuth bearer token (refreshes if expired)'
complete -c pi -n __pi_auth_no_command -a check              -d 'Check provider credential readiness'
complete -c pi -n '__pi_using_subcommand auth' -l provider -r -a '(__pi_providers)' -d 'Provider name'
complete -c pi -n '__pi_using_subcommand auth' -l model    -r -a '(__pi_models)'    -d 'Model pattern or ID'
complete -c pi -n '__pi_using_subcommand print-bearer-token' -l min-expiry -r -d 'Require token valid for at least this duration'
complete -c pi -n '__pi_using_subcommand check' -l json        -d 'Emit JSON output'
complete -c pi -n '__pi_using_subcommand check' -l credentials -d 'Include the credential in the output'
complete -c pi -n '__pi_using_subcommand check' -l no-refresh  -d "Don't refresh expired OAuth credentials"

# ---------------------------------------------------------------------------
# Top-level options
# ---------------------------------------------------------------------------

complete -c pi -n __pi_no_subcommand -l provider  -r -a '(__pi_providers)' -d 'Provider name'
complete -c pi -n __pi_no_subcommand -l model     -r -a '(__pi_models)'    -d 'Model pattern or ID'
complete -c pi -n __pi_no_subcommand -l models    -r                       -d 'Comma-separated model patterns for cycling'
complete -c pi -n __pi_no_subcommand -l api-key   -r -d 'API key'
complete -c pi -n __pi_no_subcommand -l system-prompt        -r -d 'System prompt'
complete -c pi -n __pi_no_subcommand -l append-system-prompt -r -F -d 'Append text or file to system prompt'
complete -c pi -n __pi_no_subcommand -l mode      -r -a 'text json rpc' -d 'Output mode'

complete -c pi -n __pi_no_subcommand -s p -l print    -d 'Non-interactive mode: process prompt and exit'
complete -c pi -n __pi_no_subcommand -s c -l continue -d 'Continue previous session'
complete -c pi -n __pi_no_subcommand -s r -l resume   -d 'Select a session to resume'
complete -c pi -n __pi_no_subcommand -l session      -r -F -d 'Use specific session file or partial UUID'
complete -c pi -n __pi_no_subcommand -l session-id   -r    -d 'Use exact project session ID'
complete -c pi -n __pi_no_subcommand -l fork         -r -F -d 'Fork specific session into a new session'
complete -c pi -n __pi_no_subcommand -l session-dir  -r -a '(__fish_complete_directories)' -d 'Directory for session storage'
complete -c pi -n __pi_no_subcommand -l no-session         -d "Don't save session (ephemeral)"
complete -c pi -n __pi_no_subcommand -s n -l name    -r    -d 'Set session display name'

complete -c pi -n __pi_no_subcommand -s nt  -l no-tools           -d 'Disable all tools by default'
complete -c pi -n __pi_no_subcommand -s nbt -l no-builtin-tools   -d 'Disable built-in tools but keep custom'
complete -c pi -n __pi_no_subcommand -s t   -l tools         -r -a '(__pi_tools)' -d 'Comma-separated allowlist of tools'
complete -c pi -n __pi_no_subcommand -s xt  -l exclude-tools -r -a '(__pi_tools)' -d 'Comma-separated denylist of tools'

complete -c pi -n __pi_no_subcommand -l thinking -r -a 'off minimal low medium high xhigh max' -d 'Set thinking level'
complete -c pi -n __pi_no_subcommand -l tui-mode -r -a 'regular fullscreen' -d 'TUI mode'

complete -c pi -n __pi_no_subcommand -s e -l extension  -r -F -d 'Load an extension file'
complete -c pi -n __pi_no_subcommand -s ne -l no-extensions   -d 'Disable extension discovery'
complete -c pi -n __pi_no_subcommand -l skill           -r -F -d 'Load a skill file or directory'
complete -c pi -n __pi_no_subcommand -s ns -l no-skills       -d 'Disable skills discovery'
complete -c pi -n __pi_no_subcommand -l prompt-template  -r -F -d 'Load a prompt template file or directory'
complete -c pi -n __pi_no_subcommand -s np -l no-prompt-templates -d 'Disable prompt template discovery'
complete -c pi -n __pi_no_subcommand -l theme           -r -F -d 'Load a theme file or directory'
complete -c pi -n __pi_no_subcommand -l use-theme       -r    -d 'Set the initial interactive theme for this run'
complete -c pi -n __pi_no_subcommand -l no-themes             -d 'Disable themes discovery'
complete -c pi -n __pi_no_subcommand -s nc -l no-context-files -d 'Disable AGENTS.md and CLAUDE.md discovery'

complete -c pi -n __pi_no_subcommand -l export      -r -F -d 'Export session file to HTML and exit'
complete -c pi -n __pi_no_subcommand -l list-models -r    -d 'List available models (with optional search)'

complete -c pi -n __pi_no_subcommand -l verbose -d 'Force verbose startup'
complete -c pi -n __pi_no_subcommand -l offline -d 'Disable startup network operations'
complete -c pi -n __pi_no_subcommand -s a -l approve     -d 'Trust project-local files for this run'
complete -c pi -n __pi_no_subcommand -o na -l no-approve -d 'Ignore project-local files for this run'

# Flags registered by the session-manager extension
complete -c pi -n __pi_no_subcommand -l delete -r -d 'Delete a session by exact ID or unique ID prefix'
complete -c pi -n __pi_no_subcommand -l force     -d 'Skip the delete confirmation'
complete -c pi -n __pi_no_subcommand -l purge     -d 'Permanently delete instead of moving to trash'

complete -c pi -n __pi_no_subcommand -s h -l help    -d 'Show help'
complete -c pi -n __pi_no_subcommand -s v -l version -d 'Show version number'
