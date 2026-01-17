# Anarchy

Highly disorganized personal configs and install scripts for Arch Linux.  


## Configs


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


### zram

Configure zram using `zram-generator`:
```bash
curl -fsSL https://dimk90.github.io/anarchy/copnfigure-zram | bash
```


### alias

Configure alias for common commands:
```bash
curl -fsSL https://dimk90.github.io/anarchy/copnfigure-alias | bash
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
