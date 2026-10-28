import UIKit
import XCTest

/// Real-app compact-phone coverage. Run explicitly on an iPhone SE (3rd generation), not a resized image.
/// Screenshots include the real listening orb/meter; semantic geometry does not prove decorative-pixel bounds.
final class TuneCheckLayoutUITests: XCTestCase {
    private var app: XCUIApplication!
    private var sample = "unstarted"
    private var observations: [String] = []
    private var watched: [String: XCUIElement] = [:]
    private var header: XCUIElement!
    private var skip: XCUIElement!
    private var close: XCUIElement!
    private var pinnedSkip = CGRect.zero
    private var pinnedClose = CGRect.zero

    private struct Failure: Error, CustomStringConvertible { let description: String }

    private struct Copy {
        let language: String
        let locale: String
        let learn: String
        let lesson: String
        let tuneUp: String
        let title: String
        let instructions: String
        let hint: String
        let skip: String
        let stringPattern: String
        let boardPattern: String
        static let english = Copy(language: "en", locale: "en_US", learn: "Learn", lesson: "The open strings",
            tuneUp: "Tune up", title: "Quick tune check",
            instructions: "Pluck each open string. In-tune strings help Timbre hear you right.",
            hint: "Pluck the string", skip: "My strings are tuned — skip",
            stringPattern: "String [1-6]", boardPattern: "string 6 open")
        static let arabic = Copy(language: "ar", locale: "ar_SA", learn: "تعلّم", lesson: "الأوتار المطلقة",
            tuneUp: "ضبط الآلة", title: "فحص سريع للضبط",
            instructions: "انقر كل وتر مفتوح. الأوتار المضبوطة تساعد Timbre على سماعك بدقة.",
            hint: "انقر الوتر", skip: "أوتاري مضبوطة — تخطٍّ",
            stringPattern: "الوتر [1-6١-٦]", boardPattern: "الوتر [6٦] مفتوح")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testEnglishPortraitLarge() throws { try exercise(.english, landscape: false, ax5: false) }
    func testEnglishLandscapeLarge() throws { try exercise(.english, landscape: true, ax5: false) }
    func testEnglishPortraitAX5() throws { try exercise(.english, landscape: false, ax5: true) }
    func testEnglishLandscapeAX5() throws { try exercise(.english, landscape: true, ax5: true) }
    func testArabicPortraitLarge() throws { try exercise(.arabic, landscape: false, ax5: false) }
    func testArabicLandscapeLarge() throws { try exercise(.arabic, landscape: true, ax5: false) }
    func testArabicPortraitAX5() throws { try exercise(.arabic, landscape: false, ax5: true) }
    func testArabicLandscapeAX5() throws { try exercise(.arabic, landscape: true, ax5: true) }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private var screen: CGRect { app.windows.firstMatch.frame }

    private static func valid(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isEmpty
            && [frame.minX, frame.maxX, frame.minY, frame.maxY].allSatisfy { $0.isFinite }
    }

    private static func contains(_ frame: CGRect, in viewport: CGRect) -> Bool {
        valid(frame) && valid(viewport) && frame.minX >= viewport.minX && frame.maxX <= viewport.maxX
            && frame.minY >= viewport.minY && frame.maxY <= viewport.maxY
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            observations.append("FAIL: " + message)
            capture("failure") // Attach before throwing, not a defer after a fatal XCTest assertion.
            throw Failure(description: message)
        }
    }

