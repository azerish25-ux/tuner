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
/// `stillScore`, `ShowMeStage` carries `ShowMeProbe` and the explanation's card `ShowMeHostProbe`. Stage code may read
/// `marketingScale` (inside `#if DEBUG`) to exaggerate motion for the camera.
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
///   Strings are chosen the way automatic detection chooses them, so AUTO stays AUTO on screen.
/// - `show-me` (frame #3's alternative, the App Preview): the same lesson opens on its first step, E minor explained on
///   its card. It is the chord's first appearance in the course, so the 3D model takes the card by itself once it has
///   settled and the demonstration plays there: the fingertips land in finger order, then the chord rings across every
///   string. (The test asks with "Show me" when the model doesn't come by itself, and again for each replay it needs.)
/// - `lesson-chord` (frame #3): the first guitar lesson with a chord ("Your first chord: E minor") opens on its chord
///   step with the day's tune check done. The demo pitch plays the chord string by string, every string lights, and
///   the step stays on "Every string rings" instead of moving on.
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
    case songPerform = "song-perform"
    case showMe = "show-me"
    case previewTune = "preview-tune"
    case instrumentWall = "instrument-wall"

    static let current: DemoScene? = ProcessInfo.processInfo.environment["TIMBRE_SCENE"].flatMap(DemoScene.init(rawValue:))

    /// What the UI test asked for besides the scene, all optional.
    enum Option {
        private static let environment = ProcessInfo.processInfo.environment
        /// The instrument the tuner opens on (a catalog id such as "violin.standard.4").
        static let instrument = environment["TIMBRE_SCENE_INSTRUMENT"].flatMap { $0.isEmpty ? nil : $0 }
        /// `song-perform`: the song (a lesson id) and the bar its take starts at.
        static let song = environment["TIMBRE_SCENE_SONG"].flatMap { $0.isEmpty ? nil : $0 }
        static let bar = environment["TIMBRE_SCENE_BAR"].flatMap { Int($0) }
        /// `tune-locked`: pluck the held string again every `cometPeriod`, so its lock shimmer runs again.
        static let comet = environment["TIMBRE_SCENE_COMET"] == "1"
        /// `preview-tune`: a file the UI test creates once the 3D stage is up; the scene starts then.
        static let cue = environment["TIMBRE_SCENE_CUE"].flatMap { $0.isEmpty ? nil : $0 }
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
        case .lessonChord?, .showMe?:
            // Learn opens it out of its Continue card, as it opens onboarding's first lesson.
            guard let lesson = DemoScene.chordLesson(store) else { return }
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

    /// The run `LessonPlayer` opens `lesson` with: in `lesson-chord`, at its first chord step; in `show-me`, at the step
    /// that explains that chord on its card; in `song-perform`, at the song's last step, its performance (nil otherwise).
    static func lessonStart(_ lesson: Lesson) -> LessonRun? {
        let start: Int?
        switch current {
        case .lessonChord?: start = lesson.steps.firstIndex(where: DemoScene.isChord)
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

    /// In `song-perform` the take's score changes in place rather than rolling its digits: it changes with every note,
    /// several times a second, so a rolling score is mid-roll in almost any picture.
    static var stillScore: Bool { current == .songPerform }

    /// Learn opens the song (as a Siri or Spotlight link opens one), then goes back to the player's own course once
    /// the song is on screen, so later runs in the same simulator still open Learn on guitar.
    @MainActor private static func openSong(_ store: AppStore) {
        guard let found = store.curriculum.lesson(id: performSongId) else { return }
        let own = UserDefaults.standard.string(forKey: "learn.course") ?? "guitar"
        store.pendingLessonId = found.lesson.id
        store.selectedTab = .learn
        guard own != found.course.id else { return }
        Task { @MainActor in
            for _ in 0..<50 where store.pendingLessonId != nil { try? await Task.sleep(for: .milliseconds(100)) }
            // Past Learn's own wait for covering screens, so the switch happens behind the open song.
            try? await Task.sleep(for: .milliseconds(2500))
            guard UserDefaults.standard.string(forKey: "learn.course") == found.course.id else { return }
            UserDefaults.standard.set(own, forKey: "learn.course")
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
    /// thread, and a gap of more than 150 ms in the readings starts the hold again).
    @MainActor fileprivate static func lock(_ course: Course, _ store: AppStore) async {
        select(course, store)
        for _ in 0..<2400 where !store.lockedCourses.contains(course.index) {
            try? await Task.sleep(for: .milliseconds(25))
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
        await DemoScene.lock(first, store)
        PreviewRecorder.event("lock", ["string": 0])
        try? await Task.sleep(for: .seconds(firstHold))
        steady = true
        for (number, course) in courses.enumerated().dropFirst() {
            await DemoScene.lock(course, store)
            let all = store.allCoursesLocked
            PreviewRecorder.event(all ? "tuned" : "lock", ["string": number])
            if !all { try? await Task.sleep(for: .seconds(nextGap)) }
        }
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
///   `launch` (scene), `cue` (a sound effect starting: its file, volume and player), `event` (a scene's moments: a
///   lock, the full tune, a take's beat clock).
/// - `cue-<fingerprint>.wav`: each sound effect once, exactly the bytes `AVAudioPlayer` was given.
/// - `engine-<launch>.pcm`: what the lessons' engine rendered (tones, the click, the band), mono 16-bit, as records of
///   a little-endian header (Float64 start, UInt32 frames, UInt32 sample rate) and the samples; silence is left out.
///
/// Sound effects are noted by swapping `AVAudioPlayer.play` for a version that notes, then plays. The engine is reached
/// through `Mirror` (its `engine` property is private) and tapped at its main mixer. The band plays only on headphones,
/// so the preview's route reads as headphones (`AVAudioSessionPortDescription.portType` swapped for the speaker): the
/// soundtrack is the band as a player hears it in headphones. The folder falls back to Caches/preview-audio when the
/// asked one can't be written.
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
    // The main actor's own state.
    @MainActor private weak var audio: AudioService?
    @MainActor private var tappedEngine: ObjectIdentifier?
    @MainActor private var tappedRate = 0.0
    @MainActor private var engineWasRunning = false

    private init() {
        let asked = ProcessInfo.processInfo.environment["TIMBRE_PREVIEW_AUDIO"] ?? ""
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
        queue.async { try? self.log?.write(contentsOf: line) }
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

    /// Five times a second: taps the lessons' engine when it is new, or has just started (its format settled then).
    @MainActor private func watchEngine() {
        Task { @MainActor in
            while true {
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
        queue.async { try? self.pcm?.write(contentsOf: record) }
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

    private static let enabled = ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1"

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

    private static let enabled = ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1"

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
