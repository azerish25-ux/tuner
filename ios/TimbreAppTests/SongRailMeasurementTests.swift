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
            XCTAssertEqual(cache.hostCount, examples.count)
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
        _ = cache.maximum(key: key(), count: 1) { _ in
            caption("Caption").onAppear { appeared = true }.task { startedTask = true }
        }
        await Task.yield()
        XCTAssertFalse(appeared, "Measurement must not run appearance side effects")
        XCTAssertFalse(startedTask, "Measurement must not start asynchronous work")
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
                    let actual = host.sizeThatFits(in: CGSize(width: 2000, height: .greatestFiniteMagnitude))
                    XCTAssertEqual(width + 10 + height, actual.height, accuracy: 1,
                                   "The lazy rail must retain eager production-caption height: \(language), \(size)")
                }
            }
        }
    }

    func testInitialMiddleSelectionIsRevealedWithoutBuildingEveryCard() async throws {
        struct Item: Identifiable { let id: Int }
        let items = (0..<120).map { Item(id: $0) }
        var constructed = Set<Int>()
        let host = UIHostingController(rootView:
            SongShelfRail(items: items, selection: 59, itemWidth: 148, height: 100, identity: "rail.selection-test") { item in
                let _ = constructed.insert(item.id)
                Text("Song \(item.id)").frame(height: 80)
            }.frame(width: 402, height: 100))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(500))
        func scrolls(_ view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrolls($0) }
        }
        let scroll = try XCTUnwrap(scrolls(host.view).first { $0.contentSize.width > 1000 })
        // Item 60's center must be inside the viewport; allow content margins, not a whole missing card.
        let itemCenter = CGFloat(59) * (148 + 14) + 20 + 74
        let center = scroll.contentOffset.x + scroll.bounds.width / 2
        XCTAssertEqual(center, itemCenter, accuracy: 24)
        XCTAssertGreaterThan(scroll.contentSize.width, CGFloat(119) * 162)
        XCTAssertLessThan(constructed.count, 120, "The lazy rail must not construct the complete offscreen card tree")
        print("Song rail initial middle selection: constructed \(constructed.count) of 120 cards")
    }

}
