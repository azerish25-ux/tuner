import XCTest

/// The App Store App Previews (6.9-inch iPhone, portrait). .github/workflows/preview.yml records the simulator screen
/// while one of these tours plays with the demo pitch on; the main iOS workflow skips them.
///
/// - `testAppPreview`, the main preview: a string drifts into tune on the 3D headstock, heard as it comes in, and locks
///   with its bell; the clip holds the lock 1.2 s (the poster: ✓ In tune, the peg's tick, the comet); the other strings
///   lock, chosen the way automatic detection chooses them (AUTO stays AUTO), and the full-tune celebration plays out;
///   "Show me" fingers E minor on the 3D guitar; Kite Weather's chorus on the highway at ×4 with the band, from the
///   store frame's clean take, cut on the song's own downbeats; the song's stars ringing as they land; the Songs tab
///   with the song of the day's preview playing, under 3 s. preview.py adds the end card, the app's motif under it.
/// - `testAppPreviewViolin`, the violin page's preview (a Custom Product Page): the same tuner moment on the 3D violin,
///   then Jingle Bells from the violin songbook on the runway with the band, its stars, and Songs.
///
/// Every scene is a fresh launch into a store scene (TIMBRE_SCENE, ios/Timbre/Root/DemoScenes.swift), so each moment
/// comes from the app's own code paths, in the same state on every run. Each scene marks only the stretch worth showing:
/// `PREVIEW-CLIP <name> <start> <end> <head|tail> [<shortest>] [anchor=<sync>]` in wall-clock seconds, printed to the log
/// and attached to the result; tools/marketing/preview.py cuts those stretches out of the recording and joins them with
/// hard cuts, so launches, taps and waits stay off camera. `PREVIEW-BEAT <downbeat> <seconds a beat> <beats a bar>` gives
/// the band's clock, which the cut lands on; `PREVIEW-POSTER <time>` the poster frame; `PREVIEW-REGION readout …` where
/// the tuner's badge shows; `PREVIEW-CARD <start> <end>` the app's sound for the end card; `PREVIEW-CHECK` what this test
/// checked (a fail stops the cut); `PREVIEW-MISSED` a moment that didn't come; `PREVIEW-CUT <name>` which preview.
///
/// The app writes down what it plays and when (`PreviewRecorder`: the strings, the bells, the strum, the band, the
/// motif) and its scenes' moments (a lock, the full tune, a take's beat clock, the band starting) to a folder it shares
/// with this test (TIMBRE_PREVIEW_AUDIO). The test cuts on those moments when they are there, and on the demo pitch's
/// known clock when they aren't; preview.py lays the soundtrack from the same folder.
///
/// `PREVIEW-SYNC` screenshots (attached as `sync-<label>`) let the cut find each moment in the recording by its picture
/// rather than by the clock, and prove the recording really shows the app there. The lock's is taken the moment the app
/// notes its lock (the test reads the shared file every 10 ms), while the badge, the halo and the comet change the
/// screen, and the lock clip is placed by it alone; preview.py then checks the lock's bell against the badge's first
/// frame. While a string is due to lock or a note is due, the test keeps its hands off: every query holds the app's main
/// thread, and a gap of more than 150 ms in the readings restarts the 0.65 s hold a lock needs (or makes a note late).
/// Screenshots and reading the shared folder don't touch the app.
final class AppPreviewUITests: XCTestCase {
    /// Which end of a clip matters when the cut has to shorten it.
    private enum Keep: String { case head, tail }

    /// One preview: the instrument the tuner opens on, and what it plays after.
    private struct Cut {
        let name: String
        /// A catalog id for the tuner's instrument (nil: the player's own, the acoustic guitar).
        let instrument: String?
        /// The lesson performed, and whether it is a song performance (`song-perform` starts its take by itself at
        /// `bar`) or a lesson play-along the test starts.
        let lesson: String
        let performs: Bool
        let bar: Int
        /// The clip runs `hookBars` bars from the downbeat of `hookBar` (0-based bars, as the arrangement counts them).
        let hookBar: Int
        let hookBars: Int
        let showMe: Bool
        /// The song's tempo and last beat, for when the app's own note of the take's clock is missing.
        let bpm: Double
        let endBeat: Double

