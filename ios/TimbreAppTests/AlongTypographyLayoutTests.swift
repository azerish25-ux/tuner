import SwiftUI
import UIKit
import XCTest
import TimbreCore
@testable import Timbre

/// Native component geometry and original raster attachments; whole-step reachability remains a UI-test gate.
@MainActor
final class AlongTypographyLayoutTests: XCTestCase {
    func testEqualWidthRowUsesIntrinsicFitRatherThanATypeSizeThreshold() {
        XCTAssertTrue(AlongActionLayout.fitsRow([100, 120], available: 250, spacing: 10))
        XCTAssertFalse(AlongActionLayout.fitsRow([100, 120], available: 249, spacing: 10))
        XCTAssertFalse(AlongActionLayout.fitsRow([180, 240], available: 362, spacing: 10))
        XCTAssertTrue(AlongActionLayout.fitsRow([180, 240], available: 490, spacing: 10))
        XCTAssertTrue(AlongActionLayout.fitsRow([], available: 0, spacing: 10))
    }

    func testNativeActionsFitAtNormalAndAX5InLTRAndRTL() throws {
        let language = TimbreLocalization.language
        defer { TimbreLocalization.language = language }
        for locale in ["en", "de", "ar"] {
            TimbreLocalization.language = locale
            for size in [DynamicTypeSize.large, .accessibility5] {
                for width in [CGFloat(280), 362] {
                    for primary in [false, true] {
                        let content = AlongActionLayout(spacing: 10) {
                            ActionFitProbe(available: width) {
                                AlongDoneButton(title: "Try again", primary: primary) {}
                            }
                            ActionFitProbe(available: width) {
                                AlongDoneButton(title: "Continue", primary: !primary) {}
                            }
                        }
                        try capture(content, width: width, locale: locale, size: size,
                                    name: "along-actions-\(locale)-\(size)-\(Int(width))-\(primary)")
                    }
                }
            }
        }
    }

    func testPlayingPlaceReservesAllLocalizedLinesInsteadOfAnEllipsis() throws {
        let language = TimbreLocalization.language
        defer { TimbreLocalization.language = language }
        for locale in ["en", "de", "ar"] {
            TimbreLocalization.language = locale
            let words = NotePlace.words(Fretting(string: 6, fret: 0), board: nil)
            for width in [CGFloat(140), 280, 362] {
                let actual = AlongPlaceLabel(words: words, tint: Palette.mint)
                // Same native font and complete localized copy, independent of the badge component and flow.
                let fullText = Text(verbatim: words).font(Typeface.label(.body))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                let measured = measure(actual, width: width, locale: locale, size: .accessibility5)
                let reference = measure(fullText, width: width, locale: locale, size: .accessibility5)
                XCTAssertLessThanOrEqual(measured.width, width)
                XCTAssertEqual(measured.height, reference.height, "All native localized lines must receive height")
                try capture(actual, width: width, locale: locale, size: .accessibility5,
                            name: "along-place-\(locale)-\(Int(width))")
                if locale == "en", width == 140 {
                    let former = Text(verbatim: words).font(Typeface.label(.body))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                    XCTAssertLessThan(measure(former, width: width, locale: locale, size: .accessibility5).height,
                                      measured.height, "The original ellipsized badge must fail the full-height control")
                }
            }
        }
    }

