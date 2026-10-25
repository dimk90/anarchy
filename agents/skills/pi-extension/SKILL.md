---
name: pi-extension
disable-model-invocation: true
description: Create, extend, maintain, and release extensions for the pi coding agent (pi-coding-agent). Use when the user asks to build or change a pi extension, add tools/commands/shortcuts/flags/providers, hook lifecycle events, render TUI views, bootstrap a new pi extension package, test an extension, bump its Pi version, or release it. Provides the package template, project conventions, testing approach, and TUI style. Load together with code-style and typescript-code skills.
compatibility: Node.js 22.19+ and pnpm. The template's release script also needs git, gum, curl, and npm access; demo media uses git-lfs.
---

# Pi Extension Development

## Prerequisites — read these first if not in context

- `~/.pi/agent/skills/code-style/SKILL.md`
- `~/.pi/agent/skills/typescript-code/SKILL.md`

This skill holds project conventions only. For Pi APIs, read the installed Pi
docs, examples, and type declarations instead of relying on memory; check an
example against the types before copying it, since examples can lag the API.

## New Extension

Pick the smallest shape that fits:

1. **Single file** — one concern, no deps: `~/.pi/agent/extensions/my-ext.ts`
   or `.pi/extensions/my-ext.ts`.
2. **Directory** — several modules, still local: `my-ext/index.ts` + helpers.
3. **Package** — published to npm/git, versioned, documented: copy the
   template in `assets/package-template/`.

```bash
skill=~/.pi/agent/skills/pi-extension/assets/package-template
cp -r "$skill/." ./my-ext/ && cd my-ext
mv gitignore .gitignore && mv gitattributes .gitattributes && mv github .github
rg '\{\{' .   # replace every placeholder before the first commit
```

| Placeholder | Value |
| --- | --- |
| `{{package}}` | npm package and repository name |
| `{{owner}}` | GitHub owner |
| `{{Author Name}}` | package author |
| `{{command}}`, `{{arg-a}}`, `{{arg-b}}` | primary slash command (no `/`) and its arguments |
| `{{pi --version}}` | exact output of `pi --version` |
| `{{commit-sha}}` | commit that pins README and gallery media |
| `{{demo}}` | demo image base name under `doc/images/` |
| other `{{...}}` | prose to write, or a section to delete |

Then add `LICENSE` (MIT, author, year), run `pnpm install` and `pnpm check`,
and create `develop` and `master` branches (the release flow uses both).
Delete `src/pi-version.ts` and its test only when no Pi version floor matters.

## Project Conventions

- **Factory default export.** Pi requires `export default function (pi)`; it
  is the one exception to the named-export rule.
- **Module boundaries.** `src/index.ts` only registers commands and handlers
  and holds closure state. Parsing, state, and measurement live in modules
  without `pi` access; TUI components in `src/ui/`, with view state
  (`*-model.ts`) separate from rendering (`*-view.ts`).
- **Namespaces.** Prefix custom entry/message types and status keys with the
  package name (`"{{package}}:state"`).
- **Persisted shapes.** Session files keep old entry `data` and tool
  `details`. Keep reading old shapes; map old tool arguments with
  `prepareArguments()` instead of loosening the schema.
- **Pi dependencies.** All four Pi packages (`pi-coding-agent`, `pi-tui`,
  `pi-ai`, `pi-agent-core`) are `"*"` peer dependencies with exact dev pins
  matching `pi --version`; never in `dependencies`. Third-party runtime deps
  go in `dependencies`.
- **Version floor.** `MIN_PI_VERSION` in `src/pi-version.ts` refuses older Pi:
  the factory registers only the command, which reports the required version.
- **Published files.** `files` ships `src` and `README.md` only; verify with
  `pnpm pack --dry-run`. There is no build step: Pi loads `src/**.ts`.
- **Media.** Images live in `doc/images/` under git-lfs and are referenced by
  `https://media.githubusercontent.com/media/<owner>/<repo>/<commit-sha>/doc/images/<file>`,
  so README and `pi.image` stay immutable.
- **Docs.** One job per file: `AGENTS.md` (rules and sources of truth),
  `doc/ARCHITECTURE.md` (lifecycle, modules, state, invariants; split into
  `doc/architecture/` pages when it grows), `README.md` (users, including an
  honest Context Footprint), `CHANGELOG.md`, `doc/RELEASE.md`.
- **TUI style.** Custom views follow [references/tui-style.md](references/tui-style.md).

## Modifying an Existing Extension

1. Read the project's `AGENTS.md` and the docs it lists; project rules win over
   this skill.
2. Read the factory wiring, closure state, handlers, and persisted shapes
   before changing them.
3. Update `doc/ARCHITECTURE.md` (or the owning page) with any lifecycle, state,
   or persisted-shape change, and the README with any command change.

## Testing

Test in the cheapest layer that proves the behavior, and never call a real
model unless the user asks:

1. **Unit** — pure modules with `node:test`.
2. **Runtime** — `test/harness/runtime.ts` runs the pinned Pi in process
   against the loopback mock provider (`test/harness/mock-provider.ts`):
   scripted text, tool calls, delays, and HTTP errors for OpenAI Completions,
   OpenAI Responses, and Anthropic. Provider hooks run and request bodies are
   recorded. Load `test/fixtures/marker.ts` before and after the extension to
   prove load-order independence; add an `after_provider_response` sentinel
   when zero provider requests is an invariant.
3. **Real PTY** — TUI behavior, only when explicitly requested.

`pnpm test` runs `test/run.ts`: all files in one process, concurrently. So no
top-level hooks, no observable process-wide state changes, and no mocks that
change a shared static method; register per-test Pi settings with
`useSettings()` from `test/harness/settings.ts`. Register a session-stopping
`t.after()` before the one that removes its directory.

For a real-PTY check, use tmux (or `script`/Python `pty`; never piped stdio):

```bash
tmux new-session -d -s ext-test -x 100 -y 30
tmux send-keys -t ext-test "pi -e . --no-session" Enter
sleep 3 && tmux capture-pane -t ext-test -p
tmux send-keys -t ext-test "/mycommand" Enter
sleep 2 && tmux capture-pane -t ext-test -p
tmux kill-session -t ext-test
```

- Wait until `tmux display-message -p '#{pane_current_command}'` is `pi`
  before typing; keys sent earlier go to the shell.
- Check both `--tui-mode fullscreen` and `--tui-mode regular`, narrow and
  normal widths, resize, and theme changes; capture the live pane before
  closing a fullscreen view.
- With an installed copy also loaded, `pi -e .` suffixes duplicate commands in
  load order: `/cmd:1` is the working copy, `/cmd:2` the installed release.
- For recorded demos and media, use the `s-vhs-recording` skill.

## Bump Pi

1. Read the installed Pi `CHANGELOG.md` for every release between the current
   pin and `pi --version`, not only the target release.
2. Set the four Pi dev pins to the new version and run `pnpm install`.
3. Run `pnpm check`; fix breakages and recheck the lifecycle assumptions in
   `doc/ARCHITECTURE.md` against the changelog.
4. Raise `MIN_PI_VERSION` only when the extension now relies on new Pi
   behavior, with a `[package] Require Pi X.Y.Z` changelog entry.
5. Commit as `[ci] Bump Pi to X.Y.Z`.

## Release

Follow `doc/RELEASE.md`; `scripts/release.sh` runs every check, asks for one
approval, then commits, merges `develop` into `master`, tags, pushes, waits
for the GitHub release workflow, and publishes to npm.
