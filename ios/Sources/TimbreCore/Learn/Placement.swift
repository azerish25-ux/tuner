import Foundation

// MARK: - Where an experience answer starts, per course

/// Onboarding's "How long have you been playing?" as a place in each course. Beginners start at unit 1;
/// "novice" (a few months) starts after the basics; "intermediate" (a few years) at the course's mid-course chord
/// and song units; "advanced" (many years) at its barre and lead units; "pro" past those where the course goes
/// further. Units are named by id, so a reordered course still places right; a course missing from the table
/// (or a unit id it no longer has) falls back to a share of the course (`LearnProgress.placementUnit(level:unitCount:)`).
public enum CoursePlacement {
    /// The answers, lowest first.
    public static let levels = ["beginner", "novice", "intermediate", "advanced", "pro"]

    /// 0 for beginners (and anything unknown) up to 4 for "pro".
    public static func rung(of level: String) -> Int { levels.firstIndex(of: level) ?? 0 }

    /// The unit each level starts at, by course.
    static let starts: [String: [String: String]] = [
        // Hello · First melodies · … · More open chords · … · Songs with chords · … · Barre chords and the pentatonic · … · Lead technique
        "guitar": ["novice": "gtr-2", "intermediate": "gtr-7", "advanced": "gtr-10", "pro": "gtr-13"],
        // Hello · First chords · Strumming · Melodies · More chords · Songs
        "ukulele": ["novice": "uke-2", "intermediate": "uke-5", "advanced": "uke-6", "pro": "uke-7"],
        // Hello · Roots and timing · E and A strings · Root, fifth, octave · Walking bass · Grooves
        "bass": ["novice": "bass-2", "intermediate": "bass-4", "advanced": "bass-5", "pro": "bass-6"],
        // Hello · Bowing · First fingers · D and G strings · Low 2 and high 2 · Expression
        "violin": ["novice": "vln-2", "intermediate": "vln-4", "advanced": "vln-5", "pro": "vln-6"],
        // Hello · Bowing · First position · G and C strings · Shifting basics
        "cello": ["novice": "vc-2", "intermediate": "vc-4", "advanced": "vc-5", "pro": "vc-5"],
        // Hello · First notes · Down, up and tremolo · Chords and the chop · Fiddle tunes · Slides, hammers and crosspicking
        "mandolin": ["novice": "man-2", "intermediate": "man-4", "advanced": "man-5", "pro": "man-6"],
        // Hello · Rolls · Chords with rolls · First melodies · Hammer-ons, pull-offs, slides · Clawhammer
        "banjo": ["novice": "bjo-2", "intermediate": "bjo-4", "advanced": "bjo-5", "pro": "bjo-6"],
        // Finding your voice · Pitch matching · Scales · Intervals you can sing · Melodies · Control
        "voice": ["novice": "voc-2", "intermediate": "voc-4", "advanced": "voc-5", "pro": "voc-6"],
        // Higher or lower · Same or different · Steps and skips · Intervals I · Intervals II · Chord qualities · Scale degrees · Dictation
        "ear": ["novice": "ear-2", "intermediate": "ear-4", "advanced": "ear-6", "pro": "ear-7"],
        // Notes · Sharps and flats · The staff · Rhythm and time · Major scales · Intervals · Chords · Progressions
        "theory": ["novice": "thy-2", "intermediate": "thy-4", "advanced": "thy-6", "pro": "thy-7"],
        // The beat · Eighth notes · Rests and syncopation · Ties and dots · Triplets and swing · Other meters
        "rhythm": ["novice": "rhy-2", "intermediate": "rhy-3", "advanced": "rhy-5", "pro": "rhy-6"],
    ]

    /// The unit (0-based) a level starts at in a course, given its unit ids; 0 for beginners. Never past the last unit.
    public static func startUnit(level: String, courseId: String, unitIds: [String]) -> Int {
        guard unitIds.count >= 2, rung(of: level) > 0 else { return 0 }
        if let id = starts[courseId]?[level], let index = unitIds.firstIndex(of: id) { return min(index, unitIds.count - 1) }
        return (LearnProgress.placementUnit(level: level, unitCount: unitIds.count) ?? -1) + 1
    }
}

// MARK: - The 45-second placement check

