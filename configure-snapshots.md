# Configure-Snapshots Review

Conceptually, the script follows `doc/Arch Install/-3- Snapshots.md`: separate root/home policies, sibling snapshot holders, UKI primary boot, split-kernel Limine snapshots, sync hooks, timers, and `snap-pac` installed last.

## Important Findings

- [ ] **Rerunning after Secure Boot setup breaks Limine’s boot chain.** `configure-snapshots:480` overwrites the signed/enrolled EFI binary with the packaged copy. Line 714 replaces `/etc/default/limine`, removing `ENABLE_ENROLL_LIMINE_CONFIG=yes` added by the next guide. The initial sync consequently cannot restore enrollment. This happens even when choosing to keep the existing `limine.conf`.
- [x] **Snapshot boots can resume through the EFI fallback.** [`noresume` explicitly disables resumption](https://man.archlinux.org/man/systemd-hibernate-resume-generator.8.en), including systemd's `HibernateLocation` fallback. `SNAPSHOT_KERNEL_PARAMETERS+=noresume` protects new manifest entries; `boot/81-limine-strip-resume` also adds the guard to existing snapshot cmdlines replayed from `snapshots.json` and strips `resume=` / `resume_offset=`. The hook leaves non-snapshot entries untouched and runs before config-checksum enrollment. Once the updated hook is installed, one `limine-snapper-sync` run protects existing entries.
- [x] **Package installation performs unsupported partial upgrades.** Repo installs use `pacman -S --needed`, never a standalone database refresh. The shared [`action_require_pacman_ready`](.agents/skills/anarchy-script/references/helpers.md#action_require_pacman_ready) preflight covers missing gum, missing repo packages, the AUR sync tool, and `install-yay`'s build/install steps. It rejects upgrade exclusions, unreadable databases, and pending upgrades or replacements without refreshing or upgrading anything. Users read Arch News and complete any required `sudo pacman -Syu` externally. Install errors retain their diagnostics rather than assuming every failure means stale databases. Repo packages remain ahead of Limine deployment; `snap-pac` stays last. This checks existing databases, not mirror freshness, and cannot certify custom/AUR package compatibility or prevent concurrent package-manager changes.

## Script Bugs

- [x] **Existing Snapper configs bypass holder mounting and validation.** Reruns now mount missing sibling holders and verify the actual filesystem UUID and subvolume. Empty interrupted-setup remnants are cleared; wrong mounts, symlinks, and nonempty nested layouts stop setup without migrating data.
- [x] **The fstab check accepts commented or unrelated entries.** `findmnt` now parses active entries at the exact target, requiring the expected UUID, btrfs type, and subvolume. Conflicts and duplicates fail before Snapper changes; a missing entry is appended only after its sibling exists.
- [x] **Kernel cmdline substitution is not literal.** Quoting the replacement itself preserves ampersands and backslashes regardless of `patsub_replacement`.
- [x] **Hook backups remain executable hooks.** New backups end in `.disabled`, matching [upstream's exclusion rule](https://gitlab.com/Zesko/limine-snapper-sync/-/raw/master/install/arch-linux/usr/bin/limine-snapper-sync). Legacy `.bakN` copies have execution permission removed.
- [x] **Deselecting flattening does not disable an installed flattener.** Deselection now disables the canonical hook and its legacy backups; selecting it again installs an executable copy.
- [x] **Temporary resources lack failure cleanup.** Scoped EXIT cleanup removes temporary config/hook downloads and unmounts the temporary Btrfs top level on failure or SIGINT/SIGTERM. Failed cleanup warns with the retained mountpoint instead of prompting or deleting a mounted tree.

## Problems Shared With the Guide

- [x] **Inline Limine comments are invalid.** Every option carries its comment on preceding lines now, in the config, the theme, and the guide's copies of both. `remember_last_entry` matches `yes` again and `default_entry` parses as an index instead of an unresolvable entry path; `timeout` states Limine's real `9999` cap.
- [x] **Retention does not guarantee every retained snapshot is bootable.** `EXCLUDE_SNAPSHOT_TYPES=post` keeps only the `pre` half of each pacman pair, bounding entries at 10 + 5 against `MAX_SNAPSHOT_ENTRIES=20` with room for minimum-age slack. `pre` is also the half worth booting.
- [x] **Daily home retention is not daily snapshot creation.** A `snapper-timeline.timer` drop-in (`snapper/timeline-daily.conf`) clears the packaged hourly schedule for `OnCalendar=daily` with `Persistent=true`, installed before the timer is enabled.
- [x] **Read-only snapshot usability remains unverified.** The guide documents the read-only contract and a snapshot-boot check (`findmnt`, `btrfs property get / ro`, `limine-snapper-info`). No overlay is configured on purpose: `grub-btrfs-overlayfs` requires a busybox initramfs, and `btrfs-overlayfs` makes `limine-snapper-sync` refuse to run at all, so the restore path dies inside every snapshot boot. `SNAPSHOT_WRITABLE=yes` is the documented escape if a service ever needs write access.

## Verification

The six Script Bugs, the four Problems Shared With the Guide, and the partial-upgrade and hibernation findings were addressed. The Secure Boot rerun finding remains open; its line references describe the original reviewed version.