        /// Kite Weather from bar 15, the take store frame #2 is caught from (68 notes before it played clean, so the
        /// run is long past ×4): the first chorus's "let it climb, let it go", then the hook ("It's kite weather, kite
        /// weather", bars 16–17) at ×4 with the band.
        static let guitar = Cut(name: "guitar", instrument: nil, lesson: "orig-kite-weather", performs: true, bar: 15,
                                hookBar: 16, hookBars: 2, showMe: true, bpm: 88, endBeat: 224)
        /// Jingle Bells from the violin songbook (free): its last chorus ("Jingle bells, jingle bells", bars 42–43) and
        /// the song's end ten bars later.
        static let violin = Cut(name: "violin", instrument: "violin.standard.4", lesson: "vln-sb-song-jingle-bells", performs: true,
                                bar: 41, hookBar: 42, hookBars: 2, showMe: false, bpm: 80, endBeat: 208)
    }

    private var app: XCUIApplication!
    private var marks: [String] = []
    /// The folder the app writes its sounds and moments to, shared with this test.
    private var exchange: URL!

    override func setUpWithError() throws {
        continueAfterFailure = true  // a missed beat shortens the cut; the tour keeps filming
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        exchange = Self.exchangeFolder()
        try? FileManager.default.createDirectory(at: exchange, withIntermediateDirectories: true)
        mark("PREVIEW-BEGIN \(stamp(Date()))")
        mark("PREVIEW-APP \(exchange.path)")
        waitForRecorder()
    }

