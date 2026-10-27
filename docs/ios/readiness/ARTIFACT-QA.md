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
| `[listing-screenshots-pilot]` | Phone and tablet screenshots for en-US, de-DE, ar-SA |
| `[listing-screenshots-all]` | Phone and tablet screenshots for all 50 listing locales |

Use the screenshots pilot before the full run. The owner selected screenshots
without optional preview videos for the initial submission. Manual listing runs
therefore default to `screenshots`. Legacy `[listing-assets-pilot]` and
`[listing-assets-all]` retain their old meaning: screenshots **and** main preview
videos. Do not combine listing markers: conflicting requests fail closed before
native build/capture. Different workflow markers may share a reviewed commit.

The full screenshot plan has 100 locale/device sets (50 two-locale shards), nine
phone frames and four tablet frames per locale: 650 rendered screenshots plus
contact sheets and original capture evidence. `full_screenshot_listing_scope`
records the complete selected scope; historical `full_default_listing_scope`
continues to require previews and stays false for screenshots-only plans. These
are **plan coverage**, not evidence that captures have passed.

Native validators are unchanged: exact 50-locale registry, actual medium phone
1206×2622 and landscape iPad 2752×2064 captures, executed language assertions,
original pixel hashes, source/build provenance, and complete manifests remain
required. Never substitute generated images, parser fixtures, or a large phone
capture for native evidence. Failed/missing shards stay incomplete. Mechanical
success still requires visual review and never changes `release_ready: false`.

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
