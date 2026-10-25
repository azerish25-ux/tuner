# Wave 19 integration requests (collected from team reports)
## From WP9
- WP1 lint: add `status-colour` rule (`\bPalette\.(?:amber|coral)\b`, Theme.swift exempt) + fail warn rules on listed paths; arm type-scale and status-colour on WP9 paths; --update-baseline. Adopt scratchpad/icon/icon_layers.py as tools/brand/icon.py; designer AppIcon.icon → file reference + ASSETCATALOG_OTHER_FLAGS --enable-icon-stack-fallback-generation=disabled.
- WP3: mount `TuningMenu(onNewCustom:){…}` in TuneView header; Celebration.swift use `TimbreLogotype` in ShareCardFrame and lamp glyph at lines ~59, 428, 479.
- WP4: OnboardingView:242 → TimbreLogotype; OnboardingView:745 → opaque dock backdrop; FirstTuneStep:362 → lamp glyph.
- WP5: Calm-gate PracticeView level card/quests, SongsView XP suffix, EarTraining tiles; M6/P4 full names (Intervals.names) as spoken labels + legend; amber/coral → roles.
- WP10: WatchBridge:133-141 send "neutral" (0xB4BECB) + WatchTheme entry; copy new icon to Watch; TimbreWidgets:204 amber → flame.
- WP2: recapture 07/14/17/18 (toast), 20, 62, 12/30, Learn, store art (icon changed).
## From WP3
- SettingsView.swift:~359 bind Tune-by-feel toggle with `TuneByFeel.binding(store, voiceOver:)`; Feel test uses `TuneByFeel.isOn(...)` at ~389/396.
- UI tests: tune-locked scene checks `tune.status` stays "In tune" (or stage.state lock=1) for 1.5 s; violin/cello/mandolin check `stage.head` head= ≥ 0 once framing ≥ 0.99.
- AppStore, LiveReading, app tests, FirstTuneStep: replace status strings with `TuningStatus` enum cases.
- Lint baseline can shrink (WP1: --update-baseline).
- WP2 recapture iPhone/iPad #1, 49/49b/49c, Arabic. Owner: haptic-bleed device test. Larger studio renders needed for the studio head to reach 55–60% of the stage.
## From WP10 (merged f83c27d; AppStore conflict resolved to WP10 lock path, WP3 recordLock dropped)
- WP8: `bandOnSpeaker` deleted from LocalStore; re-add `public var bandOnSpeaker = false` + read line only if WP8 reads it.
- TuningStatus: WP3 already added the enum; switch string cases in AppStore.statusText, LiveReading.silence/unclear, TunerSessionTests, AppStoreIntegrationTests, FirstTuneStep.
- Env-read sweep → TestSupport.isOn(.demoPitch)/.isAutomated/.debugState/.stageDebug/.value(.scene…): StrumModel:181, TuneView:34, InstrumentStage:793, TimbreTips:12, ShowMe:46, LessonMotion:14, FirstTuneStep:47, PaywallWinBack:78, Analytics:143, RemoteConfig:94, PitchSniperView:218, CoachVoice:298, RootView:65, DemoScenes:53–66/342/625/671.
- learn.course sweep → Preferences.Key.learnCourse / Preferences.learnCourse: Celebration:118, LearnView:13, DailySetCard:186/468, PaywallView:413, SongsView:24, DemoScenes:187–196.
- Risks: Live Activities + Spotlight off in all automated runs; XP toast lands ~0.3 s after lock (WP2 captures); Synchronization.Mutex needs iOS 18.
- Not done: iCloud sync (needs entitlement + owner enabling iCloud on App ID), curriculum sharding, Router/ProgressStore split.
## From WP7 (merged 5dca1c3)
- LessonSteps:565-567 / LessonExplain:567-569: `ChordCardHeader(name:, accent:, threeD: model != nil ? showMeBinding : nil)`; LessonSteps:1595 + LessonExplain:378 show ShowMeToggle whenever a model exists.
- LessonSteps:231 violin "fret" → `Text(verbatim: NotePlace.words(at, board: Fingerboard(instrument: course.instrument)))`; pass `fingerboard:` to FretboardDiagram at LessonSteps :228/:2014, LessonExplain :743/:858; to ShowMe.words at LessonExplain:752.
- ChartSongView:53: add `song: instrument.take(for: chart, title: library.title(of: song), transform: transform)` (full-song take hidden until then).
- SongsView:269-270: use `filledBars` with `SongPlayback.band(notes:harmony:…)`.
- PlayAlongCues (WP8): optional `fingerboard:` on phrase/schedule using FingerPlace.words.
- lint --update-baseline; WP2 recapture 59, 60, 65b, 51/51b, song sheet, results.
- Compile risks: Text+Text with .foregroundStyle in ChordLane; LeadChart has `bars` property + `bars(under:)`.
- Owner: hand rig asset (hook ShowMeController.handRig ready); ukulele/banjo 3D models via models-manifest.json.
## From WP8 (merged)
- bandOnSpeaker: unused anywhere → stays deleted.
- Highway:941-942 "Band with headphones" chip shows on speaker (speaker now plays drums) → revise copy/gate.
- Highway:801, SongPerform:543 → cues via `PlayAlongCues.schedule`; SongChords:245 chord names via `schedule(saying:lead:)`.
- Drop `audio.headphones` gate: SongOpener:571,618; SongsView:267.
- LessonSteps:1743, SongChords:204: `onSpeaker: false` if device test 4 counts drum hits as strokes (grading risk) — decide: default false for attack-graded steps until device test proves otherwise.
- Not done: speaker band step 2 (AEC, device), metronome voices/grooves (joint w/ MetronomeView exhaustive switch :412-416).
- Compile risks: speech delegate conformance, `.ended(let resume)`, sync/async session activation pair, suspended reason raw 1.
- Owner: docs/ios/AUDIO-DEVICE-TESTS.md device sheet.
## From WP4 (merged)
- LearnView: add `.deferredOnboardingQuestions()` to body (else "Just tune" never asks questions). Settings strobe/temperament locks → `FreeTier.opens`.
- PracticeView 575–581, 648–656: `pro:` flags from `FreeTier.opens(.drone/.scales/.intonation/.chords)`.
- TimbreUITests test01: wait for first chord before reminder card.
- Keep `Haptics.feelTest()`. WP8: ambient session API for welcome sound.
- Legal strings: "Free for %lld days, then %@ a month." and "12 × %@" (l10n critical list). Shrink hygiene baseline. Associated Domains. APPLE-DELIVERY.md: _b/_c products creatable; rating JSON needs only `show`.
- Optional: AppStore.canPlay passes RemoteConfig.shared.freeOpenings explicitly.
- Compile risks: `transaction.reason == .renewal`, OSAllocatedUnfairLock in TimbreCore, custom Layout timeline, plan glass background layer.
- Paywall ids now paywall.plan.yearly/.monthly/.lifetime (no other refs to old ids).
## From WP6 (merged)
- Spoken cues: three schedulers now exist (contracts SpokenCues.schedule, WP6 CuePlan.plan in LessonEngine, WP8 PlayAlongCues.schedule). Integration: Highway ~788–802 + SongPerform ~543 → one path (CuePlan for timing → PlayAlongCues/SpokenCues for speech). Pick one, delete dupes.
- SpacedReview .rhythm + SpacedReviewSession:62/121 drop muted/accented beats → reviewed patterns grade chunks as misses. Fix. ChordsView:234 comment stale (9/add9/6/dim chords checkable now).
- WP8: feed AudioClip buffers into audio.frames under a DEBUG-only env flag so UI tests can play recordings.
- Content: add muted beats to man-4-4, uke-8-1, gtr-15-3 (+ similar), accents to uke-8-4 (WP5 may have done).
- Violin "fret" in notes step + explanation lane → FingerboardPlace (WP7 mapping).
- Risks: one misread per take allowed in audio-level chord asserts; Space/Return vs Full Keyboard Access focus (device); loud strokes masking soft ones (onset detector).
- WP2 recapture 53–55 (up strokes steel).
## From WP2 (merged)
- Store #1 + poster now require the "In tune" badge latch (WP3, merged).
- Remove reward island before captures 07, 14, 17, 18, 17b (toast vs captures).
- Listing keeps "band in your headphones" until kit-only speaker band verified (WP8 merged → update listing copy).
- WP5: "Songs you know" shelf (frame #5 caption) + new Kite Weather cover.
- LessonSteps:484 → `.foregroundStyle(finished ? Palette.ink : Palette.inkSoft)`.
- Demo-strum hook (fixed reading with silent string) for dead-string/"Am?" frame.
- WP4: onboarding preselect instrument from attribution ad group via remote-config map when no deep link.
- preview.yml records both cuts, retries on exit 3/4, publishes violin cut to ci-results/preview-violin.
## From WP1 (merged; ios.yml = PR gate core/app(smoke)/release/accessibility/gate; nightly.yml = tour/captures/ipad/archive/tsan on `captures` label — label added to PR #2)
- AudioService: add `self.tapInstalled` to guards at :129, :322, :345 (route/config change replaces demo pitch with silent mic → deaf lesson steps). (Line numbers pre-WP8.)
- TestSupport: read `TIMBRE_STAGE_REST`; StageShared:106, Kit:807, Shaders:11 treat as Low Power so audits complete.
- SettingsView:530 language list → only languages with a .lproj.
- CommerceService:160 → refresh entitlements again briefly after verified purchase.
- APPLE-DELIVERY.md §3.4: document new delivery inputs (internal_testflight_untranslated).
- Owner: make `gate` (+ optionally `accessibility`) required checks.
- l10n report + critical baseline rewritten (de4875e).
## From WP5 (merged 63f73bd; 526 lessons/11 courses, 19 courses total incl. songbooks, 146 songs)
- Curriculum.distinctTuneCount body → `distinctTunes.count`.
- SoundFX.playWobble(frequency:) so Pitch Sniper miss sounds near target.
- canPlay honours RemoteConfig.freeSongs during carol week; privacy note for free-text `song_request` event (PRIVACY.md).
- Lint baseline shrink. WP2 recapture Kite Weather sleeve, new Songs shelves, Pro lock.
- Compile doubts: two-way Text in request footer, ProLock in sleeve overlay, local helper funcs in dial motif.
- Owner: Kite Weather cover commission optional; low-G ukulele course.
## Integration pass leftovers (A merged 0170b42, D merged 8f11ae9)
- A: OnboardingView.playWelcome() → C's ambient welcome-sound API once C reports its name.
- A: TuningMenu only on the tuning line; whole header would break tests tapping `tune.instrument`.
- A: no carol-week key in RemoteConfig; owner removes freeSongs after the week. Owner: refresh published privacy.html from PRIVACY.md.
- D: TimbreWatchWidgets.swift:26 sample tint "amber"/"mint" → "neutral"; WatchSnapshot Step.tint doc lists old names; PaywallView ~536 comment "by title"; Watch TodayScreen/MetronomeScreen status amber (baselined).
- Gate: SmokeUITests.testBuyingProUnlocksAProTool fails "the drone didn't ask for Pro" on 3be9da4 — investigate with ci-results/gate.
## Post-integration (audio + QA merged, v2/foundations 0bbf273)
- Audio: called-off start no longer releases a newer start's session; one quiet retry; DEBUG Logger category `audio`. Device test list in agent report: cold launch onto tuner ×N, restart within 1 s, drone + mic, AirPods in/out, phone call alert, permission denied.
- QA: in the store scene the main thread stalled 9.4 s (2.2 s violin) right when the take's output started (ensureOutput → configureSession → AudioSessionOwner queue.sync behind a pending deactivation / slow setActive on CI). Click now starts before the take clock. Device check: time from Perform to first click; any freeze >300 ms is a bug.
- AX5 tuner header still cramped (text clipped, overlaps) — tuner team.
- Handoff check ignores moved line numbers.