    /// preview.yml's shared folder (`app` inside it, which preview.py reads), else one in the test runner's temporary
    /// folder (the simulator's apps share the host's file system).
    private static func exchangeFolder() -> URL {
        if let folder = ProcessInfo.processInfo.environment["PREVIEW_HANDSHAKE"], !folder.isEmpty {
            return URL(fileURLWithPath: folder, isDirectory: true).appendingPathComponent("app", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("timbre-preview-\(UUID().uuidString)", isDirectory: true)
    }

    /// preview.yml starts the screen recording only when the tour begins (minutes of home screen while the runner
    /// installs only add load and length). It passes a shared folder as TEST_RUNNER_PREVIEW_HANDSHAKE: the test drops
    /// `begin` there and waits for `recording`. Without the folder (a local run) it goes on at once.
    private func waitForRecorder() {
        guard let folder = ProcessInfo.processInfo.environment["PREVIEW_HANDSHAKE"], !folder.isEmpty else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        let recording = directory.appendingPathComponent("recording").path
        do {
            try Data().write(to: directory.appendingPathComponent("begin"))
        } catch {
            // The host also watches the log for PREVIEW-BEGIN: give it time to start the recorder that way.
            missed("handshake folder not writable: \(error.localizedDescription)")
            pause(12)
            return
        }
        let deadline = Date().addingTimeInterval(90)
        while !FileManager.default.fileExists(atPath: recording) && Date() < deadline { pause(0.25) }
        if !FileManager.default.fileExists(atPath: recording) { missed("the recorder never said it started") }
        pause(1)
    }

    override func tearDownWithError() throws {
        let passed = (testRun?.totalFailureCount ?? 0) == 0
        mark("PREVIEW-END \(passed ? "passed" : "failed")")
        let note = XCTAttachment(string: marks.joined(separator: "\n"))
        note.name = "preview-clips"
        note.lifetime = .keepAlways
        add(note)
        if !passed {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "preview-failure"
            shot.lifetime = .keepAlways
            add(shot)
        }
        app.terminate()
    }

    func testAppPreview() throws { tour(.guitar) }

    func testAppPreviewViolin() throws { tour(.violin) }

    private func tour(_ cut: Cut) {
        mark("PREVIEW-CUT \(cut.name)")
        tuneScene(cut)
        if cut.showMe { showMeScene() }
        if cut.performs { performScene(cut) } else { playAlongScene(cut) }
        songsScene()
    }

    // MARK: Launching a scene

    /// A fresh launch (fresh storage, the seeded player) into `scene`, recording what the app plays.
    private func launch(scene: String?, _ extra: [String: String] = [:]) {
        if app.state != .notRunning { app.terminate() }
        var environment = [
            "TIMBRE_TEST_STORAGE_ID": UUID().uuidString,
            "TIMBRE_SKIP_ONBOARDING": "1",
            "TIMBRE_DEMO_DATA": "1",
            "TIMBRE_DEMO_PITCH": "1",
            "TIMBRE_PREVIEW_AUDIO": exchange.path,
        ]
        if let scene { environment["TIMBRE_SCENE"] = scene }
        environment.merge(extra) { _, new in new }
        app.launchEnvironment = environment
        app.launchArguments = CaptureLocalization.launchArguments
        app.launch()
        CaptureLocalization.recordLaunch(context: "preview-" + (scene ?? "songs"))
    }

    // MARK: Scenes

    /// The `preview-tune` scene: once the 3D stage is up, the test tells the app to go (the cue file). The lowest string
    /// drifts in from 14 cents flat and locks with its bell; the clip holds the lock `Timing.lockTail` past the moment
    /// (the shimmer, "✓ In tune", the peg's tick). Then the other strings lock on the scene's clock and the celebration
    /// plays out.
    private func tuneScene(_ cut: Cut) {
        let cue = exchange.appendingPathComponent("go-\(UUID().uuidString)")
        var extra = ["TIMBRE_SCENE_CUE": cue.path, "TIMBRE_DEBUG_STATE": "1"]
        if let instrument = cut.instrument { extra["TIMBRE_SCENE_INSTRUMENT"] = instrument }
        launch(scene: "preview-tune", extra)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 30))
        let stage = waitForStage()
        if stage != "3d" { missed("the tuner's stage is '\(stage)', not 3D") }
        // One snapshot before the scene starts (nothing locks before the cue): the strings, and where the readout is.
        let layout = tunerLayout()
        if let readout = layout.readout { region("readout", readout) } else { missed("no readout region: the badge can't be checked") }
        sync("tuner")

        FileManager.default.createFile(atPath: cue.path, contents: Data())
        let go = Date()
        // Hands off. The picture is taken the moment the app notes the lock (reading the shared file doesn't touch the
        // app), while the badge, the halo and the comet change the screen: a moment the recording can't confuse.
        let noted = awaitEvent("lock", after: go, until: go.addingTimeInterval(Demo.firstLock + 25), every: 0.01)
        let taken = sync("lock")
        let lock = noted?.time ?? go.addingTimeInterval(Demo.firstLock + 0.1)
        if noted == nil {
            missed("the app noted no lock")
        } else if taken.timeIntervalSince(lock) > Timing.syncLag {
            missed(String(format: "the lock's sync came %.0f ms after the app's lock", taken.timeIntervalSince(lock) * 1000))
        }
        clip("lock", from: lock.addingTimeInterval(-Timing.lockLead), to: lock.addingTimeInterval(Timing.lockTail), keep: .tail,
             shortest: 3.0, anchor: "lock")
        poster(at: lock.addingTimeInterval(Timing.posterAfterLock))
        hold(until: lock.addingTimeInterval(0.8))
        sync("lock-held")

        // The other strings, on the scene's clock (`PreviewTune`): hands off until the last one has locked.
        let rest = Double(max(1, layout.strings) - 1) * (Demo.hold + Timing.nextGap)
        let expected = lock.addingTimeInterval(Timing.firstHold + rest + 0.3)
        let tuned = awaitEvent("tuned", after: lock, until: expected.addingTimeInterval(20))?.time ?? expected
        hold(until: tuned.addingTimeInterval(3.4))
        sync("tuned")
        if !celebration().exists { missed("No celebration once every string locked") }
        clip("tuned", from: tuned.addingTimeInterval(-1.4), to: tuned.addingTimeInterval(3.2), keep: .tail, shortest: 3.4)
        // The strings' sound is written once the scene is done with them: this launch ends only after it is.
        if awaitEvent("strings", after: lock, until: Date().addingTimeInterval(15)) == nil {
            missed("the app never finished writing the strings' sound")
        }
    }

