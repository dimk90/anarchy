---
name: shell-code
description: Shell/Bash-specific code style and conventions for writing or editing shell scripts. Use whenever creating, refactoring, or reviewing Bash/shell (.sh, bash, sourced library) code. Adds shell rules on top of the general code-style skill; load that one too — both apply together, and these rules win on any overlap.
---

# Shell Code Style

> **REQUIRED FIRST:** If not already in context, read
> `~/.pi/agent/skills/code-style/SKILL.md` before writing or editing any code.
> These rules layer on top of it.

Bash-specific rules that layer on the general `code-style` skill; it covers
the language-agnostic baseline (thinking before coding, simplicity, surgical
changes, verification, naming and comments). Only the shell additions live
here.

## File Layout

- `#!/bin/bash` shebang; target Bash, not POSIX sh.
- Order: shebang → exported constants → functions grouped under `## Section`
  comment headers → (for sourced libraries) an `export -f` block at file end,
  grouped with `# Section` comments mirroring the function sections.
- Two blank lines between functions and around `## Section` headers; single
  blank line elsewhere.
- 4-space indentation.

## Naming

- Globals and exported variables: `UPPER_SNAKE_CASE`; locals and function
  parameters: `lower_snake_case`.
- Functions: `lower_snake_case`, verb-led (`start_logger`, `backup_file`);
  predicates read as questions (`is_command_available`, `have_privilege`).
- Related functions share a prefix namespace: `printf_*`, `action_*`, `env_*`.
- Internal functions (implementation details of a sourced library, not part
  of its public surface): prefix with a leading underscore (`_send`,
  `_cleanup`) and group under a `## Internal` section. Bash cannot hide
  functions from a sourcing script — the prefix is convention only; note
  that in a comment at the top of the section. Trap handlers and helpers
  called only by other functions belong here.
- Define functions as `name() {` — never the `function` keyword.

## Function Docstrings

Shell has no native doc format; this comment block satisfies code-style's
docstring rule. Place it as the first lines inside the function, framed by
bare `#` lines, with `Parameters:` when args exist and `Example:` showing a
real invocation including error handling:

```bash
backup_file() {
    #
    # Create a backup of the given file by appending .bakN
    # where N is the next available number.
    #
    # Parameters:
    #   $1 - filename - file to backup.
    #   $2 - prefix - (optional) - prefix command (e.g., 'sudo').
    #
    # Example:
    #    backup_name=$(backup_file "$file")
    #    assert $? "backup failed for $file"
    #
    local filename="$1"
    local prefix="${2-}"
    ...
```

## Parameters and Variables

- Bind every positional parameter to a named `local` variable as the first
  statements of the function: `local file="$1"`.
- Optional parameters via default expansion: `local prefix="${3-}"`,
  `local title="${1:-Set password}"`.
- Declare all function variables `local`. When capturing command output whose
  exit code matters, split declaration and assignment
  (`local tmpfile` then `tmpfile="$(mktemp)"`).
- Use braces `${var}` when adjacent to other text; plain `"$var"` otherwise.

## Quoting

- Single quotes for literal strings: `'pacman'`, `'done'`,
  `export GUM_SPIN_SPINNER='minidot'`.
- Double quotes only when expansion is needed.
- Quote all expansions: `"$@"`, `"$file"`, `"$(get_package_manager)"`. Inside
  `[[ ]]`, unquoted `$var` is acceptable (`[[ ! -f $filename ]]`).

## Tests and Control Flow

- `[[ ]]` for file tests, regex/pattern matches, and compound conditions;
  `[ ]` is fine for simple string/number comparisons.
- Short-circuit one-liners for guards: `is_command_available 'gum' && return 0`,
  `[ -n "$reason_text" ] && reason_text=" $reason_text"`.
- `case` for dispatch, with patterns, bodies, and `;;` column-aligned:

```bash
case "$(get_package_manager)" in
    pacman) pacman -Qi "${package}" &>> "$LOG_FILE" ;;
    apt)    dpkg-query -W "${package_apt}" &>> "$LOG_FILE" ;;
    *)      return 1 ;;
esac
```

## Return Values and Errors

- Exit code carries success/failure; stdout carries the return value
  (`echo "$backup_name"`). When stdout carries data, send status/UI messages
  to stderr. Echo an empty string as the "no result" sentinel alongside a
  meaningful exit code.
- Use explicit `return 0` / `return 1`; add a trailing comment when the
  meaning is not obvious: `return 1 # need password`.
- Fail fast with an assert helper checked immediately after the command:

```bash
as_root pacman -Sy gum
assert $? "failed to install gum"
```

## Output, Logging, Input

- `printf` with format strings (`%b` for pre-styled text) — never `echo -e`.
- Redirect command noise to a log file: `cmd &>> "$LOG_FILE"`, where
  `LOG_FILE` defaults to `/dev/null` until logging is started.
- Read interactive input from `/dev/tty` so scripts work when stdin is
  redirected (`curl ... | bash`): `read -r reply </dev/tty`.
- Clean up temp files with an EXIT trap registered right after creation.

## Multi-line Formatting

Break long commands with backslash continuations aligned in a single column,
one argument or flag per line:

```bash
gum spin --align='right'                                             \
         --title "${action_title}$(gum style --faint ' - checking')" \
         -- sleep $UI_INTERACTION_DELAY
```

## ShellCheck

- Keep scripts shellcheck-clean.
- When flagged code is intentional, suppress per-line with
  `# shellcheck disable=SCxxxx` directly above it — never file-wide — and
  keep a nearby comment explaining why the pattern is safe.
