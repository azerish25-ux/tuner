import XCTest

/// Production catalogue reachability, not a smaller audit fixture. All 120 Bass Songbook records remain browsable.
final class SongShelfRailUITests: XCTestCase {
    private var app: XCUIApplication!
    private let samples = ["bass-sb-song-mary", "bass-sb-std-angels-from-the-realms", "bass-sb-orig-constellation-prize"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_STAGE_REST"] = "1"
    }

    override func tearDownWithError() throws {
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "song-rail-" + name; image.lifetime = .keepAlways; add(image)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "song-rail-" + name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
    }

    private func showRail() -> XCUIElement {
        let rail = app.scrollViews.matching(identifier: "songs.rail.bass-songbook").firstMatch
        let vertical = app.scrollViews.firstMatch
        for _ in 0..<24 {
            if rail.exists {
                let bounds = rail.frame
                let bottom = app.tabBars.firstMatch.frame.minY - 24
                if bounds.minY >= app.frame.minY + 70 && bounds.maxY <= bottom { return rail }
                if bounds.minY < app.frame.minY + 70 { vertical.swipeDown(velocity: .slow) }
                else { vertical.swipeUp(velocity: .slow) }
            } else { vertical.swipeUp(velocity: .slow) }
        }
        capture("vertical-unreachable")
        XCTFail("The complete songbook rail must fit vertically and remain reachable")
        return rail
    }

    private func reveal(_ id: String, in rail: XCUIElement, forward: Bool, rtl: Bool) -> XCUIElement {
        let target = rail.buttons.matching(identifier: "songs.song." + id).firstMatch
        // The visible target's geometry is physical in either language direction. Only discovery of an
        // unrealized target uses logical forward/backward; otherwise correct overshoot in either direction.
        for attempt in 0..<85 {
            let viewport = rail.frame
            guard usable(viewport) else {
                XCTFail("The catalogue rail must have a finite, nonempty viewport")
                return target
            }
            let limit = viewport.width * 0.6
            var distance: CGFloat = (forward != rtl) ? -limit : limit
            if target.exists {
                guard let frame = stableFrame(target) else { continue }
                // Asking isHittable for a realized but fully offscreen lazy child can itself throw an
                // XCTest activation-point error. Check all geometry first; never suppress that error.
                let atFirst = id == samples[0]
                let atLast = id == samples[2]
                let leading: CGFloat = (rtl ? atLast : atFirst) ? 19 : 52
                let trailing: CGFloat = (rtl ? atFirst : atLast) ? 19 : 52
                let fullyClear = frame.minX >= viewport.minX + leading && frame.maxX <= viewport.maxX - trailing
                    && frame.minY >= viewport.minY - 1 && frame.maxY <= viewport.maxY + 1
                if fullyClear {
                    XCTAssertTrue(target.isHittable, "The fully visible catalogue record must actually be hittable: \(id)")
                    return target
                }
                distance = max(-limit, min(limit, viewport.midX - frame.midX))
                print("SONG-RAIL reveal: id=\(id) attempt=\(attempt) target=\(frame) viewport=\(viewport) drag=\(distance)")
                if abs(distance) < 1 {
                    capture("geometry-unreachable-" + id)
                    XCTFail("The centered record does not fit the rail's unobscured bounds: \(id)")
                    return target
                }
            }
            dragRail(rail, distance: distance, viewport: viewport)
        }
        capture("horizontal-unreachable-" + id)
        XCTFail("First/middle/last catalogue record must remain fully reachable: \(id)")
        return target
    }

    private func usable(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && frame.minX.isFinite && frame.minY.isFinite
            && frame.width.isFinite && frame.height.isFinite && frame.width > 0 && frame.height > 0
    }

