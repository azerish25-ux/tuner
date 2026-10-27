# Audio startup readiness implementation plan

> **For agentic workers:** Execute inline with executing-plans; the parent owns final independent review and commits. Shared workspace use is explicitly authorized.

**Goal:** Remove synchronous session activation from UI playback, preserve desired playback/capture across asynchronous startup, and start lesson clocks only after click readiness.

**Architecture:** Commands synchronously reserve desired state and return `Task<Bool, Never>` readiness handles. A shared main-actor output startup awaits session activation on the existing session queue, coalesces startup and checks lifecycle/command generations before installing output. Explicit stops cancel intent; interruption suspension preserves only still-requested restore settings. Recording playback checks transport generation after activation.

**Tech Stack:** Swift 5 concurrency, SwiftUI, AVAudioEngine, AVAudioSession, XCTest.

## Constraints

- No commit/push by this worker; preserve other workers' changes.
- Keep renderer state, microphone retry policy, capture/output sharing, 180ms route coalescing, background metronome/drone and foreground-only capture.
- No Xcode/Swift on this Windows host: native RED/GREEN are unexecuted until hosted macOS CI. Never report a native pass from static checks.
- Device test sheet remains unrun.

## Task 1: Specify async command and cancellation behavior

Files: create `ios/TimbreAppTests/AudioStartupTests.swift`; modify `ios/Timbre/Audio/AudioService.swift`.

- [x] Write tests using a manually suspended activation dependency and a fake output preparation dependency. Assertions: a main-actor task advances during delayed activation; metronome completion stays pending; stop suppresses delayed click; newest tempo request wins; cancelled startup releases only once no capture/output intent holds it.
- [ ] Attempt focused command on macOS: `xcodebuild test -project ios/Timbre.xcodeproj -scheme Timbre -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TimbreAppTests/AudioStartupTests CODE_SIGNING_ALLOWED=NO`. On Windows record unavailable, not RED or GREEN.
- [x] Implement injectable activation/release/output preparation defaults, a coalesced output readiness task, and per-command generation checks. Public command signature example:

```swift
@discardableResult
func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool,
                  beatLevels: [Int]? = nil, sound: MetronomeRenderer.Sound = .click,
                  tool: Bool = false) -> Task<Bool, Never>
```

- [x] Migrate all direct output requests and retry/rebuild restarts to await readiness. Preserve pending-session reservations until underlying activation completes, even when command task is cancelled.

## Task 2: Capture and interruption intent

Files: `ios/Timbre/Audio/AudioService.swift`, `ios/TimbreAppTests/AudioStartupTests.swift`.

- [x] Test interruption desired-state preservation and explicit-stop clearing through testable lifecycle entry points; test delayed rebuild/restore token checks.
- [x] Store capture settings before permission await, include pending capture in interruption snapshot, and distinguish interruption suspension from explicit stop. Clear interrupted microphone intent on stopCapture. Guard all queued restore/rebuild tasks with capture generation.
- [x] Retain activationsPending guards for microphone and extend to output activation. Revalidate after every awaited activation and retry delay. Explicit cancellation does not publish startup errors.

## Task 3: Recording transport and interface sounds

Files: `ios/Timbre/YourSongs/RecordingPlayer.swift`, `ios/Timbre/Audio/AudioService.swift`, focused XCTest additions.

- [x] Test transport stop/seek/new-play suppress stale activation completion using injectable activation and transport startup where needed.
- [x] Return a readiness task from play; increment transport generation before asynchronous activation, reserve pending session ownership, check generation before scheduling/playing, and release only after the last pending request when transport has no desired playback.
- [x] Replace synchronous interface ambient preparation with serial queue scheduling; no main thread session queue wait remains. Serial execution rechecks holders and pending activation reservations before setting ambient.

## Task 4: Lesson startup clocks

Files: `SongPerform.swift`, `Highway.swift`, `RhythmStep.swift`, `SongChords.swift`, `LatencyCalibration.swift`, `SongSheet.swift`.

- [x] Await metronome readiness before creating clocks, counting in, judging, cues and band first-bar scheduling. Keep a view-owned startup task or request generation and cancel from existing stop/clear/disappear paths. The returned command handle must be cancellation checked after await.
- [x] SongPlayback waits for its optional band click before creating its ContinuousClock; scheduled tones await their readiness so startup does not run ahead silently.
- [x] Review every `setMetronome` caller with `rg -n 'setMetronome|session.begin|startTime =|startedAt =' ios/Timbre` for clock sequencing.

## Task 5: Verification receipt and review handoff

- [x] Run JSON/static syntax and diff checks available on Windows. Run repository hygiene checks appropriate to touched Swift files if available.
- [x] Attempt `swift --version` and `xcodebuild -version` once to establish native-tool availability.
- [x] Save `docs/ios/readiness/reviews/audio-implementation.json` with touched scope, actual checks, unexecuted native tests and device gates. Parent must obtain a fresh independent diff review before committing.
