import XCTest
@testable import TimbreCore

final class CatalogTests: XCTestCase {
    func testCompleteCatalogAndDefaults() throws {
        let catalog = try Catalog()
        XCTAssertEqual(catalog.instruments.count, 60)
        XCTAssertEqual(catalog.families.count, 8)
        XCTAssertEqual(catalog.tunings.count, 132)
        XCTAssertEqual(catalog.instruments.filter(\.isAdjustable).count, 14)
        for instrument in catalog.instruments {
            let tuning = try XCTUnwrap(catalog.tuning(id: instrument.defaultTuningId))
            XCTAssertEqual(tuning.instrumentId, instrument.id)
            XCTAssertTrue(tuning.isDefault)
            XCTAssertFalse(tuning.courses.isEmpty)
            XCTAssertNotNil(catalog.photo(instrumentId: instrument.id))
        }
    }
    /// The preset library a "best free tuner" review checks: 24 guitar tunings (the drops, the lower standards, the
    /// open majors and cross-note minors, Nashville, lute and all fourths), and more for bass, ukulele, mandolin,
    /// violin and banjo. Each preset tunes the strings of its instrument's standard tuning, and each string's label
    /// spells the pitch it tunes to.
    func testPresetTuningsCoverTheirInstrumentsStrings() throws {
        let catalog = try Catalog()
        let guitar = try XCTUnwrap(catalog.instrument(id: "guitar.acoustic.6"))
        XCTAssertGreaterThanOrEqual(guitar.supportedTuningIds.count, 22)
        func midis(_ id: String) -> [Int]? { catalog.tuning(id: id)?.courses.sorted { $0.index < $1.index }.map(\.targetMidi) }
        XCTAssertEqual(midis("guitar.acoustic.6.drop_c"), [36, 43, 48, 53, 57, 62])
        XCTAssertEqual(midis("guitar.acoustic.6.open_c"), [36, 43, 48, 55, 60, 64])
        XCTAssertEqual(midis("guitar.acoustic.6.open_e"), [40, 47, 52, 56, 59, 64])
        XCTAssertEqual(midis("guitar.acoustic.6.nashville"), [52, 57, 62, 67, 59, 64])
        XCTAssertEqual(midis("bass.electric.4.bead"), [23, 28, 33, 38])
        XCTAssertEqual(midis("violin.standard.4.high_bass"), [57, 62, 69, 76])
        let counts = ["bass.electric.4": 7, "ukulele.soprano.4": 5, "mandolin.standard.8": 3, "violin.standard.4": 5, "banjo.five.5": 4]
        for (id, count) in counts {
            XCTAssertEqual(catalog.instrument(id: id)?.supportedTuningIds.count, count, id)
        }
        for id in ["guitar.acoustic.6", "ukulele.soprano.4", "mandolin.standard.8", "violin.standard.4", "banjo.five.5"] {
            let instrument = try XCTUnwrap(catalog.instrument(id: id))
            let standard = try XCTUnwrap(catalog.tuning(id: instrument.defaultTuningId))
            let strings = standard.courses.sorted { $0.index < $1.index }.map(\.anchorId)
            for tuningId in instrument.supportedTuningIds {
                let tuning = try XCTUnwrap(catalog.tuning(id: tuningId))
                XCTAssertEqual(tuning.courses.sorted { $0.index < $1.index }.map(\.anchorId), strings, tuningId)
                for course in tuning.courses {
                    XCTAssertEqual(PitchMath.parseNote(course.label), course.targetMidi, "\(tuningId) \(course.label)")
                    let hz = PitchMath.frequency(midi: Double(course.targetMidi))
                    XCTAssertTrue(hz >= instrument.minFrequencyHz - 0.01 && hz <= instrument.maxFrequencyHz + 0.01, "\(tuningId) \(course.label)")
                }
            }
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
