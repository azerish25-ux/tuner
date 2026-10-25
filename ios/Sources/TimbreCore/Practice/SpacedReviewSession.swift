import Foundation

// MARK: - A review session as a lesson

extension SpacedReview {
    /// A session's tempo for chord changes: slow enough to land each change.
    public static let changeBpm = 60.0
    /// Most chord changes one progression step credits (a song's long progression has many).
    static let changesPerStep = 4

    /// The id of a course's spaced review session. It is a review (`LearnProgress.isReview`): it settles weak spots,
    /// keeps no stars and never unlocks anything.
    public static func lessonId(courseId: String) -> String { LearnProgress.reviewId(courseId: sessionPrefix + courseId) }
    public static func isSession(_ lessonId: String) -> Bool { lessonId.hasPrefix(LearnProgress.reviewId(courseId: sessionPrefix)) }
    private static let sessionPrefix = "spaced."

    /// The items as a short lesson out of the usual steps, opening on a look at what's coming: notes (three to a
    /// step), chords to ring, changes as a slow progression, rhythms strummed or tapped as they were asked, ear and
    /// theory questions as they were asked. The kinds take turns in the order the items came. Nil without items.
    /// - Parameters:
    ///   - strings: strings on the course instrument (0 without one): the opening card shows the notes on the neck.
    ///   - strums: strummed instruments strum their rhythms; others tap them.
    public static func lesson(courseId: String, cards: [ReviewCard], text: ReviewText, strings: Int, strums: Bool) -> Lesson? {
        let items = cards.map(\.item)
        guard !items.isEmpty else { return nil }
        var kinds: [ReviewItem.Kind] = []
        var queues: [ReviewItem.Kind: [LessonStep]] = [:]
        var notes: [TimedNote] = []
        for item in items where !kinds.contains(item.kind) { kinds.append(item.kind) }
        for item in items {
            switch item {
            case let .note(midi, at): notes.append(TimedNote(midi: midi, beat: 0, beats: 1, at: at))
            default: if let step = step(for: item, strums: strums) { queues[item.kind, default: []].append(step) }
            }
        }
        // Three notes to a step, in the order they were chosen.
        queues[.note] = stride(from: 0, to: notes.count, by: 3).map { start in
            LessonStep.playNotes(notes: numbered(Array(notes[start..<min(start + 3, notes.count)])), hint: text.notesHint)
        }
        var steps: [LessonStep] = [.explain(title: text.title, body: text.intro, visual: introVisual(items, strings: strings))]
        var round = 0
        while kinds.contains(where: { round < queues[$0, default: []].count }) {
            for kind in kinds {
                let queue = queues[kind, default: []]
                if round < queue.count { steps.append(queue[round]) }
            }
            round += 1
        }
        return Lesson(id: lessonId(courseId: courseId), title: text.title, kind: .review, minutes: sessionMinutes,
                      xp: WeakSpotReview.xp, free: true, steps: steps)
    }

    /// The step that asks for one item again (notes are grouped by `lesson`).
    static func step(for item: ReviewItem, strums: Bool) -> LessonStep? {
        switch item {
        case .note: return nil
        case let .chord(spec): return .playChord(chord: spec)
        case let .change(from, to):
            return .progression(chords: [from, to, from, to], bars: [1, 1, 1, 1], pattern: [0, 1, 2, 3], bpm: changeBpm, beatsPerBar: 4)
        case let .rhythm(pattern, beatsPerBar, bpm, chord, strummed):
            let tempo = min(200, max(40, bpm))
            if strummed && strums { return .strum(chord: chord, pattern: pattern, bpm: tempo, bars: 2, beatsPerBar: beatsPerBar) }
            return .tapRhythm(pattern: pattern, bpm: tempo, bars: 2, beatsPerBar: beatsPerBar)
        case let .question(question):
            if let sound = question.sound {
                return .listen(prompt: question.prompt, sound: sound, options: question.options, answer: question.answer)
            }
            return .quiz(prompt: question.prompt, options: question.options, answer: question.answer, why: question.why, visual: question.visual)
        }
    }

