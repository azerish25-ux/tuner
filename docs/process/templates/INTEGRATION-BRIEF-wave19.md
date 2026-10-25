# Wave 19 integration pass (read after PREAMBLE.md)

All ten wave-19 packages are merged on `v2/foundations`. Each team could only see its own worktree, so each left
cross-package requests. You carry out ONE group of them (below). Four integration agents run in parallel, each in its
own worktree, with DISJOINT files. Touch only the files your group lists; if an item needs a file outside your list,
leave it and report it precisely (file, line, code).

## Setup (do this first)
Your worktree may have been cut from `main`. Run, inside your worktree:
  git fetch -q origin v2/foundations && git reset -q --hard origin/v2/foundations && git log --oneline -1
and confirm the head is the commit the orchestrator named in your prompt (or newer). Line numbers below were reported
by the teams against their own branches and may have moved: locate by the code, not by the number.

## Rules
- Smallest correct change. Reuse what exists (TestSupport, Preferences, FreeTier, FingerboardPlace/NotePlace,
  PlayAlongCues, CuePlan, TimbreLogotype, the lamp glyph, Palette roles, Typeface scale). No new abstractions unless a
  request names one. Keep validation, error handling, accessibility labels and identifiers.
- No Swift compiler here: verify every API you call against the code in the repo (grep its declaration) and Apple's
  docs. Compile safety beats ambition: if an item is risky, do the safe part and report the rest.
- No review/juror/bug-number comments. No "WIP", no "[skip ci]".
- Before committing run: python3 tools/ci/lint_tells.py ; python3 tools/verify-ios-resources.py ;
  python3 tools/curriculum/build.py --check (only if you touched curriculum).
- Finish: ONE commit in your worktree (git add -A), a clear technical message ending with
    Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
    Claude-Session: https://claude.ai/code/session_019ufcyLVTAsS1wDMvGhgM3C
  Never push; never touch other branches.
- Report: branch, commit hash, per-file changes, items done / not done (why), compile doubts, anything that needs another
  group's file.

