import SwiftUI
import UIKit
import XCTest
@testable import Timbre

/// Measure the actual card views, rather than estimating room for a badge drawn over their prices.
@MainActor
final class PaywallLayoutTests: XCTestCase {
    private struct Example {
        let locale: String
        let direction: LayoutDirection
        let offer: String
        let detail: String
        let price: String
        let anchor: String
    }

    private let examples = [
        Example(locale: "en_US", direction: .leftToRight, offer: "14 days free", detail: "$0.67 a week",
                price: "$34.99", anchor: "12 × $6.99"),
        Example(locale: "de_DE", direction: .leftToRight, offer: "14 Tage kostenlos ohne zusätzliche Kosten",
                detail: "0,67 € pro Woche", price: "34,99 €", anchor: "12 × 6,99 €"),
        Example(locale: "ar_SA", direction: .rightToLeft, offer: "١٤ يومًا مجانًا دون أي رسوم إضافية",
                detail: "٠٫٦٧ ر.س. في الأسبوع", price: "١٢٬٣٤٥٫٩٩ ر.س.", anchor: "١٢ × ٦٫٩٩ ر.س."),
    ]

    func testTrialBadgeReservesItsFullHeightAtNarrowWidthsAndLargeType() {
        for example in examples {
            for typeSize in [DynamicTypeSize.large, .xxxLarge, .accessibility3, .accessibility5] {
                for width in [CGFloat(240), CGFloat(343)] {
                    assertSeparateOfferRow(example, width: width, typeSize: typeSize, arrangement: .stacked)
                }
            }
        }
    }

    func testTrialBadgeReservesItsFullHeightInBothCompactArrangements() {
        for example in examples {
            for arrangement in [PlanFace.Arrangement.inline, .savingUnderPrice] {
                assertSeparateOfferRow(example, width: 1200, typeSize: .large, arrangement: arrangement)
            }
        }
    }

    func testPhoneWidthChoosesTheStackedFallbackForLongStorefrontPrices() {
        let example = examples[1]
        let face = PlanFace(title: "Yearly", detail: example.detail, price: "12 345 678,99 soʻm", saving: 58,
                            anchor: "12 × 1 234 567,89 soʻm", selected: true, quiet: false)
        for arrangement in [PlanFace.Arrangement.inline, .savingUnderPrice] {
            let compact = PaywallPlanCardContent(face: face, tag: example.offer, arrangement: arrangement)
                .fixedSize(horizontal: true, vertical: false)
            XCTAssertGreaterThan(measure(compact, width: 343, typeSize: .large, example: example).width, 343,
                                 "This candidate must genuinely be too wide for the phone")
        }
        let adaptive = PaywallPlanArrangements(hasSaving: true) { arrangement in
            PaywallPlanCardContent(face: face, tag: example.offer, arrangement: arrangement)
        }
        let stacked = PaywallPlanCardContent(face: face, tag: example.offer, arrangement: .stacked)
        for typeSize in [DynamicTypeSize.large, .accessibility5] {
            let chosen = measure(adaptive, width: 343, typeSize: typeSize, example: example)
            let fallback = measure(stacked, width: 343, typeSize: typeSize, example: example)
            XCTAssertLessThanOrEqual(chosen.width, 343.5)
            XCTAssertEqual(chosen.height, fallback.height, accuracy: 1)
        }
    }

    func testLongOffersWrapInsteadOfShrinkingOrTruncating() {
        for example in examples.dropFirst() {
            let badge = PaywallOfferBadge(text: example.offer, trial: true)
            let wide = measure(badge, width: 1200, typeSize: .large, example: example)
            let narrow = measure(badge, width: 180, typeSize: .large, example: example)
            let accessible = measure(badge, width: 180, typeSize: .accessibility5, example: example)
            XCTAssertGreaterThan(narrow.height, wide.height, example.locale)
            XCTAssertGreaterThan(accessible.height, narrow.height, example.locale)
            XCTAssertLessThanOrEqual(narrow.width, 180.5, example.locale)
            XCTAssertLessThanOrEqual(accessible.width, 180.5, example.locale)
        }
    }

    private func assertSeparateOfferRow(_ example: Example, width: CGFloat, typeSize: DynamicTypeSize,
                                        arrangement: PlanFace.Arrangement, file: StaticString = #filePath, line: UInt = #line) {
        let face = PlanFace(title: "Yearly", detail: example.detail, price: example.price, saving: 58,
                            anchor: example.anchor, selected: true, quiet: false)
        let plain = measure(PaywallPlanCardContent(face: face, tag: nil, arrangement: arrangement),
                            width: width, typeSize: typeSize, example: example)
        let tagged = measure(PaywallPlanCardContent(face: face, tag: example.offer, arrangement: arrangement),
                             width: width, typeSize: typeSize, example: example)
        let badge = measure(PaywallOfferBadge(text: example.offer, trial: true),
                            width: width, typeSize: typeSize, example: example)
        let context = "\(example.locale), \(typeSize), width \(width), \(arrangement)"
        // An overlay with guessed top padding cannot satisfy this: every rendered line of the offer contributes
        // its full height, plus separation, without borrowing any room from the plan's price or name.
        XCTAssertEqual(tagged.height, plain.height + badge.height + 6, accuracy: 1, context, file: file, line: line)
        XCTAssertLessThanOrEqual(tagged.width, width + 0.5, context, file: file, line: line)
    }

    private func measure<Content: View>(_ content: Content, width: CGFloat, typeSize: DynamicTypeSize,
                                        example: Example) -> CGSize {
        let host = UIHostingController(rootView: content
            .environment(\.locale, Locale(identifier: example.locale))
            .environment(\.layoutDirection, example.direction)
            .environment(\.dynamicTypeSize, typeSize))
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