/// For players who say they've played for years: G, C and D from their course's own chord steps, then a strum
/// pattern from its strum steps (D DU UDU when it has one). How it went moves the answer one level up or down.
public enum PlacementCheck {
    /// Answers the check is offered for.
    public static let levels: Set<String> = ["intermediate", "advanced", "pro"]
    /// The strum the check asks for when the course teaches it: D, DU, UDU.
    public static let strumPattern: [Double] = [0, 1, 1.5, 2.5, 3, 3.5]
    /// Bars of the strum.
    public static let bars = 2

    public static func offered(level: String) -> Bool { levels.contains(level) }

    /// The check's steps in a course: G, C and D chords (D7 when there's no D), then the strum on G. Chord shapes
    /// come from its chord steps first, then from the chords its strum steps play; the strum is the course's
    /// D DU UDU at its quickest tempo, else its busiest four-beat pattern. Nil when the course has no such steps
    /// (bowed strings, bass, voice and the any-instrument courses).
    public static func steps(in course: LearnCourse) -> [LessonStep]? {
        var chordShapes: [String: ChordSpec] = [:]
        var strumShapes: [String: ChordSpec] = [:]
        var strums: [(pattern: [Double], bpm: Double)] = []
        for step in course.lessons.flatMap(\.steps) {
            switch step {
            case let .playChord(chord):
                if chordShapes[chord.symbol] == nil { chordShapes[chord.symbol] = chord }
            case let .strum(chord, pattern, bpm, _, beatsPerBar, _, _):
                if let chord, strumShapes[chord.symbol] == nil { strumShapes[chord.symbol] = chord }
                if (beatsPerBar ?? 4) == 4, !pattern.isEmpty, (pattern.max() ?? 0) < 4 { strums.append((pattern, bpm)) }
            default:
                break
            }
        }
        func shape(_ symbol: String) -> ChordSpec? { chordShapes[symbol] ?? strumShapes[symbol] }
        guard let g = shape("G"), let c = shape("C"), let d = shape("D") ?? shape("D7"), let strum = chooseStrum(strums) else { return nil }
        return [.playChord(chord: g), .playChord(chord: c), .playChord(chord: d),
                .strum(chord: g, pattern: strum.pattern, bpm: strum.bpm, bars: bars, beatsPerBar: nil)]
    }

    private static func chooseStrum(_ strums: [(pattern: [Double], bpm: Double)]) -> (pattern: [Double], bpm: Double)? {
        let named = strums.filter { $0.pattern == strumPattern }
        if let quickest = named.max(by: { $0.bpm < $1.bpm }) { return quickest }
        return strums.max { a, b in a.pattern.count != b.pattern.count ? a.pattern.count < b.pattern.count : a.bpm < b.bpm }
    }

    public enum Verdict: String, Equatable, Sendable { case up, same, down }

    /// Seconds a chord may take, from showing to ringing, to count as a fluent change.
    public static let fluentSeconds = 8.0

    /// How the check went. `chords`: each chord step's score (1 when it rang as a chord, the share of right
    /// notes when plucked, 0.6 when the player said they played it); `seconds`: how long each took;
    /// `strum`: the share on the beat, nil when the microphone didn't hear it (tapped instead).
    /// Up: every chord clean (0.9+) within `fluentSeconds` and the strum 85 % on the beat. Down: two or more
    /// chords well short (under 0.6) without a strong strum, or a heard strum under half without fluent chords.
    /// Anything else, or too little heard to tell, keeps the answer.
    public static func verdict(chords: [Double], seconds: [Double], strum: Double?) -> Verdict {
        let fluentChords = !chords.isEmpty && chords.allSatisfy { $0 >= 0.9 }
            && seconds.count == chords.count && seconds.allSatisfy { $0 <= fluentSeconds }
        let fluentStrum = (strum ?? 0) >= 0.85
        if fluentChords && fluentStrum { return .up }
        let shakyChords = chords.filter { $0 < 0.6 }.count >= 2
        let shakyStrum = strum.map { $0 < 0.5 } ?? false
        if (shakyChords && !fluentStrum) || (shakyStrum && !fluentChords) { return .down }
        return .same
    }

    /// The answer after the check: one level up (at most "pro") or down (never below "novice": a few years
    /// of playing still skips the first steps).
    public static func level(_ level: String, after verdict: Verdict) -> String {
        let rung = CoursePlacement.rung(of: level)
        let levels = CoursePlacement.levels
        switch verdict {
        case .same: return level
        case .up: return levels[min(levels.count - 1, rung + 1)]
        case .down: return rung <= 1 ? level : levels[rung - 1]
        }
    }
}
