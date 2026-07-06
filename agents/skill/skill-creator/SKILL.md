---
name: skill-creator
description: Create, edit, improve, or audit Pi skills. Use when creating a new skill from scratch, or when asked to improve, review, audit, tidy up, or clean up an existing skill or SKILL.md file, including restructuring a skill directory (moving files to references/ or scripts/, removing stale content, validating against the Agent Skills spec). Triggers on phrases like "create a skill", "author a skill", "improve this skill", "review the skill", "clean up the skill", "audit the skill".
---

# Skill Creator

Guidance for creating effective Pi skills.

## About Skills

Skills are self-contained directories that extend Pi with specialized workflows, tool integrations, domain knowledge, and bundled resources — "onboarding guides" that turn a general-purpose agent into a specialist. Pi implements the [Agent Skills standard](https://agentskills.io/specification) leniently: spec violations warn but the skill still loads; only a missing `description` prevents loading. Working examples: [Anthropic Skills](https://github.com/anthropics/skills), [Pi Skills](https://github.com/badlogic/pi-skills).

How loading works: at startup Pi injects each skill's `name` and `description` into the system prompt; when a task matches, the agent reads the full SKILL.md with the `read` tool (Pi has no dedicated Skill tool). Models don't always auto-load — `/skill:name` forces it (trailing arguments are appended as `User: <args>`), and for must-run workflows add an explicit pointer in AGENTS.md.

## Core Principles

### Concise is key

The context window is shared with the system prompt, conversation history, and every other skill's metadata. Pi is already very smart: add only context it doesn't have, and challenge each paragraph — does it justify its token cost? Prefer concise examples over verbose explanations.

### Set appropriate degrees of freedom

Match specificity to task fragility:

- **High freedom (prose instructions)**: multiple approaches are valid; decisions depend on context.
- **Medium freedom (pseudocode or parameterized scripts)**: a preferred pattern exists; some variation is acceptable.
- **Low freedom (specific scripts, few parameters)**: fragile, error-prone operations where a fixed sequence matters.

### Anatomy of a skill

````
skill-name/
├── SKILL.md          # Required: YAML frontmatter (name, description) + Markdown instructions
├── scripts/          # Executable code for logic that is rewritten repeatedly or needs deterministic reliability
├── references/       # Docs loaded into context on demand (schemas, API docs, policies)
└── assets/           # Files used in output, never loaded into context (templates, fonts, boilerplate)
````

- Frontmatter is the triggering mechanism and is always in context; the body loads only after triggering.
- Scripts run without being loaded into context (though Pi may still read them for patching).
- Don't duplicate content between SKILL.md and references: keep procedural workflow in SKILL.md, details in references. For references over ~10k words, include grep search patterns in SKILL.md.
- Do NOT add auxiliary files (README.md, CHANGELOG.md, installation or quick-reference guides): a skill contains only what an AI agent needs for the job, not documentation about the skill itself.

### Progressive disclosure

Three loading levels: metadata (always in context, ~100 words) → SKILL.md body (on trigger; <5k words, under 500 lines) → bundled resources (on demand; unlimited). When approaching the body limit, split content into reference files, each linked directly from SKILL.md with a clear cue for when to read it:

- **Link out details**: quick start in SKILL.md; "For form filling, see [FORMS.md](FORMS.md)."
- **Organize by domain or variant** so only the relevant file loads:

````
cloud-deploy/
├── SKILL.md (workflow + provider selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
````

Keep references one level deep. Give reference files over ~100 lines a table of contents so Pi sees the scope when previewing.

## Skill Creation Process

1. Understand the skill with concrete examples
2. Plan reusable contents (scripts, references, assets)
3. Create the skill (directory + SKILL.md + resources)
4. Install and verify
5. Iterate

Follow in order; skip a step only with a clear reason.

### Step 1: Understand with Concrete Examples

Gather concrete usage examples from the user, or generate examples and validate them with user feedback: "What functionality should this skill support?", "What would a user say that should trigger it?". Ask the most important questions first, a few at a time. Conclude when the intended functionality is clear. Skip only if usage patterns are already well understood.

### Step 2: Plan Reusable Contents

For each example, consider how to execute it from scratch and what resource would save that work on repetition:

- Same code rewritten each time (rotate a PDF) → `scripts/rotate_pdf.py`
- Same boilerplate each time (webapp scaffold) → `assets/hello-world/` template
- Same knowledge rediscovered each time (BigQuery table schemas) → `references/schema.md`

The output is the list of scripts, references, and assets to include.

### Step 3: Create the Skill

A Pi skill is just a directory with a SKILL.md — there is no scaffolding or packaging step. Skip directory creation if iterating on an existing skill.

#### Location

Use the Pi skill directories: `~/.pi/agent/skills/<name>/` (global) or `.pi/skills/<name>/` (project; loaded after the project is trusted). Pi also discovers skills from packages, the `settings.json` `skills` array, and `--skill <path>`.

````bash
mkdir -p ~/.pi/agent/skills/my-skill
````

Create only the resource subdirectories the skill actually needs.

#### Naming

Lowercase a-z, 0-9, hyphens; 1–64 chars; no leading, trailing, or consecutive hyphens. Normalize user-provided titles to hyphen-case ("Plan Mode" → `plan-mode`). Prefer short, verb-led names; namespace by tool when it helps triggering (`gh-address-comments`). Pi only warns when the folder name differs from `name`, but keep them equal — Claude Code and Codex require it.

#### Resources first

Build the scripts, references, and assets from Step 2. This may need user input (e.g. brand assets or internal docs). Test scripts by actually running them — a representative sample if many are similar. Reference bundled files by relative paths (`scripts/process.sh`), which is how they resolve at load time. Write for another Pi session: include what is beneficial and non-obvious.

#### Frontmatter

Pi supports these fields (unknown fields are ignored):

| Field | Required | Notes |
| --- | --- | --- |
| `name` | Yes | See Naming above. |
| `description` | Yes | Max 1024 chars. The primary trigger — see below. Missing description means the skill is not loaded. |
| `license` | No | License name or reference to a bundled file. |
| `compatibility` | No | Max 500 chars. Environment requirements (runtimes, env vars, OS). |
| `allowed-tools` | No | Tools the skill uses, e.g. `Bash(git:*) Read` — see below. |
| `metadata` | No | Arbitrary key-value mapping. |
| `disable-model-invocation` | No | When `true`, the skill is hidden from the system prompt; users load it only via `/skill:name`. |

`description`: state both what the skill does and the specific triggers/contexts for using it — all of it here, since the body loads only after triggering (a "When to Use" section in the body is useless). Example for a `docx` skill: "Comprehensive document creation, editing, and analysis with support for tracked changes, comments, formatting preservation, and text extraction. Use when Pi needs to work with professional documents (.docx files) for: (1) Creating new documents, (2) Modifying or editing content, (3) Working with tracked changes, (4) Adding comments, or any other document tasks".

`allowed-tools`: a space-separated pre-approval list, `Bash(<cmd>:*)` scopes shell commands. Experimental in the spec; Pi currently ignore it, but fill it with the tools the skill actually uses anyway, for the future potential use.

#### Body

Use imperative/infinitive form. Common sections: **Setup** (one-time steps like `npm install` plus required env vars — mirror these in `compatibility`) and **Usage** (how to invoke the scripts or apply the workflow). A minimal skeleton:

````markdown
---
name: my-skill
description: What this skill does and the specific situations that should trigger it.
---

# My Skill

## Setup

Run once before first use:
```bash
cd ~/.pi/agent/skills/my-skill && npm install
```

## Usage

```bash
./scripts/process.sh <input>
```
````

### Step 4: Install and Verify

A skill created in a discovery location is already installed — there is no build step or archive. Run `/reload` in an interactive session (or start a new one), then force-load with `/skill:name` to test. If `/skill:` commands are unavailable, enable them via `/settings` or `enableSkillCommands: true` in `settings.json`. Fix any validation warnings in the startup output; name collisions across locations warn and keep the first skill found.

To distribute, share the directory itself: a git repo cloned into a skills location, a pi package (a `skills/` directory or `pi.skills` entries in `package.json`), or a `settings.json` `skills` / `--skill <path>` entry.

### Step 5: Iterate

Use the skill on real tasks and note struggles — including whether it auto-loaded at all. If it didn't load when it should have, sharpen the `description`; if it must always run for certain tasks, add a pointer in AGENTS.md. Update, `/reload`, and retest.
