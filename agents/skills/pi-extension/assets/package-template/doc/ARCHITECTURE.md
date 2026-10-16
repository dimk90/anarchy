# Architecture

How `{{package}}` hooks into Pi, and the rules that changes must preserve. This
file holds the overview, the lifecycle, the module boundaries, state, and the
required invariants.

<!--
When a section outgrows this file, move it to doc/architecture/<topic>.md and
list the page here:

| Document                                           | Covers              |
| -------------------------------------------------- | ------------------- |
| [architecture/topic.md](architecture/topic.md)     | {{what it covers}}  |
-->

## Lifecycle

{{Describe the lifecycle the extension depends on, as an event flow. Name the
event where each fact becomes observable and why an earlier event is not
enough — that is the knowledge that is expensive to rediscover. Delete the
rows that do not apply.}}

```text
session_start/session_tree   → {{rehydrate active-branch state}}
before_agent_start           → {{add structured prompt sections}}
context                      → {{transform conversation without system messages}}
context_with_system          → {{inspect/transform full request including system state}}
message_end                  → {{patch only the messages this extension owns}}
turn_end/agent_before_settle → {{append context edits or request bounded continuation}}
agent_settled                → {{restore UI, resolve pending work}}
session_shutdown             → {{release resources; idempotent}}
```

## Module Boundaries

| Path                | Responsibility                                                       |
| ------------------- | -------------------------------------------------------------------- |
| `src/index.ts`      | Factory: register commands and handlers, hold closure state, guards. |
| `src/command.ts`    | Parse `/{{command}}` arguments and offer completions.                |
| `src/pi-version.ts` | Check the running Pi version against the oldest supported release.   |

## State

{{Which state lives in the factory closure, how it is persisted
(`pi.appendEntry("{{package}}:...", ...)` or tool result `details`), and how
it is rebuilt from `getBranch()` in `session_start` and `session_tree` so
resume, reload, fork, and tree navigation follow the active branch.}}

## Privacy

{{If the extension can observe prompts, messages, or files: state that raw
content stays process-local and terminal-sanitized, is shown only on explicit
user action, and is never logged, persisted again, or injected into later
requests. Delete this section when the extension observes nothing sensitive.}}

## Required Invariants

- Normal turns are unchanged when the extension is not invoked.
- On a Pi version older than `MIN_PI_VERSION`, no lifecycle handler is
  registered.
- {{Extension-specific invariant.}}
