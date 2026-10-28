import StoreKitTest
import XCTest

/// End-to-end flows that double as a visual tour: every screen is captured so the
/// design can be reviewed from CI results.
final class TimbreUITests: XCTestCase {
    private var app: XCUIApplication!
    private var storeKit: SKTestSession!
    private var tunerEvidenceCue: URL?

    override func setUpWithError() throws {
        continueAfterFailure = true
        // The scheme's StoreKit configuration, loaded and emptied here: a UI-only run has no unit test to load it (the
        // paywall would find no products), and a run after the unit tests may inherit their purchases (Pro at launch).
        storeKit = try SKTestSession(configurationFileNamed: "Timbre")
        storeKit.resetToDefaultState()
        storeKit.clearTransactions()
        storeKit.disableDialogs = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        app.launchArguments = CaptureLocalization.launchArguments
    }

    /// The tour's language: English, unless the run asks for another to capture a localized store set
    /// (`TEST_RUNNER_TIMBRE_UI_LANGUAGE=de TEST_RUNNER_TIMBRE_UI_LOCALE=de_DE xcodebuild test …`, then
    /// `tools/marketing/screenshots.py … --locale de-DE`). Chord completion and results frames use semantic identifiers,
    /// not English captions. Other tour selectors still need localization coverage; this does not certify every frame.
    private static let language = CaptureLocalization.language

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 { shot("zz-failure-\(name)") }
        if app.state != .notRunning { app.terminate() }
    }

    /// `scene`: a store screenshot's hero moment (TIMBRE_SCENE, ios/Timbre/Root/DemoScenes.swift; it needs `pitch`).
    /// `instrument`: the catalog id the tuner opens on; `comet`: the held string is plucked again every few seconds.
    private func launch(onboarded: Bool = true, demo: Bool = true, studio: Bool = false, pitch: Bool = false, stageDebug: Bool = false,
                        scene: String? = nil, instrument: String? = nil, comet: Bool = false) {
        if let scene { app.launchEnvironment["TIMBRE_SCENE"] = scene }
        if scene == "tune-locked" {
            let cue = FileManager.default.temporaryDirectory.appendingPathComponent("timbre-lock-\(UUID().uuidString)")
            tunerEvidenceCue = cue
            app.launchEnvironment["TIMBRE_SCENE_CUE"] = cue.path
        }
        if let instrument { app.launchEnvironment["TIMBRE_SCENE_INSTRUMENT"] = instrument }
        if comet { app.launchEnvironment["TIMBRE_SCENE_COMET"] = "1" }
        if stageDebug { app.launchEnvironment["TIMBRE_STAGE_DEBUG"] = "1" }
        if pitch { app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1" }
        if onboarded { app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1" }
        if demo { app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1" }
        if studio { app.launchEnvironment["TIMBRE_STAGE_MODE"] = "studio" }
        app.launch()
        CaptureLocalization.recordLaunch(context: "iphone")
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A capture taken once the screen has come to rest (StillScreen.swift): entrances, staggers and counters done.
    private func stillShot(_ name: String, timeout: TimeInterval = 4) {
        keep(stillScreenshot(timeout: timeout), as: name)
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    /// Taps a tab, retrying while a sheet is still dismissing and swallows the tap.
    private func tabButton(_ name: String) -> XCUIElement {
        guard let label = CaptureLocalization.tabLabel(name) else {
            XCTFail("Missing capture tab fixture for \(Self.language): \(name)")
            return app.tabBars.buttons["__missing_capture_tab_fixture__"].firstMatch
        }
        return app.tabBars.buttons[label].firstMatch
    }

    private func tab(_ name: String) {
        let button = tabButton(name)
        for attempt in 0..<4 {
            button.tap()
            if button.isSelected { return }
            settle(0.8 + Double(attempt) * 0.4)
        }
    }
    private func settle(_ seconds: Double = 1.2) { Thread.sleep(forTimeInterval: seconds) }

    /// Taps an element that may vanish on its own at any moment: the frame comes from a snapshot (which throws
    /// rather than failing the test when the element is gone), and the tap goes to that point.
    private func tapIfPresent(_ target: XCUIElement) {
        guard let frame = (try? target.snapshot())?.frame, !frame.isEmpty else { return }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
    }
    /// Opens the instrument browser (the tuner's picker sheet) unless it is already up.
    private func openPicker() {
        let picker = element("instruments.done")
        if picker.exists || element("instruments.search").exists { return }
        tab("Tune")
        let button = element("tune.instrument")
        XCTAssertTrue(button.waitForExistence(timeout: 25))
        for _ in 0..<3 where !picker.exists {
            button.tap()
            _ = picker.waitForExistence(timeout: 4)
        }
        settle(1.2)
    }
    /// An instrument card in the open picker, found through its search field: scrolling the long sheet is
    /// flaky (a downward swipe at the top of the list dismisses the sheet).
    private func findInstrument(_ asset: String, search: String) -> XCUIElement {
        let card = element("instrument." + asset)
        let field = element("instruments.search")
        if field.waitForExistence(timeout: 5) {
            field.tap(); field.typeText(search); settle(1)
        }
        if !(card.exists && card.isHittable) { scrollTo(card) }
        return card
    }

    /// Swipes until the element is on screen, then lets the scroll come to rest: a tap during
    /// momentum only stops the scroll and never reaches the button.
    private func scrollTo(_ target: XCUIElement) {
        var swiped = false
        for _ in 0..<10 where !(target.exists && target.isHittable) { app.swipeUp(velocity: .slow); swiped = true }
        // The list may have been left scrolled past the target: search back up.
        for _ in 0..<20 where !(target.exists && target.isHittable) { app.swipeDown(velocity: .slow); swiped = true }
        if swiped { settle(1.2) }
    }

    /// Drags the scrolled screen until `target` sits about a third of the way down it: slow drags with a hold at the
    /// end, so no momentum carries it past.
    private func bringToUpperMiddle(_ target: XCUIElement) {
        let screen = app.frame
        guard screen.height > 0 else { return }
        for _ in 0..<4 {
            guard let frame = (try? target.snapshot())?.frame, !frame.isEmpty else { return }
            let distance = frame.minY - screen.height * 0.3
            guard abs(distance) > 30 else { return }
            // At most half the screen per drag, from a point that leaves the tab bar alone.
            let step = max(-0.5, min(0.5, distance / screen.height))
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: step > 0 ? 0.75 : 0.25))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -step * screen.height)),
                       withVelocity: .slow, thenHoldForDuration: 0.4)
            settle(0.6)
        }
    }

    /// Waits for `target` with one query every `interval` seconds instead of continuously: each query stalls the app's
    /// main thread, which is where a step played by the demo pitch does its work.
    private func waitSparingly(for target: XCUIElement, timeout: TimeInterval, every interval: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            if target.exists { return true }
            guard Date() < deadline else { return false }
            settle(interval)
        }
    }

    /// Taps a lesson explanation's Continue until the step after it is on screen. A tap that lands while the lesson is
    /// still zooming open can be dropped; the steps that follow an explanation here (the tune check, a notes step) have
    /// no Continue of their own, so its disappearance is the sign the lesson moved on.
    private func leaveExplanation() {
        let next = element("lesson.continue")
        for _ in 0..<4 {
            guard next.waitForExistence(timeout: 5) else { return }
            next.tap()
            if next.waitForNonExistence(timeout: 6) { return }
        }
        XCTFail("the lesson stayed on its explanation: Continue was tapped four times")
    }

    /// Taps Continue (once it is enabled) until the next screen's element appears: a tap during the
    /// enable animation or the page transition can be dropped.
    private func continueUntil(_ next: XCUIElement) {
        let button = element("onboarding.continue")
        for _ in 0..<4 where !next.exists {
            _ = button.waitForExistence(timeout: 3)
            if button.isEnabled { button.tap() }
            _ = next.waitForExistence(timeout: 2.5)
        }
        XCTAssertTrue(next.exists)
    }

    // MARK: App Store frames
    //
    // The captures the listing's screenshot table names (docs/ios/APP-STORE-LISTING.md, rendered by
    // tools/marketing/screenshots.py) must show what their captions say, every run. The tuner's lock, Kite Weather on
    // the highway, "Show me" and the chord come from store scenes (TIMBRE_SCENE, ios/Timbre/Root/DemoScenes.swift) that
    // put the app into that moment through its own code paths, so no shot races the demo pitch's clock ("Show me" is
    // caught mid-play on the demonstration's own clock, read from its probe, and checked against it afterwards);
    // Strum to tune hears the demo pitch's one fixed strum; the results follow a play-along the demo pitch plays clean;
    // the others are plain navigation. Every one starts from the same seeded state (`DemoData` in
    // ios/Timbre/TimbreApp.swift: a 7-day streak that counts today, level 5) and is taken once the screen has come to
    // rest (`stillScreenshot`, StillScreen.swift), after the cue that its slowest animation has finished.

    /// Keeps a store frame under its own name when it shows what its caption says. Otherwise the test fails and the
    /// picture is kept as "<name>-wrong" (for the log), so screenshots.py never frames it.
    private func storeFrame(_ name: String, picture: XCUIScreenshot? = nil, ok: Bool, _ problem: @autoclosure () -> String) {
        let picture = picture ?? XCUIScreen.main.screenshot()
        if ok {
            keep(picture, as: name)
        } else {
            XCTFail("\(name): \(problem())")
            keep(picture, as: name + "-wrong")
        }
    }

    private func keep(_ screenshot: XCUIScreenshot, as name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Every node of the app's accessibility tree from one snapshot: one query, so one stall of the app's main thread
    /// (separate queries over the 3D stage cost about a second each).
    private func appNodes() -> [XCUIElementSnapshot] {
        guard let root = try? app.snapshot() else { return [] }
        var nodes: [XCUIElementSnapshot] = []
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            nodes.append(node)
            pending.append(contentsOf: node.children)
        }
        return nodes
    }

    // MARK: Tuner

    /// Sleeps until `moment` (no-op once it has passed): pacing follows the clock, not query times.
    private func hold(until moment: Date) {
        let seconds = moment.timeIntervalSinceNow
        if seconds > 0 { Thread.sleep(forTimeInterval: seconds) }
    }

    /// The demo pitch's clock (AudioService.startDemo): from when listening started, 6 s cycles that drift in from
    /// 14 cents flat, are inside the 5-cent lock band from 2.7 s and lock 0.65 s later, at 3.35 s.
    private enum Demo {
        static let cycle = 6.0
        /// About 9 cents flat: "Tighten", the peg's turn arrow up.
        static let drifting = 1.4
    }

    /// The start of the first demo cycle (counted from `origin`) whose `offset` second is at least `lead` from now.
    private func nextCycle(from origin: Date, reaching offset: TimeInterval, lead: TimeInterval) -> Date {
        let needed = Date().addingTimeInterval(lead).timeIntervalSince(origin) - offset
        let cycles = max(0, (needed / Demo.cycle).rounded(.up))
        return origin.addingTimeInterval(cycles * Demo.cycle)
    }

    /// The tuner's UI-test probe (TIMBRE_DEBUG_STATE=1, never drawn): "stage=<3d|loading|2d> listening=<epoch s, 0 if not>
    /// lock=<1 while a lock is on screen, else 0>". `lock` is nil without the field.
    private func tunerProbe() -> (stage: String, listening: Date?, lock: Bool?) {
        guard let label = (try? element("stage.state").snapshot())?.label else { return ("", nil, nil) }
        var stage = ""
        var listening: Date?
        var lock: Bool?
        for field in label.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "stage" { stage = parts[1] }
            if parts[0] == "listening", let seconds = Double(parts[1]), seconds > 0 { listening = Date(timeIntervalSince1970: seconds) }
            if parts[0] == "lock" { lock = parts[1] == "1" }
        }
        return (stage, listening, lock)
    }

    /// Waits for the 3D model to take over from the studio render that holds the stage while it loads (the first
    /// model on a fresh simulator can take 20 s or more), then for the camera's dolly in to the headstock.
    private func waitForStage(timeout: TimeInterval = 90) -> (stage: String, listening: Date?, lock: Bool?) {
        var probe = tunerProbe()
        let started = Date()
        let deadline = started.addingTimeInterval(timeout)
        while probe.stage != "3d" && probe.stage != "2d" && Date() < deadline {
            // No probe at all (not a debug build): don't wait out the whole timeout for it.
            if probe.stage.isEmpty && Date().timeIntervalSince(started) > 15 { break }
            settle(0.5)
            probe = tunerProbe()
        }
        if probe.stage != "3d" { print("The tuner's stage is '\(probe.stage)', not 3D") }
        settle(2.5)
        return tunerProbe()
    }

    /// Whether the tuner shows a lock, read from one snapshot: at least `strings` chips read "Tuned" (the ✓ on the
    /// ones not being tuned), the selected chip among them, and the status line ("Hold it…", "Tighten…") has stepped
    /// aside for the readout's In tune badge. The badge holds after a lock while the string stays in the band, so the
    /// snapshot (taken just after the picture) sees what the picture shows. `summary` says what was seen.
    private func tunerLock(strings: Int) -> (shown: Bool, summary: String) {
        guard let tunedWord = CaptureLocalization.tuned, let inTuneWord = CaptureLocalization.inTune else {
            return (false, "Missing localized tuner-state capture fixture")
        }
        var chips: [String: (selected: Bool, tuned: Bool)] = [:]
        var status: String?
        var stage = false
        for node in appNodes() {
            if node.identifier.hasPrefix("string.") {
                let seen = chips[node.identifier] ?? (selected: false, tuned: false)
                chips[node.identifier] = (selected: seen.selected || node.isSelected, tuned: seen.tuned || (node.value as? String) == tunedWord)
            }
            if node.identifier == "tune.status" { status = node.label }
            if node.identifier == "tune.stage" { stage = true }
        }
        let tuned = chips.values.filter { $0.tuned }.count
        let selectedTuned = chips.values.contains { $0.selected && $0.tuned }
        let badge = status == nil || status == inTuneWord
        let summary = "stage shown \(stage), \(tuned) of \(chips.count) strings tuned, selected tuned \(selectedTuned), status '\(status ?? "hidden: the In tune badge")'"
        // The store frame's caption is a string standing still: the selected chip's tick and the In tune badge, both.
        return (stage && tuned >= strings && selectedTuned && badge, summary)
    }

    /// Observe the actual rendered badge state without blocking its main actor with AX queries.
    /// The same 1.5-second hold must occur inside seven seconds, with fresh samples and no gaps.
    private func lockHolds(for seconds: TimeInterval = 1.5, window: TimeInterval = 7,
                           stages: Set<String>) -> (held: Bool, summary: String) {
        guard let cue = tunerEvidenceCue else { return (false, "no lock evidence cue") }
        let trace = URL(fileURLWithPath: cue.path + ".lock")
        defer {
            if let text = try? String(contentsOf: trace, encoding: .utf8) {
                let attachment = XCTAttachment(string: text)
                attachment.name = "tuner-lock-state-evidence"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            try? FileManager.default.removeItem(at: cue)
            try? FileManager.default.removeItem(at: trace)
        }
        let start = ProcessInfo.processInfo.systemUptime
        guard FileManager.default.createFile(atPath: cue.path, contents: Data()) else {
            return (false, "could not request lock evidence")
        }
        var count = 0
        while ProcessInfo.processInfo.systemUptime <= start + window {
            let samples = (try? Data(contentsOf: trace)).map(CaptureLockEvidence.samples) ?? []
            count = samples.count
            let now = ProcessInfo.processInfo.systemUptime
            if CaptureLockEvidence.held(samples, since: start, now: now, seconds: seconds, window: window, stages: stages) {
                return (true, "fresh continuous readout lock for at least \(seconds) s (\(count) samples)")
            }
            settle(0.05)
        }
        return (false, "no fresh continuous \(seconds) s lock in \(window) s (\(count) samples)")
    }

    // MARK: Head clearance

    /// The 3D stage's head probe (TIMBRE_DEBUG_STATE=1, never drawn): "framing=<0…1> head=<points under the stage's top
    /// edge, negative when the stage cuts the head; none before the model frames it>". Nil without the probe.
    private func headProbe() -> (framing: Double, head: Double?)? {
        guard let label = (try? element("stage.head").snapshot())?.label else { return nil }
        var framing = 0.0
        var head: Double?
        for field in label.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "framing" { framing = Double(parts[1]) ?? 0 }
            if parts[0] == "head" { head = Double(parts[1]) }
        }
        return (framing, head)
    }

    /// Once the camera has dollied into the close-up (framing 0.99 or more), the whole head stands inside the stage
    /// (head ≥ 0: the stage's top edge doesn't cut it). Looked at for up to `timeout` seconds; a stage that never
    /// reaches the close-up (no model, a photo stage) or a run without the probe has nothing to check.
    private func checkHeadClear(_ name: String, timeout: TimeInterval = 12) {
        let deadline = Date().addingTimeInterval(timeout)
        var last: (framing: Double, head: Double?)?
        while Date() < deadline {
            guard let probe = headProbe() else { print("\(name): no head probe"); return }
            last = probe
            if probe.framing >= 0.99, let head = probe.head {
                XCTAssertGreaterThanOrEqual(head, 0, "\(name): the stage cuts the head (\(head) pt under its top edge, framing \(probe.framing))")
                return
            }
            settle(0.5)
        }
        let head = last?.head.map { String(format: "%.1f", $0) } ?? "none"
        print("\(name): the close-up never framed the head (framing \(last?.framing ?? 0), head \(head))")
    }

    // MARK: Reward toast

    /// When the reward toast was last handed something, from the app's probe (`debug.state`, TIMBRE_DEBUG_STATE=1):
    /// `found` is false without the probe, `latest` nil before any reward.
    private func rewardProbe() -> (found: Bool, latest: Date?) {
        guard let label = (try? element("debug.state").snapshot())?.label else { return (false, nil) }
        for field in label.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == "reward" else { continue }
            guard let seconds = Double(parts[1]), seconds > 0 else { return (true, nil) }
            return (true, Date(timeIntervalSince1970: seconds))
        }
        return (false, nil)
    }

    /// Seconds after the latest reward the toast has surely gone: two of its longest banners (2.8 s each) with their
    /// entrance and exit (RewardToast in ios/Timbre/Design/GameUI.swift).
    private static let toastQuiet = 6.5

    /// Waits the reward toast out before a capture: it is hidden from accessibility and takes no taps, so it can't be
    /// dismissed. A reward handed to it after `since` is waited out (`toastQuiet` after the latest one); with none yet
    /// and one `due` (a string's first lock earns XP about 0.3 s after the lock), until then for it first. A run without
    /// the probe waits for nothing. Few looks: each one stalls the app's main thread.
    private func waitOutRewardToast(since: Date, due: Date? = nil, timeout: TimeInterval = 30) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let probe = rewardProbe()
            guard probe.found else { return }
            if let latest = probe.latest, latest >= since {
                let clear = latest.addingTimeInterval(Self.toastQuiet)
                if Date() >= clear { return }
                hold(until: min(clear, deadline))
            } else {
                guard let due, Date() < due else { return }
                hold(until: min(due, deadline))
            }
        }
    }

    // MARK: Instrument browser

    /// Closes a paywall sheet that opened over the browser.
    private func closePaywall() {
        let close = element("paywall.close")
        guard close.exists else { return }
        tapIfPresent(close)
        _ = element("paywall.purchase").waitForNonExistence(timeout: 5)
        settle(0.8)
    }

    /// Closes the instrument browser (and a paywall over it) and waits for the sheet to go.
    private func closePicker() {
        closePaywall()
        let picker = element("instruments.done")
        for _ in 0..<3 where picker.exists {
            let done = element("instruments.done")
            if done.exists { done.tap() }
            _ = picker.waitForNonExistence(timeout: 4)
        }
        settle(0.8)
    }

    func test01Onboarding() throws {
        // The app's probe (debug.state) dates the rewards, so the tuner's picture can wait out the reward toast.
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        // The demo pitch plays the first-tune step's string (it drifts from 14 cents flat into tune).
        launch(onboarded: false, demo: false, pitch: true)
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        settle(); shot("01-onboarding-welcome")
        element("onboarding.instrument.violin.standard.4").tap(); settle(); shot("02-onboarding-instrument")
        element("onboarding.instrument.guitar.acoustic.6").tap()
        start.tap(); settle(1.5); shot("03-onboarding-experience")
        // Nothing is pre-selected: Continue waits for an answer. A beginner's path holds every page, the first chord too.
        element("onboarding.option.beginner").tap()
        // A beginner's goal starts on "Play my first songs".
        continueUntil(element("onboarding.option.songs")); settle(1.2); shot("04-onboarding-goal")
        // A guitar has strings to hold: which hand plays (right-handed until the player says otherwise).
        continueUntil(element("onboarding.option.right")); settle(1.2); shot("04b-onboarding-hand")
        let notNow = element("onboarding.microphone.skip")
        for _ in 0..<3 where !notNow.exists { element("onboarding.continue").tap(); settle(1.5) }
        XCTAssertTrue(notNow.waitForExistence(timeout: 5))
        shot("05-onboarding-microphone")
        notNow.tap()
        // "Pluck your thickest string": the stage follows the pitch and locks.
        let firstTune = element("onboarding.firsttune")
        XCTAssertTrue(firstTune.waitForExistence(timeout: 10))
        settle(1.6); shot("05a-onboarding-first-tune")
        // The lock counts as practice: the badge, the XP and day one of the streak show where Skip was.
        if element("onboarding.firsttune.reward").waitForExistence(timeout: 15) { settle(0.5); shot("05a2-onboarding-first-tune-reward") }
        // A beginner's first chord follows the first tune: the demo pitch plays it string by string, every string
        // lights, then the fact, which hands over by itself.
        if element("onboarding.firstchord").waitForExistence(timeout: 15) {
            settle(1.5); shot("05c-onboarding-first-chord")
            if element("onboarding.firstchord.done").waitForExistence(timeout: 30) {
                settle(0.8); shot("05c2-onboarding-first-chord-done")
            }
        }
        // After both wins the reminder card asks once, on a card of its own ("Later" never raises the system prompt).
        let later = element("onboarding.reminder.later")
        if later.waitForExistence(timeout: 12) {
            settle(0.8); shot("05a3-onboarding-reminder")
            tapIfPresent(later); settle(1)
        }
        let plan = element("onboarding.plan.start")
        // Never stall the tour on a page that waits for a sound: each has a way on to the same plan.
        for skip in ["onboarding.firsttune.skip", "onboarding.reminder.later", "onboarding.firstchord.done", "onboarding.firstchord.skip"] {
            if plan.waitForExistence(timeout: 8) { break }
            let button = element(skip)
            if button.exists && button.isHittable { tapIfPresent(button) }
        }
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        settle(2); shot("05b-onboarding-plan")
        plan.tap()
        let free = element("paywall.free")
        XCTAssertTrue(free.waitForExistence(timeout: 15))
        // The sheet rises, then the outcomes slide in one after another and the trial track draws itself.
        settle(0.8); stillShot("06-paywall-onboarding", timeout: 5)
        scrollTo(free)
        free.tap()
        // Onboarding hands over to Learn and opens the plan's first lesson (the first free one on the free plan).
        let close = element("lesson.close")
        XCTAssertTrue(close.waitForExistence(timeout: 20))
        settle(2); shot("06b-first-lesson")
        let closed = Date()
        close.tap(); settle(1.5)
        // The first tune already counted: the tuner shows day one of the streak, with no reward toast over it (the
        // demo pitch's first lock here earns XP within a cycle).
        tab("Tune")
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        let shown = Date()
        settle(2.5)
        waitOutRewardToast(since: closed, due: shown.addingTimeInterval(Demo.cycle + 1))
        shot("07-tune-first-run")
    }

    func test02TuneScreen() throws {
        // The tuner's probe (stage.state) says when the 3D model is up and when listening started.
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        var probe = waitForStage()
        if probe.listening == nil {
            element("listenButton").tap(); settle(0.5)
            probe = tunerProbe()
        }
        // A string drifting in, about 9 cents flat: "Tighten" and the peg's turn arrow. The demo pitch runs in 6 s
        // cycles from when listening started, so the shot is timed from that clock. (The lock, App Store frame #1,
        // comes from its own scene: test11StoreTunerLock.)
        let origin = probe.listening ?? Date()
        let cycle = nextCycle(from: origin, reaching: Demo.drifting, lead: 0.4)
        hold(until: cycle.addingTimeInterval(Demo.drifting)); shot("10-tune-3d")
        element("string.3").tap(); settle(1.5); shot("11-tune-string-selected")
        element("tune.instrument").tap(); settle(1.5); shot("12-instrument-picker")
        element("instruments.done").tap(); settle()
        element("settings.open").tap(); settle(1.5); shot("13-settings")
        // Pro upsell from inside the settings sheet presents the paywall on top of it.
        element("settings.pro").tap()
        XCTAssertTrue(element("paywall.purchase").waitForExistence(timeout: 15))
        settle(1.5); shot("16-paywall-from-settings")
        // Strum to tune is App Store frame #8, from a fresh launch of its own (test13StoreStrum), not from behind
        // these two sheets.
    }

    func test03StudioStage() throws {
        // The app's probe (debug.state) dates the rewards, so the picture can wait out the reward toast.
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        let launched = Date()
        launch(studio: true, pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        let shown = Date()
        // The demo pitch's first lock earns XP within a cycle: its toast leaves before the picture.
        settle(3)
        waitOutRewardToast(since: launched, due: shown.addingTimeInterval(Demo.cycle + 1))
        shot("14-tune-studio")
        openPicker()
        element("instruments.chromatic").tap(); settle(2); shot("15-tune-chromatic")
    }

    func test04PracticeTour() throws {
        launch()
        tab("Practice"); settle(1.5); shot("20-practice-hub")
        // The Today card sits above the tools: bring the metronome into view first.
        scrollTo(element("practice.metronome"))
        element("practice.metronome").tap(); settle(1.2); shot("21-metronome")
        element("metronome.start").tap(); settle(1.0); shot("22-metronome-running")
        element("metronome.start").tap()
        app.navigationBars.buttons.firstMatch.tap(); settle()
        scrollTo(element("practice.ear"))
        element("practice.ear").tap(); settle(2); shot("23-ear-training")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        scrollTo(element("practice.voice"))
        element("practice.voice").tap(); settle(1.5); shot("24-voice-range")
    }

    func test05OtherTabs() throws {
        launch()
        // The instrument browser is the tuner's picker sheet (the Songs tab took the Instruments tab's place).
        openPicker(); settle(0.8); shot("30-instruments")
        // The Guitar family filter: a full grid of guitars, each on its own stage, under the title bar. A tap on the
        // family chip is deterministic; scrolling the sheet could dismiss it or tap a Pro card. (Frame #7 was this grid
        // until Strum to tune took its place: test13StoreStrum.)
        let guitars = element("instruments.family.guitar")
        if guitars.waitForExistence(timeout: 5) { guitars.tap(); settle(1.5) }
        shot("31-instruments-scrolled")
        closePicker()
        // App Store frame #9: Progress, with nothing over it, once its cards have come in.
        tab("Progress"); settle(0.8)
        let picture = stillScreenshot()
        let progress = tabButton("Progress")
        let front = progress.exists && progress.isSelected && !element("paywall.purchase").exists && !element("instruments.done").exists
        storeFrame("32-journey", picture: picture, ok: front, "Progress isn't the screen in front (the browser or a paywall is still up)")
        app.swipeUp(); settle(); shot("33-journey-scrolled")
    }

    func test06PurchaseUnlocksPro() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch()
        tab("Practice"); settle()
        scrollTo(element("practice.drone"))
        element("practice.drone").tap()
        let purchase = element("paywall.purchase")
        let found = purchase.waitForExistence(timeout: 15)
        if !found { print("STATE after drone: \(element("debug.state").label)") }
        XCTAssertTrue(found)
        settle(2); shot("40-paywall")
        scrollTo(purchase)
        purchase.tap()
        // StoreKit testing can take a minute on a busy runner, and the Play tab stays in the tree behind the
        // sheet the whole time: wait for the sheet itself to go.
        if !purchase.waitForNonExistence(timeout: 150) { print("STATE after purchase: \(element("debug.state").label)") }
        XCTAssertTrue(element("practice.drone").waitForExistence(timeout: 20))
        settle(2)
        scrollTo(element("practice.drone"))
        element("practice.drone").tap(); settle(1.5); shot("41-drone")
        element("drone.start").tap(); settle(1.5); shot("42-drone-running")
        element("drone.start").tap()
        app.navigationBars.buttons.firstMatch.tap(); settle()
        scrollTo(element("practice.chords"))
        element("practice.chords").tap(); settle(1.5); shot("43-chords")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        scrollTo(element("practice.scales"))
        element("practice.scales").tap(); settle(1.5); shot("44-scales")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        // Progress with Pro: its top (streak, level, coach, week) is the same on any plan, so the picture is taken on
        // the card Pro adds, the tuning accuracy chart, and kept only when that card (not the Pro teaser) is there.
        tab("Progress"); settle(1.5)
        let chart = element("journey.accuracy")
        if chart.waitForExistence(timeout: 5) {
            scrollTo(chart)
            bringToUpperMiddle(chart)
        }
        let teaser = element("journey.accuracy.locked").exists
        storeFrame("45-journey-pro", picture: stillScreenshot(), ok: chart.exists && chart.isHittable && !teaser,
                   "Progress shows \(teaser ? "the Pro teaser" : "no tuning accuracy card") after the purchase")
        tab("Practice"); settle()
        scrollTo(element("practice.intonation"))
        element("practice.intonation").tap(); settle(1.5); shot("46-intonation")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        tab("Tune"); settle()
        element("tune.instrument").tap(); settle(1.5)
        element("tunings.custom").tap(); settle(1.5); shot("47-custom-tuning")
        XCTAssertTrue(element("custom.save").waitForExistence(timeout: 10))
        element("custom.save").tap(); settle(1.5); shot("48-custom-tuning-saved")
        // Instruments on their 3D stage: the mandolin (Pro, open now), then the violin and cello (free on any plan). Each
        // close-up keeps the whole head inside the stage (the head probe, stage.head).
        for (asset, search, name) in [("13_mandolin_mandolin", "Mandolin", "49-tune-mandolin-3d"), ("17_bowed_strings_violin", "Violin", "49b-tune-violin-3d"), ("19_bowed_strings_cello", "Cello", "49c-tune-cello-3d")] {
            // The picker is still up after saving the custom tuning; later rounds open it from the tuner.
            openPicker()
            let card = findInstrument(asset, search: search)
            card.tap(); _ = waitForStage(); shot(name)
            checkHeadClear(name)
        }
    }

    func test08PhotoStage() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        openPicker()
        let ukulele = findInstrument("10_ukulele_soprano_ukulele", search: "Soprano")
        let picked = Date()
        ukulele.tap()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        // A new instrument's first lock earns XP within a demo cycle, and so does a new string's: each picture waits
        // its toast out.
        settle(7)
        waitOutRewardToast(since: picked, due: picked.addingTimeInterval(Demo.cycle + 1.5))
        shot("17-tune-photo-stage")
        let selected = Date()
        element("string.2").tap(); settle(3)
        waitOutRewardToast(since: selected, due: selected.addingTimeInterval(Demo.cycle + 1.5))
        shot("18-tune-photo-stage-string")
        openPicker()
        let bass = findInstrument("06_bass_4_string_p_bass", search: "4-string")
        bass.tap(); _ = waitForStage(); shot("19-tune-bass-3d")
    }

    func test09LearnChordLesson() throws {
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        // App Store frame #6, once Learn's cards have come in (and any reward banner from the tune has gone).
        tab("Learn"); settle(1); stillShot("50-learn", timeout: 5)
        // The lesson zooms open on E minor's demonstration: the fingertips land one by one, the chord rings across the
        // strings, then "Your turn" (or, when the demo pitch plays it back, "Nice") shows under the neck. The picture
        // waits for that line: every fingertip is down and the strings have stopped shimmering.
        element("learn.continue").tap()
        // Do not snapshot accessibility while the main-actor demonstration is running: native tour
        // evidence showed individual exists queries stalling it for 11–16 seconds. Allow the actual
        // two-finger Em sequence to run hands-off first. The slowest first-model path is
        // settle(0.7) + patience(5) + lead(0.85) + two fingers(0.9) + ring tail(1.8) = 9.25 s.
        // This does not force completion; the same unique cue and its real state must still appear.
        settle(10)
        let turnCue = element("lesson.explain.turnCue")
        XCTAssertTrue(turnCue.waitForExistence(timeout: 12))
        if Self.language.hasPrefix("en") {
            XCTAssertTrue(["Your turn — play it back", "Nice — that’s right."].contains(turnCue.label),
                          "The identified cue must expose the completed demonstration's real teaching state")
        }
        stillShot("51-lesson-explain", timeout: 2.5)
        // The lesson zooms open: a tap during the transition can be dropped, so tap until the tune check shows.
        let skip = element("lesson.tunecheck.skip")
        for _ in 0..<4 where !skip.exists { element("lesson.continue").tap(); _ = skip.waitForExistence(timeout: 3) }
        settle(1); shot("52-lesson-tunecheck")
        // The tune check is covered by its own screenshot; skip the rest of it to keep the run short. The demo
        // pitch tunes each string in turn, so the check can finish on its own while the tap is on its way.
        tapIfPresent(skip)
        // The demo pitch plays the chord's strings and the step hands over to the strum explainer by itself. (The
        // chord with every string lit, App Store frame #3, comes from its own scene: test12StoreChord.)
        let next = element("lesson.continue")
        XCTAssertTrue(next.waitForExistence(timeout: 30))
        settle(1.5); shot("53-lesson-strum-explain")
        next.tap(); settle(1.2); shot("54-lesson-strum-ready")
        element("lesson.continue").tap(); settle(5); shot("55-lesson-strum")
    }

    func test10PlayAlongLesson() throws {
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        // Songs: the song of the day opens the same lesson player as Learn.
        tab("Songs")
        let hero = element("songs.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        // App Store frame #5, once the shelves have come in.
        settle(1); stillShot("63-songs", timeout: 5)
        hero.tap()
        let close = element("lesson.close")
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        settle(1.5); shot("64-songs-lesson")
        close.tap(); settle(1.5)
        tab("Learn"); settle(2)
        let node = element("learn.lesson.gtr-1-2")
        scrollTo(node)
        node.tap(); settle(1.5)
        leaveExplanation()
        // Today's tune check comes first unless an earlier flow already did it (test09 does, on the same simulator):
        // skip it. With the demo pitch it can also finish by itself while the tap is on its way.
        let skip = element("lesson.tunecheck.skip")
        if skip.waitForExistence(timeout: 2) {
            tapIfPresent(skip)
            _ = skip.waitForNonExistence(timeout: 20)
        }
        settle(1.5); shot("56-lesson-notes")
        // Two note steps finish on their own with the demo pitch, then a quiz and a listening question. Hands off while
        // they play: every query of the screen stalls the app's main thread for a second or more, and the demo pitch,
        // the hold that ticks each note off and the hand-over to the next step all run on that thread. Polling from
        // the start stretched the two steps to 13 s on a quiet runner and past 25 s on a busy one.
        settle(6)
        XCTAssertTrue(waitSparingly(for: element("lesson.option.0"), timeout: 60), "the note steps didn't finish on the demo pitch")
        // The quiz slides in from the side: a tap resolved mid-slide lands on the tile beside the right answer.
        settle(1.2)
        element("lesson.option.0").tap(); settle(1); shot("57-lesson-quiz")
        element("lesson.continue").tap(); settle(2)
        element("lesson.option.1").tap(); settle(1); shot("58-lesson-listen")
        element("lesson.continue").tap(); settle(1.5)
        guard waitForPlayAlongReady() else { return }
        shot("59-along-ready")
        // Six notes occupy twelve beats at 60 BPM, plus a four-beat count-in and
        // the 1.2-second session tail: 17.2 seconds, not the old ten-second estimate.
        // Pictures are hands-off; leave 21 seconds before the first accessibility query
        // so the demo pitch can complete without a snapshot stalling its readings.
        element("lesson.continue").tap(); settle(7); shot("60-along-playing")
        settle(14)
        XCTAssertTrue(element("along.again").waitForExistence(timeout: 30))
        settle(1); shot("61-along-done")
        // App Store frame #7. The results land in order: the stars, the coach, the XP counting up, then the level bar
        // (labelled "Level N") fills under them. Its arrival means the XP has finished counting; the badges that pop in
        // after it and the bar's fill settle before the picture. Kept only with three stars (the row reads "3 of 3 stars").
        guard openResultsForCapture() else { return }
        let results = stillScreenshot(timeout: 3)
        let headline = element("lesson.results.stars.3").exists
        let room = resultsFit()
        storeFrame("62-lesson-results", picture: results, ok: headline && room.fits,
                   headline ? room.summary
                            : "the results don't show three stars: the play-along wasn't played clean")
    }

    /// A prior check's day can expire while the questions are open. The real check may then appear before
    /// this microphone step, not just after the explanation. Let demo pitch finish it hands-off: a coordinate
    /// tap on its disappearing skip could hit the next screen's Start in the same place.
    private func waitForPlayAlongReady() -> Bool {
        guard let startLabel = CaptureLocalization.lessonButtonLabel("Start") else {
            return playAlongReadinessFailed("Missing localized play-along Start fixture")
        }
        for observation in 0...3 {
            let viewport = app.frame
            let controls = appNodes().filter {
                !$0.frame.isEmpty && viewport.contains($0.frame)
            }.map {
                CapturePlayAlongReadiness.Control(identifier: $0.identifier, label: $0.label, enabled: $0.isEnabled)
            }
            let stage = CapturePlayAlongReadiness.observed(controls, startLabel: startLabel)
            if stage == .ready {
                guard element("lesson.continue").isHittable else {
                    return playAlongReadinessFailed("The verified play-along Start is not hittable")
                }
                print("TIMBRE_PLAYALONG_READY observation=\(observation)")
                return true
            }
            guard observation < 3 else { break }
            switch stage {
            case .tuneCheck:
                print("TIMBRE_PLAYALONG_OPTIONAL_TUNECHECK observation=\(observation)")
                shot("playalong-optional-tunecheck-\(observation)")
                // Six strings need their real holds and handovers. Do not poll the main-thread pitch reader.
                settle(10)
            case .unexpected:
                // A page transition may expose neither stage, or both. No action on an unidentified stage.
                settle(1.5)
            case .ready:
                break
            }
        }
        return playAlongReadinessFailed("Expected the actual play-along Start after at most three bounded waits")
    }

    private func playAlongReadinessFailed(_ message: String) -> Bool {
        XCTFail(message)
        shot("59-along-ready-wrong")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "59-along-ready-wrong-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        return false
    }

    /// The violin page's results frame: "Open-string checkup" (vln-1-6, free), opened on its play-along through the
    /// `song-perform` scene (DemoScenes.swift opens a lesson on its last step), played clean by the demo pitch, then its
    /// results, kept only with three stars and room above the buttons, as frame #7 is. Hands off while the take runs (a
    /// query stalls the app's main thread, and a note heard late is a miss).
    func test19StoreViolinResults() throws {
        app.launchEnvironment["TIMBRE_SCENE_SONG"] = "vln-1-6"
        launch(pitch: true, scene: "song-perform")
        XCTAssertTrue(element("lesson.close").waitForExistence(timeout: 30), "The violin checkup never opened")
        settle(1.2)
        let start = element("lesson.continue")
        // This scene opens directly on the play-along. Its enabled primary control is the start action;
        // matching an English caption would unnecessarily wait in every other language.
        for _ in 0..<40 where !(start.exists && start.isEnabled) { settle(0.5) }
        XCTAssertTrue(start.exists && start.isEnabled, "The play-along start control was not ready")
        start.tap()
        // This checkup now has 28 beats at 60 BPM, plus a four-beat count-in and
        // the 1.2-second session tail. Do not poll accessibility during the take:
        // simulator snapshots stall the demo pitch's main-thread readings.
        // The source-contract test below guards this quiet 40-second interval.
        settle(40)
        XCTAssertTrue(element("along.again").waitForExistence(timeout: 30), "The violin play-along never finished")
        settle(1)
        guard openResultsForCapture() else { return }
        let results = stillScreenshot(timeout: 3)
        let headline = element("lesson.results.stars.3").exists
        let room = resultsFit()
        storeFrame("62b-lesson-results-violin", picture: results, ok: headline && room.fits,
                   headline ? room.summary
                            : "the violin results don't show three stars: the play-along wasn't played clean")
    }

    /// A completed take can still be settling when Continue appears. Retry only that
    /// navigation control, never the performance or its grade, and stop once results exist.
    private func openResultsForCapture() -> Bool {
        let result = element("lesson.results.level")
        let button = element("lesson.continue")
        for attempt in 1...3 where !result.exists {
            if button.waitForExistence(timeout: 2) && button.isEnabled && button.isHittable {
                button.tap()
            }
            if result.waitForExistence(timeout: 6) {
                print("TIMBRE_RESULTS_OPENED attempt=\(attempt)")
                return waitForSettledResults()
            }
        }
        guard result.exists else {
            XCTFail("The completed take did not open lesson results after three Continue attempts")
            shot("lesson-results-navigation-wrong")
            return false
        }
        return waitForSettledResults()
    }

    /// A level label appears before the reveal finishes. Wait for the real rewards and burst to settle,
    /// without replacing the earned stars, timing, or the captured pixels.
    private func waitForSettledResults() -> Bool {
        guard waitSparingly(for: element("lesson.results.settled"), timeout: 20) else {
            XCTFail("The real lesson result reveal did not finish before capture")
            shot("lesson-results-unsettled-wrong")
            return false
        }
        return true
    }

    func testCaptureLocalizationNavigationFixture() {
        for tab in ["Tune", "Learn", "Songs", "Practice", "Progress"] {
            XCTAssertNotNil(CaptureLocalization.tabLabel(tab), "Missing tab \(tab) for \(Self.language)")
            XCTAssertFalse(CaptureLocalization.tabLabel(tab)?.isEmpty ?? true)
        }
        XCTAssertNil(CaptureLocalization.tabLabel("not-a-tab"))
        XCTAssertNotNil(CaptureLocalization.tuned)
        XCTAssertNotNil(CaptureLocalization.inTune)
    }

    func testStoreResultsBoundsCalculation() {
        XCTAssertEqual(CaptureFrameBounds.safeBottom(viewportBottom: 780, buttonsTop: 788, fadeHeight: 0), 780)
        XCTAssertEqual(CaptureFrameBounds.safeBottom(viewportBottom: 780, buttonsTop: 788, fadeHeight: 28), 752)
        XCTAssertTrue(CaptureFrameBounds.fits(contentBottom: 771, safeBottom: 780))
        XCTAssertFalse(CaptureFrameBounds.fits(contentBottom: 771, safeBottom: 752))
        XCTAssertFalse(CaptureFrameBounds.fits(contentBottom: 782, safeBottom: 780))
        XCTAssertNil(CaptureFrameBounds.safeBottom(viewportBottom: 0, buttonsTop: 788, fadeHeight: 0))
        XCTAssertNil(CaptureFrameBounds.safeBottom(viewportBottom: .infinity, buttonsTop: 788, fadeHeight: 0))
    }

    /// Whether the results' first screen fits above the pinned buttons (LessonResults): the Share pill and the level bar
    /// end above the actual visible viewport and, only when active, its bottom fade. The previous unconditional
    /// 36-point allowance falsely rejected intact translated layouts whose fade was off. Read from one snapshot.
    private func resultsFit() -> (fits: Bool, summary: String) {
        let nodes = appNodes()
        func frame(_ id: String) -> CGRect? { nodes.first { $0.identifier == id }?.frame }
        let buttons = [frame("lesson.next"), frame("lesson.done")].compactMap { $0?.minY }.min()
        let level = frame("lesson.results.level")
        let share = frame("lesson.share")
        guard let buttons, let level else {
            return (false, "the results show no level bar or no buttons (level \(level != nil), buttons \(buttons != nil))")
        }
        guard let probe = nodes.first(where: { $0.identifier == "lesson.results.layout" })?.label else {
            return (false, "the actual results viewport/fade probe is missing")
        }
        var fields: [String: Double] = [:]
        for token in probe.split(separator: " ") {
            let pair = token.split(separator: "=", maxSplits: 1)
            if pair.count == 2, let value = Double(pair[1]) { fields[String(pair[0])] = value }
        }
        guard let viewport = fields["bottom"], let fade = fields["fade"],
              let clear = CaptureFrameBounds.safeBottom(viewportBottom: viewport, buttonsTop: Double(buttons), fadeHeight: fade) else {
            return (false, "the actual results viewport/fade probe is invalid: \(probe)")
        }
        let lowest = Double(max(level.maxY, share?.maxY ?? 0))
        let fits = CaptureFrameBounds.fits(contentBottom: lowest, safeBottom: clear)
        let details = "Share bottom=\(share?.maxY ?? 0), level bottom=\(level.maxY), viewport=\(viewport), fade=\(fade), buttons=\(buttons), safe bottom=\(clear), fits=\(fits)"
        print("TIMBRE_RESULTS_BOUNDS \(details)")
        return (fits, details)
    }

    /// App Store frame #1 through the `tune-locked` scene (ios/Timbre/Root/DemoScenes.swift): the demo pitch plays the
    /// selected string steadily in tune, so the tuner's own tracker locks the two lowest strings (✓ on their chips), then
    /// the third, which stays locked: solid chip, In tune badge, its peg ringed and ticked on the 3D headstock. With
    /// `comet` the scene plucks that string again every 4 s, and the picture is caught mid-comet, its lock shimmer
    /// running along the string (`cometPicture`). Nothing races a clock: the test keeps its hands off while the holds
    /// run (a query stalls the app's main thread, and a gap of more than 150 ms in the readings starts the 0.65 s hold
    /// again).
    func test11StoreTunerLock() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        // A still frame must keep the actual lock, not reselect the string during the later accessibility snapshot.
        launch(pitch: true, scene: "tune-locked")
        storeFrame("10b-tune-locked", tuner: lockedTunerFrame(strings: 3))
    }

    /// The violin page's lead frame (a Custom Product Page): the same scene on the 3D violin, G, D and A locked (the
    /// third held, mid-comet).
    func test16StoreViolinStage() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true, scene: "tune-locked", instrument: "violin.standard.4", comet: true)
        storeFrame("49d-tune-violin-locked", tuner: lockedTunerFrame(strings: 3))
    }

    /// The cello page's lead frame (a Custom Product Page): the same scene on the 3D cello, C, G and D locked (the third
    /// held, mid-comet).
    func test20StoreCelloStage() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true, scene: "tune-locked", instrument: "cello.standard.4", comet: true)
        storeFrame("49e-tune-cello-locked", tuner: lockedTunerFrame(strings: 3))
    }

    /// The ukulele page's lead frame: the same scene on the soprano ukulele's stage (its photograph until a 3D model
    /// ships), G, C and E locked.
    func test21StoreUkuleleStage() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true, scene: "tune-locked", instrument: "ukulele.soprano.4", comet: true)
        storeFrame("17b-tune-ukulele-locked", tuner: lockedTunerFrame(strings: 3, stages: ["3d", "2d"]))
    }

    private func storeFrame(_ name: String, tuner: (picture: XCUIScreenshot, problem: String)) {
        storeFrame(name, picture: tuner.picture, ok: tuner.problem.isEmpty, tuner.problem)
    }

    /// The tuner's lock as a store frame: the picture (mid-comet when the burst caught one, else the settled lock) and
    /// why it isn't the frame ("" when it is). `stages`: the stages the frame may show ("3d" the model; "2d" a photo
    /// stage, for an instrument without a model).
    private func lockedTunerFrame(strings: Int, stages: Set<String> = ["3d"]) -> (picture: XCUIScreenshot, problem: String) {
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        let stage = waitForStage().stage
        var picture = XCUIScreen.main.screenshot()
        guard stages.contains(stage) else { return (picture, "the tuner's stage is '\(stage)', not \(stages.sorted().joined(separator: " or "))") }
        var problem = ""
        for attempt in 0..<3 {
            // Hands off: the scene's locks land and the camera settles on the third peg; then the reward toast (each
            // string's first lock earns XP) is waited out.
            settle(attempt == 0 ? 7 : 3)
            if attempt == 0 { waitOutRewardToast(since: .distantPast) }
            if let readout = readoutRegion(), let comet = cometPicture(readout: readout) {
                picture = comet.picture
                print("TUNER FRAME: mid-comet, \(comet.note)")
            } else {
                picture = XCUIScreen.main.screenshot()
                print("TUNER FRAME: no comet caught; the settled lock")
            }
            let lock = tunerLock(strings: strings)
            if lock.shown { problem = ""; break }
            problem = "no lock on screen: " + lock.summary
        }
        // A lock on screen stays there while the string stays in the band (the In tune badge doesn't flicker).
        if problem.isEmpty {
            let hold = lockHolds(stages: stages)
            if !hold.held { problem = "the tuner's lock didn't stay on screen for 1.5 s: " + hold.summary }
            // The saved frame must still show the lock after its continuous-state proof.
            picture = XCUIScreen.main.screenshot()
            let ending = tunerLock(strings: strings)
            if !ending.shown { problem = "lock not visible after observation: " + ending.summary }
            XCTAssertTrue(hold.held, "the tuner's lock didn't stay on screen for 1.5 s: \(hold.summary)")
        }
        return (picture, problem)
    }

    /// The tuner's readout (the note, its badge and meter) as a fraction of the screen: from under the AUTO / MANUAL
    /// control down to the string chips. One snapshot; nil without the control.
    private func readoutRegion() -> CGRect? {
        let nodes = appNodes()
        let screen = app.frame
        guard screen.height > 0, let control = nodes.first(where: { $0.identifier == "tune.detection" })?.frame else { return nil }
        let chips = nodes.filter { $0.identifier.hasPrefix("string.") }.map { $0.frame.minY }.min() ?? screen.height * 0.85
        guard chips - control.maxY > 40 else { return nil }
        return CGRect(x: 0.1, y: control.maxY / screen.height, width: 0.8, height: (chips - control.maxY) / screen.height)
    }

    /// The lock shimmer caught mid-run. The `comet` scene plucks the held string again every 4 s; the tracker locks it
    /// again 0.65 s later and the shimmer runs from its peg along the string. A burst of pictures over more than one
    /// period, hands off; the readout's own change (the In tune badge stepping aside while the hold runs) dates the
    /// pluck, and the picture kept is the one nearest `cometAim` after the lock with the readout back as it rests (In
    /// tune). Nil when the burst saw no pluck.
    private func cometPicture(readout: CGRect) -> (picture: XCUIScreenshot, note: String)? {
        var burst: [(time: Date, shot: XCUIScreenshot, readout: [UInt8])] = []
        let end = Date().addingTimeInterval(5.6)
        while Date() < end && burst.count < 48 {
            let time = Date()
            let shot = XCUIScreen.main.screenshot()
            burst.append((time, shot, StillScreen.thumbnail(shot.image.cgImage, region: readout)))
        }
        guard burst.count >= 8, let rest = StillScreen.medoid(burst.map { $0.readout }) else { return nil }
        let changed = burst.map { StillScreen.motion($0.readout, rest) > Self.cometChange }
        guard let pluck = changed.indices.first(where: { $0 > 0 && changed[$0] && !changed[$0 - 1] }) else { return nil }
        let locked = burst[pluck].time.addingTimeInterval(0.65)
        let aim = locked.addingTimeInterval(Self.cometAim)
        let settled = burst.indices.filter { $0 > pluck && burst[$0].time >= locked && !changed[$0] }
        guard let best = settled.min(by: { abs(burst[$0].time.timeIntervalSince(aim)) < abs(burst[$1].time.timeIntervalSince(aim)) }) else { return nil }
        let after = burst[best].time.timeIntervalSince(burst[pluck].time)
        return (burst[best].shot, String(format: "%.2f s after the pluck (%ld pictures)", after, burst.count))
    }

    /// Seconds after the lock the comet is at its brightest, partway along the string (LockShimmer runs 1.15 s, longer in
    /// the store scenes).
    private static let cometAim = 0.35
    /// The readout's mean change (grey levels) that marks the hold after a pluck.
    private static let cometChange = 2.5

    /// App Store frame #3 through the `lesson-chord` scene (DemoScenes.swift): "Your first chord: E minor" opens on its
    /// chord step, the demo pitch plays the chord string by string, and the step stays on "Every string rings" with
    /// every string lit instead of handing over to the next step.
    func test12StoreChord() throws {
        launch(pitch: true, scene: "lesson-chord")
        // Leave the six strings quiet while the scene loads and hears them. A busy
        // software-rendered simulator can need longer; sparse snapshots avoid starving
        // the demo pitch as rapid waitForExistence polling did.
        settle(45)
        var complete = false
        var heard: Set<Int> = []
        var checkCount = 0
        var physicalOrder = false
        for attempt in 0..<6 {
            let nodes = appNodes()
            let ringing = nodes.contains { $0.identifier == "lesson.chord.complete" }
            let checks = nodes.filter { $0.identifier.hasPrefix("lesson.chord.string.") }
            heard = Set((1...6).filter { number in
                checks.contains { $0.identifier == "lesson.chord.string.\(number).heard" }
            })
            checkCount = checks.count
            let numbersLeftToRight = checks.sorted { $0.frame.midX < $1.frame.midX }.compactMap { node in
                Int(node.identifier.split(separator: ".").dropFirst(3).first ?? "")
            }
            physicalOrder = numbersLeftToRight == [6, 5, 4, 3, 2, 1]
            complete = ringing && checks.count == 6 && heard == Set(1...6)
            if complete { break }
            if attempt < 5 { settle(10) }
        }
        // The scene holds its completed chord; capture after confirmation, never approve
        // an earlier incomplete picture using a later successful snapshot.
        settle(1.2)
        storeFrame("52b-lesson-chord", picture: XCUIScreen.main.screenshot(), ok: complete && physicalOrder,
                   "\(heard.count) of 6 strings heard; \(checkCount) checks visible; physical string order correct: \(physicalOrder)")
    }

    /// App Store frame #8: Strum to tune, every string of the guitar read from one strum (polyphonic, the tuner no
    /// rival has). Under the demo pitch the screen hears one fixed strum a second after it opens (`StrumDemo` in
    /// Timbre/Tune/StrumModel.swift): A2 12 cents flat (the string to tune first), E4 8 sharp, the other four in tune
    /// and B3 marked as an estimate. Nothing races a clock: the reading never changes, so the picture only waits for
    /// the "Fine-tune A2" button and for the strum's ring (1.8 s) to die away so the lanes stand still. It opens from
    /// a fresh launch, straight from the tuner, so no sheet is still on its way out behind it.
    func test13StoreStrum() throws {
        launch(pitch: true)
        let strum = element("tune.strum")
        XCTAssertTrue(strum.waitForExistence(timeout: 25))
        let close = element("strum.close")
        for _ in 0..<3 where !close.exists {
            if strum.exists && strum.isHittable { strum.tap() }
            _ = close.waitForExistence(timeout: 4)
        }
        let read = element("strum.finetune").waitForExistence(timeout: 10)
        // The reading lands about a second after the screen opens; its ring dies away 1.8 s after the strum's attack.
        settle(1.2)
        let picture = stillScreenshot(timeout: 4)
        let summaryNode = try? element("strum.summary.tune").snapshot()
        let summary = summaryNode?.label ?? ""
        let covered = element("paywall.purchase").exists || element("instruments.done").exists
        storeFrame("11b-tune-strum", picture: picture, ok: read && summaryNode != nil && !covered,
                   "the strum screen reads '\(summary)' (Fine-tune button: \(read), a sheet over it: \(covered)), not the demo strum")
    }

    /// App Store frame #2: Kite Weather opens at its first chorus (zero-based bar 12).
    /// Earlier notes are played by the existing scene. A still-only barrier holds the actual take
    /// after one more bar, so its score, lyric cue and runway cannot race screenshot delivery.
    /// Semantics bracket the image; all four HUD/lyric regions must still match.
    func test14StoreSongPerform() throws {
        // Start at the first chorus, leaving enough real music for both capture and validation.
        app.launchEnvironment["TIMBRE_SCENE_BAR"] = "12"
        app.launchEnvironment["TIMBRE_SCENE_STILL"] = "1"
        let cue = FileManager.default.temporaryDirectory.appendingPathComponent("timbre-take-\(UUID().uuidString)")
        app.launchEnvironment["TIMBRE_SCENE_CUE"] = cue.path
        launch(pitch: true, scene: "song-perform")
        storePerformFrame("65-song-perform", cue: cue, song: "Kite Weather", chorus: ["kite weather", "let it climb", "summer winds"])
    }

    /// The violin page's second frame: Jingle Bells from the violin songbook (free) on the runway, its last chorus
    /// lighting up, through the same `song-perform` scene and the same checks as frame #2.
    func test18StoreViolinSong() throws {
        app.launchEnvironment["TIMBRE_SCENE_SONG"] = "vln-sb-song-jingle-bells"
        app.launchEnvironment["TIMBRE_SCENE_BAR"] = "42"
        app.launchEnvironment["TIMBRE_SCENE_STILL"] = "1"
        let cue = FileManager.default.temporaryDirectory.appendingPathComponent("timbre-take-\(UUID().uuidString)")
        app.launchEnvironment["TIMBRE_SCENE_CUE"] = cue.path
        launch(pitch: true, scene: "song-perform")
        storePerformFrame("65b-song-perform-violin", cue: cue, song: "Jingle Bells", chorus: ["jingle bells", "jingle all the way", "what fun"])
    }

    /// Where a performance's bottom button sits, as fractions of the screen: the stage's Perform (mint, mean grey about
    /// 180) and the take's Stop (dark, about 25) both fill this band across a phone.
    private static let takeButton = CGRect(x: 0.1, y: 0.895, width: 0.8, height: 0.04)
    /// How long the take has been on screen when its pictures are taken: about 4.5 s in, its hook line in the light.
    private static let takeHold: TimeInterval = 4.5

    /// Read the current performance state, then choose a stable pair without an unnecessary
    /// six-pair delay. The HUD and lyric region must all be present and stable.
    private func storePerformFrame(_ name: String, cue: URL, song: String, chorus: [String]) {
        defer {
            let events = URL(fileURLWithPath: cue.path + ".events")
            if let data = try? Data(contentsOf: events), let text = String(data: data, encoding: .utf8) {
                let attachment = XCTAttachment(string: text)
                attachment.name = name + "-timing"
                attachment.lifetime = .keepAlways
                add(attachment)
                print("TIMBRE_PERFORM_TIMING \(text)")
            }
            try? FileManager.default.removeItem(at: cue)
            try? FileManager.default.removeItem(at: events)
        }
        let opened = element("lesson.close").waitForExistence(timeout: 30)
        // Finish the initial AX lookup before releasing the scene. During startup/playing,
        // screenshot-only observation leaves the main actor free for the real demo take.
        guard opened, FileManager.default.createFile(atPath: cue.path, contents: Data()) else {
            storeFrame(name, ok: false, "the lesson did not open or its capture cue could not be written")
            return
        }
        print("TIMBRE_PERFORM_CUE epoch=\(Date().timeIntervalSince1970)")
        let playing = waitForDark(Self.takeButton, hold: Self.takeHold, timeout: 40)
        let held = waitSparingly(for: element("performance.capture.frozen"), timeout: 30)
        // The explicit still barrier stops the actual take, not its displayed numbers alone.
        // Video scenes do not request it. Wait for any pre-barrier transition to settle.
        if held { settle(1) }
        // Resolve semantics and bounds before capturing, then stop on the first stable pair.
        // The previous six-pair burst read a later verse while validating an earlier chorus image.
        let screen = app.frame
        var combo = 0
        var words = ""
        var hud: CGRect?
        var score: CGRect?
        var lyrics: CGRect?
        var sectionIdentifier: String?
        var heldBeat: String?
        for node in appNodes() {
            if node.identifier.hasPrefix("performance.combo.") {
                combo = Int(node.identifier.dropFirst("performance.combo.".count)) ?? 0
                hud = node.frame
            }
            if node.identifier.hasPrefix("performance.lyrics.section."), let value = node.value as? String {
                sectionIdentifier = node.identifier
                words = value.lowercased()
                lyrics = node.frame
            }
            if node.identifier == "performance.score" { score = node.frame }
            if node.identifier == "performance.capture.frozen" { heldBeat = node.value as? String }
        }
        var regions = hudRegions(hud: hud, score: score, screen: screen)
        if let lyrics, !lyrics.isEmpty, lyrics.minX.isFinite, lyrics.minY.isFinite,
           lyrics.width.isFinite, lyrics.height.isFinite,
           screen.width > 0, screen.height > 0,
           screen.insetBy(dx: -1, dy: -1).contains(lyrics) {
            regions.append(CGRect(x: lyrics.minX / screen.width, y: lyrics.minY / screen.height,
                                  width: lyrics.width / screen.width, height: lyrics.height / screen.height))
        }
        var picture: XCUIScreenshot?
        var last: XCUIScreenshot?
        if opened && playing && held && combo >= 8 && chorus.contains(where: { words.contains($0) }) && regions.count == 4 {
            for _ in 0..<6 {
                let first = XCUIScreen.main.screenshot()
                Thread.sleep(forTimeInterval: 0.12)
                let second = XCUIScreen.main.screenshot()
                last = first
                if StillScreen.regionsMatch(first, second, regions) {
                    picture = first
                    break
                }
            }
        }
        // The same section anchor must bracket the actual images. A later verse or
        // another chorus cannot certify an earlier frame just because its words look similar.
        var sameSection = false
        var endingWords = ""
        var endingCombo = 0
        var endingHeldBeat: String?
        if picture != nil {
            for node in appNodes() {
                if node.identifier == "performance.capture.frozen" { endingHeldBeat = node.value as? String }
                if let sectionIdentifier, node.identifier == sectionIdentifier {
                    sameSection = true
                    endingWords = (node.value as? String)?.lowercased() ?? ""
                }
                if node.identifier.hasPrefix("performance.combo.") {
                    endingCombo = Int(node.identifier.dropFirst("performance.combo.".count)) ?? 0
                }
            }
        }
        let problem: String
        if !playing {
            problem = "\(song)'s take never stayed on screen for \(Self.takeHold) s (opened: \(opened))"
        } else if !held {
            problem = "the actual performance capture barrier was not reached"
        } else if !(opened && combo >= 8 && chorus.contains(where: { words.contains($0) })) {
            problem = "\(song)'s take shows a combo of \(combo) and the words '\(words)' (opened: \(opened)), not a run of 8+ in the chorus"
        } else if hud == nil || score == nil || lyrics == nil || regions.count != 4 {
            problem = "the semantic combo, score or lyric region is missing"
        } else if picture == nil {
            problem = "the HUD or lyrics changed between every capture pair; no stable frame was approved"
        } else if !sameSection || endingCombo < 8 || !chorus.contains(where: { endingWords.contains($0) }) {
            problem = "the performance left the verified chorus during capture; no frame was approved"
        } else if heldBeat == nil || heldBeat != endingHeldBeat || combo != endingCombo {
            problem = "the held take changed between semantic snapshots; no frame was approved"
        } else {
            problem = ""
        }
        storeFrame(name, picture: picture ?? last, ok: problem.isEmpty, problem)
    }

    /// The HUD's numbers as fractions of the screen: the combo counter (the left of the HUD row), the multiplier dial
    /// (its right; the runway between them moves) and the score. Empty without the HUD.
    private func hudRegions(hud: CGRect?, score: CGRect?, screen: CGRect) -> [CGRect] {
        guard screen.width > 0, screen.height > 0,
              let hud, !hud.isEmpty, hud.minX.isFinite, hud.minY.isFinite, hud.width.isFinite, hud.height.isFinite,
              let score, !score.isEmpty, score.minX.isFinite, score.minY.isFinite, score.width.isFinite, score.height.isFinite else { return [] }
        func fraction(_ box: CGRect) -> CGRect {
            CGRect(x: box.minX / screen.width, y: box.minY / screen.height, width: box.width / screen.width, height: box.height / screen.height)
        }
        let side = min(hud.width * 0.24, 110)
        var regions = [fraction(CGRect(x: hud.minX, y: hud.minY, width: side, height: hud.height)),
                       fraction(CGRect(x: hud.maxX - side, y: hud.minY, width: side, height: hud.height))]
        regions.append(fraction(score))
        return regions
    }

    /// Interior family chips must clear both active rail fades, not merely expose their centre.
    private static func instrumentFilterIsClear(_ frame: CGRect, in viewport: CGRect) -> Bool {
        !frame.isEmpty && viewport.insetBy(dx: 52, dy: 8).contains(frame)
    }

    func testInstrumentFamilyChipMustClearBothFades() {
        let viewport = CGRect(x: 0, y: 0, width: 402, height: 874)
        let clippedLeft = CGRect(x: 10, y: 200, width: 160, height: 44)
        // The old centre-only rule accepted this partially faded chip.
        XCTAssertTrue(viewport.insetBy(dx: 52, dy: 8).contains(
            CGPoint(x: clippedLeft.midX, y: clippedLeft.midY)))
        XCTAssertFalse(Self.instrumentFilterIsClear(clippedLeft, in: viewport))
        XCTAssertFalse(Self.instrumentFilterIsClear(CGRect(x: 220, y: 200, width: 170, height: 44), in: viewport))
        XCTAssertTrue(Self.instrumentFilterIsClear(CGRect(x: 52, y: 200, width: 298, height: 44), in: viewport))
    }

    /// App Store frame #4 ("Tune whatever you play"), with the instrument wall around it: the `instrument-wall` scene opens
    /// the browser by itself; the Folk & world strings filter fills it with the instruments no other tuner has.
    func test17StoreInstrumentWall() throws {
        launch(scene: "instrument-wall")
        XCTAssertTrue(element("instruments.search").waitForExistence(timeout: 25), "The instrument browser never opened")
        settle(1)
        let folk = element("instruments.family.folk_world_strings")
        // A chip's centre can be visible while its title/target is clipped by the rail's fade.
        // Bring the complete control clear before tapping; follow measured coordinates in either direction.
        func clearFrame() -> CGRect? {
            guard let frame = (try? folk.snapshot())?.frame, !frame.isEmpty,
                  frame.minX.isFinite, frame.midY.isFinite else { return nil }
            return frame
        }
        for _ in 0..<5 {
            guard let frame = clearFrame() else { break }
            if Self.instrumentFilterIsClear(frame, in: app.frame) { break }
            let viewport = app.frame
            let startX = viewport.midX
            let endX = min(viewport.maxX - 24, max(viewport.minX + 24, startX + viewport.midX - frame.midX))
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: startX, dy: frame.midY)).press(forDuration: 0.1,
                thenDragTo: origin.withOffset(CGVector(dx: endX, dy: frame.midY)),
                withVelocity: .slow, thenHoldForDuration: 0.2)
            settle(0.6)
        }
        if let frame = clearFrame(), Self.instrumentFilterIsClear(frame, in: app.frame) { tapIfPresent(folk) }
        let selected = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"), object: folk)], timeout: 5) == .completed
        settle(1)
        let picture = stillScreenshot(timeout: 4)
        let banjo = element("instrument.22_folk_world_strings_banjo_5_string")
        let filtered = selected && banjo.exists && banjo.isHittable && !element("instrument.01_guitar_acoustic_guitar").exists
        storeFrame("31b-instruments-folk", picture: picture, ok: filtered,
                   "the browser isn't showing the Folk & world strings (banjo on screen: \(banjo.exists), "
                   + "filter chip found: \(folk.exists), selected: \(selected))")
    }

    // MARK: Show me

    /// One reading of the "Show me" stage's probe (TIMBRE_DEBUG_STATE=1, `ShowMeProbe` in ios/Timbre/Root/DemoScenes.swift,
    /// never drawn): "showme=<3d|picture|loading> landed=<epoch s the last fingertip lands, 0 before a demonstration>
    /// ringing=<n> live=<epoch s of the first frame drawn with the model on the card, 0 before> frames=<drawn since>
    /// now=<app clock> diag=<free text>". "3d" only once the card has swapped its picture for the model (the card's own
    /// state, not just the stage's); "picture" is a ready stage the card hasn't shown. An empty stage when no "Show me"
    /// stage is on screen.
    private struct ShowMeReading {
        var stage = ""
        var landed: Date?
        var ringing = 0
        var live: Date?
        var frames = 0
    }

    private func showMeProbe() -> ShowMeReading {
        var reading = ShowMeReading()
        guard let label = (try? element("showme.state").snapshot())?.label else { return reading }
        // The free-text diagnostic comes last; only the fields before it are read.
        let head = label.components(separatedBy: " diag=").first ?? label
        for field in head.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "showme": reading.stage = parts[1]
            case "landed": reading.landed = Double(parts[1]).flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
            case "ringing": reading.ringing = Int(parts[1]) ?? 0
            case "live": reading.live = Double(parts[1]).flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
            case "frames": reading.frames = Int(parts[1]) ?? 0
            default: break
            }
        }
        return reading
    }

    /// Both "Show me" probes in full, the stage's and its card's (`ShowMeHostProbe`), for the log when the frame isn't
    /// kept: the model's load state and error, attached, ready, frames drawn, framing, and the card's own state.
    private func showMeDiagnostics() -> String {
        let stage = (try? element("showme.state").snapshot())?.label ?? "no stage on the card"
        let card = (try? element("showme.host").snapshot())?.label ?? "no card probe"
        return "stage probe: \(stage) | \(card)"
    }

    /// A chord's demonstration on the model, timed from its last fingertip landing (LessonExplain's `runDemo`): a
    /// landing step (0.45 s) later the chord rings across the strings, low to high 0.04 s apart, and they stay lit for
    /// 1.5 s. A picture taken from `from` to `to` after the landing has every fingertip down and every string ringing.
    private enum ShowMeRing {
        static let from = 0.75
        static let to = 1.85
        static let aim = 1.0
        /// "Show me" on the model plays it again: its first fingertip lands 0.05 s after the tap, its last (E minor's
        /// second) a landing step later.
        static let replayLanding = 0.5
        /// The model takes the card in a 0.6 s cross-fade (Motion.reveal): the picture must come later than this after
        /// the first frame drawn with the model on the card (a renderer that stalls on its first frames leaves the
        /// cross-fade's first frame on screen: the chart with the "3D" switch on).
        static let shown = 0.9
        /// Frames drawn with the model on the card by the reading after the picture: the renderer was drawing.
        static let frames = 8
    }

    /// Why a take isn't the store frame ("" when it is): the card showed the model in place of its picture, the renderer
    /// had been drawing it there for longer than the cross-fade, and the picture fell inside the ring.
    private func showMeVerdict(_ probe: ShowMeReading, start: Date, end: Date) -> String {
        guard probe.stage == "3d" else { return "the card isn't showing the 3D model (stage '\(probe.stage)')" }
        guard let live = probe.live, probe.frames >= ShowMeRing.frames else {
            return "the renderer drew \(probe.frames) frames with the model on the card (live: \(probe.live == nil ? "never" : "yes"))"
        }
        guard start >= live.addingTimeInterval(ShowMeRing.shown) else {
            return String(format: "the picture came %.2f s after the model's first frame on the card, inside its cross-fade",
                          start.timeIntervalSince(live))
        }
        guard let landed = probe.landed,
              start >= landed.addingTimeInterval(ShowMeRing.from), end <= landed.addingTimeInterval(ShowMeRing.to) else {
            let offset = probe.landed.map { String(format: "%.2f", start.timeIntervalSince($0)) } ?? "?"
            return "the picture missed the ring: taken \(offset) s after the last fingertip landed (\(probe.ringing) strings lit now)"
        }
        return ""
    }

    /// One try at the ring, hands off from the last probe to the picture: the demonstration already under way while
    /// its ring is still ahead, otherwise "Show me" again (it replays on the model, once the last one is over), its new
    /// clock read from the probe right after the tap. Returns the picture and when it was taken.
    private func catchShowMeRing(landed: Date?, replay: Bool) -> (picture: XCUIScreenshot, start: Date, end: Date) {
        let aim: Date
        if !replay, let landed, landed.addingTimeInterval(ShowMeRing.to - 0.5) > Date() {
            aim = max(landed.addingTimeInterval(ShowMeRing.aim), Date())
        } else {
            // The last demonstration has finished (its strings dark, "Your turn" up), so the app is at rest for the tap.
            if let landed { hold(until: landed.addingTimeInterval(3)) }
            let before = Date()
            tapIfPresent(element("lesson.showme"))
            let replayed = showMeProbe().landed.flatMap { $0 > before ? $0 : nil }
            aim = max(replayed?.addingTimeInterval(ShowMeRing.aim) ?? before.addingTimeInterval(ShowMeRing.replayLanding + ShowMeRing.aim),
                      Date())
        }
        hold(until: aim)
        let start = Date()
        let picture = XCUIScreen.main.screenshot()
        return (picture, start, Date())
    }

    /// "Show me" through the `show-me` scene (DemoScenes.swift; the guitar page's frame and the check of the string glow):
    /// "Your first chord: E minor" opens on its first
    /// step, the chord explained on its card, and the guitar's 3D model takes the card (by itself, the chord's first time
    /// in the course; otherwise the test asks with "Show me"). The picture is the demonstration mid-play: both
    /// fingertips down on the model's own frets and the chord ringing across every string. It is kept only when the
    /// probe says the card has swapped its chart for the model, the renderer had been drawing the model there for
    /// longer than the cross-fade (and kept drawing), and the picture fell inside the ring on the demonstration's own
    /// clock; a miss plays it again ("Show me" on the model), hands off until the picture. A frame not kept logs both
    /// probes in full (load state, error, attached, ready, frames, framing; the card's state).
    func test15StoreShowMe() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true, scene: "show-me")
        let opened = element("lesson.close").waitForExistence(timeout: 30)
        // The model loads (the first on a fresh simulator can take 20 s or more); ask for it if it doesn't come, again
        // should the card give up on it meanwhile (its first-time wait is 5 s).
        let askAfter = Date().addingTimeInterval(5)
        let deadline = Date().addingTimeInterval(90)
        var asks = 0
        var lastAsk = Date.distantPast
        var probe = showMeProbe()
        while probe.stage != "3d" && Date() < deadline {
            if probe.stage.isEmpty && asks < 3 && Date() > askAfter && Date().timeIntervalSince(lastAsk) > 8 {
                let button = element("lesson.showme")
                if button.exists && button.isHittable { button.tap(); asks += 1; lastAsk = Date() }
            }
            settle(0.5)
            probe = showMeProbe()
        }
        var picture = XCUIScreen.main.screenshot()
        var problem = "the 3D stage never showed (stage '\(probe.stage)', lesson open: \(opened), Show me asked \(asks) times)"
        if probe.stage == "3d" {
            for attempt in 0..<4 {
                let take = catchShowMeRing(landed: probe.landed, replay: attempt > 0)
                picture = take.picture
                probe = showMeProbe()
                problem = showMeVerdict(probe, start: take.start, end: take.end)
                if problem.isEmpty { break }
            }
        }
        if !problem.isEmpty {
            let diagnostics = showMeDiagnostics()
            print("SHOW ME PROBE: \(diagnostics)")
            let note = XCTAttachment(string: diagnostics)
            note.name = "showme-probe"
            note.lifetime = .keepAlways
            add(note)
            problem += " [\(diagnostics)]"
        }
        storeFrame("51b-lesson-showme", picture: picture, ok: problem.isEmpty, problem)
    }

    func test07StageDiagnostics() throws {
        launch(stageDebug: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        let debug = element("stage.debug")
        XCTAssertTrue(debug.waitForExistence(timeout: 20))
        for _ in 0..<20 where !debug.label.hasPrefix("loaded") { settle(1) }
        print("STAGE DEBUG: \(debug.label)")
        let note = XCTAttachment(string: debug.label)
        note.name = "stage-debug"; note.lifetime = .keepAlways
        add(note)
        shot("90-stage-diagnostics")
    }
}
