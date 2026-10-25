# Timbre — hand-over (start here)

**Date:** 2026-10-25 · **Repository:** github.com/azerish25-ux/tuner · **Default branch:** `main` (the working branch
`v2/foundations` and every commit of it were merged into `main` at hand-over).

Timbre is a native iOS app (Swift, SwiftUI, RealityKit, AVAudioEngine, StoreKit 2) for iPhone, iPad and Apple Watch:
a precision tuner for 60 instruments and 132 tunings, and a music-lessons app that listens as you play — 526 teaching
lessons in 11 courses plus songbooks (1,100 lessons in 19 courses in all), 146 songs (public-domain standards and the
app's own Originals), a play-along "highway" with a band, chord and strum checking, ear training, a metronome, a drone,
voice exercises, practice history, streaks, quests and badges, widgets, a Live Activity, Siri/App Intents, Game Center
and a watch companion. Free tier: every instrument's standard tuning (violin and cello included), open chords, capo,
one custom tuning; Timbre Pro (yearly with a 14-day trial, monthly, lifetime) opens the rest. No ads, no account.

## Read in this order

| # | Document | What it gives you |
|---|---|---|
| 1 | **This page** | where things stand and where to go next |
| 2 | [KNOWN-ISSUES.md](KNOWN-ISSUES.md) | everything unfinished, with where it lives and what closes it |
| 3 | [ios/RELEASE-CHECKLIST.md](ios/RELEASE-CHECKLIST.md) | the ordered path from today to the App Store, who does each step |
| 4 | [OWNER-ACTIONS.md](OWNER-ACTIONS.md) | what only the owner can do (accounts, money, licences, people), prioritised, with costs |
| 5 | [ARCHITECTURE.md](ARCHITECTURE.md) | the codebase map: targets, folders, data flow, audio, lessons, commerce, design system, test hooks |
| 6 | [TESTING-AND-CI.md](TESTING-AND-CI.md) | every test suite and workflow, the required gate, the `ci-results/*` branches, flakiness |
| 7 | [TOOLS.md](TOOLS.md) | every script under `tools/` |
| 8 | [process/AGENCY-WORKFLOW.md](process/AGENCY-WORKFLOW.md) | how development was run (agent departments, jury rounds, briefs, rules) and how to continue it |
| 9 | [history/DEVELOPMENT-HISTORY.md](history/DEVELOPMENT-HISTORY.md) | every round and wave from the Android port to today, with scores and decisions |
| 10 | [history/COMMIT-LOG.md](history/COMMIT-LOG.md) | every commit, oldest first, with its full message and files |
| 11 | [l10n/TRANSLATING-WITH-GPT.md](l10n/TRANSLATING-WITH-GPT.md) + [l10n/GLOSSARY-TEMPLATE.md](l10n/GLOSSARY-TEMPLATE.md) + [l10n/HANDOFF.md](l10n/HANDOFF.md) | how to translate the app with GPT, safely through the gates |

Existing reference docs: [ios/APPLE-DELIVERY.md](ios/APPLE-DELIVERY.md) (App Store Connect, products, signing,
growth features), [ios/APP-STORE-LISTING.md](ios/APP-STORE-LISTING.md) and
[ios/APP-STORE-LISTING-LOCALIZED.md](ios/APP-STORE-LISTING-LOCALIZED.md) (listing text, keywords, captions),
[ios/PRIVACY.md](ios/PRIVACY.md) (policy; publishable HTML in [site/](site/)),
[ios/AUDIO-DEVICE-TESTS.md](ios/AUDIO-DEVICE-TESTS.md), [content/](content/) (audio sources, public-domain clearance,
song-licensing playbook), [process/archive/](process/archive/) (every review and jury verdict).

## Where it stands

- **Quality bar and score.** The owner's target is 9.5/10 from a harsh Apple-Design-Award-style jury and #1 against
  GuitarTuna, Fender, Yousician, Simply Guitar and JustinGuitar on every angle. Jury round 16 scored **8.3**
  (visual 8.8, delight 8.7, inclusivity 8.7 — #1, technical 8.5, growth 8.1, category 8.3). Wave 19 (ten packages)
  and its integration pass shipped against that review afterwards; round 17 has not been judged (its brief is ready in
  [process/templates/](process/templates/)). The jury's view: code alone tops out around 8.7; 9.0–9.1 needs the owner
  items (licensed songs, real recordings, design hires, translations, testers).
- **Build health at hand-over.** On the final commit the required PR `gate` (TimbreCore tests, app unit tests and smoke UI flows, Release
  device build, lint and translation gates) is green. The nightly tour (App Store captures), the accessibility audit
  and the App Preview have open items listed in [KNOWN-ISSUES.md](KNOWN-ISSUES.md) §2.
- **Ready for the App Store?** The app is feature-complete for a first release in English. Before submitting: the
  owner's App Store Connect setup, a device test pass of the audio (KNOWN-ISSUES §1), Watch screenshots, the photo
  licences, the published privacy/support pages, and either translations or shipping English (plus any complete
  locale) first — the delivery workflow's strict translation gate passes with English only today.

## How to work on it

- **No Mac needed for most work:** every macOS step runs on GitHub Actions. Open a pull request into `main`; the
  `iOS` workflow's `gate` must be green. Label the PR `captures` to run the full UI tour and App Store screenshots.
  Read results from the `ci-results/*` branches (see [TESTING-AND-CI.md](TESTING-AND-CI.md)).
- **Local checks (Linux or Mac, Python 3.12+):** `python3 tools/ci/lint_tells.py`, `python3 tools/ci/test_hygiene.py`,
  `python3 tools/verify-ios-resources.py`, `python3 tools/curriculum/build.py --check`,
  `python3 tools/l10n/report.py --check --strict`, `python3 tools/marketing/screenshots.py --check`.
  On a Mac: `swift test --package-path ios`, `cd ios && xcodegen generate && open Timbre.xcodeproj`.
- **Rules that must not be broken** (from the owner): never paste secrets into chat or commits (they go into GitHub
  secrets / the `apple-delivery` environment); never dispatch the Apple delivery workflow without the owner's explicit
  go; nothing reaches `main` without the owner's review; agents write English only (translations go through
  [l10n/](l10n/)); no `[skip ci]` commits touching `ios/`.
- **To continue the agency process** (reviews → work packages → parallel teams → integration → gate → jury):
  follow [process/AGENCY-WORKFLOW.md](process/AGENCY-WORKFLOW.md) §12 "Running round 17 from here".

## Contacts and accounts

- Owner / publisher: Shahrad Azeri Sharghi (azerish25@gmail.com), GitHub `azerish25-ux`.
- Bundle id `com.shahradazerisharghi.timbre`; App Group `group.com.shahradazerisharghi.timbre`; products
  `timbre_pro_annual`, `timbre_pro_monthly`, `timbre_plus_lifetime` (+ price tests `timbre_pro_annual_b/_c`).
- Third-party services to configure: TelemetryDeck (analytics app ID), a remote-config URL, App Store Server
  Notifications v2 — see [ios/APPLE-DELIVERY.md](ios/APPLE-DELIVERY.md) §5.
