# Release translation and CI implementation plan

**Goal:** Close bounded developer CI gaps without dispatching Apple delivery or reducing the 49-language app / 48-language lesson scope.

**Architecture:** Export English XLIFF from the checked-out source before choosing shipping locales. Feed that export to the existing report model, coverage selection and strict critical checks. Keep simulator work serial and preserve every existing capture assertion.

**Files:** `.github/workflows/{ios,nightly,l10n,apple-delivery}.yml`, `tools/l10n/shipping.py`, `tools/l10n/tests/test_shipping.py`, `ios/TimbreUITests/{FirstSessionUITests,TimbreUITests}.swift`, `ios/TimbreAppTests/{CommerceIntegrationTests,StoreKitTestEnvironment}.swift`.

- [x] Write and run failing Python tests for authoritative export validation, critical-aware locale selection, and complete UI scope independent of shipping selection.
- [x] Add `shipping.py --xliff PATH --require-complete`; reject missing, empty, non-English or structurally empty exports; include pending imports in completion checks.
- [x] Generate/export before delivery selection, pass the same export to all checks, use `--critical`, retain full lesson strict gate and internal-only build stamp. Strengthen localization export checks without treating handoff freshness as translation completeness.
- [x] Run `python tools/curriculum/build.py --check` in core. Add FirstSession UI tests and a real silent-string scene assertion to nightly.
- [x] Terminate the UI app only when running. Await StoreKit cleanup with a 30-second bound, preserving failures.
- [x] Run focused and full Python tests; validate against downloaded current-head XLIFF. Record native checks as pending macOS CI and request independent review before root commit.

Watch capture design (separate task): build unsigned TimbreWatch for an available 416×496 native simulator; deterministic DEBUG snapshot and page launch arguments; capture Today/metronome through genuine views; export PNGs and verify pixel dimensions. A watch-face complication capture needs a genuine configured face and separate verification; an app view cannot stand in for it.

No commits, pushes or Apple delivery dispatch in this task.

Verification: focused Python tests initially failed because the export/completeness options did not exist, then passed (5 tests). The missing-English-folder regression then failed and passed after the scope check correction (6 tests). An unapplied-critical-translation regression failed and then passed after including pending imports in critical selection (7 focused tests). Final full localization suite passed **159 tests**. Ruby YAML parsing succeeded for all four workflows; scoped `git diff --check` passed. Comment hygiene passed with an existing warn-only PaywallWinBack inline-orb finding. Downloaded `0c67901` English XLIFF passes both `--require-complete` and `--min 95 --critical` with 49 app languages, all 48 targets retained and zero critical gaps. Native UI/StoreKit execution awaits macOS CI. This local export validation does not replace a fresh export of the final changed revision. Root was asked to arrange independent review before commit.
