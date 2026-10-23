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

    private func launch(onboarded: Bool = true, demo: Bool = true, studio: Bool = false, pitch: Bool = false, stageDebug: Bool = false) {
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
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        settle(2.5); shot("07-tune-first-run")
    }

    func test02TuneScreen() throws {
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        // The demo pitch drifts into tune over four seconds and re-plucks every six.
        settle(8); shot("10-tune-3d")
        settle(2.5); shot("10b-tune-locked")
        element("string.3").tap(); settle(1.5); shot("11-tune-string-selected")
        element("tune.instrument").tap(); settle(1.5); shot("12-instrument-picker")
        app.buttons["Done"].firstMatch.tap(); settle()
        element("settings.open").tap(); settle(1.5); shot("13-settings")
        // Pro upsell from inside the settings sheet presents the paywall on top of it.
        element("settings.pro").tap()
        XCTAssertTrue(element("paywall.purchase").waitForExistence(timeout: 15))
        settle(1.5); shot("16-paywall-from-settings")
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
        app.swipeUp(); settle(); shot("31-instruments-scrolled")
        app.buttons["Done"].firstMatch.tap(); settle()
        tab("Progress"); settle(2); shot("32-journey")
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
        // Pro instruments on their 3D stage.
        for (asset, name) in [("13_mandolin_mandolin", "49-tune-mandolin-3d"), ("17_bowed_strings_violin", "49b-tune-violin-3d"), ("19_bowed_strings_cello", "49c-tune-cello-3d")] {
            // The picker is still up after saving the custom tuning; later rounds open it from the tuner.
            openPicker()
            let card = element("instrument." + asset)
            scrollTo(card)
            card.tap(); settle(6); shot(name)
        }
    }

    func test08PhotoStage() throws {
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        openPicker()
        let ukulele = element("instrument.10_ukulele_soprano_ukulele")
        scrollTo(ukulele)
        ukulele.tap()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 15))
        settle(7); shot("17-tune-photo-stage")
        element("string.2").tap(); settle(3); shot("18-tune-photo-stage-string")
        openPicker()
        let bass = element("instrument.06_bass_4_string_p_bass")
        scrollTo(bass)
        bass.tap(); settle(6); shot("19-tune-bass-3d")
    }

    func test09LearnChordLesson() throws {
        launch(pitch: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 25))
        tab("Learn"); settle(2.5); shot("50-learn")
        element("learn.continue").tap(); settle(1.5); shot("51-lesson-explain")
        // The lesson zooms open: a tap during the transition can be dropped, so tap until the tune check shows.
        let skip = element("lesson.tunecheck.skip")
        for _ in 0..<4 where !skip.exists { element("lesson.continue").tap(); _ = skip.waitForExistence(timeout: 3) }
        settle(2.5); shot("52-lesson-tunecheck")
        // The tune check is covered by its own screenshot; skip the rest of it to keep the run short.
        if skip.exists { skip.tap() }
        settle(8); shot("52b-lesson-chord")
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
        if skip.exists { skip.tap(); settle(1) }
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
