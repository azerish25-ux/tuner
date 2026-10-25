#if DEBUG
import AVFoundation
import ObjectiveC
import QuartzCore
import SwiftUI
import TimbreCore

/// App Store screenshot and App Preview scenes, debug builds only. `TIMBRE_SCENE=<name>` (with `TIMBRE_DEMO_PITCH=1`) puts
/// the app straight into one hero moment through its own code paths: the tuner's tracker really locks, the lesson's judge
/// really hears each string. The UI tests (TimbreUITests `test11StoreTunerLock`, `test12StoreChord`,
/// `test14StoreSongPerform`, `test15StoreShowMe`, `test16StoreViolinStage`, `test17StoreInstrumentWall`, and the
/// AppPreviewUITests tour) then capture what the listing promises without racing the demo pitch's clock.
///
/// Hooks, a line or two each: `Bootstrap.load` calls `start`, `AppStore.startListening` asks `steadyPitch`,
/// `LessonPlayer` asks `lessonStart` (init) and `holds` (advance), `SongPerformStep` asks `performBeat` and
/// `stillScore`, `ChordStep` hands its strum handler to `strumWithSilentString`, `ShowMeStage` carries `ShowMeProbe` and
/// the explanation's card `ShowMeHostProbe`. Stage code may read `marketingScale` (inside `#if DEBUG`) to exaggerate
/// motion for the camera.
///
/// - `tune-locked` (frame #1): the demo pitch plays the selected string steadily in tune, so each string locks after
///   the tracker's 0.65 s hold. The two lowest strings lock first (✓ on their chips), then the third locks and stays
///   locked: solid chip, the In tune badge, its peg ringed and ticked on the 3D headstock. A stalled main thread only
///   delays a lock (the hold starts again), so the scene waits for each one rather than for a time. With
///   `TIMBRE_SCENE_COMET=1` the held string is plucked again every `cometPeriod`, so its lock shimmer runs again for a
///   picture taken mid-comet.
/// - `preview-tune` (the App Preview): the tuner holds off locking until the UI test says the 3D stage is up (it creates
///   the `TIMBRE_SCENE_CUE` file). Then the lowest string drifts in from 14 cents flat and locks with its bell; after a hold
///   the camera can film, each other string locks in turn, steadily, and the last one brings the full-tune celebration.
///   Strings are chosen the way automatic detection chooses them, so AUTO stays AUTO on screen. Each lock is noted the
///   moment it lands (within 10 ms), and the strings themselves are heard in the preview (`PreviewString`).
/// - `show-me` (frame #3's alternative, the App Preview): the same lesson opens on its first step, E minor explained on
///   its card. It is the chord's first appearance in the course, so the 3D model takes the card by itself once it has
///   settled and the demonstration plays there: the fingertips land in finger order, then the chord rings across every
///   string. (The test asks with "Show me" when the model doesn't come by itself, and again for each replay it needs.)
/// - `lesson-chord` (frame #3): the first guitar lesson with a chord ("Your first chord: E minor") opens on its chord
///   step with the day's tune check done. The demo pitch plays the chord string by string, every string lights, and
///   the step stays on "Every string rings" instead of moving on.
/// - `lesson-dead-string`: the same chord step, where one strum leaves a string silent (`strumWithSilentString`): the
///   strings that rang tick, and the one that didn't is named with what usually stops it ("String 3 isn't ringing").
///   The demo pitch stays quiet, so nothing plays the chord string by string and the step waits on that picture.
/// - `song-perform` (frame #2, the App Preview): a song (`TIMBRE_SCENE_SONG`, Kite Weather by default) opens on its
///   performance (the final take over the band, on the fretboard runway with its words) and starts the take by itself a
///   moment later, at `performBar` (`TIMBRE_SCENE_BAR`; by default the second half of Kite Weather's first chorus).
///   Every note before that bar is judged as the demo pitch plays them, on time, so the combo, the score and the ribbon
///   stand where a clean take would; from there the demo pitch plays each note on time.
/// - `instrument-wall` (frame #4): the tuner opens its instrument browser by itself.
///
/// `TIMBRE_SCENE_INSTRUMENT=<catalog id>` opens the tuner on that instrument first (the violin page's frames).
/// `TIMBRE_PREVIEW_AUDIO=<folder>` writes down what the app plays, for the App Preview's soundtrack (`PreviewRecorder`).
enum DemoScene: String {
    case tuneLocked = "tune-locked"
    case lessonChord = "lesson-chord"
    case lessonDeadString = "lesson-dead-string"
    case songPerform = "song-perform"
    case showMe = "show-me"
    case previewTune = "preview-tune"
    case instrumentWall = "instrument-wall"

    static let current: DemoScene? = TestSupport.value(.scene).flatMap(DemoScene.init(rawValue:))

    /// What the UI test asked for besides the scene, all optional.
    enum Option {
        /// The instrument the tuner opens on (a catalog id such as "violin.standard.4").
        static let instrument = TestSupport.value(.sceneInstrument).flatMap { $0.isEmpty ? nil : $0 }
        /// `song-perform`: the song (a lesson id) and the bar its take starts at.
        static let song = TestSupport.value(.sceneSong).flatMap { $0.isEmpty ? nil : $0 }
        static let bar = TestSupport.value(.sceneBar).flatMap { Int($0) }
        /// `tune-locked`: pluck the held string again every `cometPeriod`, so its lock shimmer runs again.
        static let comet = TestSupport.isOn(.sceneComet)
        /// `preview-tune`: a file the UI test creates once the 3D stage is up; the scene starts then.
        static let cue = TestSupport.value(.sceneCue).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// How much a store or preview capture exaggerates the stage's motion (the live string's swing): 3 in a scene, 1
    /// otherwise. The camera sees 1.2 mm of string travel as nothing; the product never sees this value. `start` hands
    /// it to the 3D stage (`StageInput.captureScale`) before the stage appears.
    static var marketingScale: Double { current == nil ? 1 : 3 }

