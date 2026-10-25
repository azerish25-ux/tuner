# Timbre: the tools

Every script under `tools/`: what it is for, how to run it, what it reads and what it writes. Commands run from the
repository root. Which workflow runs which tool is in [TESTING-AND-CI.md](TESTING-AND-CI.md); what the generated files
are used for in the app is in [ARCHITECTURE.md](ARCHITECTURE.md). Checked against the scripts at the commit this file
was added in.

## Contents

1. [Overview](#1-overview)
2. [Curriculum (`tools/curriculum`)](#2-curriculum-toolscurriculum)
3. [Localization (`tools/l10n`)](#3-localization-toolsl10n)
4. [Marketing (`tools/marketing`)](#4-marketing-toolsmarketing)
5. [3D models (`tools/models`)](#5-3d-models-toolsmodels)
6. [Recorded samples (`tools/build-ios-samples.py`)](#6-recorded-samples-toolsbuild-ios-samplespy)
7. [Brand and icon (`tools/brand`, `tools/timbre-icon.svg`)](#7-brand-and-icon-toolsbrand-toolstimbre-iconsvg)
8. [Resource import and verification](#8-resource-import-and-verification)
9. [CI scripts (`tools/ci`)](#9-ci-scripts-toolsci)
10. [Dependencies](#10-dependencies)

---

## 1. Overview

| Path | What it does | Writes into the app? | Run by |
|---|---|---|---|
| `tools/curriculum/build.py` | Validates the lesson sources and builds the curriculum | `curriculum.json`, `en.lproj/Learn.strings` | People, after editing lessons |
| `tools/curriculum/{lib,songbook,tunes,editions}.py`, `courses/*.py` | Lesson-writing helpers and the lessons themselves | via `build.py` | `build.py` |
| `tools/l10n/report.py` | Translators' handoff, TODO files, import of translations | via `apply*.py` on `--import` | People; CI (`--check --strict`) |
| `tools/l10n/critical.py` | Legal, permission and VoiceOver strings in every shipped locale | no | CI (`--baseline`), delivery (`--strict`) |
| `tools/l10n/shipping.py` | Which locales ship; coverage | `ios/project.yml` with `--apply` | People; delivery |
| `tools/l10n/apply.py`, `apply_learn.py` | Write translations into the string tables | `<locale>.lproj/*.strings` | `report.py --import`, people |
| `tools/l10n/swiftstrings.py` | Finds localizable literals in Swift without Xcode | no | `report.py`, `critical.py` |
| `tools/l10n/xcstrings.py` | Builds String Catalogs from the tables (not adopted yet) | no (`--out DIR`) | People |
| `tools/l10n/extract.py` | `pending.json` from an Xcode export (superseded by `report.py`) | no | People |
| `tools/marketing/screenshots.py` | App Store screenshot frames from CI captures; listing checks | no | People |
| `tools/marketing/preview.py` | Records and cuts the App Preview | no | `preview.yml` |
| `tools/marketing/gates.py`, `art.py`, `soundtrack.py` | Libraries for the two above | no | – |
| `tools/models/build_assets.py` (+ `blendkit.py`, `instruments.py`, `bowed.py`, `textures.py`) | Procedural 3D instruments in Blender | via `install_assets.py` | `assets.yml` |
| `tools/models/postprocess.py` | Trims renders, thumbnails, contact sheet | no | `assets.yml` |
| `tools/models/install_assets.py` | Installs the Blender pipeline's output | `Models/`, `render_*.imageset` | People |
| `tools/models/install_artist_models.py` | Installs converted artist models (the models that ship) | `Models/`, renders, `photos.json` | People |
| `tools/models/render_cards.swift`, `cards.py` | Studio cards rendered with RealityKit; review and install | `render_*.imageset` (`cards.py install`) | `cards.yml`, people |
| `tools/build-ios-samples.py` | Builds the recorded instruments from CC0 libraries | `Resources/Samples/`, `docs/content/AUDIO-SOURCES.md` | People |
| `tools/brand/icon.py` | Renders the icon design (in amber; the shipped icon is mint, §7) | a PNG you copy into the asset catalog | People |
| `tools/verify-ios-resources.py` | Checks every bundled resource | no | CI, delivery |
| `tools/import-ios-resources.py`, `tools/localize-ios-copy.py` | One-time Android import (legacy; see §8) | yes (destructive) | Nobody now |
| `tools/ci/*` | CI gates and helpers | no | Workflows ([TESTING-AND-CI.md §6](TESTING-AND-CI.md#6-lint-and-hygiene-tools-toolsci)) |

## 2. Curriculum (`tools/curriculum`)

How to write lessons (shape, voice, music, songs, don'ts) is in [STYLE.md](../tools/curriculum/STYLE.md); public-domain
rules are in [content/PUBLIC-DOMAIN-CLEARANCE.md](content/PUBLIC-DOMAIN-CLEARANCE.md).

### 2.1 `build.py`

```sh
python3 tools/curriculum/build.py                                  # validate and write
python3 tools/curriculum/build.py --check                          # validate only (about 10 s)
python3 tools/curriculum/build.py --check --only ear,theory        # validate some courses (--only needs --check)
python3 tools/curriculum/build.py --check --editions               # also list each songbook edition's key choices
python3 tools/curriculum/build.py --check --clips                  # list technique clips still to shoot
```

- **Reads** the modules in `COURSES` (in this order): `guitar`, `ukulele`, `bass`, `violin`, `cello`, `mandolin`,
  `banjo`, `ear`, `theory`, `rhythm`, `voice`, `songs`, `originals`, `songs_part3`, `ukulele_songbook`,
  `mandolin_songbook`, `violin_songbook`, `cello_songbook`, `bass_songbook`, each `tools/curriculum/courses/<name>.py`
  defining `COURSE = course(...)`.
- **Writes** `ios/Sources/TimbreCore/Resources/curriculum.json` (`{"version": 1, "courses": […]}`, compact, one line)
  and `ios/Timbre/Resources/en.lproj/Learn.strings` (sorted). Nothing is written when any check fails.
- **Keys:** every text becomes `{"k": "L<first 10 hex of SHA-1 of the English>", "t": "<English>"}`, so a sentence used
  twice is translated once and an edited sentence gets a new key (its old translation then shows in English until it
  is translated again).
- **Free lessons:** every lesson of each course's first unit is set `free` here.
- **Checks** (each failure prints `course/lesson: problem`, and the run exits 1): length limits (title 42, body 300,
  prompt 140, option 48, hint 120, why 220, summary 120, subtitle 80), duplicate lesson ids, 3–16 steps and something to
  play or answer, notes inside the instrument's range and on the string and fret named (the banjo's fifth string open
  only), chord shapes spelling their chord, tempos, answers and options, listen/quiz directions matching the sound,
  patterns inside their bar, muted and accented beats inside the pattern; for arranged songs: the take is the last step,
  tempo and meter agree, sections cover every bar in order, notes never overlap and are at least 0.15 s apart, chord
  changes have shapes, the song runs 1:30–3:00, lyric syllables and credits are consistent and lines stay inside a
  section; strummed songs (chords only) also run 1:30–3:00.
- **Prints** totals: courses, lessons, strings, and per course the number of whole songs, how many have lyrics, and the
  shortest/median/longest length.

After building, run `python3 tools/l10n/report.py` and commit its output with the curriculum (the CI handoff check
fails otherwise). No workflow runs `build.py --check`, so run it yourself before committing lesson changes; CI only
sees the built `curriculum.json` through the Swift tests.

### 2.2 The helper modules

| File | Contents |
|---|---|
| `lib.py` | Conventions (strings numbered from the highest, fret 0 open, MIDI or note names, beats from 0), `TUNINGS` and `INSTRUMENT_IDS` per course instrument, chord `QUALITIES`, and the builders: `course`, `unit`, `lesson`, `explain`, `notes`, `along`, `play_chord`, `strum`, `progression`, `tap`, `listen`, `quiz`, visuals (`fretboard`, `staff`, `keyboard`, `rhythm`, `part`, `chord`), `position` (first-position fretting), `T`/`Text` (translatable text), `bundled_clips` |
| `songbook.py` | Full song arrangements: `Part` (intro, verse, chorus, bridge, solo, interlude, outro; melody tokens `note:beats`, `note@string:beats`, `note~finger:beats`, rests; pickups; one chord token per bar, `C,G` splits a bar, `N` no chord; lyric tokens with `-`, `_`, `/`, `~`), `song(...)` → the final take plus `arrangement`, `transpose`, `transpose_chords` |
| `tunes.py` | Tunes several courses share (Ode to Joy, Twinkle, Amazing Grace, Clementine, Oh! Susanna, Lightly Row, three-note Mary Had a Little Lamb), each once in one key with chords and public-domain words and credits |
| `editions.py` | Songbook editions: every whole song of Songs, Standards & Classics and Originals moved to a key and position that suit ukulele, mandolin, violin or cello (a scored search over keys and octaves), chords respelled in the new key, plus root-and-fifth bass editions (`bass_edition`) |
| `courses/<course>.py` | One course each. `guitar.py` imports `guitar_part2.py` and `guitar_part3.py` (and those import back, so always load through `guitar`); `songs.py` collects `songs_part1.py`/`songs_part2.py`; `songs_part3.py` is the **Standards & Classics** course (id `standards`, with `standards_part2.py`); `originals.py` uses `originals_part2.py`; `ukulele.py` uses `ukulele_part2.py` |
| `courses/songbook_sources.py` | The order songbooks take the source units in, and the report `--editions` prints |
| `courses/*_songbook.py` | Five songbook courses built by `editions.songbook(...)` (bass: `bass_edition`) |

## 3. Localization (`tools/l10n`)

The full translator brief, file formats and the developer commands are in [l10n/HANDOFF.md](l10n/HANDOFF.md) (generated
by `report.py`). This section lists the scripts and the data files.

### 3.1 Scripts

| Script | Commands | Reads | Writes |
|---|---|---|---|
| `report.py` | `report.py` (regenerate); `--check` (CI: warn, write nothing in the repo); `--check --strict` (exit 1 when the handoff is stale); `--out DIR` (with `--check`, write the generated files there); `--import DIR` (merge filled TODO files, apply, regenerate); `--xliff en.xliff` (settle code keys with Xcode's export) | Swift sources (via `swiftstrings.py`), `en.lproj/Localizable.strings` and `.stringsdict`, the Info.plist strings in `ios/project.yml`, App Shortcut phrases, `en.lproj/Learn.strings`, every locale's tables, `translations/`, `learn/` | `todo/<locale>.json`, `todo/index.json`, `pending.json`, `source/learn-history.json`, `docs/l10n/HANDOFF.md` |
| `critical.py` | default report; `--github`; `--baseline [FILE]` (fail on a gap not in the baseline); `--write-baseline [FILE]`; `--strict` (fail on any gap); `--locales de,fr`; `--out DIR` (`critical-missing.json`); `--xliff` | As `report.py`; shipped locales from `CFBundleLocalizations` | Only with `--write-baseline` or `--out` |
| `shipping.py` | default (coverage per locale); `--min PERCENT` (dry run); `--critical` (also require every launch-critical string); `--apply`; `--all --apply`; `--github-output` | The tables, `ios/project.yml` | `ios/project.yml` lines marked `# shipping.py` (`CFBundleLocalizations` and the `.lproj` excludes of every target) |
| `apply.py` | `apply.py tools/l10n/translations` | `translations/<locale>.json` | `<locale>.lproj/Localizable.strings`, `AppShortcuts.strings`, `InfoPlist.strings`; rejects translations whose format arguments or named tokens differ from the key's |
| `apply_learn.py` | `apply_learn.py [--import DIR]` | `learn/<locale>.json`, `en.lproj/Learn.strings` | `<locale>.lproj/Learn.strings` (only keys present in English) |
| `swiftstrings.py` | library | Swift sources | – |
| `xcstrings.py` | `--check` (round trip, exit 1 on a loss); `--out DIR` | Every `.strings`/`.stringsdict`, `plurals-en.json` | `Localizable.xcstrings`, `AppShortcuts.xcstrings`, `InfoPlist.xcstrings` in `DIR`; the docstring lists the steps to adopt them |
| `extract.py` | `extract.py en.xliff > tools/l10n/pending.json` | An Xcode export | stdout |

### 3.2 Data files

| Path | What |
|---|---|
| `tools/l10n/todo/<locale>.json` (48 locales) and `todo/index.json` | What each locale still needs, launch-critical strings first; the files translators fill in |
| `tools/l10n/translations/<locale>.json` | Delivered interface translations by table |
| `tools/l10n/learn/<locale>.json` | Delivered lesson translations for the nine lesson languages (de, es, fr, it, ja, ko, pt, ru, zh-CN) |
| `tools/l10n/pending.json` | Every interface string some locale lacks |
| `tools/l10n/critical-baseline.json` | Known gaps the pull-request gate tolerates (today 11 legal, 1 permission, 94 VoiceOver strings; a reviewed decision to ship English there for now) |
| `tools/l10n/plurals-en.json` | English plural forms for counted strings (used by `xcstrings.py`) |
| `tools/l10n/source/learn-history.json` | Old English of lesson keys that left `Learn.strings`, so changed sentences can reuse old translations |

## 4. Marketing (`tools/marketing`)

### 4.1 `screenshots.py`

```sh
python3 tools/marketing/screenshots.py <captures> <out> [--ipad] [--page NAME] [--locale CODE] [--font PATH] [--allow-english]
python3 tools/marketing/screenshots.py --check
```

- **Frames are defined in the docs**, not in the script: the tables under "## Screenshots" in
  [ios/APP-STORE-LISTING.md](ios/APP-STORE-LISTING.md) (iPhone 6.9", iPad 13", one table per Custom Product Page via
  `--page`) and the localized tables in [ios/APP-STORE-LISTING-LOCALIZED.md](ios/APP-STORE-LISTING-LOCALIZED.md). Each row
  is a caption, a supporting line, the capture it frames and its look (`layout accent`).
- **`<captures>`** is a folder of exported xcresult attachments (with `manifest.json`), e.g. `screenshots/` from
  `ci-results/app` (iPhone) or `ipad-screenshots/` from `ci-results/ipad` (with `--ipad`), or PNGs named after their
  captures. A localized set needs a tour run with `TEST_RUNNER_TIMBRE_UI_LANGUAGE`/`_LOCALE`.
- **Output:** iPhone 1320×2868; iPad 2752×2064 (landscape) or 2064×2752 (portrait); every frame read back and checked;
  `sheet.png` (the set side by side at search-result size). Exits non-zero if a frame is missing, was flagged wrong by
  its test, was captured twice or has a size App Store Connect would refuse.
- **`--check`** validates every table and the listing's paste blocks (at most 10 frames a set, captions ≤ 30
  characters, captures the UI tests really take, localized tables matching the English order, every count quoted
  equal to the build's own from `curriculum.json` and `catalog.json`, Apple's text limits); untranslated captions
  (`TRANSLATE:`) are listed, not failed. Standard library only.
- Looks: `breakout`, `zoom`, `callout`, `wall`, `light`, `offset`, `offset-left`, `flip`; on iPad `side`,
  `side-right`, `light`. Hero regions per capture are in `FOCUS` in the script.

### 4.2 `preview.py`

Run by `preview.yml` ([TESTING-AND-CI.md §3.4](TESTING-AND-CI.md#34-previewyml-app-preview)):

```sh
python3 tools/marketing/preview.py device                       # pick or create a 6.9-inch iPhone simulator
python3 tools/marketing/preview.py record --device ID --out DIR [--handshake DIR --log LOG]
python3 tools/marketing/preview.py stop --out DIR
python3 tools/marketing/preview.py render --out DIR --log LOG [--attachments DIR] [--audio DIR] [--offset S] [--reanchor]
python3 tools/marketing/preview.py check --out DIR              # re-measure a rendered preview's sound
```

- **Input:** the simulator recording (`raw.mp4`), the test log's `PREVIEW-*` lines (`PREVIEW-CLIP`, `-SYNC`, `-POSTER`,
  `-REGION`, `-CARD`, `-BEAT`, `-CHECK`, `-MISSED`, `-CUT`, `-APP`, written by `AppPreviewUITests`), the exported
  attachments (sync screenshots), and the folder where the app wrote what it played (`TIMBRE_PREVIEW_AUDIO`).
- **Output:** `preview.mp4` (886×1920, 30 fps, H.264 High, stereo AAC 44.1 kHz, 20–25 s plus an end card),
  `poster.png`, `contact.png`, `PREVIEW.txt`, `cut.json`, `sync.png`, `raw-small.mp4`.
- Clips are placed by finding each sync screenshot in the recording by its picture, cut on the band's beats, captioned
  and laid over the app's own sound. Exit 3: the recording lost the app; exit 4: a moment was missed (the workflow
  records again). `--offset` shifts every cut; `--reanchor` places the lock clip by its badge.

### 4.3 Libraries

| File | What |
|---|---|
| `gates.py` | What a preview must prove, measured on the files: no silence over its limit, every clip sounding, the band audible under a "band" caption (low end), the lock badge's first frame (`mint_series`, `badge_onset`), sync refinement to 1/60 s (`refine_sync`) |
| `art.py` | Shared art direction: the app's palette, Sora captions with fallback fonts (fontTools checks glyph coverage; `TIMBRE_CAPTION_FONT` / `--font` adds one), per-feature background accents |
| `soundtrack.py` | Reads `events.jsonl`, `cue-*.wav`, `engine-*.pcm`, `string-*.pcm` written by `PreviewRecorder` (`ios/Timbre/Root/DemoScenes.swift`) and returns the app's sound for any wall-clock stretch (`AppAudio.segment`); pure Python, synthesizes nothing |

## 5. 3D models (`tools/models`)

There are two pipelines. **The seven models that ship are Sketchfab artist models (CC BY)**, converted outside this
repository and installed with `install_artist_models.py`; their cards are re-rendered with `render_cards.swift`. The
procedural Blender pipeline is kept and runs in `assets.yml`, but its rigs carry no `credit` block, which
`verify-ios-resources.py` requires, so its output does not pass verification as is.

### 5.1 Artist models

```sh
python3 tools/models/install_artist_models.py <converted dir> [<converted dir> …]
```

- **Input:** folders holding `<model>.usdz`, `<model>.rig.json` (with `credit` and complete `card2D` peg points) and a
  square `<model>_hero.png`, as produced by `tools/models/sketchfab/convert.py` (referenced by the script, **not in the
  repository**). `MAPPING` lists the models and the photo assets each stands for: `guitar_acoustic`,
  `guitar_classical`, `guitar_electric`, `bass_p4`, `mandolin`, `violin`, `cello`.
- **Effect:** deletes every installed usdz, rig and `render_*` imageset; copies the new models and rigs; writes
  `render_<model>` (1024 px) imagesets; for `guitar_classical` and `guitar_electric` adds library photographs made from
  the render (`photos.json` entries with origin credit); rewrites `Models/models-manifest.json`.

### 5.2 Studio cards with RealityKit

```sh
xcrun swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos15.0 tools/models/render_cards.swift -o build/render-cards
build/render-cards ios/Timbre/Resources/Models build/cards [--size 1024] [--supersample 2] [--models a,b] [--variants a,b]
python3 tools/models/cards.py sheet build/cards [--live <screenshots dir>]
python3 tools/models/cards.py install build/cards --variant <name> [--models a,b] [--photos] [--force]
```

`render_cards.swift` (macOS 15+, `RealityRenderer`) renders each model with the live stage's lights and image-based
light from the camera the cards were first rendered with (so `card2D` stays valid): `cards/<variant>/render_<model>.png`
(1024×1024 RGBA), `closeups/` (acoustic guitar and mandolin head close-ups) and `RENDER.txt`. `cards.py sheet` lays the
variants beside live-stage captures (`sheet-closeups.png`, `sheet-cards.png`); `cards.py install` copies a variant over
`Assets.xcassets/render_<model>.imageset`, checking the silhouette matches, and with `--photos` refreshes the library
photographs made from the classical and electric cards and their SHA-256 in `photos.json`. The `cards.yml` workflow
runs the first three steps.

### 5.3 Procedural Blender pipeline

```sh
python3 tools/models/textures.py [output_dir]                    # default tools/models/textures/
blender -b --factory-startup --python tools/models/build_assets.py -- --out build/assets [--models a,b] [--samples 64] [--res 1024] [--no-render]
python3 tools/models/postprocess.py build/assets
python3 tools/models/install_assets.py build/assets [--photo-cards id,id]
```

| File | What |
|---|---|
| `textures.py` | Procedural wood, pearl, rosette, sunburst and varnish textures (NumPy, SciPy, Pillow), committed in `tools/models/textures/` |
| `blendkit.py` | Geometry and material helpers (Blender Z-up, front view −Y, metres) |
| `instruments.py` | Fretted, machine-head instruments (`MODELS`: guitar_acoustic, bass_p4, …; `PHOTO_MODELS` maps photo assets); animated nodes `peg_<anchor>`, `post_<anchor>`, `string_<anchor>` |
| `bowed.py` | Violin, viola, cello, double bass with friction pegs (`BOWED`, `BOWED_PHOTOS`) |
| `build_assets.py` | Builds each model, exports `<id>.usdz` (USD export, Y up), writes `<id>.rig.json`, renders `<id>_hero.png` and `<id>_head.png` with Cycles (AgX), writes `manifest.json` |
| `postprocess.py` | `<id>_card.png` (1024 square), `<id>_thumb.png` (320), a contact sheet |
| `install_assets.py` | Copies usdz and rigs into `ios/Timbre/Resources/Models` (drops `hero2D`), card renders into `render_<id>.imageset` (unless listed in `--photo-cards`, which keep the photograph), and merges `models-manifest.json` |

`assets.yml` runs `textures.py`, `build_assets.py` (Blender 4.5 on Ubuntu) and `postprocess.py`, then publishes to
`ci-results/assets`.

## 6. Recorded samples (`tools/build-ios-samples.py`)

```sh
python3 -I tools/build-ios-samples.py [--cache DIR] [--only piano,guitar] [--doc-only]
```

- **Sources:** CC0 libraries on GitHub, each pinned to a commit and licence-checked before any sample is read
  (Karoryfer Black and Green Guitars and Growlybass, FreePats Spanish Classical Guitar, Jeff Learman's Martin HD-28 from
  the Discord SFZ GM bank, VCSL, Virtuosity Drums, VSCO 2). Partial clones go to `--cache` (default
  `~/.cache/timbre-samples`, about 400 MB).
- **Processing per recording:** mono 44.1 kHz; sustain-loop ring-out for trimmed plucks; trimmed pre-roll and tails;
  fundamental measured to 0.01 ¢ (rejected beyond 35 ¢ of equal temperament) and the pitch Timbre's own YIN reads;
  gain normalisation; AAC encode (mono, 80–112 kbps) and a decode check.
- **Writes** `ios/Timbre/Resources/Samples/<set>/*.m4a`, `Samples/manifest.json` (sources, zones with pitch, gain,
  velocity, loop points, SHA-256 of the original) and the per-file table in
  [content/AUDIO-SOURCES.md](content/AUDIO-SOURCES.md). `--doc-only` rewrites only the document.
- **Needs** git, ffmpeg (`/usr/bin/ffmpeg`), NumPy. `verify-ios-resources.py` then checks licences, hashes, pitches,
  the 35 MB budget and that every file is listed in `AUDIO-SOURCES.md`.

## 7. Brand and icon (`tools/brand`, `tools/timbre-icon.svg`)

```sh
python3 tools/brand/icon.py [out.png]          # default icon.png in the current directory
```

Renders the "Still Point" icon (a frozen standing wave inside a strobe ring) at 4096 px with NumPy and SciPy and saves
1024×1024. It draws the design in a warm amber palette; the icon that ships
(`ios/Timbre/Resources/Assets.xcassets/AppIcon.appiconset/icon.png`, with separate `icon-dark.png` and
`icon-tinted.png`) is the same design in mint, so the script does not reproduce it as it stands. Change its colours
before using it to regenerate the icon, then copy the output into the asset catalog by hand. `tools/timbre-icon.svg` is the original icon vector, kept for reference
(nothing reads it).

## 8. Resource import and verification

| Script | Status | What it does |
|---|---|---|
| `tools/verify-ios-resources.py` | **In use** (CI core job, delivery) | Asserts 60 instruments, 132 tunings, 8 families, at least 71 photos with both imagesets present and provenance fields; the Sora fonts and licence; every 3D model's usdz, rig, render, credit licence (`by` or `cc0`) and anchors; photo-stage points; the privacy manifests' required-reason entries; that every literal `"timbre_*"` key in `ios/Timbre` Swift code (comments excluded, product ids excepted) exists in `en.lproj/Localizable.strings`; exactly 49 `.lproj` folders; the sample library (licences, pinned sources, hashes, pitches within 35 ¢, coverage, drum pieces, the band's sets, nothing unlisted, every file in `AUDIO-SOURCES.md`, ≤ 35 MB). Prints one `OK:` summary line. Update its pinned numbers in the same change that alters the content |
| `tools/import-ios-resources.py` | **Legacy, do not run** | The original import from the Android project (`reference/android`, ignored by git) with Pillow: rewrites `catalog.json`, `photos.json`, the photo imagesets, `Resources/Fonts` (Android's fonts) and every `<locale>.lproj/Localizable.strings` from Android XML. Running it today would discard 30 added tunings, the Sora fonts and every interface translation made since |
| `tools/localize-ios-copy.py` | **Legacy, broken** | Replaced SwiftUI literals with Android keys in `ios/Timbre/Views/*.swift`, a folder that no longer exists |

## 9. CI scripts (`tools/ci`)

Documented in [TESTING-AND-CI.md §6](TESTING-AND-CI.md#6-lint-and-hygiene-tools-toolsci):

| File | Purpose |
|---|---|
| `comment_hygiene.py`, `hygiene-baseline.json` | Comment and design-rule lint and its shrinking baseline |
| `lint_tells.py` | Old name of `comment_hygiene.py` |
| `sweep_comments.py` | Mechanical rewrite of review/bug/QA/store-frame references in comments |
| `swift_source.py` | Swift lexer used by the hygiene tools and `verify-ios-resources.py` |
| `test_hygiene.py` | Tests for the three above |
| `build_warnings.py`, `warnings-allowlist.json` | Warnings-as-errors log gate (concurrency counted) |
| `coverage.py`, `coverage-floor.json` | TimbreCore line-coverage floor |
| `swiftlint-baseline.json` | SwiftLint baseline |
| `skip_ci_guard.py`, `skip-ci-grandfathered.txt` | No untested `ios/` commit in a pull request |
| `launch_retry.py` | Re-run UI tests that failed only at launch |
| `summarize-log.py` | Log summaries and annotations |
| `publish-results.sh` | Publish results to `ci-results/*` |
| `ensure-metal.sh` | Install the Metal toolchain |

## 10. Dependencies

| Tool | Python | Other |
|---|---|---|
| curriculum, l10n, `verify-ios-resources.py`, `tools/ci/*.py`, `screenshots.py --check` | Python 3.12 or later, standard library only (`verify-ios-resources.py` nests quotes inside an f-string, which needs 3.12; this document's checks ran on 3.13) | git (optional for `report.py`, required for `skip_ci_guard.py`) |
| `screenshots.py` rendering, `art.py` | Pillow; fontTools for glyph checks | Sora fonts in the repo |
| `preview.py`, `gates.py`, `soundtrack.py` | Pillow, fontTools | ffmpeg, Xcode simulator (`simctl`) |
| `build-ios-samples.py` | NumPy | git, ffmpeg |
| `models/textures.py`, `brand/icon.py` | NumPy, SciPy, Pillow | – |
| `models/build_assets.py`, `blendkit.py`, `instruments.py`, `bowed.py` | Blender 4.5's bundled Python | Blender |
| `models/postprocess.py`, `install_artist_models.py`, `cards.py` | Pillow (`cards.py` also NumPy) | – |
| `models/render_cards.swift` | – | macOS 15+, Xcode (`swiftc`, RealityKit) |
