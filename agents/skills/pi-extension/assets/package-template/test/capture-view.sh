#!/bin/bash
#
# Render a TUI view of the working-copy extension in a detached tmux pane and
# capture the frame to a log file, so views can be diffed across versions.
#
# Usage:
#   test/capture-view.sh [command-index] [session-file]
#
# `pi -e .` registers a second copy of an already installed extension, so pi
# disambiguates the duplicate commands by index in load order: 1 is the working
# copy, 2 the installed package. Pass the index to compare them:
#
#   test/capture-view.sh            # working copy, fresh session
#   test/capture-view.sh 2          # installed package
#   test/capture-view.sh 1 path/to/session.jsonl
#
# A session file is copied to a temp dir before pi opens it: opening a session
# lets pi and extensions append entries, which would mutate the recording.
#

set -euo pipefail


## Constants


# Any of the constants below may be overridden in the environment.

: "${SESSION:={{package}}-capture}"
: "${COLS:=120}"
: "${ROWS:=45}"
: "${OUT_DIR:=test/captures}"
: "${COMMAND:=/{{command}}}"

# Which duplicate command to run: 1 = working copy (`pi -e .`), 2 = installed.
: "${COMMAND_INDEX:=1}"

# Text pi draws in the slash-command completion popup: proof that pi, not the
# shell, received the typed command.
: "${COMPLETION_PATTERN:={{command description substring}}}"

# Text of the rendered view: proof the command ran.
: "${VIEW_PATTERN:={{view title}}}"

: "${STARTUP_TIMEOUT:=60}"
: "${VIEW_TIMEOUT:=90}"

# How long to wait for pi to react to a typed command, and how often to retype
# it. Loading a large session drops keystrokes, so the product is the budget.
: "${INPUT_TIMEOUT:=6}"
: "${INPUT_ATTEMPTS:=10}"

# Temp copy of the session, set by main and removed by the EXIT trap. Global
# because the trap runs after main's locals are gone.
WORK_DIR=


## Session


start_pi() {
    #
    # Start a detached tmux session running pi with the working-copy extension.
    #
    # Parameters:
    #   $1 - session_file - (optional) - .jsonl session to open.
    #
    # Example:
    #   start_pi /tmp/capture/session.jsonl
    #
    local session_file="${1-}"

    local command_line="pi -e ."
    [[ -n $session_file ]] && command_line="$command_line --session $session_file"

    tmux kill-session -t "$SESSION" 2> /dev/null || true # leftover from an aborted run
    tmux new-session -d -s "$SESSION" -x "$COLS" -y "$ROWS" -c "$PWD"
    tmux send-keys -t "$SESSION" "$command_line" Enter
    wait_for_pi "$STARTUP_TIMEOUT"
}


wait_for_pi() {
    #
    # Poll until pi is the foreground process of the pane. Return 1 on timeout.
    #
    # Pane text cannot gate startup: the shell prompt is drawn before pi runs,
    # so a text pattern can match the prompt and return immediately. Readiness
    # for input is established separately, by open_view waiting for the popup.
    #
    # Parameters:
    #   $1 - timeout - (optional) - seconds before giving up (default: 30).
    #
    # Example:
    #   wait_for_pi 60
    #
    local timeout="${1:-30}"

    local deadline=$((SECONDS + timeout))

    until [[ $(tmux display-message -p -t "$SESSION" '#{pane_current_command}') == 'pi' ]]; do
        if ((SECONDS >= deadline)); then
            printf 'timeout waiting for pi to start\n' >&2
            return 1
        fi
        sleep 0.5
    done
}


