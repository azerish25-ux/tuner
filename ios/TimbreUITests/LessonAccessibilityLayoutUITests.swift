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
    private func scrollClear(_ target: XCUIElement, above bottom: CGFloat? = nil,
                             in contentScroll: XCUIElement? = nil) {
        let scroll = contentScroll ?? app.scrollViews.firstMatch
        XCTAssertTrue(scroll.exists, "The overflowing lesson content must scroll")
        var observations: [String] = []
        var traceAttached = false
        func attachTrace() {
            guard !traceAttached else { return }
            traceAttached = true
            let trace = XCTAttachment(string: observations.joined(separator: "\n"))
            trace.name = "layout-ax5-scroll-geometry-" + target.identifier
            trace.lifetime = .keepAlways
            add(trace)
        }
        defer { attachTrace() }
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
        // XCTest can abort immediately with continueAfterFailure=false; attach before failing.
        attachTrace()
        capture("unreachable")
        XCTAssertTrue(isClear(target, within: contentViewport(scroll, above: bottom)),
                      "Target is not fully visible and hittable inside its scroll viewport: \(target)")
    }

    /// Only a previously clear target below a newly shortened viewport may need lazy rediscovery.
    /// Its old rectangle chooses a search direction; it is never accepted as current geometry.
    private static func quizRediscoveryDistance(previousFrame: CGRect, previousViewport: CGRect,
                                                viewport: CGRect) -> CGFloat? {
        guard contains(previousFrame, in: previousViewport), valid(viewport),
              viewport.minX == previousViewport.minX, viewport.width == previousViewport.width,
              viewport.minY == previousViewport.minY, viewport.height < previousViewport.height,
              previousFrame.minY >= viewport.maxY else { return nil }
        return -min(120, viewport.height * 0.35)
    }

    /// Feedback is a pinned sibling: at AX5 it shortens the quiz scroll view and can dematerialize
    /// its LazyVGrid. Search only for the exact, already observed answer in this same quiz step.
    private func rediscoverSelectedFirstQuizOption(_ first: XCUIElement, in scroll: XCUIElement,
                                                   prompt: XCUIElement, header: XCUIElement,
                                                   next: XCUIElement, previousFrame: CGRect,
                                                   previousViewport: CGRect) {
        var observations: [String] = []
        var traceAttached = false
        func attachTrace() {
            guard !traceAttached else { return }
            traceAttached = true
            let trace = XCTAttachment(string: observations.joined(separator: "\n"))
            trace.name = "layout-ax5-selected-quiz-rediscovery"
            trace.lifetime = .keepAlways
            add(trace)
        }
        defer { attachTrace() }
        let promptLabel = "What is string 5 called?"
        let promptPredicate = NSPredicate(format: "label == %@", promptLabel)
        let headerPredicate = NSPredicate(format: "label == %@", "The open strings")
        let feedbackPredicate = NSPredicate(format: "label == %@", "Nice — that’s right.")
        func sameStep() -> Bool {
            guard header.exists && header.label == "The open strings" && (header.value as? String) == "Step 4 of 6"
                && app.otherElements.matching(headerPredicate).count == 1
                && prompt.exists && prompt.label == promptLabel
                && scroll.exists && scroll.staticTexts.matching(promptPredicate).count == 1
                && app.staticTexts.matching(feedbackPredicate).count == 1
                && next.exists && next.identifier == "lesson.continue" && next.label == "Continue"
                && next.isEnabled && isClear(next) else { return false }
            let matchingScrolls: [XCUIElement] = app.scrollViews.allElementsBoundByIndex.filter {
                $0.staticTexts.matching(promptPredicate).count == 1
            }
            return matchingScrolls.count == 1
        }
        func exactAnswerExists() -> Bool {
            first.exists && first.identifier == "lesson.option.0" && first.elementType == .button
                && first.isEnabled
                && first.staticTexts.matching(NSPredicate(format: "label == %@", "A")).count == 1
                && scroll.buttons.matching(identifier: "lesson.option.0").count == 1
                && app.descendants(matching: .any).matching(identifier: "lesson.option.0").count == 1
        }
        if !first.exists { capture("quiz-post-feedback-before-rediscovery") }
        for attempt in 0..<4 {
            guard sameStep() else { observations.append("same quiz-step witness lost"); break }
            if exactAnswerExists() {
                observations.append("rediscovered currentLabel=\(first.label) frame=\(first.frame)")
                return // Only rediscovery; scrollClear still proves current geometry.
            }
            guard !first.exists else { observations.append("answer identity changed or duplicated"); break }
            let viewport = contentViewport(scroll, above: next.frame.minY)
            let before = prompt.frame
            guard let distance = Self.quizRediscoveryDistance(previousFrame: previousFrame,
                                                               previousViewport: previousViewport,
                                                               viewport: viewport), Self.valid(before),
                  abs(distance) > 1 else {
                observations.append("no bounded post-feedback rediscovery plan")
                break
            }
            // The quiz content has 20-point horizontal padding; stay in that non-button gutter.
            let x = viewport.minX + min(12, viewport.width * 0.1)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: x, dy: viewport.midY))
            let end = origin.withOffset(CGVector(dx: x, dy: viewport.midY + distance))
            let row = "attempt=\(attempt) missing=lesson.option.0 viewport=\(viewport) promptBefore=\(before) dragDelta=\(distance)"
            observations.append(row)
            print("TIMBRE_QUIZ_REDISCOVERY " + row)
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            guard sameStep() else { observations.append("quiz-step witness lost after gesture"); break }
            let after = prompt.frame
            observations.append("promptAfter=\(after) targetExists=\(first.exists)")
            // A gesture is not progress by itself. Do not keep blindly dragging if content stalled.
            guard Self.valid(after), contentViewport(scroll, above: next.frame.minY) == viewport,
                  abs(after.minX - before.minX) < 1, abs(after.width - before.width) < 1,
                  abs(after.height - before.height) < 1, before.minY - after.minY >= 1 else {
                observations.append("no measured upward content progress in stable viewport")
                break
            }
            if exactAnswerExists() {
                observations.append("rediscovered currentLabel=\(first.label) frame=\(first.frame)")
                return
            }
        }
        attachTrace()
        capture("quiz-post-feedback-rediscovery-failed")
        XCTFail("Previously observed lesson.option.0 was not rediscovered unchanged in the same quiz step")
    }

    func testQuizRediscoveryRequiresPreviouslyClearTargetAndShrunkenViewport() {
        let before = CGRect(x: 0, y: 116, width: 402, height: 651.3333333333334)
        let after = CGRect(x: 0, y: 116, width: 402, height: 427.7)
        let selected = CGRect(x: 20, y: 577.3333333333333, width: 176, height: 84.00000000000011)
        let distance = Self.quizRediscoveryDistance(previousFrame: selected, previousViewport: before, viewport: after)
        XCTAssertEqual(distance, CGFloat(-120))
        XCTAssertFalse(Self.contains(selected, in: after)) // The old witness never proves visibility.
        XCTAssertGreaterThan(after.midY + distance!, after.minY)
        XCTAssertLessThan(after.midY, after.maxY)
        for invalidViewport in [before, CGRect(x: 1, y: 116, width: 402, height: 427.7),
                                CGRect(x: 0, y: 117, width: 402, height: 427.7), .null, .zero, .infinite] {
            XCTAssertNil(Self.quizRediscoveryDistance(previousFrame: selected, previousViewport: before,
                                                       viewport: invalidViewport))
        }
        for invalidFrame in [CGRect(x: 20, y: 120, width: 176, height: 84),
                             CGRect(x: -1, y: 577, width: 176, height: 84),
                             CGRect(x: 20, y: 740, width: 176, height: 84), .zero, .infinite] {
            XCTAssertNil(Self.quizRediscoveryDistance(previousFrame: invalidFrame, previousViewport: before,
                                                       viewport: after))
        }
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
        // A quiz reward also must not enlarge its button or become a duplicate target.
        let quizDecorationBounds = CGRect(x: -22, y: 532, width: 260, height: 260)
        XCTAssertFalse(Self.contains(quizDecorationBounds, in: viewport))
        XCTAssertNil(Self.scrollDistance(quizDecorationBounds, in: viewport))
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
        assertQuizOptionsReachableAndSelectable(above: next)
    }

    private func assertQuizOptionsReachableAndSelectable(above next: XCUIElement) {
        let first = app.buttons.matching(identifier: "lesson.option.0").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        let promptPredicate = NSPredicate(format: "label == %@", "What is string 5 called?")
        let prompts = app.staticTexts.matching(promptPredicate)
        let headers = app.otherElements.matching(NSPredicate(format: "label == %@", "The open strings"))
        XCTAssertEqual(prompts.count, 1)
        XCTAssertEqual(headers.count, 1)
        let prompt = prompts.firstMatch
        let header = headers.firstMatch
        XCTAssertEqual(header.value as? String, "Step 4 of 6")
        let quizScrolls = app.scrollViews.allElementsBoundByIndex.filter {
            $0.staticTexts.matching(promptPredicate).count == 1
        }
        XCTAssertEqual(quizScrolls.count, 1, "The quiz prompt must identify one real content scroll view")
        guard let quizScroll = quizScrolls.first else { return }
        for (index, label) in ["A", "D", "B", "G"].enumerated() {
            let id = "lesson.option.\(index)"
            let option = app.buttons.matching(identifier: id).firstMatch
            XCTAssertTrue(option.exists, "Every answer must remain a semantic button")
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: id).count, 1,
                           "A decorative background must not inherit the answer's identity")
            XCTAssertEqual(option.label, label, "Every answer must retain its complete text")
            scrollClear(option, above: next.frame.minY)
            XCTAssertTrue(option.isEnabled)
            capture("quiz-option-\(index)-scroll-clear")
        }
        // Return from the last row and activate the real first button, rather than an
        // identically named decoration. Its selected state must remain reachable too.
        scrollClear(first, above: next.frame.minY)
        let previousFrame = first.frame
        let previousViewport = contentViewport(quizScroll, above: next.frame.minY)
        XCTAssertTrue(Self.contains(previousFrame, in: previousViewport) && first.isHittable)
        XCTAssertEqual(first.identifier, "lesson.option.0")
        XCTAssertEqual(first.label, "A")
        XCTAssertEqual(first.elementType, .button)
        XCTAssertEqual(quizScroll.buttons.matching(identifier: "lesson.option.0").count, 1)
        XCTAssertEqual(header.value as? String, "Step 4 of 6")
        first.tap()
        let feedback = app.staticTexts.matching(NSPredicate(format: "label == %@", "Nice — that’s right.")).firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout: 10))
        XCTAssertEqual(next.label, "Continue")
        XCTAssertTrue(next.isEnabled)
        XCTAssertTrue(isClear(next), "Continue must remain pinned after selecting an answer")
        rediscoverSelectedFirstQuizOption(first, in: quizScroll, prompt: prompt, header: header, next: next,
                                          previousFrame: previousFrame, previousViewport: previousViewport)
        scrollClear(first, above: next.frame.minY, in: quizScroll)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "lesson.option.0").count, 1)
        XCTAssertEqual(first.identifier, "lesson.option.0")
        XCTAssertEqual(first.elementType, .button)
        XCTAssertTrue(first.isEnabled)
        let answerText = first.staticTexts.matching(NSPredicate(format: "label == %@", "A"))
        XCTAssertEqual(answerText.count, 1, "The selected answer must retain its complete text")
        XCTAssertTrue(Self.contains(answerText.firstMatch.frame, in: first.frame))
        XCTAssertTrue(Self.contains(answerText.firstMatch.frame, in: contentViewport(quizScroll, above: next.frame.minY)))
        XCTAssertEqual(header.value as? String, "Step 4 of 6")
        capture("quiz-correct-answer-scroll-clear")
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