    /// The `show-me` scene: E minor's card plays on the 3D guitar. The chord's first showing plays by itself; the clip is
    /// a replay, asked for with "Show me" once the first is over: the fingertips land, then the chord rings.
    private func showMeScene() {
        launch(scene: "show-me", ["TIMBRE_DEBUG_STATE": "1"])
        XCTAssertTrue(element("lesson.close").waitForExistence(timeout: 30), "The Show me lesson never opened")
        var probe = showMeProbe()
        let deadline = Date().addingTimeInterval(90)
        var asked = Date.distantPast
        while probe.stage != "3d" && Date() < deadline {
            if probe.stage.isEmpty && Date().timeIntervalSince(asked) > 8 {
                let button = element("lesson.showme")
                if button.exists && button.isHittable { button.tap(); asked = Date() }
            }
            pause(0.5)
            probe = showMeProbe()
        }
        guard probe.stage == "3d" else {
            missed("the Show me stage never showed the 3D model (stage '\(probe.stage)')")
            return
        }
        // Past the first demonstration (its strings dark, "Your turn" up), so the app is at rest for the tap.
        if let landed = probe.landed { hold(until: landed.addingTimeInterval(3)) } else { pause(2) }
        sync("showme-ready")
        let tapped = Date()
        tapIfPresent(element("lesson.showme"))
        // The first fingertip lands 0.05 s after the tap, the last a landing step later; the ring follows.
        hold(until: tapped.addingTimeInterval(ShowMeRing.replayLanding + ShowMeRing.ringEnd))
        sync("showme")
        let landed = showMeProbe().landed.flatMap { $0 > tapped ? $0 : nil } ?? tapped.addingTimeInterval(ShowMeRing.replayLanding)
        clip("showme", from: tapped.addingTimeInterval(-0.3), to: landed.addingTimeInterval(ShowMeRing.ringEnd), keep: .tail, shortest: 2.2)
    }

    /// The `song-perform` scene: the song opens on its performance and starts its take by itself; the app notes the
    /// take's beat clock. The clip runs from the hook's downbeat for `hookBars` bars; the song then plays out, hands
    /// off, and the finale's stars land.
    private func performScene(_ cut: Cut) {
        launch(scene: "song-perform", ["TIMBRE_SCENE_SONG": cut.lesson, "TIMBRE_SCENE_BAR": "\(cut.bar)"])
        let opened = element("lesson.close").waitForExistence(timeout: 30)
        XCTAssertTrue(opened, "The performance never opened")
        let shown = Date()
        // Hands off from here: a query stalls the main thread, and a note heard late would break the run.
        let clock = takeClock(after: shown.addingTimeInterval(-15), until: shown.addingTimeInterval(12))
            ?? TakeClock(origin: shown.addingTimeInterval(3.2), beat: 60.0 / cut.bpm, meter: 4,
                         firstBeat: Double((cut.bar - 1) * 4), endBeat: cut.endBeat)
        let hookStart = clock.time(ofBeat: Double(cut.hookBar * clock.meter))
        let hookEnd = clock.time(ofBeat: Double((cut.hookBar + cut.hookBars) * clock.meter))
        mark("PREVIEW-BEAT \(stamp(hookStart)) \(String(format: "%.5f", clock.beat)) \(clock.meter)")
        hold(until: hookStart.addingTimeInterval(1.5))
        sync("highway")
        hold(until: hookEnd.addingTimeInterval(0.3))
        sync("highway-2")
        // Whole bars on the band's clock: the cut never trims this clip.
        clip("highway", from: hookStart, to: hookEnd, keep: .head, shortest: hookEnd.timeIntervalSince(hookStart))
        checkMultiplier()

        // The rest of the song, hands off; then the finale, its stars landing one by one.
        hold(until: clock.time(ofBeat: clock.endBeat).addingTimeInterval(1.0))
        let finale = soft(firstSeen(20) { element("song.again").exists || element("lesson.continue").exists }, "The song's finale never showed")
        resultsClip(finale: finale)
    }

