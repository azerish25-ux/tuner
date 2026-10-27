import SwiftUI
import UIKit
import XCTest
import TimbreCore
@testable import Timbre

@MainActor
final class SongRailMeasurementTests: XCTestCase {
    private func key(_ size: DynamicTypeSize = .large, locale: String = "en_US") -> SongRailMeasurement.Key {
        .init(content: ["caption"], width: 148, locale: locale, language: locale,
              typeSize: size, direction: .leftToRight, legibility: nil, bold: false, scale: 3)
    }

    private func caption(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: text).font(Typeface.label(TypeStep.caption.points, relativeTo: .subheadline))
                .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8).padding(.vertical, 4).frame(minHeight: 24)
            Text("+35 XP").font(.footnote).lineLimit(1)
        }
    }

    func testMaximumUsesAllCaptionsAndExactNativeFallbackSizing() {
        let examples = ["Finish your first song", "Terminez votre première chanson avec les nouveaux accords",
                        "أكمل أغنيتك الأولى", "முதல் பாடலை வாசித்து முடிக்கவும்", "最初の曲を完成させる"]
        for size in [DynamicTypeSize.large, .xxxLarge, .accessibility5] {
            let cache = SongRailMeasurement()
            let signature = key(size)
            let measured = cache.maximum(key: signature, count: examples.count) { caption(examples[$0]) }
            for example in examples {
                let actual = SongRailMeasurement.measure(caption(example), key: signature)
                XCTAssertGreaterThanOrEqual(measured, actual.height)
            }
            let maximum = examples.map { SongRailMeasurement.measure(caption($0), key: signature).height }.max() ?? 0
            XCTAssertEqual(measured, maximum, accuracy: 1 / signature.scale)
            XCTAssertEqual(cache.hostCount, 1)
            XCTAssertEqual(cache.measurementCount, examples.count)
            print("Caption sizing native observation: \(size), \(cache.lastDuration)s, \(cache.hostCount) hosts")
        }
    }

    func testCacheDoesNotRetainOrRebuildViewsOnHitAndIsBounded() {
        let cache = SongRailMeasurement()
        let signature = key()
        _ = cache.maximum(key: signature, count: 120) { caption("Caption \($0)") }
        let hosts = cache.hostCount
        _ = cache.maximum(key: signature, count: 120) { _ in
            XCTFail("A cache hit must not build a caption")
            return Text("unexpected")
        }
        XCTAssertEqual(cache.hostCount, hosts)
        for index in 0..<40 {
            var changed = signature
            changed.content = [String(index)]
            _ = cache.maximum(key: changed, count: 1) { _ in caption("Caption") }
        }
        XCTAssertEqual(cache.entryCount, SongRailMeasurement.capacity)
    }

    func testEachGeometryEnvironmentChangeInvalidatesTheCache() {
        let cache = SongRailMeasurement()
        let original = key()
        var keys = [original]
        var changed = original; changed.content = ["other standing/versions/stars/calm"]; keys.append(changed)
        changed = original; changed.width = 176; keys.append(changed)
        changed = original; changed.locale = "ar_SA"; keys.append(changed)
        changed = original; changed.language = "ar"; keys.append(changed)
        changed = original; changed.typeSize = .accessibility5; keys.append(changed)
        changed = original; changed.direction = .rightToLeft; keys.append(changed)
        changed = original; changed.legibility = .bold; keys.append(changed)
        changed = original; changed.bold = true; keys.append(changed)
        changed = original; changed.scale = 2; keys.append(changed)
        for signature in keys { _ = cache.maximum(key: signature, count: 1) { _ in caption("Caption") } }
        XCTAssertEqual(cache.hostCount, keys.count)
    }

    func testOffWindowMeasurementDoesNotInvokeAppearanceOrTask() async {
        var appeared = false
        var startedTask = false
        let cache = SongRailMeasurement()
        _ = cache.maximum(key: key(), count: 3) { _ in
            caption("Caption").onAppear { appeared = true }.task { startedTask = true }
        }
        await Task.yield()
        XCTAssertFalse(appeared, "Measurement must not run appearance side effects")
        XCTAssertFalse(startedTask, "Measurement must not start asynchronous work")
    }

    private struct StatefulSizingCaption: View {
        @State private var height: CGFloat
        init(height: CGFloat) { _height = State(initialValue: height) }
        var body: some View { Color.clear.frame(height: height) }
    }

    func testReusedHostingRootResetsStateAndMeasuresEveryCaptionOnce() {
        for size in [DynamicTypeSize.large, .accessibility5] {
            for width in [CGFloat(148), CGFloat(176)] {
                var signature = key(size); signature.width = width
                let cache = SongRailMeasurement()
                let heights: [CGFloat] = [10, 75, 20, 110, 12]
                var built: [Int] = []
                let maximum = cache.maximum(key: signature, count: heights.count) { index in
                    built.append(index)
                    return StatefulSizingCaption(height: heights[index])
                }
                XCTAssertEqual(maximum, 110, accuracy: 1 / signature.scale)
                XCTAssertEqual(built, Array(heights.indices))
                XCTAssertEqual(cache.hostCount, 1)
                XCTAssertEqual(cache.measurementCount, heights.count)
            }
        }
    }

    private final class SizingLifetimeToken { let id = UUID().uuidString }
    private final class WeakSizingToken {
        weak var token: SizingLifetimeToken?
        init(_ token: SizingLifetimeToken) { self.token = token }
    }
    private struct LifetimeSizingCaption: View {
        let token: SizingLifetimeToken
        var body: some View { Text("Caption").accessibilityIdentifier(token.id) }
    }

    func testBatchDoesNotRetainCaptionTreesInTheHeightCache() async {
        let cache = SongRailMeasurement()
        var references: [WeakSizingToken] = []
        autoreleasepool {
            _ = cache.maximum(key: key(), count: 12) { _ in
                let token = SizingLifetimeToken()
                references.append(WeakSizingToken(token))
                return LifetimeSizingCaption(token: token)
            }
        }
        await Task.yield()
        XCTAssertEqual(references.count, 12)
        XCTAssertTrue(references.allSatisfy { $0.token == nil },
                      "Only value-type signatures and heights may survive a sizing batch")
        XCTAssertEqual(cache.entryCount, 1)
    }

    func testEmptyShelfDoesNotCreateAHostOrEvaluateContent() {
        let cache = SongRailMeasurement()
        let height = cache.maximum(key: key(), count: 0) { _ in
            XCTFail("An empty shelf has no caption")
            return Text("Unexpected")
        }
        XCTAssertEqual(height, 0)
        XCTAssertEqual(cache.hostCount, 0)
        XCTAssertEqual(cache.measurementCount, 0)
    }

    func testAccessibleTypeGrowsRatherThanCapsTheNaturalRowHeight() {
        let cache = SongRailMeasurement()
        let normal = cache.maximum(key: key(), count: 1) { _ in caption("Finish your first song") }
        let accessible = cache.maximum(key: key(.accessibility5), count: 1) { _ in caption("Finish your first song") }
        XCTAssertGreaterThan(accessible, normal)
    }
    func testProductionCaptionsMatchIndependentEagerRowIncludingLocksAndVersions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(directory: directory)
        let catalog = SongsCatalog()
        let layout = catalog.layout(filter: "bass.electric.4", course: "guitar", store: store)
        let rail = try XCTUnwrap(layout.rails.first { $0.shelf.id == "bass-songbook" })
        XCTAssertEqual(rail.songs.count, 120)
        let songs = [rail.songs[0], rail.songs[59], rail.songs[119]]
        let gate = try XCTUnwrap(store.curriculum.course(id: "guitar")?.lessons.last)
        let versions = Array(store.curriculum.courses.prefix(5))
        let originalLanguage = TimbreLocalization.language
        defer { TimbreLocalization.language = originalLanguage }
        for language in ["en", "ar", "ta"] {
            TimbreLocalization.language = language
            for size in [DynamicTypeSize.large, .accessibility5] {
                for (width, versionLimit) in [(CGFloat(148), 2), (CGFloat(176), 3)] {
                    var signature = key(size, locale: language)
                    signature.width = width
                    signature.direction = language == "ar" ? .rightToLeft : .leftToRight
                    signature.content = songs.map(\.id) + [language]
                    let captions: (Int) -> AnyView = { index in
                        let song = songs[index]
                        let access: LessonAccess = index == 0 ? .locked : index == 1 ? .play : .pro
                        return AnyView(SongsView.TileCaption(song: song, sheet: SongSheet.of(song.lesson), accent: Palette.mint,
                            standing: .init(access: access, gate: gate), stars: index == 2 ? 3 : 0,
                            calm: false, versionLimit: versionLimit, others: versions, identity: "production-caption.\(index)").environmentObject(store))
                    }
                    let cache = SongRailMeasurement()
                    let height = cache.maximum(key: signature, count: songs.count, caption: captions)
                    // Independent oracle: the former eager layout measures the actual full set together.
                    // It does not call the measurement helper or infer height from the first visible item.
                    let eager = HStack(alignment: .top, spacing: 14) {
                        ForEach(0..<songs.count, id: \.self) { index in
                            VStack(spacing: 10) {
                                Rectangle().frame(width: width, height: width)
                                captions(index)
                            }.frame(width: width)
                        }
                    }.fixedSize()
                    let host = UIHostingController(rootView: eager
                        .environment(\.locale, Locale(identifier: language))
                        .environment(\.layoutDirection, signature.direction)
                        .environment(\.dynamicTypeSize, size))
                    let actual = host.sizeThatFits(in: CGSize(width: 2000, height: CGFloat.greatestFiniteMagnitude))
                    XCTAssertEqual(width + 10 + height, actual.height, accuracy: 1,
                                   "The lazy rail must retain eager production-caption height: \(language), \(size)")
                }
            }
        }
    }

    /// Exercise every production shelf, not three representative captions. Timings are observations, not
    /// an invented performance threshold or proof that the on-screen accessibility traversal completes.
    func testFullProductionCatalogueCaptionSizingAcrossDynamicType() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AppStore(directory: directory)
        DemoData.seed(store)
        let originalLanguage = TimbreLocalization.language
        TimbreLocalization.language = "en"
        defer { TimbreLocalization.language = originalLanguage }
        let catalog = SongsCatalog()
        let layout = catalog.layout(filter: SongsView.all, course: "guitar", store: store)
        let expected = Set(store.curriculum.courses.flatMap { course in
            course.lessons.filter { $0.kind == .song }.map(\.id)
        })
        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(Set(layout.rails.flatMap { $0.songs.map(\.id) }), expected,
                       "The performance fixture must cover the entire shipped catalogue")
        let shelves = catalogueShelves(layout)
        var observations = ["Off-window caption sizing only; no covers, scene layout or AX traversal."]
        for size in [DynamicTypeSize.large, .accessibility5] {
            let cache = SongRailMeasurement()
            let started = ProcessInfo.processInfo.systemUptime
            var sizingSeconds = 0.0
            var oracleSeconds = 0.0
            var freshHostSeconds = 0.0
            var captionCount = 0
            for shelf in shelves {
                let result = measureProductionShelf(shelf, size: size, cache: cache, catalog: catalog, store: store)
                sizingSeconds += result.sizingSeconds
                oracleSeconds += result.oracleSeconds
                freshHostSeconds += result.freshHostSeconds
                captionCount += shelf.songs.count
                observations.append("type=\(size) shelf=\(shelf.id) captions=\(shelf.songs.count) "
                    + "sizingSeconds=\(result.sizingSeconds) eagerOracleSeconds=\(result.oracleSeconds) freshHostSeconds=\(result.freshHostSeconds)")
            }
            XCTAssertEqual(cache.hostCount, shelves.count)
            XCTAssertEqual(cache.measurementCount, captionCount)
            observations.append("TOTAL type=\(size) shelves=\(shelves.count) uniqueSongs=\(expected.count) "
                + "captions=\(captionCount) hosts=\(cache.hostCount) measurements=\(cache.measurementCount) sizingSeconds=\(sizingSeconds) eagerOracleSeconds=\(oracleSeconds) freshHostSeconds=\(freshHostSeconds) "
                + "wallSeconds=\(ProcessInfo.processInfo.systemUptime - started)")
        }
        let report = observations.joined(separator: "\n")
        print("SONG-RAIL full catalogue:\n" + report)
        let attachment = XCTAttachment(string: report)
        attachment.name = "song-rail-full-production-catalogue-sizing"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func catalogueShelves(_ layout: SongsCatalog.Layout) -> [(id: String, songs: [SongsView.Song])] {
        var shelves = layout.picks.map { (id: "pick." + $0.id, songs: $0.songs) }
        let split = min(max(0, layout.lowerAfter), layout.rails.count)
        shelves += layout.rails[..<split].map { (id: "rail." + $0.id, songs: $0.songs) }
        if let lower = layout.lower { shelves.append((id: "pick." + lower.id, songs: lower.songs)) }
        shelves += layout.rails[split...].map { (id: "rail." + $0.id, songs: $0.songs) }
        return shelves
    }

    private func productionCaption(_ song: SongsView.Song, catalog: SongsCatalog, store: AppStore) -> AnyView {
        var versions: [LearnCourse] = []
        for version in catalog.versions(of: song).dropFirst() where !versions.contains(where: { $0.id == version.course.id }) {
            versions.append(version.course)
        }
        return AnyView(SongsView.TileCaption(song: song, sheet: SongSheet.of(song.lesson), accent: Palette.accent(song.course.accent),
            standing: catalog.standing(song), stars: store.learn.stars[song.id] ?? 0, calm: store.settings.calmMode,
            versionLimit: 2, others: versions, identity: "catalogue-caption." + song.id).environmentObject(store))
    }

    private func measureProductionShelf(_ shelf: (id: String, songs: [SongsView.Song]), size: DynamicTypeSize,
                                        cache: SongRailMeasurement, catalog: SongsCatalog, store: AppStore)
        -> (sizingSeconds: Double, oracleSeconds: Double, freshHostSeconds: Double) {
        var signature = key(size, locale: "en")
        // This fixture freezes progress, language, width and versions for both calls; production's full
        // mutable signature remains independently checked by the source contract and invalidation tests.
        signature.content = [shelf.id] + shelf.songs.map(\.id)
        let hostsBefore = cache.hostCount
        let measurementsBefore = cache.measurementCount
        let height = cache.maximum(key: signature, count: shelf.songs.count) { index in
            productionCaption(shelf.songs[index], catalog: catalog, store: store)
        }
        let sizingSeconds = cache.lastDuration
        XCTAssertEqual(cache.hostCount - hostsBefore, 1)
        XCTAssertEqual(cache.measurementCount - measurementsBefore, shelf.songs.count)
        XCTAssertTrue(height.isFinite)
        XCTAssertGreaterThan(height, 0)
        let warmHeight = cache.maximum(key: signature, count: shelf.songs.count) { _ in
            XCTFail("A complete production shelf's cache hit must not build captions")
            return Text("unexpected")
        }
        XCTAssertEqual(warmHeight, height)
        XCTAssertEqual(cache.hostCount - hostsBefore, 1)
        XCTAssertEqual(cache.measurementCount - measurementsBefore, shelf.songs.count)
        let oracleStarted = ProcessInfo.processInfo.systemUptime
        let eagerHeight = autoreleasepool {
            let eager = HStack(alignment: .top, spacing: 14) {
                ForEach(shelf.songs) { song in
                    self.productionCaption(song, catalog: catalog, store: store).frame(width: 148)
                }
            }.fixedSize()
            let host = UIHostingController(rootView: eager.environment(\.locale, Locale(identifier: "en"))
                .environment(\.layoutDirection, LayoutDirection.leftToRight).environment(\.dynamicTypeSize, size)
                .environment(\.displayScale, signature.scale))
            let width = CGFloat(shelf.songs.count) * 162
            return host.sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
        }
        XCTAssertEqual(height, eagerHeight, accuracy: 1, "Full production shelf: \(shelf.id), \(size)")
        let oracleSeconds = ProcessInfo.processInfo.systemUptime - oracleStarted
        // Compare the former per-caption host allocation using this SAME production layout and environment.
        // Record timing only: no machine-dependent performance threshold can waive a correctness failure.
        let freshStarted = ProcessInfo.processInfo.systemUptime
        var freshMaximum: CGFloat = 0
        for song in shelf.songs {
            let measured = autoreleasepool {
                SongRailMeasurement.measure(self.productionCaption(song, catalog: catalog, store: store), key: signature)
            }
            freshMaximum = max(freshMaximum, measured.height)
        }
        XCTAssertEqual(height, freshMaximum, accuracy: 1 / signature.scale,
                       "Reusing a host must equal independently created hosts for every production shelf")
        return (sizingSeconds, oracleSeconds, ProcessInfo.processInfo.systemUptime - freshStarted)
    }

    func testInitialMiddleSelectionIsRevealedWithoutBuildingEveryCard() async throws {
        struct Item: Identifiable { let id: Int }
        let items = (0..<120).map { Item(id: $0) }
        var constructed = Set<Int>()
        var appeared = false
        let host = UIHostingController(rootView:
            SongShelfRail(items: items, selection: 59, itemWidth: 148, height: 100, identity: "rail.selection-test") { item in
                let _ = constructed.insert(item.id)
                Text("Song \(item.id)").frame(height: 80)
            }.frame(width: 402, height: 100).onAppear { appeared = true })
        // A scene-less UIWindow can lay out offscreen views without a displayed SwiftUI scroll lifecycle.
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
        host.view.layoutIfNeeded()
        func scrolls(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrolls($0) }
        }
        // Observe the actual async completion condition, not a fixed delay after an unattached layout.
        let itemCenter = CGFloat(59) * (148 + 14) + 20 + 74
        let revealed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard appeared, host.view.window === window,
                  let scroll = scrolls(host.view).first(where: { $0.contentSize.width > 1000 }) else { return false }
            let center = scroll.contentOffset.x + scroll.bounds.width / 2
            return abs(center - itemCenter) <= 24
        }, object: nil)
        await fulfillment(of: [revealed], timeout: 3)
        let scroll = try XCTUnwrap(scrolls(host.view).first { $0.contentSize.width > 1000 })
        let diagnostic = XCTAttachment(string: "appeared=\(appeared) scene=\(scene.activationState.rawValue) key=\(window.isKeyWindow) "
            + "window=\(window.frame) scroll=\(scroll.frame) content=\(scroll.contentSize) offset=\(scroll.contentOffset) "
            + "constructed=\(constructed.count) expectedCenter=\(itemCenter)")
        diagnostic.name = "song-rail-initial-selection-layout"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTAssertTrue(appeared)
        XCTAssertTrue(host.view.window === window)
        // Item 60's center must be inside the viewport; allow content margins, not a whole missing card.
        let center = scroll.contentOffset.x + scroll.bounds.width / 2
        XCTAssertEqual(center, itemCenter, accuracy: 24)
        XCTAssertGreaterThan(scroll.contentSize.width, CGFloat(119) * 162)
        XCTAssertLessThan(constructed.count, 120, "The lazy rail must not construct the complete offscreen card tree")
        print("Song rail initial middle selection: constructed \(constructed.count) of 120 cards")
    }

}
