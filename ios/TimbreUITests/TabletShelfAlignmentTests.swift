import XCTest

final class TabletShelfAlignmentTests: XCTestCase {
    private func accepts(_ top: CGFloat, _ bottom: CGFloat, cardsTop: CGFloat = 400, cardsBottom: CGFloat = 900) -> Bool {
        TabletShelfAlignment.accepts(cardsTop: cardsTop, cardsBottom: cardsBottom,
                                     headingTop: top, headingBottom: bottom, clearTop: 96, hiddenBottom: 64, foot: 960)
    }
    func testOnlyFullyClearOrFullyHiddenHeadingPasses() {
        XCTAssertTrue(accepts(96, 120))
        XCTAssertTrue(accepts(40, 64))
        XCTAssertFalse(accepts(80, 104))
        XCTAssertFalse(accepts(50, 74))
        XCTAssertFalse(accepts(70, 90)) // wholly within shade is not wholly hidden
    }
    func testThreeCardBoundsAreNeverWeakened() {
        XCTAssertFalse(accepts(40, 60, cardsTop: 95))
        XCTAssertFalse(accepts(100, 120, cardsBottom: 961))
    }
    func testCorrectionUsesFeasibleClearOrHiddenPosition() {
        for bottom: CGFloat in [900, 959] {
            let move = TabletShelfAlignment.correction(cardsTop: 400, cardsBottom: bottom,
                                                       headingTop: 80, headingBottom: 104,
                                                       clearTop: 96, hiddenBottom: 64, foot: 960)
            XCTAssertNotNil(move)
            if let move {
                XCTAssertTrue(accepts(80 - move, 104 - move, cardsTop: 400 - move, cardsBottom: bottom - move))
                if bottom == 959 { XCTAssertGreaterThan(move, 0) } // cannot reveal heading by clipping bottom cards
            }
        }
    }
    func testImpossibleAndInvalidGeometryFailsClosed() {
        XCTAssertNil(TabletShelfAlignment.correction(cardsTop: 98, cardsBottom: 959, headingTop: 80, headingBottom: 104,
                                                      clearTop: 96, hiddenBottom: 64, foot: 960))
        XCTAssertFalse(accepts(.nan, 100))
        XCTAssertFalse(accepts(100, .infinity))
        XCTAssertFalse(accepts(100, 90))
    }
}
