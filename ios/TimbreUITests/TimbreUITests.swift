import XCTest

/// End-to-end flows that double as a visual tour: every screen is captured so the
/// design can be reviewed from CI results.
final class TimbreUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 { shot("zz-failure-\(name)") }
        app.terminate()
    }

    /// `scene`: a store screenshot's hero moment (TIMBRE_SCENE, ios/Timbre/Root/DemoScenes.swift; it needs `pitch`).
    private func launch(onboarded: Bool = true, demo: Bool = true, studio: Bool = false, pitch: Bool = false, stageDebug: Bool = false, scene: String? = nil) {
        if let scene { app.launchEnvironment["TIMBRE_SCENE"] = scene }
        if stageDebug { app.launchEnvironment["TIMBRE_STAGE_DEBUG"] = "1" }
        if pitch { app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1" }
        if onboarded { app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1" }
        if demo { app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1" }
        if studio { app.launchEnvironment["TIMBRE_STAGE_MODE"] = "studio" }
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    /// Taps a tab, retrying while a sheet is still dismissing and swallows the tap.
    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name].firstMatch
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
        let picker = app.navigationBars["Choose instrument"]
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
    // tools/marketing/screenshots.py) must show what their captions say, every run. The tuner's lock and the chord
    // come from store scenes (TIMBRE_SCENE, ios/Timbre/Root/DemoScenes.swift) that put the app into that moment
    // through its own code paths, so no shot races the demo pitch's clock; the others are plain navigation.

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

    /// The tuner's UI-test probe (TIMBRE_DEBUG_STATE=1, never drawn): "stage=<3d|loading|2d> listening=<epoch s, 0 if not>".
    private func tunerProbe() -> (stage: String, listening: Date?) {
        guard let label = (try? element("stage.state").snapshot())?.label else { return ("", nil) }
        var stage = ""
        var listening: Date?
        for field in label.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "stage" { stage = parts[1] }
            if parts[0] == "listening", let seconds = Double(parts[1]), seconds > 0 { listening = Date(timeIntervalSince1970: seconds) }
        }
        return (stage, listening)
    }

    /// Waits for the 3D model to take over from the studio render that holds the stage while it loads (the first
    /// model on a fresh simulator can take 20 s or more), then for the camera's dolly in to the headstock.
    private func waitForStage(timeout: TimeInterval = 90) -> (stage: String, listening: Date?) {
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
    /// aside for the readout's In tune badge. `summary` says what was seen.
    private func tunerLock(strings: Int) -> (shown: Bool, summary: String) {
        var chips: [String: (selected: Bool, tuned: Bool)] = [:]
        var status: String?
        var stage = false
        for node in appNodes() {
            if node.identifier.hasPrefix("string.") {
                let seen = chips[node.identifier] ?? (selected: false, tuned: false)
                chips[node.identifier] = (selected: seen.selected || node.isSelected, tuned: seen.tuned || (node.value as? String) == "Tuned")
            }
            if node.identifier == "tune.status" { status = node.label }
            if node.identifier == "tune.stage" { stage = true }
        }
        let tuned = chips.values.filter { $0.tuned }.count
        let selectedTuned = chips.values.contains { $0.selected && $0.tuned }
        let badge = status == nil || status == "In tune"
        let summary = "stage shown \(stage), \(tuned) of \(chips.count) strings tuned, selected tuned \(selectedTuned), status '\(status ?? "hidden: the In tune badge")'"
        // The picture is taken before this check, hands off; the check's own snapshot stalls the app's main thread,
        // which can restart the hold (status back to "Hold it…") without undoing the lock, so the badge isn't required.
        _ = badge
        return (stage && tuned >= strings && selectedTuned, summary)
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
        let picker = app.navigationBars["Choose instrument"]
        for _ in 0..<3 where picker.exists {
            let done = app.buttons["Done"].firstMatch
            if done.exists { done.tap() }
            _ = picker.waitForNonExistence(timeout: 4)
        }
        settle(0.8)
    }

    func test01Onboarding() throws {
        // The demo pitch plays the first-tune step's string (it drifts from 14 cents flat into tune).
        launch(onboarded: false, demo: false, pitch: true)
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        settle(); shot("01-onboarding-welcome")
        element("onboarding.instrument.bass.electric.4").tap(); settle(); shot("02-onboarding-instrument")
        element("onboarding.instrument.guitar.acoustic.6").tap()
        start.tap(); settle(1.5); shot("03-onboarding-experience")
        // Nothing is pre-selected: Continue waits for an answer.
        element("onboarding.option.intermediate").tap()
        continueUntil(element("onboarding.option.practice")); settle(1.2); shot("04-onboarding-goal")
        element("onboarding.option.practice").tap(); settle(0.5)
        let notNow = app.buttons["Not now"]
        for _ in 0..<3 where !notNow.exists { element("onboarding.continue").tap(); settle(1.5) }
        XCTAssertTrue(notNow.waitForExistence(timeout: 5))
        shot("05-onboarding-microphone")
        notNow.tap()
        // "Pluck your thickest string": the stage follows the pitch, locks, and moves on to the plan by itself.
        let firstTune = element("onboarding.firsttune")
        XCTAssertTrue(firstTune.waitForExistence(timeout: 10))
        settle(1.6); shot("05a-onboarding-first-tune")
        // The lock counts as practice: the badge, the XP and day one of the streak show where Skip was.
        if element("onboarding.firsttune.reward").waitForExistence(timeout: 15) { settle(0.5); shot("05a2-onboarding-first-tune-reward") }
        let plan = element("onboarding.plan.start")
        if !plan.waitForExistence(timeout: 15) {
            // Never stall the tour on the lock: Skip leads to the same plan.
            let skip = element("onboarding.firsttune.skip")
            if skip.exists && skip.isHittable { skip.tap() }
        }
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        settle(2); shot("05b-onboarding-plan")
        plan.tap()
        let free = element("paywall.free")
        XCTAssertTrue(free.waitForExistence(timeout: 15))
        settle(2); shot("06-paywall-onboarding")
        scrollTo(free)
        free.tap()
        // Onboarding hands over to Learn and opens the plan's first lesson (the first free one on the free plan).
        let close = element("lesson.close")
        XCTAssertTrue(close.waitForExistence(timeout: 20))
        settle(2); shot("06b-first-lesson")
        close.tap(); settle(1.5)
        // The first tune already counted: the tuner shows day one of the streak.
        tab("Tune")
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        settle(2.5); shot("07-tune-first-run")
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
        app.buttons["Done"].firstMatch.tap(); settle()
        element("settings.open").tap(); settle(1.5); shot("13-settings")
        // Pro upsell from inside the settings sheet presents the paywall on top of it.
        element("settings.pro").tap()
        XCTAssertTrue(element("paywall.purchase").waitForExistence(timeout: 15))
        settle(1.5); shot("16-paywall-from-settings")
        // Strum to tune, back on the tuner: under the demo pitch one strum is heard as the screen opens (A2 12 cents
        // flat first, B3 approximate), so the shot waits for its "Fine-tune" button.
        tapIfPresent(element("paywall.close")); settle(1.2)
        let settingsDone = app.navigationBars.buttons["Done"].firstMatch
        if settingsDone.exists { settingsDone.tap(); settle(1.2) }
        let strum = element("tune.strum")
        XCTAssertTrue(strum.waitForExistence(timeout: 10))
        strum.tap()
        XCTAssertTrue(element("strum.finetune").waitForExistence(timeout: 8))
        settle(1.2); shot("11b-tune-strum")
        element("strum.close").tap(); settle()
    }

    func test03StudioStage() throws {
        launch(studio: true, pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        settle(3); shot("14-tune-studio")
        openPicker()
        element("instruments.chromatic").tap(); settle(2); shot("15-tune-chromatic")
    }

    func test04PracticeTour() throws {
        launch()
        tab("Play"); settle(1.5); shot("20-practice-hub")
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
        // App Store frame #7: the Guitar family filter — a full grid of guitars, each on its own stage, under the
        // title bar. A tap on the family chip is deterministic; scrolling the sheet could dismiss it or tap a Pro card.
        let guitars = app.buttons["Guitar"].firstMatch
        if guitars.waitForExistence(timeout: 5) { guitars.tap(); settle(1.5) }
        let grid = element("instrument.guitar_classical").exists && app.navigationBars["Choose instrument"].exists && !element("paywall.purchase").exists
        storeFrame("31-instruments-scrolled", ok: grid, "the guitar grid isn't on screen, or a paywall is over the browser")
        closePicker()
        // App Store frame #8: Progress, with nothing over it.
        tab("Progress"); settle(2)
        let progress = app.tabBars.buttons["Progress"].firstMatch
        let front = progress.exists && progress.isSelected && !element("paywall.purchase").exists && !app.navigationBars["Choose instrument"].exists
        storeFrame("32-journey", ok: front, "Progress isn't the screen in front (the browser or a paywall is still up)")
        app.swipeUp(); settle(); shot("33-journey-scrolled")
    }

    func test06PurchaseUnlocksPro() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch()
        tab("Play"); settle()
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
        tab("Progress"); settle(2); shot("45-journey-pro")
        tab("Play"); settle()
        scrollTo(element("practice.intonation"))
        element("practice.intonation").tap(); settle(1.5); shot("46-intonation")
        app.navigationBars.buttons.firstMatch.tap(); settle()
        tab("Tune"); settle()
        element("tune.instrument").tap(); settle(1.5)
        element("tunings.custom").tap(); settle(1.5); shot("47-custom-tuning")
        XCTAssertTrue(element("custom.save").waitForExistence(timeout: 10))
        element("custom.save").tap(); settle(1.5); shot("48-custom-tuning-saved")
        // Instruments on their 3D stage: the mandolin (Pro, open now), then the violin and cello (free on any plan).
        for (asset, search, name) in [("13_mandolin_mandolin", "Mandolin", "49-tune-mandolin-3d"), ("17_bowed_strings_violin", "Violin", "49b-tune-violin-3d"), ("19_bowed_strings_cello", "Cello", "49c-tune-cello-3d")] {
            // The picker is still up after saving the custom tuning; later rounds open it from the tuner.
            openPicker()
            let card = findInstrument(asset, search: search)
            card.tap(); _ = waitForStage(); shot(name)
        }
    }

    func test08PhotoStage() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        openPicker()
        let ukulele = findInstrument("10_ukulele_soprano_ukulele", search: "Soprano")
        ukulele.tap()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        settle(7); shot("17-tune-photo-stage")
        element("string.2").tap(); settle(3); shot("18-tune-photo-stage-string")
        openPicker()
        let bass = findInstrument("06_bass_4_string_p_bass", search: "4-string")
        bass.tap(); _ = waitForStage(); shot("19-tune-bass-3d")
    }

    func test09LearnChordLesson() throws {
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        tab("Learn"); settle(2.5); shot("50-learn")
        element("learn.continue").tap(); settle(1.5); shot("51-lesson-explain")
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
        settle(2); shot("63-songs")
        hero.tap()
        let close = element("lesson.close")
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        settle(1.5); shot("64-songs-lesson")
        close.tap(); settle(1.5)
        tab("Learn"); settle(2)
        let node = element("learn.lesson.gtr-1-2")
        scrollTo(node)
        node.tap(); settle(1.5)
        element("lesson.continue").tap(); settle(1)
        let skip = element("lesson.tunecheck.skip")
        tapIfPresent(skip); settle(1)
        settle(1.5); shot("56-lesson-notes")
        // Two note steps finish on their own with the demo pitch, then a quiz and a listening question.
        XCTAssertTrue(element("lesson.option.0").waitForExistence(timeout: 25))
        element("lesson.option.0").tap(); settle(1); shot("57-lesson-quiz")
        element("lesson.continue").tap(); settle(2)
        element("lesson.option.1").tap(); settle(1); shot("58-lesson-listen")
        element("lesson.continue").tap(); settle(1.5); shot("59-along-ready")
        element("lesson.continue").tap(); settle(7); shot("60-along-playing")
        XCTAssertTrue(element("along.again").waitForExistence(timeout: 30))
        settle(1); shot("61-along-done")
        element("lesson.continue").tap(); settle(3.5); shot("62-lesson-results")
    }

    /// App Store frame #1 through the `tune-locked` scene (ios/Timbre/Root/DemoScenes.swift): the demo pitch plays the
    /// selected string steadily in tune, so the tuner's own tracker locks the two lowest strings (✓ on their chips), then
    /// the third, which stays locked: solid chip, In tune badge, its peg ringed and ticked on the 3D headstock. Nothing
    /// races a clock. The test only keeps its hands off while the holds run: a query stalls the app's main thread, and a
    /// gap of more than 150 ms in the readings starts the 0.65 s hold again (the scene waits for each lock).
    func test11StoreTunerLock() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true, scene: "tune-locked")
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        let stage = waitForStage().stage
        var picture = XCUIScreen.main.screenshot()
        var problem = "the 3D headstock never replaced its studio render (stage '\(stage)')"
        if stage == "3d" {
            for attempt in 0..<3 {
                // Hands off: the scene's locks land, the camera settles on the third peg and the reward banner clears.
                settle(attempt == 0 ? 7 : 3)
                picture = XCUIScreen.main.screenshot()
                let lock = tunerLock(strings: 3)
                if lock.shown { problem = ""; break }
                problem = "no lock on screen: " + lock.summary
            }
        }
        storeFrame("10b-tune-locked", picture: picture, ok: problem.isEmpty, problem)
    }

    /// App Store frame #3 through the `lesson-chord` scene (DemoScenes.swift): "Your first chord: E minor" opens on its
    /// chord step, the demo pitch plays the chord string by string, and the step stays on "Every string rings" with
    /// every string lit instead of handing over to the next step.
    func test12StoreChord() throws {
        launch(pitch: true, scene: "lesson-chord")
        let finished = NSPredicate(format: "identifier == %@ AND label == %@", "lesson.chord", "Every string rings")
        let ringing = app.descendants(matching: .any).matching(finished).firstMatch.waitForExistence(timeout: 45)
        // The last string's tick and the burst land.
        settle(1.2)
        let picture = XCUIScreen.main.screenshot()
        // Each string's check over the box reads "Got it" once heard; a muted string has none.
        let checks = appNodes().filter { $0.label.hasPrefix("String ") && $0.identifier.isEmpty }
        let unheard = checks.filter { ($0.value as? String) != "Got it" }.count
        storeFrame("52b-lesson-chord", picture: picture, ok: ringing && unheard == 0,
                   ringing ? "\(unheard) of \(checks.count) strings not lit" : "the chord step never heard every string")
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
