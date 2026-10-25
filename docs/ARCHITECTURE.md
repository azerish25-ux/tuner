# Timbre for iOS: architecture

This is the map of the codebase for whoever takes it over. It says what each part is, where it lives and how the parts
connect. Paths are from the repository root; type and member names are given so you can jump to them
(`Type.member`). Everything here was checked against the code at the commit this file was added in. When the code and
this file disagree, the code is right: fix this file in the same change.

Related documents (read them rather than expecting their content repeated here):

| Document | What it covers |
|---|---|
| [README.md](../README.md) | One-page overview, build commands, purchase identifiers |
| [TESTING-AND-CI.md](TESTING-AND-CI.md) | Every test suite, every workflow, the gates, the `ci-results/*` branches, local runs |
| [TOOLS.md](TOOLS.md) | Every script under `tools/`, with commands, inputs and outputs |
| [ios/APPLE-DELIVERY.md](ios/APPLE-DELIVERY.md) | App Store Connect, signing, products, remote settings file, Game Center IDs, Watch, MusicKit: the owner's steps |
| [ios/APP-STORE-LISTING.md](ios/APP-STORE-LISTING.md), [ios/APP-STORE-LISTING-LOCALIZED.md](ios/APP-STORE-LISTING-LOCALIZED.md) | Store text, screenshot tables (read by `tools/marketing/screenshots.py`) |
| [ios/PRIVACY.md](ios/PRIVACY.md) | The published privacy policy (must match what the code sends) |
| [ios/AUDIO-DEVICE-TESTS.md](ios/AUDIO-DEVICE-TESTS.md) | Manual audio checks on a real phone before a release that touches audio |
| [ios/resource-inventory.md](ios/resource-inventory.md) | The original Android resource import (partly out of date, see [Known discrepancies](#16-known-discrepancies-and-legacy)) |
| [content/AUDIO-SOURCES.md](content/AUDIO-SOURCES.md) | Licence and provenance of every bundled audio sample |
| [content/PUBLIC-DOMAIN-CLEARANCE.md](content/PUBLIC-DOMAIN-CLEARANCE.md), [content/SONG-LICENSING-PLAYBOOK.md](content/SONG-LICENSING-PLAYBOOK.md) | Song clearance rules and the licensing plan |
| [l10n/HANDOFF.md](l10n/HANDOFF.md) | The translators' brief and the localization developer commands (generated) |
| [../tools/curriculum/STYLE.md](../tools/curriculum/STYLE.md) | How lessons are written |

## Contents

1. [At a glance](#1-at-a-glance)
2. [Build system, targets and identifiers](#2-build-system-targets-and-identifiers)
3. [Repository layout](#3-repository-layout)
4. [TimbreCore, folder by folder](#4-timbrecore-folder-by-folder)
5. [The app (ios/Timbre), folder by folder](#5-the-app-iostimbre-folder-by-folder)
6. [Extensions: widgets, watch app, watch complications](#6-extensions-widgets-watch-app-watch-complications)
7. [Data flow](#7-data-flow)
8. [The audio stack](#8-the-audio-stack)
9. [Listening and judging](#9-listening-and-judging)
10. [The 3D stage](#10-the-3d-stage)
11. [Commerce, remote settings, analytics, Game Center](#11-commerce-remote-settings-analytics-game-center)
12. [System surfaces](#12-system-surfaces)
13. [Design system](#13-design-system)
14. [Test hooks](#14-test-hooks)
15. [Resources](#15-resources)
16. [Known discrepancies and legacy](#16-known-discrepancies-and-legacy)

---

## 1. At a glance

| | |
|---|---|
| Language, UI | Swift (language mode 5, complete concurrency checking as warnings), SwiftUI; RealityKit for 3D; AVAudioEngine for audio; StoreKit 2 |
| Minimum OS | iOS 18.0 (iPhone and iPad), watchOS 11.0 |
| Toolchain | Xcode 26 / iOS 26 SDK or later for App Store archives; CI pins Xcode 26.3 (`DEVELOPER_DIR` in every workflow) |
| Project generation | XcodeGen from `ios/project.yml`; the `.xcodeproj` is not committed |
| Third-party code | None. The only package is the local `TimbreCore` (`ios/Package.swift`). TelemetryDeck is called over HTTPS by a small client in `ios/Timbre/Services/Analytics.swift`, not an SDK |
| Size (Swift lines) | TimbreCore 15,366 (57 files); app 71,260 (159 files); widgets 1,296; watch app 979; watch complications 173; tests 12,927 |
| Tests | 463 TimbreCore test methods, 47 app unit tests, 41 UI tests (see [TESTING-AND-CI.md](TESTING-AND-CI.md)) |
| Content | 60 instruments, 8 families, 132 tunings, 73 photographs, 7 3D models, 19 courses, 1,100 lessons, 616 whole songs, 300 recorded samples in 15 sets, 49 localizations |

The split that matters: **`ios/Sources/TimbreCore`** is a Swift package with no UI (Foundation, Synchronization and
`os`, plus Accelerate and AVFoundation where available). It holds the musical logic, DSP, the curriculum model, persistence and the access rules,
and it is what `swift test` covers. **`ios/Timbre`** is the app: SwiftUI screens, the audio engine, the 3D stage,
StoreKit, Game Center, widgets plumbing and everything that needs UIKit or a device.

## 2. Build system, targets and identifiers

### 2.1 XcodeGen

`ios/project.yml` is the only project definition. Generate the project with `cd ios && xcodegen generate`; the
generated `ios/Timbre.xcodeproj` is ignored by git (`.gitignore`). XcodeGen also writes each target's `Info.plist` and
`.entitlements` from the `info:` and `entitlements:` blocks of `project.yml`. Only `ios/Timbre/Info.plist` is listed in
`.gitignore`; the other generated plists and entitlements files are not committed either and should not be.

Project-wide settings (`settings.base` in `project.yml`):

| Setting | Value | Why |
|---|---|---|
| `SWIFT_VERSION` | 5.10 | Swift 5 language mode |
| `SWIFT_STRICT_CONCURRENCY` | complete | Concurrency diagnostics as warnings; `tools/ci/build_warnings.py` counts them per file and fails every other warning |
| `DEVELOPMENT_TEAM` | empty | Delivery passes the team (`apple-delivery.yml`) |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | 1.0.0 / 1 | Delivery overrides both; every bundle carries them |
| `deploymentTarget.iOS` | 18.0 | |
| `xcodeVersion` | 26.0 | |

### 2.2 Targets

| Target | Type | Platform | Bundle id | Sources | Notes |
|---|---|---|---|---|---|
| `Timbre` | application | iOS 18 | `com.shahradazerisharghi.timbre` | `ios/Timbre` (resources from `ios/Timbre/Resources`, `Samples` copied as a folder reference) | Depends on `TimbreCore`, embeds `TimbreWidgets` and `TimbreWatch` (`codeSign: false` for the watch: it signs itself). `TARGETED_DEVICE_FAMILY` 1,2. Compilation condition `COACH_MODEL`; `-weak_framework FoundationModels` (the on-device coach, iOS 26 only, behind `#available`) |
| `TimbreWidgets` | app-extension (WidgetKit) | iOS 18 | `com.shahradazerisharghi.timbre.widgets` | `ios/TimbreWidgets` plus shared app files: `Intents/SharedIntents.swift`, `Intents/WidgetLibrary.swift`, `Intents/StreakSnippet.swift`, `Services/WidgetBridge.swift`, `Services/PracticeActivityAttributes.swift`, `Design/Theme.swift`, the fonts, and every `*.lproj/Localizable.strings(dict)` | Widgets, Control Center controls and the Live Activity UI |
| `TimbreWatch` | application (single-target watch app) | watchOS 11 | `com.shahradazerisharghi.timbre.watchkitapp` | `ios/TimbreWatch` plus `Timbre/Services/WatchSnapshot.swift`, Sora Medium and SemiBold, the string tables | `WKApplication`, `WKCompanionAppBundleIdentifier` = the iPhone app, `WKRunsIndependentlyOfCompanionApp: false`. Embeds `TimbreWatchWidgets` |
| `TimbreWatchWidgets` | app-extension (WidgetKit) | watchOS 11 | `com.shahradazerisharghi.timbre.watchkitapp.widgets` | `ios/TimbreWatchWidgets` plus `WatchSnapshot.swift`, `TimbreWatch/Shared/SnapshotStore.swift`, `TimbreWatch/Shared/WatchTheme.swift`, the string tables | Complications |
| `TimbreAppTests` | unit-test bundle | iOS | (generated) | `ios/TimbreAppTests`, `Tests/Fixtures/Timbre.storekit` | Hosted in the app (`TEST_HOST` / `BUNDLE_LOADER`) |
| `TimbreUITests` | UI-test bundle | iOS | (generated) | `ios/TimbreUITests`, `Tests/Fixtures/Timbre.storekit` | |
| `TimbreCore` | Swift package library | iOS 18, macOS 15 | n/a | `ios/Sources/TimbreCore` | `ios/Package.swift`, tools version 6.0, `swiftLanguageModes: [.v5]`, upcoming feature `StrictConcurrency`; resources `.process("Resources")` (read with `Bundle.module`) |
| `TimbreCoreTests` | package test target | macOS (`swift test`) | n/a | `ios/Tests/TimbreCoreTests` | Fixtures in `ios/Tests/Fixtures` are read from the repository path |

Schemes (`schemes:` in `project.yml`):

- `Timbre`: builds the app and both test bundles; `test` runs `TimbreAppTests` and `TimbreUITests`
  (`parallelizeBuild: false`); `run` uses the StoreKit configuration `Tests/Fixtures/Timbre.storekit`.
- `TimbreWatch`: builds and runs the watch app on its own (Debug).

### 2.3 Entitlements, App Group, capabilities

Every one of the four product targets has exactly one entitlement:
`com.apple.security.application-groups: [group.com.shahradazerisharghi.timbre]`.

- The iPhone app and its widget extension share that App Group container (`UserDefaults(suiteName:)`): the widget
  snapshot (`widget.snapshot`, `Services/WidgetBridge.swift`) and the widget library (`widget.library`,
  `Intents/WidgetLibrary.swift`).
- On the watch the same group id names the watch's own container: the watch app stores the iPhone's last snapshot
  there (`watch.snapshot`, `TimbreWatch/Shared/SnapshotStore.swift`) for the complications.
- Game Center is deliberately **not** in the entitlements (see [APPLE-DELIVERY.md §6.1](ios/APPLE-DELIVERY.md)); the
  app runs without it. MusicKit is an App Service on the App ID, not an entitlement ([§8](ios/APPLE-DELIVERY.md)).
- `UIBackgroundModes: [audio]`: the Metronome tool's click keeps playing with the screen locked.

### 2.4 Info.plist keys the code reads

Build settings flow into `Info.plist` (`targets.Timbre.info.properties`) and are read at run time by `AppLinks`
(`ios/Timbre/Services/ShareDestination.swift`). An empty or unexpanded value counts as unset.

| Info.plist key | Build setting | Read by | Effect when empty |
|---|---|---|---|
| `TimbreTelemetryAppID` | `TIMBRE_TELEMETRY_APP_ID` | `Telemetry` in `Services/Analytics.swift` | No event leaves the device |
| `TimbrePrivacyURL` | `TIMBRE_PRIVACY_POLICY_URL` (default `https://azerish25-ux.github.io/tuner/privacy.html`) | `AppLinks.privacy` | Falls back to the published address. `TimbrePrivacyPolicyURL` carries the same value; no Swift code reads it today |
| `TimbreAppStoreID` | `TIMBRE_APP_STORE_ID` (digits) | `AppLinks.appStoreID`/`appStore`, `ShareDestination.friendOffer`, `StoreRating` | No App Store link, no "Give a friend a month" offer link, no rating lookup |
| `TimbreShareURL` | `TIMBRE_SHARE_URL` (https) | `AppLinks.share`, `ShareDestination` | Shares carry the App Store page, or no link at all without the App Store ID |
| `TimbreRemoteConfigURL` | `TIMBRE_REMOTE_CONFIG_URL` (https) | `AppLinks.remoteConfig`, `RemoteConfig` | Built-in defaults only |
| `TimbreBuildChannel` | `TIMBRE_BUILD_CHANNEL` | (stamp) | `internal` marks an internal-TestFlight build (`apple-delivery.yml`) |
| `CFBundleLocalizations` | (literal list) | iOS | Edited by `tools/l10n/shipping.py --apply` |

Other notable keys: `NSMicrophoneUsageDescription`, `NSAppleMusicUsageDescription`, `NSUserActivityTypes`
(`com.shahradazerisharghi.timbre.today`, the watch hand-off), `CFBundleURLSchemes: [timbre]`, `CFBundleDocumentTypes`
and `UTImportedTypeDeclarations` for ChordPro (`.cho`, `.chordpro`, `.chopro`, `.crd`) and plain text,
`NSSupportsLiveActivities`, `UIAppFonts` (the four Sora faces), `ITSAppUsesNonExemptEncryption: false`,
`UIApplicationSupportsMultipleScenes: false`, `UILaunchScreen.UIColorName: LaunchBackground`.

Privacy manifests: `ios/Timbre/Resources/PrivacyInfo.xcprivacy` (required-reason APIs: system boot time `35F9.1`,
UserDefaults `CA92.1` and `1C8F.1`; collected data: product interaction, performance, crash and advertising data, all
not linked and not tracking), and one each in `ios/TimbreWidgets`, `ios/TimbreWatch`, `ios/TimbreWatchWidgets`.
`tools/verify-ios-resources.py` checks the app's and the widgets' manifests.

## 3. Repository layout

| Path | What |
|---|---|
| `ios/project.yml` | XcodeGen project (targets, Info.plist, entitlements, schemes) |
| `ios/Package.swift` | The `TimbreCore` package and its test target |
| `ios/Sources/TimbreCore/` | Core library ([§4](#4-timbrecore-folder-by-folder)) |
| `ios/Timbre/` | The iPhone/iPad app ([§5](#5-the-app-iostimbre-folder-by-folder)) |
| `ios/TimbreWidgets/`, `ios/TimbreWatch/`, `ios/TimbreWatchWidgets/` | Extensions ([§6](#6-extensions-widgets-watch-app-watch-complications)) |
| `ios/Tests/` | `TimbreCoreTests` and `Fixtures/` (StoreKit file, saved-state fixture, real-world audio corpus manifest) |
| `ios/TimbreAppTests/`, `ios/TimbreUITests/` | App unit tests and UI tests |
| `tools/` | Content builders, localization pipeline, marketing renderers, 3D pipeline, CI scripts ([TOOLS.md](TOOLS.md)) |
| `.github/workflows/` | Seven workflows ([TESTING-AND-CI.md](TESTING-AND-CI.md)) |
| `docs/` | This documentation |
| `.swiftlint.yml`, `.swiftformat` | Lint and format configuration (SwiftLint runs in CI; SwiftFormat is local only) |

## 4. TimbreCore, folder by folder

`ios/Sources/TimbreCore`. Pure logic; almost every type is `Sendable` and has tests in `ios/Tests/TimbreCoreTests`.

### Audio (`Audio/`, 8 files): offline synthesis and the band's score

| File | Key types | What it does |
|---|---|---|
| `ToneSynth.swift` | `ToneRequest`, `ToneClip`, `ToneClipPlayer`, `ToneSynth` | Renders "Hear it", chords, listen steps and the tuner's reference: Karplus–Strong strings, a struck bar, sustained bowed/blown/sung voices. Equal requests render the same audio, so the app caches clips |
| `InstrumentVoice.swift` | `InstrumentVoice` | Maps a catalogue instrument (or family, or "voice") to a voice and its synthesis profile |
| `SampleLibrary.swift` | `SampleLibrary`, `SampleManifest`, `SampleCredit` | The recorded instruments in `Samples/`: lazy decoding into a size-capped cache, purge on memory warning |
| `SampledTones.swift` | `SampledInstrument`, `SampledTones` | Renders a `ToneRequest` from recordings when they cover the note; nil otherwise, so `ToneSynth` takes over |
| `StrumFeel.swift` | `StrumFeel` | Timing and weight of each string in a down or up stroke, so chords from single notes sound strummed |
| `BandGroove.swift` | `BandStyle`, `BandCue`, `BandStyleIndex`, `BandGroove` | The band's styles (standard, pop, rock, reggae, country, funk, ballad), how a song's style is found, and one bar of the band as pure data (drum hits, bass notes, chord strokes) |
| `OutputAudio.swift` | `MetronomeRenderer`, `MetronomePattern`, `ReferenceToneRenderer`, `ReferenceToneWaveform` | The metronome click on a sample clock (sounds `click`, `wood`, `beep`); the Android-parity reference tone (kept, no longer used for the tuner's tone) |
| `DroneRenderer.swift` | `DroneRenderer` | Tanpura and pure drones on a sample clock |

### Catalog (`Catalog/`, 5 files)

| File | Key types | What it does |
|---|---|---|
| `Catalog.swift` | `Catalog`, `Instrument`, `InstrumentFamily`, `Tuning`, `Course`, `CustomTuning`, `ReferenceMode`, `InstrumentPhoto`, `LocalizedText` | Decodes `catalog.json` and `photos.json`. `LocalizedText` resolves `timbre_catalog_*` keys through `TimbreLocalization.bundle` |
| `PhotoSelection.swift` | `Catalog.photo(instrumentId:tuningId:preferredAsset:)` | Picks the photograph for an instrument and tuning |
| `PitchMath.swift` | `PitchMath`, `Temperament` | Hz/MIDI/cents conversions, note names, temperaments (Android's offset tables) |
| `NoteNames.swift` | `NoteNames` | Note and chord names in the chosen system (`english`, `german`, `solfege`, `sargam`, `numbered`); `NoteNames.active` is set by the app; spoken words per language |
| `TimbreLocalization.swift` | `TimbreLocalization` | The app language and its bundle ([§12.9](#129-localization-at-run-time)) |

### Coach (`Coach/`, 2 files)

`CoachNotes.swift` (`Coach`, `CoachNote`, `CoachFact`, `CoachAction`, `CoachSkill`) turns measured facts (timing,
note and chord scores, string drift, streak, Today) into a few specific notes, each with one action.
`CoachTiming.swift` (`CoachHit`, `CoachTake`, `Coach.Change`) finds chord changes that keep landing late. The app
words the notes (`Journey/CoachVoice.swift`).

### Commerce (`Commerce/`, 2 files)

`Access.swift`: `TimbreProduct` (product ids), `EntitlementEvidence`, `FreeOpenings` (lessons the remote settings open
to everyone; `FreeOpenings.current` is thread-safe global state the app sets), `AccessPolicy` (`isPro`, `canTune`,
`canUse(tuning:)`, `canPlay(_:pro:progress:courses:openings:)`, `placementPass`). `PlanComparison.swift`: the paywall's
Free/Pro table built from the enforced rules. See [§11.1](#111-commerce).

### DSP (`DSP/`, 9 files)

| File | Key types | What it does |
|---|---|---|
| `DSP.swift` | `DetectedPitch`, `DspMath`, `Fft`, `Autocorrelation` | Basic transforms (radix-2 FFT matching Android) |
| `PitchDetectors.swift` | `YinPitchDetector`, `MpmPitchDetector` | Monophonic pitch. The app's tuner uses YIN (`AudioService`'s `PitchWorker`) |
| `PolyTuner.swift` | `PolyTuner`, `PolyReading` | Strum to tune: every string's offset from one strum (about 0.65 s, 0.85 s on a bass) |
| `ChordRing.swift` | `ChordRing` | Which strings of a strummed chord rang, from one `PolyTuner` reading ("String 3 isn't ringing") |
| `ChordRecognizer.swift` | `ChordRecognizer`, `ChordTarget`, `ChordEstimate` | Chord recognition from spectral peaks and templates: readings named major, minor, 7, maj7, m7, sus2, sus4 or 5; diminished, dim7 and augmented only as lesson targets or when nothing else fits |
| `OnsetDetector.swift` | `OnsetDetector`, `RhythmJudge` | Spectral-flux onsets; pairing of onsets with expected beats |
| `StrokeChords.swift` | `StrokeChords` | Each stroke's chord, attack and ring about 0.25 s after the onset |
| `LessonListening.swift` | `LessonListening` | One place that runs chords, onsets, strokes and strums over the microphone stream (or a recording) |
| `AudioClip.swift` | `AudioClip` | A recording fed in the microphone tap's own 512-frame buffers, for tests and the demo clip |

### History (`History/PracticeAnalytics.swift`)

`PracticeAnalytics`, `PracticeHistorySummary`: 14-day accuracy comparisons and 7-day activity, ported from Android's
`HistoryStateHolder` rules.

### Learn (`Learn/`, 9 files)

| File | Key types | What it does |
|---|---|---|
| `Curriculum.swift` | `Curriculum`, `LearnCourse`, `LearnUnit`, `Lesson`, `LessonStep`, `LessonVisual`, `TimedNote`, `ChordSpec`, `Fretting`, `LearnText` | The model of `curriculum.json`; `LearnText.localized` reads `Learn.strings` |
| `CurriculumStore.swift` | `CurriculumStore` | Decodes the curriculum once, off the main thread, shared by everyone |
| `LessonEngine.swift` | `PlayAlongJudge`, `CuePlan`, `TempoLadder`, `LatencyCalibration`, `NoteSequenceJudge`, `LessonRun`, `LessonResult`, `LearnProgress` | Judging, stars, XP scaling, unlocking, weak spots |
| `PlayAlongSession.swift` | `PlayAlongSession`, `ChordAlongJudge` | One play-along take: clock, count-in, combo multiplier, sections; "Chords & words" judging |
| `StrumTake.swift` | `StrumTake` | A rhythm step judged stroke by stroke (timing, chord, muted and accented strokes) |
| `SongArrangement.swift` | `SongArrangement`, `LyricSheet` | A song's sections, chord chart, words |
| `SongOfTheDay.swift` | `SongOfTheDay`, `SongPreview` | The Songs tab's featured song and the few seconds a sleeve plays |
| `Placement.swift` | `CoursePlacement`, `PlacementCheck` | Onboarding's experience answer as a place in each course; the 45-second check |
| `WeakSpots.swift` | `PracticeItem`, `ItemScore`, `WeakSpot`, `WeakSpotReview` | Notes and chords that went badly and the review lesson built from them |

### Notation (`Notation/`, 2 files)

`Notation.swift` (`SpelledPitch`, `KeySignature`, `Clef`, `NotationMeter`, `NoteDuration`) and `NotationScore.swift`
(`NotationScore`, `NotationMeasure`, `NotationEvent`, `NotationBeam`, `NotationLayout`): melodies spelled and quantized
into standard notation. The app engraves them (`Learn/NotationEngraver.swift`).

### Persistence (`Persistence/LocalStore.swift`)

`UserSettings`, `Handedness`, `ShowMeKey`, `PracticeRecord`, `LocalStore`. See [§7.3](#73-persistence).

### Practice (`Practice/`, 8 files)

| File | Key types | What it does |
|---|---|---|
| `Chords.swift` | `ChordFormula`, `ChordShape`, `ChordFingering`, `ChordFinder`, `ChordLibrary`, `ScaleFormula`, `ScaleMap`, `IntervalName` | Chord shapes (hand-picked guitar voicings, a finder for other tunings), scales on the neck |
| `EarTraining.swift` | `EarSession`, `EarDrill`, `EarQuestion`, `SplitMix64` | Ear-training rounds, deterministic random |
| `FreeTier.swift` | `FreeTier` | What the free plan includes beyond the tuner |
| `PitchSniper.swift` | `PitchSniper` | The Bullseye game (ten rounds, hidden tune) |
| `Progression.swift` | `ProgressState`, `Level`, `XPReward`, `Progression`, `Quest`, `Quests`, `ProgressEvent`, `ProgressUpdate`, `Achievement`, `Achievements`, `StringHealth` | XP, levels, quests, badges, string drift ([§7.4](#74-progress-xp-quests-achievements)) |
| `Streaks.swift` | `Streaks`, `StreakSummary`, `StreakCache`, `StreakFreeze`, `DailyActivity`, `DailySet` | Streaks, freezes, Today ([§7.5](#75-streaks-and-today)) |
| `SpacedReview.swift`, `SpacedReviewSession.swift` | `SpacedReview`, `ReviewItem`, `ReviewCard`, `ReviewDeck`, `ReviewCredit` | SM-2 spaced review of what slipped in lessons |

### Signal, Tuning, Voice

- `Signal/OneEuroFilter.swift`: `OneEuroFilter` (smooths the needle, strobe and 3D peg) and `StrobePhase`.
- `Tuning/TuningTracker.swift`: `InTuneRule` (default band 5 ¢, hold 650 ms, continuity 150 ms, lock gap 500 ms),
  `TuningPrecision` (`beginner` 5 ¢, `standard` 3 ¢, `pro` 1 ¢), `TuningStatus`, `TuningReading`, `TuningTracker`,
  `StabilityTracker`, `ReadingCadence`, `AnalysisWindowPolicy`.
- `Tuning/CourseGroups.swift`: `CourseGrouping` (unison pairs share a chip; octave partners keep one each).
- `Tuning/TargetLabelFormatter.swift`: string label formatting kept from Android.
- `Voice/VoiceExercise.swift`: the eight vocal exercises, `VoiceAttempt` scoring, `VocalProgression`.

### YourSongs (`YourSongs/`, 5 files)

`ChordPro.swift` (lenient ChordPro parser, import of chord-over-words sheets, in-place edits), `ChordSymbol.swift`
(chord symbols and spelling after transposition), `ChartPlayback.swift` (`ChartTransform`, `CapoAdvisor`,
`ChartTimeline`, `TapAlong`, `ChartPractice`, `YourSongsPolicy`), `RecordingAnalysis.swift` (tempo, beats and a chord
per bar from a recording; `DraftChart`), `UserSongLibrary.swift` (one JSON file per chart, imported audio in `Audio/`).

### Resources (`Resources/`)

`catalog.json`, `photos.json`, `curriculum.json` (11 MB, one line). See [§15](#15-resources).

## 5. The app (ios/Timbre), folder by folder

`ios/Timbre/TimbreApp.swift` is the entry point ([§7.1](#71-launch)). The tab bar (`Root/RootView.swift`) has five tabs:
Tune (`AppTab.tune`), Learn, Songs (titled by the Songs course), Practice, Progress (`AppTab.journey`).

| Folder | Files | What lives there |
|---|---:|---|
| `Audio/` | 4 | `AudioService` (engine, microphone, tones, metronome, drone, band) and `AudioSessionOwner`; `Band.swift` (band arrangement, offline rendering, render-thread player); `SoundFX.swift` (interface sounds, `RoomReverb`); `CueVoice.swift` (spoken note cues, `SpeechGate`) |
| `Design/` | 12 + `Shaders.metal` | The design system ([§13](#13-design-system)) |
| `Instruments/` | 4 | `InstrumentsView` and `InstrumentPicker` (every instrument as studio cards), `CustomTuningEditor`, `TuningMenu` (the tuner header's tuning menu, `CustomTuningAccess`), `ProLock` |
| `Intents/` | 9 | App Intents, App Shortcuts, `DeepLink`, Spotlight, widget library publishing ([§12](#12-system-surfaces)) |
| `Journey/` | 5 | The Progress tab: `JourneyView`, the coach (`CoachCard`, `CoachVoice`, `CoachPolish`), `WeekRecap`, `StreakCelebration` |
| `Learn/` | 34 | The Learn tab and the lesson player: `LearnView` (course path), `LessonPlayer`/`StepView`, every step view, the play-along highway and runway, song sheet/opener/perform, notation engraving, "Show me" 3D demonstrations, diagrams, results, latency calibration, spaced and weak-spot review |
| `Onboarding/` | 6 | `OnboardingView` (pages `welcome, experience, goal, hand, microphone, firstTune, firstChord, reminder, plan`), `FirstTuneStep`, `FirstChordStep`, `PlacementCheckView`, `ReminderAskStep`, `OnboardingDeferral` ("Just tune" defers the questions until Learn first opens) |
| `Paywall/` | 7 | `PaywallView` (contexts `onboarding`, `standard`), `PaywallPlan` (the person's plan and outcomes), heroes (`PaywallPreview`, `PaywallPlanHero`, `PaywallScenes`), `PaywallWinBack` (one-time exit offer), `BillingIssueBanner` |
| `Practice/` | 19 | The Practice tab (`PracticeView`, `PracticeRoute`: metronome, ear, chords, scales, drone, voice, intonation, sniper), Today (`DailySetCard`), the tools (`MetronomeView`, `DroneView` with `DroneTanpura`/`DroneSingAlong`, `ChordsView`/`ChordLibraryView`, `ScalesView`, `EarTrainingView`, `PitchSniperView`, `IntonationView`, `VoiceView`), hub cards and previews |
| `Previews/` | 1 | SwiftUI previews of the design system |
| `Resources/` | | Assets, fonts, models, samples, string tables, privacy manifest ([§15](#15-resources)) |
| `Root/` | 2 | `RootView` (tabs, overlays, scene-phase handling, URL handling) and `DemoScenes.swift` (debug-only capture scenes, [§14](#14-test-hooks)) |
| `Services/` | 18 | `AppStore`, `TunerSession`, `LiveReading`, `CommerceService`, `RemoteConfig`, `Analytics`, `GameCenter*`, `LiveActivityController`, `PracticeReminder`/`TrialReminder`, `ShareDestination`/`AppLinks`, `StoreRating`, `WatchBridge`/`WatchSnapshot`, `WidgetBridge`, `PracticeActivityAttributes`, `Localization.swift` |
| `Settings/` | 1 | `SettingsView`: groups Tuning (A4 reference, temperament, precision, note names, Tune by feel, strobe precision, capo, transpose), Display (handedness, Charts as printed, string order, Simple tuner, Calm mode), Feedback (haptics, Feel the beat, stage, feel test), Reminders (daily reminder and time, Advanced listening), Language (app language), Privacy (privacy policy, Acknowledgements, Share anonymous usage data, Clear practice history). `Acknowledgements` lists Fonts, Music, Instruments and Sounds credits |
| `Songs/` | 2 | `SongsView` (record shelves, song of the day, `SongsCatalog`), `SongCover` (generative sleeves `CoverArt`, `CoverMesh`, `VinylRecord`) |
| `Stage/` | 6 | The 3D and 2D tuning stages ([§10](#10-the-3d-stage)) |
| `Support/` | 3 | `TestSupport`, `DemoData`, `Preferences` |
| `Tips/` | 1 | TipKit coach marks (`TimbreTips`; off under automation) |
| `Tune/` | 14 | `TuneView` (the tuner), `Readout`, `StringRail`, `TunerControls`, `ChromaticStage` (strobe dial), `LockLatch`, `Celebration` (full tune, share cards), `FeelToggle` (Tune by feel), Strum to tune (`StrumTuneView`, `StrumModel`, `StrumMeters`, `StrumFinale`), `TuneSidePane` (iPad), `TunerVoiceOver` |
| `YourSongs/` | 10 | The player's own chord charts: `YourSongsStore`, `YourSongsShelf`, `ChartSongView`, `ChartSheet`, `ChartEditorView`, `ChartPracticeView`, `ChartDock`, `ChartFollower`, `RecordingPlayer`, `AppleMusicListen` |

## 6. Extensions: widgets, watch app, watch complications

**`ios/TimbreWidgets`** (`TimbreWidgets.swift` is the `WidgetBundle`):

| Widget / control | Kind | Data source |
|---|---|---|
| `QuickTuneWidget` | `timbre.quicktune` (configurable, `QuickTuneConfiguration`) | `WidgetSnapshot` + `WidgetLibrary` instruments |
| `NextLessonWidget` | `timbre.nextlesson` | `WidgetSnapshot.lesson` |
| `NextSongWidget` | `timbre.nextsong` (configurable shelf, `NextSongConfiguration`) | `WidgetLibrary` shelves |
| `StreakWidget` | `timbre.streak` | `WidgetSnapshot` carried forward by `StreakStatus` |
| `TunerControl` | `timbre.control.tune` | Runs `OpenTunerIntent` |
| `MetronomeControl` | `timbre.control.metronome` | Runs `OpenMetronomeIntent` |
| `PracticeLiveActivity` | ActivityKit | `PracticeActivityAttributes` (Lock Screen, Dynamic Island, Smart Stack, StandBy) |

`ConfigurationIntents.swift` defines the widgets' configuration intents and entities over `WidgetLibrary`.

**`ios/TimbreWatch`** (`TimbreWatchApp`): two pages, `TodayScreen` (streak flame in today's set ring, quest, next
lesson, "Start today's practice") and `MetronomeScreen` (`WristMetronome`: haptic taps, 30–240 BPM, 2/4 to 7/4,
Digital Crown). `WatchSync` receives the iPhone's snapshot (application context or complication transfer) and stores
it (`SnapshotStore`). `WatchTheme.swift` has the watch's own `Palette` and `Typeface`.

**`ios/TimbreWatchWidgets`**: `StreakComplication` (`timbre.watch.streak`): accessoryCircular, Rectangular, Corner and
Inline, drawn from `SnapshotStore`.

## 7. Data flow

### 7.1 Launch

1. `TimbreApp.init` (`ios/Timbre/TimbreApp.swift`) calls `CurriculumStore.shared.preload()` (decode on a background
   queue) and `TimbreTips.configure()`.
2. `Bootstrap` (same file) decodes the `Catalog` on a detached task, awaits `CurriculumStore.shared.load()`, then
   creates `AppStore(directory:catalog:)`. The directory is `TestSupport.storageRoot` (a UI test's own folder) or
   `LocalStore.defaultDirectory` (Application Support/Timbre).
3. In debug builds `Bootstrap.open` applies launch keys: `TIMBRE_SKIP_ONBOARDING`, `TIMBRE_STAGE_MODE`,
   `TIMBRE_DEMO_DATA` (seeds `DemoData` on an empty store) and starts a `DemoScene`.
4. `SpotlightIndex.refresh(store)` runs; queued hand-offs (Spotlight, Apple Watch) run once the store exists
   (`Bootstrap.whenReady`).
5. The window shows, in order of precedence: `RecoveryNotice` when `LocalStore.recovery` is set (the saved file was
   unreadable and a backup or a fresh state opened), `LaunchFailure` when opening threw (with "Try again" and, for a
   storage error, "Open without it", which calls `LocalStore.setAside`), otherwise `RootView` with `AppStore`,
   `AudioService` and `CommerceService` as environment objects and `TunerSession` in the environment.
6. `UIApplication.protectedDataDidBecomeAvailableNotification` retries a load that failed because the file was
   protected before the first unlock.

What `AppStore.init` does (`ios/Timbre/Services/AppStore.swift`): opens `LocalStore` with `.background` durability,
applies the language (`TimbreLocalization.language`), note-name default (`UserSettings.applyNotationDefault`), tracker
threshold and precision, haptics switch, analytics sharing (`Analytics.setSharing`, then `Analytics.start()`), wires
`audio.onReading` to `AppStore.accept`, publishes widgets, attaches `LiveActivityController`, and subscribes to
`CommerceService` (republish widgets and re-pin Today when Pro resolves or changes), to the metronome's ownership (a
Metronome-tool session counts as rhythm practice), to day changes and foregrounding (re-pin Today), and to write
failures (`LocalStore.onWriteFailure` shows an alert).

`RootView` then: `.task` runs `applyStreakFreezes`, `syncAchievements`, `GameCenter.shared.launched`, and
`TimbreShortcuts.updateAppShortcutParameters()`. On scene phase change it stops listening in the background, calls
`flushSettings()` whenever the phase is not active, and on becoming active applies freezes and syncs achievements.
Leaving the Tune tab calls `store.stopActivity()`. `keepAwake` disables the idle timer while anything listens or plays.

### 7.2 AppStore, TunerSession and LiveReading

`AppStore` (`@MainActor final class AppStore: ObservableObject`) is the app's one state object and action surface. It
owns `catalog`, `audio` (`AudioService`), `commerce` (`CommerceService`), `live` (`LiveReading`), `tuner`
(`TunerSession`), `curriculum`, and the `LocalStore`. Its `@Published` state is `settings`, `records`, `selectedTab`,
presentation flags (`showPaywall`, `showSettings`, `showInstrumentPicker`), `error`, paywall context, pending routes
(`pendingPracticeRoute`, `pendingLessonId`), reward announcements (`lastReward`, `rewardPulse`, `streakNotice`,
`streakPulse`, `streakMilestone`) and voice-exercise state.

State that changes many times a second is kept out of it on purpose:

- `LiveReading` (`Services/LiveReading.swift`): the current `TuningReading`, input level, voice trace, about 60
  updates a second. Only views that draw the reading observe it.
- `TunerSession` (`Services/TunerSession.swift`, `@Observable`): what the tuner tunes to (string or chromatic note),
  automatic detection, locked strings, celebration counter, game/lesson target (`gameTargetHz`), and the session's
  measurements for its practice record (`@ObservationIgnored`). `AppStore` forwards its tuner API (`selectedCourse`,
  `automatic`, `referenceMode`, `gameTargetHz`, …) so screens read `store.selectedCourse`.

The tuner path per microphone reading: `AudioService` → `AppStore.accept(_:confidence:level:)`. If a lesson owns the
microphone (`lessonListener` set) the raw reading goes to it and nothing else happens. Otherwise: voice exercise
scoring when one runs; else automatic string/note following (`follow`, three agreeing readings via `TunerSession`),
`TuningTracker.accept` against `targetHz`, `live.reading`, then `onTunerFrame` (the feel hook; default
`TunerFrame.standardFeel`, cent detents and the lock haptic), then string health and lock bookkeeping (`noteLock`). A
lock never writes settings on the frame it happens: rewards go through `later { … }` and `updateSettingsSoon`.

Main `AppStore` action groups (all in `AppStore.swift`): instrument/tuning selection (`selectInstrument`, `selectTuning`,
`saveCustomTuning`, `selectReference`, `chooseCourse`), listening (`startListening`, `pauseListening`, `toggleTone`),
sessions (`endTuningSession`, `save`), practice tracking (`beginPractice`, `finishPractice`), lessons
(`canPlay`, `startLessonListening(owner:…)`, `stopLessonListening(owner:)`, `finishLesson`), progress
(`recordProgress`, `markDaily`), Today (`dailySet`, `pinDailyPlan`, `openDailyLesson`), voice (`startVoice`,
`finishVoice`), metronome and drone (`setMetronome`, `toggleMetronome`, `setDrone`, `toggleDrone`), Strum to tune
(`beginStrum`, `endStrum`, `completeStrumTune`), onboarding (`completeOnboarding`, `recordFirstTune`, `planCourse`), and
the paywall (`presentPaywall(_:lesson:instrument:)`). `WeakSpotReview.swift` extends it with review sessions.

### 7.3 Persistence

**The saved state** is one JSON file written by `LocalStore` (`ios/Sources/TimbreCore/Persistence/LocalStore.swift`):

| Item | Value |
|---|---|
| File | `Application Support/Timbre/timbre-state.json` (`LocalStore.fileName`, `defaultDirectory`) |
| Backup | `timbre-state.bak.json`: the file as it stood before the latest save; opens if the file can't be read |
| Quarantine | An unreadable file is moved to `timbre-state.corrupt-<UTC yyyyMMdd-HHmmss>.json`; the newest 3 are kept |
| Contents | `State { version, settings: UserSettings, records: [PracticeRecord], demonstratedLevels }`, `currentVersion = 1` |
| Reading | Lenient: each `UserSettings` field decodes on its own (missing or wrong-typed keys keep the default; unknown keys are skipped); an unreadable record or custom tuning is dropped alone; values are clamped into bounds (`repaired`) |
| Writing | Each save validates only what it changes (`validate`), then commits. `.immediate`: writes before returning, throws on failure. `.background` (what the app uses): changes memory at once, a serial `StateWriter` writes the newest state; bursts coalesce; failures go to `onWriteFailure` and retry on the next save or `flush()` |
| History size | Past `recordLimit` (2,000) records, records older than `rollUpAfterDays` (180) roll up to one per day, instrument, tuning and kind (`LocalStore.rolledUp`), keeping streaks and minutes exact |
| Recovery | `LocalStore.recovery` is `.restoredBackup` or `.startedFresh` (shown once by `RecoveryNotice`) |

`UserSettings` holds everything the player chose and earned: reference pitch, temperament, language, notation,
precision, handedness, selected instrument and photo, last tuning per instrument, custom tunings, metronome and drone
settings, onboarding answers, `progress: ProgressState`, `learn: LearnProgress`, `spacedReview: ReviewDeck`, Today
(`dailyDone`, `dailyPlan`), `shownDemos`, switches (`calmMode`, `simpleTuner`, `tuneByFeel`, `feelTheBeat`,
`chartsAsPrinted`, `shareUsageData`, …). `PracticeRecord` is one practice session (`kind`: `tuning`, `voice`,
`lesson`, `ear`, `rhythm`, `drone`, …; `instrumentId` may be a pseudo id such as `learn.<course>` or
`practice.<kind>`). "Clear practice history" (`LocalStore.clearHistory`) removes records and demonstrated levels, not
settings.

**How the app writes settings** (`AppStore`):

- `updateSettings { $0.x = … }`: validates and stages the change in `LocalStore` at once (`stageSettings`), publishes
  it, applies side effects (language, note names, haptics, analytics sharing, tracker threshold and precision; restarts
  the microphone only when a listening setting changed; re-pins Today if something it depends on changed), and
  schedules one coalesced write 400 ms later (`scheduleSettingsWrite` → `LocalStore.flush(wait: false)`). Returns
  `false` and shows an error if the settings are refused.
- `updateSettingsSoon { … }`: queues a mutation; all queued mutations apply together about 300 ms later as one
  `updateSettings` (`scheduleSettingsBatch`). The tuner's lock path uses it (via the private `later`) so the frame that
  locks a string saves nothing. Write each mutation against the settings it is handed, not a captured copy.
- `flushSettings()`: applies anything queued and waits until the file is on disk. `RootView` calls it whenever the
  scene leaves `.active`.
- `save(_ record:)`: appends a `PracticeRecord` (which also carries any staged settings), then checks streak freezes,
  streak milestones and republishes widgets.

**Small per-device preferences** live in `UserDefaults.standard`, not in the state file. The named ones are in
`Support/Preferences.swift` (`learn.course`, `plan.dailyMinutes`, `analytics.proActive`). Others, by owner:

| Key(s) | Owner |
|---|---|
| `remote.config`, `remote.fetchedAt`, `remote.bucket`, `remote.paywallVariant` | `Services/RemoteConfig.swift` |
| `telemetry.installID`, `telemetry.attributionSent` | `Services/Analytics.swift` |
| `storeRating.line`, `storeRating.fetchedAt` | `Services/StoreRating.swift` |
| `reminder.enabled`, `reminder.minutes`, `reminder.asked`, `trial.reminder.fire`, `trial.reminder.start` | `Services/PracticeReminder.swift` |
| `commerce.subscriptionState` | `Services/CommerceService.swift` (`SubscriptionOutcomes`) |
| `gamecenter.reported`, `gamecenter.sniper.sent`, `gamecenter.streak.sent` | `Services/GameCenter.swift` |
| `spotlight.signature` | `Intents/SpotlightIndex.swift` |
| `review.afterSong` | `Services/ShareDestination.swift` (`ReviewPrompt`) |
| `paywall.declines`, `paywall.exitOfferMade` | `Paywall/PaywallWinBack.swift` |
| `latency.calibrated.<speaker|wired|bluetooth>` | `Audio/AudioService.swift` (tap-along calibration per route) |
| `learn.band` | `Audio/Band.swift` (band switch) |
| `along.spokenCues`, `lesson.startOnStrum` | `Learn/PlayAlongCues.swift` |
| `song.takeMode`, `songsheet.notation` | `Learn/SongChords.swift`, `Learn/NotationEngraver.swift` |
| `display.chordPicture` (migrates `display.stringOrder`) | `Learn/PlayerNeck.swift` (`ChordPicture`) |
| `tune.strobe`, `tune.feel.chosen`, `haptics.detentGate` | `Tune/TuneView.swift`, `Tune/FeelToggle.swift`, `Services/LiveReading.swift` |
| `onboarding.questionsDeferred`, `onboarding.firstChordLesson` | `Onboarding/OnboardingDeferral.swift`, `Onboarding/FirstChordStep.swift` |
| `daily.celebrated`, `drone.firstString`, `ear.recent.exampleSeen`, `journey.badgesSeen`, `songs.instrument`, `yoursongs.textScale` | `@AppStorage` in the view that uses them |

Shared with extensions through the App Group: `widget.snapshot`, `widget.library` (iPhone), `watch.snapshot` (watch).
The watch app keeps its own `metronome.bpm` and `metronome.beats` (`TimbreWatch/WristMetronome.swift`).

**Other files:** the player's own songs live in `<storage>/YourSongs/` (`UserSongLibrary`, one JSON per chart and
`Audio/` for imported recordings), where `<storage>` is the same directory as the state file.

### 7.4 Progress: XP, quests, achievements

All rules are pure, in `ios/Sources/TimbreCore/Practice/Progression.swift`; the state is `UserSettings.progress`
(`ProgressState`: `xp`, lifetime `stats`, today's quest progress, achievements, instruments tuned, string samples,
restrung dates, streak freezes, `tunedToday`, `dailySetDay`).

- Events (`ProgressEvent`): `stringTuned`, `practiceMinutes`, `earCorrect`, `earRound`, `sniperRound`, `sniperGame`,
  `lessonCompleted`, `dailySetCompleted`. `ProgressState.record(_:…)` applies one and returns a `ProgressUpdate`
  (XP gained, level-up, quests and achievements completed, daily-set flag).
- XP (`XPReward`): string locked 5; full tune +20; practice minute 3; ear answer 2; bullseye 4; Bullseye game won 30;
  daily set 25; completed quests add their own XP. A lesson pays `lesson.xp × (0.6 + 0.2 × stars)`
  (`LessonRun.result`), so 3 stars pay 1.2×.
- Levels (`Progression.level(for:)`): level n starts at `50·n·(n−1)` XP (0, 100, 300, 600, 1000, …), ten named levels.
- Quests (`Quests.daily(for:)`): three a day, stable for the date: always "tune every string" (`tuneAll`), plus two
  from a seeded shuffle of `sniperWin`, `bullseyes`, `practiceMinutes`, `earCorrect`, `lessons`.
- Achievements (`Achievements`): 42 badges (tuning, dedication, ear, learning, course), tiered bronze/silver/gold.
  `Achievements.learnMetrics` supplies Learn-derived values.

App side: `AppStore.recordProgress(_:announce:toast:)` applies the event via `updateSettings` and `announceProgress`
gives the haptic, the reward toast (`Design/GameUI.swift`, `RewardToast`; rewards from one action merge), analytics
(`quest_done`, `level_up`, `daily_set_done`) and Game Center (`GameCenter.shared.recorded`). `syncAchievements()`
awards badges already earned (launch and foreground).

### 7.5 Streaks and Today

- `Streaks.summary` (`Practice/Streaks.swift`): a day counts when any practice record falls on it; the current
  streak survives until the end of today; frozen days keep a run without adding to it. `AppStore.streak` caches it
  with `StreakCache` (recounted when records, frozen days, the day or the time zone change).
- `StreakFreeze`: one freeze earned on every 7th day of a run, at most 2 banked (`cap`); banked freezes cover a gap
  automatically only if there are enough for all of it (`AppStore.applyStreakFreezes`, at launch and foreground).
- Milestones: `AppStore.streakMilestones = [3, 7, 30, 100]`; reached only by practice saved today; shown by lesson
  results or `StreakMilestoneOverlay` (not in Calm mode).
- Today (`DailySet.activities`): one session sized to the daily commitment (`Preferences.dailyMinutes`, 5/10/15,
  default 10): the next lesson (3–8 min) when the player can open it, a review when one is due (2–6 min), a 1-minute
  tune-up, then tool reps chosen by goal and day; Pro-only tools (`scale`, `drone`) are never picked on the free plan.
  The tool reps are pinned for the day in `UserSettings.dailyPlan` (`AppStore.pinDailyPlan`, after onboarding and
  once StoreKit has answered) so switching instrument never reshuffles a plan the player has seen. Done activities are
  in `UserSettings.dailyDone` (45 days kept). The last activity pays the daily-set bonus once a day.

### 7.6 The curriculum

**Source and build.** Lessons are Python data in `tools/curriculum/courses/*.py`; `tools/curriculum/build.py` validates
them and writes `ios/Sources/TimbreCore/Resources/curriculum.json` and `ios/Timbre/Resources/en.lproj/Learn.strings`.
Text keys are `L` + the first 10 hex digits of SHA-1 of the English. See [TOOLS.md](TOOLS.md) and
[STYLE.md](../tools/curriculum/STYLE.md).

**Loading.** `CurriculumStore.shared` decodes once (background queue at launch); `AppStore.curriculum`, Spotlight and
`BandStyleIndex` all hold the same copy. A failed decode leaves an empty curriculum, asserts in debug and logs
`curriculum_failed`.

**Model** (`Learn/Curriculum.swift`): `Curriculum.courses` → `LearnCourse.units` → `LearnUnit.lessons` → `Lesson.steps`.
`LearnCourse.lessons` (path order) and `Curriculum.lesson(id:)` are indexed once. A course is a songbook
(`isSongbook`) when it has song lessons and no teaching lessons.

| Course id | Instrument | Units | Lessons |
|---|---|---:|---:|
| guitar | guitar.acoustic.6 | 22 | 154 |
| ukulele | ukulele.soprano.4 | 10 | 61 |
| bass | bass.electric.4 | 6 | 32 |
| violin | violin.standard.4 | 6 | 39 |
| cello | cello.standard.4 | 5 | 32 |
| mandolin | mandolin.standard.8 | 6 | 34 |
| banjo | banjo.five.5 | 6 | 31 |
| ear | any | 8 | 40 |
| theory | any | 8 | 44 |
| rhythm | any | 6 | 29 |
| voice | voice | 6 | 30 |
| songs | guitar.acoustic.6 | 6 | 38 |
| originals | guitar.acoustic.6 | 10 | 60 |
| standards | guitar.acoustic.6 | 9 | 47 |
| ukulele-songbook | ukulele.soprano.4 | 25 | 110 |
| mandolin-songbook | mandolin.standard.8 | 15 | 68 |
| violin-songbook | violin.standard.4 | 15 | 66 |
| cello-songbook | cello.standard.4 | 15 | 65 |
| bass-songbook | bass.electric.4 | 25 | 120 |

Lesson kinds (`Lesson.Kind`): `lesson`, `song`, `review`, `challenge`. A song lesson may carry an `arrangement`
(`SongArrangement`) whose last step is the whole song.

**Step kinds** (`LessonStep`; JSON `type`; count in the shipped curriculum; the view `StepView` in
`Learn/LessonPlayer.swift` routes it to):

| Case | JSON | Count | View | `usesMicrophone` | What the learner does |
|---|---|---:|---|---|---|
| `explain` | `explain` | 1,452 | `ExplainStep` (`LessonExplain.swift`) | no | Reads an idea with a picture (`LessonVisual`: fretboard, chord, staff, rhythm, keyboard, instrument part, clip); chord cards can play "Show me" |
| `playNotes` | `notes` | 983 | `NotesStep` (`LessonSteps.swift`) | yes | Plays notes one after another, each held in tune, no clock (`NoteSequenceJudge`) |
| `playAlong` | `along` | 2,025 | `AlongStep` (`Highway.swift`) | yes | Plays along with the highway/runway at a tempo (`PlayAlongSession`, `TempoLadder`) |
| `playChord` | `chord` | 294 | `ChordStep` (`LessonSteps.swift`) | yes | Plays a chord and lets it ring (`ChordRing` via `PolyTuner`) |
| `strum` | `strum` | 121 | `RhythmStep(mode: .strum)` | yes | Strums a pattern (`StrumTake`, `StrokeChords`) |
| `progression` | `progression` | 543 | `RhythmStep(mode: .progression)` | yes | Strums a chord progression in time |
| `tapRhythm` | `tap` | 254 | `RhythmStep(mode: .tap)` | no (but on an instrument course the step is strummed on the open strings and listens, `hearsInstrument`) | Taps (or strums) a rhythm |
| `listen` | `listen` | 488 | `ChoiceStep` with sound | no | Hears notes and picks an answer |
| `quiz` | `quiz` | 668 | `ChoiceStep` | no | Answers a theory question |

The lesson player (`LessonPlayer`) adds a tune check (`TuneCheckStep`) before the first listening step of the day. A
song opens on its song sheet (`SongOpener`/`SongSheet`) and ends on a performance (`SongPerformStep`, or
`SongEncoreStep` for a song that ends on a progression; "Chords & words" is `SongChordsTake`). Results:
`LessonResults`.

**Scoring** (`Learn/LessonEngine.swift`): each scored step reports 0…1; `LessonRun.result` gives stars from the
average (≥ 90 % three, ≥ 70 % two, else one), capped by the final play-along's score (`starCap(finalTake:)`: three
from 90 %, two from 50 %) and by a take below the lesson tempo (`capStars`). `AppStore.finishLesson` records the result
in `LearnProgress` (best stars, best accuracy, finished dates, weak spots), adds review credits to the `ReviewDeck`,
saves a `lesson` practice record, records progress and ticks Today.

**Unlocking and access.** Two separate rules:

- Order (`LearnProgress.isUnlocked`): the first lesson of each course, the placed units and the lesson after them,
  then each lesson after a finished one. Songbook songs are all open in order terms (their challenges keep the path).
- Payment (`AccessPolicy.canPlay`, via `AppStore.canPlay`): Pro opens everything; otherwise a lesson plays if it is
  `free` (`build.py` marks every lesson of each course's unit 1 free), if the remote settings open it
  (`FreeOpenings`: `freeSongs`, `flags.unit2Free`), or if it is the placement pass (the first lesson after the placed
  units, in a course the learner was placed in). `LessonAccess` (`Learn/LearnView.swift`) turns this into a tap
  outcome: paywall, refuse (shake), or play.

**Placement** (`Learn/Placement.swift`): onboarding's "How long have you been playing?" places each course
(`CoursePlacement`, `LearnProgress.place`); players who say years can take the 45-second `PlacementCheck`
(`Onboarding/PlacementCheckView.swift`).

**Review** (`Practice/SpacedReview*.swift`, `Learn/WeakSpots.swift`, `Learn/WeakSpotReview.swift`): items scoring below
0.8 in a lesson become weak spots and join an SM-2 schedule (`ReviewDeck` in `UserSettings.spacedReview`); review
sessions play in the normal lesson player and earn XP but never change unlocks.

**Songs tab** (`Songs/SongsView.swift`): every song lesson in every course as record shelves under a song of the day
(`SongOfTheDay`). Sleeves are generated (`Songs/SongCover.swift`), no image assets.

**Coach** (`Coach/` in core, `Journey/CoachCard.swift`, `Journey/CoachVoice.swift`): notes from measured facts; under
`COACH_MODEL` on iOS 26 with Apple Intelligence, `CoachPolish` may reword a note with FoundationModels, checked to keep
every number. Disabled under automation.

## 8. The audio stack

### 8.1 The session: AudioSessionOwner

`AudioSessionOwner.shared` (`ios/Timbre/Audio/AudioService.swift`) is the only code that sets the `AVAudioSession`
category, mode and activation. Users: `.lessons` (`AudioService`: `.playAndRecord`, mode `.measurement`, options
`.defaultToSpeaker`, `.allowBluetoothA2DP`, `.mixWithOthers`, 48 kHz preferred, haptics allowed while recording) and
`.recording` (`RecordingPlayer`: `.playback` unless play-and-record is already set). Changes run on one serial queue.
Releasing waits one second (`grace`) before deactivating with `.notifyOthersOnDeactivation` and setting `.ambient`;
any activation in that second cancels it. `prepareInterfaceSound()` and `interfaceSoundIsAmbient()` let `SoundFX` play
in the ambient category between engines (mixes with other audio, honours the Ring/Silent switch).

### 8.2 AudioService

`AudioService` (`@MainActor final class AudioService: ObservableObject`) owns one `AVAudioEngine`, an input tap and an
`AVAudioSourceNode` driven by `OutputRenderer` (render thread: tone clip, metronome, drone, band; synchronised once per
buffer). Published: `running`, `error`, `permissionDenied`, `metronomeRunning`, `metronomeOwnedByTool`,
`droneRunning`, `tonePlaying`, `headphones`, `bandPlaying`, `route`.

**Capture pipeline** (`start(minimum:maximum:micSensitivity:analysisWindowOverride:confidenceThreshold:)`):

1. Asks for record permission (`AVAudioApplication.requestRecordPermission`); refusal sets `permissionDenied` and an
   error.
2. Waits briefly for the app to be active; picks the I/O buffer: 20 ms when only listening (`listeningBuffer`), 5 ms
   when timing matters (`timedBuffer`: lesson analysers set or output playing).
3. `openMicrophone` activates the session off the main thread (`activateInBackground`), installs a 512-frame tap on
   the input node, attaches output, starts the engine. A failure that a moment may fix is retried once after 300 ms
   (`MicStartRetry.shouldRetry`; lasting failures: no input, `!pri`, `siri`, `!rec`, `!cat`, `ent?`, `-50`). A
   superseded start never tears down a newer one (`generation` token).
4. Each tap buffer is copied to the serial `com.timbre.pitch` analysis queue. There the capture's `PitchWorker` (a ring
   buffer feeding `YinPitchDetector` one reading per `rate/60` samples, about 60 a second; at most 6 buffers queued)
   consumes it, and the raw frames go to `frames` (`FrameSink`: the lesson analysers and Strum to tune). While the app's
   own voice is speaking (`SpeechGate.shared.isQuiet`) the frames are not sent and the worker's readings are dropped
   (the detector keeps following the sound so it can pick up after).
5. Readings go through `ReadingRelay` (keeps order, one main-actor hop at a time, at most 16 queued) and reach
   `onReading` (wired to `AppStore.accept`). While a tone plays, readings arrive silent.

**Output:** `playTone` (the tuner's reference: re-plucked or held without vibrato at exactly the target), `playTones`
("Hear it", chord buttons, listen steps), `setMetronome(…, tool:)` (only the Metronome tool keeps phase across
changes; any other caller starts a fresh count), `setDrone`, the band (`prepareBand`, `playBand`, `finishBand`,
`stopBand`). Tones render on the `com.timbre.tones` queue from `SampledTones` (recordings, decoded ahead with
`warmSamples`) or `ToneSynth`, and recent renderings are cached by `ToneRequest`; the band renders on
`com.timbre.band`. Lesson clocks read `metronomeOrigin()` (when the first click reached the ears: its render time plus
this route's tap-along calibration, else the session's output latency) and `metronomeRenderOrigin()` (when it left the
engine); calibrations are saved per `OutputRoute` (speaker, wired, bluetooth) with `saveCalibration(_:for:)`;
`heardStart(near:)` nudges a step's clock toward the audio clock.

**Resilience:** route and configuration changes share one rebuild; the microphone restarts only if its input changed;
interruptions (calls, Siri, alarms) snapshot what was going and bring back the microphone, the tool's click and the
drone on "should resume" (`SessionInterruption`; an "app was suspended" notification is ignored); media-services resets
rebuild. The demo pitch (`startDemo`, debug only) stands in for the microphone.

**Band** (`Audio/Band.swift` with `TimbreCore/Audio/BandGroove.swift`):

- `BandArrangement`: bars with harmony segments (root, chord tones, changes inside a bar), fills, endings, and cues;
  equal arrangements share a rendering.
- Style: `BandStyleIndex` maps every song lesson's cues (melody openings, chord stretches) to a `BandStyle` (Originals
  get their genre; everything else the standard groove), built from `CurriculumStore.shared.curriculum`.
- `BandSynth` renders each distinct bar offline (off the main thread, `com.timbre.band` queue) into a `BandTrack` in
  three layers (kit; bass and toms; comping), using recorded drums, bass, piano, electric guitar and chops when bundled.
- `BandPlayer` (render thread) is started bar by bar by the metronome's downbeats, so the band is sample-locked to the
  click. `BandFeel` carries the take's state: thin to drums and bass on a miss, full again after four in a row, step
  back under spoken cues, and **kit only on the speaker while the microphone listens** (bass and chords would be heard
  as notes); the full band plays in headphones.

**Interface sounds** (`Audio/SoundFX.swift`): synthesized once (`SoundSynth`, `RoomReverb`), played with
`AVAudioPlayer`: lock bell at the string's pitch, full-tune strum of the open strings, stars on the key's triad, count-in
click, the three-note motif. `SoundCue` lists them.

**Spoken cues** (`Audio/CueVoice.swift`, `Learn/PlayAlongCues.swift`): with VoiceOver (or by choice), `CueVoice` names
each note ahead of it with the app's own `AVSpeechSynthesizer`; `CuePlan` (core) decides when and whether brief so no
cue runs into its note; `SpeechGate` sets the microphone aside while it speaks. `Earcons` adds tick/thud and swishes;
`TakeFeedback` coordinates haptics and the band's reaction.

**Recordings of the player's own songs** (`YourSongs/RecordingPlayer.swift`): `AVAudioEngine` with
`AVAudioUnitTimePitch` (slow down without pitch change, transpose), A–B loop; session through
`AudioSessionOwner(.recording)`. `RecordingReader` runs `RecordingAnalyzer` over a file off the main thread.

## 9. Listening and judging

What is judged, by which core type, fed how:

| What | Core type (TimbreCore) | App side | Fed by |
|---|---|---|---|
| Tuner string | `TuningTracker` (band, 650 ms hold) | `AppStore.accept`, `LockLatch` (`Tune/LockLatch.swift`) keeps the shown lock | YIN readings |
| Strum to tune | `PolyTuner` | `StrumListener`/`StrumModel` (`Tune/StrumModel.swift`), `AppStore.completeStrumTune` | raw frames (`AudioService.frames`) |
| Notes one by one | `NoteSequenceJudge` | `NotesStep` | readings via `AppStore.startLessonListening` |
| Play-along | `PlayAlongJudge` (windows: early 0.20 s, late 0.32 s; perfect ≤ 0.07 s, good ≤ 0.15 s), `PlayAlongSession`, `TempoLadder` (75/90/100/110 %) | `AlongStep`, `HighwayRunway`, `HighwayCanvas`, `SongPerformStep` | readings, clock from `metronomeOrigin` |
| Chord rings | `ChordRing` via `PolyTuner` on the chord's pitches | `ChordStep` | `LessonAnalyzer` strums |
| Running chord | `ChordRecognizer` | `LessonAnalyzer.onChord` | raw frames |
| Strums and rhythms | `StrumTake` (perfect ≤ 50 ms, good ≤ 100, OK ≤ 180), `StrokeChords`, `OnsetDetector`, `RhythmJudge` | `RhythmStep`, `LessonBeatRow` | `LessonAnalyzer` onsets and strokes |
| Chords & words | `ChordAlongJudge` | `SongChordsTake` | strokes |
| Voice | `VoiceAttempt` | `AppStore.startVoice` / `VoiceView` | readings |
| Ear / Bullseye | `EarSession`, `PitchSniper` | `EarTrainingView`, `PitchSniperView` | answers / readings |
| Your songs draft | `RecordingAnalyzer`, `TempoEstimator`, `BeatTracker`, `DraftChart` | `RecordingDraftSheet` | file via `RecordingReader` |

`LessonAnalyzer` (`Learn/LessonAnalyzer.swift`) wraps `LessonListening` on the analysis queue and moves each event to the
host clock (`CACurrentMediaTime`) and the main actor. `LessonListening` is in core so tests and the real-world corpus
feed recordings through exactly the live path (`AudioClip.tapFrames`).

Microphone ownership for lessons: `AppStore.startLessonListening(owner:lowHz:highHz:analyzer:listener:)` sets
`lessonListener` (raw readings bypass the tuner) and `audio.frames`; `stopLessonListening(owner:)` only stops if that
owner still holds it, so a step leaving never stops the next one. Without the microphone, rhythm steps fall back to
tapping (`LessonMicrophone`, at most one star).

## 10. The 3D stage

- **Renderer:** RealityKit (`RealityView`) in `Stage/InstrumentStage.swift`. `StageController` drives camera framing
  (whole instrument vs. headstock close-up), peg rotation following measured cents (`degPerCent` from the rig), a
  vibrating string whose standing wave drifts with the error and freezes in tune, lock shimmer, and string glow
  (`Stage/StageShared.swift`, `StringGlow`). Lighting is a generated environment map (`StageLighting`). A left-handed
  player's stage is mirrored by its host (`flipX`).
- **Models:** `ios/Timbre/Resources/Models/<id>.usdz` with `<id>.rig.json` (`InstrumentRig`: per string `anchor`,
  `saddle`, `nut`, `peg`, `post`, `pegCenter`, `pegAxis`, `tighten`, optional `motion` rotate/slide; `degPerCent`;
  bounds; `card2D` points on the studio render; `credit`). `models-manifest.json` maps photo assets to model ids
  (`ModelLibrary.modelID(forPhoto:)`). Seven models: `guitar_acoustic`, `guitar_classical`, `guitar_electric`,
  `bass_p4`, `mandolin` (rig `MACHINE_HEAD`), `violin`, `cello` (rig `FRICTION_PEG`). All are Sketchfab artist models
  under CC BY (see `credit` in each rig and Settings › Acknowledgements, `ModelLibrary.credits()`).
- **Loading:** `Stage/ModelCache.swift` loads each usdz once, keeps the most recent, hands each stage its own instance
  (`instance(of:)`), and drops everything on memory warning or background. A load superseded by a newer instrument
  never lands (`StageController` compares a generation counter after each await).
- **2D fallback:** `Stage/StudioStage.swift` draws the live string and peg ring over the studio render
  (`render_<id>` in the asset catalog) or over a photograph using `photo-rigs.json` points and `photo-turns.json` turn
  signs (`ModelLibrary.photoCard`). Used when Metal is missing, when Settings picks the studio stage
  (`UserSettings.stageMode == "studio"`), for instruments without a model, and while a model loads.
- **Power:** `StagePower.shared.reduced` is true in Low Power Mode, at serious/critical thermal state, or with
  `TIMBRE_STAGE_REST`; the 3D stages then rest on their pictures. At rest the 3D stage hands over to its picture after
  `StageRest.idle` (12 s).
- **Peg cue:** `Stage/PegCue.swift` (`PegTurn`, `StagePegCue`, `PegLabel`) projects the ring and turn arrow onto the
  peg being tuned.
- **"Show me"** (`Learn/ShowMe.swift`, `Learn/ShowMeScene.swift`): the same models in lesson cards: fingertips land in
  finger order, strings shimmer, a 3D pick strums patterns (`ShowMeController`, `ShowMeNeck`, `ShowMeShape`). Plays by
  itself the first time a chord or pattern appears in a course (`UserSettings.shownDemos`, `ShowMeKey`).

## 11. Commerce, remote settings, analytics, Game Center

### 11.1 Commerce

`CommerceService` (`Services/CommerceService.swift`, StoreKit 2):

- Products (`TimbreProduct.all`): `timbre_pro_annual`, `timbre_pro_monthly`, `timbre_plus_lifetime`, and the price-test
  yearly arms `timbre_pro_annual_b`, `timbre_pro_annual_c`. Subscriptions are in the group "Timbre Pro".
- `isPro` comes only from verified, unrevoked transactions in `Transaction.currentEntitlements` (`AccessPolicy.isPro`);
  no expiry date is checked (StoreKit already drops lapsed subscriptions and keeps grace-period ones).
  `entitlementResolved` turns true after the first refresh; widgets and Today wait for it.
- Refreshes on launch, on every `Transaction.updates` item (which it finishes), on foreground, and just after the
  active subscription's expiry.
- `billingIssue` (`BillingIssue.gracePeriod` / `.billingRetry`) drives `BillingIssueBanner` over every tab.
- `annual` sells the yearly product named by this install's paywall arm (`RemoteConfig.annualProductID`) when it is a
  known yearly id and on sale, else the standard year. `trialDays(for:)` / `trialLabel(for:)` read the introductory
  offer.
- `SubscriptionOutcomes` logs `subscription_state`, `renewal` and `refund` events.

What is free (`AccessPolicy`, `FreeTier`, `YourSongsPolicy`), and the paywall's Free/Pro table is built from the same
rules (`PlanComparison`):

| Area | Free | Pro |
|---|---|---|
| Tuner | Every instrument in its standard tuning; every preset and custom tuning of the free instruments (guitar.acoustic.6, bass.electric.4, ukulele.soprano.4, violin.standard.4, cello.standard.4: catalogue `isFree`); one custom tuning in all | Every tuning, unlimited custom tunings |
| Lessons | Unit 1 of every course; remote openings; the placement pass | All |
| Tools | Chords (open-position shapes, Check), metronome (quarters, eighths, triplets; click and wood), Bullseye, ear "higher or lower", capo, transpose | Drone, scales, intonation, strobe precision, temperaments, interval and chord naming by ear, sixteenths, beep, accents, speed trainer, barre shapes |
| Voice | Level 7 (range) | All levels (`AppStore.startVoice`) |
| Your songs | 10 charts; play along and tap-sync with own recording; Apple Music listening | Unlimited charts; slow down and loop; chord detection from a recording |

`AppStore.presentPaywall(_:lesson:instrument:)` opens the paywall with a reason string; `RootView` draws it as an
overlay (Settings and the instrument picker host their own, `PaywallHost`). The paywall logs its own `paywall_view`.

### 11.2 Remote settings

`RemoteConfig.shared` (`Services/RemoteConfig.swift`) is started by `Analytics.start()` (so it starts only once the
player's sharing choice is known) and then fetches a small JSON file from `AppLinks.remoteConfig` whenever the app
becomes active and the last copy is more than 6 hours old, with an ephemeral session and no identifier; 64 KB cap. The last good copy is
cached; nothing waits for it; automation never fetches (`TestSupport.isAutomated`). Fields: `paywall` (weighted arms,
each may set `annualProductId`, `onboardingLifetime`, `headline`), `rating.show`, `referralCode`, `freeSongs`, `flags`
(e.g. `unit2Free`). An install's arm is drawn once from a random number fixed per install. Loading sets
`FreeOpenings.current`. The owner-facing description is [APPLE-DELIVERY.md §5](ios/APPLE-DELIVERY.md).

### 11.3 Analytics

`Analytics.log(_:_:)` (`Services/Analytics.swift`) writes every event to the unified log
(subsystem `com.shahradazerisharghi.timbre`, category `events`) and, when the build has a TelemetryDeck app id and the
player has not switched sharing off, queues it for TelemetryDeck's ingest API v2 (`https://nom.telemetrydeck.com/v2/`):
batched every 30 s, at 20 queued, and on backgrounding; failed posts are dropped. The user id is SHA-256 of a random
per-install UUID. Opt-out: Settings › Share anonymous usage data (`UserSettings.shareUsageData`, nil means on) →
`Analytics.setSharing(false)` drops the queue. `Analytics.start()` also starts app-open/session tracking
(`AnalyticsLifecycle`), MetricKit summaries (`metrics_daily`, `diagnostics`), and the one-time Apple Ads attribution
(`AppleAdsAttribution`). The funnel's event names are listed in the `Analytics` doc comment. Automated runs send
nothing. Keep [PRIVACY.md](ios/PRIVACY.md) and the privacy manifest in step with any change here.

### 11.4 Game Center

`GameCenter.shared` (`Services/GameCenter.swift`) authenticates, reports Pitch Sniper scores (all-time and weekly
boards), the ear level, the streak, per-song Perform boards and badges, handles iOS 26 challenges and activities
(`GameCenterListener`), and reads friends' streaks (`FriendStreak`, counts only). Every identifier is in
`Services/GameCenterIDs.swift` and must exist in App Store Connect ([APPLE-DELIVERY.md §6.1](ios/APPLE-DELIVERY.md)).
Without Game Center everything stays hidden and nothing fails. Disabled under automation. UI pieces:
`Services/GameCenterSocial.swift`.

## 12. System surfaces

### 12.1 Deep links

`DeepLink` (`Intents/DeepLink.swift`) is the one router for `timbre://` URLs from widgets, Siri, Shortcuts, Spotlight, the
Action button, share links and the watch: `tune[?instrument=<id>]`, `metronome[?bpm=&start=1]`,
`drone[?key=0…11&start=1]`, `lesson[?id=<id>]`, `challenge?game=sniper&score=<n>`, `practice`, `ear`, `learn`, `songs`.
`RootView.onOpenURL` first offers the URL to `YourSongsStore.receive` (an imported chord chart), then to `DeepLink.open`.
Access rules still apply (a Pro instrument opens the paywall). Links wait for full-screen covers to close. During
onboarding a `tune?instrument=` link pre-selects the instrument (`OnboardingLink`).

### 12.2 App Intents and App Shortcuts

`Intents/SharedIntents.swift` (compiled into the widget extension too): `IntentRouter` (`pending` destination or a
`link`) and the plain intents `OpenTunerIntent`, `OpenMetronomeIntent`, `EarTrainingIntent`, `DailyPracticeIntent`.
`Intents/PracticeIntents.swift`: `TuneInstrumentIntent`, `StartMetronomeIntent`, `StartDroneIntent`,
`ContinueLessonIntent`, `LessonCommandIntent` (`LessonCommand`, delivered to the open lesson through `LessonRemote`),
`PracticeStreakIntent` (answers without opening the app, `StreakSnippet`). `Intents/InstrumentEntity.swift` exposes
catalogue instruments. `Intents/TimbreShortcuts.swift` declares ten App Shortcuts; phrases are translated in
`<locale>.lproj/AppShortcuts.strings`.

### 12.3 Spotlight

`SpotlightIndex` (`Intents/SpotlightIndex.swift`) indexes instruments, lessons and songs (`LessonEntity`,
`OpenLessonIntent`, `OpenInstrumentIntent`) in the background, only when the build, catalogue, curriculum or device
language changed (`spotlight.signature`). Skipped under automation.

### 12.4 Widgets and the widget library

`AppStore.publishWidgets()` (after every save and on Pro changes) writes `WidgetSnapshot` (streak, best, practiced
today, last 7 days, instrument name, next lesson) to the App Group and reloads timelines only when something visible
changed; it also publishes the `WidgetLibrary` (Quick tune's instruments and Next song's shelves,
`Intents/WidgetLibraryPublisher.swift`) once entitlements are known, sends the watch snapshot (`WatchBridge`), and
re-plans reminders (`PracticeReminder.update`).

### 12.5 Live Activity

`LiveActivityController` (`Services/LiveActivityController.swift`) shows one `PracticeActivityAttributes` activity while
the Metronome or Drone tool plays, the player tunes or sings, or a lesson is open (tuning and lessons after a 10 s
dwell). Local updates only, at most one a second; it ends when the last source stops (after a 3 s grace in the
foreground, so a reference tone pausing the microphone doesn't end it); after a real practice the final frame stays on
the Lock Screen for two minutes. Never under automation. The UI is `ios/TimbreWidgets/PracticeLiveActivity.swift`.

### 12.6 Apple Watch bridge

`WatchBridge` (`Services/WatchBridge.swift`, WatchConnectivity) sends `WatchSnapshot` (streak, Today, open quest, next
lesson, metronome tempo; strings already localized) as application context, plus a complication transfer when a Timbre
complication is on the face. "Start today's practice" arrives as a message: with Timbre in front it opens Today
(`timbre://practice`); otherwise the watch offers Handoff (`com.shahradazerisharghi.timbre.today`, continued in
`TimbreApp`) and opening Timbre within ten minutes lands on Today. `WatchDay` carries a snapshot past midnight without
the phone.

### 12.7 Notifications

`PracticeReminder` (`Services/PracticeReminder.swift`) plans the next 14 days as single local notifications
(`timbre.practice.daily`; none on a day already practised; each names the next lesson and the streak) plus a weekly
summary (`timbre.practice.week`), re-planned whenever practice is saved. `TrialReminder` schedules one notification
two days before a free trial renews (`timbre.trial.reminder`).

### 12.8 Your songs and Apple Music

`YourSongsStore.shared` (`YourSongs/YourSongsStore.swift`) keeps the player's charts (ChordPro text) and recordings on
the device only. Charts come from Files, paste, the editor, a recording's detected chords, or "Open in Timbre"
(`CFBundleDocumentTypes`). `AppleMusicListener` (`YourSongs/AppleMusicListen.swift`) is a plain "Listen on Apple Music"
player (`ApplicationMusicPlayer`): free for everyone, never looped, slowed, synced or analysed, per Apple's MusicKit
terms (`YourSongsPolicy`). Owner setup: [APPLE-DELIVERY.md §8](ios/APPLE-DELIVERY.md).

### 12.9 Localization at run time

- The setting is `UserSettings.language` (`"system"` or a code such as `"de"`, `"zh-CN"`). `AppStore` sets
  `TimbreLocalization.language` at launch and on every settings change; that resolves one `Bundle` (the `.lproj` of the
  picked language, or `Bundle.main` for "system") that every lookup uses: `LocalizedText.localized` (catalogue),
  `LearnText.localized` (lessons, table `Learn`), and the app's `String(localized:)` and `NSLocalizedString`, which
  `Services/Localization.swift` overrides module-wide to use `TimbreLocalization.bundle`. New code should name the
  bundle explicitly: `String(localized: "…", bundle: .app)` (`Bundle.app`).
- `RootView` sets the SwiftUI environment's `locale` (`TimbreLocalization.locale(for:)`) and `layoutDirection`
  (`TimbreLocalization.isRightToLeft`), so a picked language applies without relaunch. Pictures of music keep a
  left-to-right layout (`.environment(\.layoutDirection, .leftToRight)`): the 3D and 2D stages, the string rail, the
  readout, the play-along highway, song sheets and timing strips, among others; words around them still follow the
  language.
- Note names follow `NoteNames.active` (set from `UserSettings.notation`; defaults from the language until the player
  picks, `applyNotationDefault`: German letters for German).
- String tables: `<locale>.lproj/Localizable.strings` and `.stringsdict` (interface), `Learn.strings` (lessons, in nine
  lesson languages), `AppShortcuts.strings`, `InfoPlist.strings`. The pipeline is in [l10n/HANDOFF.md](l10n/HANDOFF.md)
  and [TOOLS.md](TOOLS.md).

## 13. Design system

All in `ios/Timbre/Design/` ("Studio Noir": dark by design; `RootView` forces `.preferredColorScheme(.dark)`).
`Design/Theme.swift` is also compiled into the widget extension; the watch has its own `TimbreWatch/Shared/WatchTheme.swift`.

### 13.1 Palette (`Palette`, `Theme.swift`)

The colour rule, enforced in review and by `tools/ci/comment_hygiene.py` (`status-colour`):

| Role | Tokens | Meaning |
|---|---|---|
| Stage | `stage` #060708, `stageRaised`, `stageDeep`, `surface` | Backgrounds |
| Lines | `line`, `controlLine`, `hairline` | Dividers, control outlines (≥ 3:1), card borders; brighter with Increase Contrast |
| Ink | `ink`, `inkSoft`, `inkFaint` | Text; soft and faint follow Increase Contrast |
| Status (exclusive) | `mint` (in tune, correct, go; every primary button), `amber`/`adjust`, `coral`/`danger` | Never used for anything else; ask by role (`adjust`, `danger`, `flat`, `sharp`, `pitch(_:locked:band:)`) |
| Pitch colour | `Palette.pitch(cents, locked:, band:)` | Mint inside the lock band (`Palette.tuningBand`, declared in `Tune/Readout.swift` and set by `AppStore` from Precision), amber to 20 ¢ (`nearCents`), coral beyond |
| Course hues | `accent(_:)` → `mint`, `sky`, `violet`, `orchid`, `lime` | Only what a course owns. Curriculum names `amber`/`coral` are remapped to `orchid`/`lime` |
| Neutral category | `accentNeutral` | Activities, tools, difficulties no course owns |
| Rewards | `starGold`, `starFill`, `proGold`, `proGoldDeep`, `flame`, `flameInk`, `frost`, `spotlight` | Stars, Pro, streak lamp, freezes, stage light |
| On colour | `onAccent`, `onGold` | Dark ink on mint/accents and on gold |

Deprecated names `brass`, `brassDeep`, `ember` map to mint/amber; rename them when you touch a file.

### 13.2 Type (`TypeStep`, `Typeface`)

Sora (Light, Medium, SemiBold, Bold; `Resources/Fonts`, OFL) for headings, note names, numbers and buttons; the system
font for body text. Eight steps, each on a Dynamic Type curve: caption 12, footnote 13, body 15, headline 17, title3 20,
title 28, display 40, hero 64; above 64 only hero numerals (`Typeface.hero` with `.heroNumeral()`). Roles:
`screenTitle`, `stepTitle`, `sectionTitle`, `cardTitle`, `button`, `badge`, `eyebrow`, `eyebrowDisplay`. With Bold Text
every face is one weight heavier (`Typeface.boldText`, kept in step by `.boldTextAware()` at each window root). A literal
size off the scale is reported by the `type-scale` hygiene rule.

### 13.3 Motion (`Motion`) and Metrics (`Metrics`)

Motion tokens: `pluck`, `settle`, `quick`, `toastIn`, `toastOut`, `page`, `pop`, `reward`, `hero`, `fade`, `reveal`,
`reduced`. Under Reduce Motion movement becomes `Motion.reduced` and slide/scale transitions become opacity
(`Motion.adaptive`, `withMotion`, `.adaptiveAnimation`, `AnyTransition.adaptive` in `Kit.swift`); decorative loops stop.

Metrics: `gutter` 20, `proseInset` 8, corners `cornerHero` 28 / `corner` 22 / `cornerTile` 16 / `cornerChip` 12,
`cardPadding` 18, `tilePadding` 12, `minTarget` 44, `buttonHeight` 54.

### 13.4 Haptics

`Haptics.shared` (`Design/Haptics.swift`, Core Haptics with `playsHapticsOnly`): `detent(cents:)` per cent near the
target, `lock()`, `done()`, `selection()`, `beat(accent:)` (the metronome's Feel the beat, play-along count-ins and
perfect notes, tap-along sync), and `feel(_:)` for Tune by feel (the phone
pulses at the beat frequency between string and target, still at the lock; `byFeel`). `enabled` follows Settings.
No iPad has haptics (`hardwareSupported`).

### 13.5 Components

| File | Components |
|---|---|
| `Components.swift` | `StageBackground`, `Eyebrow`, `ScreenTitle`, `PrimaryButtonStyle` (the one mint action), `SecondaryButtonStyle`, `ChipButtonStyle`, `PressScaleStyle`, `ProBadge`, `FeatureRow`, `.stillCard(…)`, `.glassCapsule()`; `IconOrb` is retired (draws a bare glyph) |
| `Kit.swift` | `TabHeader`, `HeaderControls` (streak chip and level ring; hidden in Calm mode), `SectionHeader`, `CardTitle`, `IconButton`, `CloseButton`, `BackButton`, `SegmentedPill`, `StatTile`/`StatTileRow`/`StatBar`, `Badge`, `EmptyState`, `StageSpinner`, `Hairline`, `TextLinkStyle`, modifiers `.heroNumeral()`, `.tapTarget()`, `.boldTextAware()`, `.cappedControl(_:symbol:cap:)`, `.liveGlow(_:)`, `.animatesWhileSeen(_:)` |
| `Glass.swift` | Liquid Glass on iOS 26 with fallbacks: `TimbreGlassGroup`, `.timbreGlass(…)`, `.timbreGlassID(…)`, `TimbreGlassPlate`, `GlassActionButtonStyle` |
| `GameUI.swift` | `StreakChip`, `LevelRing`, `LevelMark`, `LevelArc`, `ProgressLine`, `QuestRow`, `AchievementGlyph`, `AchievementMedal`, `RewardBanner`, `RewardToast` |
| `Glyphs.swift` | `TimbreGlyph` (custom glyphs), `Glyph` (bare glyph in a square box), `DrawnGlyph` |
| `EdgeFade.swift` | `.edgeFade(…)` for horizontal rails |
| `Brand.swift` | `TimbreMark`, `TimbreLogotype` |
| `RewardStar.swift`, `SparkBurst.swift` | The reward star and burst |
| `Shaders.swift` + `Shaders.metal` | `timbreLockShimmer`, `timbreStrobeRipple`, `timbreStrobeLamp`, `timbreHeatStar`; run only when `ShaderFX.allowed` (not with Reduce Motion, Low Power Mode or a resting stage). The Metal toolchain must be installed (`tools/ci/ensure-metal.sh`) |

### 13.6 Modes that change the whole app

- **Calm mode** (`UserSettings.calmMode`, Settings › Display): no XP pills, level ring, streak chip, quests or reward
  toasts; Progress shows time played instead of the streak; streak milestones are dropped silently. Checked in
  `Kit.swift`, `GameUI.swift`, `RootView`, Learn, Practice, Journey and results views.
- **Simple tuner** (`UserSettings.simpleTuner`): the tuner alone, no quest line or XP.
- **Left-handed** (`UserSettings.handedness`: `right`, `left` mirrored instrument, `leftUpsideDown` right-handed
  instrument played left as strung) with `chartsAsPrinted`: read through `HandStyle` / `@CurrentHand`
  (`Learn/Diagrams.swift`); `CanvasMirror` mirrors shapes but never words; the 3D stage flips; the string rail and
  necks follow; every string keeps its number.
- **Chord picture** (`ChordPicture`: chart vs. player's view, `display.chordPicture`) decides string order on every
  neck and chord.
- **Low Power and resting stage**: `StagePower` (3D stages rest), `.animatesWhileSeen` (decoration pauses off screen,
  in background, in Low Power Mode), `ShaderFX.allowed`. `TIMBRE_STAGE_REST` simulates all of it for tests.
- **Increase Contrast, Bold Text, Dynamic Type, Differentiate Without Colour, Button Shapes, VoiceOver**: handled in the
  tokens and components above; pitch also reads as ▲ ▼ ✓ (`PitchMark`).

## 14. Test hooks

All automation hooks compile only in debug builds (`#if DEBUG` or `TestSupport` returning nil in release). A release
build reads no launch environment.

### 14.1 TestSupport launch keys

`TestSupport.Key` in `ios/Timbre/Support/TestSupport.swift`; read with `TestSupport.value(_:)` and `isOn(_:)`.

| Key | Value | Effect | Read in |
|---|---|---|---|
| `TIMBRE_TEST_STORAGE_ID` | a UUID | Saved state (and Your songs) in `Application Support/TimbreUITests/<uuid>` (`TestSupport.storageRoot`) | `Bootstrap`, `YourSongsStore` |
| `TIMBRE_DEMO_PITCH` | `1` | A demo pitch replaces the microphone: a plucked string drifting from 14 ¢ flat into tune every 6 s, or the lesson's target on time (`AudioService.startDemo`) | `AppStore.startListening`, `startLessonListening` |
| `TIMBRE_DEMO_DATA` | `1` | Seeds `DemoData` on an empty store | `Bootstrap.open` |
| `TIMBRE_SKIP_ONBOARDING` | `1` | Marks onboarding done, goal `practice` | `Bootstrap.open` |
| `TIMBRE_STAGE_MODE` | `studio` | Tuner opens on the 2D studio stage | `Bootstrap.open` |
| `TIMBRE_DEBUG_STATE` | `1` | Draws invisible probe labels for XCUITest ([§14.4](#144-debug-probes)) | `RootView`, `TuneView`, `InstrumentStage`, `DemoScenes` |
| `TIMBRE_STAGE_DEBUG` | `1` | Prints the 3D stage's load state over it (`stage.debug`) | `InstrumentStage` |
| `TIMBRE_STAGE_REST` | `1` | Everything that moves rests as in Low Power Mode (`TestSupport.stageResting`) | `StagePower`, `Kit.swift` `WhileSeen`, `ShaderFX` |
| `TIMBRE_SCENE` | scene name | Starts a capture scene ([§14.2](#142-capture-scenes)) | `DemoScene.current` |
| `TIMBRE_SCENE_INSTRUMENT` | catalogue id | The tuner opens on that instrument | `DemoScene.Option.instrument` |
| `TIMBRE_SCENE_SONG` | lesson id | `song-perform`'s song (default Kite Weather) | `DemoScene.Option.song` |
| `TIMBRE_SCENE_BAR` | integer | `song-perform`'s starting bar | `DemoScene.Option.bar` |
| `TIMBRE_SCENE_COMET` | `1` | `tune-locked` re-plucks the held string so its shimmer runs again | `DemoScene.Option.comet` |
| `TIMBRE_SCENE_CUE` | file path | `preview-tune` waits until this file exists | `DemoScene.Option.cue` |
| `TIMBRE_PREVIEW_AUDIO` | folder (or `1`) | Writes what the app plays for the App Preview soundtrack (`PreviewRecorder`) | `DemoScenes.swift` |
| `TIMBRE_PREVIEW_MOTIF` | file path | Plays the motif once the file appears (end card) | `DemoScene.playMotifWhenAsked` |
| `TIMBRE_DEMO_CLIP` | file path or bundle name | A recording played into `frames` while the demo pitch runs (`AudioService.demoClip`) | `AudioService` |

`TestSupport.isAutomated` is true when XCTest is present or any of `TIMBRE_TEST_STORAGE_ID`, `TIMBRE_DEMO_PITCH`,
`TIMBRE_DEMO_DATA`, `TIMBRE_SCENE` is set. Under automation these stay off: remote settings fetch, Game Center,
Live Activities, TipKit tips, the paywall exit offer, analytics sending, Spotlight indexing, the store-rating lookup,
the review prompt, the on-device coach model.

Test-runner-only variables (set as `TEST_RUNNER_<NAME>` on `xcodebuild`; read by the test process, not the app):
`TIMBRE_MATRIX` (accessibility matrix variant), `TIMBRE_UI_LANGUAGE` and `TIMBRE_UI_LOCALE` (the UI tour's language),
`PREVIEW_HANDSHAKE` (App Preview recorder folder). `TIMBRE_CAPTION_FONT` is read by `tools/marketing/art.py`.

### 14.2 Capture scenes

`DemoScene` in `ios/Timbre/Root/DemoScenes.swift`. Each scene drives the real code paths (the tracker really locks,
the judge really hears), started by `DemoScene.start(store)` from `Bootstrap.open`. Use with `TIMBRE_DEMO_PITCH=1`.

| Scene | What happens | Used by |
|---|---|---|
| `tune-locked` | The two lowest strings lock, then the third locks and holds (In tune badge, peg ticked) | `TimbreUITests.test11StoreTunerLock`, `test16StoreViolinStage`, `test20StoreCelloStage`, `test21StoreUkuleleStage` |
| `preview-tune` | Waits for the cue file, then the lowest string drifts in from 14 ¢ flat and locks with its bell; the rest lock in turn; the full-tune celebration. Every lock is logged for the preview's cut | `AppPreviewUITests` |
| `show-me` | Opens the first guitar chord lesson on the step that explains E minor; the 3D demonstration plays | `test15StoreShowMe`, App Preview |
| `lesson-chord` | Opens that lesson on its chord step; the demo pitch plays every string; the step holds on "Every string rings" (`DemoScene.holds`) | `test12StoreChord` |
| `lesson-dead-string` | Same chord step; one fixed strum leaves one string silent (`strumWithSilentString`) so the step names it | No UI test launches it today (manual runs) |
| `song-perform` | Opens a song (default Kite Weather) on its performance and starts the take at a bar with the earlier notes already judged clean | `test14StoreSongPerform`, `test18StoreViolinSong`, `test19StoreViolinResults`, App Preview |
| `instrument-wall` | Opens the instrument browser after 1.5 s | `test17StoreInstrumentWall` |

`DemoScene.marketingScale` (3 in a scene, else 1) exaggerates string motion for the camera (`StageInput.captureScale`).

### 14.3 Demo data

`DemoData.seed` in `ios/Timbre/Support/DemoData.swift`, on an empty store with `TIMBRE_DEMO_DATA=1`: tuning records
on 20 days within the last 35 (a 7-day streak including today, dated at 5 PM and never in the future), ear practice on
the even-numbered of those days, three finished guitar lessons (3/2/3 stars), level 5 (1,240 XP), stats and six badges,
a G string drifting flat (string health), today's tune-up done and today's tool plan pinned to ear training, and
today's streak freeze marked as already awarded, so every capture shows the same state whatever the hour.

### 14.4 Debug probes

With `TIMBRE_DEBUG_STATE=1`, views draw labels in clear ink with accessibility identifiers that UI tests read:

| Identifier | Where | Content |
|---|---|---|
| `debug.state` | `Root/RootView.swift` | `paywall=… settings=… picker=… reason=… pro=… tab=… reward=<epoch s>` |
| `stage.state` | `Tune/TuneView.swift` | `stage=<3d|loading|2d> listening=<epoch s> lock=<0|1>` |
| `stage.head` | `Stage/InstrumentStage.swift` | `framing=<0…1> head=<points>` |
| `stage.debug` | `Stage/InstrumentStage.swift` (`TIMBRE_STAGE_DEBUG`) | Load status text (visible) |
| `showme.state` | `ShowMeProbe` in `DemoScenes.swift` | `showme=<3d|picture|loading> landed=… ringing=… live=… frames=… now=… diag=…` |
| `showme.host` | `ShowMeHostProbe` | `card showMe=… ready=… threeD=… failed=… first=… model=… problem=…` |

## 15. Resources

| Resource | Location | Produced by | Verified by |
|---|---|---|---|
| Instrument catalogue (60 instruments, 8 families, 132 tunings, chromatic reference mode) | `ios/Sources/TimbreCore/Resources/catalog.json` | Originally `tools/import-ios-resources.py` from the Android project; edited by hand since | `tools/verify-ios-resources.py` (exact counts), `CatalogTests` |
| Photo index (73 entries) | `ios/Sources/TimbreCore/Resources/photos.json` | Import script; renders added by `tools/models/install_artist_models.py` and `cards.py install --photos` | `verify-ios-resources.py`, `PhotoSelectionTests` |
| Curriculum | `ios/Sources/TimbreCore/Resources/curriculum.json`, `ios/Timbre/Resources/en.lproj/Learn.strings` | `tools/curriculum/build.py` | `build.py --check`; `LearnTests`, `CurriculumIndexTests`, `SongArrangementTests`, `SongbookEditionTests`, `PlacementTests` |
| Photographs and thumbnails (146 imagesets) | `ios/Timbre/Resources/Assets.xcassets/<asset>.imageset` | Import script (WebP → PNG) | `verify-ios-resources.py` |
| Studio renders (7) | `Assets.xcassets/render_<model>.imageset` | `tools/models/render_cards.swift` (cards workflow) + `cards.py install`, or `install_artist_models.py` | `verify-ios-resources.py` |
| App icon (`icon.png`, `icon-dark.png`, `icon-tinted.png`), `LaunchBackground` colour | `Assets.xcassets/AppIcon.appiconset`, `LaunchBackground.colorset` | Committed images. `tools/brand/icon.py` renders the same design in the earlier amber palette, not the mint icon that ships | — |
| `Brand`, `Medals` asset folders | `Assets.xcassets/Brand`, `Medals` | Empty namespaces (only `Contents.json`) | — |
| 3D models and rigs | `ios/Timbre/Resources/Models/*.usdz`, `*.rig.json`, `models-manifest.json` | `tools/models/install_artist_models.py` (current models); `tools/models/install_assets.py` for the Blender pipeline | `verify-ios-resources.py` (rig, render, credit licence `by`/`cc0`, anchors), `AppStoreIntegrationTests.testGuitarHasA3DModelWithMatchingRigAnchors` |
| 2D photo stage points, turn signs | `Models/photo-rigs.json`, `Models/photo-turns.json` | By hand / earlier tooling (not in `tools/`) | `verify-ios-resources.py` (points in range, anchors) |
| Recorded samples (300 files, 15 sets, 11.4 MB) | `ios/Timbre/Resources/Samples/<set>/*.m4a`, `Samples/manifest.json` | `tools/build-ios-samples.py` | `verify-ios-resources.py` (licences, hashes, pitches, ≤ 35 MB, every file in `AUDIO-SOURCES.md`), `SampledTonesTests` |
| Fonts | `ios/Timbre/Resources/Fonts/Sora-{Light,Medium,SemiBold,Bold}.ttf`, `Sora-OFL.txt` | Committed | `verify-ios-resources.py` |
| String tables (49 `.lproj`) | `ios/Timbre/Resources/<locale>.lproj/` | `tools/l10n/apply.py`, `apply_learn.py`; English `Learn.strings` from `build.py` | `verify-ios-resources.py` (49 locales; every literal `timbre_*` key exists), `report.py --check --strict`, `critical.py` |
| Privacy manifests | `ios/Timbre/Resources/PrivacyInfo.xcprivacy`, extension folders | By hand | `verify-ios-resources.py` |
| StoreKit test configuration | `ios/Tests/Fixtures/Timbre.storekit` | By hand (test prices: annual 34.99 with 2-week trial, monthly 6.99, lifetime 89.99, annual_b 44.99, annual_c 29.99 with 1-week trial) | `CommerceIntegrationTests` |
| Saved-state fixture | `ios/Tests/Fixtures/state-v1-2026-10.json` | By hand | `PersistenceTests` |
| Real-world audio corpus | `ios/Tests/Fixtures/RealWorld/expected.json` (budgets; `clips` empty today) | The owner records clips | `RealWorldAccuracyTests` (skip until clips exist) |

Lesson technique clips (`LessonVisual.clip`, `Learn/LessonClip.swift`) look for `<name>.mov/.mp4/.m4v` or photographs in
the bundle; none are bundled yet (`python3 tools/curriculum/build.py --check --clips` lists them).

## 16. Known discrepancies and legacy

Found while writing this document; none were changed here.

- `README.md` says "102 tunings" and "71 photographic instrument variants"; the catalogue has 132 tunings and
  `photos.json` 73 entries (`verify-ios-resources.py` asserts 132 and at least 71).
- `README.md` says `tools/models` builds every 3D instrument in Blender. The seven shipped models are Sketchfab artist
  models (CC BY) installed by `tools/models/install_artist_models.py`. Its converter, `tools/models/sketchfab/convert.py`,
  is not in the repository. Installing Blender-pipeline output with `install_assets.py` would fail
  `verify-ios-resources.py`, which requires a `credit` block with licence `by` or `cc0` in every rig.
- `docs/ios/resource-inventory.md` describes Inter, Space Grotesk and IBM Plex Mono fonts and 102 tunings; the app
  ships Sora only.
- `tools/import-ios-resources.py` needs `reference/android` and would overwrite `catalog.json`, `photos.json`, the
  fonts folder and every `Localizable.strings` with the Android snapshot. Do not run it on the current tree.
- `tools/localize-ios-copy.py` edits `ios/Timbre/Views/*.swift`, a folder that no longer exists; it fails if run.
- `ios/TimbreUITests/FirstSessionUITests.swift` is not named by any workflow's `-only-testing`, so CI never runs it.
- TimbreCore reports zero concurrency warnings (`ci-results/core`, `warnings-core/concurrency-by-file.json`), the
  condition `ios/Package.swift` names for moving the package to the Swift 6 language mode.
- The coverage floor is 50 % while measured TimbreCore line coverage is about 95 % (`tools/ci/coverage.py --raise-floor`
  would ratchet it).
- `ReferenceToneRenderer` (`OutputAudio.swift`) is kept for Android parity and no longer used for the tuner's tone.
- `tools/brand/icon.py` draws the icon's design (strobe ring, frozen string) in a warm amber palette; the shipped
  `AppIcon` is mint. Regenerating the icon with the script as it stands would change its colour.
- The `ci-results/convert/*`, `ci-results/import/*`, `ci-results/bench` and `ci-results/scout` branches on the remote
  come from workflows that no longer exist.
- The `lesson-dead-string` capture scene has no UI test that launches it.
