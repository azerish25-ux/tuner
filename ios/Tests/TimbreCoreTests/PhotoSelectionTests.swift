import XCTest
@testable import TimbreCore

final class PhotoSelectionTests: XCTestCase {
    func testBassVariantsFollowTuningRatherThanIncompatiblePhoto() throws {
        let catalog = try Catalog()
        for (id, four, five) in [("bass.electric.4", "4-string bass", "5-string bass"), ("bass.double.4", "4-string double bass", "5-string double bass")] {
            let fourPhoto = try XCTUnwrap(catalog.photos.first { $0.instrumentId == id && $0.label == four })
            let fivePhoto = try XCTUnwrap(catalog.photos.first { $0.instrumentId == id && $0.label == five })
            XCTAssertEqual(catalog.photo(instrumentId: id, tuningId: id + ".five", preferredAsset: fourPhoto.asset)?.label, five)
            XCTAssertEqual(catalog.photo(instrumentId: id, tuningId: id + ".standard", preferredAsset: fivePhoto.asset)?.label, four)
            XCTAssertEqual(catalog.photo(instrumentId: id, tuningId: nil, preferredAsset: fivePhoto.asset)?.label, four)
        }
    }
    func testEveryMalletRangeSelectsItsOwnPhoto() throws {
        let catalog = try Catalog()
        let wrong = try XCTUnwrap(catalog.photos.first { $0.label == "Vibraphone" })
        for (suffix, label) in [("standard", "Marimba"), ("xylophone", "Xylophone"), ("glockenspiel", "Glockenspiel"), ("vibraphone", "Vibraphone")] {
            XCTAssertEqual(catalog.photo(instrumentId: "mallet.marimba.0", tuningId: "mallet.marimba.0." + suffix, preferredAsset: wrong.asset)?.label, label)
        }
    }
    func testSharedTuningAliasesRemainSelectable() throws {
        let catalog = try Catalog()
        for (id, label) in [("ukulele.soprano.4", "Concert ukulele"), ("ukulele.soprano.4", "Tenor ukulele"), ("recorder.standard.0", "Alto recorder"), ("clarinet.bb.0", "A clarinet"), ("saxophone.standard.0", "B-flat tenor saxophone"), ("keys.accordion.0", "Concertina")] {
            let preferred = try XCTUnwrap(catalog.photos.first { $0.instrumentId == id && $0.label == label })
            XCTAssertEqual(catalog.photo(instrumentId: id, tuningId: id + ".standard", preferredAsset: preferred.asset)?.asset, preferred.asset)
        }
    }
    func testForeignUnknownAndMissingInputsNeverSelectAnotherInstrumentPhoto() throws {
        let catalog = try Catalog()
        let foreign = try XCTUnwrap(catalog.photos.first { $0.label == "Glockenspiel" })
        XCTAssertEqual(catalog.photo(instrumentId: "bass.electric.4", tuningId: "bass.double.4.five", preferredAsset: foreign.asset)?.label, "4-string bass")
        XCTAssertEqual(catalog.photo(instrumentId: "mallet.marimba.0", tuningId: "unknown", preferredAsset: foreign.asset)?.label, "Marimba")
        XCTAssertEqual(catalog.photo(instrumentId: "ukulele.soprano.4", tuningId: nil, preferredAsset: foreign.asset)?.label, "Soprano ukulele")
        XCTAssertNil(catalog.photo(instrumentId: "unknown", tuningId: nil))
    }
}
