---
name: python-code
description: Python-specific code style and conventions for writing or editing Python source. Use whenever creating, refactoring, or reviewing Python (.py) code. Adds Python rules on top of the general code-style skill; load that one too — both apply together, and these rules win on any overlap.
---

# Python Code Style

Python-specific rules that layer on the general `code-style` skill. Load
`code-style` as well; it covers the language-agnostic baseline (thinking
before coding, simplicity, surgical changes, verification, naming and
comments). Only the Python additions live here.

## Strings

- Use single quotes `'...'` for all string literals.
- Reserve double quotes for docstrings (`"""..."""`), or use `"..."` only to
  avoid escaping an embedded `'`.

## Type Annotations

- Strongly prefer type annotations: annotate every function argument and
  return type.
- Add annotations to any function you touch while editing, even if it lacked
  them before.

## Docstrings

- Give every function a docstring except `main`.
- Use multi-line docstrings only: newline right after the opening `"""` and
  before the closing `"""`. Never a single-line docstring.
- In a class, `dataclass`, or `NamedTuple`, leave no blank line between the
  docstring and the first field/member.

## Return Types

- For complex or multi-field return types (e.g.
  `tuple[dict[int, Glyph], int | None, int | None]`), return a `dataclass` or
  `NamedTuple` with named fields instead of a bare tuple.

## main

- `main` returns `int` (`def main() -> int:`) and ends with `return 0` when no
  errors occurred.
