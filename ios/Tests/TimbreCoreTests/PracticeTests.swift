import XCTest
@testable import TimbreCore

final class PracticeTests: XCTestCase {
    private let guitar = [40, 45, 50, 55, 59, 64]
    private let ukulele = [67, 60, 64, 69]

    func testChordFinderFindsStandardOpenShapes() {
        func top(_ root: Int, _ id: String, _ tuning: [Int]) -> [String] {
            ChordFinder.shapes(root: root, formula: .byId(id), openMidi: tuning, limit: 4).map(\.notation)
        }
        XCTAssertEqual(top(0, "maj", guitar).first, "x32010")
        XCTAssertTrue(top(7, "maj", guitar).contains { $0 == "320003" || $0 == "320033" || $0 == "320003" })
        XCTAssertEqual(top(4, "maj", guitar).first, "022100")
        XCTAssertEqual(top(9, "min", guitar).first, "x02210")
        XCTAssertTrue(top(2, "maj", guitar).contains("xx0232"))
        XCTAssertEqual(top(0, "maj", ukulele).first, "0003")
    }

    func testEveryChordShapeContainsOnlyChordTonesWithRootInBass() {
        for formula in ChordFormula.all {
            for root in 0..<12 {
                for shape in ChordFinder.shapes(root: root, formula: formula, openMidi: guitar) {
                    let pitches = shape.frets.enumerated().compactMap { i, f in f.map { guitar[i] + $0 } }
                    let tones = Set(formula.intervals.map { (root + $0) % 12 })
                    XCTAssertTrue(Set(pitches.map { $0 % 12 }).isSubset(of: tones), "\(formula.id) \(root) \(shape.notation)")
                    XCTAssertEqual(pitches.min()! % 12, root, "\(formula.id) \(root) \(shape.notation)")
                    XCTAssertLessThan(shape.highestFret - shape.lowestFret, 4)
                }
            }
        }
    }

    func testScaleMapMarksRootsAndDegrees() {
        let positions = ScaleMap.positions(root: 9, scale: ScaleFormula.all.first { $0.id == "pent_minor" }!, openMidi: guitar, frets: 5...8)
        XCTAssertTrue(positions.contains { $0.string == 0 && $0.fret == 5 && $0.isRoot })
        XCTAssertTrue(positions.allSatisfy { (1...5).contains($0.degree) })
        XCTAssertEqual(positions.filter(\.isRoot).count, 3)
    }

    func testEarSessionLevelsUpAndBackDeterministically() {
        var session = EarSession(drill: .pitchDirection, seed: 1)
        var first = session.next()
        XCTAssertEqual(abs(first.cents ?? 0), 50)
        for _ in 0..<3 { first = session.next(); session.answer(first.answer, for: first) }
        XCTAssertEqual(session.level, 1)
        let q = session.next()
        XCTAssertEqual(abs(q.cents ?? 0), 35)
        session.answer(q.answer == "Higher" ? "Lower" : "Higher", for: q)
        XCTAssertEqual(session.level, 0)
        XCTAssertEqual(session.accuracy, 75)
        var a = EarSession(drill: .interval, seed: 9), b = EarSession(drill: .interval, seed: 9)
        XCTAssertEqual(a.next(), b.next())
        var chords = EarSession(drill: .chordQuality, seed: 3)
        let chord = chords.next()
        XCTAssertTrue(chord.simultaneous)
        XCTAssertTrue(chord.choices.contains(chord.answer))
    }

