import XCTest
@testable import TimbreCore

/// Access: Pro from the App Store's entitlements, the free tunings, and lessons (free lessons, Pro, and the placement
/// pass: the placed unit's first lesson on the free plan).
final class AccessPolicyTests: XCTestCase {
    // MARK: Pro

    private func evidence(_ product: String, subscription: Bool = true, revoked: Bool = false, expires: Date? = nil) -> EntitlementEvidence {
        EntitlementEvidence(productID: product, isSubscription: subscription, revoked: revoked, expiresAt: expires)
    }

    func testProFollowsTheEntitlementsWhateverTheExpiryDate() {
        let now = Date()
        XCTAssertTrue(AccessPolicy.isPro([evidence(TimbreProduct.annual, expires: now.addingTimeInterval(86_400))]))
        // In the Billing Grace Period the subscription stays in the entitlements after its paid period has ended.
        XCTAssertTrue(AccessPolicy.isPro([evidence(TimbreProduct.monthly, expires: now.addingTimeInterval(-86_400))]))
        XCTAssertTrue(AccessPolicy.isPro([evidence(TimbreProduct.lifetime, subscription: false)]))
        XCTAssertTrue(AccessPolicy.isPro([evidence(TimbreProduct.annual, revoked: true), evidence(TimbreProduct.lifetime, subscription: false)]))
    }

    func testRevokedUnknownOrNoEntitlementIsNotPro() {
        XCTAssertFalse(AccessPolicy.isPro([]))
        XCTAssertFalse(AccessPolicy.isPro([evidence(TimbreProduct.annual, revoked: true)]))
        XCTAssertFalse(AccessPolicy.isPro([evidence(TimbreProduct.lifetime, subscription: false, revoked: true)]))
        XCTAssertFalse(AccessPolicy.isPro([evidence("other", subscription: false)]))
        XCTAssertFalse(AccessPolicy.isPro([evidence("other.subscription")]))
    }

    // MARK: Tunings

    func testEveryInstrumentTunesFreeInItsStandardTuning() throws {
        let catalog = try Catalog()
        XCTAssertGreaterThan(catalog.instruments.count, 50)
        for instrument in catalog.instruments {
            let standard = try XCTUnwrap(catalog.tuning(id: instrument.defaultTuningId), instrument.id)
            XCTAssertTrue(AccessPolicy.canTune(instrument: instrument, pro: false), instrument.id)
            XCTAssertTrue(AccessPolicy.canUse(tuning: standard, of: instrument, pro: false), instrument.id)
        }
    }