    private func exercise(_ copy: Copy, landscape: Bool, ax5: Bool) throws {
        sample = "\(copy.language)-\(landscape ? "landscape" : "portrait")-\(ax5 ? "AX5" : "Large")"
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_STAGE_REST"] = "1"
        // Existing UserDefaults argument domain: each case must really enter today's check, even after a prior skip.
        // No synthetic pitch: the genuine waiting state cannot tune itself away while geometry is inspected.
        app.launchArguments = ["-AppleLanguages", "(\(copy.language))", "-AppleLocale", copy.locale,
            "-UIPreferredContentSizeCategoryName", ax5 ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
            "-tunecheck.guitar.acoustic.6", "1900-01-01"]
        app.launch()
        try require(element("tune.stage").waitForExistence(timeout: 40), "Actual app did not reach the tuner")
        try require(screen.size == CGSize(width: 375, height: 667),
                    "Compact fixture requires an actual 375×667-point iPhone window, got \(screen)")
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", copy.learn))
        try require(tab.count == 1 && tab.firstMatch.isHittable, "Unique localized Learn tab is not available")
        tab.firstMatch.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: tab.firstMatch)
        try require(XCTWaiter.wait(for: [selected], timeout: 10) == .completed, "Learn tab did not become selected")
        let lesson = element("learn.lesson.gtr-1-2")
        for _ in 0..<10 {
            if lesson.exists && lesson.isHittable && Self.contains(lesson.frame, in: screen) { break }
            let scroll = app.scrollViews.firstMatch
            if lesson.exists && Self.valid(lesson.frame) && scroll.exists {
                let room = scroll.frame.intersection(screen)
                let delta = max(-room.height * 0.4, min(room.height * 0.4, room.midY - lesson.frame.midY))
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(dx: room.midX, dy: room.midY))
                let end = origin.withOffset(CGVector(dx: room.midX, dy: room.midY + delta))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            } else { app.swipeUp(velocity: .slow) }
        }
        try require(lesson.exists && lesson.isHittable && Self.contains(lesson.frame, in: screen),
                    "The open-strings lesson must be a fully visible actual Learn-path target")
        lesson.tap()
        let next = element("lesson.continue")
        try require(next.waitForExistence(timeout: 20) && next.isHittable && Self.contains(next.frame, in: screen),
                    "The first real lesson explanation did not provide a clear Continue action")
        next.tap()
        skip = element("lesson.tunecheck.skip")
        try require(skip.waitForExistence(timeout: 15), "Fresh guitar lesson did not enter its actual TuneCheckStep")
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        let expectedSize = landscape ? CGSize(width: 667, height: 375) : CGSize(width: 375, height: 667)
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { [unowned self] _, _ in
            self.screen.size == expectedSize
        }, object: nil)
        try require(XCTWaiter.wait(for: [rotated], timeout: 10) == .completed,
                    "Native window did not report the requested orientation; no transposed-frame substitute is accepted")
        close = element("lesson.close")
        let headers = app.otherElements.matching(NSPredicate(format: "label == %@ AND value == %@", copy.lesson, copy.tuneUp))
        try require(headers.count == 1, "Expected localized lesson header with real Tune up state")
        header = headers.firstMatch
        try require(copy.language == "ar" ? close.frame.midX > header.frame.midX : close.frame.midX < header.frame.midX,
                    "The actual lesson header must mirror with its language; translated copy alone does not prove RTL")
        let title = element("lesson.tunecheck.title")
        let instructions = element("lesson.tunecheck.instructions")
        let hint = element("lesson.tunecheck.hint")
        for (target, expected) in [(title, copy.title), (instructions, copy.instructions), (hint, copy.hint), (skip!, copy.skip)] {
            try require(target.exists && target.label == expected, "Actual visible language/state differs: \(expected)")
        }
        let notes = app.staticTexts.matching(NSPredicate(format: "label == %@", "E2"))
        try require(notes.count == 1, "The first actual listening target must remain E2")
        let note = notes.firstMatch
        let boards = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", copy.boardPattern))
        try require(boards.count == 1, "Expected the actual string-6 open fretboard, not a geometry proxy")
        let board = boards.firstMatch
        let chips = app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", copy.stringPattern))
        try require(chips.count == 6, "Every real string chip must remain in the accessibility tree")
        let rail = chips.allElementsBoundByIndex.sorted { $0.frame.minX < $1.frame.minX }
        for (index, chip) in rail.enumerated() {
            let number = chip.label.compactMap(\.wholeNumberValue).last
            try require(number == 6 - index && (chip.value as? String) == ["E", "A", "D", "G", "B", "E"][index],
                        "RTL must not reverse the physical string rail or lose its note/number")
        }
        try require(rail[0].isSelected, "String 6 must be the actual current string")
        watched = ["header": header, "close": close, "skip": skip, "title": title, "instructions": instructions,
                   "note": note, "hint": hint, "fretboard": board]
        for (index, chip) in rail.enumerated() { watched["string-\(6 - index)"] = chip }
        pinnedSkip = skip.frame
        pinnedClose = close.frame
        capture("arrival")
        try assertPinned()
        let scrolls = app.scrollViews.allElementsBoundByIndex.filter {
            $0.descendants(matching: .any).matching(identifier: "lesson.tunecheck.instructions").count == 1
        }
        try require(scrolls.count == (ax5 ? 1 : 0), "Expected the actual TuneCheckStep scrolling branch")
        let scroll = scrolls.first
        for (name, target) in [("title", title), ("instructions", instructions), ("rail", rail[0]),
                               ("note", note), ("hint", hint), ("fretboard", board)] {
            try reveal(target, in: scroll)
            if name == "rail" {
                for chip in rail {
                    try require(Self.contains(chip.frame, in: viewport(scroll)) && chip.isHittable,
                                "All six chips must fit the same visible rail, not only its first chip")
                }
            }
            // Read both frames from the same live content position, not a cached pre-scroll screenshot.
            let railTop = rail.map { $0.frame.minY }.min()!
            let railBottom = rail.map { $0.frame.maxY }.max()!
            try require(railTop - 8 >= instructions.frame.maxY + 14,
                        "The reserved reward band must not borrow the instruction's 14-point gap")
            try require(railBottom + 8 + 14 <= note.frame.minY,
                        "The reward band must stay separated from the actual listening note")
            capture("clear-" + name)
        }
        try assertPinned()
        skip.tap()
        let nextTarget = element("lesson.notes.target")
        try require(nextTarget.waitForExistence(timeout: 15) && !element("lesson.tunecheck.skip").exists,
                    "The visible Skip action must actually leave TuneCheckStep for the lesson's notes step")
        capture("skip-activated")
    }

    private func assertPinned() throws {
        for (name, target) in [("Skip", skip!), ("Close", close!), ("Header", header!)] {
            try require(target.exists && Self.contains(target.frame, in: screen) && target.isHittable,
                        "\(name) must remain wholly visible and hittable")
        }
        try require(skip.frame == pinnedSkip && close.frame == pinnedClose,
                    "Teaching-content scrolling must not move the fixed actions")
    }

    private func viewport(_ scroll: XCUIElement?) -> CGRect {
        let top = max(header.frame.maxY, close.frame.maxY)
        let bottom = min(screen.maxY, skip.frame.minY)
        guard bottom > top else { return .null }
        let content = CGRect(x: screen.minX, y: top, width: screen.width, height: bottom - top)
        return scroll.map { $0.frame.intersection(content) } ?? content
    }

    private func reveal(_ target: XCUIElement, in scroll: XCUIElement?) throws {
        var previous: CGRect?
        var stalled = 0
        for attempt in 0..<12 {
            try assertPinned()
            try require(target.exists, "The exact teaching target disappeared before it could be checked")
            let frame = target.frame
            let room = viewport(scroll)
            observations.append("attempt=\(attempt) target=\(target.label) frame=\(frame) viewport=\(room)")
            if Self.contains(frame, in: room) && target.isHittable { return }
            guard let scroll else {
                try require(false, "Normal-size teaching target is clipped; no scrolling fallback exists: \(target.label)")
                return
            }
            try require(Self.valid(room) && frame.width <= room.width && frame.height <= room.height
                        && frame.minX >= room.minX && frame.maxX <= room.maxX,
                        "The complete teaching target cannot fit its real viewport: \(target.label)")
            try require(!Self.contains(frame, in: room), "Contained but non-hittable target must not be scrolled into a false pass")
            if let previous, abs(previous.minY - frame.minY) < 1 { stalled += 1 } else { stalled = 0 }
            try require(stalled < 2, "Two gestures made no measured progress")
            previous = frame
            let distance = max(-room.height * 0.45, min(room.height * 0.45, room.midY - frame.midY))
            try require(abs(distance) > 1, "No useful bounded scroll plan remains")
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: room.midX, dy: room.midY))
            let end = origin.withOffset(CGVector(dx: room.midX, dy: room.midY + distance))
            observations.append("scroll=\(scroll.frame) interiorX=\(room.midX) dragDelta=\(distance)")
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        try require(false, "Teaching target remained unreachable after the bounded scroll attempts")
    }

    private func capture(_ phase: String) {
        let prefix = "tunecheck-compact-" + sample + "-" + phase
        let screenshot = XCUIScreen.main.screenshot()
        let picture = XCTAttachment(screenshot: screenshot)
        picture.name = prefix
        picture.lifetime = .keepAlways
        add(picture)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = prefix + "-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
        var targets: [String: Any] = [:]
        for (name, target) in watched {
            targets[name] = target.exists ? ["label": target.label, "value": String(describing: target.value),
                "frame": [target.frame.minX, target.frame.minY, target.frame.width, target.frame.height],
                "hittable": target.isHittable] : ["exists": false]
        }
        let metadata: [String: Any] = ["sample": sample, "phase": phase, "window": [screen.minX, screen.minY, screen.width, screen.height],
            "appFrame": String(describing: app.frame), "orientation": XCUIDevice.shared.orientation.rawValue,
            "screenshotPixels": [screenshot.image.cgImage?.width ?? 0, screenshot.image.cgImage?.height ?? 0],
            "launchArguments": app.launchArguments, "targets": targets, "observations": observations]
        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]) {
            let geometry = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            geometry.name = prefix + "-geometry"
            geometry.lifetime = .keepAlways
            add(geometry)
        }
    }
}
