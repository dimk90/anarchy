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

### Script Pattern

All install/configure scripts follow this structure:
1. `set -o nounset` for strict variable handling
2. `set -o errexit` during import only, then `set +o errexit` for runtime (helpers return non-zero on purpose, checked with `assert`)
3. Source `common` library via curl
4. Define functions for each operation
5. Main function with gum-based interactive UI
6. Execute main with assert-based error handling

For authoring or editing these scripts (helpers, output flow, privilege handling), use the `anarchy-script` skill.

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

## Script Section Headers

`printf_section` headers use English Title Case: capitalize every major word, lowercase articles/prepositions (e.g. "Install Packages", "Files and Env", "Set Up the User").

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
