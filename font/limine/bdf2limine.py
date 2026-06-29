#!/usr/bin/env python3
"""Convert a BDF bitmap font to Limine's raw console-font format.

Limine's `term_font` expects a headerless blob of 256 CP437-ordered glyphs,
8 px wide, 1 byte per row, top to bottom. Width is fixed at 8 (Limine ignores
the width in `term_font_size`), so the source BDF must be an 8-wide font.

Usage: bdf2limine.py SRC.bdf OUT.bin HEIGHT [DONOR.bdf] [--bold]

An optional DONOR BDF (same 8-wide geometry) fills any CP437 position the
source font lacks — e.g. box-drawing/blocks for a Latin-only font. The source
wins wherever both define a glyph. `--bold` synthetically emboldens the source
glyphs (not the donor) for fonts that ship no real bold face.
"""
import sys
from typing import NamedTuple

# CP437 bytes 0x01-0x1F and 0x7F hold graphic glyphs (arrows, triangles, card
# suits) that Python's `cp437` codec instead maps to control characters. Limine
# draws some of them as menu indicators — notably U+25BA (right triangle) for an
# expandable entry — so map the whole range to its graphic code points.
CP437_GRAPHICS: dict[int, int] = {
    0x01: 0x263A, 0x02: 0x263B, 0x03: 0x2665, 0x04: 0x2666,
    0x05: 0x2663, 0x06: 0x2660, 0x07: 0x2022, 0x08: 0x25D8,
    0x09: 0x25CB, 0x0A: 0x25D9, 0x0B: 0x2642, 0x0C: 0x2640,
    0x0D: 0x266A, 0x0E: 0x266B, 0x0F: 0x263C, 0x10: 0x25BA,
    0x11: 0x25C4, 0x12: 0x2195, 0x13: 0x203C, 0x14: 0x00B6,
    0x15: 0x00A7, 0x16: 0x25AC, 0x17: 0x21A8, 0x18: 0x2191,
    0x19: 0x2193, 0x1A: 0x2192, 0x1B: 0x2190, 0x1C: 0x221F,
    0x1D: 0x2194, 0x1E: 0x25B2, 0x1F: 0x25BC, 0x7F: 0x2302,
}

# Near-equivalent code points to try when a font lacks the exact glyph — e.g.
# the CP437 pointers U+25BA/U+25C4 vs the more common triangles U+25B6/U+25C0.
GLYPH_EQUIVALENTS: dict[int, tuple[int, ...]] = {
    0x25BA: (0x25B6, 0x25B8),
    0x25C4: (0x25C0, 0x25C2),
}


class BBox(NamedTuple):
    """
    A BDF glyph bounding box: pixel size plus offset from the origin.
    """
    width: int
    height: int
    x_offset: int
    y_offset: int


class Glyph(NamedTuple):
    """
    A single glyph: its bounding box and one packed int per pixel row.
    """
    bbox: BBox
    rows: list[int]


class ParsedFont(NamedTuple):
    """
    The result of parsing a BDF: glyphs keyed by Unicode code point, plus the
    font-wide ascent and descent (None if the BDF omitted them).
    """
    glyphs: dict[int, Glyph]
    ascent: int | None
    descent: int | None


def parse_bdf(path: str) -> ParsedFont:
    """
    Parse a BDF font file into glyphs keyed by their Unicode code point.

    The font-wide ascent and descent are returned alongside the glyphs; they
    position each glyph vertically within a fixed cell.
    """
    glyphs: dict[int, Glyph] = {}
    ascent: int | None = None
    descent: int | None = None
    encoding: int | None = None
    bbox: BBox | None = None
    bitmap_rows: list[int] | None = None
    in_bitmap = False
    with open(path, 'r', errors='replace') as font_file:
        for line in font_file:
            fields = line.split()
            if not fields:
                continue
            keyword = fields[0]
            match keyword:
                case 'FONT_ASCENT':
                    ascent = int(fields[1])
                case 'FONT_DESCENT':
                    descent = int(fields[1])
                case 'ENCODING':
                    encoding = int(fields[1])
                case 'BBX':
                    bbox = BBox(int(fields[1]), int(fields[2]), int(fields[3]), int(fields[4]))
                case 'BITMAP':
                    bitmap_rows, in_bitmap = [], True
                case 'ENDCHAR':
                    in_bitmap = False
                    if encoding is not None and encoding >= 0 and bbox is not None:
                        glyphs[encoding] = Glyph(bbox, bitmap_rows or [])
                    encoding = bbox = bitmap_rows = None
                case _ if in_bitmap and bitmap_rows is not None:
                    bitmap_rows.append(int(keyword, 16))
    return ParsedFont(glyphs, ascent, descent)


