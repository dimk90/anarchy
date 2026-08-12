# Changelog

Versions track `COMMON_VERSION` in `common`; every entry ships as soon as it lands on `main`.

## `[v2.14]` - 12.08.2026

### New
* Add `action_start_tui` for shared UI and logger initialization.
* Add `action_choose_items` and `has_choice` for standard multi-select menus.

### Changed
* Use the shared startup action in all entry-point scripts.
* Use the shared selection helpers in all nine standard multi-select menus.

## `[v2.13]` - 09.08.2026

### New
* Add `pretty_path` - shortens a leading `$HOME` to `~` for display.

### Changed
* Show the destination as `~/...` in the `action_install_file` install line.
* Show file names only in the `action_install_file` backup line.

## `[v2.12]` - 09.08.2026

### New
* Add a `gum` wrapper - re-raises Ctrl+C as `SIGINT` instead of leaking exit status 130.
* Add `_anarchy_handle_interrupt` - prints `interrupted` and exits with status 130.

### Changed
* Re-raise status 130 as `SIGINT` in `assert` instead of failing with the given message.
* Make `is_command_available` look up executables only, so the `gum` wrapper isn't matched.

## `[v2.11]` - 09.08.2026

### Changed
* Write fish env vars as `conf.d` files with global exported variables (`set -gx`) instead of universal ones.
* Erase the previously set fish universal variable once its replacement file exists.
* Validate the variable name in `env_set_permanent` / `env_unset_permanent`.

## `[v2.10]` - 08.08.2026

### New
* Add `APT_LISTS_REFRESHED` - refreshes apt lists only on the first install of a run.

### Changed
* Make action statuses (`exists`, `installed`, `done`, `granted`, ...) bold for a consistent color style.
* Make the installed file name bold in the `action_install_file` install line.

## `[v2.9]` - 30.07.2026

### New
* Add `install_gum_deb` - installs gum from the `.deb` release on Debian/Ubuntu.

## `[v2.8]` - 29.07.2026

### Changed
* Emit a leading blank line from `printf_warning` / `printf_info` / `printf_error`.
* Drop `faint` from colored action statuses and pre-style the `action_run` separator instead.
* Create the log file with a `.log` suffix via `mktemp --suffix`.
* Quote the title in the `action_run` spinner `printf`.

### Fixed
* Fix `replace_line` breaking on a `|` in the replacement.
* Fix the faint style leaking into the status and separator of `action_set_password`.

## `[v2.7]` - 29.04.2026

### New
* Add `printf_info` / `bullet_info` - info-level output helpers.
* Add the `fail_status` parameter to `action_run`.

## `[v2.6]` - 27.04.2026

### New
* Add `action_set_password` - prompts for a password and sets it.

### Changed
* Export the `action_*` functions so they work in sub-shells.

### Fixed
* Fix value escaping in `env_set_permanent` (variables, and bash in particular).
* Fix `regex_sanitize` to escape `.` and to keep an escaped `\`.
* Fix `action_require_package` when an empty title is provided.

## `[v2.5]` - 30.03.2026

### New
* Add `get_package_manager` - detects pacman or apt.
* Add apt support to `is_package_installed`, `action_require_package` and `request_gum`.

### Changed
* Improve file name logging in `action_install_file`.

## `[v2.4]` - 07.02.2026

### Removed
* Remove the redundant `array_contains` and `choices_to_indices` functions.

## `[v2.3]` - 07.02.2026

### New
* Add `env_unset_permanent` - removes a permanently set env var.

### Fixed
* Fix and simplify the `regex_sanitize` implementation.

## `[v2.2]` - 28.12.2025

### New
* Add `alias_set_permanent` - sets an alias across bash and fish.

### Changed
* Use ERE mode for all `sed` calls.

## `[v2.1]` - 27.12.2025

### New
* Add `regex_sanitize` - escapes a string for use inside a regex.
* Add `config_set_param` - sets a `key=value` parameter in a config file.

### Changed
* Redirect the `action_run` command output to the log file.
* Unify the docstring format and the color definitions.

## `[v2.0]` - 26.12.2025

### New
* Add `action_run` - runs a command behind a spinner and reports its status.
* Add `action_install_file` - downloads a file, backs up the target and installs it.
* Add `action_request_permission` - requests sudo with a reason text.
* Add `env_set_permanent` - sets an env var across bash and fish.

### Changed
* Export functions and variables, so they survive in sub-shells (e.g. `gum spin`).
* Rename `VERSION` to `COMMON_VERSION`.
* Add a case-insensitive mode to `remove_line`.
* Log every `sed` command and print a `failed` status for `action_run`.
* Lower the minimal UI delay from 1s to 0.6s.

## `[v1.0]` - 26.10.2025

### New
* First versioned release of the shared library.
