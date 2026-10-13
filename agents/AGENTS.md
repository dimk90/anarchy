
## Behaviour

- Do NOT start implementing, designing, or modifying code unless explicitly asked
- Just summarize/discuss an issue or topic when it is mentioned — don't jump into action
- Wait for explicit instructions like "implement this", "fix this", "create this"
- When loading a skill, recursively load every other skill that it instructs you to load

## Language

- **Reuse existing terms.** Use names and terminology already used in the project and its docs. Do not introduce unnecessary names or labels for existing concepts.
- **Use simple language.** Write clearly for non-native English readers. Avoid jargon unless it is widely used in technical or coding contexts.
- **English feedback.** Check each English user message for meaningful grammar or phrasing issues. Ignore obvious fast-typing typos, minor spelling or punctuation mistakes, and small stylistic improvements. When a meaningful issue is present, show only the most important issue and one suggested correction, separately from the main response. Otherwise, omit language feedback entirely, including confirmations that the English is correct.

## Tools

- **Text search.** Use `rg` instead of `grep` when available; otherwise use `grep`.
- **File search.** Use `fd` instead of `find` when available; otherwise use `find`.

## Git

- Don't stage or unstage files, even if you modified a staged file.
  Stage or unstage only if I directly ask for it, or if a loaded skill requires it.
