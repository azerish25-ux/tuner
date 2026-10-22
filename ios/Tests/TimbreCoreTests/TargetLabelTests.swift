import XCTest
@testable import TimbreCore

final class TargetLabelTests: XCTestCase {
    func testPhysicalAndRelativeCuesSurvive() {
        XCTAssertEqual(TargetLabelFormatter.display(label: "C4 (+1)", midi: 60), "C4 (+1)")
        XCTAssertEqual(TargetLabelFormatter.display(label: "D4 (-1)", midi: 62, notation: "solfege"), "Re4 (-1)")
        XCTAssertEqual(TargetLabelFormatter.display(label: "Sa (8va)", midi: 61), "Sa (8va)")
        XCTAssertEqual(TargetLabelFormatter.splitCue("Chikari Sa (7)").cue, "7")
        XCTAssertEqual(TargetLabelFormatter.splitCue("Sa (8va)").main, "Sa")
    }
    func testFlatsAndDisplayShiftsMatchSource() {
        XCTAssertEqual(TargetLabelFormatter.display(label: "Bb3 (main slide)", midi: 58), "Bb3")
        XCTAssertEqual(TargetLabelFormatter.display(label: "C4 (+1)", midi: 60, transposition: 2), "D4 (+1)")
        XCTAssertEqual(TargetLabelFormatter.display(label: "Low drum (set per piece)", midi: 38), "Low drum (set per piece)")
    }
}
