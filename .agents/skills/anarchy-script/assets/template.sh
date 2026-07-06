#!/bin/bash

# Treat unset variables as an error and exit immediately
set -o nounset


## Imports


set -o errexit # exit on non-zero exit code

COMMON=$(curl -fsSL "https://dimk90.github.io/anarchy/common")
# shellcheck source=common
source <(echo "$COMMON")

set +o errexit # disable exit on non-zero exit code


## Routines


# Example helper run via action_run.
# shellcheck disable=SC2329
example_step() {
    # Use config_set_param / remove_line / replace_line / env_set_permanent
    # / alias_set_permanent here. Remember: pattern args are sed regex —
    # escape '.', '|', '(', ')', '$', '?', '+', '*'.
    :
}


main() {

    ## Get gum

    request_gum
    assert $? 'no gum - no fun :('

    ## Init

    printf_section "Starting\n"
    printf_action "Common lib version: ${STYLE_CLR}${COMMON_VERSION}\n"
    start_logger
    printf_action "Log started: ${STYLE_CLR}${LOG_FILE}\n"

    ## Work

    printf_section "Doing the thing\n"

    # Ensure a package is present (no-op if already installed).
    # action_require_package 'some-pkg'

    # Drop a config file from the GitHub Pages URL with backup of any existing one.
    # action_request_permission 'to install /etc/foo.conf'
    # action_install_file '/etc/foo.conf' \
    #                     'https://dimk90.github.io/anarchy/foo/foo.conf' \
    #                     "$(check_sudo)"

    # Run an exported helper inside a spinner.
    # export -f example_step
    # action_run 'Apply example step' 'example_step' 'done'
    # assert $? 'example step failed'

    # Persist an alias / env var across shells.
    # local shells
    # shells=$(alias_set_permanent 'cat' 'bat')
    # action_run 'Set alias cat->bat' '' "${shells}"

    return 0
}


main "$@"
