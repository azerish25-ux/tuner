import XCTest
@testable import TimbreCore

final class CatalogTests: XCTestCase {
    func testCompleteCatalogAndDefaults() throws {
        let catalog = try Catalog()
        XCTAssertEqual(catalog.instruments.count, 60)
        XCTAssertEqual(catalog.families.count, 8)
        XCTAssertEqual(catalog.tunings.count, 102)
        XCTAssertEqual(catalog.instruments.filter(\.isAdjustable).count, 14)
        for instrument in catalog.instruments {
            let tuning = try XCTUnwrap(catalog.tuning(id: instrument.defaultTuningId))
            XCTAssertEqual(tuning.instrumentId, instrument.id)
            XCTAssertTrue(tuning.isDefault)
            XCTAssertFalse(tuning.courses.isEmpty)
            XCTAssertNotNil(catalog.photo(instrumentId: instrument.id))
        }
    }
    func testTwelveStringOctavePartnersAreRetained() throws {
        let catalog = try Catalog()
        let tuning = try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.12.standard"))
        XCTAssertEqual(tuning.courses.count, 12)
        XCTAssertTrue(tuning.courses.contains { $0.targetMidi == 40 })
        XCTAssertTrue(tuning.courses.contains { $0.targetMidi == 52 })
    }
    func testReferenceAndNoteSystems() {
        XCTAssertEqual(PitchMath.frequency(midi: 69), 440, accuracy: 1e-9)
        XCTAssertEqual(PitchMath.frequency(midi: 69, reference: 432), 432, accuracy: 1e-9)
        XCTAssertEqual(PitchMath.midi(frequency: 880), 81, accuracy: 1e-9)
        XCTAssertEqual(PitchMath.cents(target: 440, measured: 880), 1200, accuracy: 1e-9)
        XCTAssertEqual(PitchMath.noteName(midi: 69), "A4")
        XCTAssertEqual(PitchMath.noteName(midi: 61, notation: "solfege"), "Do#4")
        XCTAssertEqual(PitchMath.noteName(midi: -1), "B-2")
        XCTAssertEqual(PitchMath.parseNote("Bb3"), 58)
        XCTAssertEqual(PitchMath.noteName(midi: 69, notation: "sargam"), "Dha4")
        XCTAssertEqual(PitchMath.noteName(midi: 69, notation: "numbered"), "64")
    }
    func testShippedTemperamentLetterRule() {
        XCTAssertEqual(Temperament.all.count, 5)
        XCTAssertEqual(Temperament.pythagorean.offsetCents(midi: 60), -6)
        XCTAssertEqual(Temperament.pythagorean.offsetCents(midi: 61), 6)
        XCTAssertEqual(Temperament.pythagorean.offsetCents(midi: 61, letterName: "Db"), -2)
        XCTAssertEqual(Temperament.just.frequency(midi: 69), 440, accuracy: 1e-9)
        XCTAssertEqual(Temperament.byId("unknown"), .equal)
    }
}