## Group A — tuner, settings, onboarding, commerce, Learn shell
Files: ios/Timbre/Services/AppStore.swift, Services/LiveReading.swift, Services/CommerceService.swift,
Services/Analytics.swift, Services/RemoteConfig.swift, Settings/SettingsView.swift, Tune/TuneView.swift,
Tune/Celebration.swift, Onboarding/* (OnboardingView, FirstTuneStep, …), Learn/LearnView.swift,
Practice/DailySetCard.swift, Paywall/*, ios/TimbreAppTests/TunerSessionTests.swift,
ios/TimbreAppTests/AppStoreIntegrationTests.swift, docs/ios/PRIVACY.md, docs/ios/APPLE-DELIVERY.md.
Items:
1. TuningStatus: `TuningStatus` enum exists (TimbreCore TuningTracker.swift). Replace status string literals with enum
   cases in AppStore.statusText, LiveReading.silence/unclear, FirstTuneStep, TunerSessionTests, AppStoreIntegrationTests.
2. SettingsView: bind the Tune-by-feel toggle with `TuneByFeel.binding(store, voiceOver:)`; the feel test uses
   `TuneByFeel.isOn(...)`. Language list shows only languages with a `.lproj` in the app bundle. Strobe and temperament
   locks read `FreeTier.opens(...)` (check FreeTier's API).
3. TuneView: mount `TuningMenu(onNewCustom:){…}` in the header (see WP9's TuningMenu); env read → TestSupport.
4. Celebration: `TimbreLogotype` in ShareCardFrame; the lamp glyph (StreakLamp / whatever WP9 named it) where a flame
   or streak symbol is drawn; `learn.course` → `Preferences.learnCourse` / `@AppStorage(Preferences.Key.learnCourse)`.
5. Onboarding: OnboardingView wordmark → `TimbreLogotype`; FirstTuneStep streak glyph → lamp glyph; env reads →
   TestSupport.
6. LearnView: add `.deferredOnboardingQuestions()` to the body (WP4's OnboardingDeferral.swift) so "Just tune" users get
   the questions on Learn; `learn.course` sweep. DailySetCard: `learn.course` sweep.
7. CommerceService: after a verified purchase, refresh entitlements again briefly (one retry ~1 s later) so a slow
   StoreKit update can't leave Pro off.
8. AppStore.canPlay: pass `RemoteConfig.shared.freeOpenings` explicitly; make `freeSongs` honour carol week if
   RemoteConfig exposes it (else report).
9. PaywallWinBack, Analytics, RemoteConfig env reads → TestSupport; PaywallView `learn.course` sweep.
10. PRIVACY.md: note the free-text `song_request` event (what is sent, opt-out via shareUsageData). APPLE-DELIVERY.md:
    `_b`/`_c` products can now be created; rating JSON needs only `show`; §3.4 documents the
    `internal_testflight_untranslated` delivery input.

## Group B — lessons, songs, play-along
Files: ios/Timbre/Learn/LessonSteps.swift, Learn/LessonExplain.swift, Learn/Highway.swift, Learn/SongPerform.swift,
Learn/SongChords.swift, Learn/SongOpener.swift, Learn/ShowMe*.swift, Learn/LessonMotion.swift, Learn/SpacedReview*.swift,
ios/Sources/TimbreCore/**/SpacedReview*.swift, Practice/ChordsView.swift, YourSongs/ChartSongView.swift,
Songs/SongsView.swift, Audio/PlayAlongCues.swift, tools/curriculum/** (content only), ios/Timbre/Resources/curriculum.json
(rebuilt by build.py only).
Items:
1. LessonSteps / LessonExplain: `ChordCardHeader(name:, accent:, threeD: model != nil ? showMeBinding : nil)`; show
   `ShowMeToggle` whenever a model exists, not only `if showMe`. Violin/cello must never say "fret": use
   `NotePlace.words(at, board: Fingerboard(instrument: course.instrument))` (check WP7's FingerboardPlace.swift API) and
   pass `fingerboard:` to every `FretboardDiagram` and to `ShowMe.words`. LessonSteps finished-row colour:
   `.foregroundStyle(finished ? Palette.ink : Palette.inkSoft)`.
2. Attack-graded steps (LessonSteps strum/chord steps that call `playBand`, SongChords) pass `onSpeaker: false` — the
   speaker band is drums now and must not be graded as strokes until the device test proves otherwise.
3. Spoken cues: there are three schedulers (contracts' SpokenCues.schedule, WP6's CuePlan.plan in LessonEngine, WP8's
   PlayAlongCues.schedule). Highway (~788–802) and SongPerform (~543): time cues with `CuePlan.plan`, speak them via
   `PlayAlongCues.schedule`; SongChords chord names via `PlayAlongCues.schedule(saying:lead:)`. Give PlayAlongCues an
   optional `fingerboard:` so violin/cello cues say string + finger (FingerboardPlace). Delete whichever scheduler ends
   up unused (only if nothing else references it).
4. Highway: the "Band with headphones" chip is wrong now that the speaker plays a drums-only band: reword/gate it so it
   tells the truth (speaker = drums, headphones = full band). SongOpener (two places) and SongsView: drop the
   `audio.headphones` gate on the band.
5. ChartSongView: `song: instrument.take(for: chart, title: library.title(of: song), transform: transform)` so the
   full-song "Chords & words" take appears.
6. SongsView: build the band with `filledBars` + `SongPlayback.band(notes:harmony:…)`; `learn.course` →
   Preferences; XP suffix hidden in Calm mode (see how WP9 gates Calm).
7. SpacedReview `.rhythm` and SpacedReviewSession keep muted and accented beats (they currently drop them, so reviewed
   chunks grade as misses). ChordsView: remove the stale comment saying 9/add9/6/dim chords can't be checked.
8. ShowMe, LessonMotion env reads → TestSupport.
10. SwiftLint errors (CI gate): LessonSteps.swift (2372 lines) and Highway.swift (2290) must each be ≤ 2200 lines:
   move self-contained types (whole structs/views, unchanged) into new files in the same folder, named for what they
   hold (new files are picked up by XcodeGen's folder source; check ios/project.yml). Highway's function with 10
   parameters (~line 1821) must take ≤ 7: group related parameters into a small struct. Keep new lines ≤ 160 chars.
9. Content: check man-4-4, uke-8-1, gtr-15-3 (and similar strum lessons) have muted beats and uke-8-4 accents, using
   lib.py's parameters; add if missing; rebuild with build.py; keep every lesson id.

## Group C — audio, practice, demo scenes
Files: ios/Timbre/Audio/AudioService.swift, Audio/SoundFX.swift, Audio/CueVoice.swift, ios/Sources/TimbreCore/DSP/*,
Practice/PracticeView.swift, Practice/PitchSniperView.swift, Practice/EarTraining*.swift, Practice/MetronomeView.swift,
Support/DemoScenes.swift.
Items:
1. AudioService: when a route or engine configuration change rebuilds the engine, the demo pitch must not be replaced by
   a silent real microphone: guard the rebuild paths with `self.tapInstalled` (and whatever demo flag exists) so lesson
   steps under TIMBRE_DEMO_PITCH stay fed. In DEBUG only, behind a TestSupport launch key, feed `AudioClip` buffers into
   the same frames path the mic uses, so UI tests can play recordings (WP6's AudioClip/LessonListening).
2. An ambient-session way to play the onboarding welcome sound (API on AudioService/SoundFX); report the call site
   change for Group A's onboarding file instead of making it.
3. SoundFX.playWobble(frequency:) and Pitch Sniper's miss uses it near the target note. PitchSniperView env read →
   TestSupport.
4. PracticeView: `pro:` flags from `FreeTier.opens(.drone/.scales/.intonation/.chords)` (check the enum); level card and
   quests hidden in Calm mode. EarTraining: tiles respect Calm; interval labels speak full names (Intervals.names) for
   VoiceOver with a visible legend for M6/P4 abbreviations; amber/coral → Palette roles.
5. DemoScenes: env reads → TestSupport (`TestSupport.value(.scene…)` etc.), `learn.course` → Preferences; add a
   demo-strum hook (one fixed reading with a silent string) so the dead-string "Am?" frame can be captured.
7. SwiftLint errors (CI gate): Band.swift has two functions with 9 and 10 parameters (~lines 775 and 855); bring
   each to ≤ 7 by grouping related parameters into a small struct. Keep new lines ≤ 160 chars.
6. Metronome voices/grooves (WP8 left it): only if it is a small, compile-safe change to MetronomeRenderer.Sound and the
   MetronomeView switch; otherwise report.

## Group D — platform, stage, watch, widgets, tests, lint
Files: ios/Timbre/RootView.swift, Coach/CoachVoice.swift (wherever it is), TimbreTips.swift, Stage/* (StrumModel,
InstrumentStage, StageShared, Shaders), Design/Kit.swift, Support/TestSupport.swift, Support/Preferences.swift,
ios/TimbreWatch/**, ios/TimbreWidgets/**, Services/WatchBridge.swift, ios/Sources/TimbreCore/Learn/Curriculum.swift,
ios/TimbreUITests/**, tools/ci/**.
Items:
1. Env reads → TestSupport in RootView, CoachVoice, TimbreTips, StrumModel, InstrumentStage. TestSupport reads
   `TIMBRE_STAGE_REST`; StageShared, Kit and Shaders treat it as Low Power so the accessibility audit can finish.
2. WatchBridge sends a "neutral" colour (0xB4BECB) where it sent amber/coral for status; add the WatchTheme entry; copy
   the current app icon to the Watch app's asset catalog if it differs. TimbreWidgets amber → flame role.
3. Curriculum.distinctTuneCount body → `distinctTunes.count` (if `distinctTunes` exists; else report).
4. UI tests: tune-locked scene checks `tune.status` stays "In tune" (or `stage.state` lock=1) for 1.5 s; violin, cello
   and mandolin checks read `stage.head` and expect head ≥ 0 once framing ≥ 0.99 (only if the identifiers exist —
   grep); test01 waits for the first chord before the reminder card; the reward toast/island is dismissed or waited out
   before captures 07, 14, 17, 18 and 17b (find how the toast is identified).
5. Lint: add a `status-colour` rule to tools/ci/lint_tells.py (`\bPalette\.(?:amber|coral)\b`, Theme.swift exempt,
   warn level unless the existing structure makes per-path error arming easy). Do NOT run --update-baseline: the
   orchestrator does that once after merging all four groups (a new warn rule must not fail CI before then).
