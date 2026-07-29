# {{package}}

{{One paragraph: what the extension does, which commands/tools/flags it adds,
and which modes it supports.}}

- `/{{command}}` — {{what it opens or does}}.

{{State explicitly what is out of scope or roadmap-only, and link to
[doc/PLAN.md](doc/PLAN.md).}}

## Architecture

{{Describe the lifecycle the extension depends on, as an event flow. Name the
event where each fact becomes observable and why an earlier event is not
enough — that is the knowledge that is expensive to rediscover.}}

```text
session_start      → {{rehydrate persisted state}}
before_agent_start → {{own the prompt options / extend the prompt}}
context            → {{read the final prompt and active tools}}
message_end        → {{patch only the messages this extension owns}}
agent_settled      → {{restore UI, resolve pending work}}
```

{{Document per subsystem: what is captured or computed, what is owned versus
borrowed, and which invariants must hold. Keep semantics in typed model
fields; never recover meaning from display labels.}}

## State

{{Which state lives in the factory closure, how it is persisted
(`pi.appendEntry("{{package}}:...", ...)` or tool result `details`), and how it
is rebuilt in `session_start` so resume, reload, and fork behave identically.
Namespace every custom type and status key with the package name.}}

## Privacy

{{If the extension can observe prompts, messages, or files: state that raw
content stays process-local and terminal-sanitized, is shown only on explicit
user action, and is never logged, persisted again, or injected into later
requests. Delete this section when the extension observes nothing sensitive.}}

## UI

[doc/UI.md](doc/UI.md) is the canonical specification for rendering,
interaction, responsive behavior, previews, and release media. {{Delete this
section and the file for headless extensions.}}

## Verification

Run `pnpm check`. Follow the `pi-extension` skill for provider smoke tests and
real-PTY testing. Lifecycle coverage must load `test/fixtures/marker.ts` in
both load orders {{and use an `after_provider_response` sentinel when zero
provider calls is an invariant}}.

Required invariants:

- normal turns are unchanged when the extension is not invoked;
- {{extension-specific invariant}};
- {{extension-specific invariant}};
- every rendered line respects width, and views reflow with width and height.

## Dependencies

Keep `@earendil-works/pi-coding-agent` and `@earendil-works/pi-tui` as `"*"`
peer dependencies and exact development pins matching `pi --version`. Run
`pnpm install` after changing the pins.
