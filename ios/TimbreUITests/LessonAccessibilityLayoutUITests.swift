import XCTest

/// Geometry/reachability regressions, not exemptions for the diagnostic accessibility audits.
final class LessonAccessibilityLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_STAGE_REST"] = "1"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }

    override func tearDownWithError() throws { app.terminate() }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func capture(_ name: String) {
        let picture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        picture.name = "layout-ax5-" + name
        picture.lifetime = .keepAlways
        add(picture)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "layout-ax5-" + name + "-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }

    /// Fixed controls are checked against the app viewport, independently of scrolling content.
    private func isClear(_ target: XCUIElement) -> Bool {
        isClear(target, within: app.frame)
    }

    private func isClear(_ target: XCUIElement, within viewport: CGRect) -> Bool {
        guard !viewport.isNull, !viewport.isEmpty, target.exists, target.isHittable else { return false }
        let frame = target.frame
        return frame.width > 0 && frame.height > 0
            && frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
            && frame.minY >= viewport.minY && frame.maxY <= viewport.maxY
    }

    private func contentViewport(_ scroll: XCUIElement, above bottom: CGFloat?) -> CGRect {
        let visible = scroll.frame.intersection(app.frame)
        guard !visible.isNull, !visible.isEmpty else { return .null }
        let clearBottom = min(visible.maxY, bottom ?? visible.maxY)
        guard clearBottom > visible.minY else { return .null }
        return CGRect(x: visible.minX, y: visible.minY, width: visible.width,
                      height: clearBottom - visible.minY)
    }

    /// Scroll the same target into its actual content viewport, below the header and above pinned actions.
    private func scrollClear(_ target: XCUIElement, above bottom: CGFloat? = nil) {
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.exists, "The overflowing lesson content must scroll")
        for _ in 0..<12 {
            let viewport = contentViewport(scroll, above: bottom)
            if isClear(target, within: viewport) { return }
            if target.exists && !viewport.isNull && target.frame.minY < viewport.minY {
                scroll.swipeDown(velocity: .slow)
            } else {
                scroll.swipeUp(velocity: .slow)
            }
        }
        capture("unreachable")
        XCTAssertTrue(isClear(target, within: contentViewport(scroll, above: bottom)),
                      "Target is not fully visible and hittable inside its scroll viewport: \(target)")
    }

    func testNotesAndTeachingContentRemainReachableAtAX5() throws {
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 40))
        app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()
        let lesson = element("learn.lesson.gtr-1-2")
        for _ in 0..<10 where !lesson.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(lesson.isHittable)
        lesson.tap()
        let next = element("lesson.continue")
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        let explanation = app.staticTexts.matching(NSPredicate(
            format: "label == %@", "From thick to thin: E, A, D, G, B, E. Try: Every Amateur Does Get Better Eventually."
        )).firstMatch
        scrollClear(explanation, above: element("lesson.hear").frame.minY)
        capture("explanation-scroll-clear")
        next.tap()
        let skip = element("lesson.tunecheck.skip")
        if skip.waitForExistence(timeout: 5) {
            XCTAssertTrue(isClear(skip), "Tune-check skip must be fully on screen")
            skip.tap()
        }
        let override = element("lesson.override")
        XCTAssertTrue(override.waitForExistence(timeout: 20))
        let hear = element("lesson.hear")
        XCTAssertTrue(isClear(element("lesson.close")), "Lesson close must stay on screen")
        XCTAssertTrue(isClear(hear), "Hear must remain fully on screen")
        XCTAssertTrue(isClear(override), "I played it must remain fully on screen")
        let target = element("lesson.notes.target")
        scrollClear(target, above: override.frame.minY)
        XCTAssertEqual(target.value as? String, "Listening…")
        capture("notes-status-scroll-clear")
        hear.tap()
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(isClear(hear), "Hear must remain reachable after activation")
        override.tap()
        Thread.sleep(forTimeInterval: 7)
        XCTAssertTrue(override.waitForExistence(timeout: 20))
        override.tap()
        let first = element("lesson.option.0")
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        for index in 0..<4 {
            scrollClear(element("lesson.option.\(index)"), above: next.frame.minY)
            capture("quiz-option-\(index)-scroll-clear")
        }
    }

    func testPlayAlongStartAndCompletedTakeAtAX5() throws {
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        app.launchEnvironment["TIMBRE_SCENE"] = "song-perform"
        app.launchEnvironment["TIMBRE_SCENE_SONG"] = "gtr-1-2"
        app.launch()
        XCTAssertTrue(element("lesson.close").waitForExistence(timeout: 30))
        let start = element("lesson.continue")
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        scrollClear(start)
        XCTAssertTrue(start.isEnabled)
        capture("along-ready-start-clear")
        start.tap()
        // Screenshot only during playback: accessibility queries stall the demo pitch's main-thread readings.
        Thread.sleep(forTimeInterval: 7)
        let playing = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        playing.name = "layout-ax5-along-playing"
        playing.lifetime = .keepAlways
        add(playing)
        Thread.sleep(forTimeInterval: 14)
        let again = element("along.again")
        XCTAssertTrue(again.waitForExistence(timeout: 30))
        capture("along-done-overlay")
        scrollClear(again)
        XCTAssertTrue(isClear(again))
        scrollClear(start)
        XCTAssertTrue(start.isEnabled)
        capture("along-done-actions-clear")
        start.tap()
        XCTAssertTrue(element("lesson.results.level").waitForExistence(timeout: 20))
        capture("lesson-results")
    }
}
