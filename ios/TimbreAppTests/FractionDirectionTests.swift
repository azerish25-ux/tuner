import SwiftUI
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class FractionDirectionTests: XCTestCase {
    func testProgressFractionKeepsTheSameNumericOrderInBothLayoutDirections() throws {
        for locale in ["ar_SA", "fa_IR", "he_IL", "en_US"] {
            for counts in [(3, 6), (12, 34)] {
                let leftToRight = try render(counts.0, counts.1, locale: locale, direction: .leftToRight)
                let rightToLeft = try render(counts.0, counts.1, locale: locale, direction: .rightToLeft)
                XCTAssertEqual(leftToRight, rightToLeft,
                               "The completed/total order must stay intact in \(locale): \(counts.0)/\(counts.1)")
            }
        }
    }

    func testDirectionFixDoesNotCollapseDifferentProgressValues() throws {
        let threeOfSix = try render(3, 6, locale: "ar_SA", direction: .rightToLeft)
        let sixOfThree = try render(6, 3, locale: "ar_SA", direction: .rightToLeft)
        XCTAssertNotEqual(threeOfSix, sixOfThree)
    }

    private func render(_ done: Int, _ total: Int, locale: String, direction: LayoutDirection) throws -> Data {
        let content = Text.fraction(done, total)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(Color.black)
            .frame(width: 240, height: 64)
            .background(Color.white)
            .environment(\.locale, Locale(identifier: locale))
            .environment(\.layoutDirection, direction)
            .environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = true
        return try XCTUnwrap(renderer.uiImage?.pngData())
    }
}
