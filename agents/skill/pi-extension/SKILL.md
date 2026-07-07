---
name: pi-extension
description: Create, extend, and modify extensions for the pi coding agent (pi-coding-agent). Use when the user asks to build a pi extension, add a custom tool/command/shortcut/flag, hook agent lifecycle events (tool_call, session_start, before_agent_start, etc.), render custom TUI components, add widgets/status/footer, or change an existing extension. Covers extension folder initialization, modular structure, event contracts, custom tools, and pi TUI usage. Load together with code-style and typescript-code skills.
compatibility: Requires pi coding agent. Extensions are TypeScript (ESM), loaded via jiti without compilation.
---

# Pi Extension Development

Distilled workflow and best practices for pi extensions. Load `code-style` and
`typescript-code` too; this skill adds pi-specific rules on top.

Detailed references (read on demand):

- [references/api.md](references/api.md) — events, return contracts, `ctx`/`pi` API, state, session replacement footguns
- [references/tools.md](references/tools.md) — custom tools: schemas, execute, errors, truncation, file mutation queue, overriding built-ins
- [references/tui.md](references/tui.md) — TUI components, `ctx.ui`, dialogs, widgets, custom components, theming, key handling

Authoritative sources (when references are not enough): the installed pi package
ships `docs/extensions.md`, `docs/tui.md`, and ~80 working examples in
`examples/extensions/`. Locate them:

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
`@earendil-works/pi-ai` (`StringEnum`), `@earendil-works/pi-tui` (components),
`typebox` (schemas), Node built-ins. npm deps work if a `package.json` sits
next to the extension and `npm install` was run.

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

1. **Clarify behavior** — which lifecycle points, which tools/commands, what
   UI. Map each requirement to an API: LLM-callable → `registerTool`;
   user-invoked → `registerCommand`/`registerShortcut`; intercept/observe →
   `pi.on(event)`; startup config → `registerFlag` or project config file.
2. **Find the closest example** in `examples/extensions/README.md` and read it.
3. **Skeleton first**: factory + event subscriptions with `ctx.ui.notify()`
   stubs. Run `pi -e ./ext.ts` and verify hooks fire.
4. **Split into modules when a file grows**: keep the factory, wiring, and
   closure state in `index.ts`; move pure logic (parsing, matching, formatting)
   to helper modules; move TUI component classes and subprocess plumbing to
   their own files. Pure helpers get unit-testable functions, not `pi` access.
5. **Add state handling last** (see State below).
6. **Test interactively** in tmux; iterate with `/reload`.

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
6. Retest: `pi -e ./ext.ts` in tmux, exercise old and new paths, then `/reload`
   in a real session.

## Testing

```bash
tmux new-session -d -s ext-test -x 100 -y 30
tmux send-keys -t ext-test "pi -e ./my-ext.ts" Enter
sleep 3 && tmux capture-pane -t ext-test -p
tmux send-keys -t ext-test "/mycommand" Enter
sleep 2 && tmux capture-pane -t ext-test -p
tmux kill-session -t ext-test
```

- Non-interactive smoke test: `pi -e ./my-ext.ts -p "prompt"` (no UI; verifies
  load errors, tool registration, headless behavior).
- Extension errors are logged and the agent continues, except `tool_call`
  handler errors which block the tool (fail-safe).
- Debug raw TUI output: `PI_TUI_WRITE_LOG=/tmp/tui.log pi -e ./ext.ts`.