    func testStreaksCountConsecutiveDaysAndSurviveUntilTonight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_800_000_000) // midday UTC
        func record(_ daysAgo: Int) -> PracticeRecord {
            PracticeRecord(date: now.addingTimeInterval(-Double(daysAgo) * 86400), instrumentId: "guitar.acoustic.6", kind: "tuning", count: 1, stableCount: 1, durationMs: 120_000)
        }
        let yesterdayRun = Streaks.summary(records: [record(1), record(2), record(3), record(6), record(7)], now: now, calendar: calendar)
        XCTAssertEqual(yesterdayRun.current, 3)
        XCTAssertFalse(yesterdayRun.practicedToday)
        XCTAssertEqual(yesterdayRun.best, 3)
        let today = Streaks.summary(records: [record(0), record(1)], now: now, calendar: calendar)
        XCTAssertEqual(today.current, 2)
        XCTAssertTrue(today.practicedToday)
        XCTAssertEqual(today.totalMinutes, 4)
        XCTAssertEqual(Streaks.summary(records: [record(2)], now: now, calendar: calendar).current, 0)
    }

    func testStreakFreezesBridgeAGapWithoutAddingToTheRun() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func day(_ daysAgo: Int) -> Date { calendar.startOfDay(for: now.addingTimeInterval(-Double(daysAgo) * 86400)) }
        func record(_ daysAgo: Int) -> PracticeRecord {
            PracticeRecord(date: day(daysAgo).addingTimeInterval(3600), instrumentId: "guitar.acoustic.6", kind: "tuning", count: 1, stableCount: 1, durationMs: 60_000)
        }
        // Practised 5, 4 and 3 days ago; missed 2 and 1.
        let records = [record(5), record(4), record(3)]
        XCTAssertEqual(Streaks.summary(records: records, now: now, calendar: calendar).current, 0)
        XCTAssertEqual(StreakFreeze.daysToCover(records: records, frozen: [], available: 1, now: now, calendar: calendar), [], "one freeze can't cover two days")
        let cover = StreakFreeze.daysToCover(records: records, frozen: [], available: 2, now: now, calendar: calendar)
        XCTAssertEqual(cover, [day(2), day(1)])
        let saved = Streaks.summary(records: records, frozen: Set(cover), now: now, calendar: calendar)
        XCTAssertEqual(saved.current, 3, "frozen days keep the run but don't add to it")
        XCTAssertEqual(Streaks.summary(records: records + [record(0)], frozen: Set(cover), now: now, calendar: calendar).current, 4)
        // Nothing to cover when yesterday was practised.
        XCTAssertEqual(StreakFreeze.daysToCover(records: [record(1)], frozen: [], available: 2, now: now, calendar: calendar), [])
        // Earned on the seventh day, once.
        let week = Streaks.summary(records: (0..<7).map(record), now: now, calendar: calendar)
        XCTAssertTrue(StreakFreeze.earnsFreeze(summary: week, banked: 0, lastAwardDay: nil, todayKey: "d"))
        XCTAssertFalse(StreakFreeze.earnsFreeze(summary: week, banked: 0, lastAwardDay: "d", todayKey: "d"))
        XCTAssertFalse(StreakFreeze.earnsFreeze(summary: week, banked: StreakFreeze.cap, lastAwardDay: nil, todayKey: "d"))
    }

    func testDailySetStartsWithTuneAndHasNoDuplicates() throws {
        let catalog = try Catalog()
        let guitar = try XCTUnwrap(catalog.instrument(id: "guitar.acoustic.6"))
        for goal in [nil, "voice", "ear", "rhythm", "practice"] {
            let set = DailySet.activities(instrument: guitar, goal: goal)
            XCTAssertEqual(set.first?.kind, .tune)
            XCTAssertEqual(Set(set.map(\.kind)).count, set.count)
            XCTAssertGreaterThanOrEqual(set.reduce(0) { $0 + $1.minutes }, 7)
            // Without Pro the set has no Pro tool, keeps its length and can always be finished.
            let free = DailySet.activities(instrument: guitar, goal: goal, pro: false)
            XCTAssertTrue(free.allSatisfy { !DailySet.proKinds.contains($0.kind) })
            XCTAssertEqual(free.reduce(0) { $0 + $1.minutes }, set.reduce(0) { $0 + $1.minutes })
            XCTAssertEqual(free.first?.kind, .tune)
        }
    }

    func testTodayOpensWithTheNextLessonThenTwoToolReps() throws {
        let catalog = try Catalog()
        let guitar = try XCTUnwrap(catalog.instrument(id: "guitar.acoustic.6"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        for offset in 0..<8 {
            let date = Date(timeIntervalSince1970: 1_800_000_000 + Double(offset) * 86_400)
            for goal in [nil, "voice", "ear", "rhythm"] {
                for pro in [true, false] {
                    let set = DailySet.activities(instrument: guitar, goal: goal, pro: pro, lessonMinutes: 5, date: date, calendar: calendar)
                    XCTAssertEqual(set.map(\.kind).first, .lesson)
                    XCTAssertEqual(set.count, 3, "the lesson and two tool reps")
                    XCTAssertEqual(set[1].kind, .tune)
                    XCTAssertFalse(set[2].isLearn)
                    XCTAssertEqual(Set(set.map(\.kind)).count, set.count)
                    XCTAssertEqual(set.reduce(0) { $0 + $1.minutes }, 10)
                    if !pro { XCTAssertTrue(set.allSatisfy { !DailySet.proKinds.contains($0.kind) }) }
                    // Stable all day.
                    XCTAssertEqual(set, DailySet.activities(instrument: guitar, goal: goal, pro: pro, lessonMinutes: 5, date: date.addingTimeInterval(3 * 3600), calendar: calendar))
                }
            }
        }
        // The lesson keeps a sensible share of the ring; a due review joins right after it.
        XCTAssertEqual(DailySet.activities(instrument: guitar, goal: nil, lessonMinutes: 40).first?.minutes, DailySet.lessonMinutes.upperBound)
        XCTAssertEqual(DailySet.activities(instrument: guitar, goal: nil, lessonMinutes: 1).first?.minutes, DailySet.lessonMinutes.lowerBound)
        let withReview = DailySet.activities(instrument: guitar, goal: nil, lessonMinutes: 5, reviewMinutes: 3)
        XCTAssertEqual(Array(withReview.map(\.kind).prefix(3)), [.lesson, .review, .tune])
        XCTAssertEqual(withReview.count, 4)
        // The tools fill out the player's daily commitment.
        XCTAssertEqual(DailySet.activities(instrument: guitar, goal: nil, lessonMinutes: 5, target: 15).reduce(0) { $0 + $1.minutes }, 15)
        XCTAssertEqual(DailySet.activities(instrument: guitar, goal: nil, target: 15).reduce(0) { $0 + $1.minutes }, 15)
        XCTAssertTrue(DailySet.activities(instrument: guitar, goal: nil, lessonMinutes: 5, target: 5).allSatisfy { $0.minutes >= 1 })
        // The goal's tool turns up on some days, another tool on others.
        let days = (0..<8).map { DailySet.activities(instrument: guitar, goal: "voice", lessonMinutes: 5, date: Date(timeIntervalSince1970: 1_800_000_000 + Double($0) * 86_400), calendar: calendar)[2].kind }
        XCTAssertTrue(days.contains(.voice))
        XCTAssertGreaterThan(Set(days).count, 1)
    }

    func testQuestsForTheSamePracticeRideOnTodaysRows() {
        let quests = [Quest(kind: .tuneAll, target: 1, xp: 20), Quest(kind: .earCorrect, target: 10, xp: 20), Quest(kind: .bullseyes, target: 5, xp: 25)]
        let set = [DailyActivity(kind: .lesson, minutes: 5), DailyActivity(kind: .tune, minutes: 1), DailyActivity(kind: .ear, minutes: 4)]
        XCTAssertEqual(DailySet.quest(for: .tune, in: quests)?.kind, .tuneAll)
        XCTAssertEqual(DailySet.quest(for: .ear, in: quests)?.kind, .earCorrect)
        XCTAssertNil(DailySet.quest(for: .lesson, in: quests))
        XCTAssertEqual(DailySet.sideQuests(quests, beside: set).map(\.kind), [.bullseyes])
        // Without ear training today, its quest stands on its own.
        let noEar = [DailyActivity(kind: .tune, minutes: 1), DailyActivity(kind: .rhythm, minutes: 4)]
        XCTAssertEqual(DailySet.sideQuests(quests, beside: noEar).map(\.kind), [.earCorrect, .bullseyes])
        XCTAssertEqual(Quest(kind: .lessons, target: 2, xp: 30).dailyKind, .lesson)
        XCTAssertNil(Quest(kind: .practiceMinutes, target: 5, xp: 15).dailyKind)
    }

    func testAccessPolicy() throws {
        let catalog = try Catalog()
        let guitar = try XCTUnwrap(catalog.instrument(id: "guitar.acoustic.6"))
        let violin = try XCTUnwrap(catalog.instrument(id: "violin.standard.4"))
        let dropD = try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.6.drop_d"))
        XCTAssertTrue(AccessPolicy.canUse(tuning: dropD, of: guitar, pro: false), "Every preset of a free instrument is free")
        XCTAssertFalse(AccessPolicy.canTune(instrument: violin, pro: false))
        XCTAssertTrue(AccessPolicy.canTune(instrument: violin, pro: true))
        let now = Date()
        XCTAssertTrue(AccessPolicy.isPro([.init(productID: TimbreProduct.annual, isSubscription: true, revoked: false, expiresAt: now.addingTimeInterval(60))], now: now))
        XCTAssertFalse(AccessPolicy.isPro([.init(productID: TimbreProduct.annual, isSubscription: true, revoked: false, expiresAt: now.addingTimeInterval(-60))], now: now))
        XCTAssertFalse(AccessPolicy.isPro([.init(productID: TimbreProduct.lifetime, isSubscription: false, revoked: true, expiresAt: nil)], now: now))
        XCTAssertTrue(AccessPolicy.isPro([.init(productID: TimbreProduct.lifetime, isSubscription: false, revoked: false, expiresAt: nil)], now: now))
        XCTAssertFalse(AccessPolicy.isPro([.init(productID: "other", isSubscription: false, revoked: false, expiresAt: nil)], now: now))
    }

    func testOneEuroFilterSmoothsJitterAndFollowsSteps() {
        var filter = OneEuroFilter()
        var t = 0.0
        var outputs: [Double] = []
        for i in 0..<120 {
            t += 1.0 / 60
            outputs.append(filter.filter(i % 2 == 0 ? 1.0 : -1.0, at: t))
        }
        XCTAssertLessThan(outputs.suffix(30).map(abs).max()!, 0.6, "alternating jitter is damped")
        var step = OneEuroFilter()
        _ = step.filter(0, at: 0)
        var value = 0.0
        for i in 1...30 { value = step.filter(20, at: Double(i) / 60) }
        XCTAssertGreaterThan(value, 18, "a real change is reached within half a second")
    }

    func testStrobeDriftsWithSignAndStopsInTune() {
        var strobe = StrobePhase()
        let a = strobe.advance(cents: 10, dt: 0.1)
        XCTAssertGreaterThan(a, 0)
        var flat = StrobePhase()
        XCTAssertGreaterThan(flat.advance(cents: -10, dt: 0.1), 0.5, "flat wraps backwards")
        var still = StrobePhase()
        XCTAssertEqual(still.advance(cents: 0, dt: 0.1), 0)
    }

    func testDroneRendersFiniteAudioAndStops() {
        for voice in DroneRenderer.Voice.allCases {
            let drone = DroneRenderer(tonic: 146.83, voice: voice)
            var peak: Float = 0
            for _ in 0..<48000 { let s = drone.nextSample(); XCTAssertTrue(s.isFinite); peak = max(peak, abs(s)) }
            XCTAssertGreaterThan(peak, 0.005)
            XCTAssertLessThan(peak, 1)
            drone.stop()
            for _ in 0..<24000 { _ = drone.nextSample() }
            XCTAssertFalse(drone.isPlaying)
        }
    }

    func testMetronomeBeatLevelsMuteBeats() {
        let renderer = MetronomeRenderer(sampleRate: 4800, initial: MetronomePattern(bpm: 120, beatsPerBar: 4, subdivision: 1))
        renderer.beatLevels = [2, 0, 1, 0]
        var buffer = [Float](repeating: 0, count: 9600)
        let pulses = renderer.render(&buffer)
        XCTAssertEqual(pulses.count, 4)
        let beatLength = 2400
        func energy(_ beat: Int) -> Float { buffer[(beat * beatLength)..<(beat * beatLength + 120)].map { $0 * $0 }.reduce(0, +) }
        XCTAssertGreaterThan(energy(0), energy(2))
        XCTAssertEqual(energy(1), 0)
        XCTAssertEqual(energy(3), 0)
    }
}

final class CustomTuningTests: XCTestCase {
    func testCustomTuningKeepsAnchorsAndOrder() throws {
        let catalog = try Catalog()
        let base = try XCTUnwrap(catalog.tuning(id: "guitar.acoustic.6.standard"))
        let dadgad = CustomTuning(instrumentId: "guitar.acoustic.6", name: "DADGAD", midis: [38, 45, 50, 55, 57, 62])
        let tuning = dadgad.tuning(base: base)
        XCTAssertTrue(tuning.isCustom)
        XCTAssertEqual(tuning.courses.map(\.targetMidi), [38, 45, 50, 55, 57, 62])
        XCTAssertEqual(tuning.courses.map(\.label), ["D2", "A2", "D3", "G3", "A3", "D4"])
        XCTAssertEqual(tuning.courses.map(\.anchorId), base.courses.sorted { $0.index < $1.index }.map(\.anchorId))
        XCTAssertEqual(tuning.name.localized, "DADGAD")
    }

    func testCustomTuningsPersistAndValidate() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = try LocalStore(directory: directory)
        var settings = store.settings
        settings.customTunings = [CustomTuning(instrumentId: "ukulele.soprano.4", name: "Low G", midis: [55, 60, 64, 69])]
        try store.saveSettings(settings)
        XCTAssertEqual(try LocalStore(directory: directory).settings.customTunings?.first?.name, "Low G")
        settings.customTunings = [CustomTuning(instrumentId: "ukulele.soprano.4", name: "Broken", midis: [200])]
        XCTAssertThrowsError(try store.saveSettings(settings))
    }
}
