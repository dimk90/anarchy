# Font Versions

Version of the upstream source each font is built from.
Update the row when a font is rebuilt, and name the version in the commit message.

> [!TIP]
> Check the version of a scalable font (`.ttf`, `.ttc`, `.woff2`):
> ```shell
> uv run -q --no-project --with fonttools --with brotli python -c \
>     'import sys; from fontTools.ttLib import TTFont; print(TTFont(sys.argv[1], fontNumber=0)["name"].getDebugName(5))' \
>     Iosevka/IosevkaTerm.ttc
> ```
> Bitmap fonts (`.psf`, `.psfu`, Limine `.bin`) carry no version, see the table below.


## Scalable Fonts

| Font             | Files                                                    | Version                                                                    | Updated    | Build                                        |
| ---------------- | -------------------------------------------------------- | -------------------------------------------------------------------------- | ---------- | -------------------------------------------- |
| Iosevka Code     | `Iosevka/IosevkaCode.ttc`, `Iosevka/IosevkaCode-*.woff2` | Iosevka 34.2.1                                                             | 2026-05-17 | [Iosevka.md](Iosevka/build/Iosevka.md)       |
| Iosevka Term     | `Iosevka/IosevkaTerm.ttc`                                | Iosevka 34.2.1                                                             | 2026-05-17 | [Iosevka.md](Iosevka/build/Iosevka.md)       |
| Iosevka Text     | `Iosevka/IosevkaText.ttc`, `Iosevka/IosevkaText-*.woff2` | Iosevka 34.2.0                                                             | 2026-05-17 | [Iosevka.md](Iosevka/build/Iosevka.md)       |
| Noto Color Emoji | `NotoEmoji/NotoColorEmoji.sbix*.ttf`                     | [akb2/noto-emoji](https://github.com/akb2/noto-emoji) fork, unknown commit | 2026-05-17 | [NotoEmoji.md](NotoEmoji/build/NotoEmoji.md) |


## Bitmap Fonts

| Font             | Files                                       | Version             | Updated    | Build                         |
| ---------------- | ------------------------------------------- | ------------------- | ---------- | ----------------------------- |
| Iosevka Term PSF | `psf/iosevka-term-28.psf`                   | Iosevka Term 34.2.1 | 2026-06-28 | [iosevka.md](psf/iosevka.md)  |
| Neep PSF         | `psf/neep-12x24.psfu`                       | unknown             | 2026-06-29 | [neep.md](psf/neep.md)        |
| ProFont PSF      | `psf/profont-16x32.psfu`                    | unknown             | 2026-06-29 | [profont.md](psf/profont.md)  |
| Spleen PSF       | `psf/spleen-*.psfu`                         | unknown             | 2026-06-28 | —                             |
| Limine fonts     | `limine/{profont,spleen,terminus}-8x16.bin` | unknown             | 2026-06-30 | [limine.md](limine/limine.md) |
