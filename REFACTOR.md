# Common Refactor Candidates

Duplication audit of the 15 entry-point scripts (`install-*`, `configure-*`, `create-user`,
`wipe-disk`) against the shared `common` library. Candidates are split between a proposed new
`fs-tools.sh` module (disk / filesystem domain) and the existing `common`.

Row numbers are unique across both tables and stable for reference.

## Column Meaning

- **Done** — `[x]` once the row is implemented: the helper lives in its module and every listed
  call site uses it.
- **Lines** — physical lines the pattern occupies *today*, summed over every site. This is the
  extraction target, not the net saving: a helper still costs its own body plus one call line per
  site. Rows marked *sites* are inline expressions, where the win is consistency, not line count.
- **Tier** — strength of the evidence that the code already wants to be shared:
  - **1** — verbatim duplicate; `diff` says identical (or differs only in a comment). Mechanical move, zero design work.
  - **2** — repeated boilerplate block; an inline sequence pasted into many `main()` bodies with cosmetic drift. Needs a small API decision.
  - **3** — recurring idiom; a short pattern repeated many times, or one concept implemented differently in each place. Highest judgement, highest risk of a bad abstraction.

## `fs-tools.sh` — Disk, Partition, Btrfs, fstab, UEFI

| #   | Done  | Candidate                                                                                                                                | Suggested Name               | Tier | Lines   |
| --- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ---- | ------- |
| 1   | `[ ]` | Partition path → `<disk>\|<idx>`; byte-identical in `configure-boot:93` + `configure-snapshots:93`                                       | `parse_disk_part`            | 1    | 40      |
| 2   | `[ ]` | `<disk>` + `<idx>` → partition path (inverse of #1); `configure-disk:204`                                                                | `partition_path`             | 1    | 14      |
| 3   | `[ ]` | `lsblk -dpnP` disk enumeration; byte-identical `configure-disk:86` + `wipe-disk:49`                                                      | `list_disks`                 | 1    | 28      |
| 4   | `[ ]` | Gum disk picker; byte-identical `configure-disk:102` + `wipe-disk:65`                                                                    | `select_disk`                | 1    | 60      |
| 5   | `[ ]` | `findmnt -n -o SOURCE /boot`; `configure-boot:85` + `configure-snapshots:85`                                                             | `detect_esp_mount`           | 1    | 12      |
| 6   | `[ ]` | Root-is-btrfs-`subvol=@` check; `configure-boot:124` + `configure-snapshots:116`                                                         | `is_root_btrfs_subvol_at`    | 1    | 24      |
| 7   | `[ ]` | Idempotent fstab append; `configure-snapshots:640` + `configure-swap:154` (also kills the `export -f` hack at `configure-snapshots:700`) | `fstab_append`               | 1    | 21      |
| 8   | `[ ]` | mount `subvolid=5` → `btrfs subvolume create` → umount; `create-user:220`, `configure-snapshots:665`, `configure-swap:127`               | `action_create_subvolume`    | 3    | 77      |
| 9   | `[ ]` | `as_root blkid -s UUID -o value "$dev" 2>>"$LOG_FILE"`; 5 sites                                                                          | `get_uuid`                   | 3    | 5       |
| 10  | `[ ]` | efibootmgr entry create + duplicate-label check; `configure-boot:300,392`, `configure-snapshots:569`                                     | `action_register_uefi_entry` | 3    | 49      |
| 11  | `[ ]` | Function at `configure-boot:115`, inlined as `[ -d /sys/firmware/efi ]` at `configure-snapshots:302`                                     | `is_uefi_boot`               | 3    | 8       |
| 12  | `[ ]` | Cross-script contracts synced by hand: `CRYPT_NAME` (4×), `MNT` (3×), `BTRFS_OPTS` (2×), `UKI_PATH`/`UKI_LABEL` (2×)                     | constants block              | 3    | 16      |
|     |       | **Total**                                                                                                                                |                              |      | **354** |

## `common` — TUI, Actions, Env, Generic Helpers

| #   | Done  | Candidate                                                                                                                            | Suggested Name            | Tier | Lines    |
| --- | ----- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------- | ---- | -------- |
| 13  | `[ ]` | CPU vendor check; byte-identical `install-drivers:22` + `configure-boot:49`                                                          | `is_intel_cpu`            | 1    | 12       |
| 14  | `[ ]` | `request_gum` + assert + "Starting" + version + `start_logger` + log path; identical in **15/15** scripts                            | `action_start_tui`        | 2    | 165      |
| 15  | `[ ]` | Multi-select menu: header → `gum choose --no-limit` → lowercase → count → "Selected X: N" → empty-exit; 9 scripts                    | `choose_items`            | 2    | 270      |
| 16  | `[ ]` | `grep -q 'x' <<< "$choices"` dispatch; local variants `has_component` (`configure-prompt:119`), `add_dep` (`install-modern-cli:343`) | `has_choice`              | 2    | 17       |
| 17  | `[ ]` | `gum style --bold --foreground "$GUM_YELLOW" X` across 8 scripts                                                                     | `highlight`               | 3    | 58 sites |
| 18  | `[ ]` | `printf_action "Label: ${STYLE_CLR}%b\n" "$(gum style …)"`; 10 sites                                                                 | `printf_value`            | 3    | 20       |
| 19  | `[ ]` | `action_run 'Reload …' "$(check_sudo) systemctl daemon-reload" 'done'` + assert; 4 blocks                                            | `action_daemon_reload`    | 3    | 16       |
| 20  | `[ ]` | `action_run "Enable X" "as_root systemctl enable --now X"`; 6 sites                                                                  | `action_enable_service`   | 3    | 24       |
| 21  | `[x]` | `require_tools` skeleton (section header + N × `action_require_package`); `configure-disk`, `configure-swap`, `wipe-disk`            | `action_require_packages` | 3    | 27       |
| 22  | `[ ]` | `action_run "Create X" "as_root mkdir -p …" 'done'`; 12 sites                                                                        | `action_mkdir`            | 3    | 36       |
| 23  | `[ ]` | `https://dimk90.github.io/anarchy` hardcoded at download sites in 8 scripts                                                          | `ANARCHY_URL` const       | 3    | 24 sites |
| 24  | `[ ]` | `mktemp -d` + `trap "rm -rf …" EXIT`; `install-yay:56`, `install-modern-cli:60`, `configure-snapshots:672`                           | `make_temp_dir`           | 3    | 9        |
| 25  | `[ ]` | `id -u "$1"` presence check; `create-user:36`                                                                                        | `user_exists`             | 3    | 6        |
| 26  | `[ ]` | `[ "$EUID" -eq 0 ]` guard; `install-yay:25`                                                                                          | `require_non_root`        | 3    | 5        |
|     |       | **Total**                                                                                                                            |                           |      | **607**  |

## Summary

- ~960 lines are in scope; roughly **550–570 removable** after paying for helper bodies and call sites.
- Biggest single win is #15 (270 lines) followed by #14 (165) — both Tier 2, both mechanical once the
  signature is agreed.
- All Tier 1 rows (#1–#7, #13, 211 lines) are provably behaviour-preserving moves.

## Open Questions

- **Not listed, same domain**: `list_partitions`, `list_crypt_mappers`, `list_mountpoints`,
  `close_mappers`, `is_disk_empty`, `is_disk_ssd` are single-use today, but belong in `fs-tools.sh`
  if the module should be topically complete rather than dedup-only.
- **Naming**: root files are extensionless (`common`), so `fs-tools` matches convention;
  `fs-tools.sh` publishes fine either way at `https://dimk90.github.io/anarchy/fs-tools.sh`.
- **Loading**: only 6 of 15 scripts need fs-tools, so a separate `curl … | source` keeps the rest
  lean — but then fs-tools needs its own `FS_TOOLS_VERSION` and a documented "source `common` first"
  contract (it uses `assert`, `action_run`, `LOG_FILE`, `as_root`).