    /// A lesson's play-along (the violin's open strings): the scene opens the lesson on it, the test starts it, the demo
    /// pitch plays each note on time, and the results' stars land.
    private func playAlongScene(_ cut: Cut) {
        launch(scene: "song-perform", ["TIMBRE_SCENE_SONG": cut.lesson])
        XCTAssertTrue(element("lesson.close").waitForExistence(timeout: 30), "The play-along lesson never opened")
        pause(1.2)
        // A one-bar count-in, then each note runs down its lane to the line and lights as it is played.
        let started = soft(press("Start", timeout: 20), "The play-along never started")
        hold(until: started.addingTimeInterval(5.5))
        sync("highway")
        hold(until: started.addingTimeInterval(10.2))
        sync("highway-2")
        clip("highway", from: started.addingTimeInterval(3.6), to: started.addingTimeInterval(9.6), keep: .head)
        XCTAssertTrue(element("along.again").waitForExistence(timeout: 40), "The play-along never finished")
        pause(0.6)
        let finished = soft(press("Continue"), "No results after the play-along")
        resultsClip(finale: finished)
    }

    /// The results clip, from just before the first star rings (the first sound effect the app starts once the finale
    /// is up, read from the shared file), so the stars land under "Hear how you did" with their bells. Without that
    /// sound, from just before the finale was seen. Hands off until the clip is over.
    private func resultsClip(finale: Date) {
        let star = awaitCue(after: finale.addingTimeInterval(-0.5), until: finale.addingTimeInterval(2.5))
        if star == nil { missed("no star rang within 2.5 s of the finale: the results clip starts at the finale") }
        let start = star.map { $0.addingTimeInterval(-Timing.starLead) } ?? finale.addingTimeInterval(-0.2)
        hold(until: start.addingTimeInterval(0.9))
        sync("results")
        hold(until: start.addingTimeInterval(3.6))
        clip("results", from: start, to: start.addingTimeInterval(3.3), keep: .head, shortest: 2.6)
    }

    /// The Songs tab, under 3 s, and sounding: the song of the day's preview (its first verse, with the band) plays
    /// while the shelves scroll by. Then, off camera, the app plays its motif for the end card.
    private func songsScene() {
        let motif = exchange.appendingPathComponent("motif-\(UUID().uuidString)")
        launch(scene: nil, ["TIMBRE_PREVIEW_MOTIF": motif.path])
        tab("Songs")
        let hero = element("songs.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Songs never showed its song of the day")
        pause(1.4)  // the shelves' entrance
        sync("songs-ready")
        let asked = Date()
        tapIfPresent(element("songs.hero.preview"))
        // The clip starts once the preview is heard (the app notes its engine sounding after a pause).
        let heard = awaitEvent("sound", after: asked, until: asked.addingTimeInterval(5))?.time
        if heard == nil { missed("the song of the day's preview was never heard") }
        let start = (heard ?? asked.addingTimeInterval(0.6)).addingTimeInterval(0.15)
        hold(until: start)
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: .slow, thenHoldForDuration: 0.1)
        hold(until: start.addingTimeInterval(3.0))
        sync("songs")
        clip("songs", from: start, to: start.addingTimeInterval(2.7), keep: .head)

