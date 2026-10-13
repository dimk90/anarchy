# Custom Tools Reference

Verified against Pi 1.1.0. Exact types: coding-agent's
`dist/core/extensions/types.d.ts` and agent-core's `dist/types.d.ts`.

## Contents

- [Tool definition](#tool-definition)
- [Schema rules](#schema-rules)
- [Execute contract](#execute-contract)
- [Tool exposure and codemode](#tool-exposure-and-codemode)
- [Nested tool calls](#nested-tool-calls)
- [Prompt integration](#prompt-integration)
- [Output truncation](#output-truncation)
- [File mutation queue](#file-mutation-queue)
- [Schema evolution (prepareArguments)](#schema-evolution-preparearguments)
- [Dynamic tool loading](#dynamic-tool-loading)
- [Overriding built-in tools](#overriding-built-in-tools)
- [Rendering](#rendering)

## Tool definition

```typescript
import { StringEnum } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { type Static, Type } from "typebox";

const todoSchema = Type.Object({
	action: StringEnum(["list", "add", "toggle"] as const),
	text: Type.Optional(Type.String({ description: "Todo text (for add)" })),
	id: Type.Optional(Type.Number({ description: "Todo ID (for toggle)" })),
});
export type TodoInput = Static<typeof todoSchema>;  // export for tool_call narrowing

interface TodoDetails { todos: Todo[]; nextId: number }

const todoTool = defineTool({
	name: "todo",
	label: "Todo",
	description: "Manage the project todo list",       // shown to the LLM
	promptSnippet: "List, add, or toggle todo items",   // one-liner in Available tools
	promptGuidelines: ["Use todo for task planning instead of file edits."],
	parameters: todoSchema,
	async execute(toolCallId, params, signal, onUpdate, ctx) {
		onUpdate?.({ content: [{ type: "text", text: "Working..." }], details: { todos, nextId } });
		return {
			content: [{ type: "text", text: "Done" }],  // sent to LLM
			details: { todos, nextId },                  // rendering + state reconstruction
			// usage: nestedModelUsage,                 // nested LLM usage, if any
		};
	},
});

export default function (pi: ExtensionAPI) {
	pi.registerTool(todoTool);
}
```

Use `defineTool()` when assigning to a variable or passing through arrays —
it preserves parameter type inference. Inline `pi.registerTool({...})` is fine
too.

Optional definition fields: `executionMode: "sequential"` (this tool never runs
concurrently with other tool calls — use for tools with shared mutable
resources), `renderShell: "self"`, `prepareArguments`, `outputSchema`,
`exposure`, `namespace`, `annotations`, `defaultActive`, `prepareLoadout`, and
`constrainedSampling`. Use only provider-supported constrained sampling;
`false` disables a built-in tool's default strict-prefer request.

## Schema rules

- Schemas are TypeBox (`typebox`); derive the TS type via `Static<typeof schema>`.
- **Pi 1.1.0 ships typebox 1.3.27.** The 1.3 migration removed `Type.Base`, `Type.Awaited`,
  `Type.Promise`, `Type.AsyncIterator`, `Type.Iterator`, `Type.Options`, and
  `Value.Mutate`. Replace `Type.Base` subclasses with
  `Type.Refine(Type.Unsafe<T>({...}), check, message)`, model promises and
  iterators structurally (a promise is an object with `then`), use the `with`
  keyword instead of `Options` in `Type.Script`, and keep mutation helpers in
  your own code. Tool parameters need none of the removed types.
- **String enums must use `StringEnum([...] as const)` from `@earendil-works/pi-ai`.**
  `Type.Union([Type.Literal(...)])` breaks Google's API.
- Add `{ description }` to every parameter — the LLM reads them.
- If a parameter is a path, strip a leading `@` before resolving (some models
  include it) and resolve relative to `ctx.cwd`.

## Execute contract

Signature: `execute(toolCallId, params, signal, onUpdate, ctx)`.

- Return `content` and `details` (`details: undefined` when unused). Keep
  persisted args/details JSON-compatible — not classes, maps, or live objects.
- **Errors:** throw for an ordinary failure, or return `isError: true` when a
  failure must retain data. Returning an object alone does not mark failure.
- With `outputSchema`, return matching `structuredContent`. The model receives
  `content`; codemode callers receive the structured value. Without an output
  schema, scripts receive text. Structured error results remain available to
  scripts instead of becoming thrown failures.
- Check `signal?.aborted` at the top and between long steps; pass `signal` to
  `pi.exec`, `fetch`, etc.
- `onUpdate?.({ content, details? })` streams partial results to the TUI
  (`isPartial` in the renderer).
- Return `usage` for model work performed by this tool. Pi persists it and
  includes it in footer, `/session`, and RPC totals. Usage from tools called
  through `ctx.executeTool()` is aggregated automatically; do not count it
  again in the parent.
- `terminate: true` on the result hints skipping the follow-up LLM call; takes
  effect only when every tool result in the batch sets it (structured-output
  pattern). A `tool_call` handler can set the same hint while blocking
  (`{ block: true, terminate: true }`) so an all-blocked batch
  also stops without another model call.
- Tools run with `ExtensionToolContext` (no command-only session controls).
  Dispatch commands explicitly:
  `pi.sendUserMessage("/cmd", { deliverAs: "followUp", expandPromptTemplates: true })`.
  Without expansion, `/cmd` is ordinary model input.

## Tool exposure and codemode

The active set controls model declarations, not every programmatic call:

| `exposure` | Declared to model | Callable through `ctx.executeTool()` |
|---|---|---|
| `direct` (default) | While active | While active |
| `model-only` | While active | Never |
| `codemode` | Only if explicitly activated | Whenever registered; eligible for inline codemode listing |
| `deferred` | Only if explicitly activated | Whenever registered; discoverable, not inline-listed |
| `hidden` | Never | Never |

Use `model-only` for interactive or orchestrating tools that should not run
inside scripts. Direct/model-only registrations activate by default;
`defaultActive: false` opts out. Other exposures never auto-activate.
Re-register with `hidden` to withdraw a tool; there is no unregister API.
Deactivating `codemode`/`deferred` tools is **not** access control.

`namespace: { name, description?, instructions? }` groups tools. Scripts can
read long instructions on demand with `describeNamespace()`.
`annotations` (`readOnlyHint`, `destructiveHint`, `idempotentHint`,
`openWorldHint`) are unverified hints, not enforcement. Missing hints have
conservative MCP defaults; permission checks belong in `tool_call`.

An active orchestrator can implement `prepareLoadout(loadout)`, receiving
`declared`, `callable`, `registered`, `getExposure()`, `getNamespace()`, and
`getPromptGuidelines()`. Return `descriptions` keyed by name and/or
`hiddenDeclarations`; hidden **declarations** remain active/callable, unlike
`exposure: "hidden"`. Pi omits hidden tools from system-prompt tool lists and
rules; present their guidelines in the orchestrator's tool descriptions instead.

The built-in codemode uses these APIs. Scripts run in QuickJS without Node,
filesystem, network, or timers; tools are their capability boundary. For script
globals and `models.classify()`/`models.generateImages()`, read
`docs/codemode.md`. Probe tools with `"name" in tools`, not
`typeof tools.name` (unknown property access throws).
`searchTools()`, `describeTool()`, and `describeNamespace()` are async; await
them before using their values. `tools.read()` returns an image block for
image files, which `image()` can show. `image()` also saves output to a temp
file; only forward images with the user's intended privacy behavior. Text,
image, and console output share hard limits (16 Mi characters / 100000 items),
and sandbox built-ins are frozen; do not patch prototypes.

## Nested tool calls

Inside `execute()`, use `ctx.executeTool(name, args, { signal, onUpdate })`
rather than directly calling another definition's `execute`. `ctx.tools`
lists callable tools. Nested calls pass validation and permission/result
hooks. `executeTool()` returns `AgentToolCallOutcome`; tool failures return
`isError: true` rather than rejecting. Inspect it before using the result.
This differs from the codemode JavaScript wrapper, which rejects ordinary
failed calls (but preserves structured error results).

All nested tool events carry `parentToolCallId`; Pi assigns IDs of the form
`<parent id>/<n>`. Do not assume every event has a corresponding assistant
call or transcript result. Nested results reach the caller only; report them
through the parent's content/details/updates when needed.

Pi stores bounded `nestedCalls` metadata on the parent's result: name, args,
status, duration, error, but never result bodies. Limits: 8 KiB of args per
call, 32 KiB per parent result, 256 calls; `complete: false` marks loss.
Nested usage aggregates at every depth. Redacting `tool_result.content` alone
drops `structuredContent`; return a sanitized structured value too when
programmatic consumers still need it.

## Prompt integration

- Without `promptSnippet`, custom tools are omitted from the system prompt's
  `Available tools` section (the LLM still sees `description` via tool defs).
- `promptGuidelines` bullets are appended flat to the `Guidelines` section with
  no tool prefix — each bullet must name the tool ("Use todo when...", never
  "Use this tool when...").

## Output truncation

Bound model-facing text; the standard helpers default to 50KB / 2000 lines,
whichever hits first (not an automatic limit for every custom tool):

```typescript
import {
	DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, formatSize,
	truncateHead,  // keep start (file reads, search results)
	truncateTail,  // keep end (logs, command output)
} from "@earendil-works/pi-coding-agent";

const t = truncateHead(output, { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES });
let text = t.content;
if (t.truncated) {
	text += `\n\n[Truncated: ${t.outputLines} of ${t.totalLines} lines. Full output: ${tempFile}]`;
}
```

Always tell the LLM output was truncated and where to find the rest (temp file,
offset parameter). Document limits in the tool description. Keep larger
structured results only when needed by programmatic callers and bound them
separately: Pi 1.1's bash/PowerShell structured output allows up to 1 MiB,
while model-facing output still uses the smaller limit. Output temp files
must be user-readable only, as Pi's built-in output files are. Do not persist
full sensitive output merely to implement truncation.

## File mutation queue

Tool calls run in parallel by default. Any tool that mutates files must wrap
the whole read-modify-write window in `withFileMutationQueue()` so it shares
the per-file queue with built-in `edit`/`write`:

```typescript
import { withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { resolve } from "node:path";

async execute(_id, params, _signal, _onUpdate, ctx) {
	const absolutePath = resolve(ctx.cwd, params.path);  // resolve BEFORE queueing
	return withFileMutationQueue(absolutePath, async () => {
		// read + modify + write, all inside the queue
	});
}
```

## Schema evolution (prepareArguments)

`prepareArguments(args)` runs before validation. Use it to map legacy stored
arguments onto the current schema. Keep the public schema strict — never add
deprecated fields to `parameters`. The declared return type is
`Static<TParams>`; validate/narrow the normalized object rather than returning
arbitrary `unknown`. For an edit-like tool whose `editSchema` is defined above:

```typescript
import * as Value from "typebox/value";

// Inside the tool definition
prepareArguments(args) {
	let normalized = args;
	if (args && typeof args === "object" && "oldText" in args && "newText" in args) {
		const { oldText, newText, ...rest } = args;
		if (typeof oldText === "string" && typeof newText === "string") {
			const edits = "edits" in rest && Array.isArray(rest.edits) ? rest.edits : [];
			normalized = { ...rest, edits: [...edits, { oldText, newText }] };
		}
	}
	if (!Value.Check(editSchema, normalized)) throw new Error("Invalid edit arguments");
	return normalized;
}
```

## Dynamic tool loading

Register all tools up front, keep a small loader/search tool active, and add
matching tools from that loader's `execute()`:

```typescript
const active = pi.getActiveTools();
const added = matches.filter((name) => !active.includes(name));
pi.setActiveTools([...new Set([...active, ...added])]);
```

The names must already be registered; unknown/hidden names are ignored.
Prefer `defaultActive: false` or `deferred` exposure for optional tools, and
keep activation additive during loader execution. Pi persists tool changes as
transcript system deltas before the next model request. Providers without
support receive a collapsed checkpoint, which can invalidate the cache prefix.
Anthropic defines added or redefined tools inline mid-conversation, preserving
the earlier prompt-cache prefix even when a tool keeps its name.

Keep the loader active. Optional tools should usually omit `promptSnippet`
and `promptGuidelines` to avoid additional prompt changes on activation.
Use built-in `tool_search` when it fits, and inspect `dynamic-tools.ts` for
runtime registration. Do not copy old examples that assume tool definitions
are stored only on loader result messages.

## Overriding built-in tools

For rendering-only changes, prefer `pi.registerToolRenderer()` (below): it
does not replace execution, schemas, exposure, or prompt metadata.
Register a tool with a built-in name (`read`, `bash`, `powershell`, `edit`,
`write`, `grep`, `find`, `ls`) to replace it. Registering `codemode`,
`tool_search`, or `/mcp` can replace an entire built-in extension; Pi warns
about this. Do not accidentally disable its integration.

- **Result shape must match exactly**, including `details` types
  (`ReadToolDetails`, `BashToolDetails`, ...) — UI and session logic depend on
  them. Read the built-in source in the package
  (`src/core/tools/*.ts` or dist types) before overriding.
- Rendering inherits per slot: omit `renderCall`/`renderResult` to keep the
  built-in rendering (diffs, syntax highlighting) while wrapping execution.
- `promptSnippet`/`promptGuidelines` are NOT inherited; retain the original
  values when wrapping. Preserve `outputSchema`/`structuredContent` too so
  codemode callers keep the original result contract.
- Wrapping pattern: `createReadTool(cwd, { operations })`,
  `createBashTool(cwd, { spawnHook, operations })` etc. accept pluggable
  operations (`ReadOperations`, `BashOperations`, ...) for remote/SSH/sandbox
  delegation; call the created tool's `execute` from your override.
- For `!` user commands, hook `user_bash` and wrap
  `createLocalBashOperations()` instead of reimplementing process spawning.

## Rendering

Optional `renderCall(args, theme, context)` and
`renderResult(result, { expanded, isPartial }, theme, context)` return a TUI
`Component`. Default fallback: tool name / raw content text.

`pi.registerToolRenderer((toolName, next) => renderers)` selects renderers
without registering or replacing a tool, including MCP calls restored before
their server connects. Resolvers run in extension load order. `next()` asks
the remaining resolvers, then the registered definition; return it for tools
you do not own. `next() ?? mine` fills in only when no later renderer exists;
spread `next()` when intentionally overriding just one slot. The returned
`ToolRenderers` has optional `renderShell`, `renderCall`, and `renderResult`.

```typescript
pi.registerToolRenderer((toolName, next) => {
	if (!toolName.startsWith("mcp__docs__")) return next();
	return next() ?? {
		renderCall(_args, theme) {
			return new Text(theme.fg("toolTitle", toolName), 0, 0);
		},
	};
});
```

`context` fields: `args`, `state` (shared across both slots), `lastComponent`,
`invalidate()`, `toolCallId`, `cwd`, `executionStarted`, `argsComplete`,
`isPartial`, `expanded`, `showImages`, `isError`, `durationMs`, `outputPad`.
`durationMs` is recorded monotonic execution time, not live elapsed time;
it is `undefined` while running, for calls that did not execute, and for old
stored results. Pi supplies it from the final result on resume too. Read
`context.durationMs` rather than expecting timing in the renderer's result
argument. `tool_execution_end.durationMs` exposes the same execution timing.

Best practices:

- Use `new Text(str, 0, 0)` (zero padding) — the default Box shell applies
  `context.outputPad` (0 or 1). Self-rendered shells must apply it themselves.
- Reuse `context.lastComponent` and update in place:
  `const text = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0); text.setText(...); return text;`
- Handle `isPartial` (streaming) and `expanded` (detail on demand); keep the
  collapsed view to one line.
- Read args via `context.args` in `renderResult`; use `context.state` only for
  data genuinely shared across slots.
- Keybinding hints: `keyHint("app.tools.expand", "to expand")` /
  `keyText(id)` from `@earendil-works/pi-coding-agent` — never hardcode keys.
- `renderShell: "self"` only when the default boxed shell gets in the way; you
  then own framing, padding, and background. Test both `outputPad` values so
  tool output aligns with messages, `!` output, and summary blocks.

See [tui.md](tui.md) for components and theming.