    func testQueuedNotesGrowAndWrapWithoutCappingTypeOrReversingMusic() throws {
        let notes = [40, 45, 50, 55, 59, 64].enumerated().map {
            TimedNote(midi: $0.element, beat: Double($0.offset), beats: 1,
                      at: Fretting(string: 6 - $0.offset, fret: 0))
        }
        let rail = UpNextRail(notes: notes, from: 0, fretted: true, strings: 6, accent: Palette.mint)
        for width in [CGFloat(280), 362] {
            let normal = measure(rail, width: width, locale: "en", size: .large)
            let large = measure(rail, width: width, locale: "en", size: .accessibility5)
            XCTAssertGreaterThan(large.height, normal.height, "A 44pt rail must not squeeze uncapped AX5 figures")
            XCTAssertLessThanOrEqual(large.width, width)
            try capture(rail, width: width, locale: "en", size: .accessibility5,
                        name: "along-queue-ltr-\(Int(width))")
            // Notes remain LTR in an RTL interface; the production rail owns that override.
            try capture(rail, width: width, locale: "ar", size: .accessibility5,
                        name: "along-queue-rtl-interface-\(Int(width))")
        }
    }

    func testAXResultSurfaceUsesContentHeightInsteadOfTheFormerStageCeiling() throws {
        executionTimeAllowance = 120
        let language = TimbreLocalization.language
        defer { TimbreLocalization.language = language }
        for locale in ["en", "de", "ar"] {
            TimbreLocalization.language = locale
            for width in [CGFloat(280), 362] {
                // This is a surface/component fixture, not a fabricated completed session or hosted screen.
                let content = resultSurfaceFixture
                let natural = measure(content, width: width - 24, locale: locale, size: .accessibility5)
                let surface = AlongResultSurface(tint: Palette.mint) { content }
                let actual = measure(surface, width: width, locale: locale, size: .accessibility5)
                XCTAssertEqual(actual.width, width)
                XCTAssertEqual(actual.height, max(420, natural.height + 24))
                XCTAssertGreaterThan(actual.height, 420, "The real AX content must not be squeezed into the old stage")
                let former = Color.clear.frame(height: 420).overlay(content.padding(12))
                XCTAssertEqual(measure(former, width: width, locale: locale, size: .accessibility5).height, 420,
                               "An overlaid summary does not reserve its own height")
                try capture(surface, width: width, locale: locale, size: .accessibility5,
                            name: "along-result-surface-\(locale)-\(Int(width))")
            }
        }
    }

    func testResultStatsAndTempoReserveFullLocalizedNativeText() throws {
        executionTimeAllowance = 120
        let language = TimbreLocalization.language
        defer { TimbreLocalization.language = language }
        for locale in ["en", "de", "ar"] {
            TimbreLocalization.language = locale
            for width in [CGFloat(140), 280, 338] {
                let labels: [LocalizedStringKey] = ["Perfect", "Good", "Early/late", "Missed"]
                for label in labels {
                    let stat = AlongResultStat(label: label, value: 6, color: Palette.mint, id: "fixture")
                    let fullText = VStack(spacing: 2) {
                        Text("6").font(Typeface.number(20))
                        Text(label).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                    let actual = measure(stat, width: width, locale: locale, size: .accessibility5)
                    let reference = measure(fullText, width: width, locale: locale, size: .accessibility5)
                    XCTAssertLessThanOrEqual(actual.width, width)
                    XCTAssertEqual(actual.height, reference.height, "Every complete localized grade receives native height")
                }
            }
            for width in [CGFloat(280), 338] {
                let stats = AlongResultStats(perfect: 6, good: 0, earlyLate: 0, missed: 0, accent: Palette.mint)
                let actual = measure(stats, width: width, locale: locale, size: .accessibility5)
                XCTAssertLessThanOrEqual(actual.width, width)
                XCTAssertGreaterThan(actual.height, measure(stats, width: width, locale: locale, size: .large).height)
                try capture(stats, width: width, locale: locale, size: .accessibility5,
                            name: "along-result-stats-\(locale)-\(Int(width))")
                let tempo = AlongTempoUpLabel(percent: 110, tint: Palette.mint)
                let fullTempo = HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                    Text("Tempo up").fixedSize(horizontal: false, vertical: true)
                }.font(Typeface.label(13)).padding(.horizontal, 12).padding(.vertical, 5)
                let measured = measure(tempo, width: width, locale: locale, size: .accessibility5)
                XCTAssertLessThanOrEqual(measured.width, width)
                XCTAssertGreaterThanOrEqual(measured.height,
                    measure(fullTempo, width: width, locale: locale, size: .accessibility5).height)
                try capture(tempo, width: width, locale: locale, size: .accessibility5,
                            name: "along-result-tempo-\(locale)-\(Int(width))")
            }
        }
    }

