---
name: pi-extension
description: Create, extend, and modify extensions for the pi coding agent (pi-coding-agent). Use when the user asks to build or change a pi extension, add tools/commands/shortcuts/flags/providers, register MCP servers or virtual models, hook lifecycle events, transform model context, or render TUI components, widgets, and status. Covers Pi 1.1 event contracts, tool exposure, nested calls, providers, and TUI usage. Load together with code-style and typescript-code skills.
compatibility: Verified against Pi 1.1.0. Requires Node.js 22.19+ for npm installs. Extensions are TypeScript (ESM), loaded via jiti without compilation.
---

# Pi Extension Development

## Prerequisites — read these first if not in context

- `~/.pi/agent/skills/code-style/SKILL.md`
- `~/.pi/agent/skills/typescript-code/SKILL.md`

Distilled workflow and best practices for pi extensions; this skill adds
pi-specific rules on top of the prerequisites above.

Detailed references (read on demand):

- [references/api.md](references/api.md) — events, boundaries, prompt/context edits, `ctx`/`pi`, providers, virtual models, MCP, state
- [references/tools.md](references/tools.md) — schemas, results, exposure, codemode/nested calls, usage, truncation, file mutation queue, overrides
- [references/tui.md](references/tui.md) — TUI components, `ctx.ui`, dialogs, widgets, custom components, theming, key handling
- [references/packaging.md](references/packaging.md) — published package layout: `package.json`/`tsconfig` rules, documentation set, release checklist, TUI-capture harness

Authoritative sources (when references are not enough): the installed pi package
ships `CHANGELOG.md`, `docs/extensions.md`, `docs/tui.md`,
`docs/custom-provider.md`, `docs/virtual-models.md`, `docs/mcp.md`,
`docs/codemode.md`, and working examples in `examples/extensions/`.
Locate them:

```bash
pi_entry=$(readlink -f "$(command -v pi)")
# pnpm's executable is a shim; its target is the actual entry point
shim_target=$(rg --no-line-number '^# cmd-shim-target=' "$pi_entry" 2>/dev/null || true)
[[ -z $shim_target ]] || pi_entry=${shim_target#\# cmd-shim-target=}
pi_pkg=${PI_PACKAGE_DIR:-$(dirname "$pi_entry")}
while [[ ! -d $pi_pkg/docs && $pi_pkg != / ]]; do
    pi_pkg=$(dirname "$pi_pkg")
done
ls "$pi_pkg/docs" "$pi_pkg/examples/extensions"
```

Walk upward rather than assuming a fixed number of parents: npm's CLI entry
point is now `dist/bundle/cli.js`. For a standalone/managed installation, use
its adjacent docs or an explicit `PI_PACKAGE_DIR`.
Run `pi --version`; for a latest-version update, compare it with
`npm view @earendil-works/pi-coding-agent version`. If they differ, do not label
installed docs as the latest release. After an upgrade, review all intervening
release notes, not just the target version's breaking changes. Read the relevant
installed docs completely and follow their related API references. Exact contracts live
in `dist/core/extensions/types.d.ts` and the companion package declarations.
If an example disagrees with the installed types or runtime, verify before
copying it — examples can lag an API change.

Prefer adapting a close example over writing from scratch — check the table
in `examples/extensions/README.md` first.

## Anatomy

