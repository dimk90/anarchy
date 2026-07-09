---
name: typescript-code
description: TypeScript-specific code style and conventions for writing or editing TypeScript source. Use whenever creating, refactoring, or reviewing TypeScript (.ts) code. Adds TypeScript rules on top of the general code-style skill; load that one too — both apply together, and these rules win on any overlap.
---

# TypeScript Code Style

> **REQUIRED FIRST:** If not already in context, read
> `~/.pi/agent/skills/code-style/SKILL.md` before writing or editing any code.
> These rules layer on top of it.

TypeScript rules that layer on the general `code-style` skill. Project
formatter/linter config always wins over the defaults below.

## Formatting

- Tabs for indentation, line width 120, double quotes, semicolons.
- Numeric separators for large literals: `2_147_483_647`.

## Modules and Imports

- ESM only. In projects that resolve them, use explicit `.ts` extensions in
  relative imports (`./types.ts`); otherwise match the project.
- Top-level imports only — no `await import()`, no inline `import("pkg").Type`.
- Separate type imports: `import type { Foo } from "./foo.ts"`. When mixing
  values and types from one module, inline `type` per name:
  `import { type Static, Type } from "typebox"`.
- Named exports only; never `export default`.
- Public packages expose a curated barrel `index.ts`; prefer explicit
  `export { a, type B }` lists over blanket `export *` when the module has
  internals.

## File Layout

Top-to-bottom "newspaper" layout — readers meet things in dependency order:

1. Imports.
2. Module constants (`SCREAMING_SNAKE_CASE`).
3. Public types/interfaces — the module's vocabulary and contract.
4. Exported functions — the API.
5. Private helpers — below the public functions, or just before their single
   caller.

Refinements:

- A private type used by only one helper may sit directly above that helper
  instead of at the top ("declare near single use").
- Long files with distinct areas: group by feature under `// ===...===`
  banners, each section holding its own types + functions.
- Never interleave types and functions with no dependency or locality logic —
  order encodes structure, not edit history.

## Types

- Strict mode assumed. Use only erasable syntax (works under type stripping):
  no `enum`, `namespace`, `import =`, `export =`, or constructor parameter
  properties. Declare fields explicitly and assign in the constructor.
- String literal unions instead of enums:
  `type QueueMode = "all" | "one-at-a-time"`.
- Discriminated unions on a `type` field for events/results; narrow with
  `switch` or `Extract<Union, { type: "x" }>`.
- Extensible string unions via `KnownFoo | (string & {})` to keep completions
  while accepting arbitrary strings.
- `interface` for object shapes and options bags; `type` for unions, aliases,
  and mapped/conditional types.
- `satisfies` for typed constant literals: `const DEFAULT = {...} satisfies Model`.
- Prefer `undefined` over `null`: optional fields (`foo?: T`), `return undefined`,
  defaults via `??`. Use `null` only where an API demands it (e.g. cleared
  timer handles: `NodeJS.Timeout | null`).
- `T[]` over `Array<T>`, except when the element type is a union:
  `Array<TextContent | ImageContent>`.
- No `any` unless truly necessary; `unknown` for opaque values. Avoid non-null
  assertions — restructure or check instead.
- For validated inputs (tool params, configs), define a runtime schema
  (typebox/zod per project) and derive the static type from it
  (`Static<typeof schema>` / `z.infer`), not the other way around.

## Functions and Classes

- `function` declarations at module level; arrow functions only for callbacks
  and stored function-typed values.
- Options-bag parameters (`options?: FooOptions`) instead of long positional
  lists; destructure with `??` defaults at the top.
- Factory functions named `createXxx(...)`.
- Classes: `private` / `public` / `readonly` keywords, not `#` fields. Mark
  never-reassigned fields `private readonly`. Use getters/setters when access
  needs controlled semantics (defensive copies, derived state).
- Thread `AbortSignal` through long-running/async APIs as an optional
  parameter; check `signal?.aborted` and clean up listeners.

## Naming

- `camelCase` functions/variables, `PascalCase` types/classes,
  `SCREAMING_SNAKE_CASE` module-level constants (`DEFAULT_MAX_LINES`),
  kebab-case file names (`credential-store.ts`).
- Short locals like `ctx`, `opts` are fine in small scopes; exported API uses
  full words (`context`, `options`).

## Comments and Docs

- JSDoc (`/** ... */`) on exported functions, classes, interfaces, and
  non-obvious fields. Document contracts, defaults, and merge/override
  semantics — not restatements of the signature.
- `// ===...===` section banners to organize long files.

## Errors

- Throw `Error` with a descriptive, actionable message.
- Normalize unknown catches with
  `error instanceof Error ? error.message : String(error)`.
- Don't type catch clauses as `any`; use bare `catch (error)` or
  `catch (error: unknown)`.