    /// The notes on the neck when the course has one (and knows where they sit), on a staff otherwise; else the first
    /// chord (or change), a rhythm's pattern, or nothing.
    static func introVisual(_ items: [ReviewItem], strings: Int) -> LessonVisual {
        var midi: [Int] = []
        var dots: [Fretting] = []
        for case let .note(note, at) in items {
            midi.append(note)
            if let at { dots.append(at) }
        }
        if !midi.isEmpty {
            if strings > 0, dots.count == midi.count {
                let highest = dots.map(\.fret).max() ?? 0
                return .fretboard(strings: strings, dots: dots, frets: min(12, max(5, highest + 1)), start: 1)
            }
            midi.sort()
            let average = Double(midi.reduce(0, +)) / Double(midi.count)
            return .staff(midi: midi, clef: average < 57 ? "bass" : "treble")
        }
        for item in items {
            switch item {
            case let .chord(spec): return .chord(spec)
            case let .change(from, _): return .chord(from)
            case let .rhythm(pattern, beatsPerBar, _, _, _): return .rhythm(pattern: pattern, beatsPerBar: beatsPerBar ?? 4)
            default: continue
            }
        }
        return LessonVisual.none
    }

    /// Notes one beat apart, in the given order (play-at-your-own-pace steps ignore the beats).
    private static func numbered(_ notes: [TimedNote]) -> [TimedNote] {
        notes.enumerated().map { index, note in TimedNote(midi: note.midi, beat: Double(index), beats: 1, at: note.at) }
    }

    // MARK: Credit from a finished step

    /// What a finished step says about the items spaced review keeps beyond a lesson's note and chord scores (those
    /// come from `LessonResult.items`): a progression's chord changes, a strum's or tap's rhythm, a listen or quiz
    /// question, each at the step's score. `tapped`: the step was passed by tapping the glass (no microphone), so a
    /// progression's changes were never played and earn nothing.
    public static func credits(for step: LessonStep, score: Double?, tapped: Bool = false) -> [ReviewCredit] {
        guard let score, score.isFinite else { return [] }
        let credit = max(0, min(1, score))
        switch step {
        case let .progression(chords, _, _, _, _):
            guard !tapped else { return [] }
            return changes(in: chords).map { ReviewCredit(item: $0, score: credit) }
        case let .strum(chord, pattern, bpm, _, beatsPerBar):
            guard !pattern.isEmpty else { return [] }
            return [ReviewCredit(item: .rhythm(pattern: pattern, beatsPerBar: beatsPerBar, bpm: bpm, chord: chord, strummed: true), score: credit)]
        case let .tapRhythm(pattern, bpm, _, beatsPerBar):
            guard !pattern.isEmpty else { return [] }
            return [ReviewCredit(item: .rhythm(pattern: pattern, beatsPerBar: beatsPerBar, bpm: bpm, chord: nil, strummed: false), score: credit)]
        case let .listen(prompt, sound, options, answer):
            guard options.indices.contains(answer) else { return [] }
            return [ReviewCredit(item: .question(ReviewQuestion(prompt: prompt, sound: sound, options: options, answer: answer)), score: credit)]
        case let .quiz(prompt, options, answer, why, visual):
            guard options.indices.contains(answer) else { return [] }
            return [ReviewCredit(item: .question(ReviewQuestion(prompt: prompt, sound: nil, options: options, answer: answer, why: why, visual: visual)), score: credit)]
        case .explain, .playNotes, .playAlong, .playChord:
            return []
        }
    }

    /// Each change between two different chords, once (either way round), in order, at most `changesPerStep`.
    static func changes(in chords: [ChordSpec]) -> [ReviewItem] {
        var out: [ReviewItem] = []
        var keys = Set<String>()
        for (from, to) in zip(chords, chords.dropFirst()) where from.symbol != to.symbol {
            let item = ReviewItem.change(from: from, to: to)
            guard keys.insert(item.key).inserted else { continue }
            out.append(item)
            if out.count == changesPerStep { break }
        }
        return out
    }
}