An extension is a TypeScript module with a default-exported factory:

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => { /* ... */ });
	pi.registerTool({ /* ... */ });
	pi.registerCommand("name", { /* ... */ });
	pi.registerShortcut("ctrl+shift+p", { /* ... */ });
	pi.registerFlag("my-flag", { description: "...", type: "boolean", default: false });
}
```

Available imports: `@earendil-works/pi-coding-agent` (types, helpers),
`@earendil-works/pi-ai` (`StringEnum`, provider/API helpers),
`@earendil-works/pi-tui` (components), `@earendil-works/pi-agent-core`
(agent types), `typebox` (schemas; 1.3.27 in Pi 1.1.0), Node built-ins.
The extension factory's default export is required by Pi and is an exception
to the TypeScript skill's named-export rule. npm
deps work if a `package.json` sits next to the extension and `npm install` was
run.

## Initializing an Extension Folder

Pick the smallest structure that fits:

1. **Single file** — one concern, no deps: `~/.pi/agent/extensions/my-ext.ts`
   (global) or `.pi/extensions/my-ext.ts` (project).
2. **Directory** — multiple modules: `my-ext/index.ts` + helper files
   (`utils.ts`, `agents.ts`, ...). `index.ts` exports the factory.
3. **Package** — needs npm deps: add `package.json` with `dependencies` and
   `"pi": { "extensions": ["./index.ts"] }`, run `npm install`. Runtime deps
   must be in `dependencies`, not `devDependencies`.
4. **Published package** — distributed via npm/git: start from the template in
   `assets/package-template/` and read
   [references/packaging.md](references/packaging.md).

```bash
skill=~/.pi/agent/skills/pi-extension/assets/package-template
cp -r "$skill/." ./my-ext/ && cd my-ext
mv gitignore .gitignore && mv gitattributes .gitattributes
rg '\{\{' .   # replace every placeholder before the first commit
```

The template ships `package.json` (peer `"*"` + exact pins, `pi` manifest,
gallery image), `tsconfig.json`, `pnpm-workspace.yaml`, `AGENTS.md`,
`README.md`, `CHANGELOG.md`, `doc/PLAN.md`, `doc/RELEASE.md`, a factory plus
pure-command-grammar source pair, `node:test` grammar and state tests, the load-order
`test/fixtures/marker.ts`, and a tmux view-capture harness.

Extra load paths: `settings.json` `"extensions": ["/path/to/ext.ts"]` and
`"packages": ["npm:@foo/bar@1.0.0", "git:github.com/user/repo@v1"]`.

During development, load explicitly: `pi -e ./my-ext/index.ts`. In
auto-discovered locations, `/reload` hot-reloads the extension.

## Writing an Extension Step by Step

1. **Clarify behavior** — which lifecycle points, tools/commands, providers,
   and UI. Map each requirement to an API: LLM-callable → `registerTool`;
   user-invoked → `registerCommand`/`registerShortcut`; model integration →
   `registerProvider`; request routing → `registerVirtualModel`; MCP →
   `registerMcpServer`; rendering-only tool changes → `registerToolRenderer`;
  intercept/observe → `pi.on(event)`; startup config →
   `registerFlag` or project config file. Choose tool exposure explicitly for
   interactive or orchestrating tools (usually `model-only`).
2. **Find the closest example** in `examples/extensions/README.md` and read it.
3. **Skeleton first**: factory + event subscriptions with `ctx.ui.notify()`
   stubs. Run `pi -e ./ext.ts` and verify hooks fire.
4. **Split into modules when a file grows**: keep the factory, wiring, and
   closure state in `index.ts`; move pure logic (parsing, matching, formatting)
   to helper modules; move TUI component classes and subprocess plumbing to
   their own files. Pure helpers get unit-testable functions, not `pi` access.
5. **Add state handling last** (see State below).
6. **Test interactively** in a real PTY (tmux, `script`, or a Python pty
   harness); iterate with `/reload`.

## Core Rules

- **Factory does registration only.** No background processes, sockets,
  watchers, or timers in the factory — it may run in invocations that never
  start a session. Start resources in `session_start` or on first use; register
  an idempotent `session_shutdown` cleanup handler.
- **Async factory only for startup-critical awaits** (e.g. fetching a model
  list before `pi --list-models`). pi awaits it before startup continues.
- **Guard UI calls.** `ctx.hasUI` before dialogs/notify (TUI+RPC);
  `ctx.mode === "tui"` before `ctx.ui.custom()`, editor/header/footer/widget
  factories. RPC supports string-array widgets, not component factories.
  In non-interactive modes decide a safe default (e.g. block dangerous action).
- **Keep closure state minimal and reconstructable.** State lives in the
  factory closure; persist via tool result `details` or `pi.appendEntry()` and
  rebuild from `ctx.sessionManager.getBranch()` on `session_start` and
  `session_tree` when state follows the active branch. Do not replay abandoned
  branches from `getEntries()`.
- **Pass `ctx.signal` / tool `signal` to everything abortable** (`fetch`,
  `pi.exec`, model calls) so Esc cancels extension work.
- **Custom messages vs entries**: `pi.sendMessage()` participates in LLM
  context; `pi.appendEntry()` persists non-context state in every mode, with
  optional TUI rendering. Neither is private storage; `display: false` is not
  a privacy boundary.
- **Use `CONFIG_DIR_NAME`** instead of hardcoding `.pi` for project-local paths.
- **Namespace custom types and status keys** with your extension name
  (`customType: "plan-mode-context"`, `setStatus("my-ext", ...)`).
- **Preserve prompt state.** Mutate `before_agent_start.systemPromptOptions`
  for structured additions; returning `systemPrompt` forces the full prompt.
  `context` excludes system messages; `context_with_system` owns the whole
  request transcript, including the leading system message and tool state.
- **Return contracts matter.** `tool_call` can block; `message_end` can replace
  a same-role message; `turn_end` and `agent_before_settle` can return chained
  entries and request continuation. `agent_settled` is notification-only;
  its `aborted` flag distinguishes cancellation, not success from failure.
  Most handlers may return `undefined`; `project_trust` requires a decision
  and receives `ProjectTrustContext`, not a session-capable `ExtensionContext`.
  See [references/api.md](references/api.md).

## Pi-Native TUI Style

For custom selector/dialog components, match pi's `/settings` and `/model`
visual language instead of inventing a new one:

- Always color through the current theme's semantic keys with `theme.fg(...)`
  (and theme-based colorizers for borders). Never hardcode hex, ANSI escape
  codes, or named terminal colors, so views track the user's active theme.
- Use an accent title and fixed-column `→` cursor. Color both the selected label
  and its value with `accent`; use foreground only, never a full-row background.
- Render section sub-headers (e.g. `INITIAL`, `RUNTIME`) bold with `mdHeading`.
- Use `text` for main rows, `muted` for sub-items and unselected values, and
  `dim` for sub-sub-items and overflow position `(current/total)`.
- Format hints as dim key + muted description (`rawKeyHint("↑↓", "Navigate")`)
  and join multiple hints with ` · `. Put a short muted dialog description
  between blank rows immediately above the hints.
- Inside bordered dialogs, use one blank row at top/bottom and after the title;
  keep one blank row before later subheaders. Indent hierarchy after the cursor
  so the cursor remains in one column.
- Keep headers, sub-headers, and the `→` cursor flush at column 0; indent the
  muted description, the `(current/total)` counter, the hint row, and preview
  body content two spaces.
- Use Title Case for titles, section names, and hint labels (`Context
  Injections`, `Esc Close`), and conventional keyboard casing for key names
  (`PgUp/PgDn`, not `Pgup/Pgdn`), but keep recognizable identifiers such as
  `pi` and tool names (`edit`, `web_search`) in their literal casing and keep
  longer descriptions in sentence case.

Use `SelectList`/`SettingsList` when they fit. For custom hierarchical views and
full examples, see [references/tui.md#pi-native-selector-style](references/tui.md#pi-native-selector-style).

## Modifying an Existing Extension

1. **Read the whole extension first** — factory wiring, closure state, event
   handlers, persisted `details`/entry shapes.
2. **Preserve persisted shapes.** Session files already contain old
   `details`/`data`. When changing a tool schema, add `prepareArguments()` to
   map old stored args to the new schema instead of loosening `parameters`.
   When changing entry data, handle old shapes in the `session_start`
   reconstruction.
3. **Match the existing structure** — single-file stays single-file unless it
   grows past a few hundred lines; then split as in step 4 above.
4. **Check for handler chaining**: `tool_result` patches, `input` transforms,
   prompt options, and boundary drafts chain across extensions. Preserve prior
   values; prefer adding a namespaced `systemPromptOptions.sections` entry
   over forcing a concatenated prompt. Redact both `content` and
   `structuredContent` when changing tool output.
5. When adding UI to a previously headless extension, add `ctx.hasUI` guards.
6. Retest: `pi -e ./ext.ts` in a real PTY, exercise old and new paths, then
   `/reload` in a real session.

## Testing

Test in the cheapest layer that proves the behavior:

1. Run the project typecheck and pure unit tests.
2. Test lifecycle/event behavior without a provider when possible. Abort a
   synthetic run at `turn_start`; add an `after_provider_response` sentinel
   when zero provider calls is an invariant. Assert the resulting assistant
   message's `stopReason` explicitly — it varies by abort point and pi version
   (see [references/api.md](references/api.md#event-return-contracts)).
3. Make a provider-backed smoke test only when output from a real model is
   relevant. Unless the project or user specifies another model, use the
   cheapest/simple default and avoid session persistence:

```bash
pi --model anthropic/claude-haiku-5-5 -e ./my-ext.ts --no-session \
  -p "Say one word: ok"
