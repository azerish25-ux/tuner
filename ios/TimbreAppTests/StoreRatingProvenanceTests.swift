import Foundation
import XCTest
@testable import Timbre

@MainActor
final class StoreRatingProvenanceTests: XCTestCase {
    private let appID = "6827721551"
    private let bundleID = "com.shahradazerisharghi.timbre"

    private func data(_ changes: [String: Any] = [:]) throws -> Data {
        var result: [String: Any] = ["trackId": Int64(6_827_721_551), "bundleId": bundleID,
                                     "averageUserRating": 4.9, "userRatingCount": 250]
        result.merge(changes) { _, new in new }
        return try JSONSerialization.data(withJSONObject: ["resultCount": 1, "results": [result]])
    }

    private func parse(_ data: Data, requestedID: String? = nil, expectedBundle: String? = nil) -> StoreRating.Line? {
        StoreRating.validatedLookup(data, appID: requestedID ?? appID,
                                    bundleID: expectedBundle ?? bundleID, storefront: "CAN")
    }

    func testMatchingRecordCarriesExactIdentityAndStorefront() throws {
        let payload = try data()
        let line = try XCTUnwrap(parse(payload))
        XCTAssertEqual(line.stars, 4.9)
        XCTAssertEqual(line.count, 250)
        XCTAssertEqual(line.appID, appID)
        XCTAssertEqual(line.bundleID, bundleID)
        XCTAssertEqual(line.storefront, "CAN")
    }

    func testWrongTrackAndBundleAreRejected() throws {
        XCTAssertNil(parse(try data(["trackId": 123])))
        XCTAssertNil(parse(try data(["bundleId": "com.other.app"])))
        XCTAssertNil(parse(try data(), requestedID: "123"))
        XCTAssertNil(parse(try data(), expectedBundle: "com.other.app"))
    }

    func testOwnerOverrideMatchesConfiguredIDNotHardcodedDefault() throws {
        let line = parse(try data(["trackId": 123]), requestedID: "123")
        XCTAssertEqual(line?.appID, "123")
        XCTAssertNil(parse(try data(["trackId": 123])))
    }

    func testUnpublishedAndMalformedLookupsHaveNoRating() throws {
        for text in [#"{"resultCount":0,"results":[]}"#, "{}", "not JSON",
                     #"{"resultCount":1,"results":[]}"#,
                     #"{"resultCount":0,"results":[{"trackId":6827721551}]}"#] {
            XCTAssertNil(parse(Data(text.utf8)))
        }
        let invalidRecords: [[String: Any]] = [["trackId": NSNull()], ["bundleId": NSNull()],
                                       ["trackId": "6827721551"], ["averageUserRating": NSNull()],
                                       ["userRatingCount": NSNull()], ["averageUserRating": 5.1],
                                       ["averageUserRating": -1], ["userRatingCount": -1]]
        for changes in invalidRecords {
            XCTAssertNil(parse(try data(changes)))
        }
    }

    func testInvalidConfigurationAndOversizedPayloadFailClosed() throws {
        for invalid in ["", "$(TIMBRE_APP_STORE_ID)", "0", "-1", "06827721551", "６８２７７２１５５１"] {
            XCTAssertNil(parse(try data(), requestedID: invalid))
        }
        XCTAssertNil(StoreRating.validatedLookup(try data(), appID: appID, bundleID: nil, storefront: "CAN"))
        XCTAssertNil(parse(try data(), expectedBundle: ""))
        XCTAssertNil(parse(Data(repeating: 32, count: 256_001)))
    }

    func testOldUnboundRatingCacheCannotBecomeSocialProof() {
        let old = Data(#"{"stars":4.9,"count":250,"storefront":"CAN"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(StoreRating.Line.self, from: old))
    }
    func testCachedRatingRequiresKnownMatchingCurrentStorefront() throws {
        let payload = try data()
        let cached = try XCTUnwrap(parse(payload))
        XCTAssertNil(StoreRating.matchingStorefront(cached, currentStorefront: nil))
        XCTAssertNil(StoreRating.matchingStorefront(cached, currentStorefront: ""))
        XCTAssertEqual(StoreRating.matchingStorefront(cached, currentStorefront: "CAN"), cached)
        XCTAssertNil(StoreRating.matchingStorefront(cached, currentStorefront: "USA"))
        XCTAssertNil(StoreRating.matchingStorefront(nil, currentStorefront: "CAN"))
        // Cache remains available: returning to its storefront can show it without a fetch.
        XCTAssertEqual(StoreRating.matchingStorefront(cached, currentStorefront: "CAN"), cached)
    }

    func testInvalidCachedRatingsAndIdentitiesAreRejected() {
        func cached(stars: Double = 4.9, count: Int = 250) -> StoreRating.Line {
            StoreRating.Line(stars: stars, count: count, storefront: "CAN", appID: appID, bundleID: bundleID)
        }
        XCTAssertTrue(StoreRating.validCachedLine(cached(), appID: appID, bundleID: bundleID))
        for stars in [Double.nan, Double.infinity, -Double.infinity, -0.1, 5.1] {
            XCTAssertFalse(StoreRating.validCachedLine(cached(stars: stars), appID: appID, bundleID: bundleID))
        }
        XCTAssertTrue(StoreRating.validCachedLine(cached(count: 0), appID: appID, bundleID: bundleID))
        XCTAssertFalse(StoreRating.validCachedLine(cached(count: -1), appID: appID, bundleID: bundleID))
        XCTAssertFalse(StoreRating.validCachedLine(cached(), appID: "123", bundleID: bundleID))
        XCTAssertFalse(StoreRating.validCachedLine(cached(), appID: appID, bundleID: "com.other.app"))
        XCTAssertFalse(StoreRating.validCachedLine(cached(), appID: nil, bundleID: bundleID))
        XCTAssertFalse(StoreRating.validCachedLine(cached(), appID: appID, bundleID: nil))
    }

}
