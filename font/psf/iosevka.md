# PSF Console Font

Build a Linux vconsole (`setfont`) font from the custom
[Iosevka](../Iosevka/build/Iosevka.md) build. The pipeline rasterizes the
scalable `IosevkaTerm.ttc` to a fixed-size bitmap and packs it into a PSF,
sized to a 13×28 cell (≈ Terminus `ter-128b`).

> [!NOTE]
> Console fonts are bitmaps, not outlines, so this is a rasterization, not a
> format conversion. Constraints:
>  - Max 512 glyphs per font (using more than 256 drops the console from 16 to
>    8 colors).
>  - Glyph height ≤ 32 px on kernels before 6.9 (raised to 64×128 in 6.9+).
>  - No antialiasing — the console is 1-bit, so jagged curves are inherent; a
>    larger cell and dehinted outlines (steps below) reduce visible aliasing.

> [!TIP]
> Iosevka **Term** keeps every glyph inside its cell box (no overhang), which is
> exactly what a fixed bitmap cell needs.


## Build

- Install dependencies:
    ```shell
    yay -S otf2bdf bdf2psf ttfautohint
    ```

    ```shell
    uv tool install fonttools
    ```

- List the faces in the collection to find the weight index:
    ```shell
    fc-scan --format='%{index}\t%{fullname}\n' ../Iosevka/IosevkaTerm.ttc
    ```

- Extract the Medium face to a TTF. `otf2bdf` can't index a `.ttc`, so
  round-trip the face through `ttx` (index `6` = `Medium Semi-Extended,Regular`):
    ```shell
    ttx -y 6 -f -o /tmp/IosevkaTerm-Medium.ttx ../Iosevka/IosevkaTerm.ttc
    ```

    ```shell
    ttx -f -o /tmp/IosevkaTerm-Medium.ttf /tmp/IosevkaTerm-Medium.ttx
    ```

- Strip the built-in hints. Iosevka ships ttfautohint's vertical-only hints,
  tuned for antialiased screens; removing them lets FreeType's autohinter
  grid-fit both axes for the 1-bit console target, which renders noticeably
  crisper:
    ```shell
    ttfautohint --dehint /tmp/IosevkaTerm-Medium.ttf /tmp/IosevkaTerm-Medium-nohint.ttf
    ```

- Rasterize to a 28 px-tall bitmap (BDF). `otf2bdf` renders *every* glyph and
  unions their extents, so Iosevka's oversized glyphs (big braces, integrals)
  inflate the bounding box. Restrict the output to the code points the console
  font needs with `-l`, and size with `-r 72 -p 24` so the cell lands on 13×28:
    ```shell
    otf2bdf -r 72 -p 24 \
        -l "32_126 160_383 9472_9631" \
        -o /tmp/iosevka-term-28.bdf /tmp/IosevkaTerm-Medium-nohint.ttf
    ```

    > [!IMPORTANT]
    > `-l` ranges are **decimal only** (no `0x`). The ones above are ASCII
    > (`32_126`), Latin-1 + Latin-Ext-A (`160_383`), and box-drawing + blocks
    > (`9472_9631`). Add more decimal ranges to cover punctuation (`8192_8303`),
    > currency (`8352_8399`), arrows (`8592_8703`), etc.

- Verify the cell. `bdf2psf` sizes the PSF from `FONT_ASCENT + FONT_DESCENT`
  (height) and `DWIDTH` (width) — *not* `FONTBOUNDINGBOX`. Want the sum ≈ 28 and
  `DWIDTH` ≈ 13; nudge `-p` if off:
    ```shell
    grep -c '^STARTCHAR' /tmp/iosevka-term-28.bdf                  # a few hundred glyphs
    grep -e 'FONT_ASCENT|FONT_DESCENT' /tmp/iosevka-term-28.bdf    # sum ≈ 28
    grep -m1 DWIDTH /tmp/iosevka-term-28.bdf                       # ≈ 13
    ```

- Patch the width metric. `otf2bdf` writes `AVERAGE_WIDTH` as the *average ink*
  width, not the fixed advance, so `bdf2psf` would build too narrow a cell and
  clip glyphs. Set it to `DWIDTH × 10` (13 → 130):
    ```shell
    sed -i 's/^AVERAGE_WIDTH .*/AVERAGE_WIDTH 130/' /tmp/iosevka-term-28.bdf
    ```

- Pack into a PSF (fixed-width, 512-glyph Latin set):
    ```shell
    bdf2psf --fb /tmp/iosevka-term-28.bdf \
        /usr/share/bdf2psf/standard.equivalents \
        /usr/share/bdf2psf/fontsets/Uni2.512 512 \
        /tmp/iosevka-term-28.psf
    ```

    ```shell
    od -An -tu4 -j 24 -N 8 /tmp/iosevka-term-28.psf   # PSF2 height width → 28 13
    ```

    > [!NOTE]
    > Residual `no glyph defined` warnings are for `Uni2.512` code points outside
    > the rendered `-l` ranges — those cells stay blank; widen `-l` to cover them.
    > If the data paths error, list `/usr/share/bdf2psf/fontsets/`.

- Preview live on a tty (needs a real framebuffer console — not WSL or SSH):
    ```shell
    setfont /tmp/iosevka-term-28.psf
    ```
