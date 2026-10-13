# Extension API Reference

Verified against Pi 1.1.0's `docs/extensions.md` and
`dist/core/extensions/types.d.ts`. Use the installed declarations for exact
types; public docs summarize rather than list every field.

## Contents

- [Event lifecycle](#event-lifecycle)
- [Event return contracts](#event-return-contracts)
- [Prompt and context state](#prompt-and-context-state)
- [Actionable boundaries](#actionable-boundaries)
- [UI prompt lifecycle](#ui-prompt-lifecycle)
- [ExtensionContext (ctx)](#extensioncontext-ctx)
- [ExtensionCommandContext](#extensioncommandcontext)
- [ExtensionAPI (pi) methods](#extensionapi-pi-methods)
- [State management pattern](#state-management-pattern)
- [Session replacement footguns](#session-replacement-footguns)
- [Providers](#providers)
- [Virtual models and non-chat models](#virtual-models-and-non-chat-models)
- [MCP servers](#mcp-servers)
- [SDK embedding](#sdk-embedding)
- [Mode behavior](#mode-behavior)

## Event lifecycle

Startup: `project_trust` (user/global + CLI extensions only) → `session_start { reason: "startup" }` → `resources_discover`.

Per prompt:

```
extension commands checked → input → skill/template expansion
→ before_agent_start → agent_start
→ [per turn: turn_start → context → context_with_system
   → provider request/response hooks
   → LLM streams (provider_stream_event, message_start/update/end)
   → tools: tool_execution_start → tool_call → tool_execution_update
            → tool_result → tool_execution_end
   → turn_end]
→ agent_end → recovery/queued work if needed
→ agent_before_settle → agent_settled (no automatic continuation left)
```

Session replacement (`/new`, `/resume`, `/fork`, `/clone`):
`session_before_switch|session_before_fork` (can cancel) → `session_shutdown`
→ extensions reloaded/rebound → `session_start { reason, previousSessionFile }`.

Others: `session_before_compact`/`session_compact`, `session_before_tree`/`session_tree`,
`model_select`, `thinking_level_select`, `session_info_changed`, `user_bash`.
Exit fires `session_shutdown`.

Provider hooks cover `before_provider_request` (payload),
`before_provider_headers` (headers), and `after_provider_response` (status and
headers before consuming the body). Do not assume one cross-provider ordering
between payload and header assembly. Parsed stream events are observations,
not original HTTP bytes, and need not map one-to-one to message updates.

Auto-compaction may run after a tool batch and before the next
assistant response in the same active run. The normal
`session_before_compact` → `session_compact|session_compact_failed` lifecycle
still wraps it.

Parallel tool mode (default): `tool_execution_start` in source order,
`tool_result`/`tool_execution_end` in completion order, final toolResult
messages later in source order. `tool_call` handlers may not see sibling tool
results from the same assistant message. `tool_execution_end.durationMs` is
optional: monotonic `execute()` time, absent when the tool did not run. Final
tool-result messages persist the duration; do not measure from event timestamps.

## Event return contracts

Most handlers can return `undefined` for no change; `project_trust` requires
a decision. Handlers run in extension load/registration order; several chain
like middleware. `pi.on()` returns an unsubscribe function. Changes to
subscriptions during a dispatch affect later dispatches only.

| Event | Return | Notes |
|---|---|---|
| `project_trust` | `{ trusted: "yes"\|"no"\|"undecided", remember? }` | Required. First yes/no wins and suppresses built-in prompt. |
| `input` | `{ action: "continue" }` / `{ action: "transform", text, images? }` / `{ action: "handled" }` | Transforms chain; first `handled` wins. `event.source`: `"interactive"\|"rpc"\|"extension"`. `event.streamingBehavior`: `undefined\|"steer"\|"followUp"`. |
| `before_agent_start` | `{ message?, systemPrompt? }` | Mutate `event.systemPromptOptions` for structured updates. `systemPrompt` forces a complete prompt; later handlers see it. `message` persists in context. |
| `context` | `{ messages? }` | Conversation only, without system messages; Pi restores prompt/tool state afterward. |
| `context_with_system` | `{ messages? }` | Full request transcript after `context`; sent as returned. Preserve a leading system message and tool state. |
| `turn_end` / `agent_before_settle` | `{ entries?, continue? }` | Actionable boundaries; preserve earlier drafts and guard continuation. |
| `cache_warming_decision` | `{ action: "warm"\|"stop" }` | Idle cache warming override; last returned action wins. |
| `before_provider_headers` | none | Mutate `event.headers` in place; `null` deletes a header. Fires once per request (not per retry). |
| `before_provider_request` | replacement payload or `undefined` | Payload-level; not reflected in `ctx.getSystemPrompt()`. |
| `message_end` | `{ message }` | Replacement must keep the same `role`. |
| `tool_call` | `{ block: true, reason?, terminate? }` | `event.input` is mutable — mutate in place to patch args; no re-validation. Narrow built-ins with `isToolCallEventType("bash", event)`; custom tools with explicit type params: `isToolCallEventType<"my_tool", MyToolInput>("my_tool", event)` (export the input type from the defining extension). Handler errors block the tool (fail-safe). `terminate` applies only to a blocked call and skips the follow-up model call only when every finalized result in the batch terminates — see [tools.md](tools.md#execute-contract). |
| `tool_result` | `{ content?, structuredContent?, details?, isError?, usage? }` | Partial patches chain. Replacing `content` alone drops `structuredContent`; return both to preserve it. Typed guards: `isBashToolResult(event)` etc. |
| `session_before_switch` / `session_before_fork` | `{ cancel: true }` | |
| `session_before_compact` | `{ cancel: true }` or `{ compaction: { summary, firstKeptEntryId, tokensBefore, details?, usage? } }` | `event.reason`: `"manual"\|"threshold"\|"overflow"`. |
| `session_before_tree` | `{ cancel: true }` or `{ summary: { summary, details?, usage? } }` | `usage` is included in session totals. |
| `user_bash` | `{ operations }` or `{ result }` | First defined result stops propagation. Errors/invalid defined results block local execution. Wrap `createLocalBashOperations()` to modify commands. |
| `resources_discover` | `{ skillPaths?, promptPaths?, themePaths? }` | |

Notification-only (returns ignored): `agent_start`, `agent_end`,
`agent_settled`, `ui_prompt_start`, `ui_prompt_end`, `turn_start`,
`message_start`, `message_update`, `tool_execution_*`, `session_start`,
`session_shutdown`, `session_compact`, `session_compact_failed`, `session_tree`,
`model_select`, `thinking_level_select`, `session_info_changed`,
`after_provider_response`, `provider_stream_event`, `mcp_servers_change`.

Treat `provider_stream_event.data` as read-only. Handlers are awaited in
stream order, so keep them fast; capture sensitive data only with explicit
opt-in, never in ordinary logs.

`agent_end` may still be followed by auto-retry, auto-compaction + retry, or
queued follow-up messages. For "agent is truly done" status integrations use
`agent_settled`: `ctx.isIdle()` is true there unless another extension started
a new run. Runs requested by settled handlers are deferred until the entire
settled notification dispatch finishes. `event.aborted` is true when the run
ended through cancellation; false also covers unrecovered errors, so inspect
the final assistant message before reporting success.

Aborting a run always ends it with a synthetic assistant message that
`message_start`/`message_end` report and pi persists, but its shape depends on
where the abort lands. Aborting an open provider stream yields
`stopReason: "aborted"`; aborting before the stream opens (e.g. from
`turn_start`) yields `stopReason: "error"` with
`errorMessage: "This operation was aborted"` on Pi 1.1.0, because auth
resolution honors the request signal and fails during stream setup. An
extension that hides its own aborted run must rewrite both shapes in
`message_end`, matched against a run it owns — never against message text —
and an unsanitized `error` shape additionally feeds pi's auto-retry check.

## Prompt and context state

Prefer structured additions in `before_agent_start`:

```typescript
pi.on("before_agent_start", (event) => {
	event.systemPromptOptions.sections.my_extension = "Extension instructions.";
});
```

The normalized options also expose `selectedTools`, `toolSnippets`,
`toolGuidelines`, `promptGuidelines`, `appendSystemPrompt`, `contextFiles`, and
`skills`. Mutations chain; do not replace another extension's additions.
Use `pi.setActiveTools()` to change actual declarations, not just prompt text.

Pi persists the initial prompt/tool loadout in a system message and later
changes as section/tool deltas. Returning `systemPrompt` (or setting
`forceSystemPrompt`) is an opaque override for the run's leading provider
prompt, while structured state still tracks sections. Use it only when full
replacement is intentional. Providers without mid-conversation system support
receive a collapsed checkpoint, which can invalidate cached prefixes.

`context` and `context_with_system` change one request, not stored history.
For durable context-only omissions/replacements, append a `context_edit` draft
at a boundary. `replacement: null` omits the target; non-null content replaces
its model-visible content. Raw history, UI, exports, and usage remain unchanged.
This is not deletion or redaction of stored data.

`SessionManager` is canonical for finalized context. `getEntries()` is raw
history, `getBranch()` selects the active path, and `buildSessionProjection()`
applies compaction/context edits. In SDK code, assigning
`session.agent.state.messages` does not replace future requests; restore
through a session manager, or append and call `session.refreshContext()`.
Read `docs/session-format.md` before manipulating persisted shapes.

## Actionable boundaries

`turn_end` and `agent_before_settle` receive `entries`, `continue`, `outcome`
(`completed`, `aborted`, `error`), and a `context` preview with
`contextEntries`, `contextMessages`, `llmMessages`, `pendingMessages`, and
`canContinue`. `turn_end` also provides `messageEntryId` and
`toolResultEntryIds` for durable edits.

Return `{ entries: [...event.entries, draft], continue: true }` only under a
bounded condition and when `event.context.canContinue` permits it. Drafts can
be `custom`, `custom_message`, `context_edit`, or `compaction`; Pi validates
and appends them in order. A replacement `entries` array must retain earlier
handlers' drafts unless intentionally changing them. `continue: true` ensures
one next provider request, not a separate steering/follow-up queue. Never
request unconditional continuation or use it to revive aborted/error runs.
A compaction draft uses `firstKeptEntryId: null` to retain no earlier entries.

## UI prompt lifecycle

`ui_prompt_start` and `ui_prompt_end` bracket blocking
extension calls to `ctx.ui.select()`, `confirm()`, `input()`, `editor()`, and
`custom()`. Each event has `reason: "ui_prompt"`, a `kind` naming the method,
and an optional `title` (`custom` has none).

Nested or overlapping prompts are coalesced into one outer waiting span.
Handlers are best-effort and are not awaited before the prompt opens or closes,
so use these events for host/status reporting, not ordering-sensitive setup or
cleanup. Pi 1.1 reports working/blocked/done/error/idle through OSC 7501 itself;
ordinary status integrations should use the lifecycle events, not emit a
second protocol stream. Reports contain session names, dialog titles, or the
first error line, never prompts or model output. See
`docs/terminal-setup.md#program-status` for detection and `PI_PROGRAM_STATUS`.

## ExtensionContext (ctx)

Most handlers receive `ExtensionContext` as `ctx`. `project_trust` instead
receives `ProjectTrustContext`: only `cwd`, `mode`, `hasUI`, and
`ui.select`/`confirm`/`input`/`notify` are available. There is no session manager,
model registry, or agent abort signal at that point.

For `ExtensionContext`:

- `ctx.ui` — see [tui.md](tui.md)
- `ctx.mode` — `"tui" | "rpc" | "json" | "print"`; guard TUI-only features with `=== "tui"`
- `ctx.hasUI` — true in TUI and RPC; guard dialogs/notify
- `ctx.cwd` — working directory; combine with `CONFIG_DIR_NAME` for project config paths
- `ctx.isProjectTrusted()` — check before honoring project-local config
- `ctx.sessionManager` — read-only session state: `getEntries()`, `getBranch()`, `buildContextEntries()`, `getLeafId()`, `getLabel(id)`, `getSessionFile()`
- `ctx.modelRegistry` — authenticated model runtime facade: lookup, `stream()`/`streamSimple()`, `classify()`, `generateImages()`
- `ctx.model` / `ctx.thinkingLevel` — current selection, possibly a virtual model; assistant messages identify physical dispatch
- `ctx.scopedModels` — read-only session scope; empty means no scope restriction
- `ctx.signal` — active agent abort signal (defined during turn events, `undefined` when idle); pass to nested `fetch`/exec/model calls
- `ctx.isIdle()` / `ctx.abort()` / `ctx.hasPendingMessages()`
- `ctx.shutdown()` — graceful shutdown request (deferred until idle)
- `ctx.getContextUsage()` — `{ tokens: number | null, contextWindow: number, percent: number | null } | undefined`; `null` means unknown (e.g. after compaction), not zero
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

`newSession`, `fork`, `switchSession`, and `navigateTree` return
`{ cancelled: boolean }`; `reload()` returns void.

## ExtensionAPI (pi) methods

- `pi.on(event, handler)` → unsubscribe function
- `pi.registerTool(def)` — works at load time and later (e.g. in `session_start` or commands); no `/reload` needed. See [tools.md](tools.md).
- `pi.registerCommand(name, { description, handler, getArgumentCompletions? })` — handler `(args: string, ctx: ExtensionCommandContext)`. Duplicate names get `:1`, `:2` suffixes.
- `pi.registerShortcut(keyId, { description, handler })` — e.g. `"ctrl+shift+p"` or `Key.ctrlAlt("p")`
- `pi.registerFlag(name, { description, type, default })` / `pi.getFlag(name)`
- `pi.sendMessage({ customType, content, display, details? }, { deliverAs?: "steer"|"followUp"|"nextTurn", triggerTurn? })` — custom message, participates in LLM context.
  A message sent with `triggerTurn: false` during a run is
  appended only after that turn's tool-result messages; do not expect immediate
  session insertion.
- `pi.sendUserMessage(content, { deliverAs?, expandPromptTemplates? })` — triggers a turn; `deliverAs` required while streaming. Command/skill/template expansion defaults to **false**; set `expandPromptTemplates: true` to dispatch a slash command.
- `pi.appendEntry(customType, data?)` — persisted, NOT in LLM context; render in the transcript with `pi.registerEntryRenderer(customType, (entry, { expanded }, theme) => Component)`
- `pi.registerMessageRenderer(customType, renderer)` — TUI renderer for `sendMessage` messages
- `pi.registerToolRenderer((toolName, next) => renderers)` — rendering-only resolver, including unregistered tools; see [tools.md](tools.md#rendering)
- `pi.registerMarkdownTransformer(transformer)` — display-only Markdown transform; context includes message type, streaming state, available width
- `pi.setSessionName(name)` / `pi.getSessionName()` / `pi.setLabel(entryId, label)`
- `pi.exec(cmd, args, { signal?, timeout? })` → `{ stdout, stderr, code, killed }`
- `pi.getActiveTools()` / `pi.getAllTools()` / `pi.setActiveTools(names)` — enable/disable tools at runtime (built-in and custom)
- `await pi.setModel(model)` → `boolean`; `false` means provider authentication is not configured. This changes the session selection, not the startup default.
- `pi.getThinkingLevel()` / `pi.setThinkingLevel(level)` (`"off"` through `"max"`); the setter clamps to model capabilities and does not change the startup default.
- `pi.getCommands()` — commands invokable via prompt, with `sourceInfo` provenance
- `pi.getSettings()` — copy of effective merged settings, not a write API
- `pi.events` — shared bus for inter-extension communication (`on`/`emit`)
- `pi.registerProvider(provider)` / `pi.registerProvider(name, config)` / `pi.unregisterProvider(name)`
- `pi.registerVirtualModel(def)` / `pi.unregisterVirtualModel(provider, id)`
- `pi.registerMcpServer(name, config)` / `pi.unregisterMcpServer(name)` / `pi.getMcpServers()`

## State management pattern

```typescript
export default function (pi: ExtensionAPI) {
	let items: Todo[] = [];

	/** Rebuild the active branch snapshot; last matching result wins. */
	function restoreState(ctx: ExtensionContext): void {
		items = [];
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "message" && entry.message.role === "toolResult"
				&& entry.message.toolName === "todo") {
				items = entry.message.details?.todos ?? [];
			}
		}
	}
	pi.on("session_start", (_event, ctx) => restoreState(ctx));
	pi.on("session_tree", (_event, ctx) => restoreState(ctx));

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

Two registration forms are available:

```typescript
import { type Api, createProvider } from "@earendil-works/pi-ai";
import { openAICompletionsApi } from "@earendil-works/pi-ai/api/openai-completions.lazy";

// Native provider: prefer for custom auth, model filtering/refresh, or streaming.
pi.registerProvider(createProvider<Api>({
	id: "local-server",
	name: "Local Server",
	baseUrl: "http://localhost:8080/v1",
	auth: {
		apiKey: {
			name: "Local server API key",
			async login(interaction) {
				return {
					type: "api_key",
					key: await interaction.prompt({ type: "secret", message: "API key" }),
				};
			},
			async resolve({ credential }) {
				return credential?.key
					? { auth: { apiKey: credential.key }, source: "stored API key" }
					: undefined;
			},
		},
	},
	models: [],
	api: openAICompletionsApi(),
}));

// Legacy config: concise proxies, static model lists, and simple OAuth/stream hooks.
pi.registerProvider("my-proxy", {
	baseUrl: "https://proxy.example.com",
	apiKey: "$PROXY_API_KEY",
	api: "openai-completions",
	models: [],
	async refreshModels({ signal }) {
		signal?.throwIfAborted();
		return [];
	},
});
```

A complete pi-ai `Provider` exposes native `auth`, `getModels`,
`refreshModels`, `filterModels`, `stream`, and `streamSimple`; `createProvider`
builds one from `auth`, `models`, `fetchModels`, `filterModels`, and `api`.
`models.json` overrides compose above it. The legacy config also supports
`name`, `headers`, `authHeader`, `oauth`, `streamSimple`, and `refreshModels`.
Use the refresh
callback's scoped `context.store` only when a discovered catalog should
persist.

`apiKey` supports `$ENV_VAR` and `!command`. Factory-time registrations are
queued and flushed at startup; later calls apply immediately. For one-time
remote discovery use an async factory so models exist for `pi --list-models`.
See `docs/custom-provider.md` and the `custom-provider-*` examples for complete
auth, refresh, and streaming implementations.

Custom streams receive `TranscriptContext`: read prompt/tools with
`getCurrentSystemPrompt(context.messages)` and `getCurrentTools(...)` from
pi-ai, not `context.systemPrompt`/`context.tools`. Use
`collapseSystemMessages(context)` if the endpoint needs a leading checkpoint.
Forward cancellation and instrumentation (`onPayload`, `onResponse`,
`onProviderStreamEvent`); honor a replacement payload from `onPayload`.

Provider model lists can include `type: "chat" | "image" | "classifier"`
(omitted type means chat). A legacy `models` list replaces the whole provider
catalog across all operations. Supply `images`/`classifiers` implementations
keyed by API for non-chat entries; omitting `models` preserves built-in ones.
Native refresh publishes via `context.publish({ update })` and returns void;
legacy `refreshModels` returns model definitions. Do not mix these contracts.

Use current provider IDs: Azure is `azure` since Pi 1.0.3, while the Responses
API ID remains `azure-openai-responses`. Model
`samplingParamsByThinkingLevel` overrides use Pi levels (`off` through `max`);
Pi clamps the level, then merges model defaults, per-level overrides, and
request parameters. Only OpenAI Completions/Responses and Azure Responses
honor these overrides; see `docs/models.md` and `docs/providers.md`.

## Virtual models and non-chat models

`pi.registerVirtualModel({ provider, id, name, thinkingLevels?, route })`
creates a selectable model. `route(request, ctx)` returns a physical
`{ model, thinkingLevel, state? }`; routing to another virtual model is invalid.
Request reasons: `user`, `continuation`, `retry`, `direct`. Read the full
contract in `docs/virtual-models.md` and adapt `examples/extensions/jev-router.ts`.

- Use `request.previous` for sticky continuations and `request.failed` for
  retries when appropriate; switching physical models can lose prompt caches.
- Propagate `request.signal` during routing. Look up physical models through
  `ctx.modelRegistry` and check for absence/credentials.
- Router `state` must be JSON-serializable; new objects persist on the branch
  before dispatch. Reuse `request.state` or return no state when unchanged.
  Direct requests have no persistent router state.
- Removing a provider does not unregister its virtual models.

For classifiers/images, use `ctx.modelRegistry.findOfType(type, provider, id)`
or `getAvailableOfType(type)`, then `classify()` or `generateImages()` with a
signal. Check `stopReason`/`errorMessage`; provider errors can be returned as
results. In a tool, report the call's usage in the tool result. Do not assume
an arbitrary extension model call is automatically included in session totals.
Chat selection APIs still list chat models only.

Classifier context accepts `{ state, questions, images? }`; images are base64
`ImageContent` blocks and require `model.input.includes("image")`. Unsupported
image input returns an error result. Find available classifier models instead
of assuming an ID or credential works for every operation: OpenAI's
`gpt-6-luna` needs API-key auth, not ChatGPT OAuth. llama.cpp 0.6.0+ native
decision models appear only as classifiers, not chat models. See
`docs/models.md`, `docs/llama-cpp.md`, and `docs/codemode.md` for contracts.

## MCP servers

`pi.registerMcpServer(name, config)` uses the `mcp.json` entry shape from
`docs/mcp.md`: stdio (`command`, `args`, `env`, `cwd`) or streamable HTTP
(`url`, `headers`, `oauth`, provider `auth`), plus exposure and metadata.

Factory registrations connect on `session_start`; later ones connect right
away. They are session-local, not saved. File configuration overrides an
extension registration with the same name. A project `mcp.json` entry without
`command`, `url`, or `type` can override only a user-level server's `enabled`,
`exposure`, and `toolExposure`, retaining its connection/auth configuration. Re-registering replaces your own
registration; names owned by another extension and invalid configs throw.
`unregisterMcpServer()` disconnects and makes its tools unreachable.

The built-in MCP extension handles connections. If another extension replaces
it, registrations need a handler: a connector reads `getMcpServers()` at
startup and subscribes to `mcp_servers_change`. Do not start a second connector
merely to register servers.

MCP server exposure `codemode` defaults to tools discoverable through scripts,
not inline tool declarations (unlike an extension tool's `codemode` exposure).
`direct` declares tools, `deferred` enables tool-search loading, and `hidden`
withdraws them; `toolExposure` overrides individual tools. Tool names normalize
to `mcp__<server>__<tool>` with invalid identifier characters replaced by `_`.
Permission hooks also run for these tools, including nested codemode calls.
Use built-in OAuth/provider auth rather than persisting tokens in extension
settings. `oauth.clientRegistration: "cimd"` uses Pi's Client ID Metadata
Document instead of dynamic registration; it requires server support and
cannot be combined with `clientId` or `clientName`. OAuth sign-in is abortable
at every step and session shutdown cancels it. `pi mcp login --timeout` bounds
the whole sign-in, including authorization-server requests. Consult
`docs/mcp.md` for trusted origins, redirects, and scope rules.

## SDK embedding

When embedding pi via the SDK (`main()` / test harnesses), `extensionFactories`
accepts factories or named `{ name, factory, replaceable?, builtin? }` entries.
Named entries improve diagnostics; `replaceable` yields to extensions with
conflicting registrations. `builtin: true` supplies a configurable
`builtin:<name>` extension, disabled by `noExtensions` unless explicitly loaded.

SDK sessions do not load the CLI's built-in extensions automatically. Add
`createCodemodeExtension()`, `createToolSearchExtension()`, and
`createMcpExtension()` through `DefaultResourceLoader` as needed, activate tools
through settings, and call `session.bindExtensions()` for startup hooks.
Read `docs/sdk.md` and `examples/sdk/14-codemode-mcp.ts` for the complete setup.

## Mode behavior

| Mode | `ctx.mode` | `ctx.hasUI` | Notes |
|---|---|---|---|
| Interactive | `"tui"` | `true` | full TUI |
| RPC | `"rpc"` | `true` | dialogs via JSON protocol; `custom()` returns `undefined` |
| JSON | `"json"` | `false` | UI methods no-op |
| Print (`-p`) | `"print"` | `false` | can't prompt |
