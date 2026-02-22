# Noto Color Emoji

Custom build of [Noto Color Emoji](https://fonts.google.com/noto/specimen/Noto+Color+Emoji/glyphs) font:
- `SBIX` version for iOS/Mac compatibility.
- Fixed `VS16` unicode modifier (B&W emoji version).

# Formats

https://learn.microsoft.com/en-us/typography/opentype/spec/otff

## TTF-based formats (.ttf extension)
- **glyf** - Standard monochrome TrueType
- **glyf_colr_0** - TrueType + COLRv0 color table
- **glyf_colr_1** - TrueType + COLRv1 color table
- **sbix** - TrueType + Apple's bitmap color table
- **cbdt** - TrueType + Google's bitmap color table

## OTF-based formats (.otf extension)
- **cff_colr_0** - CFF + COLRv0 color table
- **cff_colr_1** - CFF + COLRv1 color table
- **cff2_colr_0** - CFF2 + COLRv0 color table
- **cff2_colr_1** - CFF2 + COLRv1 color table

## SVG-based (can be either .ttf or .otf)
- **untouchedsvg** / **untouchedsvgz** - Keeps original SVG data in the SVG table, paired with either glyf (TTF) or CFF (OTF)
- **picosvg** / **picosvgz** - Optimized SVG in the SVG table, paired with either glyf (TTF) or CFF (OTF)

## Apple Support

- **sbix** - Apple's native color font format, supported since iOS 4. Uses bitmap images (PNG, JPEG, TIFF) embedded in the font.
- **glyf_colr_1** (COLRv1) - Supported starting with iOS 12 when Apple added OpenType-SVG support. However, note that iOS 17 appears to have deprecated COLRv0 support, though COLRv1 support status on iOS is unclear.
- **SVG-based formats** (untouchedsvg/untouchedsvgz) - OpenType-SVG is supported on iOS 12 and later.

- [We know](https://github.com/googlefonts/noto-emoji/issues/438#issuecomment-2060919955) Apple platform does not currently support COLRv1, only sbix, OT-SVG and COLRv0;
- **cbdt** - Google's format with native support primarily on Android;
- **COLR/CPAL v0 formats** (cff2_colr_0, cff_colr_0, glyf_colr_0) - Had some support but may be deprecated on newer iOS versions;
- **glyf** - Standard monochrome format (works but no color);
- **cff2_colr_1, cff_colr_1** - Limited documentation on iOS support;
- **picosvg/picosvgz** - Optimized SVG variants, unclear iOS support;


# Compatibility

|      |        |      | Android | Windows |           iOS/Mac            |
| ---- | ------ | :--: | :-----: | :-----: | :--------------------------: |
| cbdt |        | .ttf | Native  |    ?    |              x               |
| sbix |        | .ttf |    ?    |    x    |       Native, iOS >= 4       |
| cff2 | colr_1 | .otf |    ?    |    x    |              ?               |
| cff2 | colr_0 | .otf |   N/A   |   N/A   | N/A, Deprecated since iOS 17 |
| cff  | colr_1 | .otf |   N/A   |   N/A   |             N/A              |
| cff  | colr_0 | .otf |   N/A   |   N/A   | N/A, Deprecated since iOS 17 |
| glyf | colr_1 | .ttf |    ?    |    x    |              x               |
| glyf | colr_0 | .ttf |   N/A   |   N/A   | N/A, Deprecated since iOS 17 |
| svg  |        | .otf |    ?    |    x    |              x               |

`N/A` - build with nanoemoji failed.


# Build

Get noto font source:
```shell
git clone https://github.com/akb2/noto-emoji.git
```

> [!NOTE]
> The repo is fork of the original noto repo with partial fix for SBIX format.  
> The SBIX issue is not fixed in official repo: https://github.com/googlefonts/noto-emoji/issues/438

Install `nanoemoji` tool:
```shell
uv tool install nanoemoji
```

Run `SBIX` font building:
```shell
cd noto-emoji/colrv1 && uvx nanoemoji sbix.toml
```

## Remove Symbols up to U+3A

```shell
pyftsubset NotoColorEmoji.sbix.ttf \
    --unicodes="U+3A-10FFFF"       \
    --output-file=NotoColorEmoji.sbix.ncap.ttf
```
