# Iosevka

Custom build of [Iosevka](https://github.com/be5invis/Iosevka) font.

> [!NOTE]
>  - https://typeof.net/Iosevka/customizer  
>  - https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md


## Build

- Install dependencies:
    ```shell
    sudo pacman -S npm woff2
    ```

    ```shell
    yay -S ttfautohint
    ```

- Clone iosevka repo:
    ```shell
    git clone --depth 1 https://github.com/be5invis/Iosevka.git
    ```

- Install npm dependencies:
    ```shell
    cd iosevka && npm install
    ```

- Get custom config:
    ```shell
    curl -fL -o private-build-plans.toml "https://dimk90.github.io/anarchy/font/Iosevka/build/private-build-plans.toml"
    ```

- Build font:
    ```shell
    npm run build -- webfont::IosevkaCode --jCmd=4
    ```

    ```shell
    npm run build -- webfont::IosevkaText --jCmd=4
    ```

    ```shell
    npm run build -- webfont::IosevkaTerm --jCmd=4
    ```

    > [!TIP]
    > Verbose build:
    > ```shell
    > npm run build --loglevel verbose -- webfont::IosevkaCustom --jCmd=1 --verbosity 100
    > ```


### Missing Symbols Donation

Iosevka lacks some Unicode symbols, e.g. draughts `⛀⛁⛂⛃`, chess `♔♕♖♗♘♙` and recycling `♲♻♼`.
Take them from [Noto Sans Symbols](https://fonts.google.com/noto/specimen/Noto+Sans+Symbols)
and [Noto Sans Symbols 2](https://fonts.google.com/noto/specimen/Noto+Sans+Symbols+2)
during the [Nerd Font Patch](#nerd-font-patch). The two fonts cover different symbols, so both are needed.

[donor-unicodes.txt](donor-unicodes.txt) lists the donated code points: symbols useful in a terminal
that the Noto fonts have but patched Iosevka Term lacks.
Wide (emoji) symbols are excluded: terminals give them two cells, but the patch makes them one cell wide.

> [!TIP]
> Preview the glyphs: drop a font file on https://fontdrop.info, or render a few symbols locally:
> ```shell
> hb-view NotoSansSymbols-Regular.ttf '♲♻♼☮☯' -o preview.png
> ```

- Install fonttools:
    ```shell
    uv tool install fonttools
    ```

- Get the donor fonts:
    ```shell
    curl -fL -o NotoSansSymbols-Regular.ttf https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansSymbols/unhinted/ttf/NotoSansSymbols-Regular.ttf
    ```

    ```shell
    curl -fL -o NotoSansSymbols2-Regular.ttf https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansSymbols2/unhinted/ttf/NotoSansSymbols2-Regular.ttf
    ```

- Get the code point list:
    ```shell
    curl -fL -o donor-unicodes.txt https://dimk90.github.io/anarchy/font/Iosevka/build/donor-unicodes.txt
    ```

- Keep only the missing symbols, `--custom` copies every glyph of the donor font:
    ```shell
    fonttools subset NotoSansSymbols-Regular.ttf --unicodes-file=donor-unicodes.txt \
        --glyph-names --output-file=NotoSansSymbols-Donor.ttf
    ```

    ```shell
    fonttools subset NotoSansSymbols2-Regular.ttf --unicodes-file=donor-unicodes.txt \
        --glyph-names --output-file=NotoSansSymbols2-Donor.ttf
    ```

- Merge them into one donor font, `--custom` accepts only one font:
    ```shell
    fonttools merge --output-file=Donor.ttf NotoSansSymbols-Donor.ttf NotoSansSymbols2-Donor.ttf
    ```


### Nerd Font Patch


Patch Iosevka Term with [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) glyphs
and the [donated symbols](#missing-symbols-donation).
`--makegroups -1` keeps the original font names (`Iosevka Term`) instead of adding `Nerd Font Mono`.
Iosevka and Noto use the SIL Open Font License without a Reserved Font Name, so renaming is not required.

- Install FontForge:
    ```shell
    sudo pacman -S fontforge
    ```

- Get the font patcher:
    ```shell
    mkdir font-patcher
    ```

    ```shell
    curl -fL -o font-patcher/FontPatcher.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FontPatcher.zip
    ```

    ```shell
    bsdtar -xf font-patcher/FontPatcher.zip -C font-patcher
    ```

- Patch the fonts:
    ```shell
    mkdir -p IosevkaTerm/NerdFontMono
    ```

    Patch every face of the build:
    ```shell
    for font in IosevkaTerm/TTF/*.ttf; do
        fontforge -script font-patcher/font-patcher --mono --complete --careful --makegroups -1 \
            --custom "$PWD/Donor.ttf" --outputdir IosevkaTerm/NerdFontMono "$font"
    done
    ```


### TTC Font Package

Packages are useful for system-wide installation.

```shell
uv tool install afdko
```

```shell
otf2otc -o IosevkaCode/IosevkaCode.ttc IosevkaCode/TTF/*.ttf
```

```shell
otf2otc -o IosevkaText/IosevkaText.ttc IosevkaText/TTF/*.ttf
```

Iosevka Term is packed from the [patched fonts](#nerd-font-patch):
```shell
otf2otc -o IosevkaTerm/IosevkaTerm.ttc IosevkaTerm/NerdFontMono/*.ttf
```


## TODO

- Add instruction for woff patching;
