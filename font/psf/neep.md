# Neep PSF Console Font

Build a Linux vconsole (`setfont`) font from the **Neep** bitmap font in
[jmk-x11-fonts](https://github.com/nikolas/jmk-x11-fonts), packed to a 12×24
cell (≈ Terminus `ter-124`). Neep ships ready-made BDF bitmaps, so this is a
straight repack — not a rasterization. Box-drawing and block glyphs, which
Neep's ISO 8859-1 set lacks, are merged in from a donor font (Terminus).

> [!NOTE]
> Console font constraints:
>  - Keep the font at **256 glyphs** to retain the console's 16 colors (more
>    than 256 drops it to 8).
>  - Glyph height ≤ 32 px on kernels before 6.9 (raised to 64×128 in 6.9+);
>    24 px is safe everywhere.
>  - Neep is **ISO 8859-1 only** — no box-drawing/blocks. Without the donor
>    merge below, `┌─┐│` and `█▒▓` render blank in TUIs (`mc`, `btop`).

> [!TIP]
> The box-drawing donor must share the target's **exact cell geometry** (width,
> height, ascent, descent) or vertical rules won't reach the cell edges and
> won't tile. Terminus `ter-u24n` (12×24, asc 19 / desc 5) matches Neep exactly;
> Spleen `spleen-12x24` works too.


## Build

- Install dependencies:
    ```shell
    yay -S bdf2psf
    ```

- Get the source BDFs (both ship as BDF directly):
    - Neep 12×24: `neep-iso8859-1-12x24.bdf` from
      [jmk-x11-fonts](https://github.com/nikolas/jmk-x11-fonts) (a `-bold`
      variant is available if you prefer heavier text).
    - Donor: `ter-u24n.bdf` from the
      [Terminus source](https://terminus-font.sourceforge.net/), or
      `spleen-12x24.bdf` from Spleen's release.

- Confirm both fonts share the same cell, so the box-drawing tiles:
    ```shell
    grep -E '^(FONTBOUNDINGBOX|FONT_ASCENT|FONT_DESCENT)' neep-iso8859-1-12x24.bdf ter-u24n.bdf
    # both → FONTBOUNDINGBOX 12 24 / FONT_ASCENT 19 / FONT_DESCENT 5
    ```

- Pack into a PSF, merging the two BDFs. `bdf2psf` joins fonts with `+`; the
  **first font wins** per code point and later fonts fill gaps — so Neep keeps
  every letter and only borrows the box-drawing/blocks it lacks. The `Lat15.256`
  fontset (256 positions) keeps the console at 16 colors:
    ```shell
    bdf2psf --fb "neep-iso8859-1-12x24.bdf+ter-u24n.bdf" \
        /usr/share/bdf2psf/standard.equivalents \
        /usr/share/bdf2psf/fontsets/Lat15.256 256 \
        neep-12x24.psfu
    ```

    > [!NOTE]
    > `Lat15.256` maps the CP437 box-drawing/block subset the Linux console
    > actually uses (`┌┐└┘─│├┤┬┴┼`, `█▒▓`, `■▶◀`), not the full U+2500–257F —
    > 128 box characters can't coexist with Latin in 256 positions.

- Verify the cell and that nothing is missing:
    ```shell
    od -An -tu4 -j 24 -N 8 neep-12x24.psfu   # PSF2 height width → 24 12
    ```
    `bdf2psf` reports zero `no glyph defined` warnings once the donor covers the
    box-drawing/block positions in `Lat15.256`.

- Preview live on a tty (needs a real framebuffer console — not WSL or SSH):
    ```shell
    setfont neep-12x24.psfu
    ```
