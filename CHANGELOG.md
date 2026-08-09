# Changelog

Versions track `COMMON_VERSION` in `common`; every entry ships as soon as it lands on `main`.

## `[v2.13]` - 09.08.2026

### New
* `[common]` Add `pretty_path` - shortens a leading `$HOME` to `~` for display.

### Changed
* `[common]` Show the destination as `~/...` in the `action_install_file` install line.
* `[common]` Show file names only in the `action_install_file` backup line.