```

This headless test verifies loading, registration, non-TUI guards, and normal
turn behavior. Do not spend a model call merely to prove TypeScript compiles or
a handler registered.

For TUI behavior, use a real PTY. Prefer tmux when available:

```bash
tmux new-session -d -s ext-test -x 100 -y 30
tmux send-keys -t ext-test "pi -e ./my-ext.ts --no-session" Enter
sleep 3 && tmux capture-pane -t ext-test -p
tmux send-keys -t ext-test "/mycommand" Enter
sleep 2 && tmux capture-pane -t ext-test -p
tmux kill-session -t ext-test
```

If tmux is unavailable, use `script` or a Python `pty` harness; do not treat
plain piped stdin/stdout as a TUI test. Pi 1.1 defaults to fullscreen; test
both `--tui-mode fullscreen` and `--tui-mode regular`, narrow and normal
widths, resize, theme changes (including `system`), and focus/close behavior.
Tool renderers must also respect `outputPad: 0` and `outputPad: 1`, including
`renderShell: "self"`; display recorded `context.durationMs`, not wall time.
Keep a keyboard path for mouse interactions. Use `PI_TUI_WRITE_LOG` only for
controlled test data — raw terminal logs can contain private content.

For repeatable frame captures, adapt `assets/package-template/test/capture-view.sh`:
it gates startup on the pane's foreground process, gates input on pi's
completion popup, and copies session files before opening them. Run it with
`TUI_MODE=fullscreen` and `TUI_MODE=regular`. When an
installed copy of the same extension is present, `pi -e .` produces duplicate
commands suffixed in load order (`/cmd:1` working copy, `/cmd:2` installed) —
use that to diff working copy against the release.

Also verify relevant boundaries:

- extension loaded before and after other chained handlers;
- print/headless behavior for extensions with UI code;
- `/reload`, new/resumed/forked sessions when closure or persisted state exists;
- nested tool calls and permission gates when tools are callable from codemode;
- extension errors: most are reported and execution continues, while
  `tool_call` and `user_bash` handler errors fail closed.

For isolated CLI tests, `--no-extensions` also disables built-in extensions
(MCP, codemode, tool search, llama.cpp). Add the required ones explicitly with
`-e builtin:mcp`, `-e builtin:codemode`, `-e builtin:tool-search`, or
`-e builtin:llama.cpp`; otherwise a test can accidentally skip the integration.
`--no-mcp` disables only built-in MCP. `--tools +codemode,-write` adjusts the defaults; a plain
allowlist replaces them. Tool patterns are supported, but an allowlist keeps
MCP tools callable unless it contains an `mcp__` entry. Do not mistake the
model's declared tool selection for an access-control boundary.