    func testFreeInstrumentsKeepEveryPresetAndTheirOwnTunings() throws {
        let catalog = try Catalog()
        let guitar = try XCTUnwrap(catalog.instrument(id: "guitar.acoustic.6"))
        let violin = try XCTUnwrap(catalog.instrument(id: "violin.standard.4"))
        XCTAssertTrue(guitar.isFree)
        XCTAssertTrue(AccessPolicy.canUse(tuning: try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.6.drop_d")), of: guitar, pro: false))
        XCTAssertTrue(AccessPolicy.canUse(tuning: try XCTUnwrap(catalog.tuning(id: "violin.standard.4.cross_ae")), of: violin, pro: false))
        let standard = try XCTUnwrap(catalog.tuning(id: guitar.defaultTuningId))
        let own = CustomTuning(instrumentId: guitar.id, name: "Open C", midis: [36, 43, 48, 55, 60, 64]).tuning(base: standard)
        XCTAssertTrue(AccessPolicy.canUse(tuning: own, of: guitar, pro: false))
    }

    func testOtherInstrumentsAlternateAndCustomTuningsArePro() throws {
        let catalog = try Catalog()
        let banjo = try XCTUnwrap(catalog.instrument(id: "banjo.five.5"))
        XCTAssertFalse(banjo.isFree)
        let standard = try XCTUnwrap(catalog.tuning(id: banjo.defaultTuningId))
        let alternate = try XCTUnwrap(catalog.tunings.first { $0.instrumentId == banjo.id && $0.id != banjo.defaultTuningId })
        let own = CustomTuning(instrumentId: banjo.id, name: "Sawmill", midis: standard.courses.map(\.targetMidi).map { $0 + 2 })
            .tuning(base: standard)
        XCTAssertTrue(AccessPolicy.canUse(tuning: standard, of: banjo, pro: false))
        XCTAssertFalse(AccessPolicy.canUse(tuning: alternate, of: banjo, pro: false))
        XCTAssertFalse(AccessPolicy.canUse(tuning: own, of: banjo, pro: false))
        XCTAssertTrue(AccessPolicy.canUse(tuning: alternate, of: banjo, pro: true))
        XCTAssertTrue(AccessPolicy.canUse(tuning: own, of: banjo, pro: true))
        // A tuning only ever opens on its own instrument.
        let guitar = try XCTUnwrap(catalog.instrument(id: "guitar.acoustic.6"))
        XCTAssertFalse(AccessPolicy.canUse(tuning: standard, of: guitar, pro: true))
    }

    // MARK: Lessons

    private func lesson(_ id: String, free: Bool) -> Lesson {
        Lesson(id: id, title: LearnText(id), kind: .lesson, minutes: 3, xp: 20, free: free,
               steps: [.quiz(prompt: LearnText("q"), options: [LearnText("a"), LearnText("b")], answer: 0, why: nil, visual: .none)])
    }

    private func course(_ id: String) -> LearnCourse {
        func unit(_ name: String, _ lessons: [Lesson]) -> LearnUnit { LearnUnit(id: id + name, title: LearnText(name), summary: LearnText("s"), lessons: lessons) }
        return LearnCourse(id: id, title: LearnText(id), subtitle: LearnText("s"), instrument: nil, symbol: "music.note", accent: "mint",
                           units: [unit("u1", [lesson(id + "-1-1", free: true), lesson(id + "-1-2", free: true)]),
                                   unit("u2", [lesson(id + "-2-1", free: false), lesson(id + "-2-2", free: false)]),
                                   unit("u3", [lesson(id + "-3-1", free: false)])])
    }

    func testPlacementPassOpensOnlyThePlacedFirstLesson() {
        let guitar = course("g"), ear = course("e")
        let courses = [guitar, ear]
        func open(_ progress: LearnProgress, _ id: String, pro: Bool = false) -> Bool {
            let lesson = courses.flatMap(\.lessons).first { $0.id == id }!
            return AccessPolicy.canPlay(lesson, pro: pro, progress: progress, courses: courses)
        }
        var progress = LearnProgress()

        // No placement: free lessons only; Pro opens everything.
        XCTAssertNil(AccessPolicy.placementPass(in: guitar, progress: progress))
        XCTAssertTrue(open(progress, "g-1-1"))
        XCTAssertFalse(open(progress, "g-2-1"))
        XCTAssertTrue(open(progress, "g-2-1", pro: true))

        // Placed past unit 1 of the guitar course: unit 2's first lesson is the pass, and it is the plan's first lesson.
        progress.place(level: "intermediate", in: guitar)
        XCTAssertEqual(AccessPolicy.placementPass(in: guitar, progress: progress)?.id, "g-2-1")
        XCTAssertEqual(progress.nextLesson(in: guitar)?.id, "g-2-1")
        XCTAssertTrue(open(progress, "g-2-1"))
        // Only that lesson, and only in the course that was placed.
        XCTAssertFalse(open(progress, "g-2-2"))
        XCTAssertFalse(open(progress, "g-3-1"))
        XCTAssertFalse(open(progress, "e-2-1"))
        XCTAssertTrue(open(progress, "g-1-2"), "free lessons stay free")

        // A beginner answer clears the placement and its pass.
        progress.place(level: "beginner", in: guitar)
        XCTAssertNil(AccessPolicy.placementPass(in: guitar, progress: progress))
        XCTAssertFalse(open(progress, "g-2-1"))
    }
}
