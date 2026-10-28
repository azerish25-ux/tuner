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

    private static func valid(_ frame: CGRect) -> Bool {
        [frame.minX, frame.maxX, frame.minY, frame.maxY, frame.width, frame.height].allSatisfy { $0.isFinite }
            && !frame.isNull && !frame.isEmpty && frame.width > 0 && frame.height > 0
    }

    private static func contains(_ frame: CGRect, in viewport: CGRect) -> Bool {
        valid(frame) && valid(viewport)
            && frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
            && frame.minY >= viewport.minY && frame.maxY <= viewport.maxY
    }

    /// A fitting but clipped target is moved toward the centre, not merely to an edge.
    /// Edge-only corrections can fall below gesture recognition distance and repeat without progress.
    private static func scrollDistance(_ frame: CGRect, in viewport: CGRect) -> CGFloat? {
        guard valid(frame), valid(viewport), frame.height <= viewport.height,
              frame.minX >= viewport.minX, frame.maxX <= viewport.maxX,
              !contains(frame, in: viewport) else { return nil }
        let delta = viewport.midY - frame.midY
        return min(viewport.height * 0.45, max(-viewport.height * 0.45, delta))
    }

    private func isClear(_ target: XCUIElement, within viewport: CGRect) -> Bool {
        guard target.exists else { return false }
        // Query geometry first; a hittable point is not evidence that the entire target is visible.
        return Self.contains(target.frame, in: viewport) && target.isHittable
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
        var observations: [String] = []
        defer {
            let trace = XCTAttachment(string: observations.joined(separator: "\n"))
            trace.name = "layout-ax5-scroll-geometry-" + target.identifier
            trace.lifetime = .keepAlways
            add(trace)
        }
        var previousFrame: CGRect?
        var previousViewport: CGRect?
        var stalled = 0
        for attempt in 0..<12 {
            let viewport = contentViewport(scroll, above: bottom)
            guard target.exists else { observations.append("target missing"); break }
            let frame = target.frame
            let contained = Self.contains(frame, in: viewport)
            let hittable = contained ? target.isHittable : false
            let row = "attempt=\(attempt) viewport=\(viewport) target=\(frame) contained=\(contained) hittableWhenContained=\(hittable)"
            observations.append(row)
            print("TIMBRE_SCROLL_GEOMETRY " + row)
            if contained && hittable { return }
            // Scrolling must not turn an oversized, horizontally clipped, or genuinely occluded
            // element into a passing result. An already contained but non-hittable target fails.
            guard let distance = Self.scrollDistance(frame, in: viewport), abs(distance) > 1 else {
                observations.append("no valid scroll plan; visibility/hittability still required")
                break
            }
            if let previousFrame, let previousViewport, previousViewport == viewport,
               abs(previousFrame.minY - frame.minY) < 1, abs(previousFrame.height - frame.height) < 1 {
                stalled += 1
            } else { stalled = 0 }
            guard stalled < 2 else { observations.append("two consecutive gestures made no measured progress"); break }
            previousFrame = frame
            previousViewport = viewport
            let origin = app.coordinate(withNormalizedOffset: .zero)
            // Stay inside the scroll view, away from the central note/teaching content and screen edge.
            let x = viewport.minX + min(24, viewport.width * 0.1)
            let start = origin.withOffset(CGVector(dx: x, dy: viewport.midY))
            let end = origin.withOffset(CGVector(dx: x, dy: viewport.midY + distance))
            observations.append("dragDelta=\(distance) gutterX=\(x)")
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        capture("unreachable")
        XCTAssertTrue(isClear(target, within: contentViewport(scroll, above: bottom)),
                      "Target is not fully visible and hittable inside its scroll viewport: \(target)")
    }

    func testReachabilityPlanRequiresCompleteGeometry() {
        let viewport = CGRect(x: 0, y: 116, width: 402, height: 580.7)
        let bottomClipped = CGRect(x: 0, y: 371.7, width: 402, height: 350)
        let topClipped = CGRect(x: 0, y: 106, width: 402, height: 350)
        let up = Self.scrollDistance(bottomClipped, in: viewport)!
        let down = Self.scrollDistance(topClipped, in: viewport)!
        XCTAssertLessThan(up, -25.3)
        XCTAssertGreaterThan(down, 10)
        XCTAssertTrue(Self.contains(bottomClipped.offsetBy(dx: 0, dy: up), in: viewport))
        XCTAssertTrue(Self.contains(topClipped.offsetBy(dx: 0, dy: down), in: viewport))
        XCTAssertFalse(Self.contains(bottomClipped, in: viewport))
        XCTAssertFalse(Self.contains(topClipped, in: viewport))
        XCTAssertNil(Self.scrollDistance(CGRect(x: 0, y: 130, width: 402, height: 350), in: viewport))
        XCTAssertNil(Self.scrollDistance(CGRect(x: 0, y: 100, width: 402, height: 700), in: viewport))
        XCTAssertNil(Self.scrollDistance(CGRect(x: -1, y: 100, width: 402, height: 350), in: viewport))
        XCTAssertNil(Self.scrollDistance(.zero, in: viewport))
        XCTAssertNil(Self.scrollDistance(.infinite, in: viewport))
        XCTAssertNil(Self.scrollDistance(topClipped, in: .null))
        // Actual 2013834 failure: the hidden burst's 580-point canvas inflated a 402-point
        // note target before any gesture. Never "fix" that horizontal overflow by scrolling.
        let decorationBounds = CGRect(x: -89, y: 315, width: 580, height: 580)
        XCTAssertFalse(Self.contains(decorationBounds, in: viewport))
        XCTAssertNil(Self.scrollDistance(decorationBounds, in: viewport))
        let farBelow = CGRect(x: 0, y: 1400, width: 402, height: 350)
        XCTAssertEqual(Self.scrollDistance(farBelow, in: viewport)!, -viewport.height * 0.45, accuracy: 0.001)
        XCTAssertFalse(Self.contains(farBelow.offsetBy(dx: 0, dy: -viewport.height * 0.45), in: viewport))
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
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "Fresh guitar fixture must present its tune check")
        capture("tunecheck-arrival")
        XCTAssertTrue(isClear(skip), "Tune-check skip must be fully on screen")
        XCTAssertEqual(skip.label, "My strings are tuned — skip")
        let tuneInstructions = element("lesson.tunecheck.instructions")
        XCTAssertEqual(tuneInstructions.label, "Pluck each open string. In-tune strings help Timbre hear you right.")
        for id in ["lesson.tunecheck.title", "lesson.tunecheck.instructions", "lesson.tunecheck.hint"] {
            scrollClear(element(id), above: skip.frame.minY)
            XCTAssertTrue(isClear(skip), "Skip must remain pinned while teaching content scrolls")
            XCTAssertTrue(isClear(element("lesson.close")))
            capture("tunecheck-scroll-clear-" + id)
        }
        XCTAssertEqual(element("lesson.tunecheck.hint").label, "Pluck the string")
        skip.tap()
        let override = element("lesson.override")
        XCTAssertTrue(override.waitForExistence(timeout: 20))
        let hear = element("lesson.hear")
        XCTAssertTrue(isClear(element("lesson.close")), "Lesson close must stay on screen")
        XCTAssertTrue(isClear(hear), "Hear must remain fully on screen")
        XCTAssertTrue(isClear(override), "I played it must remain fully on screen")
        let target = element("lesson.notes.target")
        scrollClear(target, above: override.frame.minY)
        XCTAssertEqual(target.label, "E, String 6, open")
        XCTAssertEqual(target.value as? String, "Listening…")
        // Correct focus bounds must contain the real rendered note and full status, not a
        // smaller synthetic proxy that lets clipped text pass through the viewport check.
        let notesViewport = contentViewport(app.scrollViews.firstMatch, above: override.frame.minY)
        XCTAssertGreaterThan(target.frame.height, 290, "AX5 target must include the status below its 290-point ring")
        for label in ["E", "Listening…"] {
            let text = target.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssertTrue(text.exists, "The complete visible note/status text must remain present: \(label)")
            XCTAssertTrue(Self.contains(text.frame, in: target.frame), "Focus bounds must include all visible text: \(label)")
            XCTAssertTrue(Self.contains(text.frame, in: notesViewport), "All note/status text must be inside the clear viewport: \(label)")
        }
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
