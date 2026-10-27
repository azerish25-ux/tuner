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
        for _ in 0..<85 {
            if target.exists && target.isHittable {
                let frame = target.frame
                // Only the actual first/last terminal edge is exempt from the active 52-point fade.
                let atFirst = id == samples[0]
                let atLast = id == samples[2]
                let leading: CGFloat = (rtl ? atLast : atFirst) ? 19 : 52
                let trailing: CGFloat = (rtl ? atFirst : atLast) ? 19 : 52
                if frame.minX >= rail.frame.minX + leading && frame.maxX <= rail.frame.maxX - trailing { return target }
            }
            // Drag the sleeve area; do not accidentally tap preview or versions controls.
            let fromX: CGFloat = (forward != rtl) ? 0.86 : 0.14
            let toX: CGFloat = (forward != rtl) ? 0.14 : 0.86
            let y = min(0.4, 70 / max(1, rail.frame.height))
            rail.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: y))
                .press(forDuration: 0.05, thenDragTo: rail.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: y)))
        }
        capture("horizontal-unreachable-" + id)
        XCTFail("First/middle/last catalogue record must remain fully reachable: \(id)")
        return target
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
