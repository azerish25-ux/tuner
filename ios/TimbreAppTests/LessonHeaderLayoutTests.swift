import SwiftUI
import UIKit
import XCTest
@testable import Timbre

/// A full accessibility label alone does not show that the visible lesson name fits.
@MainActor
final class LessonHeaderLayoutTests: XCTestCase {
    func testLongLessonNamesWrapAtPhoneWidths() {
        let titles = [
            "Faites connaissance avec votre guitare",
            "Ролл с чередованием большого пальца: смена аккордов",
        ]
        for title in titles {
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                for typeSize in [DynamicTypeSize.large, .accessibility1] {
                    let wide = measure(title, width: 1200, direction: direction, typeSize: typeSize)
                    let narrow = measure(title, width: 240, direction: direction, typeSize: typeSize)
                    XCTAssertGreaterThan(narrow.height, wide.height + 1,
                                         "The complete title must reserve additional lines: \(title)")
                    XCTAssertLessThanOrEqual(narrow.width, 240.5)
                }
            }
        }
    }

    func testShortLessonNameKeepsTheCompactHeader() {
        let wide = measure("Guitar", width: 1200, direction: .leftToRight, typeSize: .large)
        let narrow = measure("Guitar", width: 240, direction: .leftToRight, typeSize: .large)
        XCTAssertEqual(narrow.height, wide.height, accuracy: 1)
        XCTAssertLessThanOrEqual(narrow.width, 240.5)
    }

    private func measure(_ title: String, width: CGFloat, direction: LayoutDirection,
                         typeSize: DynamicTypeSize) -> CGSize {
        let header = LessonHeader(title: title, index: 0, steps: 5, accent: .green)
            .environment(\.layoutDirection, direction)
            .environment(\.dynamicTypeSize, typeSize)
        let host = UIHostingController(rootView: header)
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