    func testNormalResultStatsKeepTheirOriginalRowGeometry() {
        executionTimeAllowance = 120
        let language = TimbreLocalization.language
        defer { TimbreLocalization.language = language }
        for locale in ["en", "de", "ar"] {
            TimbreLocalization.language = locale
            let original = HStack(spacing: 18) {
                originalResultStat("Perfect", 6, TakeRibbon.color(.perfect, accent: Palette.mint))
                originalResultStat("Good", 0, TakeRibbon.color(.good, accent: Palette.mint))
                originalResultStat("Early/late", 0, TakeRibbon.color(.ok, accent: Palette.mint))
                originalResultStat("Missed", 0, TakeRibbon.color(.miss, accent: Palette.mint))
            }
            for width in [CGFloat(280), 362] {
                let current = AlongResultStats(perfect: 6, good: 0, earlyLate: 0, missed: 0, accent: Palette.mint)
                XCTAssertEqual(measure(current, width: width, locale: locale, size: .large),
                               measure(original, width: width, locale: locale, size: .large))
            }
        }
    }

    private var resultSurfaceFixture: some View {
        VStack(spacing: 10) {
            Text("100%").font(Typeface.note(.display))
            AlongTempoUpLabel(percent: 110, tint: Palette.mint)
            AlongResultStats(perfect: 6, good: 0, earlyLate: 0, missed: 0, accent: Palette.mint)
            Text("Right on the beat").font(.subheadline.weight(.semibold))
            Text("Best combo \(6)").font(.footnote)
            // Actual pill layout; suppress only its asynchronous poster rendering in this geometry fixture.
            SharePill(preview: "Right on the beat", tint: Palette.mint, armed: false) { Color.clear }
        }
    }

    private func originalResultStat(_ label: LocalizedStringKey, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(Typeface.number(20)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    /// Pass-through measurement of the real styled button. Assertions run only at actual native placement.
    /// No production frame hook or independently invented text metrics are involved.
    private struct ActionFitProbe: Layout {
        let available: CGFloat
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            subviews[0].sizeThatFits(proposal)
        }
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let ideal = subviews[0].sizeThatFits(.unspecified)
            let naturalHeight = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            XCTAssertLessThanOrEqual(bounds.width, available)
            XCTAssertGreaterThanOrEqual(bounds.height, naturalHeight)
            if ideal.width <= available {
                XCTAssertGreaterThanOrEqual(bounds.width, ideal.width,
                                            "A label that fits a full button must not be compressed into a half-width row")
            } else {
                XCTAssertEqual(bounds.width, available, "A long localized label needs the entire column width")
            }
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        }
    }

    private func configured<V: View>(_ view: V, locale: String, size: DynamicTypeSize) -> some View {
        view.environment(\.locale, Locale(identifier: locale))
            .environment(\.dynamicTypeSize, size)
            .environment(\.layoutDirection, locale == "ar" ? .rightToLeft : .leftToRight)
    }

    private func measure<V: View>(_ view: V, width: CGFloat, locale: String, size: DynamicTypeSize) -> CGSize {
        let host = UIHostingController(rootView: configured(view, locale: locale, size: size))
        return host.sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    }

    private func capture<V: View>(_ view: V, width: CGFloat, locale: String, size: DynamicTypeSize, name: String) throws {
        let renderer = ImageRenderer(content: configured(view, locale: locale, size: size)
            .frame(width: width, alignment: .leading).padding(20).background(Palette.stage))
        renderer.scale = 3
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
