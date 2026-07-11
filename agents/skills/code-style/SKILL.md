---
name: code-style
description: Language-agnostic code style and quality conventions for writing or editing source code in any programming language. Use whenever creating new code, refactoring, or reviewing changes — covers naming, comments, simplicity, surgical changes, and verification discipline. Language-specific skills (e.g. a Python skill) layer additional rules on top of this one; load both when working in such a language.
---

# Code Style

Baseline conventions for writing readable, maintainable code in any language.

This skill is deliberately language-agnostic and self-contained. Language
skills (e.g. `python-code`) do **not** duplicate these rules — they add language-
specific ones on top. When editing code in such a language, load its skill
too; both apply together, with the language skill taking precedence on any
overlap.

## Precedence

Apply the strictest applicable rule, in this order:

1. Explicit user instruction for the task.
2. Existing conventions in the file/module being edited — match them.
3. Project config (AGENTS.md, linter/formatter config, editorconfig).
4. Language-specific skill (if one is loaded).
5. These general rules.

Never impose a personal style over an established one. When in doubt, mirror
the surrounding code.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently.
Weak criteria ("make it work") require constant clarification.

## 5. Naming and Comments

- Use descriptive variable names; avoid meaningless short names like `p`, `k`.
  Lambda parameters are a possible exception when the lambda must be compact
  and its meaning is obvious.
- Prefer clean, readable code over compactness — favor clarity even when a
  terser form is possible.
- Comments explain **why**, not **what**: document non-obvious decisions and
  gotchas. No comments restating the code, no commented-out code.
- Every function and type gets a docstring/doc comment — including private
  ones, in the language's native doc format (JSDoc, Python docstring, etc.).
  Document purpose and contract, not a restatement of the signature.
