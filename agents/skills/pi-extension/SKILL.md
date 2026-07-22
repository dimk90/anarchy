---
name: pi-extension
description: Create, extend, and modify extensions for the pi coding agent (pi-coding-agent). Use when the user asks to build a pi extension, add a custom tool/command/shortcut/flag/provider, hook agent lifecycle events (tool_call, session_start, before_agent_start, etc.), render custom TUI components, add widgets/status/footer, or change an existing extension. Covers extension structure, event contracts, custom tools and providers, and pi TUI usage. Load together with code-style and typescript-code skills.
compatibility: Requires pi coding agent. Extensions are TypeScript (ESM), loaded via jiti without compilation.
---

# Pi Extension Development

## Prerequisites — read these first if not in context

- `~/.pi/agent/skills/code-style/SKILL.md`
- `~/.pi/agent/skills/typescript-code/SKILL.md`

Distilled workflow and best practices for pi extensions; this skill adds
pi-specific rules on top of the prerequisites above.

Detailed references (read on demand):

- [references/api.md](references/api.md) — events, return contracts, `ctx`/`pi` API, providers, state, session replacement footguns
- [references/tools.md](references/tools.md) — custom tools: schemas, execute, usage, truncation, file mutation queue, dynamic loading, overriding built-ins
- [references/tui.md](references/tui.md) — TUI components, `ctx.ui`, dialogs, widgets, custom components, theming, key handling

Authoritative sources (when references are not enough): the installed pi package
ships `docs/extensions.md`, `docs/tui.md`, `docs/custom-provider.md`, and ~80
working examples in `examples/extensions/`. Locate them:

```bash
pi_pkg=$(dirname "$(dirname "$(readlink -f "$(which pi)")")")  # .../pi-coding-agent
ls "$pi_pkg/docs" "$pi_pkg/examples/extensions"
```

Prefer copying a close example over writing from scratch — check the table in
`examples/extensions/README.md` first.

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
`@earendil-works/pi-tui` (components), `typebox` (schemas), Node built-ins. npm
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

Extra load paths: `settings.json` `"extensions": ["/path/to/ext.ts"]` and
`"packages": ["npm:@foo/bar@1.0.0", "git:github.com/user/repo@v1"]`.

During development, load explicitly: `pi -e ./my-ext/index.ts`. In
auto-discovered locations, `/reload` hot-reloads the extension.

## Writing an Extension Step by Step

1. **Clarify behavior** — which lifecycle points, tools/commands, providers,
   and UI. Map each requirement to an API: LLM-callable → `registerTool`;
   user-invoked → `registerCommand`/`registerShortcut`; model integration →
   `registerProvider`; intercept/observe → `pi.on(event)`; startup config →
   `registerFlag` or project config file.
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
  `ctx.mode === "tui"` before `ctx.ui.custom()`, editor/footer/widget factories.
  In non-interactive modes decide a safe default (e.g. block dangerous action).
- **Keep closure state minimal and reconstructable.** State lives in the
  factory closure; persist via tool result `details` or `pi.appendEntry()` and
  rebuild in `session_start` by scanning `ctx.sessionManager` entries. This is
  what makes forking/branching/resume work.
- **Pass `ctx.signal` / tool `signal` to everything abortable** (`fetch`,
  `pi.exec`, model calls) so Esc cancels extension work.
- **Custom messages vs entries**: `pi.sendMessage()` participates in LLM
  context; `pi.appendEntry()` is TUI-only persistence. Pick deliberately.
- **Use `CONFIG_DIR_NAME`** instead of hardcoding `.pi` for project-local paths.
- **Namespace custom types and status keys** with your extension name
  (`customType: "plan-mode-context"`, `setStatus("my-ext", ...)`).
- Return contracts matter: `tool_call` → `{ block, reason }`; `input` →
  `{ action: "continue" | "transform" | "handled" }`; `session_before_*` →
  `{ cancel: true }`; `message_end` → `{ message }`. Returning `undefined`
  always means "no change". See [references/api.md](references/api.md).

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
4. **Check for handler chaining**: `tool_result` patches and `input` transforms
   chain across extensions; `before_agent_start` chains `systemPrompt`. Don't
   clobber — extend (`event.systemPrompt + "\n..."`).
5. When adding UI to a previously headless extension, add `ctx.hasUI` guards.
6. Retest: `pi -e ./ext.ts` in a real PTY, exercise old and new paths, then
   `/reload` in a real session.

## Testing

Test in the cheapest layer that proves the behavior:

1. Run the project typecheck and pure unit tests.
2. Test lifecycle/event behavior without a provider when possible. Abort a
   synthetic run at `turn_start`; add an `after_provider_response` sentinel
   when zero provider calls is an invariant.
3. Make a provider-backed smoke test only when output from a real model is
   relevant. Unless the project or user specifies another model, use the
   cheapest/simple default and avoid session persistence:

```bash
pi --model anthropic/claude-haiku-4-5 -e ./my-ext.ts --no-session \
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
plain piped stdin/stdout as a TUI test. Test narrow and normal terminal widths
for custom components. Use `PI_TUI_WRITE_LOG=/tmp/tui.log` to inspect raw TUI
output when rendered frames are ambiguous.

Also verify relevant boundaries:

- extension loaded before and after other chained handlers;
- print/headless behavior for extensions with UI code;
- `/reload`, new/resumed/forked sessions when closure or persisted state exists;
- extension errors: most are logged and execution continues, while `tool_call`
  handler errors block the tool fail-safe.
