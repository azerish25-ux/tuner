# iOS resource inventory

> **Current state (2026-10-25).** This page began as the record of the one-time import from the Android app; the
> bundle has grown since. Today the app ships 60 instruments, 132 tunings, 73 photographic variants (146 images),
> 49 localization tables, 7 3D models, 300 instrument samples (15 sets) and one licensed font family, **Sora**
> (Light, Medium, SemiBold, Bold; `ios/Timbre/Resources/Fonts`, SIL OFL in `Sora-OFL.txt`) — the Inter, Space Grotesk
> and IBM Plex Mono files named below were replaced. `python3 tools/verify-ios-resources.py` prints the live counts.
> **Do not run `tools/import-ios-resources.py` again:** it would overwrite the catalogue, photos, fonts and every
> translation with the Android snapshot. See [docs/ARCHITECTURE.md](../ARCHITECTURE.md) (resources) and
> [docs/TOOLS.md](../TOOLS.md).
>
> The original import record follows, unchanged.

`python tools/import-ios-resources.py` imports the checked-in Android snapshot; Python Pillow is required to decode WebP and encode PNG. The generated inputs contain 60 instruments, 8 families, 102 tunings and a separate chromatic reference mode. Catalogue attribution, provenance, anchor identifiers, tuning ownership and all paired string pitches are retained. Twelve-string guitar partners remain 12 course entries sharing six physical anchors. Bass 5-string variants remain supported tunings of their original 4/5-string instrument entry; they are not invented extra presets.

The core bundle includes `catalog.json` and `photos.json`. Names are normalized to `LocalizedText` objects with `timbre_catalog_*` keys matching Android catalog string resources. The photo index contains 71 exact instrument/variant mappings. Each full image and thumbnail is converted into one universal PNG asset in `Assets.xcassets`: 142 imagesets. The `asset` and `thumbnail` fields name compiled image assets directly, usable with `Image(photo.asset)`. Original image source, SHA-256 metadata and origin are preserved in the JSON index. The stored digest describes the original Android WebP, not the converted PNG.

The app resources include 49 native `.lproj/Localizable.strings` tables, merging module strings and English fallback values, converting `%s` parameters to native `%@`, and decoding Android escapes. Legacy Android `iw` and `in` language identifiers map to `he` and `id`. String entries and language coverage originate in the Android snapshot; this import does not claim independent translation review. UI must resolve keys through native localization for these translations to appear.

Three offline font files are preserved: Inter, Space Grotesk, and IBM Plex Mono. All include SIL Open Font License metadata. Full license notices are checked in alongside the fonts as `Inter-OFL.txt`, `SpaceGrotesk-OFL.txt`, and `IBMPlexMono-OFL.txt`, retrieved from the respective Google Fonts source directories. The application must register font filenames in UIAppFonts and compile the asset catalog/localization resources as build resources.

Core CatalogTests pin catalogue size, default ownership, source anchor validity, paired pitches, note formats, reference pitch math, and the shipped temperament tables/letter-degree behavior. Swift execution is delegated to the macOS CI runner because Swift is unavailable in the local Windows environment.