open_view() {
    #
    # Type the command, pick it from the completion popup, and wait until the
    # view is rendered. Return 1 when pi never accepts the command.
    #
    # Example:
    #   open_view
    #
    local command_line="$COMMAND:$COMMAND_INDEX"

    # Keys sent before pi takes over the terminal are echoed by the shell, so
    # the command can appear on screen while pi never saw it. Only pi draws the
    # completion popup, so gate on the popup and retype until it appears; C-u
    # first so a partially accepted attempt does not leave the line garbled.
    local attempt
    for ((attempt = 0; attempt < INPUT_ATTEMPTS; attempt++)); do
        tmux send-keys -t "$SESSION" C-u
        tmux send-keys -t "$SESSION" "$command_line"
        wait_for "$COMPLETION_PATTERN" "$INPUT_TIMEOUT" 2> /dev/null && break
    done

    if ! tmux capture-pane -p -t "$SESSION" | grep -q "$COMPLETION_PATTERN"; then
        printf 'editor did not accept %s after %s attempts\n' "$command_line" "$INPUT_ATTEMPTS" >&2
        return 1
    fi

    tmux send-keys -t "$SESSION" Enter # accept the completion
    sleep 1
    tmux send-keys -t "$SESSION" Enter # run it
    # Without the explicit return the trailing sleep becomes the exit code, and
    # a timed-out view would be captured as a success.
    wait_for "$VIEW_PATTERN" "$VIEW_TIMEOUT" || return 1
    sleep 1 # let the first frame settle
}


wait_for() {
    #
    # Poll the visible pane until a pattern appears. Return 1 on timeout.
    #
    # Parameters:
    #   $1 - pattern - grep pattern to wait for.
    #   $2 - timeout - (optional) - seconds before giving up (default: 30).
    #
    # Example:
    #   wait_for 'Context Usage' 60
    #
    local pattern="$1"
    local timeout="${2:-30}"

    local deadline=$((SECONDS + timeout))

    until tmux capture-pane -p -t "$SESSION" | grep -q "$pattern"; do
        if ((SECONDS >= deadline)); then
            printf 'timeout waiting for: %s\n' "$pattern" >&2
            return 1
        fi
        sleep 0.5
    done
}


## Internal


_cleanup() {
    #
    # Close the view, kill the tmux session, and drop the session copy; safe
    # when they are already gone.
    #
    tmux send-keys -t "$SESSION" Escape 2> /dev/null || true
    tmux kill-session -t "$SESSION" 2> /dev/null || true
    [[ -n $WORK_DIR ]] && rm -rf -- "$WORK_DIR"
    WORK_DIR=
    return 0
}


trap _cleanup EXIT


main() {
    #
    # Capture one view, optionally against a copy of an existing session.
    #
    # Parameters:
    #   $1 - command_index - (optional) - digits only; duplicate command index.
    #   $2 - session_file - (optional) - .jsonl session to open.
    #
    # A bare number can only be the index: session paths end in .jsonl.
    if [[ ${1-} =~ ^[1-9][0-9]*$ ]]; then
        COMMAND_INDEX="$1"
        shift
    fi

    local session_file="${1-}"
    local opened="$session_file"

    if [[ -n $session_file ]]; then
        WORK_DIR="$(mktemp -d)"
        cp -- "$session_file" "$WORK_DIR/"
        opened="$WORK_DIR/$(basename "$session_file")"
    fi

    # No capture is written when the view never renders, so a stale log from an
    # earlier run can never be mistaken for this one.
    if ! start_pi "$opened" || ! open_view; then
        printf 'FAILED %s\n' "${session_file:-new session}" >&2
        return 1
    fi

    mkdir -p "$OUT_DIR"
    local out_file
    out_file="$OUT_DIR/$(basename "${session_file:-new-session}" .jsonl)-$COMMAND_INDEX.log"
    {
        printf 'command:  %s:%s\n' "$COMMAND" "$COMMAND_INDEX"
        printf 'session:  %s\n' "${session_file:-new session}"
        printf 'captured: %s\n\n' "$(date -Iseconds)"
        tmux capture-pane -p -t "$SESSION"
    } > "$out_file"

    printf 'Wrote %s\n' "$out_file"
}


main "$@"