        // Off camera: the motif, for the end card.
        let cued = Date()
        FileManager.default.createFile(atPath: motif.path, contents: Data())
        if let played = awaitEvent("motif", after: cued, until: cued.addingTimeInterval(10)) {
            hold(until: played.time.addingTimeInterval(Timing.motifLength))
            mark("PREVIEW-CARD \(stamp(played.time.addingTimeInterval(-0.02))) \(stamp(played.time.addingTimeInterval(Timing.motifLength)))")
        } else {
            missed("the app never played its motif for the end card")
        }
        pause(0.5)
    }

    // MARK: Marks for the cut

    private func stamp(_ date: Date) -> String { String(format: "%.3f", date.timeIntervalSince1970) }

    private func mark(_ line: String) {
        print(line)
        marks.append(line)
    }

    /// A moment the tour waited for and didn't get: noted in the log and in PREVIEW.txt.
    private func missed(_ what: String) { mark("PREVIEW-MISSED \(what)") }

    /// A stretch worth showing. `shortest`: the cut never trims it below this (the lock's hold, the celebration).
    /// `anchor`: the sync that alone places it in the recording.
    private func clip(_ name: String, from start: Date, to end: Date, keep: Keep, shortest: Double? = nil, anchor: String? = nil) {
        guard end > start else { return }
        let floor = shortest.map { String(format: " %.2f", $0) } ?? ""
        let pinned = anchor.map { " anchor=\($0)" } ?? ""
        mark("PREVIEW-CLIP \(name) \(stamp(start)) \(stamp(end)) \(keep.rawValue)\(floor)\(pinned)")
    }

    private func poster(at moment: Date) { mark("PREVIEW-POSTER \(stamp(moment))") }

    /// A region of the screen, as fractions of it.
    private func region(_ label: String, _ box: CGRect) {
        let numbers = [box.minX, box.minY, box.width, box.height].map { String(format: "%.4f", Double($0)) }
        mark("PREVIEW-REGION \(label) \(numbers.joined(separator: " "))")
    }

    /// A picture of the screen at a known moment, for lining the cut up with the recording (and proving the recording
    /// shows the app there). A screenshot comes from the simulator, not the app's main thread. Returns when it was asked.
    @discardableResult
    private func sync(_ label: String) -> Date {
        let before = Date()
        let shot = XCUIScreen.main.screenshot()
        let after = Date()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "sync-\(label)"
        attachment.lifetime = .keepAlways
        add(attachment)
        mark("PREVIEW-SYNC \(label) \(stamp(before)) \(stamp(after))")
        return before
    }

    /// The HUD at the highway clip's end, from one snapshot (one stall of the app's main thread, after the clip): ×4
    /// comes with a run of 16 (`ComboBadge.multiplier`), so a combo of 16 or more here means the clip ended at ×4.
    private func checkMultiplier() {
        var combo = -1
        if let root = try? app.snapshot() {
            var pending: [XCUIElementSnapshot] = [root]
            while let node = pending.popLast() {
                if node.identifier.hasPrefix("performance.combo."),
                   let value = Int(node.identifier.dropFirst("performance.combo.".count)) { combo = max(combo, value) }
                pending.append(contentsOf: node.children)
            }
        }
        let seen = combo < 0 ? "no combo on screen" : "combo \(combo)"
        if combo >= Self.fourTimes {
            mark("PREVIEW-CHECK multiplier pass \(seen) at the clip's end (×4)")
        } else {
            mark("PREVIEW-CHECK multiplier fail \(seen) at the clip's end, under the run of \(Self.fourTimes) that ×4 needs")
        }
    }

    /// The run ×4 needs (Highway.swift's `ComboBadge`).
    private static let fourTimes = 16

    // MARK: The app's own record of its moments

    private struct AppEvent {
        let name: String
        let time: Date
        let fields: [String: Any]
    }

    /// The lines the app has written so far (`PreviewRecorder` in DemoScenes.swift: events.jsonl) of one kind.
    private func appLines(kind: String) -> [[String: Any]] {
        guard let text = try? String(contentsOf: exchange.appendingPathComponent("events.jsonl"), encoding: .utf8) else { return [] }
        var found: [[String: Any]] = []
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  fields["kind"] as? String == kind else { continue }
            found.append(fields)
        }
        return found
    }

    /// The scene moments the app has written so far.
    private func appEvents() -> [AppEvent] {
        appLines(kind: "event").compactMap { fields -> AppEvent? in
            guard let name = fields["name"] as? String, let seconds = fields["t"] as? Double else { return nil }
            return AppEvent(name: name, time: Date(timeIntervalSince1970: seconds), fields: fields)
        }
    }

    /// The first `name` the app noted after `moment`, if it has.
    private func appEvent(_ name: String, after moment: Date) -> AppEvent? {
        appEvents().first { $0.name == name && $0.time > moment }
    }

    /// Waits (reading the shared file, never the app) for the app to note `name` after `moment`, until `deadline`,
    /// looking every `interval` seconds.
    private func awaitEvent(_ name: String, after moment: Date, until deadline: Date, every interval: Double = 0.2) -> AppEvent? {
        while true {
            if let event = appEvent(name, after: moment) { return event }
            if Date() >= deadline { return nil }
            pause(interval)
        }
    }

    /// Waits (reading the shared file) for the first sound effect the app starts after `moment`, until `deadline`.
    private func awaitCue(after moment: Date, until deadline: Date) -> Date? {
        while true {
            let started = appLines(kind: "cue").compactMap { $0["t"] as? Double }.map { Date(timeIntervalSince1970: $0) }
            if let first = started.filter({ $0 > moment }).min() { return first }
            if Date() >= deadline { return nil }
            pause(0.1)
        }
    }

    /// A take's beat clock: wall-clock time of its first click (`firstBeat` of the song), seconds a beat, beats a bar,
    /// and the beat the song ends on.
    private struct TakeClock {
        let origin: Date
        let beat: Double
        let meter: Int
        let firstBeat: Double
        let endBeat: Double

        func time(ofBeat songBeat: Double) -> Date { origin.addingTimeInterval((songBeat - firstBeat) * beat) }
    }

    private func takeClock(after moment: Date, until deadline: Date) -> TakeClock? {
        guard let event = awaitEvent("take", after: moment, until: deadline),
              let origin = event.fields["origin"] as? Double, let bpm = event.fields["bpm"] as? Double, bpm > 0,
              let first = event.fields["firstBeat"] as? Double, let end = event.fields["endBeat"] as? Double else { return nil }
        let meter = (event.fields["meter"] as? Int) ?? 4
        return TakeClock(origin: Date(timeIntervalSince1970: origin), beat: 60 / bpm, meter: max(1, meter), firstBeat: first, endBeat: end)
    }

    // MARK: Tuner

    /// The demo pitch's clock (AudioService.startDemo): each 6-second cycle drifts in from 14 cents flat, is inside the
    /// 5-cent lock band from 2.7 s, and a lock needs 0.65 s of the band.
    private enum Demo {
        static let inBand = 2.7
        static let hold = 0.65
        static let firstLock = inBand + hold
    }

    /// The scene's own clock (`PreviewTune` in DemoScenes.swift) and the cut's moments around the first lock.
    private enum Timing {
        static let firstHold = 2.2
        static let nextGap = 0.5
        /// The lock clip runs from this long before the lock (the string drifting in, heard) to `lockTail` after it.
        static let lockLead = 2.6
        static let lockTail = 1.2
        /// The poster: the lock just landed, badge, tick and comet on screen.
        static let posterAfterLock = 0.3
        /// The lock's sync at most this long after the app noted the lock.
        static let syncLag = 0.05
        /// The results clip starts this long before the first star rings.
        static let starLead = 0.3
        /// The motif with its room's tail (SoundSynth: 2.1 s and 0.5 s of reverb).
        static let motifLength = 2.6
    }

    /// The tuner's UI-test probe (TIMBRE_DEBUG_STATE=1, never drawn): "stage=<3d|loading|2d> listening=<…>".
    private func tunerStage() -> String {
        guard let label = (try? element("stage.state").snapshot())?.label else { return "" }
        for field in label.split(separator: " ") where field.hasPrefix("stage=") {
            return String(field.dropFirst("stage=".count))
        }
        return ""
    }

    /// Waits for the 3D model to take over from the studio render that holds the stage while it loads (the first model
    /// on a fresh simulator can take 20 s or more), then for the camera's dolly in to the headstock.
    private func waitForStage(timeout: TimeInterval = 90) -> String {
        let started = Date()
        var stage = tunerStage()
        while stage != "3d" && stage != "2d" && Date().timeIntervalSince(started) < timeout {
            if stage.isEmpty && Date().timeIntervalSince(started) > 15 { break }
            pause(0.5)
            stage = tunerStage()
        }
        pause(2.5)
        return tunerStage()
    }

    /// From one snapshot: how many string chips the tuner shows, and its readout (the note, its badge and meter) as a
    /// fraction of the screen, from under the AUTO / MANUAL control down to the chips (nil without the control).
    private func tunerLayout() -> (strings: Int, readout: CGRect?) {
        guard let root = try? app.snapshot() else { return (6, nil) }
        var chips: Set<String> = []
        var chipTop = CGFloat.greatestFiniteMagnitude
        var control: CGRect?
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            if node.identifier.hasPrefix("string.") {
                chips.insert(node.identifier)
                chipTop = min(chipTop, node.frame.minY)
            }
            if node.identifier == "tune.detection" { control = node.frame }
            pending.append(contentsOf: node.children)
        }
        let screen = root.frame
        var readout: CGRect?
        if let control, screen.height > 0, chipTop < .greatestFiniteMagnitude, chipTop - control.maxY > 40 {
            readout = CGRect(x: 0.1, y: control.maxY / screen.height, width: 0.8, height: (chipTop - control.maxY) / screen.height)
        }
        return (chips.isEmpty ? 6 : chips.count, readout)
    }

    /// The celebration card: its "Ready to play" button, or its headline.
    private func celebration() -> XCUIElement {
        guard let headline = CaptureLocalization.allTuned else {
            XCTFail("Missing localized preview celebration fixture")
            return element("__missing_preview_celebration_fixture__")
        }
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "celebration.lesson", headline))
            .firstMatch
    }

    // MARK: Show me

    private struct ShowMeReading {
        var stage = ""
        var landed: Date?
    }

    /// The "Show me" stage's probe (`ShowMeProbe`, TIMBRE_DEBUG_STATE=1): "showme=<3d|picture|loading> landed=<epoch s
    /// the last fingertip lands> …". Only the fields before the free-text "diag=" are read.
    private func showMeProbe() -> ShowMeReading {
        var reading = ShowMeReading()
        guard let label = (try? element("showme.state").snapshot())?.label else { return reading }
        let head = label.components(separatedBy: " diag=").first ?? label
        for field in head.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "showme" { reading.stage = parts[1] }
            if parts[0] == "landed" { reading.landed = Double(parts[1]).flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil } }
        }
        return reading
    }

    /// A replay's clock (LessonExplain's `runDemo`): its last fingertip lands about 0.5 s after the tap; a landing step
    /// (0.45 s) later the chord rings across the strings, which stay lit for 1.5 s.
    private enum ShowMeRing {
        static let replayLanding = 0.5
        static let ringEnd = 1.9
    }

    // MARK: Lessons

    private func lessonButtonReads(_ title: String) -> Bool {
        guard let label = CaptureLocalization.lessonButtonLabel(title) else {
            XCTFail("Missing localized preview lesson-button fixture for \(title)")
            return false
        }
        let button = element("lesson.continue")
        return button.exists && button.isEnabled && button.label == label
    }

    /// Taps the lesson's big bottom button once it reads `title` and is enabled, again if the tap is lost (it still
    /// reads the same afterwards). Returns when the tap that took was made.
    private func press(_ title: String, timeout: TimeInterval = 15) -> Date? {
        guard firstSeen(timeout, { lessonButtonReads(title) }) != nil else { return nil }
        for _ in 0..<3 {
            element("lesson.continue").tap()
            let tapped = Date()
            if firstSeen(3, { !lessonButtonReads(title) }) != nil { return tapped }
        }
        return nil
    }

    /// A moment the tour waited for; if it never came, note it and carry on from now.
    private func soft(_ value: Date?, _ message: String) -> Date {
        if let value { return value }
        missed(message)
        return Date()
    }

    // MARK: Plumbing

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func pause(_ seconds: Double) { if seconds > 0 { Thread.sleep(forTimeInterval: seconds) } }

    /// Sleeps until `moment` (no-op once it has passed): pacing follows the clock, not query times.
    private func hold(until moment: Date) { pause(moment.timeIntervalSinceNow) }

    /// Polls `condition` until it holds; returns the middle of the look that first saw it (a look takes up to a second
    /// on the 3D stage, so its end is late), or nil after `timeout`.
    private func firstSeen(_ timeout: TimeInterval, _ condition: () -> Bool) -> Date? {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let asked = Date()
            if condition() { return asked.addingTimeInterval(Date().timeIntervalSince(asked) / 2) }
            if Date() >= deadline { return nil }
            pause(0.1)
        }
    }

    /// Taps an element that may vanish on its own at any moment: the frame comes from a snapshot, and the tap goes to
    /// that point.
    private func tapIfPresent(_ target: XCUIElement) {
        guard let frame = (try? target.snapshot())?.frame, !frame.isEmpty else { return }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
    }

    /// Taps a tab until it is selected (a tap while a sheet is still closing can be swallowed).
    private func tab(_ name: String) {
        guard let label = CaptureLocalization.tabLabel(name) else {
            XCTFail("Missing localized preview tab fixture for \(name)")
            return
        }
        let button = app.tabBars.buttons[label].firstMatch
        for attempt in 0..<4 {
            button.tap()
            if button.isSelected { return }
            pause(0.8 + Double(attempt) * 0.4)
        }
    }
}
