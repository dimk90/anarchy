# ProFont PSF Console Font

Build a Linux vconsole (`setfont`) font from **ProFont** by
[Tobias Jung](https://tobiasjung.name/profont/index.php?fs=24), packed to a
16×32 cell (≈ Terminus `ter-132`). ProFont ships as PCF bitmaps, so this is a
repack — not a rasterization. Box-drawing and block glyphs, absent from
ProFont's ISO 8859-1 set, are merged in from a donor font (Terminus).

> [!NOTE]
> Console font constraints:
>  - Keep the font at **256 glyphs** to retain the console's 16 colors (more
>    than 256 drops it to 8).
>  - Glyph height ≤ 32 px on kernels before 6.9 (raised to 64×128 in 6.9+);
>    32 px is the safe maximum.
>  - ProFont is **ISO 8859-1 only** — no box-drawing/blocks. They are borrowed
>    from the donor merge below.

> [!IMPORTANT]
> ProFont's tallest size rasterizes to a **16×29** cell, but the box-drawing
> donor is 16×32 (no 16×29 donor exists). Pad ProFont to 16×32 (below) so the
> donor's glyphs fill the cell edge-to-edge and tile. Padding only adds blank
> rows below the text — it does not distort ProFont.


## Build

- Install dependencies:
    ```shell
    yay -S bdf2psf pcf2bdf
    ```

- Get the sources:
    - ProFont 24 pt — `ProFont_r400-29.pcf` (a 16×29 bitmap) from
      [tobiasjung.name/profont](https://tobiasjung.name/profont/index.php?fs=24).
    - Donor: `ter-u32n.bdf` from the
      [Terminus source](https://terminus-font.sourceforge.net/), or
      `spleen-16x32.bdf` from Spleen's release (both 16×32, asc 26 / desc 6).

- Convert ProFont's PCF to BDF (`bdf2psf` needs BDF input):
    ```shell
    pcf2bdf ProFont_r400-29.pcf > /tmp/profont-29.bdf
    ```

- Patch the width metric. `pcf2bdf` omits `AVERAGE_WIDTH`, which `bdf2psf` reads
  to size the cell width — without it the pack fails with
  `width 0 zero or too big`. Set it to `width × 10` (16 → 160):
    ```shell
    sed -i -e 's/^STARTPROPERTIES 15/STARTPROPERTIES 16/' \
           -e 's/^FONT_ASCENT 24/AVERAGE_WIDTH 160\nFONT_ASCENT 24/' \
           /tmp/profont-29.bdf
    ```

- Pad the cell 16×29 → 16×32 to match the donor. Raising `FONT_ASCENT` /
  `FONT_DESCENT` only adds blank rows (glyphs stay on the baseline); it lets the
  16×32 box-drawing tile without distorting ProFont:
    ```shell
    sed -i -e 's/^FONTBOUNDINGBOX 16 29 0 -5/FONTBOUNDINGBOX 16 32 0 -6/' \
           -e 's/^FONT_ASCENT 24/FONT_ASCENT 26/' \
           -e 's/^FONT_DESCENT 5/FONT_DESCENT 6/' \
           /tmp/profont-29.bdf
    ```

    > [!TIP]
    > The donor must share the **exact** padded geometry (16×32, asc 26 /
    > desc 6) or vertical box rules won't reach the cell edges. Confirm:
    > ```shell
    > grep -E '^(FONTBOUNDINGBOX|FONT_ASCENT|FONT_DESCENT)' /tmp/profont-29.bdf ter-u32n.bdf
    > ```

- Pack into a PSF, merging the two BDFs. `bdf2psf` joins fonts with `+`; the
  **first font wins** per code point and later fonts fill gaps — ProFont keeps
  every letter and only borrows the box-drawing/blocks it lacks. The `Lat15.256`
  fontset (256 positions) keeps the console at 16 colors:
    ```shell
    bdf2psf --fb "/tmp/profont-29.bdf+ter-u32n.bdf" \
        /usr/share/bdf2psf/standard.equivalents \
        /usr/share/bdf2psf/fontsets/Lat15.256 256 \
        profont-16x32.psfu
    ```

    > [!NOTE]
    > `Lat15.256` maps the CP437 box-drawing/block subset the Linux console
    > actually uses (`┌┐└┘─│├┤┬┴┼`, `█▒▓`, `■▶◀`), not the full U+2500–257F —
    > 128 box characters can't coexist with Latin in 256 positions.

- Verify the cell and that nothing is missing:
    ```shell
    od -An -tu4 -j 24 -N 8 profont-16x32.psfu   # PSF2 height width → 32 16
    ```
    `bdf2psf` reports zero `no glyph defined` warnings once the donor covers the
    box-drawing/block positions in `Lat15.256`.

- Preview live on a tty (needs a real framebuffer console — not WSL or SSH):
    ```shell
    setfont profont-16x32.psfu
    ```
