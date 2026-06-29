#!/usr/bin/env python3
"""Convert a BDF bitmap font to Limine's raw console-font format.

Limine's `term_font` expects a headerless blob of 256 CP437-ordered glyphs,
8 px wide, 1 byte per row, top to bottom. Width is fixed at 8 (Limine ignores
the width in `term_font_size`), so the source BDF must be an 8-wide font.

Usage: bdf2limine.py SRC.bdf OUT.bin HEIGHT [DONOR.bdf]

An optional DONOR BDF (same 8-wide geometry) fills any CP437 position the
source font lacks — e.g. box-drawing/blocks for a Latin-only font. The source
wins wherever both define a glyph.
"""
import sys
from typing import NamedTuple


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


def main() -> int:
    args = sys.argv[1:]
    source_path, output_path, height = args[0], args[1], int(args[2])
    donor_path = args[3] if len(args) > 3 else None

    source = parse_bdf(source_path)
    if source.ascent is None:
        print(f'{source_path}: no FONT_ASCENT', file=sys.stderr)
        return 1
    source_ascent = source.ascent

    donor = parse_bdf(donor_path) if donor_path else None

    data = bytearray()
    donor_filled = 0
    for code in range(256):   # CP437 order
        unicode_point = ord(bytes([code]).decode('cp437', 'replace'))
        glyph = source.glyphs.get(unicode_point)
        ascent = source_ascent
        if glyph is None and donor is not None and unicode_point in donor.glyphs:
            glyph = donor.glyphs[unicode_point]
            ascent = donor.ascent if donor.ascent is not None else source_ascent
            donor_filled += 1
        data += bytes(render(glyph, ascent, height))

    with open(output_path, 'wb') as output_file:
        output_file.write(data)

    glyph_count = len(data) // height
    donor_note = f', {donor_filled} from donor' if donor_path else ''
    print(
        f'{output_path}: {len(data)} bytes = {glyph_count} glyphs x {height} rows '
        f'(ascent {source_ascent}{donor_note})'
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
