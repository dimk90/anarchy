# {{package}}

TypeScript pi extension (`src/index.ts`) that {{one-line purpose}}:

- `/{{command}}` or `/{{command}} {{arg-a}}` — {{what it opens or does}}.
- `/{{command}} {{arg-b}}` — {{what it opens or does}}.

{{State the supported run modes, e.g. "Views are unavailable outside TUI mode."}}

## Sources of truth

| Path                  | Read before                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------- |
| `doc/ARCHITECTURE.md` | Changing lifecycle handlers, state, persisted shapes, or privacy behavior.                           |
| `doc/RELEASE.md`      | Changing versions, tagging, publishing, or preparing a release; `scripts/release.sh` automates it.   |

## Repository rules

- **Architecture contract.** Preserve the invariants in `doc/ARCHITECTURE.md`; update it with any lifecycle, state, or persisted-shape change.
- **Module boundaries.** Keep `src/index.ts` to wiring: register commands and handlers and hold closure state. Put independently testable parsing, state, and rendering in focused modules under `src/` and `src/ui/`.
- **Persisted shapes.** Session files keep old entry `data` and tool `details`; keep reading old shapes when changing them.
- **Command contract.** Keep parsing, completions, registration text, README usage, and command tests synchronized whenever the `/{{command}}` grammar changes.
- **Changelog headings.** Write version headings as `## [X.Y.Z] - DD.MM.YYYY`, without a `v` prefix, so Pi can parse them.
- **Changelog entries.** Keep the text of each `CHANGELOG.md` bullet, after its `[scope]` tag, to about 80 characters.
- **Dependency contract.** Declare only the Pi packages (`pi-coding-agent`, `pi-tui`, `pi-ai`, `pi-agent-core`) the code imports, each as a `"*"` peer dependency with an exact development pin matching `pi --version`; run `pnpm install` after changing any pin.

## Verification

```bash
pnpm check
```

- **Shared test process.** `pnpm test` (`test/run.ts`) runs every test file concurrently in one process: no top-level hooks, no observable process-wide state changes, and no mocks that change a shared static method's behavior. Use `test/harness/settings.ts` for Pi settings.
- **Runtime tests.** Use `test/harness/runtime.ts`: the pinned Pi runs in process against the mock provider in `test/harness/mock-provider.ts`. Never call a real model unless explicitly requested.
- **Context footprint.** `test/runtime.test.ts` proves a normal turn sends the same provider request with and without the extension; drop it only if the extension always changes requests.
- **Load order.** When the extension changes the prompt, messages, or provider requests, keep `test/load-order.test.ts`: it loads `test/fixtures/marker.ts` before and after the extension.
- **TUI changes.** Run real-PTY UI checks only when explicitly requested; follow the `pi-extension` skill.
