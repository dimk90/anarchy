# Anarchy

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg?style=flat-square)](https://opensource.org/licenses/BSD-3-Clause)
[![Deployed](https://img.shields.io/github/deployments/dimk90/anarchy/github-pages?label=Deployed&style=flat-square)](https://dimk90.github.io/anarchy/)

Highly disorganized personal configs and install scripts for Arch Linux.  

Badges next to each heading list the distros the script is *tested* on.


## Configs


### wipe-disk ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Pre-install cleanup: erase an existing install on the target disk before
running `configure-disk`. Must be run as root from the live USB. The script
scans available disks, asks the user to pick one, closes any leftover LUKS
mappers and stale mounts, then wipes signatures (`wipefs -a`), zaps the
partition table (`sgdisk --zap-all`), and issues a whole-device TRIM
(`blkdiscard -f`):
```bash
curl -fsSL https://dimk90.github.io/anarchy/wipe-disk | bash
```

This is destructive and irreversible — `wipefs`, `sgdisk --zap-all`, and
`blkdiscard` cannot be undone. Double-check the target disk before confirming.

### disk ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Partition the target disk and prepare mount points for an Arch install
(GPT + LUKS2 + btrfs subvolumes). Must be run as root from the live USB.
The script scans available disks, asks the user to pick one, refuses to
proceed unless the disk is empty, and runs `genfstab` at the end:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-disk | bash
```

Resulting layout:

| Part | Size     | Encryption | Filesystem | Label    | Subvolume         | Mount point        |
| :--: | :------- | :--------- | :--------- | :------- | :---------------- | :----------------- |
|  p1  | 6 GiB    | —          | FAT32      | —        | —                 | `/boot`            |
|  p2  | rest     | LUKS2      | btrfs      | `rootfs` | `@`               | `/`                |
|  p2  | (shared) | LUKS2      | btrfs      | `rootfs` | `@home`           | `/home`            |
|  p2  | (shared) | LUKS2      | btrfs      | `rootfs` | `@home-snapshots` | `/home/.snapshots` |
|  p2  | (shared) | LUKS2      | btrfs      | `rootfs` | `@log`            | `/var/log`         |
|  p2  | (shared) | LUKS2      | btrfs      | `rootfs` | `@cache`          | `/var/cache`       |
|  p2  | (shared) | LUKS2      | btrfs      | `rootfs` | `@snapshots`      | `/.snapshots`      |

The encrypted partition is opened as `/dev/mapper/cryptroot`.
Btrfs is mounted with `noatime,ssd,discard=async,commit=120,compress=zstd:1,space_cache=v2`.

### boot ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Set up UEFI boot for an encrypted Arch install — Unified Kernel Image
(UKI) with the LUKS UUID baked into `/etc/kernel/cmdline`, plus an
optional EDK2 UEFI Shell entry for low-level diagnostics. Must be run
from inside the chroot with the ESP mounted at `/boot`. The script
switches `mkinitcpio` to systemd-flavor HOOKS, writes
`/etc/kernel/cmdline` and `/etc/crypttab.initramfs`, builds the UKI via
`mkinitcpio -P`, and registers entries in NVRAM via `efibootmgr`:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-boot | bash
```

CPU microcode is bundled into the UKI by mkinitcpio's `microcode` hook
(`intel-ucode` on Intel; AMD/other vendors must install microcode
manually). The preset also emits a split `initramfs-linux.img` (paired
with `vmlinuz-linux` + microcode) that `configure-snapshots` consumes for
the snapshot boot path.

### snapshots ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Set up btrfs snapshots with boot-to-snapshot recovery. Installs the
Limine bootloader (registered as a separate NVRAM entry, ordered *after*
the UKI so the UKI stays the default), its AUR companions
(`limine-snapper-sync`, `limine-mkinitcpio-hook`), and `snapper` +
`snap-pac`. Configures a mandatory `root` snapshot config (pacman-triggered
via snap-pac, no timeline, 20-snapshot rollback window) and an optional
`home` config (timeline-driven — daily/weekly/monthly), provisioning the
`@snapshots`/`@home-snapshots` holder subvolumes and their fstab entries
if missing. Must be run as a non-root user (AUR tools can't build as root):
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-snapshots | bash
```

Fills the Limine `//Current` snapshot-boot template's cmdline from
`/etc/kernel/cmdline`, installs `post.d` hooks that strip `resume=` from
snapshot entries (and optionally flatten their submenus), enables
`limine-snapper-sync.service` (turns each new snapshot into a Limine boot
entry) and, for `home`, `snapper-timeline.timer`. Requires the
`configure-disk` layout (open `cryptroot`, btrfs `subvol=@`), the UKI and
`/etc/kernel/cmdline` from `configure-boot`, and `yay` (`install-yay`). The
Limine theme (monochrome HiDPI menu with a selectable bitmap font) is optional.

### user ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Create a new user with home dir, optional `/opt/<user>` workspace, and
an optional btrfs `@<user>-cache` subvolume mounted at `~/.cache` (no-CoW
via inherited `+C` attribute). Prompts for username and password, always
creates the user account, and asks which of the two optional steps
(workspace and cache subvolume) to run (both selected by default):
```bash
curl -fsSL https://dimk90.github.io/anarchy/create-user | bash
```

Run **before** the user's first login — apps populate `~/.cache` on
startup, and switching to a subvolume after that requires moving files.

### drivers ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Install hardware drivers grouped by category — Video (mesa + Intel GPU),
Input (libinput + IIO sensors), Power (tuned), Audio (PipeWire + ALSA),
Bluetooth (BlueZ + iwd), and Expansion (webcam, removable drives, MTP/PTP).
The script asks which categories to install (all selected by default) and
enables the relevant systemd services (`tuned`, `bluetooth`):
```bash
curl -fsSL https://dimk90.github.io/anarchy/install-drivers | bash
```

Vendor-specific GPU packages are installed only on Intel CPUs; AMD/NVIDIA
hosts get `mesa` plus a warning to install vendor drivers manually.

### vconsole ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Install and configure keymap, font, and locale for virtual console:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-vconsole | bash
```

### micro ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white) ![Ubuntu 24.04 LTS](https://img.shields.io/badge/Ubuntu_24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)

Install and configure the Micro text editor — settings, keybindings, default
editor, and clipboard support. The keybindings add a `movelines` Lua plugin that
fixes the view not scrolling when a selection is moved up past the top edge with
Alt+Up:
```bash
curl -fsSL https://dimk90.github.io/anarchy/install-micro | bash
```

### pacman ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Enable colors and install `reflector` for automatic mirror ranking:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-pacman | bash
```

### yay ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Install and configure `yay`:
```bash
curl -fsSL https://dimk90.github.io/anarchy/install-yay | bash
```

### alias ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white) ![Ubuntu 24.04 LTS](https://img.shields.io/badge/Ubuntu_24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)

Configure alias for common commands:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-alias | bash
```

### zram ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Configure zram using `zram-generator`:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-zram | bash
```

### swap ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)

Create a btrfs `@swap` subvolume at `/swap`, allocate a RAM-sized swap
file via `btrfs filesystem mkswapfile`, and optionally configure
hibernation (`resume=UUID=… resume_offset=…` appended to the UKI cmdline
+ `mkinitcpio -P` rebuild):
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-swap | bash
```

Disk swap is registered with `pri=10` so it sits below zram (`pri=100`
from `zram-generator.conf`) and only takes overflow plus the hibernation
image. Requires an open `/dev/mapper/cryptroot` btrfs filesystem;
hibernation also requires `/etc/kernel/cmdline` from `configure-boot`.

### prompt ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white) ![Ubuntu 24.04 LTS](https://img.shields.io/badge/Ubuntu_24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)

Install and configure `starship` prompt with a TERM-aware fallback for the
Linux console and a nerd-font variant for modern terminals. Fonts and fish
tweaks (colors, greeting, ctrl-arrow key bindings) are opt-out components
picked up front:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-prompt | bash
```

### modern-cli ![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white) ![Ubuntu 24.04 LTS](https://img.shields.io/badge/Ubuntu_24.04_LTS-E95420?style=flat-square&logo=ubuntu&logoColor=white)

Install and configure modern CLI replacements (`zoxide`, `bat`, `fd`, `ripgrep`,
`eza`, `fzf`, `git-delta`, `tldr`, `less`) with aliases, shell integrations,
and color themes for bash and fish:
```bash
curl -fsSL https://dimk90.github.io/anarchy/install-modern-cli | bash
```


## Tests


### color-test16

Test standard ANSI colors 0-15 (3 & 4 bit mode):
```bash
curl -fsSL https://dimk90.github.io/anarchy/color-test16 | bash
```

### color-test256

Test standard ANSI colors 8bit color:
```bash
curl -fsSL https://dimk90.github.io/anarchy/color-test256 | bash
```

### color-test-common

Test colors from `common` lib:
```bash
curl -fsSL https://dimk90.github.io/anarchy/color-test-common | bash
```


### color-gum

Test colors selected for `gum`:
```bash
curl -fsSL https://dimk90.github.io/anarchy/color-gum | bash
```
