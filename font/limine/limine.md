# Limine Console Fonts

Build raw bitmap fonts for the
[Limine](https://github.com/limine-bootloader/limine) boot menu (`term_font`)
from 8-wide BDF bitmaps. Unlike the [PSF console fonts](../psf/), Limine uses its
own headerless format, so these are a separate build.

> [!IMPORTANT]
> Limine's `term_font` is **not** PSF. It is a raw, headerless blob of **256
> CP437-ordered glyphs, 8 px wide, 1 byte per row**, top to bottom. The width is
> **hard-locked to 8** — Limine ignores the width in `term_font_size`, so only
> 8-wide source fonts work; 12/14/16-wide console fonts cannot be used. For
> HiDPI, scale an 8×16 font up with `term_font_scale: 2x2` rather than reaching
> for a taller font.

> [!NOTE]
> Ordering and coverage:
>  - Glyphs are emitted in **CP437 order** (ASCII at 0x20–0x7E, box-drawing at
>    0xB0–0xDF, blocks like `█` at 0xDB) — the layout Limine expects.
>  - The IBM-PC **graphic glyphs at 0x01–0x1F and 0x7F** (arrows, triangles) are
>    included, not blanked — Limine draws `►` (0x10) as the expandable-entry
>    marker, so a blank there leaves that menu indicator invisible.
>  - A font only renders the CP437 glyphs it actually contains. Terminus covers
>    the full set; **Spleen** lacks the `►`/`◄` pointers and **ProFont** is
>    ISO 8859-1 (no box-drawing), so both are completed from a Terminus donor.


## Fonts

| File | Source | Coverage |
|---|---|---|
| `terminus-8x16.bin` | Terminus `ter-u16b` (8×16, **bold**) | full CP437 |
| `spleen-8x16.bin` | Spleen `spleen-8x16` (8×16) + Terminus donor | full CP437; `►`/`◄` from Terminus |
| `profont-8x16.bin` | ProFont `r400-15` (7×15, padded) + Terminus donor | Latin from ProFont; box-drawing/arrows from Terminus |

> [!NOTE]
> Only the **bold** Terminus face (`ter-u16b`) is shipped — the normal weight is
> too thin to read on the boot menu. Spleen and ProFont are single-weight, so
> they have no bold variant.

> [!NOTE]
> ProFont has **no 8-wide size** (its widths are 5, 6, 7, 12, 14, 16). The 7×15
> face is the only one that fits an 8 px cell; it is left-aligned in the cell
> (1 px gap on the right) and padded to 16 rows. Being ISO 8859-1 it has no
> box-drawing, so those CP437 positions are merged from the Terminus donor.
> Scale it `2x2` for HiDPI.


## Build

- Install dependencies (only ProFont needs `pcf2bdf`; its source is PCF):
    ```shell
    yay -S pcf2bdf
    ```

- Get 8-wide BDF sources:
    - Terminus `ter-u16b.bdf` (bold — the menu font) and `ter-u16n.bdf` (used
      only as the gap-filling donor) from the
      [Terminus source](https://terminus-font.sourceforge.net/).
    - Spleen `spleen-8x16.bdf` from the
      [Spleen source](https://github.com/fcambus/spleen).
    - ProFont `r400-15` from
      [tobiasjung.name/profont](https://tobiasjung.name/profont/index.php?fs=24&pf=on)
      — convert the 7×15 PCF to BDF:
      ```shell
      pcf2bdf ProFont_r400-15.pcf > /tmp/profont-15.bdf
      ```

- Convert each to Limine's raw format with [`bdf2limine.py`](bdf2limine.py). It
  reorders glyphs to CP437 (via Python's built-in `cp437` codec) and packs them
  8-wide, 1 byte per row. Args: `SRC.bdf OUT.bin HEIGHT [DONOR.bdf]` — an
  optional donor fills any CP437 glyph the source lacks (source wins), the same
  merge as the PSF [ProFont build](../psf/profont.md):
    ```shell
    python3 bdf2limine.py ter-u16b.bdf        terminus-8x16.bin 16
    python3 bdf2limine.py spleen-8x16.bdf     spleen-8x16.bin        16 ter-u16n.bdf
    python3 bdf2limine.py /tmp/profont-15.bdf profont-8x16.bin       16 ter-u16n.bdf
    ```

- Verify each file is 256 × 16 = **4096 bytes**:
    ```shell
    ls -l *.bin
    ```

    > [!TIP]
    > To spot-check a glyph, render one back — e.g. CP437 `0xC9 ╔` should be a
    > double top-left corner, `0xDB █` a full cell. `bdf2limine.py`'s `render()`
    > does exactly this placement; a few lines of Python reading the `.bin` at
    > offset `idx*16` confirms it.


## Use in Limine

Copy the chosen `.bin` to the ESP next to `limine.conf`, then set these global
options (top of the config):

```ini
term_font: boot():/terminus-8x16.bin
term_font_size: 8x16
term_font_scale: 2x2                       # 16x32 effective — for HiDPI
```
