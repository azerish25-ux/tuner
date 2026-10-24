import XCTest

/// The App Store App Preview (6.9-inch iPhone, portrait). .github/workflows/preview.yml records the
/// simulator screen while this test plays a tour with the demo pitch on; the main iOS workflow skips it.
///
/// The real flows run longer than a preview may (15–30 s), so each scene marks only the stretch worth
/// showing: `PREVIEW-CLIP <name> <start> <end> <head|tail>` in wall-clock seconds, printed to the log and
/// attached to the result. tools/marketing/preview.py cuts those stretches out of the recording and joins
/// them with short cross-fades, so taps and waits between clips stay off camera. Clip times come from what
/// the test sees on screen and from the demo pitch's known drift (14 cents flat into tune over 4.2 s,
/// locking 3.35 s in, again every 6 s), never from fixed sleeps alone.
///
/// `PREVIEW-SYNC` screenshots (attached as `sync-<label>`) let the cut find each moment in the recording by
/// its picture rather than by the clock, and prove the recording really shows the app there. On the tuner the
/// test stays hands-off while a string is due to lock: every query holds the app's main thread, and a gap of
/// more than 150 ms in the readings restarts the 0.65 s hold a lock needs. Screenshots don't touch the app.
final class AppPreviewUITests: XCTestCase {
    /// Which end of a clip matters when the cut has to shorten it.
    private enum Keep: String { case head, tail }

