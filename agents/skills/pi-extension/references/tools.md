# Custom Tools Reference

## Contents

- [Tool definition](#tool-definition)
- [Schema rules](#schema-rules)
- [Execute contract](#execute-contract)
- [Prompt integration](#prompt-integration)
- [Output truncation](#output-truncation)
- [File mutation queue](#file-mutation-queue)
- [Schema evolution (prepareArguments)](#schema-evolution-preparearguments)
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
		onUpdate?.({ content: [{ type: "text", text: "Working..." }] });  // streaming progress
		return {
			content: [{ type: "text", text: "Done" }],  // sent to LLM
			details: { todos, nextId },                  // for rendering + state reconstruction
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
resources), `renderShell: "self"`, `prepareArguments`.

## Schema rules

- Schemas are TypeBox (`typebox`); derive the TS type via `Static<typeof schema>`.
- **String enums must use `StringEnum([...] as const)` from `@earendil-works/pi-ai`.**
  `Type.Union([Type.Literal(...)])` breaks Google's API.
- Add `{ description }` to every parameter — the LLM reads them.
- If a parameter is a path, strip a leading `@` before resolving (some models
  include it) and resolve relative to `ctx.cwd`.

## Execute contract

Signature: `execute(toolCallId, params, signal, onUpdate, ctx)`.

- **Errors: throw.** A thrown error sets `isError: true` and is reported to the
  LLM; returning any value never marks an error.
- Check `signal?.aborted` at the top and between long steps; pass `signal` to
  `pi.exec`, `fetch`, etc.
- `onUpdate?.({ content, details? })` streams partial results to the TUI
  (`isPartial` in the renderer).
- `terminate: true` on the result hints skipping the follow-up LLM call; takes
  effect only when every tool result in the batch sets it (structured-output
  pattern).
- Tools run with `ExtensionContext` (no session-control methods). To trigger a
  command from a tool, queue it: `pi.sendUserMessage("/cmd", { deliverAs: "followUp" })`.

## Prompt integration

- Without `promptSnippet`, custom tools are omitted from the system prompt's
  `Available tools` section (the LLM still sees `description` via tool defs).
- `promptGuidelines` bullets are appended flat to the `Guidelines` section with
  no tool prefix — each bullet must name the tool ("Use todo when...", never
  "Use this tool when...").

## Output truncation

Tools MUST truncate output (limit: 50KB / 2000 lines, whichever hits first):

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
offset parameter). Document limits in the tool description.

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
arguments (from resumed old sessions) onto the current schema. Keep the public
schema strict — never add deprecated fields to `parameters`:

```typescript
prepareArguments(args) {
	if (!args || typeof args !== "object") return args;
	const input = args as { edits?: Edit[]; oldText?: unknown; newText?: unknown };
	if (typeof input.oldText !== "string" || typeof input.newText !== "string") return args;
	return { ...input, edits: [...(input.edits ?? []), { oldText: input.oldText, newText: input.newText }] };
}
```

## Overriding built-in tools

Register a tool with a built-in name (`read`, `bash`, `edit`, `write`, `grep`,
`find`, `ls`) to replace it.

- **Result shape must match exactly**, including `details` types
  (`ReadToolDetails`, `BashToolDetails`, ...) — UI and session logic depend on
  them. Read the built-in source in the package
  (`src/core/tools/*.ts` or dist types) before overriding.
- Rendering inherits per slot: omit `renderCall`/`renderResult` to keep the
  built-in rendering (diffs, syntax highlighting) while wrapping execution.
- `promptSnippet`/`promptGuidelines` are NOT inherited; redefine if needed.
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

`context` fields: `args`, `state` (shared across both slots), `lastComponent`,
`invalidate()`, `toolCallId`, `cwd`, `executionStarted`, `argsComplete`,
`isPartial`, `expanded`, `showImages`, `isError`.

Best practices:

- Use `new Text(str, 0, 0)` (zero padding) — the default Box shell pads.
- Reuse `context.lastComponent` and update in place:
  `const text = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0); text.setText(...); return text;`
- Handle `isPartial` (streaming) and `expanded` (detail on demand); keep the
  collapsed view to one line.
- Read args via `context.args` in `renderResult`; use `context.state` only for
  data genuinely shared across slots.
- Keybinding hints: `keyHint("app.tools.expand", "to expand")` /
  `keyText(id)` from `@earendil-works/pi-coding-agent` — never hardcode keys.
- `renderShell: "self"` only when the default boxed shell gets in the way; you
  then own framing, padding, and background.

See [tui.md](tui.md) for components and theming.
