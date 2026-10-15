# fish completions for pi - AI coding assistant
# Updated for pi 1.2.0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function __pi_no_subcommand --description 'Check that the first argument is not a pi command'
    set -l cmd (commandline -opc)
    not contains -- "$cmd[2]" install remove uninstall update list config auth mcp
end

function __pi_using_subcommand --description 'Match a pi command at the first argument, before --'
    set -l cmd (commandline -opc)
    contains -- -- $cmd; and return 1
    contains -- "$cmd[2]" $argv
end

function __pi_using_nested_command --description 'Match a command beneath auth or mcp'
    __pi_using_subcommand $argv[1]; or return 1
    set -l cmd (commandline -opc)
    contains -- "$cmd[3]" $argv[2..-1]
end

function __pi_auth_no_command --description 'Check whether auth still needs a command'
    __pi_using_subcommand auth; or return 1
    test (count (commandline -opc)) -eq 2
end

function __pi_models
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1"/"$2}'
end

function __pi_providers
    command pi --list-models 2>/dev/null | tail -n +2 | awk '{print $1}' | sort -u
end

function __pi_tools --description 'Complete comma-separated tools; argument relative enables +name/-name entries'
    set -l token (commandline -ct)
    set -l prefix (string replace -r '[^,]*$' '' -- "$token")
    set -l current (string replace -r '^.*,' '' -- "$token")
    if contains -- relative $argv; and string match -qr '^[-+]' -- "$current"
        set prefix "$prefix"(string sub -l 1 -- "$current")
    end
    for tool in read bash powershell edit write grep find ls codemode tool_search list_mcp_resources list_mcp_resource_templates read_mcp_resource
        printf '%s%s\n' "$prefix" "$tool"
    end
end

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

complete -c pi -f
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a install   -d 'Install extension source and add to settings'
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a remove    -d 'Remove extension source from settings'
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a uninstall -d 'Alias for remove'
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a update    -d 'Update pi, installed packages, or model catalogs'
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a list      -d 'List installed extensions from settings'
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a config    -d 'Open TUI to enable/disable package resources'
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a auth      -d 'Print credentials or check provider readiness'
complete -c pi -n 'test (count (commandline -opc)) -eq 1' -a mcp       -d 'Configure MCP servers and manage OAuth sign-in'

# install / remove / uninstall options
complete -c pi -n '__pi_using_subcommand install remove uninstall' -o l -l local      -d 'Install project-locally (.pi/settings.json)'
complete -c pi -n '__pi_using_subcommand install remove uninstall' -o a -l approve    -d 'Trust project-local files for this command'
complete -c pi -n '__pi_using_subcommand install remove uninstall' -o na -l no-approve -d 'Ignore project-local files for this command'

# update options
complete -c pi -n '__pi_using_subcommand update' -a 'self pi'          -d 'Update pi itself'
complete -c pi -n '__pi_using_subcommand update' -l self               -d 'Update pi only'
complete -c pi -n '__pi_using_subcommand update' -l extensions         -d 'Update installed packages only'
complete -c pi -n '__pi_using_subcommand update' -l models             -d 'Refresh model catalogs only'
complete -c pi -n '__pi_using_subcommand update' -l all                -d 'Update pi and installed packages'
complete -c pi -n '__pi_using_subcommand update' -l extension -r       -d 'Update one package only'
complete -c pi -n '__pi_using_subcommand update' -l force              -d 'Reinstall pi even if latest'
complete -c pi -n '__pi_using_subcommand update' -o a -l approve       -d 'Trust project-local files'
complete -c pi -n '__pi_using_subcommand update' -o na -l no-approve   -d 'Ignore project-local files'

# list / config options
complete -c pi -n '__pi_using_subcommand list config' -o a -l approve     -d 'Trust project-local files for this command'
complete -c pi -n '__pi_using_subcommand list config' -o na -l no-approve -d 'Ignore project-local files for this command'
complete -c pi -n '__pi_using_subcommand config' -o l -l local            -d 'Edit project overrides (.pi/settings.json)'

