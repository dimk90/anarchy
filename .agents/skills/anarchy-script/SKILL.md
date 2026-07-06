---
name: anarchy-script
description: Author or edit install-* / configure-* scripts in this anarchy repo — the gum-based TUI installers/configurators that source the shared `common` library via curl. Use this skill whenever the user asks to create a new install-X or configure-Y script, refactor an existing one, add a step (install a package, drop a config file, set an env var/alias, enable a service), or extend any script in this repo that imports `common`. Trigger even if the user doesn't explicitly say "TUI" or "common library" — any work touching files matching `install-*` / `configure-*` / `create-user` / `wipe-disk` in the repo root, or any bash that calls `printf_section`, `action_run`, `action_require_package`, `action_install_file`, etc., counts.
---

# Anarchy Script Pattern

Scripts in this repo are gum-styled TUI shell scripts that download `common` (a ~1200-line shared bash lib) at runtime and use its helpers for output, package installs, file edits, privilege handling, and persistent shell config. Every install/configure script follows the same skeleton; the work is in choosing the right helpers and stringing them together.

The single source of truth is the local `common` file at the repo root. **Read it directly with Read/Grep — don't curl the published version.** The published file lags real edits.

## Clarify before coding

Before you start writing or editing a script, ask the user questions until you're 95% confident you understand what they need. Don't make any assumptions — surface them as questions instead. Cover at minimum:

- **Goal**: what should the script do, end-to-end? What does success look like?
- **Scope**: install vs. configure, which packages/files/services are in or out, opt-in vs. mandatory steps.
- **Inputs**: hardcoded values vs. interactive prompts (`gum choose`, `ask_yn`, password input).
- **Privilege**: which steps need root, whether the script may run as root at all.
- **Side effects**: what gets written/backed up, whether re-runs are idempotent or guarded.
- **Pre-flight checks**: which assumptions (devices, mountpoints, sibling-script outputs) must hold.

Reading existing code or `common` is fine to ground the questions, but don't pre-empt the user by guessing. Only start editing once the open questions are resolved.

## When you are invoked

Two flavors of work:

1. **Authoring a new script.** Start from `assets/template.sh`, give it a section/action structure, and pick helpers from `references/helpers.md`. Choose the filename: `install-X` for "get a thing onto the system", `configure-X` for "tune a thing already there".
2. **Editing an existing script.** Read the script first, then `common` to confirm signatures. Match the script's local style (some scripts inline functions and `export -f`, others assemble strings). Don't rewrite working code to "modernize" it.

## The skeleton

Every entry script opens identically:

```bash
#!/bin/bash

set -o nounset

## Imports

set -o errexit
COMMON=$(curl -fsSL "https://dimk90.github.io/anarchy/common")
# shellcheck source=common
source <(echo "$COMMON")
set +o errexit

## Routines

# helper functions here

main() {
    request_gum
    assert $? 'no gum - no fun :('

    printf_section "Starting\n"
    printf_action "Common lib version: ${STYLE_CLR}${COMMON_VERSION}\n"
    start_logger
    printf_action "Log started: ${STYLE_CLR}${LOG_FILE}\n"

    # actual work in further sections
    return 0
}

main "$@"
```

`set -o errexit` is on **only during import** — once the script is live, helpers return non-zero on purpose (e.g., to be checked with `assert`). Don't re-enable it inside `main`.

## Output flow

The repo has a strict visual hierarchy. Reproduce it; **don't use raw `echo` / `printf`** for user-facing lines. The canonical flow (mirror of the comment under `## Print` in `common`):

```
:: Section heading              <- printf_section "Section heading\n"
   -> Action — status            <- printf_action / action_run
   -> Action — status
   -> [INFO] in-flow note        <- printf_action with $(bullet_info) inlined
:: Next section
   -> Action
   -> [WARNING] in-flow note     <- printf_action with $(bullet_warning) inlined
:: Last section
   -> Action

[ERROR] terminal message         <- printf_error  (dedented; before exit)
[WARNING] terminal message       <- printf_warning (dedented; end-of-script)
[INFO] terminal message          <- printf_info    (dedented; end-of-script)
```

The bracketed lines have **two legal forms**: indented `   -> [WARNING] …` *inside* a section (built via `bullet_warning` inlined into `printf_action`), and dedented `[WARNING] …` *after* all sections (emitted by `printf_warning`). They're not interchangeable — pick by where you are in the flow.

