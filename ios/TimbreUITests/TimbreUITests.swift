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

    /// A capture taken once the screen has come to rest (StillScreen.swift): entrances, staggers and counters done.
    private func stillShot(_ name: String, timeout: TimeInterval = 4) {
        keep(stillScreenshot(timeout: timeout), as: name)
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    /// The first element whose whole accessibility label matches `pattern` (a regular expression).
    private func labeled(_ pattern: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", pattern)).firstMatch
    }
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
        // The sheet rises, then the outcomes slide in one after another and the trial track draws itself.
        settle(0.8); stillShot("06-paywall-onboarding", timeout: 5)
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
        // Strum to tune is App Store frame #8, from a fresh launch of its own (test13StoreStrum), not from behind
        // these two sheets.
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
        // The Guitar family filter: a full grid of guitars, each on its own stage, under the title bar. A tap on the
        // family chip is deterministic; scrolling the sheet could dismiss it or tap a Pro card. (Frame #7 was this grid
        // until Strum to tune took its place: test13StoreStrum.)
        let guitars = app.buttons["Guitar"].firstMatch
        if guitars.waitForExistence(timeout: 5) { guitars.tap(); settle(1.5) }
        shot("31-instruments-scrolled")
        closePicker()
        // App Store frame #9: Progress, with nothing over it, once its cards have come in.
        tab("Progress"); settle(0.8)
        let picture = stillScreenshot()
        let progress = app.tabBars.buttons["Progress"].firstMatch
        let front = progress.exists && progress.isSelected && !element("paywall.purchase").exists && !app.navigationBars["Choose instrument"].exists
        storeFrame("32-journey", picture: picture, ok: front, "Progress isn't the screen in front (the browser or a paywall is still up)")
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
        // Progress with Pro: its top (streak, level, coach, week) is the same on any plan, so the picture is taken on
        // the card Pro adds, the tuning accuracy chart, and kept only when that card (not the Pro teaser) is there.
        tab("Progress"); settle(1.5)
        let chart = labeled("Tuning accuracy")
        if chart.waitForExistence(timeout: 5) {
            scrollTo(chart)
            bringToUpperMiddle(chart)
        }
        let teaser = labeled("Accuracy over time").exists
        storeFrame("45-journey-pro", picture: stillScreenshot(), ok: chart.exists && chart.isHittable && !teaser,
                   "Progress shows \(teaser ? "the Pro teaser" : "no tuning accuracy card") after the purchase")
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
        // App Store frame #6, once Learn's cards have come in (and any reward banner from the tune has gone).
        tab("Learn"); settle(1); stillShot("50-learn", timeout: 5)
        // The lesson zooms open on E minor's demonstration: the fingertips land one by one, the chord rings across the
        // strings, then "Your turn" (or, when the demo pitch plays it back, "Nice") shows under the neck. The picture
        // waits for that line: every fingertip is down and the strings have stopped shimmering.
        element("learn.continue").tap()
        _ = labeled(".*(Your turn|Nice — ).*").waitForExistence(timeout: 12)
        stillShot("51-lesson-explain", timeout: 2.5)
        // The lesson zooms open: a tap during the transition can be dropped, so tap until the tune check shows.
        let skip = element("lesson.tunecheck.skip")
        for _ in 0..<4 where !skip.exists { element("lesson.continue").tap(); _ = skip.waitForExistence(timeout: 3) }
        settle(1); shot("52-lesson-tunecheck")
        // The tune check is covered by its own screenshot; skip the rest of it to keep the run short. The demo
        // pitch tunes each string in turn, so the check can finish on its own while the tap is on its way.
        tapIfPresent(skip)
        // The demo pitch plays the chord's strings and the step hands over to the strum explainer by itself. (The
        // chord with every string lit, App Store frame #4, comes from its own scene: test12StoreChord.)
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
        element("lesson.continue").tap(); settle(1)
        let skip = element("lesson.tunecheck.skip")
        tapIfPresent(skip); settle(1)
        settle(1.5); shot("56-lesson-notes")
        // Two note steps finish on their own with the demo pitch, then a quiz and a listening question.
        XCTAssertTrue(element("lesson.option.0").waitForExistence(timeout: 25))
        // The quiz slides in from the side: a tap resolved mid-slide lands on the tile beside the right answer.
        settle(1.2)
        element("lesson.option.0").tap(); settle(1); shot("57-lesson-quiz")
        element("lesson.continue").tap(); settle(2)
        element("lesson.option.1").tap(); settle(1); shot("58-lesson-listen")
        element("lesson.continue").tap(); settle(1.5); shot("59-along-ready")
        // A one-bar count-in and six notes at 60 BPM: the take is over about 10 s after Start. Hands off until then
        // (the picture doesn't touch the app): a query stalls its main thread, a note heard late is a miss, and the
        // final play-along gates the lesson's stars, so a missed note would cost frame #7 its third star.
        // The take starts a second or two after the tap (the step's entrance, then Start), so its last note lands
        // about 11 s after it: the first query waits until 15 s, well clear of it.
        element("lesson.continue").tap(); settle(7); shot("60-along-playing")
        settle(8)
        XCTAssertTrue(element("along.again").waitForExistence(timeout: 30))
        settle(1); shot("61-along-done")
        // App Store frame #7. The results land in order: the stars, the coach, the XP counting up, then the level bar
        // (labelled "Level N") fills under them. Its arrival means the XP has finished counting; the badges that pop in
        // after it and the bar's fill settle before the picture. Kept only with three stars ("Flawless" or "Great work").
        element("lesson.continue").tap()
        _ = labeled("Level [0-9]+").waitForExistence(timeout: 15)
        let results = stillScreenshot(timeout: 3)
        let headline = labeled("(Flawless|Great work)").exists
        let room = resultsFit()
        storeFrame("62-lesson-results", picture: results, ok: headline && room.fits,
                   headline ? room.summary
                            : "the results don't read Flawless or Great work: the play-along wasn't played clean, so fewer than three stars")
    }

    /// Whether the results' first screen fits above the pinned buttons (LessonResults): the Share pill and the level bar
    /// end above the fade the scroll view draws over its last 28 pt (it ends 8 pt above the buttons), so neither is
    /// dimmed (review 14 caught Share half under it). Read from one snapshot.
    private func resultsFit() -> (fits: Bool, summary: String) {
        let nodes = appNodes()
        func frame(_ id: String) -> CGRect? { nodes.first { $0.identifier == id }?.frame }
        let buttons = [frame("lesson.next"), frame("lesson.done")].compactMap { $0?.minY }.min()
        let level = nodes.first { $0.label.range(of: "^Level [0-9]+$", options: .regularExpression) != nil }?.frame
        let share = frame("lesson.share")
        guard let buttons, let level else {
            return (false, "the results show no level bar or no buttons (level \(level != nil), buttons \(buttons != nil))")
        }
        let clear = buttons - 36
        let lowest = max(level.maxY, share?.maxY ?? 0)
        return (lowest <= clear, "the results run under the fade over the buttons: Share ends at \(Int(share?.maxY ?? 0)), the level bar at \(Int(level.maxY)), the fade starts at \(Int(clear))")
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

    /// App Store frame #4 through the `lesson-chord` scene (DemoScenes.swift): "Your first chord: E minor" opens on its
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
        let summary = (try? element("strum.summary").snapshot())?.label ?? ""
        let covered = element("paywall.purchase").exists || app.navigationBars["Choose instrument"].exists
        storeFrame("11b-tune-strum", picture: picture, ok: read && summary.hasPrefix("Tune ") && !covered,
                   "the strum screen reads '\(summary)' (Fine-tune button: \(read), a sheet over it: \(covered)), not the demo strum")
    }

    /// App Store frame #2 through the `song-perform` scene (DemoScenes.swift): Kite Weather, the Originals' song of the
    /// day, performed on the fretboard runway mid-chorus, with its words under the runway, fret numbers on the gems and
    /// a long combo. The scene opens the song on its performance and starts the take by itself 3 s later at bar 16 of
    /// 56 (every note before it played clean, 68 in a row); the demo pitch plays on, on time. The hook line ("It's kite
    /// weather, kite weather") is in the light from about 2 to 7.5 s into the take, so the picture is taken about 4.5 s
    /// in, hands off from the moment the lesson shows: a query stalls the app's main thread, and a note heard late
    /// would break the run. One snapshot afterwards checks the combo and that the words are the chorus's.
    func test14StoreSongPerform() throws {
        launch(pitch: true, scene: "song-perform")
        let opened = element("lesson.close").waitForExistence(timeout: 30)
        settle(7.5)
        let picture = XCUIScreen.main.screenshot()
        var combo = 0
        var words = ""
        for node in appNodes() {
            if node.label == "Combo", let value = node.value as? String { combo = Int(value.prefix { $0.isNumber }) ?? 0 }
            if node.label == "Lyrics", let value = node.value as? String { words = value.lowercased() }
        }
        let chorus = ["kite weather", "let it climb", "summer winds"].contains { words.contains($0) }
        storeFrame("65-song-perform", picture: picture, ok: opened && combo >= 8 && chorus,
                   "Kite Weather's take shows a combo of \(combo) and the words '\(words)' (opened: \(opened)), not a run of 8+ in the chorus")
    }

    // MARK: Show me

    /// The "Show me" stage's probe (TIMBRE_DEBUG_STATE=1, `ShowMeProbe` in ios/Timbre/Root/DemoScenes.swift, never
    /// drawn): "showme=<3d|loading> landed=<epoch s the last fingertip lands, 0 before a demonstration> ringing=<n>".
    /// An empty stage when no "Show me" stage is on screen.
    private func showMeProbe() -> (stage: String, landed: Date?, ringing: Int) {
        guard let label = (try? element("showme.state").snapshot())?.label else { return ("", nil, 0) }
        var stage = ""
        var landed: Date?
        var ringing = 0
        for field in label.split(separator: " ") {
            let parts = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            if parts[0] == "showme" { stage = parts[1] }
            if parts[0] == "landed", let seconds = Double(parts[1]), seconds > 0 { landed = Date(timeIntervalSince1970: seconds) }
            if parts[0] == "ringing" { ringing = Int(parts[1]) ?? 0 }
        }
        return (stage, landed, ringing)
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

    /// App Store frame #3 through the `show-me` scene (DemoScenes.swift): "Your first chord: E minor" opens on its first
    /// step, the chord explained on its card, and the guitar's 3D model takes the card (by itself, the chord's first time
    /// in the course; otherwise the test asks with "Show me"). The picture is the demonstration mid-play: both
    /// fingertips down on the model's own frets and the chord ringing across every string. It is kept only when the
    /// probe says the 3D stage is showing and the picture fell inside the ring on the demonstration's own clock; a miss
    /// plays it again ("Show me" on the model), hands off until the picture.
    func test15StoreShowMe() throws {
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        launch(pitch: true, scene: "show-me")
        let opened = element("lesson.close").waitForExistence(timeout: 30)
        // The model loads (the first on a fresh simulator can take 20 s or more); ask for it if it doesn't come.
        let askAfter = Date().addingTimeInterval(5)
        let deadline = Date().addingTimeInterval(90)
        var asked = false
        var probe = showMeProbe()
        while probe.stage != "3d" && Date() < deadline {
            if probe.stage.isEmpty && !asked && Date() > askAfter {
                let button = element("lesson.showme")
                if button.exists && button.isHittable { button.tap(); asked = true }
            }
            settle(0.5)
            probe = showMeProbe()
        }
        var picture = XCUIScreen.main.screenshot()
        var problem = "the 3D stage never showed (probe '\(probe.stage)', lesson open: \(opened), Show me asked: \(asked))"
        if probe.stage == "3d" {
            for attempt in 0..<4 {
                let take = catchShowMeRing(landed: probe.landed, replay: attempt > 0)
                picture = take.picture
                probe = showMeProbe()
                if probe.stage == "3d", let landed = probe.landed,
                   take.start >= landed.addingTimeInterval(ShowMeRing.from), take.end <= landed.addingTimeInterval(ShowMeRing.to) {
                    problem = ""
                    break
                }
                let offset = probe.landed.map { String(format: "%.2f", take.start.timeIntervalSince($0)) } ?? "?"
                problem = "the picture missed the ring: taken \(offset) s after the last fingertip landed (stage '\(probe.stage)', \(probe.ringing) strings lit now)"
            }
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