def cp437_code_point(byte_value: int) -> int:
    """
    Map a CP437 byte to its Unicode code point.

    Uses the graphic glyphs for the 0x01-0x1F and 0x7F range that Python's
    `cp437` codec would otherwise decode as control characters.
    """
    if byte_value in CP437_GRAPHICS:
        return CP437_GRAPHICS[byte_value]
    return ord(bytes([byte_value]).decode('cp437', 'replace'))


def find_glyph(glyphs: dict[int, Glyph], code_point: int) -> Glyph | None:
    """
    Look up a glyph by code point, falling back to near-equivalent code points
    (e.g. a different triangle) when the exact one is absent.
    """
    if code_point in glyphs:
        return glyphs[code_point]
    for alternative in GLYPH_EQUIVALENTS.get(code_point, ()):
        if alternative in glyphs:
            return glyphs[alternative]
    return None


def render(glyph: Glyph | None, ascent: int, height: int) -> list[int]:
    """
    Rasterize one glyph into an 8-wide by `height` cell.

    Each returned int is a row of 8 pixels with the most significant bit as the
    leftmost pixel. A missing glyph yields a blank cell.
    """
    cell = [0] * height
    if glyph is None:
        return cell
    bbox, rows = glyph
    top = ascent - bbox.y_offset - bbox.height   # blank rows above the bounding box
    row_bytes = (bbox.width + 7) // 8
    for row_index in range(min(bbox.height, len(rows))):
        cell_y = top + row_index
        if not 0 <= cell_y < height:
            continue
        leftmost_byte = (rows[row_index] >> ((row_bytes - 1) * 8)) & 0xFF
        for pixel in range(min(bbox.width, 8)):
            if leftmost_byte & (0x80 >> pixel):
                cell_x = bbox.x_offset + pixel
                if 0 <= cell_x < 8:
                    cell[cell_y] |= 0x80 >> cell_x
    return cell


def embolden(cell: list[int]) -> list[int]:
    """
    Thicken each row by one pixel to the right for an artificial bold weight.

    OR-ing a row with itself shifted one pixel right widens vertical strokes;
    it is meant for fonts that ship no real bold face.
    """
    return [row | (row >> 1) for row in cell]


def main() -> int:
    args = sys.argv[1:]
    bold = '--bold' in args
    positional = [arg for arg in args if not arg.startswith('--')]
    source_path, output_path, height = positional[0], positional[1], int(positional[2])
    donor_path = positional[3] if len(positional) > 3 else None

    source = parse_bdf(source_path)
    if source.ascent is None:
        print(f'{source_path}: no FONT_ASCENT', file=sys.stderr)
        return 1
    source_ascent = source.ascent

    donor = parse_bdf(donor_path) if donor_path else None

    data = bytearray()
    donor_filled = 0
    for code in range(256):   # CP437 order
        code_point = cp437_code_point(code)
        glyph = find_glyph(source.glyphs, code_point)
        if glyph is not None:
            cell = render(glyph, source_ascent, height)
            if bold:
                cell = embolden(cell)
        else:
            cell = [0] * height
            if donor is not None:
                donor_glyph = find_glyph(donor.glyphs, code_point)
                if donor_glyph is not None:
                    donor_ascent = donor.ascent if donor.ascent is not None else source_ascent
                    cell = render(donor_glyph, donor_ascent, height)
                    donor_filled += 1
        data += bytes(cell)

    with open(output_path, 'wb') as output_file:
        output_file.write(data)

    glyph_count = len(data) // height
    donor_note = f', {donor_filled} from donor' if donor_path else ''
    bold_note = ', bold' if bold else ''
    print(
        f'{output_path}: {len(data)} bytes = {glyph_count} glyphs x {height} rows '
        f'(ascent {source_ascent}{donor_note}{bold_note})'
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