# auth commands and options
complete -c pi -n __pi_auth_no_command -a print-api-key      -d 'Print a provider API key'
complete -c pi -n __pi_auth_no_command -a print-bearer-token -d 'Print an OAuth bearer token (refreshes if expired)'
complete -c pi -n __pi_auth_no_command -a check              -d 'Check provider credential readiness'
complete -c pi -n '__pi_using_subcommand auth' -l provider -r -a '(__pi_providers)' -d 'Provider name'
complete -c pi -n '__pi_using_subcommand auth' -l model    -r -a '(__pi_models)'    -d 'Model pattern or ID'
complete -c pi -n '__pi_using_nested_command auth print-bearer-token' -l min-expiry -r -d 'Require token valid for at least this duration'
complete -c pi -n '__pi_using_nested_command auth check' -l json        -d 'Emit JSON output'
complete -c pi -n '__pi_using_nested_command auth check' -l credentials -d 'Include the credential in the output'
complete -c pi -n '__pi_using_nested_command auth check' -l no-refresh  -d "Don't refresh expired OAuth credentials"

# MCP commands and options; completion must not connect to servers
complete -c pi -n '__pi_using_subcommand mcp; and test (count (commandline -opc)) -eq 2' -a add    -d 'Add or replace an MCP server'
complete -c pi -n '__pi_using_subcommand mcp; and test (count (commandline -opc)) -eq 2' -a remove -d 'Remove an MCP server'
complete -c pi -n '__pi_using_subcommand mcp; and test (count (commandline -opc)) -eq 2' -a list   -d 'Connect and show server state, tools, and errors'
complete -c pi -n '__pi_using_subcommand mcp; and test (count (commandline -opc)) -eq 2' -a login  -d 'Sign in to an OAuth server'
complete -c pi -n '__pi_using_subcommand mcp; and test (count (commandline -opc)) -eq 2' -a logout -d 'Delete stored OAuth credentials'
complete -c pi -n '__pi_using_nested_command mcp add remove' -o l -l local -d 'Use project .pi/mcp.json'
complete -c pi -n '__pi_using_nested_command mcp add' -l url -x -d 'Streamable HTTP server URL'
complete -c pi -n '__pi_using_nested_command mcp add' -l env -x -d 'Stdio environment variable as KEY=VALUE (repeatable)'
complete -c pi -n '__pi_using_nested_command mcp add' -l cwd -x -a '(__fish_complete_directories)' -d 'Stdio server working directory'
complete -c pi -n '__pi_using_nested_command mcp add' -l header -x -d 'HTTP header as KEY=VALUE (repeatable)'
complete -c pi -n '__pi_using_nested_command mcp add' -l bearer-token-env-var -x -d 'Environment variable holding a bearer token'
complete -c pi -n '__pi_using_nested_command mcp add' -l oauth-client-id -x -d 'Pre-registered OAuth client ID'
complete -c pi -n '__pi_using_nested_command mcp add' -l oauth-client-secret -x -d 'OAuth client secret'
complete -c pi -n '__pi_using_nested_command mcp add' -l oauth-callback-port -x -d 'Fixed OAuth callback port'
complete -c pi -n '__pi_using_nested_command mcp add' -l oauth-client-name -x -d 'OAuth client registration name'
complete -c pi -n '__pi_using_nested_command mcp add' -l exposure -x -a 'codemode deferred direct hidden' -d 'How tools reach the model'
complete -c pi -n '__pi_using_nested_command mcp add' -l description -x -d 'Server description shown in the system prompt'
complete -c pi -n '__pi_using_nested_command mcp list' -l json -d 'Emit JSON output'
complete -c pi -n '__pi_using_nested_command mcp login' -l timeout -x -d 'Sign-in time limit in seconds (default: 300)'

complete -c pi -n '__pi_using_subcommand install remove uninstall update list config auth mcp' -o h -l help -d 'Show command help'

# ---------------------------------------------------------------------------
# Top-level options
# ---------------------------------------------------------------------------

complete -c pi -n __pi_no_subcommand -l provider  -r -a '(__pi_providers)' -d 'Provider name'
complete -c pi -n __pi_no_subcommand -l model     -r -a '(__pi_models)'    -d 'Model pattern or ID'
complete -c pi -n __pi_no_subcommand -l models    -r                       -d 'Comma-separated model patterns for cycling'
complete -c pi -n __pi_no_subcommand -l api-key   -r -d 'API key'
complete -c pi -n __pi_no_subcommand -l system-prompt        -r -F -d 'System prompt text or file'
complete -c pi -n __pi_no_subcommand -l append-system-prompt -r -F -d 'Append text or file to system prompt'
complete -c pi -n __pi_no_subcommand -l mode      -r -a 'text json rpc' -d 'Output mode'

