# Packaged Extension Reference

How to lay out, document, test, and release a pi extension distributed as an
npm/git pi package. Read this when creating a new extension repository or
publishing an existing one; a single-file extension needs none of it.

## Contents

- [When to use the package layout](#when-to-use-the-package-layout)
- [Template map](#template-map)
- [Instantiating the template](#instantiating-the-template)
- [package.json rules](#packagejson-rules)
- [TypeScript config](#typescript-config)
- [pnpm workspace](#pnpm-workspace)
- [Documentation set](#documentation-set)
- [Source and test layout](#source-and-test-layout)
- [TUI capture harness](#tui-capture-harness)
- [README media](#readme-media)
- [Release workflow](#release-workflow)

## When to use the package layout

| Shape | Use when |
| --- | --- |
| `~/.pi/agent/extensions/x.ts` or `.pi/extensions/x.ts` | one concern, no deps, no distribution |
| `my-ext/index.ts` + helpers | several modules, still local |
| Full package (this template) | published to npm/git, versioned, documented, demoed |

## Template map

`assets/package-template/` in this skill:

```text
package.json          peer "*" + exact dev pins, pi manifest, gallery image
tsconfig.json         NodeNext + type-stripping-safe strict config
pnpm-workspace.yaml   build approvals + release-age exclusion for pi packages
gitignore             → rename to .gitignore
gitattributes         → rename to .gitattributes (git-lfs for doc/images)
AGENTS.md             architecture / state / privacy / verification skeleton
README.md             badges, features, commands, demo, install, context footprint
CHANGELOG.md          `[vX.Y.Z]` - DD.MM.YYYY with `[scope]` entries
doc/PLAN.md           roadmap only; completed work moves to CHANGELOG.md
doc/RELEASE.md        develop → master → tag → publish checklist
src/index.ts          factory: registration, closure state, guards
src/command.ts        pure command grammar (parse + completions)
test/command.test.ts  node:test unit test for the pure helpers
test/fixtures/marker.ts   another-extension fixture for load-order tests
test/capture-view.sh  tmux harness that renders a view and captures the frame
```

Files not templated because they are unchanged boilerplate: `LICENSE` (MIT
text with the author and year) and `doc/UI.md` / `doc/HISTORY.md`, whose
content is entirely project-specific — but create them, since AGENTS.md and
PLAN.md link to them.

## Instantiating the template

```bash
skill=~/.pi/agent/skills/pi-extension/assets/package-template
cp -r "$skill/." ./my-ext/ && cd my-ext
mv gitignore .gitignore && mv gitattributes .gitattributes
```

Then replace every placeholder:

| Placeholder | Value |
| --- | --- |
| `{{package}}` | npm package and repo name, e.g. `pi-context-view` |
| `{{owner}}` | GitHub owner |
| `{{Author Name}}` | package author |
| `{{command}}` | primary slash command without the leading `/` |
| `{{arg-a}}`, `{{arg-b}}` | command arguments/views |
| `{{scope}}` | changelog/commit scope tags |
| `{{pi --version}}` | exact installed pi version |
| `{{commit-sha}}` | commit SHA pinning README/gallery media |
| `{{demo}}` | base name of the demo image/GIF under `doc/images/` |

Verify with `rg '\{\{' .` before the first commit.

## package.json rules

- `pi.extensions` lists entry points; pi also auto-discovers a conventional
  `extensions/` directory. `pi.image` (PNG/JPEG/GIF/WebP) or `pi.video` (MP4)
  drives the https://pi.dev/packages gallery card; both must be absolute URLs.
- Keywords `pi`, `pi-extension`, `pi-package` — `pi-package` is what the
  gallery filters on.
- Bundled pi packages (`@earendil-works/pi-ai`, `@earendil-works/pi-agent-core`,
  `@earendil-works/pi-coding-agent`, `@earendil-works/pi-tui`, `typebox`) go in
  `peerDependencies` with `"*"` and are never bundled. Pin the same versions
  exactly in `devDependencies`, matching `pi --version`, so typecheck runs
  against the pi the user actually runs. `"*"` resolves to whatever the running
  pi ships, so schemas must stay inside the current typebox surface (1.3.x
  since pi 0.83 — see [tools.md](tools.md#schema-rules) for the removed APIs).
- Third-party runtime deps go in `dependencies` (pi runs `npm install` on
  install); other pi packages additionally need `bundledDependencies`.
- `files` should ship `src` and `README.md` only — demo images and GIFs must
  stay out of the tarball. Verify with `pnpm pack --dry-run`.
- No build step: pi loads `.ts` through jiti, so `src/**.ts` is the published
  artifact and `scripts` only cover `test` and `check`.

## TypeScript config

`noEmit` with `allowImportingTsExtensions` (relative imports keep the `.ts`
suffix, which is what pi's loader resolves), `verbatimModuleSyntax`, and
`erasableSyntaxOnly` — type stripping rejects `enum`, `namespace`, and
constructor parameter properties. `pnpm check` = `tsc --noEmit && pnpm test`.

## pnpm workspace

`minimumReleaseAgeExclude: ["@earendil-works/pi-*"]` is required if the user's
pnpm config delays fresh releases; without it, pinning the dev deps to a
just-released pi fails. `allowBuilds` approves build scripts of pi's transitive
dependencies under pnpm 10.

## Documentation set

Each file has one job; duplicated content rots.

- **AGENTS.md** — architecture for agents: lifecycle flow, which event makes
  each fact observable and why earlier ones do not, ownership and attribution
  rules, privacy constraints, verification command, required invariants,
  dependency policy. Keep it prescriptive.
- **README.md** — user-facing: features, commands, demo GIFs, `pi install
  npm:<package>`, and an honest **Context** section stating what the extension
  adds to the model context.
- **CHANGELOG.md** — newest first, `## `[vX.Y.Z]` - DD.MM.YYYY``, sections
  New/Changed/Fixed, every entry prefixed with a `[scope]` tag matching commit
  scopes. `Unreleased` until the release commit.
- **doc/PLAN.md** — future work only, per version, plus open questions.
- **doc/UI.md** — canonical rendering/interaction spec when the extension has
  TUI views; AGENTS.md points to it instead of duplicating styling rules.
- **doc/HISTORY.md** — superseded designs, failed approaches, and hard-won
  findings about pi internals or third-party transports. This is what stops a
  future session from retrying an abandoned design.
- **doc/RELEASE.md** — the executable release checklist.

## Source and test layout

- `src/index.ts` holds only the factory: registration, closure state, event
  wiring, and guards (`ctx.hasUI`, `ctx.mode === "tui"`).
- Pure logic (`command.ts`, measurement, formatting) sits in sibling modules
  with no `pi` access, so `node --test` covers it directly.
- TUI components live in `src/ui/`; view state (`*-model.ts`) is separated from
  rendering (`*-view.ts`) so both are testable without a terminal.
- Tests are `test/*.test.ts` run by `node --test test/*.test.ts` (Node runs
  TypeScript natively; no test framework dependency). Render tests instantiate
  a `Theme` with recognizable per-color values and assert on the emitted
  sequences and `visibleWidth`.
- `test/fixtures/marker.ts` simulates another extension that appends to the
  system prompt and sends a hidden startup message. Load it before and after
  the extension under test to prove load-order independence.

## TUI capture harness

`test/capture-view.sh` renders a view in a detached tmux pane and writes the
captured frame. The non-obvious parts, all of which cost real debugging time:

- Gate startup on `tmux display-message -p '#{pane_current_command}' == pi`;
  pane text matches the shell prompt that was drawn before pi started.
- Gate input on pi's completion popup text, not on the typed command: keys sent
  before pi owns the terminal are echoed by the shell, so the command appears
  on screen although pi never saw it. Retype with `C-u` first.
- Copy a session file to a temp dir before opening it — pi and extensions
  append entries and would mutate the recording.
- `pi -e .` alongside an installed copy produces duplicate commands; pi suffixes
  them in load order (`/cmd:1` = working copy, `/cmd:2` = installed), which is
  the way to diff working copy against release.
- Write no capture when the view never rendered, so stale logs cannot be
  mistaken for a fresh run.

## README media

Store PNG/GIF under `doc/images/` with git-lfs (`.gitattributes`), and reference
them from README and `pi.image` through `https://media.githubusercontent.com/media/<owner>/<repo>/<commit-sha>/doc/images/<file>`
so published media is immutable and independent of later branch changes.

## Release workflow

`doc/RELEASE.md` is the checklist; the invariants behind it:

1. Release from `develop`; merge into `master` with `--no-ff`; tag the `master`
   merge commit; publish only from that tagged tree.
2. Re-pin the pi dev dependencies to the locally installed `pi --version` and
   refresh the lockfile before validating.
3. Datestamp the changelog, remove the shipped section from `doc/PLAN.md`, and
   confirm README/gallery media URLs point at the intended immutable revisions.
4. Validate with `pnpm check` and `pnpm pack --dry-run` before committing, and
   again after the merge.
5. Push branches and tag before `pnpm publish --no-git-checks --access public`;
   never publish from an unpushed tree.