- `printf_section "Title\n"` — bold `::` + faint title. Always trailing `\n`.
- `printf_action "Title\n"` — green `->` + faint title. Use for static info lines (versions, paths, "selected items: 3").
- `action_run 'Title' 'cmd' 'success_status'` — runs `cmd` with a gum spinner, prints the title with `success_status` on completion. This is the workhorse for any side-effecting command.
- `printf_warning` / `printf_info` / `printf_error` — for the **dedented terminal** `[WARNING] / [INFO] / [ERROR]` lines. **Reserve these for the script's terminus** — a final tip after all work is done, or a fatal line right before exit. They sit at the outer indent and mark a deliberate break out of normal flow; emitting one mid-script desynchronizes the section/action hierarchy. See the canonical layout comment in `common` (search `## Print` → `output flow`). **They emit their own leading blank line** — don't prefix them with a manual `echo`, that would double-space the gap.

#### Inline warning inside a flow

When you need to flag something but more sections/actions must follow, **don't** call `printf_warning` — inline a `bullet_warning` (or `bullet_info` / `bullet_error`) inside a `printf_action` so the indentation stays put. Example pattern (see `wipe-disk` for the live use):

```bash
printf_action "%b ${STYLE_DIM}this will${STYLE_CLR} %b ${STYLE_DIM}on${STYLE_CLR} %b${STYLE_DIM}. Proceed? ${STYLE_CLR}" \
    "$(bullet_warning)"                                              \
    "$(gum style --bold --foreground "$GUM_RED" 'destroy all data')" \
    "$(gum style --foreground "$GUM_YELLOW" "$disk")"
```

#### Don't leave a section empty

Every `printf_section` should be followed by at least one visible action. An orphaned `::` header — especially one followed only by a dedented `[WARNING]` / `[INFO]` / `[ERROR]` — looks like work was announced but never done.

When an early-return path threatens an empty section (silent detection that gates the rest), promote the detection into an `action_run`. Its 4th arg is the fail status (rendered red), which is the natural slot for the check's actual answer:

```bash
# Before: silent fstype lookup, section can end up empty
local fstype
fstype=$(findmnt -no FSTYPE --target /home 2>> "$LOG_FILE")

# After: section always has at least the detection action
local fstype
fstype=$(findmnt -no FSTYPE --target /home 2>> "$LOG_FILE")
action_run 'Detect /home filesystem'      \
    "[ '${fstype}' = 'btrfs' ]"           \
    'btrfs'                               \
    "${fstype:-unknown}"
```

Sketch the worst-case branch when adding a `printf_section`: if any path can fall through with zero actions printed, lift the gating step into `action_run`.

#### Group by concern; avoid single-action sections

Sections are *concerns*, not individual steps. A `printf_section` that fronts a single action is a smell — a header announcing one line of work is noise. Two failure modes, opposite directions:

- **Over-fragmented** — one tool's setup split across many headers (`Installing Limine Bootloader`, `Writing Limine Config`, `Registering Limine in NVRAM`, `Configuring Sync Defaults` …). Collapse them into one section (`Installing Limine`) whose actions read as the steps of that single job.
- **Genuinely distinct** — keep separate. The snapper configs for `/` and `/home` are different targets with different retention, so `Configuring Snapper for /` and `Configuring Snapper for /home` stay as two sections.

When a lone action is tightly related to an adjacent section, **fold it in** instead of giving it its own header. A step function can skip its own `printf_section` and just emit its `action_*` lines — they render under the preceding section's header. `ensure_holder` in `configure-snapshots` is the live precedent: no header of its own, its actions appear under `Configuring Snapper for …`.

