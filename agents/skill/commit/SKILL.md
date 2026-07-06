---
name: commit
description: Draft and create a single git commit following the repository's existing message convention. Use whenever the user asks to commit changes — "commit this", "commit my changes", "make a commit for X", "stage and commit Y". Inspects git status/diff/log, picks a coherent set of files, drafts a short imperative title matching the repo's style (e.g. a `[scope] Description` prefix convention), confirms the message and file list with the user before committing, stages files by name, and commits. Never pushes, never amends unless asked, never bypasses hooks.
allowed-tools: Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git add:*) Bash(git commit:*) Read
---

# Commit

Create one git commit for the current changes, matching the repository's existing conventions, with user confirmation before anything is committed.

## Workflow

### 1. Inspect

Run in parallel:

```bash
git status
git diff            # unstaged
git diff --cached   # staged
git log --oneline -n 10
```

Understand what changed and how recent commit messages are styled.

### 2. Select files

- **If something is already staged**, treat the staged set as the intended scope: draft the message from the staged diff only and commit just those changes — do not add unstaged files.
- Otherwise, include only files belonging to a single logical change.
- Exclude binary churn (fonts, images, build artifacts) unless the user explicitly includes it.
- If the working tree mixes unrelated changes, commit only the clearly relevant subset and mention what was left untouched.

### 3. Draft the message

- **Match the repo's convention** as seen in `git log`. If the repo uses a prefix convention (e.g. `[scope] Description` or `type(scope): description`), reuse an existing scope/type — never invent a new one without checking:
  ```bash
  git log --format='%s' | grep -oP '^(\[[^]]+\]|\w+(\([^)]+\))?:)' | sort -u
  ```
- Title short (ideally under 60 chars), imperative mood ("Add X", "Fix Y" — not "Added" / "Fixes").
- **Default to title-only.** No body, no `Co-Authored-By` trailer, no boilerplate.
- Add a body **only** when it carries non-obvious context the diff and title can't convey (a bug reference, a constraint that drove the choice, a follow-up note). If nothing is worth keeping, omit it.

### 4. Confirm with the user

Before staging or committing, present the proposed message and the exact file list via `ask_user` with options:

- **Commit as-is** (default)
- **Edit the message** — capture revised text, then re-confirm the revision the same way
- **Cancel** — abort without committing

Never run `git commit` until the user has approved the exact final message and file list.

### 5. Commit

- Stage the approved files **by name** — never `git add -A` / `git add .`.
- Commit with the approved message. Use a HEREDOC only when a body is actually needed.
- Run `git status` to confirm, then report one sentence on what was committed plus the commit hash. If files were intentionally left out, name them in one short line. If the user cancelled, say so and stop.

## Hard limits

- **Never push.** No `git push` of any kind, even if a remote is behind.
- **Never amend** unless the user explicitly asked.
- **Never use `--no-verify`** or any flag that bypasses hooks or signing.
- **Never update git config.**
- One commit per invocation — if the user wants the remainder committed too, that's a fresh pass through this workflow.

If the user's request conflicts with these limits (e.g. asks to push), surface the conflict instead of obeying silently.
