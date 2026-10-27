# Localized caption typography

Use a Pillow build with libraqm, plus the declared dependencies:

On macOS, install `fribidi` with Homebrew and expose `$(brew --prefix fribidi)/lib` through
`DYLD_FALLBACK_LIBRARY_PATH` before starting Python. Pillow's macOS wheels load FriBiDi at runtime.
The listing and preview workflows install and check this dependency on every rendering runner.
They retain its path in `TIMBRE_FRIBIDI_LIBRARY_DIR` and re-export the `DYLD_` value inside each rendering step;
macOS protected shell launches can discard inherited `DYLD_` variables.
Do not disable shaping or text-direction options to make an audit pass.

```sh
python3 -m pip install -r tools/marketing/requirements.txt
python3 tools/marketing/font_assets.py --audit --out ci-out/caption-typography.json
```

The installer fetches only the pinned Google Fonts revision and verifies each font and its SIL Open Font License file against SHA-256 before saving it under `build/marketing-fonts`. The manifest records upstream URLs and copyright/license provenance. Font binaries are not added to the app or repository. No paid service or subscription is involved. Regional Japanese/Korean/Simplified-Chinese/Traditional-Chinese fonts are also pinned here, avoiding a slow operating-system package mirror.

Set `TIMBRE_CAPTION_FONT_DIR` when using another prepared directory. Existing screenshot and preview `--locale` arguments control shaping direction and CJK collection-face selection. A requested font whose glyphs cannot be verified is rejected; a collection is checked on the exact rendered face, not a union of other faces. Arabic/Hebrew/Urdu paragraphs keep RTL direction even when a Latin brand begins the text. Unicode grapheme clusters stay together when an unspaced caption wraps.

Headlines can scale from 136 to 96 pixels at a 1320-pixel screenshot width, without cutting text. Preview headlines can scale from 80 to 48 pixels; the end-note can occupy two lines. Shaped marks/descenders determine line spacing, and preview captions must fit their fixed band. A caption that still cannot fit fails rendering rather than silently overflowing.

The audit checks all 50 listing locales: glyph coverage, actual shaping measurements, planned screenshot caption widths and preview caption widths/band heights. It does not certify native-language fluency, actual app screen captures, full composed-image clipping, or App Store upload readiness. Inspect the final composed screenshots and previews separately. Localized custom-product-page assets remain a separate, explicitly unsupported rendering request until authored; default captions must not be substituted.
