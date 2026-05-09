# Anarchy

Highly disorganized personal configs and install scripts for Arch Linux.  


## Configs


### wipe-disk

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

### disk

Partition the target disk and prepare mount points for an Arch install
(GPT + LUKS2 + btrfs subvolumes). Must be run as root from the live USB.
The script scans available disks, asks the user to pick one, refuses to
proceed unless the disk is empty, and optionally runs `genfstab` at the end:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-disk | bash
```

Resulting layout:

| Part | Size     | Encryption | Filesystem | Label    | Subvolume         | Mount point        |
| :--: | :------- | :--------- | :--------- | :------- | :---------------- | :----------------- |
|  p1  | 512 MiB  | —          | FAT32      | —        | —                 | `/efi`             |
|  p2  | 2 GiB    | —          | btrfs      | `boot`   | `@boot`           | `/boot`            |
|  p2  | (shared) | —          | btrfs      | `boot`   | `@boot-snapshots` | `/boot/.snapshots` |
|  p3  | rest     | LUKS2      | btrfs      | `rootfs` | `@`               | `/`                |
|  p3  | (shared) | LUKS2      | btrfs      | `rootfs` | `@home`           | `/home`            |
|  p3  | (shared) | LUKS2      | btrfs      | `rootfs` | `@log`            | `/var/log`         |
|  p3  | (shared) | LUKS2      | btrfs      | `rootfs` | `@cache`          | `/var/cache`       |
|  p3  | (shared) | LUKS2      | btrfs      | `rootfs` | `@snapshots`      | `/.snapshots`      |

The encrypted partition is opened as `/dev/mapper/cryptroot`.
Btrfs is mounted with `noatime,ssd,compress=zstd:1,space_cache=v2`
(and `commit=120` on non-root subvolumes).

### boot

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
manually).

### user

Create a new user with home dir, optional `/opt/<user>` workspace, and
an optional btrfs `@<user>-cache` subvolume mounted at `~/.cache` (no-CoW
via inherited `+C` attribute). Prompts for username and password and
asks which steps to run (all selected by default):
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-user | bash
```

Run **before** the user's first login — apps populate `~/.cache` on
startup, and switching to a subvolume after that requires moving files.

### drivers

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

### vconsole

Install and configure keymap, font, and locale for virtual console:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-vconsole | bash
```

### micro

Install and configure Micro text editor:
```bash
curl -fsSL https://dimk90.github.io/anarchy/install-micro | bash
```

### pacman

Enable colors and install `reflector` for automatic mirror ranking:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-pacman | bash
```

### yay

Install and configure `yay`:
```bash
curl -fsSL https://dimk90.github.io/anarchy/install-yay | bash
```

### alias

Configure alias for common commands:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-alias | bash
```

### zram

Configure zram using `zram-generator`:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-zram | bash
```

### swap

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

### prompt

Install and configure `starship` prompt with a TERM-aware fallback for the
Linux console and a nerd-font variant for modern terminals:
```bash
curl -fsSL https://dimk90.github.io/anarchy/configure-prompt | bash
```

### modern-cli

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
