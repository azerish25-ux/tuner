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

    /// The yearly price-test arms the remote settings can sell grant Pro like the standard year.
    func testYearlyTestArmsGrantPro() {
        XCTAssertEqual(TimbreProduct.yearly, [TimbreProduct.annual, TimbreProduct.annualB, TimbreProduct.annualC])
        for product in TimbreProduct.yearly + [TimbreProduct.monthly] {
            XCTAssertTrue(TimbreProduct.all.contains(product), product)
            XCTAssertTrue(TimbreProduct.subscriptions.contains(product), product)
            XCTAssertTrue(AccessPolicy.isPro([evidence(product)]), product)
            XCTAssertFalse(AccessPolicy.isPro([evidence(product, revoked: true)]), product)
        }
        XCTAssertFalse(TimbreProduct.subscriptions.contains(TimbreProduct.lifetime))
        XCTAssertEqual(Set(TimbreProduct.all).count, TimbreProduct.all.count)
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

    /// The remote settings' openings: `unit2Free` opens every teaching course's second unit and nothing past it;
    /// `freeSongs` opens the lessons it lists. Without them only the free lessons open.
    func testRemoteOpeningsOpenUnitTwoAndListedSongs() {
        let guitar = course("g")
        let songbook = LearnCourse(id: "sb", title: LearnText("sb"), subtitle: LearnText("s"), instrument: nil, symbol: "music.note", accent: "mint",
                                   units: [LearnUnit(id: "sb1", title: LearnText("1"), summary: LearnText("s"), lessons: [song("sb-1", free: true)]),
                                           LearnUnit(id: "sb2", title: LearnText("2"), summary: LearnText("s"), lessons: [song("sb-2", free: false)])])
        let courses = [guitar, songbook]
        func open(_ id: String, _ openings: FreeOpenings) -> Bool {
            let lesson = courses.flatMap(\.lessons).first { $0.id == id }!
            return AccessPolicy.canPlay(lesson, pro: false, progress: LearnProgress(), courses: courses, openings: openings)
        }
        XCTAssertFalse(open("g-2-1", .none))
        XCTAssertFalse(open("g-3-1", .none))

        let unit2 = FreeOpenings(unit2: true)
        XCTAssertTrue(open("g-2-1", unit2))
        XCTAssertTrue(open("g-2-2", unit2))
        XCTAssertFalse(open("g-3-1", unit2), "only the second unit")
        XCTAssertFalse(open("sb-2", unit2), "a song collection's shelves aren't units of a course")

        let songs = FreeOpenings(lessons: ["g-3-1", "sb-2"])
        XCTAssertTrue(open("g-3-1", songs))
        XCTAssertTrue(open("sb-2", songs))
        XCTAssertFalse(open("g-2-1", songs))
    }

    // MARK: The paywall's Free and Pro table

    /// Every row of the table says what the rules it is built from say, so it can't drift from the free tier.
    func testFreeAndProTableMatchesThePolicy() throws {
        let catalog = try Catalog()
        let curriculum = try Curriculum.bundled()
        let rows = PlanComparison.rows(catalog: catalog, curriculum: curriculum, openings: .none)
        XCTAssertEqual(rows.map(\.id), PlanComparison.Row.Kind.allCases)
        func row(_ kind: PlanComparison.Row.Kind) throws -> PlanComparison.Row { try XCTUnwrap(rows.first { $0.id == kind }) }

        // Lessons: the courses' free teaching lessons, against every teaching lesson.
        let teaching = curriculum.courses.filter { !$0.isSongbook }.flatMap(\.lessons)
        XCTAssertEqual(try row(.lessons).free, .count(teaching.filter(\.free).count))
        XCTAssertEqual(try row(.lessons).pro, .count(curriculum.lessonCount))
        XCTAssertGreaterThan(teaching.filter(\.free).count, 0)

        // Every tuning (presets and the player's own): exactly the catalogue's free instruments, against all of them.
        let everyTuning = PlanComparison.everyTuningFree(catalog)
        XCTAssertEqual(Set(everyTuning.map(\.id)), Set(catalog.instruments.filter(\.isFree).map(\.id)))
        XCTAssertEqual(Set(everyTuning.map(\.id)), ["guitar.acoustic.6", "bass.electric.4", "ukulele.soprano.4", "violin.standard.4", "cello.standard.4"])
        XCTAssertEqual(try row(.everyTuning).free, .count(everyTuning.count))
        XCTAssertEqual(try row(.everyTuning).pro, .count(catalog.instruments.count))

        // Custom tunings: one free, unlimited with Pro.
        XCTAssertTrue(FreeTier.canAddCustomTuning(saved: 0, pro: false))
        XCTAssertFalse(FreeTier.canAddCustomTuning(saved: 1, pro: false))
        XCTAssertEqual(try row(.customTunings).free, .count(1))
        XCTAssertEqual(try row(.customTunings).pro, .unlimited)

        // Open chords with Check are free; barre shapes, scales, intonation and the drone are Pro, all of them.
        let standard = ChordLibrary.standardGuitar
        let eMinor = ChordShape(frets: [0, 2, 2, 0, 0, 0], score: 0)
        let fBarre = ChordShape(frets: [1, 3, 3, 2, 1, 1], score: 0)
        XCTAssertTrue(FreeTier.canUseVoicing(eMinor, root: 4, formula: ChordFormula.byId("min"), openMidi: standard, pro: false))
        XCTAssertFalse(FreeTier.canUseVoicing(fBarre, root: 5, formula: ChordFormula.byId("maj"), openMidi: standard, pro: false))
        XCTAssertTrue(FreeTier.opens(.chords))
        XCTAssertEqual(try row(.openChords).free, .included)
        XCTAssertEqual(try row(.openChords).pro, .included)
        XCTAssertFalse(FreeTier.opens(.scales) || FreeTier.opens(.intonation) || FreeTier.opens(.drone),
                       "the practice-tools row needs all four in one plan")
        XCTAssertEqual(try row(.practiceTools).free, .excluded)

        // Strobe and temperaments, naming by ear: Pro. The metronome's basics and Bullseye: free.
        XCTAssertFalse(FreeTier.opens(.strobe) || FreeTier.opens(.temperaments))
        XCTAssertEqual(try row(.strobe).free, .excluded)
        XCTAssertTrue(FreeTier.opens(.metronome) && FreeTier.opens(.bullseye))
        XCTAssertEqual(try row(.metronome).free, .included)
        XCTAssertFalse(FreeTier.opens(.earNaming))
        XCTAssertEqual(try row(.earNaming).free, .excluded)

        // Your songs: ten charts free, unlimited with Pro; slowing down, looping and chord finding are Pro.
        XCTAssertEqual(try row(.charts).free, .count(YourSongsPolicy.freeChartLimit))
        XCTAssertEqual(try row(.charts).pro, .unlimited)
        XCTAssertFalse(YourSongsPolicy.canSlowDownAndLoop(pro: false))
        XCTAssertEqual(try row(.recordingTools).free, .excluded)

        // Pro opens every row.
        XCTAssertTrue(rows.allSatisfy { $0.pro != .excluded })
    }

    /// The lessons row counts what the remote settings open too.
    func testTheTableCountsUnitTwoWhenItIsFree() throws {
        let catalog = try Catalog()
        let curriculum = try Curriculum.bundled()
        let closed = PlanComparison.freeLessons(curriculum, openings: .none).count
        let open = PlanComparison.freeLessons(curriculum, openings: FreeOpenings(unit2: true)).count
        let secondUnits = curriculum.courses.filter { !$0.isSongbook && $0.units.count > 1 }.flatMap { $0.units[1].lessons }
        XCTAssertEqual(open, closed + secondUnits.filter { !$0.free }.count)
        let row = try XCTUnwrap(PlanComparison.rows(catalog: catalog, curriculum: curriculum, openings: FreeOpenings(unit2: true)).first)
        XCTAssertEqual(row.free, .count(open))
    }

    private func song(_ id: String, free: Bool) -> Lesson {
        Lesson(id: id, title: LearnText(id), kind: .song, minutes: 3, xp: 20, free: free,
               steps: [.quiz(prompt: LearnText("q"), options: [LearnText("a"), LearnText("b")], answer: 0, why: nil, visual: .none)])
    }
}
