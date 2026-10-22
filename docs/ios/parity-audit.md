# Android → native Swift parity evidence

This audit compares the checked-in authoritative `reference/android` implementation with the current iOS source. It describes implemented behavior and bounded evidence, rather than treating a successful compile as complete parity.

## Runtime evidence boundary

[CI run39851758978](https://github.com/azerish25-ux/tuner/actions/runs/39851758978) passed core regression tests, iPhone application/StoreKit/UI tests and an unsigned generic-iOS archive according to the coordinating agent. Optional ads-overlay compilation also passed. Later pause/reference/calibration changes, additional restoration/metronome assertions and iPad coverage await the next exact-revision run; do not attach the earlier pass to those edits.

## Source-to-Swift mapping

| Shipped Android behavior/source | Native implementation | Evidence and limits |
|---|---|---|
| Complete instruments/presets with factual attribution (`catalog.json`, `CatalogMapper`) | Catalog.swift and bundled JSON:60 instruments,8 families,102 presets; separate chromatic reference | Catalogue counts/default integrity/anchors tested; all source/provenance/license fields retained. |
| Photographed variants and physical reference ranges (`InstrumentPhotos`, `MalletPhotoTunings`) |71 photo mappings,142 PNG imagesets; tuning-aware PhotoSelection | Bass4/5 and all mallet variants follow their preset; compatible ukulele/wind/reed aliases remain selectable. Core mapping tests and paid/free UI flows. |
| Paired physical strings retain each sounding pitch | Course entries plus coursesByAnchor, Bench strip | Twelve-string partners remain12 targets/six anchors; core/app tests cover this structure. |
| Browse/search/family grouping/free/paid gates (`LibraryScreen`, `ShelfRoute`) | LibraryView with search, filters, image rows, completed-session-first recent strip and tuning menus | Native UI uses list rows rather than the Android two-column shelf. Recents deduplicate completed instrument sessions first, with remembered-selection fallback only when none exist; new regression execution is pending. Atomic selection commits instrument/preset/photo together. |
| Bench image, target note/cue, peg controls, ±50¢ precision dial, signal meter and transport | BenchView, TargetLabelFormatter, AppStore | Note/action cues and flat spellings retained; Turkish oud caution retained. Alternate images are reachable through Collection; native configuration presentation differs. |
| Auto/manual target matching and stable in-tune confirmation | AppStore.accept, TuningTracker/StabilityTracker | Core timing/signal rules tested; no fabricated measurement. Manual reference changes now reset preserved readings without disabling automatic detection internally; new regression execution is pending. |
| Explicit pause with retained last reading; tone must not masquerade as microphone pitch | AppStore.isReadingPreserved and AudioService capture/tone lifecycle | Pause shows LAST; stop/selection reset clears. New reference/calibration reset regression is pending final CI. |
| A4 presets plus finite custom415–466; note systems; shipped temperament tables | SettingsView, PitchMath, Temperament | Conversion/notation/table tests; approximate historical tables preserve Android behavior rather than claiming independent historical accuracy. |
| Paid written transposition/capo affect labels only | SettingsView and AppStore target/display split | App integration tests distinguish display-only adjustment from actual calibration frequency. |
| Confidence presets, theme/system mode, haptics/reduced motion/language | SettingsView, RootView, selected-language bundle resolver | Native controls preserve behavior; accessibility-size and RTL test flows exist. All49 language tables are not equivalent to full linguistic review. |
| All8 vocal exercises selectable, demonstrated skill suggests next but does not gate | VoiceExercise, VoiceAttempt, VocalProgression, VoiceView | Warm-up, holds, interval, melody, range and song definitions/scoring have regression tests; selected level and evidence persist. |
| Signal coaching, input meter, continuous hold, live trace and truthful result | VoiceView guidance/meter/hold, VoiceAttempt summaries | Paid simulator flow runs a timed unsupported capture and displays no invented accuracy. Physical singing/microphone performance remains unmeasured. |
| Studio40–240BPM, beat choices2/3/4/6, subdivisions1–4, accent/tap and paid gate | StudioView, AppStore, OutputRenderer | Output core tests; current paid flow reaches Studio. Added actual metronome start/background-stop assertions await final revision's run. |
| Studio preset notes/selection and current-instrument practice | Studio tuning picker/note summary and HistoryView filter | Source omission from the early prototype is closed; selection persists through the shared validated state path. |
| Seven-day duration activity, measured fortnight comparison and per-exercise best/attempts (`HistoryStateHolder`, `ProgressScreen`) | PracticeAnalytics, HistoryView, PracticeRecord.durationMs | Calendar/timezone, unknown duration, minimum3 measured sessions per side, same non-voice instrument and unscored voice cases tested. History is retained rather than truncated at500. |
| Completed session summaries only; no stored recordings | LocalStore/PracticeRecord | Atomic JSON persistence/readback, failure reporting and clear-history progress reset; failed voice save has explicit retry state. |
| One-time unlock with restore/pending/refund/unavailable states | StoreKit2 CommerceService and PlusView | Verified Apple transactions only; local StoreKit purchase/refund/restore/Ask to Buy tests and paid UI flow passed for the tested revision. Real Apple product/account configuration remains delivery work. |
| Free-session interstitial policy plus consent/privacy options | PostTuningAdPolicy and optional AdvertisingService overlay | Policy tests; baseline excludes advertising SDKs entirely. Optional overlay compile/live configuration is a separate verification scope. |
| Foreground/lifecycle/error handling | RootView and AudioService generation/cancellation/permission checks | iPhone UI flows cover navigation; additional metronome background and iPad checks pending. Device route/interrupt/acoustic behavior is not established by simulator tests. |

## Known differences and remaining delivery work

- Native SwiftUI presentation adapts Android layouts and configuration controls to iOS. Collection recents preserve Android's completed-session-first ordering and remembered-selection fallback.
- Imported catalogue/photo/font content is offline and retained with attribution/licenses.49 localization tables and selected-language routing are implemented; no claim is made that every phrase in every language was independently reviewed.
- The optional ad-supported build requires actual iOS AdMob identifiers and configured privacy messages. Neither live ad delivery nor regional consent behavior has been validated in this audit. The baseline build links no advertising SDK.
- Simulator automation and an unsigned archive cannot establish real iPhone microphone accuracy/latency or replace Apple signing. Product creation, privacy metadata, signing and App Store Connect delivery are outlined in APPLE-DELIVERY.md and require the owner handoff.
- Final automated-verification status must use the latest commit's actual results. The working revision includes new tests/changes beyond run39851758978; they remain pending rather than inheriting its success.
