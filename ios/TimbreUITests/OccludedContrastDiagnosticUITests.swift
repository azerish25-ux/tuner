import StoreKitTest
import XCTest

/// Collects revealed native pixels only. It never replaces a strict audit, supplies a contrast proof,
/// or dismisses an SDK issue. The existing strict class and every original failure remain separate.
final class OccludedContrastDiagnosticUITests: XCTestCase {
    private struct Target {
        let key: String
        let parent: String
        let identifier: String
        let label: String
        let parentLabel: String?
        init(_ key: String, _ parent: String, _ identifier: String, _ label: String,
              parentLabel: String? = nil) {
            self.key = key; self.parent = parent; self.identifier = identifier; self.label = label; self.parentLabel = parentLabel
        }
    }
    private struct Group {
        let key: String
        let tab: String
        let keys: [String]
        let rail: String?
    }
    private struct State {
        let pageBand: CGRect
        let clearBand: CGRect
        let rail: CGRect?
        let frames: [CGRect]
        let identities: [String]
        var union: CGRect { frames.reduce(CGRect.null) { $0.union($1) } }
    }
    private struct Hierarchy: Encodable {
        let identifier: String
        let label: String
        let value: String
        let type: UInt
        let frame: [Double]
        let children: [Hierarchy]
        init(_ node: any XCUIElementSnapshot) {
            identifier = node.identifier; label = node.label; value = String(describing: node.value ?? "")
            type = node.elementType.rawValue
            frame = [node.frame.minX, node.frame.minY, node.frame.width, node.frame.height].map(Double.init)
            children = node.children.map { Hierarchy($0) }
        }
    }
    private enum Blocked: Error { case evidence(String) }
    private static let targets: [Target] = [
        .init("finding-03", "learn.lesson.gtr-1-1", "", "Start",
              parentLabel: "Meet your guitar"),
        .init("finding-29", "practice.ear", "", "Ear training"),
        .init("finding-30", "practice.ear", "", "Hear two notes. Name the gap."),
        .init("finding-10", "songs.filter.violin.standard.4", "songs.filter.violin.standard.4.title", "Violin",
              parentLabel: "Violin"),
        .init("finding-12", "songs.known.song-ode-to-joy", "songs.tile.known.song-ode-to-joy.cover.title.1", "Joy",
              parentLabel: "Ode to Joy, Songs"),
        .init("finding-14", "songs.known.song-ode-to-joy", "songs.tile.known.song-ode-to-joy.chords.chord.C", "C",
              parentLabel: "Ode to Joy, Songs"),
        .init("finding-15", "songs.known.song-ode-to-joy", "songs.tile.known.song-ode-to-joy.chords.chord.G", "G",
              parentLabel: "Ode to Joy, Songs"),
        .init("finding-16", "songs.known.song-ode-to-joy", "songs.tile.known.song-ode-to-joy.duration", "2:07",
              parentLabel: "Ode to Joy, Songs"),
        .init("finding-17", "songs.known.song-ode-to-joy", "songs.tile.known.song-ode-to-joy.xp", "+35 XP",
              parentLabel: "Ode to Joy, Songs"),
        .init("finding-18", "songs.known.gtr-6-5", "songs.tile.known.gtr-6-5.chords.chord.G", "G",
              parentLabel: "Amazing Grace, Guitar"),
        .init("finding-19", "songs.known.gtr-6-5", "songs.tile.known.gtr-6-5.chords.chord.C", "C",
              parentLabel: "Amazing Grace, Guitar"),
        .init("finding-20", "songs.known.gtr-6-5", "songs.tile.known.gtr-6-5.chords.chord.D", "D",
              parentLabel: "Amazing Grace, Guitar"),
        .init("finding-21", "songs.known.song-silent-night", "songs.tile.known.song-silent-night.cover.title.0", "Silent",
              parentLabel: "Silent Night, Songs"),
        .init("finding-22", "songs.known.song-silent-night", "songs.tile.known.song-silent-night.cover.title.1", "Night",
              parentLabel: "Silent Night, Songs"),
        .init("finding-23", "songs.known.song-silent-night", "songs.tile.known.song-silent-night.cover.catalogue", "28",
              parentLabel: "Silent Night, Songs"),
        .init("finding-24", "songs.known.song-silent-night", "songs.tile.known.song-silent-night.chords.chord.A7", "A7",
              parentLabel: "Silent Night, Songs"),
        .init("finding-25", "songs.versions.song-ode-to-joy", "songs.tile.known.song-ode-to-joy.versions.more", "+5",
              parentLabel: "Versions"),
        .init("finding-26", "songs.versions.gtr-6-5", "songs.tile.known.gtr-6-5.versions.more", "+5",
              parentLabel: "Versions"),
    ]
    private var app: XCUIApplication!
    private var storeKit: SKTestSession!
    private var began: TimeInterval = 0
    private var serial = 0

    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["TIMBRE_REVEAL_CONTRAST"] == "1" else {
            throw XCTSkip("Opt-in evidence collection only; strict accessibility tests remain required")
        }
        continueAfterFailure = true
        executionTimeAllowance = 120
        storeKit = try SKTestSession(configurationFileNamed: "Timbre")
        storeKit.resetToDefaultState(); storeKit.clearTransactions(); storeKit.disableDialogs = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["TIMBRE_DEMO_DATA"] = "1"
        app.launchEnvironment["TIMBRE_STAGE_REST"] = "1"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
    }
    override func tearDownWithError() throws { app?.terminate() }

    func testRevealLearnStart() throws {
        try collect(.init(key: "learn-start", tab: "Learn", keys: ["finding-03"], rail: nil))
    }
    func testRevealPracticeEar() throws {
        try collect(.init(key: "practice-ear", tab: "Practice", keys: ["finding-29", "finding-30"], rail: nil))
    }
    func testRevealSongsFilter() throws {
        try collect(.init(key: "songs-filter", tab: "Songs", keys: ["finding-10"], rail: ""))
    }
    func testRevealSongsFirstPair() throws {
        try collect(.init(key: "songs-first-pair", tab: "Songs", keys: ["finding-12", "finding-14", "finding-15",
            "finding-16", "finding-17", "finding-18", "finding-19", "finding-20", "finding-25", "finding-26"], rail: "songs.rail.known"))
    }
    func testRevealSongsThirdCard() throws {
        try collect(.init(key: "songs-third", tab: "Songs", keys: ["finding-21", "finding-22", "finding-23", "finding-24"],
                          rail: "songs.rail.known"))
    }

    private func collect(_ group: Group) throws {
        began = ProcessInfo.processInfo.systemUptime
        let source = ProcessInfo.processInfo.environment["TIMBRE_DIAGNOSTIC_SOURCE_SHA"] ?? ""
        var lines = ["diagnosticOnly=true originalFailuresResolved=0 pixelProof=false",
                     "group=\(group.key) required=\(group.keys) source=\(source)", "locale=en_US requestedContentSize=large"]
        defer {
            let report = XCTAttachment(string: lines.joined(separator: "\n"))
            report.name = "contrast-reveal-" + group.key + "-report"; report.lifetime = .keepAlways; add(report)
            for line in lines { print("AX-REVEAL: " + line) }
        }
        do {
            try require(source.count == 40 && source.allSatisfy { $0.isHexDigit }, "Missing exact built checkout SHA")
            let buttons = app.tabBars.buttons.matching(NSPredicate(format: "label == %@", group.tab))
            try require(buttons.firstMatch.waitForExistence(timeout: 25) && buttons.count == 1, "Tab identity missing/ambiguous")
            let tab = buttons.firstMatch
            for _ in 0..<3 where !tab.isSelected {
                try require(tab.isHittable, "Tab is not reachable")
                tab.tap()
                let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: tab)
                _ = XCTWaiter.wait(for: [selected], timeout: 3)
            }
            try require(tab.isSelected, "Requested tab did not become selected")
            try capture(group.key + "-original")
            let targets = Self.targets.filter { group.keys.contains($0.key) }
            try require(targets.count == group.keys.count, "Incomplete target map")
            var state = try stable(group, targets: targets)
            let originalIdentities = state.identities
            for horizontal in [false, true] {
                let maximum = horizontal ? 6 : 3
                for attempt in 0...maximum {
                    try budget()
                    let frame = state.union
                    let band = horizontal ? state.clearBand : state.pageBand
                    let contained = horizontal ? frame.minX >= band.minX && frame.maxX <= band.maxX
                        : frame.minY >= band.minY && frame.maxY <= band.maxY
                    if contained { break }
                    try require(attempt < maximum, "Bounded reveal gestures exhausted")
                    try require(horizontal ? state.rail != nil : true, "No bound horizontal rail")
                    let extent = horizontal ? frame.width : frame.height
                    let available = horizontal ? band.width : band.height
                    try require(valid(band) && extent <= available, "Complete grouped controls cannot fit clear band")
                    let center = horizontal ? frame.midX : frame.midY
                    let desired = horizontal ? band.midX : band.midY
                    let delta = min(available * 0.45, max(-available * 0.45, desired - center))
                    try require(abs(delta) >= 2, "Required correction is too small for a deliberate drag")
                    let gesture = horizontal ? band : state.pageBand
                    let point = horizontal ? CGPoint(x: gesture.midX, y: gesture.minY + min(20, gesture.height / 4))
                        : CGPoint(x: gesture.minX + 4, y: gesture.midY)
                    let start = CGPoint(x: point.x - (horizontal ? delta / 2 : 0), y: point.y - (horizontal ? 0 : delta / 2))
                    let end = CGPoint(x: point.x + (horizontal ? delta / 2 : 0), y: point.y + (horizontal ? 0 : delta / 2))
                    try require(gesture.contains(start) && gesture.contains(end), "Gesture leaves measured clear band")
                    let origin = app.coordinate(withNormalizedOffset: .zero)
                    origin.withOffset(CGVector(dx: start.x - app.frame.minX, dy: start.y - app.frame.minY))
                        .press(forDuration: 0.1,
                               thenDragTo: origin.withOffset(CGVector(dx: end.x - app.frame.minX, dy: end.y - app.frame.minY)),
                               withVelocity: .slow, thenHoldForDuration: 0.3)
                    try capture("\(group.key)-gesture-\(horizontal ? "horizontal" : "vertical")-\(attempt)")
                    let next = try stable(group, targets: targets)
                    let moved = horizontal ? next.union.midX - frame.midX : next.union.midY - frame.midY
                    try require(next.identities == originalIdentities, "Target identity/content changed during reveal")
                    try require(moved * delta > 0 && abs(moved) >= 1, "Gesture stalled, hit an end, or moved wrong way")
                    state = next
                }
            }
            try require(valid(state.clearBand) && state.frames.allSatisfy { state.clearBand.contains($0) }, "Incomplete reveal")
            // Hittability is only a secondary check after full target/control containment.
            for parent in Set(targets.map(\.parent)) {
                let matches = app.buttons.matching(identifier: parent)
                try require(matches.count == 1 && matches.firstMatch.isHittable, "Bound parent not reachable: " + parent)
            }
            try capture(group.key + "-revealed-before")
            lines.append("geometricallyRevealed=\(group.keys) clearBand=\(state.clearBand) frames=\(state.frames)")
            try budget()
            var callbacks = 0
            var auditReturned = false
            do {
                try app.performAccessibilityAudit(for: .contrast) { issue in
                    callbacks += 1
                    let node = try? issue.element?.snapshot()
                    self.attachScreenshot("\(group.key)-callback-\(callbacks)")
                    let detail = "callback=\(callbacks) id=\(node?.identifier ?? "") label=\(node?.label ?? "") "
                        + "type=\(String(describing: node?.elementType.rawValue)) frame=\(String(describing: node?.frame)) "
                        + issue.detailedDescription
                    lines.append(detail)
                    print("AX-REVEAL: " + detail)
                    return false // Never ignore anonymous, duplicate, unrelated or target contrast failures.
                }
                auditReturned = true
                lines.append("contrastRequestReturned=true callbacks=\(callbacks)")
            } catch {
                lines.append("contrastRequestReturned=false error=\(error)")
                XCTFail("Isolated reveal audit did not complete: \(error)")
            }
            try capture(group.key + "-revealed-after")
            let after = try stable(group, targets: targets)
            try require(same(state, after), "Audit changed target identity/geometry; after image is not accepted as same-state")
            try budget()
            lines.append("revealedFramesCaptured=true contrastRequestReturned=\(auditReturned) callbacks=\(callbacks)")
            lines.append("No original failure resolved; native pixels still require independent visual/contrast review")
        } catch {
            lines.append("UNRESOLVED required=\(group.keys) error=\(error)")
            try? capture(group.key + "-blocked")
            XCTFail("Reveal diagnostic incomplete; original failures retained: \(group.key): \(error)")
        }
    }

    private func require(_ condition: Bool, _ reason: String) throws {
        if !condition { throw Blocked.evidence(reason) }
    }
    private func budget() throws {
        try require(ProcessInfo.processInfo.systemUptime - began <= 90, "90-second cooperative group budget exceeded")
    }
    private func valid(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && !frame.isEmpty
            && [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy(\.isFinite)
    }
    private func nodes(_ root: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        root.children.flatMap { [$0] + nodes($0) }
    }
    private func unique(_ nodes: [any XCUIElementSnapshot], _ reason: String) throws -> any XCUIElementSnapshot {
        try require(nodes.count == 1, reason + ": count=\(nodes.count)")
        return nodes[0]
    }
    private func read(_ group: Group, targets: [Target]) throws -> State {
        try budget()
        let all = nodes(try app.snapshot())
        let bar = try unique(all.filter { $0.elementType == .tabBar }, "Tab bar")
        let selected = try unique(nodes(bar).filter { $0.elementType == .button && $0.isSelected }, "Selected tab")
        try require(selected.label == group.tab, "Tab changed while collecting")
        let overlay = try unique(all.filter { $0.identifier == "AdditionalDimmingOverlay" && $0.elementType == .image }, "Dimming overlay")
        let scrolls = all.filter { $0.elementType == .scrollView }
        let page: any XCUIElementSnapshot
        if group.tab == "Songs" {
            page = try unique(scrolls.filter { $0.identifier == "songs.page" }, "Named outer Songs scroll")
            let filter = try unique(nodes(page).filter { $0.identifier == "songs.filter.all" && $0.elementType == .button }, "All filter")
            try require(filter.isSelected, "Original All filter changed")
        } else {
            page = try unique(scrolls.filter { nodes($0).contains { $0.elementType == .button && $0.identifier == targets[0].parent } },
                              "Owning vertical scroll")
        }
        let viewport = app.frame
        try require(valid(viewport) && valid(bar.frame) && valid(overlay.frame) && valid(page.frame), "Invalid viewport geometry")
        try require(bar.frame.minY > viewport.midY && overlay.frame.minY > viewport.midY
                    && overlay.frame.maxY >= bar.frame.minY, "Unsupported bottom obstruction geometry")
        let navigationBottom = all.filter { $0.elementType == .navigationBar }.map { $0.frame.maxY }.max() ?? page.frame.minY
        // Conservative top clearance also avoids the app's small scrolling top shade.
        let top = max(viewport.minY + viewport.height * 0.16, max(navigationBottom, page.frame.minY))
        let bottom = min(min(page.frame.maxY, viewport.maxY), min(bar.frame.minY, overlay.frame.minY))
        let pageBand = CGRect(x: max(viewport.minX, page.frame.minX) + 8, y: top + 8,
                              width: min(viewport.maxX, page.frame.maxX) - max(viewport.minX, page.frame.minX) - 16,
                              height: bottom - top - 16)
        try require(valid(pageBand), "No clear vertical page band")
        var rail: (any XCUIElementSnapshot)?
        if let id = group.rail {
            rail = try unique(nodes(page).filter { node in
                node.elementType == .scrollView && (id.isEmpty
                    ? nodes(node).contains { $0.elementType == .button && $0.identifier == targets[0].parent }
                    : node.identifier == id)
            }, "Owning horizontal rail")
        }
        var clear = pageBand
        if let rail {
            let content = try unique(rail.children.filter { $0.elementType == .other && !$0.children.isEmpty }, "Rail content")
            try require(valid(rail.frame) && valid(content.frame) && content.frame.width >= rail.frame.width
                        && abs(content.frame.minY - rail.frame.minY) <= 1 && abs(content.frame.height - rail.frame.height) <= 1,
                        "Unsupported rail content/clip topology")
            // Source EdgeFadeMask.width(bleed: 20) is 52. This is placement clearance, not measured pixel contrast.
            let left: CGFloat = content.frame.minX < rail.frame.minX - 1 ? 52 : 0
            let right: CGFloat = content.frame.maxX > rail.frame.maxX + 1 ? 52 : 0
            clear = pageBand.intersection(CGRect(x: rail.frame.minX + left + 8, y: rail.frame.minY,
                width: rail.frame.width - left - right - 16, height: rail.frame.height))
        }
        var frames: [CGRect] = [], identities: [String] = []
        for target in targets {
            let scope = nodes(rail ?? page)
            let parent = try unique(scope.filter { $0.elementType == .button && $0.identifier == target.parent }, target.key + " parent")
            if let label = target.parentLabel { try require(parent.label == label, target.key + " parent label changed") }
            if target.parent == "learn.lesson.gtr-1-1" {
                try require(parent.value as? String == "Next lesson", "First lesson state changed")
            }
            let leaf = try unique(nodes(parent).filter {
                $0.elementType == .staticText && $0.identifier == target.identifier && $0.label == target.label
            }, target.key + " exact leaf")
            try require(valid(parent.frame) && valid(leaf.frame), target.key + " invalid frames")
            frames += [parent.frame, leaf.frame]
            identities.append("\(target.key)|\(parent.identifier)|\(parent.label)|\(String(describing: parent.value))|\(leaf.identifier)|\(leaf.label)")
        }
        return State(pageBand: pageBand, clearBand: clear, rail: rail?.frame, frames: frames, identities: identities)
    }
    private func same(_ lhs: State, _ rhs: State) -> Bool {
        func equal(_ a: CGRect, _ b: CGRect) -> Bool {
            if a.isNull && b.isNull { return true }
            return valid(a) && valid(b) && abs(a.minX - b.minX) <= 0.5 && abs(a.minY - b.minY) <= 0.5
                && abs(a.width - b.width) <= 0.5 && abs(a.height - b.height) <= 0.5
        }
        return lhs.identities == rhs.identities && lhs.frames.count == rhs.frames.count
            && equal(lhs.pageBand, rhs.pageBand) && equal(lhs.clearBand, rhs.clearBand)
            && equal(lhs.rail ?? .null, rhs.rail ?? .null)
            && zip(lhs.frames, rhs.frames).allSatisfy { pair in equal(pair.0, pair.1) }
    }
    private func stable(_ group: Group, targets: [Target]) throws -> State {
        var previous = try read(group, targets: targets)
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 0.2)
            let next = try read(group, targets: targets)
            if same(previous, next) { return next }
            previous = next
        }
        throw Blocked.evidence("Target/control geometry did not settle")
    }
    private func attachScreenshot(_ name: String) {
        serial += 1
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "contrast-reveal-\(serial)-" + name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func capture(_ name: String) throws {
        attachScreenshot(name)
        let data = try JSONEncoder().encode(Hierarchy(app.snapshot()))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "contrast-reveal-\(serial)-" + name + "-hierarchy"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
