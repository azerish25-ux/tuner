import XCTest

/// 13-inch iPad captures in portrait and landscape (the iPad App Store frames and the tablet layouts). Every frame waits
/// for what it shows rather than for a fixed time: the tuner for its 3D stage (the studio render only stands in while
/// the model loads) and the scene's lock, the other screens for their content and for transitions to settle.
final class TabletScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        // The tuner holds a real lock (ios/Timbre/Root/DemoScenes.swift): two strings ticked, the third locked in tune.
        app.launchEnvironment["TIMBRE_SCENE"] = "tune-locked"
        // The tuner's probe (stage.state) says when the 3D model has replaced its studio render.
        app.launchEnvironment["TIMBRE_DEBUG_STATE"] = "1"
        app.launchArguments = ["-AppleLanguages", "(\(CaptureLocalization.language))", "-AppleLocale", CaptureLocalization.locale]
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func testTabletLayouts() throws {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 30))

        // App Store frame (iPad #1 in landscape): the 3D headstock with the scene's lock, never the studio stand-in.
        waitForStage()
        // Hands off while the scene's locks land, the camera settles on the third peg and the reward banner clears: a
        // query stalls the main thread, which restarts a hold.
        settle(7)
        tunerFrame("ipad-portrait-tune")

        XCUIDevice.shared.orientation = .landscapeLeft
        // The rotation, the new layout and the camera's re-aim; the stage keeps its model through the turn.
        settle(1.5)
        waitForStage(timeout: 30)
        settle(1.5)
        tunerFrame("ipad-landscape-tune")

        // App Store frame (iPad #2, "Violin to oud, sitar to erhu"): the instrument browser, a full page of its own on
        // iPad (Instruments/InstrumentsView.swift), never a sheet with the tuner's controls showing around it, scrolled
        // to the bowed strings and the Folk & world strings so the frame shows what its caption promises, ending on a
        // whole row. Kept only once the tuner has left the screen and sitar, oud and erhu are whole on it.
        element("tune.instrument").tap()
        XCTAssertTrue(element("instruments.search").waitForExistence(timeout: 10))
        settle(0.6)  // the page's presentation; `stillScreenshot` waits out the rails' first reveal
        let folk = scrollToFolkShelf()
        let browser = stillScreenshot(timeout: 3)
        // A full-screen cover keeps the tuner in the accessibility tree under it; covered, it can't be hit.
        let tuner = element("tune.stage")
        let alone = !tuner.exists || !tuner.isHittable
        storeFrame("ipad-landscape-instruments", picture: browser, ok: alone && folk,
                   alone ? "sitar, oud and erhu aren't whole on screen" : "the tuner is still on screen around the browser")
        closePicker()

        tab("Practice", until: "practice.sniper")
        shot("ipad-landscape-practice")
        tab("Songs", until: "songs.hero")
        shot("ipad-landscape-songs")
        tab("Learn", until: "learn.inspector")
        shot("ipad-landscape-learn")
        // The inspector follows a tap on the path: an earlier lesson, its steps and its picture; then back to the next
        // lesson (Your first chord: E minor), which the portrait frame shows.
        let earlier = element("learn.lesson.gtr-1-2")
        if earlier.waitForExistence(timeout: 5), earlier.isHittable {
            earlier.tap()
            settle(1.2)
            shot("ipad-landscape-learn-picked")
            let next = element("learn.lesson.gtr-1-4")
            if next.exists, next.isHittable { next.tap(); settle(0.8) }
        }
        tab("Progress", until: "journey.restrung")
        shot("ipad-landscape-progress")

        // Portrait: the same tabs as two-column grids.
        XCUIDevice.shared.orientation = .portrait
        settle(1.5)
        shot("ipad-portrait-progress")
        tab("Practice", until: "practice.sniper")
        shot("ipad-portrait-practice")
        tab("Learn", until: "learn.inspector")
        shot("ipad-portrait-learn")
        tab("Songs", until: "songs.hero")
        shot("ipad-portrait-songs")
    }

    // MARK: Helpers

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func settle(_ seconds: Double = 1.2) { Thread.sleep(forTimeInterval: seconds) }

    /// A capture once the screen has come to rest (StillScreen.swift): the tab's entrance, a sheet's rails and the
    /// cards' reveal done, rather than after a fixed wait.
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: stillScreenshot(timeout: 3))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Keeps a store frame under its own name when it shows what its caption says; otherwise the test fails and the
    /// picture is kept as "<name>-wrong", so the screenshot tool never frames it.
    private func storeFrame(_ name: String, picture: XCUIScreenshot, ok: Bool, _ problem: String) {
        if !ok { XCTFail("\(name): \(problem)") }
        let attachment = XCTAttachment(screenshot: picture)
        attachment.name = ok ? name : name + "-wrong"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A tuner frame for the listing: kept under its own name with the 3D stage up, the selected string locked and the
    /// In tune badge showing (it holds after a lock while the string stays in the band), otherwise kept as
    /// "<name>-wrong" (and the test fails) so the screenshot tool never frames a studio stand-in or a half-lock. Each
    /// picture is taken hands off, before the check's own snapshot (which stalls the main thread).
    private func tunerFrame(_ name: String) {
        var picture = XCUIScreen.main.screenshot()
        var problem = ""
        for attempt in 0..<3 {
            if attempt > 0 { settle(3); picture = XCUIScreen.main.screenshot() }
            let stage = tunerStage()
            let lock = lockedChips()
            if stage == "3d" && lock.selected && lock.badge { problem = ""; break }
            problem = "stage '\(stage)', \(lock.tuned) strings tuned, the selected one tuned: \(lock.selected), "
                + "In tune badge: \(lock.badge)"
        }
        if !problem.isEmpty { XCTFail("\(name): \(problem)") }
        let attachment = XCTAttachment(screenshot: picture)
        attachment.name = problem.isEmpty ? name : name + "-wrong"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Taps a tab (the iPad's tab bar sits at the top) until `until` shows; `shot` then waits for its entrance to settle.
    private func tab(_ name: String, until id: String) {
        guard let label = CaptureLocalization.tabLabel(name) else {
            XCTFail("Missing tablet capture tab fixture for \(CaptureLocalization.language): \(name)")
            return
        }
        let button = app.buttons[label].firstMatch
        let target = element(id)
        for _ in 0..<3 {
            if button.waitForExistence(timeout: 5) { button.tap() }
            if target.waitForExistence(timeout: 6) { break }
        }
        XCTAssertTrue(target.exists, "\(name) never showed \(id)")
        settle(0.6)
    }

    /// The cards the iPad #2 frame ends on, in the Folk & world strings shelf (InstrumentsView.swift keeps photos.json's
    /// order there, eight cards to a row in landscape, so the three share its second row).
    private static let folkCards = ["30_folk_world_strings_sitar", "33_folk_world_strings_oud_arabic", "37_folk_world_strings_erhu"]

    /// Scrolls the instrument browser down to the Folk & world strings until the row holding sitar, oud and erhu is
    /// whole on screen, aiming its foot at `folkRowFoot` above the screen's bottom edge: just above the page's bottom
    /// fade, with the bowed strings' row above the shelf. Any position where the three cards are whole between the
    /// navigation bar's shade and the bottom fade is accepted; the line is only the aim.
    ///
    /// Each move is measured, not assumed: short drags through the screen's centre, which start on a card, were seen to
    /// leave the page where it was while the long lazy-load drags scrolled. So the alignment drags start in the page's
    /// side margin (no card under the finger), go further than needed and correct back, and when a drag still doesn't
    /// move the page, a slow swipe takes over. Every attempt is logged.
    /// True when all three cards are whole on screen.
    private func scrollToFolkShelf() -> Bool {
        let cards = Self.folkCards.map { element("instrument." + $0) }
        let screen = screenFrame
        // The grid is lazy: down about half a page at a time until the shelf's cards are laid out.
        for _ in 0..<12 where !cards.allSatisfy({ $0.exists }) {
            drag(by: screen.height * 0.55)
        }
        let top = screen.minY + 96  // under the navigation bar and the page's top shade
        let foot = screen.maxY - 64  // above the bottom fade's darkest stretch
        let line = screen.maxY - Self.folkRowFoot
        var log: [String] = []
        var stuck = 0
        for attempt in 0..<10 {
            guard let span = folkSpan(cards) else { log.append("\(attempt): cards not found"); break }
            if span.minY >= top && span.maxY <= foot { return true }
            // Positive: the row sits too low, so the page moves up (content scrolls down the list).
            let offset = span.maxY - line
            // Past the line by a little more than the scroll view's slop, then the next round corrects back.
            let overshoot: CGFloat = attempt == 0 ? 0 : (offset > 0 ? 24 : -24)
            if stuck >= 2 {
                if offset > 0 { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
                settle(1.2)  // a swipe carries momentum: let it come to rest before measuring
            } else {
                drag(by: offset + overshoot, margin: attempt % 2 == 0 ? .leading : .trailing)
                settle(0.4)
            }
            let after = folkSpan(cards)
            let moved = after.map { abs($0.maxY - span.maxY) } ?? 0
            let how = stuck >= 2 ? "swipe" : "drag"
            log.append("\(attempt): foot \(Int(span.maxY)) -> \(Int(after?.maxY ?? -1)) (aim \(Int(line)), \(how))")
            stuck = moved < 4 ? stuck + 1 : 0
        }
        let whole = folkSpan(cards).map { $0.minY >= top && $0.maxY <= foot } ?? false
        if !whole {
            let boxes = cards.map { liveFrame($0).map { "\($0)" } ?? "none" }.joined(separator: ", ")
            print("FOLK SHELF: screen \(screen) app \(app.frame) window \(app.windows.firstMatch.frame) cards \(boxes) "
                  + "moves [\(log.joined(separator: "; "))]")
        }
        return whole
    }

    /// The top of the highest and the foot of the lowest of `cards`, from their live frames; nil when one is missing.
    private func folkSpan(_ cards: [XCUIElement]) -> (minY: CGFloat, maxY: CGFloat)? {
        let boxes = cards.compactMap { liveFrame($0) }
        guard boxes.count == cards.count else { return nil }
        return (boxes.map(\.minY).min() ?? 0, boxes.map(\.maxY).max() ?? 0)
    }

    /// The screen in the interface's own orientation. On a rotated iPad `app.frame` can still read portrait while the
    /// elements' frames are laid out in landscape, which put the scroll's target line off the screen.
    private var screenFrame: CGRect {
        let window = app.windows.firstMatch.frame
        var frame = window.isEmpty ? app.frame : window
        if XCUIDevice.shared.orientation.isLandscape && frame.height > frame.width {
            frame = CGRect(x: 0, y: 0, width: frame.height, height: frame.width)
        }
        return frame
    }

    /// From the screen's bottom edge to the foot of the frame's last whole row: the page's 64 pt bottom fade starts
    /// about 84 pt up (it runs on over the home indicator's 20 pt), and the 880 pt from the bowed strings' heading to
    /// the foot of the folk shelf's second row is a little more than fits under the navigation bar, so the heading goes
    /// under the bar (rather than half under it) and the bowed row leads the frame.
    private static let folkRowFoot: CGFloat = 100

    /// An element's frame from one snapshot; nil when it isn't there.
    private func liveFrame(_ target: XCUIElement) -> CGRect? {
        guard let box = (try? target.snapshot())?.frame, !box.isEmpty else { return nil }
        return box
    }

    /// Where a drag runs across the screen: down the middle (the long lazy-load drags), or down a side margin, outside
    /// the grid's cards (the browser's cards start 20 pt in from each edge), so the finger never lands on a button.
    private enum DragLane { case middle, leading, trailing }

    /// Scrolls the page `distance` points further down it (negative: back up) with one drag that holds still before
    /// lifting, so the page stops where the finger does. The scroll view's slop (about 10 pt) is added to the travel.
    private func drag(by distance: CGFloat, margin lane: DragLane = .middle) {
        let screen = screenFrame
        let travel = min(abs(distance) + 10, screen.height * 0.6)
        let lower = screen.height / 2 + travel / 2
        let upper = screen.height / 2 - travel / 2
        let x: CGFloat
        switch lane {
        case .middle: x = screen.width / 2
        case .leading: x = 8
        case .trailing: x = screen.width - 8
        }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: x, dy: distance > 0 ? lower : upper))
        let end = origin.withOffset(CGVector(dx: x, dy: distance > 0 ? upper : lower))
        start.press(forDuration: 0.08, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Closes the picker (a full page on iPad) with Done and waits for it to go; a swipe is the fallback.
    private func closePicker() {
        let search = element("instruments.search")
        let done = element("instruments.done")
        if done.waitForExistence(timeout: 6) { done.tap() } else { app.swipeDown(velocity: .fast) }
        if !search.waitForNonExistence(timeout: 6) { app.swipeDown(velocity: .fast); _ = search.waitForNonExistence(timeout: 4) }
        settle(1)
    }

    /// The tuner's UI-test probe (TIMBRE_DEBUG_STATE=1, never drawn): "stage=<3d|loading|2d> listening=<…>".
    private func tunerStage() -> String {
        guard let label = (try? element("stage.state").snapshot())?.label else { return "" }
        for field in label.split(separator: " ") where field.hasPrefix("stage=") {
            return String(field.dropFirst("stage=".count))
        }
        return ""
    }

    /// Waits for the 3D model to take over from the studio render that holds the stage while it loads (the first
    /// model on a fresh simulator can take 20 s or more), then for the cross-fade and the dolly in to the headstock.
    @discardableResult
    private func waitForStage(timeout: TimeInterval = 90) -> String {
        let started = Date()
        var stage = tunerStage()
        while stage != "3d" && stage != "2d" && Date().timeIntervalSince(started) < timeout {
            // No probe at all (not a debug build): don't wait out the whole timeout for it.
            if stage.isEmpty && Date().timeIntervalSince(started) > 15 { break }
            settle(0.5)
            stage = tunerStage()
        }
        settle(2.5)
        return tunerStage()
    }

    /// The string chips from one snapshot: how many read "Tuned", whether the selected one does, and whether the status
    /// line ("Hold it…") has stepped aside for the In tune badge.
    private func lockedChips() -> (tuned: Int, selected: Bool, badge: Bool) {
        guard let root = try? app.snapshot() else { return (0, false, false) }
        var chips: [String: (selected: Bool, tuned: Bool)] = [:]
        var status: String?
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children)
            if node.identifier == "tune.status" { status = node.label }
            guard node.identifier.hasPrefix("string.") else { continue }
            let seen = chips[node.identifier] ?? (selected: false, tuned: false)
            chips[node.identifier] = (selected: seen.selected || node.isSelected, tuned: seen.tuned || (node.value as? String) == "Tuned")
        }
        let badge = status == nil || status == "In tune"
        return (chips.values.filter { $0.tuned }.count, chips.values.contains { $0.selected && $0.tuned }, badge)
    }
}
