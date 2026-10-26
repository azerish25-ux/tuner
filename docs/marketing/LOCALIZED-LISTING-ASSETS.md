# Localized listing asset evidence

The explicitly requested **Localized listing assets** workflow (`listing-assets.yml`) records the
actual app for the listing locale, then renders that locale's captions. It does
not upload to Apple, sign a device build, update account settings, change the
localization registry, or publish a results branch. Only `main` is accepted.

There are two opt-in routes: manual dispatch with the inputs below, or an exact
marker in a main-branch push's head commit message:

- `[listing-assets-pilot]`: exactly `en-US,de-DE,ar-SA`, all three default asset kinds.
- `[listing-assets-all]`: exactly all 50 registry locales, all three default asset kinds.

Ordinary translation commits do not start any capture/build jobs. A commit
containing both markers fails rather than choosing the broader scope. Push
markers never enable the optional violin cut; manual dispatch retains all inputs.
Adding this workflow does not trigger it; only ROOT/owner chooses and publishes
an explicit marker or dispatch.

## Scope

The default `locales=all`, `scope=all` plan is **50 listing locales × 3 asset sets**:

- Nine default iPhone screenshots, captured on a 6.9-inch Pro Max simulator.
- Four default landscape iPad screenshots, captured on a 13-inch iPad Pro.
- One main iPhone App Preview, with its real recording, app-generated audio,
  synchronization pictures, rendered video, poster and contact sheet.

This is 650 framed screenshots and 50 main previews if every requested asset
succeeds. It is not a claim that they already exist or have passed visual review.
The optional `violin=true` adds the violin preview only. Localized Custom Product
Page screenshot sets are not authored and must not be inferred from the default
listing's 13 caption pairs. There is no iPad preview tour in the current source.

A pilot can use `locales=en-US,de-DE,ar-SA` and `scope=screenshots` or `scope=all`.
The smallest fallback pilot is `locales=ms,or-IN,zh-Hant`. A pilot never receives an
all-50 completion flag. Failed locales can be selected explicitly in a new run;
separate runs are not silently merged into one successful inventory.

## Locale and fallback policy

`tools/l10n/store-locales.json` remains the authority for supported listing codes
and app-language mappings. `listing_assets.py` records the exact listing locale,
current metadata payload SHA-256, expected app language, AppleLanguages preference
list and AppleLocale formatting region for each set. Regional listings sharing
one app language still get separate launches and renders; assets are not copied
between their directories.

`ms`, `or-IN` and `zh-Hant` have **no matching app UI language**. Their launch
preferences request Malay, Odia or Traditional Chinese first and English second.
The native evidence test must actually find all five English app tabs under
those preferences. Their manifests say `listing_only_fallback: true` and
`ui_support_claim: false`. If the OS chooses another language, the run fails; it
does not quietly force English or claim that Traditional Chinese UI is supported.
This verifies that explicit preference list, not every possible device language
order or Apple's storefront selection behavior.

Each set first executes `ListingCaptureEvidenceUITests`, which compares the
visible app tab labels to exact current shipped tables. Launch markers from the
capture/preview tests must then match the same locale, language preferences and
formatting region. Environment variables alone are not verified pixel evidence.
This check does not prove every string in every screen was translated correctly;
the captured app pixels and rendered assets still need review.

Manifests also record whether the actual app language has shipped `Learn.strings`
and its SHA-256. A supported app language with missing lesson resources is marked
failed/pending before capture; localized tabs alone must not pass a listing set
whose lesson pixels still fall back to English. The listing-only locales still
use their explicitly verified English fallback, including English lessons.

## Build reuse and bounded work

A single unsigned `build-for-testing` run generates the capture fixtures and
packages `Build/Products` (including the `.xctestrun`) as a tar archive, preserving
executable permissions. Every worker uses `test-without-building` against that
same archive and verifies source SHA, archive hash, Xcode version and host
architecture. Pinned fonts and their all-50 glyph/layout audit are prepared once
and hash-verified when restored by each worker. Two listing locales are handled sequentially per worker. One
matrix with `max-parallel: 2` caps all capture/preview workers together.

The default all-50 plan has 75 two-locale workers; this is deliberately bounded,
not fast or free-of-runner-cost. It can take many hours. No workflow is triggered
by preparing these files. The parent/owner controls dispatch and publication.

The iPad must retain Full Screen Apps settings and launch Settings after its
reboot. Failure does not silently fall back to windowed screenshots. The output
pixel dimensions also have to match the intended device. The full marketing
status bar override is required rather than reduced to a warning.

## What fails closed

- Missing, wrong (`-wrong`), repeated, out-of-folder or reused capture attachments.
- Missing or extra rendered files, wrong dimensions, identical screenshot pixels
  within one set, or a whole reused image set for different app UI languages.
- A test that was skipped or executed zero cases, missing language verification,
  or any capture launch with different locale preferences.
- Missing preview clips/syncs/audio, wrong cut, stale app-audio events, or existing
  preview format/audio/band/lock/poster gates failing. English-derived band
  semantics must remain enforced when the displayed caption is translated.
- Missing, duplicate, stale-payload, wrong-revision or different-build manifests.
- Any attempt to mark a mechanical result as visually reviewed or release-ready.

Only failures classified by the existing `launch_retry.py` as simulator launch
infrastructure get one fresh test retry. Preview renderer retake codes 3/4 (including the same band-missing class found by
the language-independent audio recheck) permit up to three real recordings; assertion, fixture and translation failures are not
masked by retakes. Every attempt has its own output directory, logs, attachments
and result bundle. No failed attempt is overwritten with a succeeding image.

## Artifacts and review

- `listing-plan`: exact requested locales/kinds and shard plan.
- `listing-simulator-build`: unsigned reusable products, log and build fingerprint.
- `listing-assets-<kind>-<shard>`: actual capture/render evidence and failed attempts.
- `listing-manifests-<kind>-<shard>`: compact per-locale manifests for aggregation.
- `listing-inventory`: aggregate result; fails unless every requested set exists
  and its provenance and mechanical checks agree.

All artifacts expire after seven days. Save required evidence before expiry.
Each manifest remains `release_ready: false`, `visual_review: pending` and
`native_review: pending`, even when `status: mechanically_verified`.

Review raw app pixels as well as final frames: truncation, overlaps, text slices,
wrong direction, script shaping, font substitution, physical instrument order,
search-size legibility and any unexpected English. For previews review actual
motion, audio, band, synchronization and poster timing. Record findings against
the exact source revision and payload hash. This workflow does not itself clear
any existing registry release blockers or authorize submission.

## Local checks (no native capture)

```sh
python3 -m unittest discover -s tools/marketing/tests -p 'test_listing_assets.py'
python3 tools/marketing/listing_assets.py plan --locales all --scope all --out /tmp/listing-plan.json
```

These check planning, source selectors, failure cases and evidence validation.
They are not macOS compilation, XCUITest execution or a render review. A native
pilot is required to verify build-artifact relocation and the actual tours before
treating the workflow as operationally proven.
