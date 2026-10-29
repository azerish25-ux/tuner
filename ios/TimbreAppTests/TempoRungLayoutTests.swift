import SwiftUI
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class TempoRungLayoutTests: XCTestCase {
    func testFullTempoPercentagesAndBPMKeepTheirOwnLinesAtAccessibleGridWidth() {
        for locale in ["en_US", "de_DE", "ar_SA", "fa_IR"] {
            for percent in [75, 90, 100, 110] {
                for typeSize in [DynamicTypeSize.large, .accessibility3, .accessibility5] {
                    let face = TempoRungFace(percent: percent, bpm: 132)
                        .environment(\.locale, Locale(identifier: locale))
                        .environment(\.dynamicTypeSize, typeSize)
                        .environment(\.layoutDirection, ["ar_SA", "fa_IR"].contains(locale) ? .rightToLeft : .leftToRight)
                    let host = UIHostingController(rootView: face)
                    let wide = host.sizeThatFits(in: CGSize(width: 1200, height: CGFloat.greatestFiniteMagnitude))
                    let narrow = host.sizeThatFits(in: CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(narrow.width, 160.5)
                    XCTAssertEqual(narrow.height, wide.height, accuracy: 0.5,
                                   "The complete \(percent)% and BPM must not gain extra lines in \(locale)")
                    XCTAssertGreaterThanOrEqual(narrow.height, 48)
                }
            }
        }
    }
}
