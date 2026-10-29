# Reviewed artifact-only QA requests

These opt-ins work on **`codex/app-store-readiness-gates`** (the exact Git branch)
and `main`. Put the marker in the **head commit message** of a reviewed push.
Ordinary handoff checkpoints do not start these expensive jobs. No dispatch,
credentials, label changes, signing, App Store upload, or release approval are
implied. Existing main/manual behavior remains available.

| Marker | Evidence requested |
|---|---|
| `[l10n-matrix]` | All eight six-language groups: all 48 translated app languages |
| `[capture-check]` | Six actual store-frame checks in English, German and Arabic |
| `[l10n-export]` | Xcode localization export and strict completeness reports |
| `[caption-typography]` | All 50 listing locales, pinned-font glyph/layout audit |
| `[listing-screenshots-pilot]` | Medium phone, large phone and tablet screenshots for en-US, de-DE, ar-SA |
| `[listing-screenshots-all]` | Medium phone, large phone and tablet screenshots for all 50 listing locales |

Use the screenshots pilot before the full run. The owner selected screenshots
without optional preview videos for the initial submission. Manual listing runs
therefore default to `screenshots`. Legacy `[listing-assets-pilot]` and
`[listing-assets-all]` retain their old meaning: screenshots **and** main preview
videos. Do not combine listing markers: conflicting requests fail closed before
native build/capture. Different workflow markers may share a reviewed commit.

The full screenshot plan has **150 locale/device sets (75 two-locale shards)**:
nine medium-phone, nine large-phone and four tablet frames per locale, totaling
**1,100 JPEGs** across 50 listings. The three-locale pilot has **9 sets / 6 shards /
66 images**. Both phone roles share captions, not captures. Contact sheets, original
capture evidence and Watch assets are separate. Historical 100-set / 650-image
plans remain historical, not complete current submission coverage.
`full_screenshot_listing_scope` records selected plan coverage, not accepted captures;
`full_default_listing_scope` still includes previews and stays false for screenshots-only plans.

Native validators require separate `iphone` **1206×2622**, `iphone-large`
**1320×2868**, and landscape `ipad` **2752×2064** originals, executed language
assertions, original pixel hashes, source/build provenance and complete manifests.
Standalone large-phone composition uses `screenshots.py ... --iphone-large`.
No generated images, parser fixtures, stretching or cross-role substitution count
as native evidence. Large-role capture and visual acceptance remain pending.
Failed/missing shards stay incomplete; mechanical success never changes
`release_ready: false`. The selected large Dynamic Island role addresses the
[conditional large-phone requirement](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
without replacing the required medium/iPad roles. Optional previews remain omitted.

Listing, typography, matrix and localized-capture jobs retain read-only tokens.
Handoff localization export is now artifact-only with a read-only token; the
historical write-permission publisher is isolated and skipped on the handoff
branch. Nightly's existing `captures` PR-label opt-in now includes thread sanitizer
coverage. Running nightly captures survive ordinary checkpoints (no automatic
cancellation); this does not guarantee all queued GitHub concurrency runs survive.

Path filters on localization-export and typography are removed so a reviewed
marker on any changed file can request evidence. Their established main and
`l10n/**` triggers are retained, with main pushes no longer path-filtered.

Local plan inspection (does not run native tests):

```sh
python3 tools/marketing/listing_assets.py plan \
  --event push --ref refs/heads/codex/app-store-readiness-gates \
  --message '[listing-screenshots-all]' --out /tmp/listing-plan.json
python3 -m unittest discover -s tools/marketing/tests
```

No workflow here replaces the required `gate`, Apple account setup, actual visual
acceptance, or the separate release-applicability policy.
