import XCTest

/// The App Store App Previews (6.9-inch iPhone, portrait). .github/workflows/preview.yml records the simulator screen
/// while one of these tours plays with the demo pitch on; the main iOS workflow skips them.
///
/// - `testAppPreview`, the main preview: a string drifts into tune on the 3D headstock and locks, held 1.5 s for the
///   camera; the other strings lock, chosen the way automatic detection chooses them (AUTO stays AUTO), and the
///   full-tune celebration plays out; "Show me" fingers E minor on the 3D guitar; Kite Weather on the highway at ×4 with
///   the band, cut on the song's own downbeats; the song's stars; the Songs tab, under 3 s. preview.py adds the end card.
/// - `testAppPreviewViolin`, the violin page's preview (a Custom Product Page): the same tuner moment on the 3D violin,
///   then Jingle Bells from the violin songbook on the runway with the band, its stars, and Songs.
///
/// Every scene is a fresh launch into a store scene (TIMBRE_SCENE, ios/Timbre/Root/DemoScenes.swift), so each moment
/// comes from the app's own code paths, in the same state on every run. Each scene marks only the stretch worth showing:
/// `PREVIEW-CLIP <name> <start> <end> <head|tail> [<shortest>]` in wall-clock seconds, printed to the log and attached
/// to the result; tools/marketing/preview.py cuts those stretches out of the recording and joins them with hard cuts,
/// so launches, taps and waits stay off camera. `PREVIEW-BEAT <downbeat> <seconds a beat> <beats a bar>` gives the
/// band's clock, which the cut lands on; `PREVIEW-POSTER <time>` the poster frame; `PREVIEW-CUT <name>` which preview.
///
/// The app writes down what it plays and when (`PreviewRecorder`: the bells, the strum, the band) and its scenes'
/// moments (a lock, the full tune, a take's beat clock) to a folder it shares with this test (TIMBRE_PREVIEW_AUDIO). The
/// test cuts on those moments when they are there, and on the demo pitch's known clock when they aren't; preview.py
/// lays the soundtrack from the same folder.
///
/// `PREVIEW-SYNC` screenshots (attached as `sync-<label>`) let the cut find each moment in the recording by its picture
/// rather than by the clock, and prove the recording really shows the app there. While a string is due to lock or a note
/// is due, the test keeps its hands off: every query holds the app's main thread, and a gap of more than 150 ms in the
/// readings restarts the 0.65 s hold a lock needs (or makes a note late). Screenshots and reading the shared folder
/// don't touch the app.
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

        /// Kite Weather from bar 47: the last chorus's "climb, let it go", then the hook ("It's kite weather, kite
        /// weather", bars 48–49) at ×4, and the song's end nine bars later.
        static let guitar = Cut(name: "guitar", instrument: nil, lesson: "orig-kite-weather", performs: true, bar: 47,
                                hookBar: 48, hookBars: 2, showMe: true, bpm: 88, endBeat: 224)
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
            mark("PREVIEW-MISSED handshake folder not writable: \(error.localizedDescription)")
            pause(12)
            return
        }
        let deadline = Date().addingTimeInterval(90)
        while !FileManager.default.fileExists(atPath: recording) && Date() < deadline { pause(0.25) }
        if !FileManager.default.fileExists(atPath: recording) { mark("PREVIEW-MISSED the recorder never said it started") }
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
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    // MARK: Scenes

    /// The `preview-tune` scene: once the 3D stage is up, the test tells the app to go (the cue file). The lowest string
    /// drifts in from 14 cents flat and locks with its bell; the clip holds the lock 1.5 s past the moment (the shimmer,
    /// "✓ In tune", the peg's tick). Then the other strings lock on the scene's clock and the celebration plays out.
    private func tuneScene(_ cut: Cut) {
        let cue = exchange.appendingPathComponent("go-\(UUID().uuidString)")
        var extra = ["TIMBRE_SCENE_CUE": cue.path, "TIMBRE_DEBUG_STATE": "1"]
        if let instrument = cut.instrument { extra["TIMBRE_SCENE_INSTRUMENT"] = instrument }
        launch(scene: "preview-tune", extra)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 30))
        let stage = waitForStage()
        if stage != "3d" { print("PREVIEW-MISSED the tuner's stage is '\(stage)', not 3D") }
        let strings = max(1, stringCount())
        sync("tuner")

        FileManager.default.createFile(atPath: cue.path, contents: Data())
        let go = Date()
        // Hands off until the lock and its hold have played out.
        hold(until: go.addingTimeInterval(Demo.firstLock + Timing.lockHold + 0.8))
        sync("lock")
        let lock = appEvent("lock", after: go)?.time ?? go.addingTimeInterval(Demo.firstLock + 0.1)
        clip("lock", from: lock.addingTimeInterval(-2.6), to: lock.addingTimeInterval(Timing.lockHold + 0.2), keep: .tail, shortest: 3.0)
        poster(at: lock.addingTimeInterval(1.0))

        // The other strings, on the scene's clock (`PreviewTune`): hands off until the last one has locked.
        let expected = lock.addingTimeInterval(Timing.firstHold + Double(strings - 1) * (Demo.hold + Timing.nextGap) + 0.3)
        let tuned = awaitEvent("tuned", after: lock, until: expected.addingTimeInterval(20))?.time ?? expected
        hold(until: tuned.addingTimeInterval(3.4))
        sync("tuned")
        if !celebration().exists { print("PREVIEW-MISSED No celebration once every string locked") }
        clip("tuned", from: tuned.addingTimeInterval(-1.4), to: tuned.addingTimeInterval(3.2), keep: .tail, shortest: 3.4)
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
            print("PREVIEW-MISSED the Show me stage never showed the 3D model (stage '\(probe.stage)')")
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

        // The rest of the song, hands off; then the finale, its stars landing one by one.
        hold(until: clock.time(ofBeat: clock.endBeat).addingTimeInterval(1.0))
        let finale = soft(firstSeen(20) { element("song.again").exists || element("lesson.continue").exists }, "The song's finale never showed")
        hold(until: finale.addingTimeInterval(3.8))
        sync("results")
        clip("results", from: finale.addingTimeInterval(0.2), to: finale.addingTimeInterval(3.6), keep: .tail, shortest: 2.6)
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
        // The results: on a loaded runner the screen takes a moment to draw, so the clip starts late and keeps its tail.
        let finished = soft(press("Continue"), "No results after the play-along")
        hold(until: finished.addingTimeInterval(3.4))
        sync("results")
        hold(until: finished.addingTimeInterval(6.2))
        clip("results", from: finished.addingTimeInterval(2.6), to: finished.addingTimeInterval(5.8), keep: .tail, shortest: 2.6)
    }

    /// The Songs tab, under 3 s: the shelves, a short scroll, and a tap that opens the song of the day.
    private func songsScene() {
        launch(scene: nil)
        tab("Songs")
        let hero = element("songs.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 15), "Songs never showed its song of the day")
        pause(1.4)  // the shelves' entrance
        sync("songs-ready")
        let start = Date()
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -120)), withVelocity: .slow, thenHoldForDuration: 0.1)
        hold(until: start.addingTimeInterval(1.2))
        tapIfPresent(hero)
        hold(until: start.addingTimeInterval(3.0))
        sync("songs")
        clip("songs", from: start.addingTimeInterval(-0.2), to: start.addingTimeInterval(2.6), keep: .head)
        pause(1)
    }

    // MARK: Marks for the cut

    private func stamp(_ date: Date) -> String { String(format: "%.3f", date.timeIntervalSince1970) }

    private func mark(_ line: String) {
        print(line)
        marks.append(line)
    }

    /// A stretch worth showing. `shortest`: the cut never trims it below this (the lock's hold, the celebration).
    private func clip(_ name: String, from start: Date, to end: Date, keep: Keep, shortest: Double? = nil) {
        guard end > start else { return }
        let floor = shortest.map { String(format: " %.2f", $0) } ?? ""
        mark("PREVIEW-CLIP \(name) \(stamp(start)) \(stamp(end)) \(keep.rawValue)\(floor)")
    }

    private func poster(at moment: Date) { mark("PREVIEW-POSTER \(stamp(moment))") }

    /// A picture of the screen at a known moment, for lining the cut up with the recording (and proving the recording
    /// shows the app there). A screenshot comes from the simulator, not the app's main thread.
    private func sync(_ label: String) {
        let before = Date()
        let shot = XCUIScreen.main.screenshot()
        let after = Date()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "sync-\(label)"
        attachment.lifetime = .keepAlways
        add(attachment)
        mark("PREVIEW-SYNC \(label) \(stamp(before)) \(stamp(after))")
    }

    // MARK: The app's own record of its moments

    private struct AppEvent {
        let name: String
        let time: Date
        let fields: [String: Any]
    }

    /// The scene moments the app has written so far (`PreviewRecorder` in DemoScenes.swift: events.jsonl).
    private func appEvents() -> [AppEvent] {
        guard let text = try? String(contentsOf: exchange.appendingPathComponent("events.jsonl"), encoding: .utf8) else { return [] }
        var found: [AppEvent] = []
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  fields["kind"] as? String == "event", let name = fields["name"] as? String,
                  let seconds = fields["t"] as? Double else { continue }
            found.append(AppEvent(name: name, time: Date(timeIntervalSince1970: seconds), fields: fields))
        }
        return found
    }

    /// The first `name` the app noted after `moment`, if it has.
    private func appEvent(_ name: String, after moment: Date) -> AppEvent? {
        appEvents().first { $0.name == name && $0.time > moment }
    }

    /// Waits (reading the shared file, never the app) for the app to note `name` after `moment`, until `deadline`.
    private func awaitEvent(_ name: String, after moment: Date, until deadline: Date) -> AppEvent? {
        while true {
            if let event = appEvent(name, after: moment) { return event }
            if Date() >= deadline { return nil }
            pause(0.2)
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

    /// The scene's own clock (`PreviewTune` in DemoScenes.swift) and the cut's hold on the first lock.
    private enum Timing {
        static let firstHold = 2.2
        static let nextGap = 0.5
        static let lockHold = 1.5
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

    /// How many string chips the tuner shows, from one snapshot.
    private func stringCount() -> Int {
        guard let root = try? app.snapshot() else { return 6 }
        var ids: Set<String> = []
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            if node.identifier.hasPrefix("string.") { ids.insert(node.identifier) }
            pending.append(contentsOf: node.children)
        }
        return ids.isEmpty ? 6 : ids.count
    }

    /// The celebration card: its "Ready to play" button, or its headline.
    private func celebration() -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "celebration.lesson", "All strings in tune"))
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
        let button = element("lesson.continue")
        return button.exists && button.isEnabled && button.label == title
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

    /// A moment the tour waited for; if it never came, note it in the log and carry on from now.
    private func soft(_ value: Date?, _ message: String) -> Date {
        if let value { return value }
        print("PREVIEW-MISSED \(message)")
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
        let button = app.tabBars.buttons[name].firstMatch
        for attempt in 0..<4 {
            button.tap()
            if button.isSelected { return }
            pause(0.8 + Double(attempt) * 0.4)
        }
    }
}
