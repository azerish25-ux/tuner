import XCTest
@testable import TimbreCore

final class SpacedReviewTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let em = ChordSpec(name: "Em", root: 4, quality: "min", frets: [0, 2, 2, 0, 0, 0], fingers: [0, 2, 3, 0, 0, 0])
    private let g = ChordSpec(name: "G", root: 7, quality: "maj", frets: [3, 2, 0, 0, 0, 3])
    private let c = ChordSpec(name: "C", root: 0, quality: "maj", frets: [-1, 3, 2, 0, 1, 0])
    private let d = ChordSpec(name: "D", root: 2, quality: "maj", frets: [-1, -1, 0, 2, 3, 2])
    private let g3 = ReviewItem.note(midi: 55, at: Fretting(string: 3, fret: 0))
    private let b3 = ReviewItem.note(midi: 59, at: Fretting(string: 2, fret: 0))
    private let text = ReviewText(title: LearnText("Review"), intro: LearnText("i"), notesHint: LearnText("h"), alongTitle: LearnText("t"))

    /// Noon on day `n` (UTC) of the test's calendar.
    private func on(_ day: Int, hour: Int = 12) -> Date {
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        return calendar.date(byAdding: .hour, value: day * 24 + hour, to: start)!
    }
    private func startOf(_ day: Int) -> Date { calendar.startOfDay(for: on(day)) }

    private func record(_ deck: inout ReviewDeck, _ item: ReviewItem, _ score: Double, day: Int, course: String = "guitar") {
        deck.record([ReviewCredit(item: item, score: score)], courseId: course, now: on(day), calendar: calendar)
    }
    private func card(_ deck: ReviewDeck, _ item: ReviewItem, course: String = "guitar") -> ReviewCard? {
        deck.cards.first { $0.id == ReviewCard.cardId(courseId: course, key: item.key) }
    }
    private func listen(_ low: Int, _ high: Int) -> ReviewItem {
        .question(ReviewQuestion(prompt: LearnText(key: "Lhigher", "Which is higher?"), sound: [[low], [high]],
                                 options: [LearnText(key: "L1", "The first"), LearnText(key: "L2", "The second")], answer: 1))
    }
    private var quiz: ReviewItem {
        .question(ReviewQuestion(prompt: LearnText(key: "Lsix", "Which string is string 6?"), sound: nil,
                                 options: [LearnText(key: "Lthick", "The thickest"), LearnText(key: "Lthin", "The thinnest")], answer: 0,
                                 why: LearnText("Strings count from the thinnest."), visual: .chord(em)))
    }

    func testQualityFollowsTheCredit() {
        XCTAssertEqual([1, 0.95, 0.9, 0.8, 0.7, 0.6, 0.5, 0.3, 0.1, 0].map(SpacedReview.quality), [5, 5, 4, 4, 3, 3, 2, 1, 0, 0])
        XCTAssertEqual(SpacedReview.quality(.nan), 0)
    }

    func testOnlyWhatSlippedJoinsAndComesBackTomorrow() throws {
        var deck = ReviewDeck()
        deck.record([ReviewCredit(item: g3, score: 0.5), ReviewCredit(item: b3, score: 1), ReviewCredit(item: .chord(em), score: 0.9)],
                    courseId: "guitar", now: on(0), calendar: calendar)
        XCTAssertEqual(deck.cards.map(\.item), [g3], "played-well items are not tracked")
        let first = try XCTUnwrap(card(deck, g3))
        XCTAssertEqual(first.due, startOf(1))
        XCTAssertEqual(first.interval, 1)
        XCTAssertEqual(first.ease, SpacedReview.startEase)
        XCTAssertEqual(deck.dueCount(in: "guitar", now: on(0, hour: 23), calendar: calendar), 0, "nothing recorded today is due today")
        XCTAssertEqual(deck.dueCount(in: "guitar", now: on(1, hour: 0), calendar: calendar), 1)
        XCTAssertEqual(deck.dueCount(in: "ukulele", now: on(1), calendar: calendar), 0, "per course")
        XCTAssertEqual(deck.nextDue(in: "guitar"), startOf(1))
        // A clear miss starts harder; one item twice in a take counts at its average.
        record(&deck, .chord(c), 0.1, day: 0)
        XCTAssertEqual(try XCTUnwrap(card(deck, .chord(c))).ease, SpacedReview.startEase - 0.2, accuracy: 1e-9)
        deck.record([ReviewCredit(item: b3, score: 0.9), ReviewCredit(item: b3, score: 0.5)], courseId: "guitar", now: on(0), calendar: calendar)
        XCTAssertEqual(try XCTUnwrap(card(deck, b3)).score, 0.7, accuracy: 1e-9)
    }

    func testPassesSpaceAnItemOutUntilItRetires() throws {
        var deck = ReviewDeck()
        record(&deck, g3, 0.5, day: 0)
        let schedule: [(day: Int, score: Double, due: Int, interval: Int, ease: Double)] = [
            (1, 1, 4, 3, 2.4), (4, 1, 11, 7, 2.5), (11, 1, 29, 18, 2.6), (29, 0.85, 76, 47, 2.6),
        ]
        for step in schedule {
            record(&deck, g3, step.score, day: step.day)
            let now = try XCTUnwrap(card(deck, g3), "day \(step.day)")
            XCTAssertEqual(now.due, startOf(step.due), "day \(step.day)")
            XCTAssertEqual(now.interval, step.interval, "day \(step.day)")
            XCTAssertEqual(now.ease, step.ease, accuracy: 1e-9, "day \(step.day)")
            XCTAssertLessThan(now.interval, SpacedReview.maxIntervalDays)
        }
        XCTAssertEqual(try XCTUnwrap(card(deck, g3)).streak, 4)
        // The next pass would wait past the cap: it has stuck and leaves the deck.
        record(&deck, g3, 1, day: 76)
        XCTAssertNil(card(deck, g3))
        XCTAssertEqual(deck.retiredCount(in: "guitar"), 1)
        // A later slip in a lesson brings it back.
        record(&deck, g3, 0.4, day: 90)
        XCTAssertEqual(try XCTUnwrap(card(deck, g3)).due, startOf(91))
    }

    func testASlipComesBackTomorrowAndAHardPassWaitsLess() throws {
        var deck = ReviewDeck()
        record(&deck, g3, 0.5, day: 0)
        record(&deck, g3, 1, day: 1)
        record(&deck, g3, 1, day: 4)
        record(&deck, g3, 0.3, day: 11)
        let lapsed = try XCTUnwrap(card(deck, g3))
        XCTAssertEqual(lapsed.due, startOf(12))
        XCTAssertEqual(lapsed.interval, 1)
        XCTAssertEqual(lapsed.streak, 0)
        XCTAssertEqual(lapsed.lapses, 1)
        XCTAssertEqual(lapsed.ease, 2.3, accuracy: 1e-9)
        record(&deck, g3, 1, day: 12)
        XCTAssertEqual(try XCTUnwrap(card(deck, g3)).due, startOf(15), "back on the first wait")

        // Quality 3: two days rather than three, and the ease drops.
        record(&deck, b3, 0.5, day: 0)
        record(&deck, b3, 0.7, day: 1)
        let hard = try XCTUnwrap(card(deck, b3))
        XCTAssertEqual(hard.due, startOf(3))
        XCTAssertEqual(hard.ease, 2.16, accuracy: 1e-9)

        // The ease never drops below its floor.
        for day in 0..<8 { record(&deck, .chord(c), 0, day: day) }
        XCTAssertEqual(try XCTUnwrap(card(deck, .chord(c))).ease, SpacedReview.easeRange.lowerBound, accuracy: 1e-9)
    }

    func testALessonBeforeTheDayOnlyMovesItBackOnASlip() throws {
        var deck = ReviewDeck()
        record(&deck, g3, 0.5, day: 0)
        record(&deck, g3, 1, day: 1)
        record(&deck, g3, 1, day: 2)
        let kept = try XCTUnwrap(card(deck, g3))
        XCTAssertEqual(kept.due, startOf(4), "a lesson playing it early keeps its day")
        XCTAssertEqual(kept.streak, 1)
        record(&deck, g3, 0.2, day: 3)
        XCTAssertEqual(try XCTUnwrap(card(deck, g3)).due, startOf(4))
        XCTAssertEqual(try XCTUnwrap(card(deck, g3)).lapses, 1)
    }

    func testASessionTakesTheDueFirstThenTheWeakestInTurn() throws {
        let now = on(10)
        let due = startOf(9), later = startOf(15)
        var cards: [ReviewCard] = []
        for midi in 40..<48 { cards.append(ReviewCard(item: .note(midi: midi, at: nil), courseId: "guitar", due: due, interval: 1, score: Double(midi - 40) / 10, seen: now)) }
        for (index, chord) in [em, g, c, d].enumerated() { cards.append(ReviewCard(item: .chord(chord), courseId: "guitar", due: due, interval: 1, score: 0.05 + 0.1 * Double(index), seen: now)) }
        for high in 50..<55 { cards.append(ReviewCard(item: listen(45, high), courseId: "guitar", due: later, interval: 5, score: 0.5, seen: now)) }
        cards.append(ReviewCard(item: .chord(em), courseId: "ukulele", due: due, interval: 1, score: 0, seen: now))
        let deck = ReviewDeck(cards: cards)
        let session = deck.session(in: "guitar", now: now, calendar: calendar)

        XCTAssertEqual(Set(session.map(\.id)).count, session.count, "no item twice")
        XCTAssertTrue(session.allSatisfy { $0.courseId == "guitar" })
        XCTAssertLessThanOrEqual(session.count, SpacedReview.maxItems)
        XCTAssertLessThanOrEqual(session.reduce(0) { $0 + SpacedReview.seconds($1.kind) }, SpacedReview.sessionSeconds)
        for kind in ReviewItem.Kind.allCases { XCTAssertLessThanOrEqual(session.filter { $0.kind == kind }.count, SpacedReview.cap(kind)) }
        // Due notes and chords take turns, the weakest of each first.
        XCTAssertEqual(Array(session.prefix(4).map(\.item)), [.note(midi: 40, at: nil), .chord(em), .note(midi: 41, at: nil), .chord(g)])
        XCTAssertEqual(session.filter { $0.kind == .note }.count, SpacedReview.cap(.note))
        XCTAssertEqual(session.filter { $0.kind == .chord }.count, SpacedReview.cap(.chord))

        // With little due, the weakest of the rest fill the time, after it.
        let few = ReviewDeck(cards: [
            ReviewCard(item: .chord(g), courseId: "guitar", due: later, interval: 4, score: 0.7, seen: now),
            ReviewCard(item: .chord(c), courseId: "guitar", due: later, interval: 4, score: 0.2, seen: now),
            ReviewCard(item: g3, courseId: "guitar", due: due, interval: 1, score: 0.9, seen: now),
            ReviewCard(item: .chord(d), courseId: "guitar", due: later, interval: 4, score: 0.5, seen: now),
        ])
        XCTAssertEqual(few.session(in: "guitar", now: now, calendar: calendar).map(\.item), [g3, .chord(c), .chord(d), .chord(g)])
        XCTAssertEqual(few.due(in: "guitar", now: now, calendar: calendar).map(\.item), [g3])
        XCTAssertTrue(ReviewDeck().session(in: "guitar", now: now, calendar: calendar).isEmpty)
    }

    func testASessionPlaysAsAReviewAndItsStepsCreditTheSameItems() throws {
        let rhythm = ReviewItem.rhythm(pattern: [0, 1, 1.5, 2, 3], beatsPerBar: 4, bpm: 80, chord: g, strummed: true)
        let items: [ReviewItem] = [g3, .chord(em), .change(from: g, to: c), rhythm, listen(40, 64), quiz, b3]
        let cards = items.map { ReviewCard(item: $0, courseId: "guitar", due: startOf(1), interval: 1, score: 0.5, seen: on(0)) }
        let lesson = try XCTUnwrap(SpacedReview.lesson(courseId: "guitar", cards: cards, text: text, strings: 6, strums: true))
        XCTAssertEqual(lesson.kind, .review)
        XCTAssertTrue(LearnProgress.isReview(lesson.id))
        XCTAssertTrue(SpacedReview.isSession(lesson.id))
        XCTAssertFalse(SpacedReview.isSession(LearnProgress.reviewId(courseId: "guitar")), "not the weak-spot review")
        XCTAssertEqual(lesson.minutes, SpacedReview.sessionMinutes)
        XCTAssertTrue(lesson.free)
        guard case .explain(_, _, .fretboard(6, let dots, _, _))? = lesson.steps.first else { return XCTFail("the intro shows the notes on the neck") }
        XCTAssertEqual(dots, [Fretting(string: 3, fret: 0), Fretting(string: 2, fret: 0)])
        // The kinds in turn, in the order the items came; both notes in one step.
        XCTAssertEqual(lesson.steps.count, 7)
        XCTAssertEqual(lesson.steps[1], .playNotes(notes: [TimedNote(midi: 55, beat: 0, beats: 1, at: Fretting(string: 3, fret: 0)),
                                                           TimedNote(midi: 59, beat: 1, beats: 1, at: Fretting(string: 2, fret: 0))], hint: text.notesHint))
        XCTAssertEqual(lesson.steps[2], .playChord(chord: em))
        XCTAssertEqual(lesson.steps[3], .progression(chords: [g, c, g, c], bars: [1, 1, 1, 1], pattern: [0, 1, 2, 3], bpm: SpacedReview.changeBpm, beatsPerBar: 4))
        XCTAssertEqual(lesson.steps[4], .strum(chord: g, pattern: [0, 1, 1.5, 2, 3], bpm: 80, bars: 2, beatsPerBar: 4))
        guard case .listen(_, [[40], [64]], _, 1) = lesson.steps[5] else { return XCTFail("the ear question as it was asked") }
        guard case .quiz(_, _, 0, _, .chord(em)) = lesson.steps[6] else { return XCTFail("the theory question with its picture") }

        // Each step's own credit lands on the item it came from.
        let keys = Set(cards.map(\.item.key))
        let stepCredits = lesson.steps.flatMap { SpacedReview.credits(for: $0, score: 1) }
        XCTAssertEqual(stepCredits.count, 4, "change, rhythm and two questions; notes and chords come from the lesson's item scores")
        XCTAssertTrue(stepCredits.allSatisfy { keys.contains($0.item.key) })

        // Played on its day, every item is spaced out.
        var deck = ReviewDeck(cards: cards)
        let noteCredits = [g3, .chord(em), b3].map { ReviewCredit(item: $0, score: 1) }
        deck.record(noteCredits + stepCredits, courseId: "guitar", now: on(1), calendar: calendar)
        XCTAssertTrue(deck.cards.allSatisfy { $0.streak == 1 && $0.due == startOf(4) })
        XCTAssertEqual(deck.dueCount(in: "guitar", now: on(1), calendar: calendar), 0)

        // Not strummed here: a rhythm is tapped.
        let tapped = try XCTUnwrap(SpacedReview.lesson(courseId: "voice", cards: [cards[3]], text: text, strings: 0, strums: false))
        XCTAssertEqual(tapped.steps.last, .tapRhythm(pattern: [0, 1, 1.5, 2, 3], bpm: 80, bars: 2, beatsPerBar: 4))
        guard case .explain(_, _, .rhythm([0, 1, 1.5, 2, 3], 4))? = tapped.steps.first else { return XCTFail("a rhythm's intro shows its pattern") }
        XCTAssertNil(SpacedReview.lesson(courseId: "guitar", cards: [], text: text, strings: 6, strums: true))
    }

    func testStepsCreditChangesRhythmsAndQuestions() {
        let progression = LessonStep.progression(chords: [g, c, g, d], bars: [1, 1, 1, 1], pattern: [0, 2], bpm: 90, beatsPerBar: 4)
        let changes = SpacedReview.credits(for: progression, score: 0.5)
        XCTAssertEqual(changes.map(\.item.kind), [.change, .change], "G–C once either way round, then G–D")
        XCTAssertEqual(changes.first?.item.key, ReviewItem.change(from: c, to: g).key)
        XCTAssertTrue(changes.allSatisfy { $0.score == 0.5 })
        XCTAssertTrue(SpacedReview.credits(for: progression, score: 0.9, tapped: true).isEmpty, "tapped on the glass: no changes were played")
        XCTAssertTrue(SpacedReview.credits(for: progression, score: nil).isEmpty)

        let strum = SpacedReview.credits(for: .strum(chord: g, pattern: [0, 1, 2, 3], bpm: 70, bars: 2, beatsPerBar: nil), score: 0.4)
        XCTAssertEqual(strum.map(\.item.kind), [.rhythm])
        let tap = SpacedReview.credits(for: .tapRhythm(pattern: [0, 1, 2, 3], bpm: 100, bars: 2, beatsPerBar: nil), score: 0.4)
        XCTAssertEqual(tap.first?.item.key, strum.first?.item.key, "one rhythm whatever the tempo, chord or way it was played")
        XCTAssertTrue(SpacedReview.credits(for: .tapRhythm(pattern: [], bpm: 100, bars: 2, beatsPerBar: nil), score: 0).isEmpty)

        let options = [LearnText("A"), LearnText("B")]
        XCTAssertEqual(SpacedReview.credits(for: .listen(prompt: LearnText("Which?"), sound: [[60], [67]], options: options, answer: 1), score: 0).first?.item.kind, .interval)
        XCTAssertEqual(SpacedReview.credits(for: .quiz(prompt: LearnText("Why?"), options: options, answer: 0, why: nil, visual: .none), score: 0).first?.item.kind, .quiz)
        XCTAssertTrue(SpacedReview.credits(for: .quiz(prompt: LearnText("Why?"), options: options, answer: 5, why: nil, visual: .none), score: 0).isEmpty)
        XCTAssertNotEqual(listen(40, 64).key, listen(40, 65).key, "the same prompt over other notes is another question")
        XCTAssertTrue(SpacedReview.credits(for: .explain(title: LearnText("t"), body: LearnText("b"), visual: .none), score: 1).isEmpty)
        XCTAssertTrue(SpacedReview.credits(for: .playChord(chord: g), score: 0).isEmpty, "chords come from the item scores")
    }

    func testOldSavesDecodeAndTheDeckRoundTrips() throws {
        // A save from before spaced review has no deck.
        let old = try JSONDecoder().decode(UserSettings.self, from: JSONEncoder().encode(UserSettings()))
        XCTAssertNil(old.spacedReview)
        XCTAssertEqual(try JSONDecoder().decode(ReviewDeck.self, from: Data("{}".utf8)), ReviewDeck())

        var deck = ReviewDeck()
        let rhythm = ReviewItem.rhythm(pattern: [0, 1.5], beatsPerBar: nil, bpm: 72, chord: nil, strummed: false)
        deck.record([g3, .chord(em), .change(from: g, to: c), rhythm, listen(40, 64), quiz].map { ReviewCredit(item: $0, score: 0.3) },
                    courseId: "guitar", now: on(0), calendar: calendar)
        XCTAssertEqual(deck.cards.count, 6)
        var settings = UserSettings()
        settings.spacedReview = deck
        let decoded = try JSONDecoder().decode(UserSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.spacedReview, deck)
        XCTAssertEqual(decoded, settings)

        // A card of a kind this version can't read is dropped; the rest of the deck stays.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(deck)) as? [String: Any])
        var list = try XCTUnwrap(json["k"] as? [[String: Any]])
        list[0]["i"] = ["t": "future"]
        json["k"] = list
        let lossy = try JSONDecoder().decode(ReviewDeck.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(lossy.cards.map(\.id), deck.cards.dropFirst().map(\.id))
    }

    func testWeakSpotsFromBeforeSeedTheDeck() throws {
        let spots: [String: [WeakSpot]] = [
            "a": [WeakSpot(item: .note(midi: 55, at: Fretting(string: 3, fret: 0)), score: 0.5, seen: on(0)), WeakSpot(item: .chord(em), score: 0.6, seen: on(0))],
            "b": [WeakSpot(item: .note(midi: 55, at: Fretting(string: 3, fret: 0)), score: 0.3, seen: on(2))],
            "x": [WeakSpot(item: .chord(c), score: 0.1, seen: on(0))],
        ]
        let deck = ReviewDeck.seeded(from: spots, calendar: calendar) { ["a": "guitar", "b": "guitar"][$0] }
        XCTAssertEqual(deck.cards.count, 2, "one card per item, lessons outside any course skipped")
        let note = try XCTUnwrap(card(deck, g3))
        XCTAssertEqual(note.score, 0.3, "at its weakest")
        XCTAssertEqual(note.due, startOf(3))
        XCTAssertEqual(try XCTUnwrap(card(deck, .chord(em))).due, startOf(1))
        XCTAssertEqual(deck.dueCount(in: "guitar", now: on(5), calendar: calendar), 2)
    }

    func testTheDeckStaysWithinItsCapacity() {
        var deck = ReviewDeck()
        let credits = (0..<(SpacedReview.capacity + 20)).map { ReviewCredit(item: .note(midi: $0, at: nil), score: 0.5) }
        deck.record(credits, courseId: "guitar", now: on(0), calendar: calendar)
        XCTAssertEqual(deck.cards.count, SpacedReview.capacity)
    }

    func testTodayMakesRoomForTheReview() throws {
        let guitar = try XCTUnwrap(Catalog().instrument(id: "guitar.acoustic.6"))
        let set = DailySet.activities(instrument: guitar, goal: nil, lessonMinutes: 5, reviewMinutes: SpacedReview.sessionMinutes)
        XCTAssertEqual(Array(set.map(\.kind).prefix(2)), [.lesson, .review])
        XCTAssertEqual(set[1].minutes, SpacedReview.sessionMinutes)
    }
}