    private var app: XCUIApplication!
    private var marks: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = true  // a missed beat shortens the cut; the tour keeps filming
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        mark("PREVIEW-BEGIN \(stamp(Date()))")
        waitForRecorder()
    }

    /// preview.yml starts the screen recording only when the tour begins (minutes of home screen while the
    /// runner installs only add load and length). It passes a shared folder as TEST_RUNNER_PREVIEW_HANDSHAKE:
    /// the test drops `begin` there and waits for `recording`. Without the folder (a local run) it goes on at once.
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

    func testAppPreview() throws {
        app.launch()
        try tuneScene()
        try chordScene()
        try playAlongScene()
        songsScene()
    }

    // MARK: Scenes

    /// A string drifts into tune on the 3D stage, its peg showing which way to turn, and locks; then the
    /// other strings lock one by one and the celebration bursts.
    private func tuneScene() throws {
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 30))
        let chips = stringChips()
        XCTAssertFalse(chips.ids.isEmpty, "The tuner shows no string chips")
        let first = chips.selected ?? chips.ids.first ?? "string.1"
        // Let the 3D instrument settle, then restart listening: pausing ends the session (every string is
        // untuned again) and the demo pitch starts over, 14 cents flat.
        pause(2)
        sync("tuner")
        let listen = listenButton()
        // A tap while the audio session is still stopping can be lost: let it stop first.
        if listen.label != "Listen" { listen.tap(); pause(1.5) }
        listen.tap()
        // The restart came a little before the tap returned: taking the return as the start keeps every
        // prediction below on the late, safe side.
        var drift = Date()
        sync("drift")

        // Hands off until the first lock is due (3.35 s into the drift), then one look. If the restart tap
        // was lost or the hold was broken, try again on a fresh cycle.
        var locked = drift.addingTimeInterval(Demo.firstLock)
        hold(until: locked.addingTimeInterval(0.5))
        sync("lock")
        if !firstLocked(first) {
            if listen.label == "Listen" {
                listen.tap()
                drift = Date()
            } else {
                while drift.addingTimeInterval(Demo.firstLock) < Date().addingTimeInterval(0.5) { drift = drift.addingTimeInterval(Demo.cycle) }
            }
            locked = drift.addingTimeInterval(Demo.firstLock)
            hold(until: locked.addingTimeInterval(0.5))
            sync("lock-2")
            if !firstLocked(first) { print("PREVIEW-MISSED The first string never locked") }
        }
        let lockStart = drift.addingTimeInterval(0.1)
        let lockEnd = locked.addingTimeInterval(1.2)
        poster(at: locked.addingTimeInterval(0.9))
        hold(until: lockEnd)

        // The other strings, one at a time: after each tap, hands off until that string's lock is due.
        let others = chips.ids.filter { $0 != first }
        var finale = locked
        for (index, id) in others.enumerated() {
            element(id).tap()
            var due = lockDue(selectedBy: Date(), cycleStart: drift)
            hold(until: due.addingTimeInterval(0.5))
            if index == others.count - 1 {
                finale = due
            } else if !isTuned(id) {
                // The phase estimate ran early, or the hold was broken: the next cycle.
                due = due.addingTimeInterval(Demo.cycle)
                hold(until: due.addingTimeInterval(0.5))
                if !isTuned(id) { print("PREVIEW-MISSED \(id) never locked") }
            }
        }
        // The last lock brings the celebration (it closes itself after six seconds).
        sync("celebration")
        if !celebration().exists {
            finale = finale.addingTimeInterval(Demo.cycle)
            hold(until: finale.addingTimeInterval(0.5))
            sync("celebration-2")
            if !celebration().exists { print("PREVIEW-MISSED No celebration once every string locked") }
        }
        let finaleStart = finale.addingTimeInterval(-3.0)
        let finaleEnd = finale.addingTimeInterval(2.6)
        if finaleStart.timeIntervalSince(lockEnd) < 1.0 {
            clip("tune", from: lockStart, to: finaleEnd, keep: .tail)
        } else {
            clip("tune-lock", from: lockStart, to: lockEnd, keep: .tail)
            clip("tune-all", from: finaleStart, to: finaleEnd, keep: .tail)
        }
        // No tap near the card (its share button opens a sheet): wait for it to close.
        hold(until: finale.addingTimeInterval(7.0))
    }

    /// Learn's next lesson is "Your first chord: E minor": the chord step hears the demo pitch play the
    /// chord string by string, every string lighting up, then bursts.
    private func chordScene() throws {
        tab("Learn")
        let next = element("learn.continue")
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        pause(1)
        // The lesson zooms open on an explanation; the chord follows the day's quick tune check (skipped).
        let explained = soft(openLesson(next), "The chord lesson never opened")
        var shown = explained
        let skip = element("lesson.tunecheck.skip")
        if skip.waitForExistence(timeout: 3) {
            pause(0.4)
            skip.tap()
            shown = Date()
        }
        let ringing = firstSeen(12) { app.staticTexts["Every string rings"].exists }
        let heard: Date
        if let ringing {
            heard = ringing
        } else {
            // Missed between looks: the next explanation's Continue arrives about 1.3 s after the chord is heard.
            let followingAt = firstSeen(15) { lessonButtonReads("Continue") }
            let following = soft(followingAt, "The chord was never heard")
            heard = following.addingTimeInterval(-1.3)
        }
        sync("chord")
        clip("chord", from: max(shown.addingTimeInterval(-0.2), heard.addingTimeInterval(-3.5)), to: heard.addingTimeInterval(0.7), keep: .tail)

        // The rest of this lesson (a tapped, then a strummed rhythm) runs on its own clock, off camera.
        XCTAssertNotNil(press("Continue", timeout: 20), "No explanation after the chord")
        XCTAssertNotNil(press("Start"), "The tap rhythm never offered Start")
        XCTAssertNotNil(press("Continue", timeout: 45), "The tap rhythm never finished")
        XCTAssertNotNil(press("Start"), "The strum never offered Start")
        XCTAssertNotNil(press("Continue", timeout: 45), "The strum never finished")
        try leaveResults()
    }

    /// "The open strings": two note steps, a quiz and a listening question, then the play-along highway
    /// and the lesson's results, its stars landing one by one.
    private func playAlongScene() throws {
        let node = element("learn.lesson.gtr-1-2")
        XCTAssertTrue(node.waitForExistence(timeout: 15))
        reveal(node)
        XCTAssertNotNil(openLesson(node), "The play-along lesson never opened")
        let skip = element("lesson.tunecheck.skip")
        if skip.waitForExistence(timeout: 2) { skip.tap() }
        // The note steps finish on their own with the demo pitch.
        XCTAssertTrue(element("lesson.option.0").waitForExistence(timeout: 30))
        pause(0.8)
        XCTAssertTrue(pick(0), "Could not answer the quiz")
        XCTAssertNotNil(press("Continue"))
        pause(1.2)
        XCTAssertTrue(pick(1), "Could not answer the listening question")
        XCTAssertNotNil(press("Continue"))

        // A one-bar count-in at 60 BPM, then each note runs down its string to the line and lights as it is played.
        let started = soft(press("Start"), "The play-along never started")
        // The count-in fills the first 4 s (60 BPM): the clip opens on its last beat, as the first gem lands.
        hold(until: started.addingTimeInterval(5.5))
        sync("highway")
        hold(until: started.addingTimeInterval(8.0))
        sync("highway-2")
        hold(until: started.addingTimeInterval(10.2))
        clip("highway", from: started.addingTimeInterval(3.0), to: started.addingTimeInterval(10.0), keep: .head)
        XCTAssertTrue(element("along.again").waitForExistence(timeout: 30))
        pause(0.6)

        // The results: stars land one by one, XP counts up and the level bar fills. On a loaded runner the
        // screen took close to 3 s to draw (run 2 filmed a blank screen from 0.4 s to 2.8 s), so the clip
        // starts late and keeps its tail.
        let finished = soft(press("Continue"), "The play-along never finished")
        hold(until: finished.addingTimeInterval(3.4))
        sync("results")
        hold(until: finished.addingTimeInterval(5.6))
        sync("results-2")
        hold(until: finished.addingTimeInterval(7.0))
        clip("results", from: finished.addingTimeInterval(2.8), to: finished.addingTimeInterval(6.8), keep: .tail)
        try leaveResults()
    }

    /// The Songs tab: the song of the day, then a slow scroll through the collection.
    private func songsScene() {
        let switched = tab("Songs")
        XCTAssertTrue(element("songs.hero").waitForExistence(timeout: 10))
        hold(until: switched.addingTimeInterval(1.6))
        app.swipeUp(velocity: .slow)
        let end = Date().addingTimeInterval(1.2)
        sync("songs")
        hold(until: end)
        clip("songs", from: switched.addingTimeInterval(-0.2), to: end, keep: .head)
        // Spare footage, in case the cut needs to run a little longer.
        pause(3)
    }

    // MARK: Marks for the cut

    private func stamp(_ date: Date) -> String { String(format: "%.3f", date.timeIntervalSince1970) }

    private func mark(_ line: String) {
        print(line)
        marks.append(line)
    }

    private func clip(_ name: String, from start: Date, to end: Date, keep: Keep) {
        guard end > start else { return }
        mark("PREVIEW-CLIP \(name) \(stamp(start)) \(stamp(end)) \(keep.rawValue)")
    }

    private func poster(at moment: Date) { mark("PREVIEW-POSTER \(stamp(moment))") }

    /// A picture of the screen at a known moment, for lining the cut up with the recording (and proving the
    /// recording shows the app there). A screenshot comes from the simulator, not the app's main thread.
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

    // MARK: Tuner

    /// The tuner's string chips ("string.1" …, lowest first) and the one being tuned, from one snapshot:
    /// each separate query over the 3D stage costs about a second.
    private func stringChips() -> (ids: [String], selected: String?) {
        var found: [String: Bool] = [:]
        if let root = try? app.snapshot() {
            var pending: [XCUIElementSnapshot] = [root]
            while let node = pending.popLast() {
                if node.identifier.hasPrefix("string.") { found[node.identifier] = (found[node.identifier] ?? false) || node.isSelected }
                pending.append(contentsOf: node.children)
            }
        }
        if found.isEmpty {
            let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "string."))
            for chip in query.allElementsBoundByIndex { found[chip.identifier] = false }
        }
        let ids = found.keys.sorted { (Int($0.dropFirst(7)) ?? 0) < (Int($1.dropFirst(7)) ?? 0) }
        return (ids, ids.first { found[$0] == true })
    }

    private func isTuned(_ id: String) -> Bool { (element(id).value as? String) == "Tuned" }

    /// A moment the tour waited for; if it never came, note it in the log and carry on from now.
    private func soft(_ value: Date?, _ message: String) -> Date {
        if let value { return value }
        print("PREVIEW-MISSED \(message)")
        return Date()
    }

    private func inTuneBadge() -> Bool {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "In tune")).firstMatch.exists
    }

    private func listenButton() -> XCUIElement {
        let byId = element("listenButton")
        if byId.exists { return byId }
        return app.buttons.matching(NSPredicate(format: "label IN %@", ["Pause listening", "Listen"])).firstMatch
    }

    /// The celebration card: its "Ready to play" button, or its headline.
    private func celebration() -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "celebration.lesson", "All strings in tune"))
            .firstMatch
    }

    /// The first string has locked: its chip reads "Tuned", or the readout shows its in-tune badge.
    private func firstLocked(_ id: String) -> Bool { isTuned(id) || inTuneBadge() }

    /// The demo pitch's clock (AudioService.startDemo): each 6-second cycle drifts in from 14 cents flat, is
    /// inside the 5-cent lock band from 2.7 s to the end, and a lock needs 0.65 s of the band.
    private enum Demo {
        static let cycle = 6.0
        static let inBand = 2.7
        static let hold = 0.65
        static let firstLock = inBand + hold
    }

    /// When a string selected no later than `selected` has surely locked, for a cycle that started no later
    /// than `cycleStart` (a later selection never locks earlier, so upper bounds give a safe answer).
    private func lockDue(selectedBy selected: Date, cycleStart: Date) -> Date {
        let phase = max(0, selected.timeIntervalSince(cycleStart)).truncatingRemainder(dividingBy: Demo.cycle)
        let cycle = selected.addingTimeInterval(-phase)
        if phase < Demo.inBand { return cycle.addingTimeInterval(Demo.firstLock) }
        if phase + Demo.hold <= Demo.cycle { return selected.addingTimeInterval(Demo.hold) }
        return cycle.addingTimeInterval(Demo.cycle + Demo.firstLock)
    }

    // MARK: Lessons

    private func lessonButtonReads(_ title: String) -> Bool {
        let button = element("lesson.continue")
        return button.exists && button.isEnabled && button.label == title
    }

    /// Taps the lesson's big bottom button once it reads `title` and is enabled, again if the tap is lost
    /// (it still reads the same afterwards). Returns when the tap that took was made.
    private func press(_ title: String, timeout: TimeInterval = 15) -> Date? {
        guard firstSeen(timeout, { lessonButtonReads(title) }) != nil else { return nil }
        for _ in 0..<3 {
            element("lesson.continue").tap()
            let tapped = Date()
            if firstSeen(3, { !lessonButtonReads(title) }) != nil { return tapped }
        }
        return nil
    }

    /// Opens a lesson from Learn and taps through its first explanation; opens it again if that tap was lost
    /// (the Learn entry is still on screen). Returns when the explanation's Continue was tapped.
    private func openLesson(_ entry: XCUIElement) -> Date? {
        for _ in 0..<2 {
            entry.tap()
            if let tapped = press("Continue", timeout: 12) { return tapped }
            guard entry.exists && entry.isHittable else { return nil }
        }
        return nil
    }

    /// Picks an answer, again if Continue doesn't light up (a tap while the step slides in can be lost).
    private func pick(_ index: Int) -> Bool {
        let option = element("lesson.option.\(index)")
        for _ in 0..<4 {
            guard option.waitForExistence(timeout: 10) else { return false }
            option.tap()
            if firstSeen(2.5, { lessonButtonReads("Continue") }) != nil { return true }
        }
        return false
    }

    /// Leaves a lesson's results for the Learn tab ("Done"; never the reminder, which asks for notifications).
    private func leaveResults() throws {
        var done = element("lesson.done")
        if !done.waitForExistence(timeout: 15) { done = app.buttons["Done"].firstMatch }
        XCTAssertTrue(done.waitForExistence(timeout: 5), "No way out of the lesson results")
        pause(1)
        done.tap()
        pause(1.5)
    }

    // MARK: Plumbing

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func pause(_ seconds: Double) { if seconds > 0 { Thread.sleep(forTimeInterval: seconds) } }

    /// Sleeps until `moment` (no-op once it has passed): pacing follows the clock, not query times.
    private func hold(until moment: Date) { pause(moment.timeIntervalSinceNow) }

    /// Polls `condition` until it holds; returns the middle of the look that first saw it (a look takes up to
    /// a second on the 3D stage, so its end is late), or nil after `timeout`.
    private func firstSeen(_ timeout: TimeInterval, _ condition: () -> Bool) -> Date? {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            let asked = Date()
            if condition() { return asked.addingTimeInterval(Date().timeIntervalSince(asked) / 2) }
            if Date() >= deadline { return nil }
            pause(0.1)
        }
    }

    /// Taps a tab until it is selected (a tap while a sheet is still closing can be swallowed);
    /// returns when the tap that took was made.
    @discardableResult
    private func tab(_ name: String) -> Date {
        let button = app.tabBars.buttons[name].firstMatch
        var tapped = Date()
        for attempt in 0..<4 {
            button.tap()
            tapped = Date()
            if button.isSelected { break }
            pause(0.8 + Double(attempt) * 0.4)
        }
        return tapped
    }

    /// Swipes until `target` is on screen, then lets the scroll come to rest (a tap during momentum is lost).
    private func reveal(_ target: XCUIElement) {
        var swipes = 0
        while !(target.exists && target.isHittable) && swipes < 6 { app.swipeUp(velocity: .slow); swipes += 1 }
        while !(target.exists && target.isHittable) && swipes < 16 { app.swipeDown(velocity: .slow); swipes += 1 }
        if swipes > 0 { pause(1.2) }
    }
}
