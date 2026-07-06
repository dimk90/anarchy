# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Overview

Anarchy is a personal Arch Linux configuration and automation repository. It contains shell scripts that install and configure CLI tools, fonts, and system settings. Scripts are deployed via GitHub Pages and invoked remotely with `curl -fsSL https://dimk90.github.io/anarchy/<script-name> | bash`.

## Architecture

### `common` Library

The central shared library (~1200 lines, versioned via `COMMON_VERSION`) sourced by all scripts. Provides:
- ANSI color definitions and styled output (gum integration)
- Logging, error handling, and assertions
- File operations (backup, line replacement, config parameter setting)
- Environment management (persistent env vars and aliases across bash/fish)
- Package management wrappers (pacman)
- Interactive TUI functions (gum-based spinners, inputs, permission requests)

Scripts download and source `common` dynamically:
```bash
COMMON=$(curl -fsSL "https://dimk90.github.io/anarchy/common")
source <(echo "$COMMON")
```

When reading `common` yourself, use the local file at the repo root — the published URL lags local edits.

Bump `COMMON_VERSION` only for new features or behavior-affecting changes (new helper, changed contract). It's shown to users at script start as a "what changed" signal — routine refactors, tweaks, and doc edits ship without a bump.

### Script Pattern

All install/configure scripts share one skeleton: strict mode, source `common` via curl, helper functions, gum-based interactive `main` with assert-based error handling. The full pattern — skeleton, output flow, helpers, privilege handling — lives in the `anarchy-script` skill (`.agents/skills/anarchy-script/SKILL.md`); use it for any script authoring or editing.

### Directory Layout

- Root scripts: `install-*`, `configure-*`, `create-user`, and `wipe-disk` are the executable entry points
- `common`: Shared shell library (a file, not a directory)
- `agents/`: Personal AI agent config and skills
- `boot/`: Limine bootloader config, kernel cmdline, pacman hooks
- `cli/`: Config files for bat, eza, fzf helpers, git theming
- `doc/`: Step-by-step Arch install guides
- `font/`: Iosevka, Nerd Symbols, Noto Emoji fonts; `font/limine/` and `font/psf/` hold console/boot-menu fonts
- `marimo/`: Marimo notebook config (`pyproject.toml`) and custom CSS styles
- `micro/`: Micro editor keybindings, settings, and plugins
- `starship/`: Shell prompt theme variants (TOML) and selector scripts
- `sudo/`: Sudoers drop-ins (proxy env passthrough)
- `vconsole/`: Custom keyboard layout map
- `zram/`: Compressed RAM disk config

## Testing

Color test scripts can be run directly:
```bash
./color-test16          # 16 ANSI colors
./color-test256         # 256 colors
./color-test-common     # Colors from common lib
./color-gum             # Gum framework colors
```

## Writing Conventions

- **Title Case headers**: `printf_section` titles and markdown headers (in `doc/`, skills, README) use English Title Case — capitalize major words, lowercase articles/prepositions (e.g. "Install Packages", "Files and Env", "Set Up the User"). Doesn't apply to commit messages, comments, or log lines.
- **Concise markdown, no duplication**: in guides (`doc/`), state each fact or explanation exactly once — cross-link the canonical spot instead of re-explaining; keep a single source of truth for values.
- **Verify against official docs**: before suggesting a CLI flag, command sequence, or multi-component design (boot, encryption, filesystems, snapshots), check the official docs/man pages — flag existence, step compatibility, and each component's support for its assigned role. Don't rely on recall.

## Commit Convention

Commits use the format: `[scope] Description` where scope matches the affected area. Reuse an existing scope — check with:
```bash
git log --format='%s' | grep -oP '^\[[^]]+\]' | sort -u
```
Common scopes: `[common]`, `[modern-cli]`, `[font]`, `[micro]`, `[boot]`, `[doc]`, `[agents]`.

## Deployment

The repository is served as a Jekyll GitHub Pages site (`_config.yaml`). Scripts are fetched raw from the pages URL, so:
- Every file in root must be valid for direct shell execution or excluded in `_config.yaml`
- Don't drop scratch files at the repo root — they get published
- New asset directories are reachable at `https://dimk90.github.io/anarchy/<dir>/<file>` automatically, no build step
