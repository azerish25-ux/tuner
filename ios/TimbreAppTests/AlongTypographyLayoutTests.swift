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