    /// The tuner's demo pitch plays the selected string in tune at once, with no six-second drift.
    static var steadyPitch: Bool {
        switch current {
        case .tuneLocked?: return true
        case .previewTune?: return PreviewTune.steady
        default: return false
        }
    }

    /// Starts the scene once the store is ready (`Bootstrap.load`, before the first frame).
    @MainActor static func start(_ store: AppStore) {
        PreviewRecorder.startIfAsked(store)
        StageInput.captureScale = Float(marketingScale)
        if let id = Option.instrument { chooseInstrument(id, store) }
        switch current {
        case .tuneLocked?:
            Task { @MainActor in await DemoScene.lockStrings(store) }
        case .previewTune?:
            Task { @MainActor in await PreviewTune.run(store) }
        case .lessonChord?, .showMe?, .lessonDeadString?:
            // Learn opens it out of its Continue card, as it opens onboarding's first lesson.
            guard let lesson = DemoScene.chordLesson(store) else { return }
            // A strum with a silent string is the picture: the demo pitch never plays a note that would tick it off.
            if current == .lessonDeadString { store.demoNoteDue = { false } }
            store.pendingLessonId = lesson.id
            store.selectedTab = .learn
        case .songPerform?:
            DemoScene.openSong(store)
        case .instrumentWall?:
            Task { @MainActor in
                // Past the tuner's own entrance, so the sheet rises over a settled screen.
                try? await Task.sleep(for: .seconds(1.5))
                store.selectedTab = .tune
                store.showInstrumentPicker = true
            }
        case nil:
            break
        }
    }

    @MainActor private static func chooseInstrument(_ id: String, _ store: AppStore) {
        guard store.instrument.id != id, let instrument = store.catalog.instrument(id: id) else { return }
        store.selectInstrument(instrument)
    }

    // MARK: Lessons

    /// The run `LessonPlayer` opens `lesson` with: in `lesson-chord` and `lesson-dead-string`, at its first chord step;
    /// in `show-me`, at the step that explains that chord on its card; in `song-perform`, at the song's last step, its
    /// performance (nil otherwise).
    static func lessonStart(_ lesson: Lesson) -> LessonRun? {
        let start: Int?
        switch current {
        case .lessonChord?, .lessonDeadString?: start = lesson.steps.firstIndex(where: DemoScene.isChord)
        case .showMe?: start = lesson.steps.firstIndex(where: DemoScene.explainsChord)
        case .songPerform? where lesson.id == performSongId: start = lesson.steps.isEmpty ? nil : lesson.steps.count - 1
        default: start = nil
        }
        guard let index = start else { return nil }
        var run = LessonRun(lesson: lesson)
        for _ in 0..<index { run.complete(score: nil) }
        return run
    }

    /// The finished step stays on screen (its finished state is the picture) instead of handing over to the next.
    static func holds(_ step: LessonStep?) -> Bool {
        guard current == .lessonChord, let step else { return false }
        return DemoScene.isChord(step)
    }

    private static func isChord(_ step: LessonStep) -> Bool {
        if case .playChord = step { return true }
        return false
    }

    /// An explanation with a chord on its card (where "Show me" plays the chord on the 3D model).
    private static func explainsChord(_ step: LessonStep) -> Bool {
        if case let .explain(_, _, visual) = step, case .chord = visual { return true }
        return false
    }

    @MainActor private static func chordLesson(_ store: AppStore) -> Lesson? {
        store.curriculum.course(id: "guitar")?.lessons.first { lesson in lesson.steps.contains(where: DemoScene.isChord) }
    }

    // MARK: A strum with a silent string

    /// How long after the chord step starts listening `lesson-dead-string` strums: past the card's entrance.
    static let deadStringDelay: Duration = .seconds(1.5)