complete -c pi -n __pi_no_subcommand -o p -l print    -d 'Non-interactive mode: process prompt and exit'
complete -c pi -n __pi_no_subcommand -o c -l continue -d 'Continue previous session'
complete -c pi -n __pi_no_subcommand -o r -l resume   -d 'Select a session to resume'
complete -c pi -n __pi_no_subcommand -l session      -r -F -d 'Use specific session file or partial UUID'
complete -c pi -n __pi_no_subcommand -l session-id   -r    -d 'Use exact project session ID'
complete -c pi -n __pi_no_subcommand -l fork         -r -F -d 'Fork specific session into a new session'
complete -c pi -n __pi_no_subcommand -l session-dir  -r -a '(__fish_complete_directories)' -d 'Directory for session storage'
complete -c pi -n __pi_no_subcommand -l no-session         -d "Don't save session (ephemeral)"
complete -c pi -n __pi_no_subcommand -o n -l name    -r    -d 'Set session display name'

complete -c pi -n __pi_no_subcommand -o nt  -l no-tools           -d 'Disable all tools by default'
complete -c pi -n __pi_no_subcommand -o nbt -l no-builtin-tools   -d 'Disable built-in tools but keep custom'
complete -c pi -n __pi_no_subcommand -o t   -l tools         -x -a '(__pi_tools relative)' -d 'Tool allowlist or +name/-name changes to defaults'
complete -c pi -n __pi_no_subcommand -o xt  -l exclude-tools -x -a '(__pi_tools)' -d 'Comma-separated denylist of tools'

complete -c pi -n __pi_no_subcommand -l thinking -r -a 'off minimal low medium high xhigh max' -d 'Set thinking level'
complete -c pi -n __pi_no_subcommand -l tui-mode -r -a 'regular fullscreen' -d 'TUI mode'

complete -c pi -n __pi_no_subcommand -o e -l extension  -r -F -a 'builtin:llama.cpp builtin:codemode builtin:tool-search builtin:mcp' -d 'Load an extension file or built-in extension'
complete -c pi -n __pi_no_subcommand -o ne -l no-extensions   -d 'Disable extension discovery and built-in extensions'
complete -c pi -n __pi_no_subcommand -l no-mcp               -d 'Disable built-in MCP servers and tools'
complete -c pi -n __pi_no_subcommand -l skill           -r -F -d 'Load a skill file or directory'
complete -c pi -n __pi_no_subcommand -o ns -l no-skills       -d 'Disable skills discovery'
complete -c pi -n __pi_no_subcommand -l prompt-template  -r -F -d 'Load a prompt template file or directory'
complete -c pi -n __pi_no_subcommand -o np -l no-prompt-templates -d 'Disable prompt template discovery'
complete -c pi -n __pi_no_subcommand -l theme           -r -F -d 'Load a theme file or directory'
complete -c pi -n __pi_no_subcommand -l use-theme       -r    -d 'Set the initial interactive theme for this run'
complete -c pi -n __pi_no_subcommand -l no-themes             -d 'Disable themes discovery'
complete -c pi -n __pi_no_subcommand -o nc -l no-context-files -d 'Disable AGENTS.md and CLAUDE.md discovery'

complete -c pi -n __pi_no_subcommand -l export      -r -F -d 'Export session file to HTML and exit'
complete -c pi -n __pi_no_subcommand -l list-models -r    -d 'List available models (with optional search)'

complete -c pi -n __pi_no_subcommand -l verbose -d 'Force verbose startup'
complete -c pi -n __pi_no_subcommand -l offline -d 'Disable startup network operations'
complete -c pi -n __pi_no_subcommand -o a -l approve     -d 'Trust project-local files for this run'
complete -c pi -n __pi_no_subcommand -o na -l no-approve -d 'Ignore project-local files for this run'

# Flags registered by the session-manager extension
complete -c pi -n __pi_no_subcommand -l delete -r -d 'Delete a session by exact ID or unique ID prefix'
complete -c pi -n __pi_no_subcommand -l force     -d 'Skip the delete confirmation'
complete -c pi -n __pi_no_subcommand -l purge     -d 'Permanently delete instead of moving to trash'

complete -c pi -n __pi_no_subcommand -o h -l help    -d 'Show help'
complete -c pi -n __pi_no_subcommand -o v -l version -d 'Show version number'
