---
name: agents-md
description: Write, audit, prune and update a repository's AGENTS.md (or an equivalent always-loaded agent instruction file such as CLAUDE.md). Use when asked to create an AGENTS.md for a project, review or clean one up, remove outdated or redundant content, shorten it, check whether it still matches the code, move corner cases into linked docs, or refresh it after a change to the layout, tooling or conventions.
allowed-tools: Read Edit Write Bash(ls:*) Bash(rg:*) Bash(cat:*) Bash(wc:*) Bash(git log:*) Bash(git show:*)
---

# AGENTS.md

AGENTS.md is injected into **every** agent run in the repository it sits in.
Its budget is paid per session, forever. Each line must change what an agent
does on many tasks, or it must go.

Optimize for one reader: a competent agent that has never seen this repo, is
about to edit it, and can run commands but pays context for everything it
reads.

## The Admission Test

Keep a line only if all four hold:

1. **Non-obvious** — a strong model would otherwise get it wrong or guess.
   Cut generic engineering advice ("write tests", "handle errors", "use
   meaningful names"). Cut restatements of a skill only when the file
   points agents at that skill — readers without it need the rule inline.
2. **Broad** — it applies across many tasks in this repo. A rule that fires
   only while releasing, deploying or debugging belongs in a doc, referenced
   by one line.
3. **Actionable** — it tells the agent what to do or not do. History,
   rationale, benchmarks, selling points and roadmaps are not.
4. **True today** — verified against the current tree, not the intent at the
   time it was written.

Everything else is either deleted or moved behind a pointer.

## What Usually Earns Its Keep

Not a template — include only what applies, name sections to fit the repo,
and drop any of these that the repo makes obvious anyway:

- One-paragraph orientation: what the project is, what shape it has (library /
  CLI / service), the language and the entry point.
- A path → purpose table for files an agent must find or must keep in sync.
  Skip self-explanatory paths; keep the ones with a duty attached.
- Commands to build, test, lint, run — exactly as invoked, including the
  "there is no test suite, verify manually by X" case.
- Constraints that silently break things: runtime/version floors, platform
  targets, generated files that must not be edited by hand, forbidden APIs.
- Conventions an agent cannot infer from a single file: naming tiers, error
  and message channels, where a new function belongs, phase/lifecycle rules.
- "Part of the change" duties: docs, changelog or fixtures that must be
  updated in the same commit as the code.
- Git and workflow rules that differ from the default (branch, commit subject
  style, what never to stage or push).
- Pointers to on-demand docs, each with its trigger: `doc/RELEASE.md` —
  read when cutting a release.

## Writing Rules

- Imperative, declarative, dense. No greeting, no "This document...", no
  restating the section title in its first sentence.
- One rule per bullet, lead with the bolded rule name, then the specifics.
- Facts belong in tables; procedures in numbered steps; commands in fenced
  blocks, copy-pasteable.
- Prefer the concrete: `no declare -A, bash 3.2 is the floor` beats
  "keep compatibility in mind".
- Single source of truth: if a rule is documented in a linked file, AGENTS.md
  gets the pointer, not a paraphrase.
- No status, version numbers, dates, or "planned / not yet frozen" claims —
  they rot. Point at the file that tracks them.
- Budget: aim under ~150 lines. Past that, cut or split before adding.

## Workflows

### Initialize

1. Explore before writing — never generalize from the README alone:
   ```bash
   ls -A && git log --oneline -20
   rg --files --hidden -g '!.git' | head -60
   cat README.md CONTRIBUTING.md 2>/dev/null
   # where the build/test/lint commands are defined:
   cat package.json Makefile pyproject.toml 2>/dev/null
   ```
2. Read the main source file and one recent feature commit's diff — house
   conventions are visible there, not in the docs.
3. Draft only rules with evidence in the tree; where the repo is silent, ask.
4. Verify (below), then report what you asserted and on what evidence.

### Audit and Prune

1. Find the drift window — commit subjects since the file was last touched
   reveal renames and tooling changes it cannot reflect:
   ```bash
   git log --oneline "$(git log -1 --format=%h -- AGENTS.md)"..HEAD
   ```
2. Verify every factual claim (below); delete or fix what fails.
3. Apply the admission test to each line. Typical cuts: onboarding prose for
   humans, rationale, restated skill/model knowledge, duplicated rules
   spread over several bullets, one-off corner cases.
4. Merge near-duplicates into one bullet instead of trimming both.
5. Rewrite the survivors denser; prefer cutting words over adding them.
6. Report cuts grouped as *outdated* / *redundant* / *moved*, with the
   before → after line count. Ask before deleting a rule whose intent is
   unclear — it may encode a bug someone hit.

### Update After a Change

Refresh AGENTS.md in the same change when it renames or moves a listed path,
adds or drops a dependency or command, changes a documented convention, or
adds a duty ("update the changelog too"). Edit the affected lines only —
no opportunistic rewrites.

### Split Out Corner Cases

When a rule needs more than ~3 lines, or fires only in a rare workflow:
move the full text into `doc/<TOPIC>.md` (or the repo's docs location),
leave one line naming the file and when to read it, and confirm the moved
text still reads standalone.

## Verify

Every claim must survive a check. At minimum:

```bash
# paths that no longer exist (globs and placeholders are expected noise);
# swap the filename when the file is CLAUDE.md
rg -o '`[^` ]+`' AGENTS.md | tr -d '`' \
  | rg '/|\.(md|sh|json|ya?ml|toml|ts|py)$' | sort -u \
  | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

- Run, or at least locate, every command AGENTS.md tells an agent to run.
- Compare claims like "no CI" or "no tests" against `.github/`, `test/`,
  `Makefile` — these age first.
- Check that top-level directories worth knowing are mentioned, and that
  nothing mentioned is gone.
- Confirm each linked doc exists and still covers what the pointer promises.

## Hard Limits

- Never invent a convention the repo does not practice; grep for a second
  instance before generalizing one.
- Never add content aimed at humans (install guides for users, project
  history, credits, badges) — that is README material.
- Never duplicate another skill's rules; reference the skill by name.
- Do not stage or commit unless asked.
