---
name: s-vhs-recording
description: Write, run and verify s-vhs recording scripts (`*.rec.sh`) that record a terminal session and render it as an animated GIF or an asciinema cast. Use when asked to record a terminal demo, produce a demo GIF or animation for a README, script an asciinema cast, automate typing into a terminal for a screencast, or port a VHS `.tape` file. Covers scaffolding, the `Set*` → `Start` → `Show` → `Render` lifecycle, typing and key presses, hiding setup steps, painting typed text with color, and verifying the result without watching the GIF.
compatibility: Requires bash, tmux and asciinema on PATH; agg is additionally required for GIF output. Linux or macOS.
allowed-tools: Read Write Edit Bash(command -v:*) Bash(curl:*) Bash(chmod:*) Bash(asciinema convert:*) Bash(tmux -L s-vhs:*) Bash(ls:*)
---

# S-VHS Recording

[s-vhs](https://github.com/dimk90/s-vhs) drives a detached `tmux` session with
`asciinema` and renders the cast with `agg`. A recording is a plain bash script
that sources `s-vhs.sh` and calls its commands — there is no tape language, so
loops, variables and functions come for free.

**Reference** — every command, setting and default:
<https://github.com/dimk90/s-vhs/blob/main/doc/REFERENCE.md>
(raw: `https://raw.githubusercontent.com/dimk90/s-vhs/main/doc/REFERENCE.md`).
Read it before using any command not shown below; the API is pre-1.0 and moves.

## Setup

```bash
command -v tmux asciinema   # always required
command -v agg              # required only for .gif output
```

Report a missing dependency instead of working around it.

## 1. Scaffold

Never hand-write the header — the scaffolder pins latest library version:

```bash
curl -fsSL https://dimk90.github.io/s-vhs/latest | bash -s -- new demo.rec.sh
```

When `s-vhs.sh` is checked out locally, use `./s-vhs.sh new demo.rec.sh` and
replace the remote import with `source ./s-vhs.sh`.

Name recordings `<topic>.rec.sh` and make them executable.

## 2. Skeleton

```bash
#!/usr/bin/env bash
#
# One sentence on what this recording shows.
#

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1090
source <(curl -fsSL https://dimk90.github.io/s-vhs/v0.2.0) && wait "$!" || exit 1

# Outputs are relative to nothing — anchor them, the script may run from anywhere
SetOutput "$SCRIPT_DIR/demo.gif"

SetCols 60
SetRows 8
SetFontSize 40

Start   # terminal up
Show    # recorder on

Type 'echo "hello"'
Enter
Sleep 2

Render  # recorder off, write every output
```

The `wait "$!"` guard is required with the remote import: without it a failed
or truncated download passes silently.

## 3. Configure

Every `Set*` call goes **before `Start`** and fails afterwards. `Start` needs at
least one `SetOutput`.

- `SetOutput` is repeatable — `.gif` and `.cast` in the same run.
- `SetCols`/`SetRows` size the grid in **cells, not pixels**. Fit them to the
  content: a two-line demo in a 40-row terminal is mostly empty frame.
- `SetFontSize` is the only pixel setting; it scales the render without
  changing the grid the recorded shell sees.
- `SetFontFamily 'A, B'` takes a list and keeps agg's Nerd Font and emoji
  fallbacks. Pass a family that exists on the rendering machine — agg fails
  with `no faces matching font family options` when none of its defaults is
  installed.
- The recorded shell is isolated by default: no personal rc files, no history,
  no user prompt in frame. Keep it that way unless the recording is *about*
  the user's setup (`SetPrompt 'native'`).
- `SetTypingSpeed` / `SetKeyDelay` set the defaults; every `Type` and key
  command still takes a per-call delay.
- `Env NAME value` exports into the recorded shell; repeatable.

## 4. Body

- `Type` types, it never submits — follow it with `Enter`.
- **Quote for the recorded shell.** `Type 'echo $HOME'` in single quotes is
  expanded by the shell in the recording; double quotes expand it in the
  recording script instead, which is almost never what is wanted.
- `Key` takes tmux notation for modified keys (`Key C-u`, `Key M-x`). Plain
  named keys are commands of their own: `Enter`, `Tab`, `Space`, `Backspace`,
  `Escape`, `Up`, `Down`, `Left`, `Right`, `PageUp`, `PageDown`, `Home`, `End`,
  `Insert`, `Delete` — each taking `[count] [delay]`, e.g. `Backspace 18 0.05`.
- **Prefer `Wait` over `Sleep` for anything whose duration is not yours to
  decide.** Anchor the pattern so it does not match the command echoed above
  the output:

  ```bash
  Type 'make build'
  Enter
  Wait '^build succeeded' 60
  ```

- **End with a `Sleep` before `Render`**, or the last frame flashes by.
- Setup belongs off camera. Before `Show`, use `Run 'cmd' 0.5`; mid-recording,
  use `RunOffRecord`, which is `Hide` + `Run` + `Show` in one call. Recording
  resumes at the end of *every* `RunOffRecord`, so chain a command and its
  cleanup on one line rather than in two calls:

  ```bash
  RunOffRecord 'export STAGE=ready; clear' 0.5
  ```

- Repetition is a shell problem, not an s-vhs one:

  ```bash
  run() { Type "$1"; Enter; Sleep "${2:-1}"; }
  for command_line in 'uname -o' 'tput colors'; do run "$command_line"; done
  ```

## 5. Colored text

For a one-off, let the recorded shell do it — the command stays visible:

```bash
Type 'printf "\e[31mred \e[32mgreen\e[0m\n"'
Enter
```

To have text *appear already painted*, with no command on screen, hand the pane
to `cat` and type the escape sequences straight into it (this is how
[`examples/logo.rec.sh`](https://github.com/dimk90/s-vhs/blob/main/examples/logo.rec.sh)
draws the project logo):

```bash
SetPrompt ''        # empty prompt: nothing but the payload reaches the screen
SetTypingSpeed 0    # escape sequences must not be typed at human speed

Start

# No echo and no line buffering, then wipe the line that asked for it
Run 'stty -echo -icanon min 1 time 0; clear'
# cat takes over the pane and echoes raw input, so escapes can be typed directly
Run 'cat'

Show

readonly WHITE=$'\e[38;2;255;255;255m'
readonly RESET=$'\e[0m'

Type "$WHITE"
Type 'painted as it appears' 0.03   # per-call delay for the visible text only
Type "$RESET"
Enter
Sleep 3

Render
```

## 6. Run

```bash
chmod +x demo.rec.sh && ./demo.rec.sh
```

`Start` prints a `tmux -L s-vhs attach -t <session>` line — attach from another
terminal to watch the recording live while it is being driven. The session is
named after the script's PID (`s-vhs-$$`), so parallel runs never collide and
need no `SetSession`; call it only to pin a fixed, predictable attach target.
Any exit, including a mid-recording failure, tears the session down through the
`EXIT` trap installed at `source` time.

## 7. Verify

A GIF cannot be reviewed by an agent — verify through the cast instead. Add a
`.cast` output (keep it if the project wants one, otherwise drop the line after
checking) and dump the session as plain text:

```bash
asciinema convert -f txt demo.cast -
```

Check the expected **command output**, not the typed text: typing is recorded
one character per event, so a typed string spans many events and will not match
a grep, while output arrives in one chunk.

Then confirm each requested file exists and is non-empty — `Render` prints
`::: Wrote <path>` per output.

State plainly that the GIF itself was not viewed; ask the user to eyeball it for
timing and framing.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `Set…: settings cannot change after the session starts` | A setting moved below `Start`; all `Set*` belong to the configuration phase |
| `Start: configure at least one output with SetOutput` | No `SetOutput` call |
| `Start: session already exists` | A pinned `SetSession` name is taken, or a `SIGKILL`ed run left its session behind; `tmux -L s-vhs kill-server` |
| `timeout waiting for: <pattern>` | `Wait` pattern never appeared — check the anchor and raise the timeout |
| `no faces matching font family options` | `SetFontFamily` names no installed family, and agg's defaults are missing too |
| `SetFontFamily: cannot be combined with SetFontFamilyExact` | agg rejects both flags; pick one |
| Variable is empty in the recording | It was expanded by the recording script — use single quotes in `Type` |
| Setup commands are in the GIF | Move them above `Show`, or into `RunOffRecord` |
| Last frame flashes by | No `Sleep` before `Render` |