    /// Read back geometry after a gesture and its scroll transition, rather than testing a stale edge frame.
    private func stableFrame(_ target: XCUIElement) -> CGRect? {
        guard target.exists else { return nil }
        var previous = target.frame
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 0.15)
            guard target.exists else { return nil }
            let current = target.frame
            if usable(current) && usable(previous)
                && abs(current.minX - previous.minX) <= 1 && abs(current.minY - previous.minY) <= 1
                && abs(current.width - previous.width) <= 1 && abs(current.height - previous.height) <= 1 {
                return current
            }
            previous = current
        }
        return nil
    }

    private func dragRail(_ rail: XCUIElement, distance: CGFloat, viewport: CGRect) {
        // Both endpoints stay within the visible sleeve band, away from preview/version controls.
        // Hold after the slow drag to avoid inertial travel skipping a target's 150-point clear band.
        let startX = viewport.width * 0.5 - distance / 2
        let endX = viewport.width * 0.5 + distance / 2
        let y = min(viewport.height * 0.4, 70)
        let origin = rail.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: startX, dy: y))
        let end = origin.withOffset(CGVector(dx: endX, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    private func verifyActions(_ id: String, tile: XCUIElement, rail: XCUIElement) {
        let preview = rail.buttons.matching(identifier: "songs.sample." + id).firstMatch
        XCTAssertTrue(preview.isHittable)
        let stopped = preview.label
        preview.tap()
        XCTAssertTrue(NSPredicate(format: "label != %@", stopped).evaluate(with: preview)
                      || XCTWaiter.wait(for: [expectation(for: NSPredicate(format: "label != %@", stopped), evaluatedWith: preview)], timeout: 5) == .completed)
        preview.tap()
        XCTAssertTrue(NSPredicate(format: "label == %@", stopped).evaluate(with: preview))
        let versions = rail.buttons.matching(identifier: "songs.versions." + id).firstMatch
        XCTAssertTrue(versions.isHittable, "The separate versions control must survive virtualization")
        versions.tap()
        let ownVersion = app.buttons.matching(identifier: "songs.tile." + id + ".version." + id).firstMatch
        XCTAssertTrue(ownVersion.waitForExistence(timeout: 5), "The menu must expose the actual version choices")
        ownVersion.tap()
        dismissDestination()
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "Returning must preserve the same source tile")
        tile.tap()
        dismissDestination()
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "The primary card action must return to the same tile")
    }

    private func dismissDestination() {
        let close = element("lesson.close")
        let paywallClose = element("paywall.close")
        if close.waitForExistence(timeout: 8) { close.tap() }
        else {
            XCTAssertTrue(paywallClose.waitForExistence(timeout: 8))
            paywallClose.tap()
        }
    }

    private func exercise(accessible: Bool, rtl: Bool) {
        app.launchArguments = ["-AppleLanguages", rtl ? "(ar)" : "(en)", "-AppleLocale", rtl ? "ar_SA" : "en_US",
                               "-songs.instrument", "bass.electric.4"]
        if accessible { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let tabs = app.tabBars.firstMatch.buttons
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 30))
        tabs.element(boundBy: 2).tap()
        let rail = showRail()
        let height = rail.frame.height
        for (index, id) in samples.enumerated() {
            let tile = reveal(id, in: rail, forward: true, rtl: rtl)
            XCTAssertEqual(rail.frame.height, height, accuracy: 1, "An offscreen taller caption must not move the row")
            XCTAssertLessThanOrEqual(tile.frame.height, height + 1)
            for role in ["duration", "xp"] {
                let leaf = element("songs.tile." + id + "." + role)
                XCTAssertTrue(leaf.exists, "The actual caption leaf must be exposed, not silently skipped: \(role)")
                XCTAssertGreaterThanOrEqual(leaf.frame.minX, tile.frame.minX - 1)
                XCTAssertLessThanOrEqual(leaf.frame.maxX, tile.frame.maxX + 1)
                XCTAssertGreaterThanOrEqual(leaf.frame.minY, tile.frame.minY - 1)
                XCTAssertLessThanOrEqual(leaf.frame.maxY, min(tile.frame.maxY, rail.frame.maxY) + 1)
            }
            capture("\(accessible ? "ax5" : "normal")-\(rtl ? "rtl" : "ltr")-\(index)")
            verifyActions(id, tile: tile, rail: rail)
        }
        // A browsed row must not jump back to its initially selected first song on rotation.
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2)
        let landscapeLast = rail.buttons.matching(identifier: "songs.song." + samples[2]).firstMatch
        XCTAssertTrue(landscapeLast.exists && landscapeLast.isHittable,
                      "The browsed terminal record must remain visible in landscape before returning")
        XCTAssertLessThanOrEqual(landscapeLast.frame.height, rail.frame.height + 1)
        capture("landscape-\(accessible)-\(rtl)")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)
        let last = rail.buttons.matching(identifier: "songs.song." + samples[2]).firstMatch
        XCTAssertTrue(last.exists && last.isHittable, "Rotation must preserve the browsed end, not reselect the first item")
        _ = reveal(samples[0], in: rail, forward: false, rtl: rtl)
        XCTAssertEqual(rail.frame.height, height, accuracy: 1)
    }

    func testFirstMiddleLastSongActionsAndStableHeight() { exercise(accessible: false, rtl: false) }
    func testFirstMiddleLastSongActionsAtAX5() { exercise(accessible: true, rtl: false) }
    func testFullCatalogueRemainsReachableRightToLeft() { exercise(accessible: false, rtl: true) }
}
