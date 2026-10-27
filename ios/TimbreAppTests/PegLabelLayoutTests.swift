import SwiftUI
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class PegLabelLayoutTests: XCTestCase {
    func testMeasuredLargeTextCueRemainsInsideStageAndClearOfControls() {
        let size = CGSize(width: 402, height: 300)
        for locale in ["en_US", "de_DE", "ar_SA", "fa_IR"] {
            for typeSize in [DynamicTypeSize.large, .accessibility5] {
                for controlsOnLeft in [false, true] {
                    let label = PegLabel(note: "E2", turn: .none, color: .white, prompt: true)
                        .environment(\.locale, Locale(identifier: locale))
                        .environment(\.dynamicTypeSize, typeSize)
                        .environment(\.layoutDirection, controlsOnLeft ? .rightToLeft : .leftToRight)
                    let host = UIHostingController(rootView: label)
                    let measured = host.sizeThatFits(in: CGSize(width: 322, height: .greatestFiniteMagnitude))
                    XCTAssertGreaterThan(measured.width, 0)
                    XCTAssertGreaterThan(measured.height, 0)
                    for point in [CGPoint(x: 157, y: 150), CGPoint(x: 30, y: 20), CGPoint(x: 370, y: 280)] {
                        let frame = PegLabelPlacement.frame(label: measured, point: point, preferred: -1, gap: 34,
                                                            size: size, controlsOnLeft: controlsOnLeft)
                        XCTAssertGreaterThanOrEqual(frame.minX, controlsOnLeft ? 72 : 8)
                        XCTAssertLessThanOrEqual(frame.maxX, controlsOnLeft ? 394 : 330)
                        XCTAssertGreaterThanOrEqual(frame.minY, 8)
                        XCTAssertLessThanOrEqual(frame.maxY, 292)
                        XCTAssertEqual(frame.size, measured, "The complete measured label must fit without clipping")
                    }
                }
            }
        }
    }

    func testCueMovesAbovePegWhenNeitherSideFitsItsMeasuredWidth() {
        let frame = PegLabelPlacement.frame(label: CGSize(width: 200, height: 60), point: CGPoint(x: 157, y: 150),
                                            preferred: -1, gap: 34, size: CGSize(width: 402, height: 300), controlsOnLeft: false)
        XCTAssertEqual(frame, CGRect(x: 57, y: 56, width: 200, height: 60))
    }

    func testCompactCueKeepsItsPreferredSideWhenItFits() {
        let frame = PegLabelPlacement.frame(label: CGSize(width: 60, height: 30), point: CGPoint(x: 157, y: 150),
                                            preferred: -1, gap: 34, size: CGSize(width: 402, height: 300), controlsOnLeft: false)
        XCTAssertEqual(frame, CGRect(x: 63, y: 135, width: 60, height: 30))
    }

    func testCueTriesOppositeSideBeforeMovingAboveAtEachControlBoundary() {
        let left = PegLabelPlacement.frame(label: CGSize(width: 100, height: 30), point: CGPoint(x: 200, y: 150),
                                           preferred: 1, gap: 34, size: CGSize(width: 402, height: 300), controlsOnLeft: false)
        XCTAssertEqual(left, CGRect(x: 66, y: 135, width: 100, height: 30))
        let right = PegLabelPlacement.frame(label: CGSize(width: 100, height: 30), point: CGPoint(x: 202, y: 150),
                                            preferred: -1, gap: 34, size: CGSize(width: 402, height: 300), controlsOnLeft: true)
        XCTAssertEqual(right, CGRect(x: 236, y: 135, width: 100, height: 30))
    }
}
