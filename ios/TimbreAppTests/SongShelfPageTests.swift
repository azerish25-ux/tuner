import SwiftUI
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class SongShelfPageTests: XCTestCase {
    private enum Driver: String {
        case scrollViewReader = "ScrollViewReader.scrollTo"
        case bindingCommand = "scrollPosition binding + shelf selection (command, not observation)"
    }

    private struct Shelf: Identifiable { let id: String }
    private struct Song: Identifiable { let id: Int }

    private final class State: ObservableObject {
        let driver: Driver
        let oversized: Bool
        let synchronizeDiagnosticCapture: Bool
        init(driver: Driver, oversized: Bool = false, synchronizeDiagnosticCapture: Bool = true) {
            self.driver = driver
            self.oversized = oversized
            self.synchronizeDiagnosticCapture = synchronizeDiagnosticCapture
        }
        @Published var size = CGSize(width: 402, height: 874)
        @Published var position: SongShelfPageTarget<String>? {
            didSet { positionHistory.append(String(describing: position)) }
        }
        @Published var requestedShelf: SongShelfPageTarget<String>?
        @Published var requestedTerminalShelf: String?
        var positionHistory: [String] = []
        var shelfFrames: [String: CGRect] = [:]
        var terminalFrames: [String: CGRect] = [:]
    }

    private struct Fixture: View {
        @ObservedObject var state: State
        let direction: LayoutDirection
        private let shelves = (0..<8).map { Shelf(id: "shelf-\($0)") }
        private let songs = (0..<120).map { Song(id: $0) }

        var body: some View {
            ScrollViewReader { proxy in
                SongShelfPage(items: shelves, position: $state.position) {
                    // The preceding content reflows as the production header/hero do on rotation.
                    Color.green.frame(height: state.size.width > state.size.height ? 440 : 500)
                } shelf: { shelf in
                    shelfRow(shelf)
                } footer: {
                    Color.blue.frame(height: 200)
                }
                .onChange(of: state.requestedShelf) { _, value in
                    guard let value else { return }
                    if state.driver == .bindingCommand {
                        // Separate command-path control only. The original reader tests never take this branch.
                        state.position = value
                    } else {
                        proxy.scrollTo(value, anchor: .center)
                    }
                }
            }
            .environment(\.layoutDirection, direction)
            .environment(\.dynamicTypeSize, state.oversized ? .accessibility5 : .large)
            .frame(width: state.size.width, height: state.size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
        }

        private func shelfRow(_ shelf: Shelf) -> some View {
            VStack(spacing: 12) {
                Color.orange.frame(height: 40)
                ScrollViewReader { proxy in
                    SongShelfRail(items: songs,
                                  selection: state.driver == .bindingCommand && state.requestedTerminalShelf == shelf.id ? 119 : 59,
                                  itemWidth: 148, height: state.oversized ? 640 : 240, identity: shelf.id) { song in
                        Text("Song \(song.id)").frame(width: 148, height: state.oversized ? 480 : 80)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                                if song.id == 119 { state.terminalFrames[shelf.id] = frame }
                            }
                    }
                    .onChange(of: state.requestedTerminalShelf) { _, value in
                        guard state.driver == .scrollViewReader, value == shelf.id else { return }
                        proxy.scrollTo(119, anchor: .trailing)
                    }
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                state.shelfFrames[shelf.id] = frame
            }
        }
    }

    func testExternalProxyInitialGeometryInteroperability() async throws {
        try await verifyExternalProxyPlacement(direction: .leftToRight)
    }

    func testExternalProxyInitialGeometryInteroperabilityRightToLeft() async throws {
        try await verifyExternalProxyPlacement(direction: .rightToLeft)
    }

    /// Public selection inputs must place actual content and survive resizing. Gesture behavior remains
    /// independently exercised by the unchanged full-catalogue real-touch tests.
    func testBindingCommandPlacesShelfAndTerminalAndPreservesResizeGeometry() async throws {
        try await verify(direction: .leftToRight)
    }

    func testBindingCommandPlacesShelfAndTerminalAndPreservesResizeGeometryRightToLeft() async throws {
        try await verify(direction: .rightToLeft)
    }

    /// Deliberately oversized content: the complete card cannot fit landscape, but its entire
    /// primary sleeve must remain reachable. This is a command-path geometry control, not a touch test.
    func testOversizedShelfKeepsPrimarySleeveAcrossRepeatedResize() async throws {
        try await verify(direction: .leftToRight, oversized: true)
    }

    func testOversizedShelfKeepsPrimarySleeveAcrossRepeatedResizeRightToLeft() async throws {
        try await verify(direction: .rightToLeft, oversized: true)
    }

    /// A contained-child sizing control, not device rotation or automatic binding observation.
    /// Both viewports fit the actual window; all original full-size failures remain separate.
    func testContainedHostCommandResize() async throws {
        executionTimeAllowance = 120
        try await verifyContainedHost(direction: .leftToRight)
    }

    func testContainedHostCommandResizeRightToLeft() async throws {
        executionTimeAllowance = 120
        try await verifyContainedHost(direction: .rightToLeft)
    }

    // Pure policy regressions supplement, never replace, the unchanged native geometry/touch gates.
    private func resizeMeasurement(_ state: SongShelfPageResize<String>, height: CGFloat)
        -> SongShelfPageResize<String>.Measurement {
        .init(rowSize: CGSize(width: state.viewport.width - 2 * Metrics.gutter, height: height),
              viewport: state.viewport, generation: state.generation)
    }

    func testResizePolicyDoesNotNavigateOnAppearanceOrNonShelfRows() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        var state = SongShelfPageResize<String>()
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        XCTAssertNil(state.target)
        let positions: [SongShelfPageTarget<String>?] = [nil, .introduction, .request]
        for position in positions {
            state.resized(to: CGSize(width: 750, height: 338), position: position)
            XCTAssertNil(state.target)
            state.resized(to: CGSize(width: 402, height: 729), position: position)
            XCTAssertNil(state.target)
        }
    }

    func testResizePolicyKeepsTypedShelfAndConsumesBeforeCommandFeedback() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        var state = SongShelfPageResize<String>()
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        state.resized(to: CGSize(width: 750, height: 338), position: target)
        XCTAssertEqual(state.target, target)
        let measurement = resizeMeasurement(state, height: 292)
        XCTAssertEqual(state.consume(for: target, measurement: measurement), .center)
        XCTAssertNil(state.target)
        XCTAssertNil(state.consume(for: target, measurement: measurement))
        state.resized(to: state.viewport, position: target)
        XCTAssertNil(state.target, "Content/offset changes at the same size must not replay a command")
    }

    func testResizePolicyUsesActualContainerNotInsetExpandedVisibleHeight() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        var state = SongShelfPageResize<String>()
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        state.resized(to: CGSize(width: 750, height: 338), position: target)
        // Observed normal row 364.7 fits the 402pt visibleRect but not the clear 338pt container.
        XCTAssertEqual(state.consume(for: target, measurement: resizeMeasurement(state, height: 364.7)), .top)
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        XCTAssertEqual(state.consume(for: target, measurement: resizeMeasurement(state, height: 364.7)), .center)
    }

    func testResizePolicyRejectsStaleWidthViewportAndGenerationWithoutConsuming() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        var state = SongShelfPageResize<String>()
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        let old = resizeMeasurement(state, height: 852)
        state.resized(to: CGSize(width: 340, height: 791), position: target)
        let intermediate = resizeMeasurement(state, height: 852)
        state.resized(to: CGSize(width: 750, height: 338), position: target)
        XCTAssertNil(state.consume(for: target, measurement: old))
        XCTAssertNil(state.consume(for: target, measurement: intermediate))
        let staleWidth = SongShelfPageResize<String>.Measurement(rowSize: CGSize(width: 362, height: 776),
                                                               viewport: state.viewport, generation: state.generation)
        XCTAssertNil(state.consume(for: target, measurement: staleWidth))
        XCTAssertEqual(state.target, target)
        XCTAssertEqual(state.consume(for: target, measurement: resizeMeasurement(state, height: 776)), .top)
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        XCTAssertNil(state.consume(for: target, measurement: old), "Same size from an old generation is still stale")
        XCTAssertEqual(state.target, target)
    }

    func testResizePolicyRejectsWrongTargetAndInvalidRowGeometry() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        var state = SongShelfPageResize<String>()
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        state.resized(to: CGSize(width: 750, height: 338), position: target)
        XCTAssertNil(state.consume(for: .shelf("preceding"), measurement: resizeMeasurement(state, height: 292)))
        for size in [CGSize.zero, CGSize(width: 710, height: CGFloat.infinity),
                     CGSize(width: CGFloat.nan, height: 292), CGSize(width: 710, height: -1)] {
            let measurement = SongShelfPageResize<String>.Measurement(rowSize: size,
                                                                     viewport: state.viewport, generation: state.generation)
            XCTAssertNil(state.consume(for: target, measurement: measurement))
        }
        XCTAssertEqual(state.target, target)
    }

    func testResizePolicyUserInteractionCancelsAndCannotRearmWhileActive() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        var state = SongShelfPageResize<String>()
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        state.resized(to: CGSize(width: 750, height: 338), position: target)
        state.userScrollChanged(true)
        XCTAssertNil(state.target)
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        XCTAssertNil(state.target)
        state.userScrollChanged(false)
        XCTAssertNil(state.target, "Ending a gesture is not another size change")
        state.resized(to: CGSize(width: 750, height: 338), position: target)
        XCTAssertEqual(state.target, target)
        state.cancel()
        XCTAssertNil(state.consume(for: target, measurement: resizeMeasurement(state, height: 292)))
    }

    func testResizePolicyDisappearanceDoesNotRetainAnActiveGesture() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        var state = SongShelfPageResize<String>()
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        state.userScrollChanged(true)
        state.disappeared()
        XCTAssertNil(state.target)
        state.resized(to: CGSize(width: 402, height: 729), position: target)
        XCTAssertNil(state.target, "Unchanged reappearance must not issue a command")
        state.resized(to: CGSize(width: 750, height: 338), position: target)
        XCTAssertEqual(state.target, target, "A later real resize must not inherit stale gesture state")
        XCTAssertEqual(state.consume(for: target, measurement: resizeMeasurement(state, height: 292)), .center)
    }

    func testResizePolicyTwoRotationCyclesPreserveCenterOrOversizedTopInEitherDirection() {
        let target = SongShelfPageTarget<String>.shelf("bass")
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let heights: [CGFloat] = [292, 776]
            for height in heights {
                var state = SongShelfPageResize<String>()
                state.resized(to: CGSize(width: 402, height: 729), position: target)
                for _ in 0..<2 {
                    for size in [CGSize(width: 750, height: 338), CGSize(width: 402, height: 729)] {
                        state.resized(to: size, position: target)
                        let expected: UnitPoint = height > size.height ? .top : .center
                        XCTAssertEqual(state.target, target, "\(direction)")
                        XCTAssertEqual(state.consume(for: target, measurement: resizeMeasurement(state, height: height)), expected)
                        XCTAssertNil(state.target)
                    }
                }
            }
        }
    }

    private func scrolls(_ view: UIView) -> [UIScrollView] {
        let current = (view as? UIScrollView).map { [$0] } ?? []
        return current + view.subviews.flatMap { scrolls($0) }
    }

    func testScrollTraversalIncludesNestedRailsAndTheirPage() {
        let root = UIView()
        let page = UIScrollView()
        let content = UIView()
        let rail = UIScrollView()
        root.addSubview(page)
        page.addSubview(content)
        content.addSubview(rail)
        let found = scrolls(root)
        XCTAssertEqual(found.count, 2)
        XCTAssertTrue(found.first === page)
        XCTAssertTrue(found.last === rail)
    }

    private func record(_ state: State, window: UIWindow, stage: String) {
        var lines = ["stage=\(stage) driver=\(state.driver.rawValue), not a touch gesture",
                     "position=\(String(describing: state.position)) history=\(state.positionHistory)",
                     "requestedSize=\(state.size) window=\(window.bounds) key=\(window.isKeyWindow)",
                     "captureWaitsForUpdates=\(state.synchronizeDiagnosticCapture); diagnostic pixels are not acceptance evidence"]
        for key in state.shelfFrames.keys.sorted() {
            lines.append("shelf=\(key) frame=\(String(describing: state.shelfFrames[key])) "
                + "terminal=\(String(describing: state.terminalFrames[key]))")
        }
        func describe(_ view: UIView, path: String) {
            var line = "\(path) \(type(of: view)) frame=\(view.convert(view.bounds, to: window)) "
                + "bounds=\(view.bounds) attached=\(view.window === window) hidden=\(view.isHidden) alpha=\(view.alpha)"
            if let scroll = view as? UIScrollView {
                line += " content=\(scroll.contentSize) offset=\(scroll.contentOffset) inset=\(scroll.adjustedContentInset) "
                    + "dragging=\(scroll.isDragging) decelerating=\(scroll.isDecelerating)"
            }
            lines.append(line)
            for (index, child) in view.subviews.enumerated() { describe(child, path: path + ".\(index)") }
        }
        if let root = window.rootViewController?.view { describe(root, path: "root") }
        let text = lines.joined(separator: "\n")
        print("SONG-PAGE: " + text)
        let diagnostic = XCTAttachment(string: text)
        diagnostic.name = "song-page-observed-" + stage
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        guard window.bounds.width > 0, window.bounds.height > 0 else { return }
        checkpoint("renderer-begin " + stage)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            checkpoint("drawHierarchy-begin " + stage)
            let complete = window.drawHierarchy(in: window.bounds, afterScreenUpdates: state.synchronizeDiagnosticCapture)
            checkpoint("drawHierarchy-end complete=\(complete) " + stage)
        }
        checkpoint("renderer-end " + stage)
        let rendered = XCTAttachment(image: image)
        rendered.name = "song-page-observed-" + stage
            + (state.synchronizeDiagnosticCapture ? "" : "-current-state-unsynchronized")
        rendered.lifetime = .keepAlways
        checkpoint("image-attachment-begin " + stage)
        add(rendered)
        checkpoint("record-end " + stage)
    }

    private func checkpoint(_ message: String) {
        // Write directly so a blocked main run loop cannot leave the latest boundary in a print buffer.
        let line = "SONG-PAGE-BOUNDARY uptime=\(ProcessInfo.processInfo.systemUptime) \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

    /// External proxy interoperability is initial geometry only. Readback is recorded passively;
    /// resize ownership is covered through the supported public selection and real-user paths.
    private func verifyExternalProxyPlacement(direction: LayoutDirection) async throws {
        executionTimeAllowance = 120
        let state = State(driver: .scrollViewReader)
        let host = UIHostingController(rootView: Fixture(state: state, direction: direction))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
        host.view.layoutIfNeeded()
        func page() -> UIScrollView? {
            scrolls(host.view).first { $0.window === window && $0.contentSize.height > 2000 }
        }
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            page() != nil && state.shelfFrames["shelf-1"] != nil
        }, object: nil)
        await fulfillment(of: [loaded], timeout: 3)
        let initialPage = try XCTUnwrap(page())
        let initialOffset = initialPage.contentOffset
        let secondRow = try XCTUnwrap(state.shelfFrames["shelf-1"])
        let initialViewport = initialPage.convert(initialPage.bounds, to: window)
        // The fixed-height ordered fixture puts shelf-3 after this already offscreen lower bound.
        XCTAssertGreaterThan(secondRow.maxY, initialViewport.maxY)
        let target = "shelf-3"
        if let frame = state.shelfFrames[target] { XCTAssertFalse(initialViewport.contains(frame)) }
        record(state, window: window, stage: "external-before-vertical-\(direction)")
        let shelfPlaced = NSPredicate { _, _ in
            guard let current = page(), let frame = state.shelfFrames[target] else { return false }
            return current.contentOffset != initialOffset && current.convert(current.bounds, to: window).contains(frame)
        }
        XCTAssertFalse(shelfPlaced.evaluate(with: nil), "Withholding the vertical command must not satisfy its geometry")
        state.requestedShelf = .shelf(target)
        let placed = XCTNSPredicateExpectation(predicate: shelfPlaced, object: nil)
        await fulfillment(of: [placed], timeout: 3)
        let shelf = try XCTUnwrap(state.shelfFrames[target])
        let horizontal = try XCTUnwrap(scrolls(host.view).first { scroll in
            let frame = scroll.convert(scroll.bounds, to: window)
            return scroll.window === window && scroll.contentSize.width > 1000
                && frame.minY >= shelf.minY - 1 && frame.maxY <= shelf.maxY + 1
        })
        let before = horizontal.contentOffset
        let distanceFromEnd = direction == .leftToRight
            ? horizontal.contentSize.width + horizontal.adjustedContentInset.right - horizontal.bounds.width - before.x
            : before.x + horizontal.adjustedContentInset.left
        XCTAssertGreaterThan(distanceFromEnd, horizontal.bounds.width,
                             "The terminal record must start beyond the current horizontal viewport")
        if let frame = state.terminalFrames[target] {
            XCTAssertFalse(horizontal.convert(horizontal.bounds, to: window).contains(frame))
        }
        record(state, window: window, stage: "external-before-horizontal-\(direction)")
        let terminalPlaced = NSPredicate { _, _ in
            guard let current = page(), let frame = state.terminalFrames[target] else { return false }
            let rails = self.scrolls(host.view).filter { $0.window === window && $0.contentSize.width > 1000 }
            return current.convert(current.bounds, to: window).contains(frame)
                && rails.contains { $0.contentOffset != before && $0.convert($0.bounds, to: window).contains(frame) }
        }
        XCTAssertFalse(terminalPlaced.evaluate(with: nil), "Withholding the horizontal command must not satisfy its geometry")
        state.requestedTerminalShelf = target
        let terminal = XCTNSPredicateExpectation(predicate: terminalPlaced, object: nil)
        await fulfillment(of: [terminal], timeout: 3)
        record(state, window: window, stage: "external-after-commands-\(direction)")
        // No assignment or expectation of state.position: its actual value/history stays in the attachments.
    }

    private func verify(direction: LayoutDirection, oversized: Bool = false) async throws {
        let state = State(driver: .bindingCommand, oversized: oversized)
        let host = UIHostingController(rootView: Fixture(state: state, direction: direction))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        defer { record(state, window: window, stage: "final-\(direction)") }
        host.view.layoutIfNeeded()
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.scrolls(host.view).contains { $0.contentSize.height > 2000 && $0.bounds.height > 800 }
        }, object: nil)
        await fulfillment(of: [loaded], timeout: 3)
        record(state, window: window, stage: "loaded-\(direction)")
        let vertical = try XCTUnwrap(scrolls(host.view).first { $0.contentSize.height > 2000 })
        let target = "shelf-3"
        // This verifier drives the public setter input, not an inferred external-proxy readback.
        XCTAssertTrue(vertical.window === window)
        state.requestedShelf = .shelf(target)
        let tracked = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            state.position == .shelf(target) && state.shelfFrames[target] != nil
        }, object: nil)
        await fulfillment(of: [tracked], timeout: 3)
        record(state, window: window, stage: "programmatic-tracking-\(direction)")
        XCTAssertEqual(state.position, .shelf(target), "The explicit command must remain bound while its target is realized")
        let shelf = try XCTUnwrap(state.shelfFrames[target])
        let horizontal = try XCTUnwrap(scrolls(host.view).first { scroll in
            let frame = scroll.convert(scroll.bounds, to: window)
            return scroll.contentSize.width > 1000 && frame.minY >= shelf.minY - 1 && frame.maxY <= shelf.maxY + 1
        })
        XCTAssertTrue(horizontal.window === window)
        state.requestedTerminalShelf = target
        await assertCurrentGeometry(state, target: target, window: window, stage: "browsed")
        for cycle in 0..<2 {
            for size in [CGSize(width: 874, height: 402), CGSize(width: 402, height: 874)] {
                state.size = size
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                await assertCurrentGeometry(state, target: target, window: window, stage: "resize-\(cycle)-\(size)")
            }
        }
    }

    private func assertCurrentGeometry(_ state: State, target: String, window: UIWindow, stage: String) async {
        if state.oversized {
            await assertPrimarySleeve(state, target: target, window: window, stage: stage)
        } else {
            await assertTerminal(state, target: target, window: window, stage: stage)
        }
    }

    private func assertPrimarySleeve(_ state: State, target: String, window: UIWindow, stage: String) async {
        func currentFrames() -> (page: CGRect, rail: CGRect, card: CGRect)? {
            guard let root = window.rootViewController?.view, let shelf = state.shelfFrames[target],
                  let card = state.terminalFrames[target] else { return nil }
            let attached = scrolls(root).filter { $0.window === window }
            guard let page = attached.first(where: { $0.contentSize.height > 2000 }),
                  let rail = attached.first(where: { scroll in
                      let frame = scroll.convert(scroll.bounds, to: window)
                      return scroll.contentSize.width > 1000 && frame.minY >= shelf.minY - 1
                          && frame.maxY <= shelf.maxY + 1
                  }) else { return nil }
            return (page.convert(page.bounds, to: window), rail.convert(rail.bounds, to: window), card)
        }
        func sleeve(_ card: CGRect) -> CGRect {
            CGRect(x: card.minX, y: card.minY, width: card.width, height: min(card.width, card.height))
        }
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard state.position == .shelf(target), let frames = currentFrames() else { return false }
            return abs(frames.page.width - state.size.width) <= 1 && abs(frames.page.height - state.size.height) <= 1
                && frames.page.insetBy(dx: -1, dy: -1).contains(sleeve(frames.card))
                && frames.rail.insetBy(dx: -1, dy: -1).contains(frames.card)
        }, object: nil)
        await fulfillment(of: [visible], timeout: 3)
        record(state, window: window, stage: "oversized-" + stage)
        guard let frames = currentFrames() else { XCTFail("Current attached page/rail required: " + stage); return }
        XCTAssertEqual(state.position, .shelf(target))
        XCTAssertEqual(frames.page.width, state.size.width, accuracy: 1)
        XCTAssertEqual(frames.page.height, state.size.height, accuracy: 1)
        XCTAssertTrue(frames.page.insetBy(dx: -1, dy: -1).contains(sleeve(frames.card)),
                      "The full primary sleeve must remain inside the page: " + stage)
        XCTAssertTrue(frames.rail.insetBy(dx: -1, dy: -1).contains(frames.card),
                      "Horizontal terminal identity and full rail containment must survive: " + stage)
        if state.size.width > state.size.height {
            XCTAssertGreaterThan(frames.card.height, frames.page.height,
                                 "The landscape control must genuinely exceed the viewport")
        }
    }

    private func verifyContainedHost(direction: LayoutDirection) async throws {
        let tall = CGSize(width: 300, height: 600)
        let compact = CGSize(width: 402, height: 340)
        // The exploratory capture records current rendering without waiting for a display commit.
        // Geometry assertions still wait for measured native bounds; screenshots never accept the result.
        let state = State(driver: .bindingCommand, synchronizeDiagnosticCapture: false)
        state.size = tall
        let host = UIHostingController(rootView: Fixture(state: state, direction: direction))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let container = UIViewController()
        window.rootViewController = container
        container.addChild(host)
        container.view.addSubview(host.view)
        host.didMove(toParent: container)
        host.view.frame = CGRect(origin: .zero, size: tall)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        defer { record(state, window: window, stage: "contained-final-\(direction)") }
        guard window.bounds.width >= compact.width, window.bounds.height >= tall.height else {
            record(state, window: window, stage: "contained-window-too-small-\(direction)")
            XCTFail("Both diagnostic viewports must fit the real window without clipping")
            return
        }
        container.view.layoutIfNeeded()
        host.view.layoutIfNeeded()
        await assertContainedHost(state, host: host, window: window, stage: "contained-loaded-\(direction)")
        let target = "shelf-3"
        state.requestedShelf = .shelf(target)
        let tracked = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            state.position == .shelf(target) && state.shelfFrames[target] != nil
        }, object: nil)
        await fulfillment(of: [tracked], timeout: 3)
        record(state, window: window, stage: "contained-command-\(direction)")
        XCTAssertEqual(state.position, .shelf(target), "Explicit command only, not automatic writeback")
        state.requestedTerminalShelf = target
        await assertTerminal(state, target: target, window: window, stage: "contained-browsed-\(direction)")
        for cycle in 0..<2 {
            for size in [compact, tall] {
                // Resize the actual child host and its SwiftUI content together; never replay a scroll command.
                let stage = "contained-\(direction)-\(cycle)-\(size)"
                checkpoint("state-size-begin " + stage)
                state.size = size
                checkpoint("host-frame-begin " + stage)
                host.view.frame = CGRect(origin: .zero, size: size)
                checkpoint("container-layout-begin " + stage)
                container.view.setNeedsLayout()
                container.view.layoutIfNeeded()
                checkpoint("host-layout-begin " + stage)
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                checkpoint("containment-await-begin " + stage)
                await assertContainedHost(state, host: host, window: window, stage: stage)
                checkpoint("terminal-await-begin " + stage)
                await assertTerminal(state, target: target, window: window, stage: stage)
                checkpoint("resize-complete " + stage)
            }
        }
    }

    private func assertContainedHost(_ state: State, host: UIViewController, window: UIWindow, stage: String) async {
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let page = self.scrolls(host.view).first(where: { $0.contentSize.height > 2000 }) else { return false }
            return page.window === window && abs(page.bounds.width - state.size.width) <= 1
                && abs(page.bounds.height - state.size.height) <= 1
        }, object: nil)
        await fulfillment(of: [settled], timeout: 3)
        record(state, window: window, stage: stage)
        guard let root = window.rootViewController?.view,
              let page = scrolls(host.view).first(where: { $0.contentSize.height > 2000 }) else {
            XCTFail("An attached root, child host, and page are required: " + stage)
            return
        }
        let rootFrame = root.convert(root.bounds, to: window)
        let hostFrame = host.view.convert(host.view.bounds, to: window)
        let pageFrame = page.convert(page.bounds, to: window)
        let diagnostic = XCTAttachment(string: "stage=\(stage) contained child sizing, not device rotation "
            + "window=\(window.bounds) root=\(rootFrame) host=\(hostFrame) page=\(pageFrame) requested=\(state.size)")
        diagnostic.name = "song-page-contained-host-" + stage
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTAssertTrue(root.window === window && host.view.window === window && page.window === window)
        XCTAssertTrue(window.bounds.insetBy(dx: -1, dy: -1).contains(rootFrame))
        XCTAssertTrue(rootFrame.insetBy(dx: -1, dy: -1).contains(hostFrame))
        XCTAssertTrue(hostFrame.insetBy(dx: -1, dy: -1).contains(pageFrame))
        XCTAssertEqual(hostFrame.width, state.size.width, accuracy: 1)
        XCTAssertEqual(hostFrame.height, state.size.height, accuracy: 1)
        XCTAssertEqual(pageFrame.width, state.size.width, accuracy: 1)
        XCTAssertEqual(pageFrame.height, state.size.height, accuracy: 1)
    }

    private func assertTerminal(_ state: State, target: String, window: UIWindow, stage: String) async {
        // SwiftUI may replace UIKit backing views during reflow. Inspect the current attached
        // hierarchy, never stale frame values from a scroll view removed from the live window.
        func currentScrolls() -> (vertical: UIScrollView, horizontal: UIScrollView)? {
            guard let root = window.rootViewController?.view, let shelf = state.shelfFrames[target] else { return nil }
            let attached = scrolls(root).filter { $0.window === window }
            guard let vertical = attached.first(where: { $0.contentSize.height > 2000 }),
                  let horizontal = attached.first(where: { scroll in
                      let frame = scroll.convert(scroll.bounds, to: window)
                      return scroll.contentSize.width > 1000 && frame.minY >= shelf.minY - 1 && frame.maxY <= shelf.maxY + 1
                  }) else { return nil }
            return (vertical, horizontal)
        }
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard state.position == .shelf(target), let frame = state.terminalFrames[target],
                  let current = currentScrolls() else { return false }
            let page = current.vertical.convert(current.vertical.bounds, to: window)
            let rail = current.horizontal.convert(current.horizontal.bounds, to: window)
            return abs(page.width - state.size.width) <= 1 && abs(page.height - state.size.height) <= 1
                && page.insetBy(dx: -1, dy: -1).contains(frame) && rail.insetBy(dx: -1, dy: -1).contains(frame)
        }, object: nil)
        await fulfillment(of: [visible], timeout: 3)
        record(state, window: window, stage: stage)
        guard let current = currentScrolls() else {
            XCTFail("The browsed shelf must have current scroll views attached to its window: \(stage)")
            return
        }
        let page = current.vertical.convert(current.vertical.bounds, to: window)
        let rail = current.horizontal.convert(current.horizontal.bounds, to: window)
        let frame = state.terminalFrames[target]
        let diagnostic = XCTAttachment(string: "stage=\(stage) position=\(String(describing: state.position)) "
            + "page=\(page) rail=\(rail) terminal=\(String(describing: frame)) "
            + "verticalOffset=\(current.vertical.contentOffset) horizontalOffset=\(current.horizontal.contentOffset)")
        diagnostic.name = "song-page-identity-" + stage
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTAssertEqual(state.position, .shelf(target))
        XCTAssertEqual(page.width, state.size.width, accuracy: 1)
        XCTAssertEqual(page.height, state.size.height, accuracy: 1)
        guard let frame else { XCTFail("The browsed terminal song must remain realized: \(stage)"); return }
        XCTAssertTrue(page.insetBy(dx: -1, dy: -1).contains(frame), "The vertical page must preserve the browsed song: \(stage)")
        XCTAssertTrue(rail.insetBy(dx: -1, dy: -1).contains(frame), "The horizontal rail must preserve its independent identity: \(stage)")
    }
}
