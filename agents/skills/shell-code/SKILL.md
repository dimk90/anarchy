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
- Order applicable elements as: shebang → file header and shell setup → public
  constants and private module state → functions grouped under `## Section`
  comment headers → source-time initialization such as traps.
- Sourcing already defines variables and functions in the caller's shell. Do
  not export them unless child processes need them; when function export is
  required, put the `export -f` block at file end and mirror the function
  sections with `# Section` comments.
- Two blank lines between functions and around `## Section` headers; single
  blank line elsewhere.
- 4-space indentation.

## Naming

- Public globals and exported variables: `UPPER_SNAKE_CASE`; locals and
  function parameters: `lower_snake_case`.
- Functions: `lower_snake_case`, verb-led (`start_logger`, `backup_file`);
  predicates read as questions (`is_command_available`, `have_privilege`).
  Preserve an established public API's casing, such as VHS-style `SetRows`.
- Related functions share a prefix namespace: `printf_*`, `action_*`, `env_*`.
- Private functions and private module variables use a project-specific prefix,
  not only a leading underscore. For example, s-vhs uses `_svhs_` for functions
  (`_svhs_send`) and `_SVHS_` for module state (`_SVHS_ROWS`). Local variables
  do not need this prefix.
- Group private functions under a `## Internal` section. Bash cannot hide them
  from a sourcing script — the prefix only marks the private boundary and
  avoids collisions; note that in a comment at the top of the section. Trap
  handlers and helpers called only by other functions belong here.
- Define functions as `name() {` — never the `function` keyword.

## Function Docstrings

Shell has no native doc format; this comment block satisfies code-style's
docstring rule. Place it as the first lines inside every function, framed by
bare `#` lines. Always include `Parameters:` (`None.` when there are no
arguments) and a real `Example:`; include error handling where it is material
to the contract:

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
    #   backup_name=$(backup_file "$file") || exit 1
    #
    local filename="$1"
    local prefix="${2-}"
    ...
```

Omit the block when the function name alone states the whole contract: no
parameters, no failure mode, and a one-line body with no side effect. A
docstring there only restates the signature, which code-style forbids:

```bash
svhs_version() {
    printf '%s\n' '0.1.0'
}
```

Anything taking an argument, returning a nonzero status, or touching state
outside the function keeps the full block.

## Comments

- No period at the end of short one- or two-line comments, inline or on their
  own line:

```bash
# truncate the cast after detaching, tmux writes a final resize event
sleep 1 # give the recorder time to attach
```

- Periods stay in prose that reads as sentences: function docstrings, file
  headers, section preambles, and any multi-sentence comment.

## Parameters and Variables

- Bind every positional parameter to a named `local` variable as the first
  statements of the function: `local file="$1"`. Use `${1-}` when a missing
  argument must survive `set -u` for explicit validation. A thin pass-through
  wrapper may instead document and forward `"$@"` directly.
- Optional parameters via default expansion: `local prefix="${2-}"`,
  `local title="${1:-Set password}"`.
- Declare all function variables `local`. When capturing command output whose
  exit code matters, split declaration and assignment
  (`local tmpfile` then `tmpfile="$(mktemp)"`).
- Use braces `${var}` when adjacent to other text; plain `"$var"` otherwise.

## Quoting

- Single quotes for literal strings: `'pacman'`, `'done'`,
  `export GUM_SPIN_SPINNER='minidot'`.
- Double quotes only when expansion is needed.
- Quote expansions: `"$@"`, `"$file"`, `"$(get_package_manager)"`. Inside
  `[[ ]]`, unquoted `$var` is acceptable (`[[ ! -f $filename ]]`). Leave an
  expansion unquoted only when word elision or splitting is intentional, and
  explain why nearby.

## Tests and Control Flow

- `[[ ]]` for file tests, regex/pattern matches, and compound conditions;
  `[ ]` is fine for simple string/number comparisons.
- Short-circuit one-liners for guards: `is_command_available 'gum' && return 0`,
  `[ -n "$reason_text" ] && reason_text=" $reason_text"`.
- `case` for dispatch, with patterns, bodies, and `;;` column-aligned:

```bash
case "$(get_package_manager)" in
    pacman) pacman -Qi "$package" &>> "$LOG_FILE" ;;
    apt)    dpkg-query -W "$package_apt" &>> "$LOG_FILE" ;;
    *)      return 1 ;;
esac
```

## Return Values and Errors

- Exit code carries success/failure; stdout carries the return value
  (`printf '%s\n' "$backup_name"`). When stdout carries data, send status/UI
  messages to stderr. Print an empty line as the "no result" sentinel alongside
  a meaningful exit code.
- Return nonzero explicitly at error points; add a trailing comment when the
  meaning is not obvious: `return 1 # need password`. Predicates should also
  end with explicit success. Ordinary procedures may use the clear status of
  their final command as their success return.
- For predicate functions that only evaluate a condition, prefer a guard plus
  explicit success over a verbose `if`/`return` block:

```bash
[[ $value =~ ^[1-9][0-9]*$ ]] || return 1
return 0
```

- Fail fast and check failures immediately using the project's established
  mechanism. Use `command || return 1` in a sourced library; use an assertion
  helper only when the project provides one.

## Output, Logging, Input

- `printf` with format strings (`%b` for pre-styled text) — never `echo -e`.
- When the project has logging, redirect non-user-facing command noise to its
  log: `cmd &>> "$LOG_FILE"`. Preserve output that is part of the command's
  public behavior.
- Read interactive input from `/dev/tty` so scripts work when stdin is
  redirected (`curl ... | bash`): `read -r reply </dev/tty`.
- Install an EXIT cleanup trap before a temporary resource can leak. A sourced
  library may define its handler with the other private functions and register
  the trap during source-time initialization at file end.

## Multi-line Formatting

Break long commands with backslash continuations aligned in a single column,
usually one option-value pair per continuation line:

```bash
gum spin --align='right'                                             \
         --title "${action_title}$(gum style --faint ' - checking')" \
         -- sleep "$UI_INTERACTION_DELAY"
```

## ShellCheck

- Keep scripts shellcheck-clean.
- When flagged code is intentional, suppress per-line with
  `# shellcheck disable=SCxxxx` directly above it — never file-wide — and
  keep a nearby comment explaining why the pattern is safe.
