# `common` Helper Reference

All helpers are sourced from the `common` file at the repo root. The local file is the source of truth — verify signatures against the `common` file at the repo root if anything below seems off (the published GitHub Pages copy can lag).

## Table of contents

- [Logger](#logger)
- [Common](#common)
- [Print](#print)
- [Input](#input)
- [Root & Privilege](#root--privilege)
- [Package management](#package-management)
- [Files](#files)
- [Persistent env / aliases](#persistent-env--aliases)
- [Action helpers (gum-based)](#action-helpers-gum-based)
- [Style globals](#style-globals)

---

## Logger

`LOG_FILE` is the global path that helpers append to (`&>> "$LOG_FILE"`). Defaults to `/dev/null` until `start_logger` is called.

| Helper | Effect |
|---|---|
| `start_logger` | If `LOG_FILE=/dev/null`, mktemp a real `.log` file and assign it. Idempotent. |
| `get_logger` | Echo current `LOG_FILE` value. |
| `reset_logger` | Set `LOG_FILE=/dev/null`. Rare — really only for tests. |

`main` always calls `start_logger` right after the "Starting" section so anything captured by `&>> "$LOG_FILE"` later in the script lands in a real file.

## Common

| Helper | Signature | Returns |
|---|---|---|
| `is_command_available` | `name` | 0 if `command -v name` finds it |
| `assert` | `exit_code [message]` | exits 1 with styled `[ERROR]` if `exit_code != 0`. Message defaults to `¯\_(ツ)_/¯`. |
| `regex_sanitize` | `regex_str` | echoes the literal string (strips metacharacters and unescapes). Inverse of the regex-quoting that `config_set_param`/etc. expect. |

## Print

All printers emit a leading bullet + faint title. Mirror this structure — don't fall back to raw `echo`.

| Helper | Bullet | Use for |
|---|---|---|
| `printf_section "Title\n" [args...]` | `:: ` (bold) | Section heading |
| `printf_action "Title\n" [args...]` | `   -> ` (green) | Static info / non-spinner action line |
| `printf_warning "msg\n"` | `[WARNING]` (yellow) | Recoverable issue |
| `printf_error "msg\n"` | `[ERROR]` (red) | Fatal — usually right before exit |
| `printf_info "msg\n"` | `[INFO]` (blue) | Bookkeeping note |
| `prefix_printf "$prefix" "title" [args...]` | custom | Used internally; handy for building gum `--header` strings |
| `bullet_section` / `bullet_action` / `bullet_warning` / `bullet_error` / `bullet_info` | — | Echo just the bullet, for embedding in a manual `printf` |

`%b` works in titles for embedded escape sequences. Trailing `\n` is your responsibility.

## Input

| Helper | Behavior |
|---|---|
| `ask_yn` | Prints `(y/n): `, reads from `/dev/tty` (so it survives `\| bash`). 0 if `[Yy]`, 1 otherwise. |

## Root & Privilege

| Helper | Behavior |
|---|---|
| `as_root cmd args...` | Runs `cmd` directly if EUID=0, else `sudo cmd`. Returns the command's exit code. |
| `check_sudo` | Echoes `'sudo'` if EUID≠0, empty string otherwise. Pass as the prefix arg to file/config helpers. |
| `have_privilege` | 0 if root or sudo cached (no password needed), 1 otherwise. |

**Rule:** before any `as_root` / sudo-using action, call `action_request_permission 'to do X'`. This puts the password prompt inside a styled UI before the spinner runs. If a flow doesn't actually need root, drop `as_root` rather than wrap it defensively.

## Package management

| Helper | Behavior |
|---|---|
| `get_package_manager` | Echoes `pacman` / `apt` / `unknown`. |
| `is_package_installed pkg [pkg_apt]` | 0 if installed under whichever PM is detected. |
| `request_gum` | If gum missing, prompt "Let's get some?" and `pacman -Sy gum` / `apt-get install -y gum`. Always at the top of `main`. |

## Files

| Helper | Signature | Notes |
|---|---|---|
| `backup_file` | `path [prefix]` | Creates `path.bakN` (next free N). Echoes the new name to stdout (empty if path didn't exist). Returns 0 on success / no-op, 1 on cp failure. |
| `remove_line` | `file pattern [prefix] [case_mode]` | Deletes lines matching sed regex `pattern`. `case_mode='i'` for case-insensitive. 0 if file missing or no matches (idempotent). |
| `replace_line` | `file pattern replacement [prefix]` | sed `s\|pattern\|replacement\|`. |
| `config_set_param` | `file pattern [section] [prefix]` | Add `pattern` to `file` in `[section]` (e.g. `'options'`, `'Unit'`); creates the section if absent. Without `section`, appends to file. Idempotent — won't duplicate. |

**Critical:** all `pattern` args are **sed regex** with `\|` as the delimiter. Escape these in literal-looking input:

| Char | Escape |
|---|---|
| `.` | `\.` |
| `|` | `\|` |
| `(` `)` | `\(` `\)` |
| `$` | `\$` |
| `?` `+` `*` | `\?` `\+` `\*` |

Examples:

```bash
remove_line ~/.config/fish/config.fish 'starship init fish \| source'
config_set_param ~/.bashrc 'eval "\$\(zoxide init --cmd j bash\)"'
config_set_param '/etc/pacman.conf' '^Color$' 'options' "$(check_sudo)"
config_set_param '/usr/lib/systemd/system/reflector.service' \
                 '\s*ConditionACPower\s*=\s*true' 'Unit' "$(check_sudo)"
```

## Persistent env / aliases

| Helper | Signature | Returns / Echoes |
|---|---|---|
| `env_set_permanent` | `VAR value` | echoes `fish,bash` / `bash` / `''`. Returns 0 if at least one shell wrote successfully. |
| `env_unset_permanent` | `VAR` | same return convention; echoes shells that had something to remove. |
| `alias_set_permanent` | `name command` | same convention. fish via `alias --save`, bash via `~/.bashrc` rewrite. |

The standard idiom captures the shell list and feeds it as the success_status of `action_run`:

```bash
local shells
shells=$(alias_set_permanent 'cat' 'bat')
action_run 'Set alias cat->bat' '' "${shells}"
```

Empty `command` arg = "just print the title with a brief spin" — no work, just UI.

## Action helpers (gum-based)

### `action_require_package`

```
action_require_package package [title_prefix] [package_apt]
```

- Spins "checking", short-circuits with `exists` if installed.
- Otherwise: spins "privilege" → asks for password if needed → spins "installing" → prints `installed`.
- On failure, exits via `assert` (don't wrap with your own `assert $?`).
- For `fd` ↔ `fd-find` style cross-distro names: `action_require_package 'fd' '' 'fd-find'`.

### `action_install_file`

```
action_install_file dest_path source_url [prefix]
```

- mktemp + `curl -fsSL` → backup existing dest (auto, with `.bakN`) → move into place.
- `prefix='sudo'` triggers `action_request_permission` for backup and install steps.
- Use `"$(check_sudo)"` for the prefix when destination is system-owned.

### `action_run`

```
action_run title [command] [success_status] [fail_status]
```

- `command` empty → spins for `UI_INTERACTION_DELAY` then prints title (use for "report" lines, and as the UI-only follow-up when the real work had to run *outside* the spinner — see SKILL.md "Secrets must not enter the spinner").
- `command` set → runs `bash -c "$command &>> $LOG_FILE"` inside spinner. Returns command's exit code.
- `success_status` — green text after `-` separator. Often `'done'`, `'enabled'`, `'installed'`.
- `fail_status` — red text on non-zero exit. Defaults to `'failed'`. Use richer text for diagnosis (`'package missing'`, `'unit not found'`).
- Multi-step `command`: define a function, `export -f`, pass the function name as `command`. Don't build `cmd1 && cmd2` strings.
- **Never embed secrets** (passphrases, passwords, tokens) in the `command` string — they leak via `/proc/<pid>/cmdline` of the spawned `bash -c`, and a stray `'` in the secret breaks quoting and lets the shell execute injected code. Pipe the secret in via the bash `printf` builtin outside `action_run`, then use empty-`command` `action_run` for the UI step. Use `assert $?` directly when nothing intervenes; only capture `local rc=$?` when an intervening statement (e.g. `unset secret`) would otherwise clobber `$?` to 0 — habitual capture everywhere is noise.

### `action_request_permission`

```
action_request_permission [reason_text]
```

Returns 0 immediately if `have_privilege`. Otherwise: gum input password, `sudo -Si true` to validate. `assert`-exits on failure. Always call this *before* the action it gates so the password prompt has a fresh styled UI.

### `action_set_password`

```
action_set_password [title]
```

Two gum password prompts. On match, echoes the password to stdout, returns 0. On mismatch / cancel, returns 1. UI lines go to stderr so `password=$(action_set_password ...)` captures only the password.

## Style globals

`STYLE_*` are escape-sequence strings. Use inside `printf` titles to color a span — but remember `STYLE_CLR` resets *everything*, so wrap any prose after a highlight in faint again or you'll get a mismatched-style line.

| Global | Effect |
|---|---|
| `STYLE_CLR` (alias `STYLE_CLEAR`) | Reset all styles |
| `STYLE_BOLD` `STYLE_DIM` `STYLE_ITALIC` `STYLE_UNDERLINE` | Text styles |
| `FG_RED` `FG_GREEN` `FG_YELLOW` `FG_BLUE` `FG_MAGENTA` `FG_CYAN` `FG_WHITE` `FG_BLACK` | Bright FG colors |
| `FG_ACCENT` | Defaults to `FG_GREEN` |
| `BG_*` | Background variants |
| `GUM_CYAN/BLUE/YELLOW/RED/GREEN/MAGENTA/WHITE` | 256-color codes for `gum style --foreground` |
| `GUM_ACCENT` | Defaults to `GUM_GREEN` |
| `UI_INTERACTION_DELAY` | Minimum spin time (0.6s) so transient statuses are visible |
| `COMMON_VERSION` | Printed in the "Starting" section |
