import XCTest
@testable import TimbreCore

final class CourseGroupTests: XCTestCase {
    func testMandolinPairsTuneAsFourCourses() throws {
        let catalog = try Catalog()
        let mandolin = try XCTUnwrap(catalog.tuning(id: "mandolin.standard.8.standard"))
        let groups = CourseGrouping.groups(mandolin.courses)
        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(groups.map(\.id), [1, 3, 5, 7])
        XCTAssertTrue(groups.allSatisfy { $0.count == 2 })
        XCTAssertEqual(groups.map(\.lead.label), ["G3", "D4", "A4", "E5"])
    }

    func testOctavePartnersKeepAChipEach() throws {
        let catalog = try Catalog()
        // The 12-string's low four courses are octave pairs (different notes); its B and E courses are unisons.
        let twelve = try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.12.standard"))
        let groups = CourseGrouping.groups(twelve.courses)
        XCTAssertEqual(groups.count, 10)
        XCTAssertEqual(groups.filter { $0.count == 2 }.map(\.lead.label), ["B3", "E4"])
        let guitar = try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.6.standard"))
        XCTAssertEqual(CourseGrouping.groups(guitar.courses).count, 6)
        // Courses without an anchor never merge, even on the same note (harmonica blow 3 and draw 2).
        let piano = try XCTUnwrap(catalog.tuning(id: "keys.piano.0.standard"))
        XCTAssertEqual(CourseGrouping.groups(piano.courses).count, piano.courses.count)
        let harmonica = try XCTUnwrap(catalog.tuning(id: "harmonica.diatonic.0.standard"))
        XCTAssertEqual(CourseGrouping.groups(harmonica.courses).count, harmonica.courses.count)
    }

    func testAPairLocksOnlyOnceBothStringsHave() {
        let pair = CourseGroup(courses: [Course(index: 1, targetMidi: 55, label: "G3", anchorId: "c4"),
                                         Course(index: 2, targetMidi: 55, label: "G3", anchorId: "c4")])
        XCTAssertFalse(pair.isTuned([]))
        XCTAssertEqual(pair.nextToTune([]).index, 1)
        XCTAssertEqual(pair.partner(after: 1, locked: [1])?.index, 2)
        XCTAssertFalse(pair.isTuned([1]))
        XCTAssertEqual(pair.lockedCount([1]), 1)
        XCTAssertEqual(pair.nextToTune([1]).index, 2)
        // The second string first: the partner wraps round to the first.
        XCTAssertEqual(pair.partner(after: 2, locked: [2])?.index, 1)
        XCTAssertTrue(pair.isTuned([1, 2, 3]))
        XCTAssertNil(pair.partner(after: 2, locked: [1, 2]))
        XCTAssertEqual(pair.nextToTune([1, 2]).index, 1)
        XCTAssertNil(pair.partner(after: 9, locked: []))
        let single = CourseGroup(courses: [Course(index: 3, targetMidi: 62, label: "D4", anchorId: "c3")])
        XCTAssertNil(single.partner(after: 3, locked: [3]))
    }

    func testPegsOfAPairResolveToTheirOwnString() throws {
        let catalog = try Catalog()
        let courses = try XCTUnwrap(catalog.tuning(id: "mandolin.standard.8.standard")).courses
        let second = try XCTUnwrap(courses.first(where: { $0.index == 2 }))
        XCTAssertEqual(CourseGrouping.position(of: second, in: courses), 1)
        let seventh = try XCTUnwrap(courses.first(where: { $0.index == 7 }))
        XCTAssertEqual(CourseGrouping.position(of: seventh, in: courses), 0)
        XCTAssertEqual(CourseGrouping.course(forPeg: "c4", in: courses)?.index, 1)
        XCTAssertEqual(CourseGrouping.course(forPeg: "c4a", in: courses)?.index, 1)
        XCTAssertEqual(CourseGrouping.course(forPeg: "c4b", in: courses)?.index, 2)
        XCTAssertEqual(CourseGrouping.course(forPeg: "c1b", in: courses)?.index, 8)
        XCTAssertNil(CourseGrouping.course(forPeg: "c4c", in: courses))
        XCTAssertNil(CourseGrouping.course(forPeg: "s3", in: courses))
        XCTAssertEqual(CourseGrouping.pegLetter(0), "a")
        XCTAssertEqual(CourseGrouping.pegLetter(1), "b")
        XCTAssertNil(CourseGrouping.pegLetter(-1))
    }
}