    /// `lesson-dead-string`: the chord step hears one strum, `deadStringDelay` after it starts listening, the fixed
    /// reading `silentStrum` (every string ringing in tune but one), so it names the string that didn't ring. `hear` is
    /// the step's own strum handler, given the reading as its analyser would give it. Does nothing in any other run.
    @MainActor static func strumWithSilentString(pitches: [Double], hear: @escaping @MainActor (PolyReading) -> Void) {
        guard current == .lessonDeadString, let reading = silentStrum(pitches: pitches) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: deadStringDelay)
            hear(reading)
        }
    }

    /// One strum of a chord whose strings sound at `pitches` (Hz, lowest string first): each heard at its own pitch but
    /// `silentString`'s, which isn't heard at all. Nil when no string can be called silent.
    static func silentStrum(pitches: [Double]) -> PolyReading? {
        guard let silent = silentString(pitches) else { return nil }
        let strings = pitches.indices.map { index in
            PolyReading.StringReading(index: index, targetHz: pitches[index], frequencyHz: index == silent ? nil : pitches[index],
                                      confidence: 0.9, evidence: .fundamental)
        }
        return PolyReading(strings: strings, onsetTime: 0, levelDbfs: -24)
    }

    /// The string left silent: the highest one clear of every other string's harmonics (`ChordRing.isClear`), so a
    /// strum without it reads as a dead string rather than an unsure one (on E minor, the open G: string 3).
    static func silentString(_ pitches: [Double]) -> Int? {
        pitches.indices.filter { ChordRing.isClear($0, among: pitches) }.max { pitches[$0] < pitches[$1] }
    }

    // MARK: A song, performed

    /// The song performed: `TIMBRE_SCENE_SONG`, else Kite Weather (Originals), the song of the day, a full arrangement
    /// with words, played on the fretboard runway.
    static var performSongId: String { Option.song ?? "orig-kite-weather" }
    /// The bar the take starts at (0-based, as the arrangement counts them): `TIMBRE_SCENE_BAR`, else Kite Weather's
    /// second half of the first chorus (bars 12–19), "let it climb, let it go", a bar before the hook line ("It's kite
    /// weather, kite weather") comes round again. The 68 notes before it are already played clean.
    static var performBar: Int { max(0, Option.bar ?? 15) }
    /// How long after the performance opens the take starts: past the zoom that brings the song in, and past the UI
    /// test's last look for the lesson (a query stalls the main thread; a note heard late would break the run).
    static let performDelay: Duration = .seconds(3)

    /// In `song-perform`, the beat of `lesson`'s performance its take starts at (nil otherwise: the player taps Perform).
    /// The take's clock starts a bar earlier (`SongPerformStep.startScene`): its first click is beat `beat − meter`.
    static func performBeat(_ lesson: Lesson, beatsPerBar: Int) -> Double? {
        guard current == .songPerform, lesson.id == performSongId else { return nil }
        let meter = max(1, beatsPerBar)
        let beat = Double(performBar * meter)
        PreviewRecorder.takeScheduled(lesson, firstBeat: beat - Double(meter), meter: meter)
        return beat
    }

    /// In `song-perform` the take's score and the HUD's combo and multiplier change in place rather than rolling their
    /// digits or popping (`HighwayHUD`): they change with every note, several times a second, so a rolling or popping
    /// count is mid-change in almost any picture.
    static var stillScore: Bool { current == .songPerform }

    /// Learn opens the song (as a Siri or Spotlight link opens one), then goes back to the player's own course once
    /// the song is on screen, so later runs in the same simulator still open Learn on guitar.
    @MainActor private static func openSong(_ store: AppStore) {
        guard let found = store.curriculum.lesson(id: performSongId) else { return }
        let own = Preferences.learnCourse
        store.pendingLessonId = found.lesson.id
        store.selectedTab = .learn
        guard own != found.course.id else { return }
        Task { @MainActor in
            for _ in 0..<50 where store.pendingLessonId != nil { try? await Task.sleep(for: .milliseconds(100)) }
            // Past Learn's own wait for covering screens, so the switch happens behind the open song.
            try? await Task.sleep(for: .milliseconds(2500))
            guard Preferences.savedLearnCourse == found.course.id else { return }
            Preferences.learnCourse = own
        }
    }

    // MARK: Tuner

    /// `tune-locked` with `TIMBRE_SCENE_COMET=1`: seconds between plucks of the held string.
    static let cometPeriod = 4.0

    /// Locks the two lowest strings one after the other, then the third, which holds (plucked again every
    /// `cometPeriod` with `TIMBRE_SCENE_COMET=1`, its lock shimmer running each time).
    @MainActor private static func lockStrings(_ store: AppStore) async {
        // The tuner is up by now; it starts listening as it appears when the microphone is allowed.
        try? await Task.sleep(for: .seconds(1.5))
        store.selectedTab = .tune
        store.startListening()
        let courses = store.courses
        guard courses.count >= 3 else { return }
        for course in courses.prefix(2) {
            await lock(course, store)
            // Its bell rings and its chip settles with the ✓ before the next string takes over.
            try? await Task.sleep(for: .seconds(1))
        }
        let held = courses[2]
        await lock(held, store)
        guard Option.comet else { return }
        for _ in 0..<150 {
            try? await Task.sleep(for: .seconds(cometPeriod))
            guard store.selectedTab == .tune, store.audio.running, !store.showInstrumentPicker else { continue }
            // The same string again: the tracker starts its hold afresh and locks it 0.65 s later, shimmer and all.
            select(held, store)
        }
    }

    /// Selects a string and waits until the tracker has locked it (at most a minute: a UI-test query stalls the main
    /// thread, and a gap of more than 150 ms in the readings starts the hold again), looking every `pollMilliseconds`.
    @MainActor fileprivate static func lock(_ course: Course, _ store: AppStore, pollMilliseconds: Int = 25) async {
        select(course, store)
        let poll = max(1, pollMilliseconds)
        for _ in 0..<(60_000 / poll) where !store.lockedCourses.contains(course.index) {
            try? await Task.sleep(for: .milliseconds(poll))
        }
    }

    @MainActor fileprivate static func select(_ course: Course, _ store: AppStore) {
        store.chooseCourse(course.index)
        // Choosing a string by hand turns automatic detection off; the scene keeps the default (on).
        store.automatic = true
    }
}

// MARK: - The App Preview's tuner

/// `preview-tune`: the lowest string drifts in and locks, holds for the camera, then the others lock one by one and the
/// celebration follows. Each lock and the full tune are written to the preview's event log (`PreviewRecorder`), so the
/// UI test can cut on the moments the app saw rather than on predictions.
enum PreviewTune {
    /// While true, the demo pitch plays the selected string in tune at once (every string after the first).
    nonisolated(unsafe) static var steady = false
    /// After the first lock, how long the camera stays on it before the next string: the cut holds the lock 1.5 s.
    static let firstHold = 2.2
    /// After each later lock: its bell and the chip's tick, then the next string.
    static let nextGap = 0.5
    /// Without a cue file, the scene starts this long after launch.
    static let fallbackStart = 12.0
    /// How often the scene looks for each lock, in milliseconds: the preview's sync is taken the moment it is noted.
    static let lockPoll = 10