Folding drops the *header*, not the step's guards. **Keep each folded step's own `action_request_permission`** — it's a silent no-op while sudo is cached, but it re-asserts privilege right before that step's work, which matters when a slow earlier action in the same section (e.g. an AUR build via `yay`) can outlast the sudo timestamp and would otherwise drop a raw password prompt into the TUI. See [Privileged commands](#privileged-commands).

### Inline highlights inside titles

To color a value inside a faint title, interrupt with `${STYLE_CLR}` (clear), then re-enter faint after. Example:

```bash
printf_action "Selected items: ${STYLE_CLR}${num_choice}\n"
```

`STYLE_CLR` resets *all* styling (color and dim), so the trailing prose loses faint. Two ways to fix:

- For a short trailing word, wrap it in `gum style --faint`:
  ```bash
  printf_action "Set EDITOR for ${STYLE_CLR}${STYLE_BOLD}$shells\n"
  ```
- For multi-segment lines, build the line with `printf` and inline `${STYLE_DIM}…${STYLE_CLR}` segments around the highlight (memory rule: re-apply faint after inline highlight).

When you have a short bullet plus secondary prose, prefer collapsing into a single `printf_action` with `%b` rather than two separate calls — keeps the output tight.

## Pre-flight checks

Lift things the script assumes — open LUKS device, expected filesystem type, a file written by a sibling script, a free mountpoint for re-runs — into a `Verifying prerequisites` section right after `Checking required tools`. Failing fast at the top is cheaper than discovering halfway through that `/dev/mapper/cryptroot` isn't open after partitioning has already started.

Each check runs through `action_run` with a meaningful fail status (not the default `failed`) so the section stays non-empty on every path and the output names what's wrong. Wrap the call in `if ! ...; then printf_error; exit 1; fi`:

```bash
if ! action_run "Cryptroot mapper ${STYLE_CLR}${CRYPT_DEV}"  \
                "[ -e '$CRYPT_DEV' ]"                        \
                'present'                                    \
                'missing'; then
    printf_error "open the LUKS volume first (e.g. cryptsetup open <part> ${CRYPT_NAME})\n"
    exit 1
fi

local fstype
fstype=$(as_root blkid -s TYPE -o value "$CRYPT_DEV" 2>>"$LOG_FILE")
if ! action_run 'Cryptroot filesystem type' \
                "[ '$fstype' = 'btrfs' ]"   \
                'btrfs'                     \
                "${fstype:-unknown}"; then
    printf_error "cryptroot is not btrfs - swap subvolume requires btrfs\n"
    exit 1
fi
```

Worth checking up front:

- **Devices / mappers**: `[ -e /dev/mapper/cryptroot ]`, `[ -b $disk ]`.
- **Filesystem type**: `blkid -s TYPE` for a raw device, `findmnt -no FSTYPE --target /path` for a mountpoint.
- **Files from sibling scripts**: e.g. `/etc/kernel/cmdline` written by `configure-boot`, `/etc/fstab` for any helper that appends to it.
- **Re-run guards**: `! mountpoint -q /swap`, `! [ -e /opt/<user> ]` — refuse to clobber existing state.
- **Derived values** (UUIDs, RAM-sized swap, detected device paths): populate into a `## Globals` block at the top of the script so downstream sections can read them without rerunning the lookup.

If any check needs root (`as_root blkid`, `as_root cat /etc/...`), call `action_request_permission 'to inspect <thing>'` once at the top of the section so the sudo password prompt lands inside styled UI instead of mid-flow during a bare `as_root` call.

**Don't lift opt-in prerequisites.** If a step is gated by `gum choose` / `ask_yn`, keep its checks lazy inside that branch — don't abort users who didn't opt in. `configure-swap` keeps the `/etc/kernel/cmdline` check inside `configure_hibernation` for this reason: users who only want swap+zram (no hibernation) don't need a kernel cmdline.

Live example: [configure-swap:verify_prerequisites](../../../configure-swap) checks cryptroot mapper, fstype, `/etc/fstab` presence, and `/swap`-not-mounted, then populates `CRYPT_UUID` and `SWAP_SIZE` globals for downstream sections.

## Action helpers — pick by intent

| Intent | Helper |
|---|---|
| Install/ensure a package | `action_require_package 'pkg'` (or `... '' 'apt-name'`) |
| Drop a file from the GitHub Pages URL onto disk (with backup) | `action_install_file dest url [prefix]` |
| Run any side-effecting command with spinner | `action_run 'Title' 'cmd' 'done'` |
| Ask for sudo before a privileged action | `action_request_permission 'to do X'` |
| Read a password with confirmation | `action_set_password 'New user password'` |

Full signatures and corner cases live in `references/helpers.md`.

### Privileged commands

Always gate `as_root` / a `sudo` action behind `action_request_permission` *first*, so the password prompt happens with a styled UI before the spinner. If the action genuinely doesn't need root in your control flow, drop `as_root` entirely — don't add it defensively.

#### `as_root` vs `$(check_sudo)` — pick by call site

Both elevate to root when EUID≠0, but they're suited to different contexts. The rule is **function call vs. string-building**:

- **`as_root cmd args`** is a function — it executes its arguments directly. Use it for direct shell invocations: bare statements, `if` conditions, `$(...)` capture, exported helper bodies.
  ```bash
  as_root mount -o subvolid=5 "$btrfs_dev" "$MNT"
  uuid=$(as_root blkid -s UUID -o value "$btrfs_dev")
  if as_root grep -q "$pat" /etc/fstab; then ...; fi
  ```
- **`$(check_sudo)`** echoes the literal string `'sudo'` (or `''`). Use it when you're constructing a command **string** that something else will evaluate later — most often the `cmd` arg of `action_run`, or the prefix arg of `action_install_file` / file helpers. The exported helper `as_root` isn't visible inside the `bash -c` subshell that runs the spinner command.
  ```bash
  action_run 'Append fstab entry' \
      "echo '${line}' | $(check_sudo) tee -a /etc/fstab" 'done'

  action_install_file '/etc/systemd/zram-generator.conf' \
                      'https://dimk90.github.io/anarchy/zram/zram-generator.conf' \
                      "$(check_sudo)"
  ```

Mixing them in the wrong direction works by accident (`$(check_sudo) cmd` happens to expand to a valid prefix), but it's inconsistent — prefer `as_root` whenever you're calling a command directly.

`install-yay` is the deliberate exception: it refuses to run as root (makepkg can't build as root), so it uses raw `sudo` directly without the as_root/check_sudo dance. Don't "normalize" it.

#### Secrets must not enter the spinner

`action_run` runs `bash -c "${command} &>> $LOG_FILE"`, so anything you interpolate into the `command` string lands in that shell's `/proc/<pid>/cmdline`. Embedding a passphrase, password, or token there leaks it to anyone who can read that PID's cmdline (root, same-UID processes), and breaks if the secret contains `'` (the outer expansion happens before single-quoting protects you — quote-injection is then arbitrary shell, often as root).

Pattern: do the privileged work *outside* `action_run`, piping the secret in via the bash `printf` builtin, then call `action_run` with an empty `command` to keep the standard UI cadence.

```bash
# real work runs silently, outside the spinner
printf '%s' "$secret" \
    | as_root some_cmd --key-file=- "$arg" 2>> "$LOG_FILE"
local rc=$?
unset secret
assert $rc 'some_cmd failed'

# UI-only step: empty command falls back to sleep $UI_INTERACTION_DELAY,
# title + 'done' status render after the assert passes
action_run "Run ${STYLE_CLR}some_cmd${STYLE_DIM} on ${STYLE_CLR}${arg}" '' 'done'
```

`printf` is a bash builtin, so the secret never spawns a child process and never leaves the script's address space until the kernel pipe hands it to the privileged binary. `--key-file=-` (cryptsetup) or stdin (chpasswd) is the conventional way to receive it.

Two gotchas the live code hit:

- **Prefer `assert $?` directly; capture `local rc=$?` only when something between the command and its consumer would clobber `$?`.** `unset secret` (or any other intervening statement) returns its own exit code — typically 0 — and silently overwrites `$?`, so without the capture every assert passes regardless of the command's outcome. In `configure-disk:encrypt_root` the first two cryptsetup calls use `assert $?` directly; the third needs `local rc=$?` because `unset passphrase` sits between the pipe and the assert. The same rule covers any `$?` consumer — `return $?`, `if [ $? -eq 0 ]`, etc. — not just `assert`.
- **The empty `action_run` runs *after* the `assert`, not before.** On failure the assert exits before the UI step ever renders, so a misleading "done" can never appear; on success the empty `action_run` shows the title + spinner-pause + success status.

Live examples: [create-user:configure_user_account](../../../create-user) (chpasswd) and [configure-disk:encrypt_root](../../../configure-disk) (luksFormat / open / refresh).

## File / config / env helpers

`config_set_param`, `remove_line`, `replace_line` all take **regex** for their pattern parameter — even when the input "looks literal". You must escape `.`, `|`, `(`, `)`, `$`, `?`, `+`, `*`. Common gotchas:

```bash
# pipe must be \|
remove_line ~/.config/fish/config.fish 'starship init fish \| source'

# dots in paths must be \.
config_set_param ~/.bashrc 'source ~/\.config/bash/aliases\.bash'

# parentheses and dollars in eval lines
config_set_param ~/.bashrc 'eval "\$\(zoxide init --cmd j bash\)"'
```

If you forget to escape, the helper either matches nothing or matches too much — both silently. There's `regex_sanitize` in `common` if you ever need the inverse.

For backup of an existing file before overwriting, `action_install_file` does it for you. For manual backup, `backup_file path [prefix]` returns the new `.bakN` filename via stdout.

### Persistent env / aliases

`env_set_permanent`, `env_unset_permanent`, and `alias_set_permanent` write to `~/.bashrc` and to fish via `set -Ux` / `alias --save`. They print the comma-separated list of shells they wrote to (`fish,bash` / `bash` / empty), and return 0 if at least one shell succeeded. Idiom:

```bash
local shells
shells=$(alias_set_permanent 'cat' 'bat')
action_run 'Set alias cat->bat' '' "${shells}"
```

The empty middle arg means "no command, just print" — `action_run` shows the title with a brief spin to communicate "done".

## Multi-step actions

For a chain of commands inside a single `action_run` spinner, **define a local function and `export -f` it** rather than building a `cmd1 && cmd2 && cmd3` string. Functions are easier to read, easier to debug (the body lives at module scope), and don't need the careful escaping that string-quoted compound commands require:

```bash
# shellcheck disable=SC2329
fish_enable_zoxide() {
    config_set_param ~/.config/fish/config.fish 'zoxide init --cmd j fish \| source'
}

# inside main / install_zoxide:
export -f fish_enable_zoxide
action_run 'Enable zoxide for fish' 'fish_enable_zoxide' 'done'
```

The `# shellcheck disable=SC2329` suppresses the "function never invoked" warning shellcheck emits because the function is called via `bash -c` inside `action_run`.

## Selection menus

For "let the user pick from a list" use `gum choose` with the section bullet as header. `--no-limit --selected='*'` means multi-select with all items pre-selected (the convention for "we'll do all unless you say otherwise"):

```bash
local section
section=$(prefix_printf "$(bullet_section)" 'Confirm Items')

local choices
if choices=$(gum choose --no-limit --selected='*' \
                        --cursor="   > "          \
                        --header "${section}"     \
                        'Settings' 'Keybindings' 'Default Editor'); then
    choices=${choices,,}     # lowercase for matching
else
    return 0
fi

printf "%s\n" "$section"     # repaint header after gum clears it

local num_choice
num_choice=$([ -n "$choices" ] && wc -l <<< "$choices" || echo 0)
printf_action "Selected items: ${STYLE_CLR}${num_choice}\n"
[ "$num_choice" -eq 0 ] && return 0

# dispatch
grep -q 'settings'    <<< "$choices" && do_settings
grep -q 'keybindings' <<< "$choices" && do_keybindings
```

For single-select, `--limit=1` and a default fallback via `|| choice='pure'`.

## Filename and commit conventions

- `install-NAME` puts a thing on the system (package, driver bundle, plugin set).
- `configure-NAME` tunes an existing thing (pacman.conf, vconsole, prompt).
- Commits use `[scope] Description`. **Scope must match an existing one in `git log`** — e.g., `[doc]` not `[docs]`, `[modern-cli]` not `[cli]`. AGENTS.md examples are illustrative, not authoritative; check `git log --format='%s' | grep -oP '^\[[^]]+\]' | sort -u` before inventing a new scope.

## Deployment caveat

Every file at the repo root is served by Jekyll under the GitHub Pages URL. Scripts curl helpers and assets from that same URL, so:

- Don't drop scratch files at the repo root — they get published.
- New asset directories (`foo/bar.conf`) are reachable as `https://dimk90.github.io/anarchy/foo/bar.conf` automatically. No build step.
- If a path must be excluded, add it to `_config.yaml`'s `exclude` list.

## Fast access

- `assets/template.sh` — copy-paste starter for a new script.
- `references/helpers.md` — full per-helper reference (signatures, return values, examples). Read this when you're picking between helpers or hit an unfamiliar one in existing code.
