# Extension API Reference

Distilled from pi's `docs/extensions.md`. For anything not covered, read that
doc in the installed package.

## Contents

- [Event lifecycle](#event-lifecycle)
- [Event return contracts](#event-return-contracts)
- [ExtensionContext (ctx)](#extensioncontext-ctx)
- [ExtensionCommandContext](#extensioncommandcontext)
- [ExtensionAPI (pi) methods](#extensionapi-pi-methods)
- [State management pattern](#state-management-pattern)
- [Session replacement footguns](#session-replacement-footguns)
- [Providers](#providers)
- [Mode behavior](#mode-behavior)

## Event lifecycle

Startup: `project_trust` (user/global + CLI extensions only) → `session_start { reason: "startup" }` → `resources_discover`.

Per prompt:

```
extension commands checked → input → skill/template expansion
→ before_agent_start → agent_start
→ [per turn: turn_start → context → before_provider_headers
   → before_provider_request → after_provider_response
   → LLM streams (message_start/update/end)
   → tools: tool_execution_start → tool_call → tool_execution_update
            → tool_result → tool_execution_end
   → turn_end]
→ agent_end
```

Session replacement (`/new`, `/resume`, `/fork`, `/clone`):
`session_before_switch|session_before_fork` (can cancel) → `session_shutdown`
→ extensions reloaded/rebound → `session_start { reason, previousSessionFile }`.

Others: `session_before_compact`/`session_compact`, `session_before_tree`/`session_tree`,
`model_select`, `thinking_level_select`, `session_info_changed`, `user_bash`.
Exit fires `session_shutdown`.

Parallel tool mode (default): `tool_execution_start` in source order,
`tool_result`/`tool_execution_end` in completion order, final toolResult
messages later in source order. `tool_call` handlers may not see sibling tool
results from the same assistant message.

## Event return contracts

Returning `undefined` always means "no change". Handlers run in extension load
order; several chain like middleware.

| Event | Return | Notes |
|---|---|---|
| `project_trust` | `{ trusted: "yes"\|"no"\|"undecided", remember? }` | Required. First yes/no wins and suppresses built-in prompt. |
| `input` | `{ action: "continue" }` / `{ action: "transform", text, images? }` / `{ action: "handled" }` | Transforms chain; first `handled` wins. `event.source`: `"interactive"\|"rpc"\|"extension"`. `event.streamingBehavior`: `undefined\|"steer"\|"followUp"`. |
| `before_agent_start` | `{ message?, systemPrompt? }` | `message` = persistent custom message injected into context. `systemPrompt` chains: base on `event.systemPrompt`. `event.systemPromptOptions` exposes structured prompt inputs. |
| `context` | `{ messages }` | `event.messages` is a deep copy; filter/modify freely. |
| `before_provider_headers` | none | Mutate `event.headers` in place; `null` deletes a header. Fires once per request (not per retry). |
| `before_provider_request` | replacement payload or `undefined` | Payload-level; not reflected in `ctx.getSystemPrompt()`. |
| `message_end` | `{ message }` | Replacement must keep the same `role`. |
| `tool_call` | `{ block: true, reason? }` | `event.input` is mutable — mutate in place to patch args; no re-validation. Narrow built-ins with `isToolCallEventType("bash", event)`; custom tools with explicit type params: `isToolCallEventType<"my_tool", MyToolInput>("my_tool", event)` (export the input type from the defining extension). Handler errors block the tool (fail-safe). |
| `tool_result` | `{ content?, details?, isError? }` | Partial patch; chains across handlers. Typed guards: `isBashToolResult(event)` etc. |
| `session_before_switch` / `session_before_fork` | `{ cancel: true }` | |
| `session_before_compact` | `{ cancel: true }` or `{ compaction: { summary, firstKeptEntryId, tokensBefore } }` | `event.reason`: `"manual"\|"threshold"\|"overflow"`. |
| `session_before_tree` | `{ cancel: true }` or `{ summary }` | |
| `user_bash` | `{ operations }` or `{ result }` | Wrap `createLocalBashOperations()` to modify commands. |
| `resources_discover` | `{ skillPaths?, promptPaths?, themePaths? }` | |

Notification-only (returns ignored): `agent_start`, `agent_end`, `turn_start`,
`turn_end`, `message_start`, `message_update`, `tool_execution_*`,
`session_start`, `session_shutdown`, `session_compact`, `session_tree`,
`model_select`, `thinking_level_select`, `session_info_changed`.

## ExtensionContext (ctx)

All handlers receive `ctx`:

- `ctx.ui` — see [tui.md](tui.md)
- `ctx.mode` — `"tui" | "rpc" | "json" | "print"`; guard TUI-only features with `=== "tui"`
- `ctx.hasUI` — true in TUI and RPC; guard dialogs/notify
- `ctx.cwd` — working directory; combine with `CONFIG_DIR_NAME` for project config paths
- `ctx.isProjectTrusted()` — check before honoring project-local config
- `ctx.sessionManager` — read-only session state: `getEntries()`, `getBranch()`, `buildContextEntries()`, `getLeafId()`, `getLabel(id)`, `getSessionFile()`
- `ctx.modelRegistry` / `ctx.model` — model lookup and current model
- `ctx.signal` — active agent abort signal (defined during turn events, `undefined` when idle); pass to nested `fetch`/exec/model calls
- `ctx.isIdle()` / `ctx.abort()` / `ctx.hasPendingMessages()`
- `ctx.shutdown()` — graceful shutdown request (deferred until idle)
- `ctx.getContextUsage()` — `{ tokens, ... } | undefined`
- `ctx.compact({ customInstructions?, onComplete?, onError? })` — fire-and-forget
- `ctx.getSystemPrompt()` — current chained system prompt string

## ExtensionCommandContext

Command handlers get extra session-control methods (would deadlock in event handlers):

- `ctx.waitForIdle()`
- `ctx.newSession({ parentSession?, setup?, withSession? })`
- `ctx.fork(entryId, { position?: "before"|"at", withSession? })`
- `ctx.switchSession(path, { withSession? })` — discover via static `SessionManager.list(cwd)`
- `ctx.navigateTree(targetId, { summarize?, customInstructions?, replaceInstructions?, label? })`
- `ctx.reload()` — same as `/reload`; treat as terminal: `await ctx.reload(); return;`
- `ctx.getSystemPromptOptions()` — base system prompt inputs (sensitive; don't log)

All session-changing methods return `{ cancelled: boolean }`.

## ExtensionAPI (pi) methods

- `pi.on(event, handler)`
- `pi.registerTool(def)` — works at load time and later (e.g. in `session_start` or commands); no `/reload` needed. See [tools.md](tools.md).
- `pi.registerCommand(name, { description, handler, getArgumentCompletions? })` — handler `(args: string, ctx: ExtensionCommandContext)`. Duplicate names get `:1`, `:2` suffixes.
- `pi.registerShortcut(keyId, { description, handler })` — e.g. `"ctrl+shift+p"` or `Key.ctrlAlt("p")`
- `pi.registerFlag(name, { description, type, default })` / `pi.getFlag(name)`
- `pi.sendMessage({ customType, content, display, details? }, { deliverAs?: "steer"|"followUp"|"nextTurn", triggerTurn? })` — custom message, participates in LLM context
- `pi.sendUserMessage(content, { deliverAs? })` — as if the user typed it; always triggers a turn; `deliverAs` required while streaming
- `pi.appendEntry(customType, data?)` — persisted, NOT in LLM context; render with `pi.registerEntryRenderer(customType, renderer)`
- `pi.registerMessageRenderer(customType, renderer)` — TUI renderer for `sendMessage` messages
- `pi.setSessionName(name)` / `pi.getSessionName()` / `pi.setLabel(entryId, label)`
- `pi.exec(cmd, args, { signal?, timeout? })` → `{ stdout, stderr, code, killed }`
- `pi.getActiveTools()` / `pi.getAllTools()` / `pi.setActiveTools(names)` — enable/disable tools at runtime (built-in and custom)
- `pi.setModel(model)` (returns `false` without API key), `pi.getThinkingLevel()` / `pi.setThinkingLevel(level)`
- `pi.getCommands()` — commands invokable via prompt, with `sourceInfo` provenance
- `pi.events` — shared bus for inter-extension communication (`on`/`emit`)
- `pi.registerProvider(name, config)` / `pi.unregisterProvider(name)`

## State management pattern

```typescript
export default function (pi: ExtensionAPI) {
	let items: Todo[] = [];

	// Reconstruct on every session start/resume/fork — last matching wins
	pi.on("session_start", async (_event, ctx) => {
		items = [];
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "message" && entry.message.role === "toolResult"
				&& entry.message.toolName === "todo") {
				items = entry.message.details?.todos ?? [];
			}
		}
	});

	pi.registerTool({
		name: "todo", /* ... */
		async execute() {
			// mutate items...
			return {
				content: [{ type: "text", text: "Done" }],
				details: { todos: [...items] },  // snapshot for reconstruction
			};
		},
	});
}
```

Store snapshots (spread copies), not live references. For non-tool state use
`pi.appendEntry("my-state", data)` and scan `entry.type === "custom" &&
entry.customType === "my-state"` (take the last one).

## Session replacement footguns

`withSession` callbacks on `newSession`/`fork`/`switchSession` run after the
old session got `session_shutdown` and the new extension instance got
`session_start`, but in the OLD closure:

- Use only the `ctx` passed to `withSession`; captured old `pi`/`ctx`
  session-bound objects are stale and throw.
- Do not reuse previously extracted objects (`const sm = ctx.sessionManager`).
- Capture only plain data (strings, ids, config) across the boundary.

## Providers

`pi.registerProvider(name, { name?, baseUrl, apiKey, api, headers?, authHeader?, models?, oauth?, streamSimple? })`.
`apiKey` supports `$ENV_VAR` and `!command`. Factory-time calls are queued and
flushed at startup; later calls apply immediately. For remote model discovery
use an async factory so models exist for `pi --list-models`. Full model/OAuth
reference: `docs/custom-provider.md` in the package.

## Mode behavior

| Mode | `ctx.mode` | `ctx.hasUI` | Notes |
|---|---|---|---|
| Interactive | `"tui"` | `true` | full TUI |
| RPC | `"rpc"` | `true` | dialogs via JSON protocol; `custom()` returns `undefined` |
| JSON | `"json"` | `false` | UI methods no-op |
| Print (`-p`) | `"print"` | `false` | can't prompt |