    @MainActor static func run(_ store: AppStore) async {
        store.selectedTab = .tune
        let launched = Date()
        let courses = store.courses
        guard let first = courses.first else { return }
        steady = false
        // Until the cue the tuner listens (a tuner that hears nothing rests on its studio picture after a while, and the
        // 3D model must stay up), but the lowest string is chosen again every 0.4 s, so its 0.65 s hold never completes
        // and nothing locks before the camera rolls.
        var chosen = Date.distantPast
        while !cued(since: launched) {
            if !store.audio.running { store.startListening() }
            if Date().timeIntervalSince(chosen) > 0.4 {
                DemoScene.select(first, store)
                chosen = Date()
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        // A fresh session (the demo pitch's drift starts over, 14 cents flat), with no pause long enough to rest.
        store.pauseListening()
        DemoScene.select(first, store)
        store.startListening()
        PreviewRecorder.event("listen")
        PreviewRecorder.shared.followStrings(store)
        await DemoScene.lock(first, store, pollMilliseconds: lockPoll)
        PreviewRecorder.event("lock", ["string": 0])
        try? await Task.sleep(for: .seconds(firstHold))
        steady = true
        for (number, course) in courses.enumerated().dropFirst() {
            await DemoScene.lock(course, store, pollMilliseconds: lockPoll)
            let all = store.allCoursesLocked
            PreviewRecorder.event(all ? "tuned" : "lock", ["string": number])
            if !all { try? await Task.sleep(for: .seconds(nextGap)) }
        }
        // The full-tune strum takes over from the strings.
        PreviewRecorder.shared.endStrings(store)
    }

    private static func cued(since launched: Date) -> Bool {
        let waited = Date().timeIntervalSince(launched)
        guard let path = Option.cue else { return waited > fallbackStart }
        return FileManager.default.fileExists(atPath: path) || waited > 90
    }

    private typealias Option = DemoScene.Option
}

// MARK: - The App Preview's soundtrack

/// What the app plays, written down as it plays (`TIMBRE_PREVIEW_AUDIO=<folder>`, debug builds only), so
/// tools/marketing/preview.py lays the App Preview's soundtrack from the app's own sound: the lock bells, the full-tune
/// strum, the lesson cues, the band and the click, each at the moment it sounded. Nothing is synthesized by the tool.
///
/// - `events.jsonl`, one JSON object a line, every time in seconds since 1970 (the simulator shares the host's clock):
///   `launch` (scene), `cue` (a sound effect starting: its file, volume and player), `stream` (another file in the
///   engine file's format), `note` (something the preview can't do) and `event` (a scene's moments: a lock, the full
///   tune, a take's beat clock, `band` when the band starts or stops and what the route reads as, `sound` when the
///   engine is heard after a pause, `motif` when the end card's motif plays).
/// - `cue-<fingerprint>.wav`: each sound effect once, exactly the bytes `AVAudioPlayer` was given.
/// - `engine-<launch>.pcm`: what the lessons' engine rendered (tones, the click, the band), mono 16-bit, as records of
///   a little-endian header (Float64 start, UInt32 frames, UInt32 sample rate) and the samples; silence is left out.
/// - `string-<launch>.pcm`: the strings the tuner was given in `preview-tune`, as `PreviewString` voices them.
///
/// Sound effects are noted by swapping `AVAudioPlayer.play` for a version that notes, then plays. The engine is reached
/// through `Mirror` (its `engine` property is private) and tapped at its main mixer. The full band (harmony and bass as
/// well as the kit) plays only on headphones, so the preview's route reads as headphones
/// (`AVAudioSessionPortDescription.portType` swapped for the speaker): the soundtrack is the band as a player hears it in
/// headphones, and the `band` events say whether it really played while each clip was filmed. With
/// `TIMBRE_PREVIEW_MOTIF=<file>` the app plays its motif once that file exists, for the end card. The folder falls back
/// to Caches/preview-audio when the asked one can't be written.
final class PreviewRecorder: @unchecked Sendable {
    static let shared = PreviewRecorder()

    /// Where everything goes; nil when the preview isn't recording (the usual case).
    let folder: URL?
    private let queue = DispatchQueue(label: "timbre.preview-recorder")
    private let launch = String(Int(Date().timeIntervalSince1970 * 1000))
    // The queue's own state.
    private var log: FileHandle?
    private var pcm: FileHandle?
    private var saved: Set<String> = []
    private var fingerprints: [String: (count: Int, key: String)] = [:]
    // The tap's own state: when the engine was last heard.
    private var lastHeard = 0.0
    // The main actor's own state.
    @MainActor private weak var audio: AudioService?
    @MainActor private var tappedEngine: ObjectIdentifier?
    @MainActor private var tappedRate = 0.0
    @MainActor private var engineWasRunning = false
    /// The band and the route as last noted (`noteBand`), so each change is noted once.
    @MainActor private var bandSeen: Bool?
    @MainActor private var headphonesSeen: Bool?
    /// While `followStrings` runs: every reading the tuner was given, and the receiver it had before.
    @MainActor private var readings: [PreviewString.Reading]?
    @MainActor private var forwarded: ((Double?, Double, Double) -> Void)?

    private init() {
        let asked = TestSupport.value(.previewAudio) ?? ""
        folder = asked.isEmpty ? nil : PreviewRecorder.usableFolder(asked)
    }

    var enabled: Bool { folder != nil }

    /// The asked folder ("1": the app's own Caches/preview-audio), or that fallback when it can't be written.
    private static func usableFolder(_ asked: String) -> URL? {
        let files = FileManager.default
        var candidates: [URL] = []
        if asked != "1" { candidates.append(URL(fileURLWithPath: asked, isDirectory: true)) }
        if let caches = files.urls(for: .cachesDirectory, in: .userDomainMask).first {
            candidates.append(caches.appendingPathComponent("preview-audio", isDirectory: true))
        }
        for url in candidates {
            do {
                try files.createDirectory(at: url, withIntermediateDirectories: true)
                let probe = url.appendingPathComponent(".write-test")
                try Data().write(to: probe)
                try? files.removeItem(at: probe)
                return url
            } catch {
                continue
            }
        }
        return nil
    }

    /// Opens the log, swaps in the noting `play`, makes the route read as headphones and starts watching the engine.
    @MainActor static func startIfAsked(_ store: AppStore) {
        let recorder = shared
        guard let folder = recorder.folder else { return }
        recorder.queue.sync {
            recorder.log = PreviewRecorder.appending(folder.appendingPathComponent("events.jsonl"))
            recorder.pcm = PreviewRecorder.appending(folder.appendingPathComponent("engine-\(recorder.launch).pcm"))
        }
        recorder.write(["kind": "launch", "t": Date().timeIntervalSince1970, "scene": DemoScene.current?.rawValue ?? "none",
                        "engine": "engine-\(recorder.launch).pcm"])
        PreviewSwaps.install()
        recorder.audio = store.audio
        store.audio.refreshRoute()
        if !store.audio.headphones {
            recorder.write(["kind": "note", "t": Date().timeIntervalSince1970, "text": "the route doesn't read as headphones: no band"])
        }
        recorder.watchEngine()
        recorder.playMotifWhenAsked()
    }

    // MARK: The end card's motif

    /// `TIMBRE_PREVIEW_MOTIF=<file>`: once that file exists, the app's motif plays (the sound of welcome and of Pro
    /// unlocked) and is noted, so the end card carries the app's own signature rather than silence.
    @MainActor private func playMotifWhenAsked() {
        guard let path = TestSupport.value(.previewMotif), !path.isEmpty else { return }
        Task { @MainActor in
            for _ in 0..<6000 {
                if FileManager.default.fileExists(atPath: path) {
                    SoundFX.shared.play(.motif)
                    PreviewRecorder.event("motif")
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: The strings, heard

    /// From now until `endStrings`, every reading the tuner is given (in `preview-tune`, the demo pitch: a string
    /// drifting into tune, then each string held in tune) is kept on its way to the tuner, so the preview can hear the
    /// string it stands for.
    @MainActor func followStrings(_ store: AppStore) {
        guard enabled, readings == nil else { return }
        readings = []
        let forward = store.audio.onReading
        forwarded = forward
        store.audio.onReading = { [weak self] hz, confidence, level in
            self?.keep(hz)
            forward?(hz, confidence, level)
        }
    }

    @MainActor private func keep(_ hz: Double?) {
        readings?.append(PreviewString.Reading(time: Date().timeIntervalSince1970, hz: hz))
    }

    /// Ends `followStrings`: the tuner gets its readings directly again, and the strings are written as a stream of
    /// their own (`string-<launch>.pcm`, the engine file's format), voiced off the main thread. A `strings` event says
    /// the file is complete, so the test waits for it before it ends this launch.
    @MainActor func endStrings(_ store: AppStore) {
        guard let taken = readings, let folder else { return }
        readings = nil
        store.audio.onReading = forwarded
        forwarded = nil
        let voice = InstrumentVoice(instrument: store.instrument)
        let name = "string-\(launch).pcm"
        queue.async {
            let data = PreviewString.records(taken, voice: voice)
            try? data.write(to: folder.appendingPathComponent(name))
            let now = Date().timeIntervalSince1970
            self.logNow(["kind": "stream", "t": now, "file": name, "what": "the demo string"])
            self.logNow(["kind": "event", "name": "strings", "t": now, "bytes": data.count])
        }
    }

    /// One line of the log, written at once: only from the queue.
    private func logNow(_ fields: [String: Any]) {
        guard var line = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return }
        line.append(0x0A)
        try? log?.write(contentsOf: line)
    }

    // MARK: The band

    /// Notes the band starting or stopping, and the route's headphones changing (a `band` event), so the preview can
    /// tell a clip filmed with the band playing from one filmed without it.
    @MainActor private func noteBand() {
        guard let audio else { return }
        let playing = audio.bandPlaying
        let headphones = audio.headphones
        guard playing != bandSeen || headphones != headphonesSeen else { return }
        bandSeen = playing
        headphonesSeen = headphones
        PreviewRecorder.event("band", ["playing": playing, "headphones": headphones])
    }

    private static func appending(_ url: URL) -> FileHandle? {
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: url) else { return nil }
        _ = try? handle.seekToEnd()
        return handle
    }

    /// One line of the log (serialized here, written on the queue).
    func write(_ fields: [String: Any]) {
        guard enabled, var line = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return }
        line.append(0x0A)
        let payload = line
        queue.async { try? self.log?.write(contentsOf: payload) }
    }

    /// A scene's moment ("lock", "tuned", "take"…), now.
    static func event(_ name: String, _ extra: [String: Any] = [:]) {
        guard shared.enabled else { return }
        var fields = extra
        fields["kind"] = "event"
        fields["name"] = name
        fields["t"] = Date().timeIntervalSince1970
        shared.write(fields)
    }

    // MARK: Sound effects

    /// A sound effect starting (the swapped-in `AVAudioPlayer.play`): its sound saved once, and a line with when it
    /// started, how loud, and which player (a player restarted cuts its last sound short).
    func noteCue(_ player: AVAudioPlayer) {
        guard enabled, let folder, let data = player.data else { return }
        let now = Date().timeIntervalSince1970
        let volume = Double(player.volume)
        let id = "\(ObjectIdentifier(player).hashValue)"
        queue.async {
            let key: String
            if let known = self.fingerprints[id], known.count == data.count {
                key = known.key
            } else {
                key = PreviewRecorder.fingerprint(data)
                self.fingerprints[id] = (data.count, key)
            }
            let name = "cue-\(key).wav"
            if !self.saved.contains(name) {
                try? data.write(to: folder.appendingPathComponent(name))
                self.saved.insert(name)
            }
            let fields: [String: Any] = ["kind": "cue", "t": now, "file": name, "volume": volume, "player": id]
            guard var line = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else { return }
            line.append(0x0A)
            try? self.log?.write(contentsOf: line)
        }
    }

    /// FNV-1a over the sound's bytes: the same sound always gets the same file.
    private static func fingerprint(_ data: Data) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        data.withUnsafeBytes { raw in
            for byte in raw {
                hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
            }
        }
        return String(hash, radix: 16)
    }

    // MARK: The engine

    /// Five times a second: taps the lessons' engine when it is new, or has just started (its format settled then), and
    /// notes the band's changes.
    @MainActor private func watchEngine() {
        Task { @MainActor in
            while true {
                self.noteBand()
                self.checkEngine()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    @MainActor private func checkEngine() {
        guard let audio, let engine = PreviewRecorder.engine(of: audio) else { return }
        let id = ObjectIdentifier(engine)
        let running = engine.isRunning
        if running {
            let rate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
            if id != tappedEngine || !engineWasRunning || rate != tappedRate {
                tap(engine)
                tappedEngine = id
                tappedRate = rate
            }
        }
        engineWasRunning = running
    }

    /// AudioService's engine, read through `Mirror` (the property is private); nil if it is ever renamed.
    private static func engine(of audio: AudioService) -> AVAudioEngine? {
        for child in Mirror(reflecting: audio).children where child.label == "engine" || child.label == "_engine" {
            if let engine = child.value as? AVAudioEngine { return engine }
        }
        return nil
    }

    /// A tap on the main mixer's output, in the bus's own format (a connected bus takes no other).
    @MainActor private func tap(_ engine: AVAudioEngine) {
        let mixer = engine.mainMixerNode
        mixer.removeTap(onBus: 0)
        let format = mixer.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0, !format.isInterleaved else { return }
        let rate = format.sampleRate
        mixer.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, when in
            self?.engineBuffer(buffer, when: when, rate: rate)
        }
    }

    /// A rendered buffer, folded to mono 16-bit and dated by its host time (the tap runs off the render thread).
    private func engineBuffer(_ buffer: AVAudioPCMBuffer, when: AVAudioTime, rate: Double) {
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frames > 0, channels > 0, rate > 0, let data = buffer.floatChannelData else { return }
        var mono = [Int16](repeating: 0, count: frames)
        var peak: Float = 0
        for index in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels { sum += data[channel][index] }
            let value = max(-1, min(1, sum / Float(channels)))
            peak = max(peak, abs(value))
            mono[index] = Int16(value * 32_767)
        }
        guard peak > 0.0005 else { return }
        let now = Date().timeIntervalSince1970
        // Heard again after a pause (a song's preview starting, a take's first click): a moment the test can cut on.
        if now - lastHeard > 0.3 { PreviewRecorder.event("sound") }
        lastHeard = now
        var start = now - Double(frames) / rate
        if when.isHostTimeValid {
            let age = AVAudioTime.seconds(forHostTime: mach_absolute_time()) - AVAudioTime.seconds(forHostTime: when.hostTime)
            if age > -1 && age < 5 { start = now - age }
        }
        var record = Data(capacity: 16 + frames * 2)
        withUnsafeBytes(of: start.bitPattern.littleEndian) { record.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(frames).littleEndian) { record.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(rate.rounded()).littleEndian) { record.append(contentsOf: $0) }
        mono.withUnsafeBytes { record.append(contentsOf: $0) }
        let payload = record
        queue.async { try? self.pcm?.write(contentsOf: payload) }
    }

    // MARK: A take's beat clock

    /// `song-perform` is about to start its take: the moment, and (once the click runs) the wall-clock time of the
    /// take's first click, so the preview can cut on the song's own downbeats.
    static func takeScheduled(_ lesson: Lesson, firstBeat: Double, meter: Int) {
        guard shared.enabled else { return }
        var bpm = 0.0
        var end = 0.0
        for step in lesson.steps {
            if case let .playAlong(notes, tempo, _, _) = step {
                bpm = tempo
                end = notes.map { $0.beat + $0.beats }.max() ?? 0
            }
        }
        let delay = Double(DemoScene.performDelay.components.seconds)
        event("take-scheduled", ["delay": delay, "firstBeat": firstBeat, "meter": meter, "bpm": bpm, "endBeat": end])
        Task { @MainActor in await shared.noteTakeClock(firstBeat: firstBeat, meter: meter, bpm: bpm, end: end) }
    }

    @MainActor private func noteTakeClock(firstBeat: Double, meter: Int, bpm: Double, end: Double) async {
        let scheduled = Date()
        for _ in 0..<600 {
            if let audio, audio.metronomeRunning, Date().timeIntervalSince(scheduled) > 0.5, let origin = audio.metronomeOrigin() {
                let wall = Date().timeIntervalSince1970 - (CACurrentMediaTime() - origin)
                PreviewRecorder.event("take", ["origin": wall, "firstBeat": firstBeat, "meter": meter, "bpm": bpm, "endBeat": end])
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

/// The strings the tuner was given in `preview-tune`, as the preview hears them: the instrument's own reference voice (the
/// tuner's "play the note" sound, from its recordings where the app has them), read faster or slower sample by sample so
/// its pitch follows each reading. The first string drifts into tune with the readout, re-plucked as a player would;
/// each later string rings while it is held in tune. Peaks at -12 dBFS, under the lock bells.
enum PreviewString {
    struct Reading: Sendable {
        let time: Double
        let hz: Double?
    }

    /// The loudest sample of a string (-12 dBFS).
    static let peak: Float = 0.25
    static let rate = 44_100
    /// How long a string rings on after its last reading, fading out.
    static let ring = 0.3

    private struct Point {
        let time: Double
        let hz: Double
    }

    /// One string's stretch: consecutive readings within a semitone of each other, none more than 0.15 s apart.
    private struct Stretch {
        var points: [Point]
        var start: Double { points.first?.time ?? 0 }
        var end: Double { points.last?.time ?? 0 }
    }

    /// The stretches as records of the engine file's format: Float64 start, UInt32 frames, UInt32 sample rate, then
    /// the samples, mono 16-bit, little-endian.
    static func records(_ readings: [Reading], voice: InstrumentVoice) -> Data {
        var data = Data()
        for stretch in stretches(readings) {
            let samples = render(stretch, voice: voice)
            guard !samples.isEmpty else { continue }
            withUnsafeBytes(of: stretch.start.bitPattern.littleEndian) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt32(samples.count).littleEndian) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt32(rate).littleEndian) { data.append(contentsOf: $0) }
            samples.withUnsafeBytes { data.append(contentsOf: $0) }
        }
        return data
    }

    private static func stretches(_ readings: [Reading]) -> [Stretch] {
        var found: [Stretch] = []
        for reading in readings {
            guard let hz = reading.hz, hz > 20 else { continue }
            let point = Point(time: reading.time, hz: hz)
            if let last = found.last?.points.last, reading.time - last.time <= 0.15, abs(log2(hz / last.hz)) < 1.0 / 12 {
                found[found.count - 1].points.append(point)
            } else {
                found.append(Stretch(points: [point]))
            }
        }
        return found.filter { $0.end - $0.start >= 0.25 }
    }

    /// The reference voice at the stretch's settled pitch (its median reading), its read position stepped by each
    /// moment's pitch over that one; a 5 ms fade in and `ring` out.
    private static func render(_ stretch: Stretch, voice: InstrumentVoice) -> [Int16] {
        let points = stretch.points
        let pitches = points.map { $0.hz }.sorted()
        guard !pitches.isEmpty else { return [] }
        let settled = pitches[pitches.count / 2]
        let seconds = stretch.end - stretch.start + ring
        // A little longer than the stretch: a sharp moment reads ahead of the clock.
        let milliseconds = min(8000, Int((seconds + 0.3) * 1000))
        let request = ToneRequest(frequencies: [settled], kind: .reference(durationMs: milliseconds), voice: voice, sampleRate: rate)
        let source = ToneSynth.render(request, samples: SampleLibrary.shared).frames
        let count = Int(seconds * Double(rate))
        guard source.count > 2, count > 0 else { return [] }
        var out = [Float](repeating: 0, count: count)
        var position = 0.0
        var index = 0
        for n in 0..<count {
            let time = stretch.start + Double(n) / Double(rate)
            while index + 1 < points.count && points[index + 1].time <= time { index += 1 }
            let hz = pitch(points, index, at: time)
            let whole = Int(position)
            guard whole + 1 < source.count else { break }
            let fraction = Float(position - Double(whole))
            out[n] = source[whole] * (1 - fraction) + source[whole + 1] * fraction
            position += hz / settled
        }
        return finished(out)
    }

    /// The pitch at `time`, between reading `index` and the next.
    private static func pitch(_ points: [Point], _ index: Int, at time: Double) -> Double {
        let here = points[index]
        guard index + 1 < points.count else { return here.hz }
        let next = points[index + 1]
        let span = max(0.000_001, next.time - here.time)
        let weight = min(1, max(0, (time - here.time) / span))
        return here.hz + (next.hz - here.hz) * weight
    }

    /// Faded in and out, at `peak`, as 16-bit samples.
    private static func finished(_ samples: [Float]) -> [Int16] {
        var out = samples
        let count = out.count
        let fadeIn = min(count, Int(0.005 * Double(rate)))
        let fadeOut = min(count, Int(ring * Double(rate)))
        for n in 0..<fadeIn { out[n] *= Float(n) / Float(max(1, fadeIn)) }
        for k in 0..<fadeOut { out[count - 1 - k] *= Float(k) / Float(max(1, fadeOut)) }
        let loudest = out.reduce(Float(0)) { max($0, abs($1)) }
        guard loudest > 0 else { return [] }
        let scale = peak / loudest * 32_767
        return out.map { value in Int16(max(-32_767, min(32_767, value * scale))) }
    }
}

/// The method swaps behind `PreviewRecorder`, made once per launch and only while the preview records.
enum PreviewSwaps {
    nonisolated(unsafe) private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        exchange(AVAudioPlayer.self, "play", #selector(AVAudioPlayer.timbrePreviewPlay))
        exchange(AVAudioSessionPortDescription.self, "portType", #selector(AVAudioSessionPortDescription.timbrePreviewPortType))
    }

    private static func exchange(_ type: AnyClass, _ name: String, _ replacement: Selector) {
        guard let original = class_getInstanceMethod(type, NSSelectorFromString(name)),
              let swapped = class_getInstanceMethod(type, replacement) else { return }
        method_exchangeImplementations(original, swapped)
    }
}

extension AVAudioPlayer {
    /// Takes `play`'s place while the App Preview records (`PreviewSwaps`): notes the sound, then plays it. After the
    /// swap, the call to itself runs the original `play`.
    @objc dynamic func timbrePreviewPlay() -> Bool {
        PreviewRecorder.shared.noteCue(self)
        return timbrePreviewPlay()
    }
}

extension AVAudioSessionPortDescription {
    /// Takes `portType`'s place while the App Preview records: the built-in speaker reads as headphones, so the lesson
    /// band plays (it never plays where it would reach the microphone). After the swap, the call to itself is the original.
    @objc dynamic func timbrePreviewPortType() -> NSString {
        let real = timbrePreviewPortType()
        let speakers = [AVAudioSession.Port.builtInSpeaker.rawValue, AVAudioSession.Port.builtInReceiver.rawValue]
        return speakers.contains(real as String) ? AVAudioSession.Port.headphones.rawValue as NSString : real
    }
}

// MARK: - Show me

/// For XCUITest only (TIMBRE_DEBUG_STATE=1), over every "Show me" stage (`ShowMeStage`): whether the model is on the
/// card, since when the renderer has drawn it there, and when the demonstration's last fingertip lands, so
/// `test15StoreShowMe` keeps its picture only when it was taken with the 3D model showing (the card's picture gone),
/// drawn for longer than the cross-fade, every fingertip down and the chord ringing. Reads
/// "showme=<3d|picture|loading> landed=<epoch s, 0 before a demonstration> ringing=<strings lit> live=<epoch s of the
/// first frame drawn with the model on the card, 0 before> frames=<frames drawn since> now=<the app's clock>
/// diag=<model, load state, host state, frames, framing, cache>". "3d" needs the stage ready *and* the host showing it
/// (the state that takes the picture away), "picture" is a ready stage the host hasn't shown, "loading" the rest; the
/// free-text `diag` comes last, for the test's log. Re-read five times a second (the controller's counters change
/// without SwiftUI hearing of it). Drawn in clear ink and never touched, like the tuner's `stage.state`, so it stays
/// out of every screenshot.
struct ShowMeProbe: View {
    let modelID: String
    let shown: Bool
    let ready: Bool
    let revealed: Bool
    let attached: Bool
    let controller: ShowMeController
    let shot: ShowMeShot
    let landStart: Date?
    let landingStep: Double
    let ringing: Int

    private static let enabled = TestSupport.isOn(.debugState)

    @ViewBuilder var body: some View {
        if Self.enabled {
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                Text(verbatim: label(at: context.date))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.clear)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("showme.state")
            }
        }
    }

    private func label(at now: Date) -> String {
        let stage = shown ? "3d" : (ready ? "picture" : "loading")
        let live = controller.liveSince?.timeIntervalSince1970 ?? 0
        let head = "showme=\(stage) landed=\(Self.seconds(landed)) ringing=\(ringing) live=\(Self.seconds(live)) "
            + "frames=\(controller.shownFrames) now=\(Self.seconds(now.timeIntervalSince1970))"
        let host = "model=\(modelID) ready=\(ready ? 1 : 0) revealed=\(revealed ? 1 : 0) attached=\(attached ? 1 : 0)"
        return head + " diag=" + host + " " + controller.diagnostics + " cache=\(ModelCache.shared.describe(modelID))"
    }

    private static func seconds(_ value: Double) -> String { String(format: "%.3f", value) }

    /// When the last fingertip lands, in seconds since 1970 (0: no demonstration under way).
    private var landed: Double {
        guard let landStart else { return 0 }
        var fingers = 1
        if case let .fretting(shape) = shot { fingers = max(1, shape.landingCount) }
        return landStart.addingTimeInterval(Double(fingers - 1) * landingStep).timeIntervalSince1970
    }
}

/// For XCUITest only (TIMBRE_DEBUG_STATE=1), on a lesson card whose picture can play in 3D (LessonExplain): the card's
/// own side of "Show me", the state that swaps its picture for the model, so a test that finds no stage (or a stage the
/// card never showed) can say why. Reads "card showMe=<0|1> ready=<0|1> threeD=<0|1> failed=<0|1> first=<0|1>
/// model=<id|none> problem=<why the last stage gave up, or none>". Drawn in clear ink and never touched.
struct ShowMeHostProbe: View {
    let showMe: Bool
    let ready: Bool
    let threeD: Bool
    let failed: Bool
    let first: Bool
    let model: String?

    private static let enabled = TestSupport.isOn(.debugState)

    @ViewBuilder var body: some View {
        if Self.enabled {
            Text(verbatim: "card showMe=\(flag(showMe)) ready=\(flag(ready)) threeD=\(flag(threeD)) failed=\(flag(failed)) "
                 + "first=\(flag(first)) model=\(model ?? "none") problem=\(ShowMe.lastProblem ?? "none")")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.clear)
                .allowsHitTesting(false)
                .accessibilityIdentifier("showme.host")
        }
    }

    private func flag(_ value: Bool) -> String { value ? "1" : "0" }
}
#endif
