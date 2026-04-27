# Anarchy

Highly disorganized personal configs and install scripts for Arch Linux.  


## Configs


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
