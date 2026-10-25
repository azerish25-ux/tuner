import Foundation

/// The paywall's Free and Pro table, built from the rules the app enforces (`AccessPolicy`, `FreeTier`,
/// `YourSongsPolicy`) rather than written beside them, so a change to the free tier changes the table with it. Each
/// row's words belong to the app (`Row.Kind` names them); its cells come from here.
public enum PlanComparison {
    /// What a plan gives on a row.
    public enum Cell: Equatable, Sendable {
        case included
        case excluded
        case count(Int)
        case unlimited
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public enum Kind: String, Sendable, CaseIterable {
            /// Teaching lessons, songbooks aside (`Curriculum.lessonCount`).
            case lessons
            /// Instruments whose every preset tuning is open.
            case everyTuning
            case customTunings
            /// Open-position chords with Check.
            case openChords
            /// Barre and movable chords, scales, intonation and the drone.
            case practiceTools
            /// The strobe's pro precision and the temperaments.
            case strobe
            /// The metronome's basics and Bullseye.
            case metronome
            /// Naming intervals and chords by ear.
            case earNaming
            /// Your own song charts.
            case charts
            /// Slow down, loop and find chords in a recording.
            case recordingTools
        }

        public let id: Kind
        public let free: Cell
        public let pro: Cell

        public init(id: Kind, free: Cell, pro: Cell) {
            self.id = id; self.free = free; self.pro = pro
        }
    }

    /// The table, in the paywall's order.
    public static func rows(catalog: Catalog, curriculum: Curriculum, openings: FreeOpenings = .current) -> [Row] {
        [
            Row(id: .lessons, free: .count(freeLessons(curriculum, openings: openings).count), pro: .count(curriculum.lessonCount)),
            Row(id: .everyTuning, free: .count(everyTuningFree(catalog).count), pro: .count(catalog.instruments.count)),
            Row(id: .customTunings, free: limit { FreeTier.canAddCustomTuning(saved: $0, pro: false) },
                pro: limit { FreeTier.canAddCustomTuning(saved: $0, pro: true) }),
            Row(id: .openChords, free: cell(FreeTier.opens(.chords) && canUse(openChord, pro: false)), pro: cell(canUse(openChord, pro: true))),
            Row(id: .practiceTools, free: cell(practiceToolsFree), pro: .included),
            Row(id: .strobe, free: cell(FreeTier.opens(.strobe) && FreeTier.opens(.temperaments)), pro: .included),
            Row(id: .metronome, free: cell(FreeTier.opens(.metronome) && FreeTier.opens(.bullseye)), pro: .included),
            Row(id: .earNaming, free: cell(FreeTier.opens(.earNaming)), pro: .included),
            Row(id: .charts, free: limit { YourSongsPolicy.canAddChart(existing: $0, pro: false) },
                pro: limit { YourSongsPolicy.canAddChart(existing: $0, pro: true) }),
            Row(id: .recordingTools, free: cell(YourSongsPolicy.canSlowDownAndLoop(pro: false) && YourSongsPolicy.canDetectChords(pro: false)),
                pro: cell(YourSongsPolicy.canSlowDownAndLoop(pro: true) && YourSongsPolicy.canDetectChords(pro: true))),
        ]
    }

    /// The teaching lessons the free plan opens to someone with no placement: each course's free lessons and what the
    /// remote settings open.
    public static func freeLessons(_ curriculum: Curriculum, openings: FreeOpenings = .current) -> [Lesson] {
        let courses = curriculum.courses
        return courses.filter { !$0.isSongbook }.flatMap(\.lessons).filter { lesson in
            AccessPolicy.canPlay(lesson, pro: false, progress: LearnProgress(), courses: courses, openings: openings)
        }
    }

    /// The instruments the free plan opens in every tuning, each preset and the player's own (guitar, bass, ukulele,
    /// violin and cello today); every other instrument tunes free in its standard tuning only.
    public static func everyTuningFree(_ catalog: Catalog) -> [Instrument] {
        catalog.instruments.filter { instrument in
            let presets = catalog.tunings.filter { $0.instrumentId == instrument.id }
            guard let standard = catalog.tuning(id: instrument.defaultTuningId) else { return false }
            let own = CustomTuning(id: "custom.probe", instrumentId: instrument.id, name: "", midis: standard.courses.map(\.targetMidi))
                .tuning(base: standard)
            return (presets + [own]).allSatisfy { AccessPolicy.canUse(tuning: $0, of: instrument, pro: false) }
        }
    }

    /// Barre and movable chords, scales, intonation and the drone: open only when all of them are. (A mix would need a
    /// row of its own; `AccessPolicyTests` fails if the free tier ever opens some and not the others.)
    public static var practiceToolsFree: Bool {
        canUse(barreChord, pro: false) && FreeTier.opens(.scales) && FreeTier.opens(.intonation) && FreeTier.opens(.drone)
    }

    // MARK: Probes

    /// E minor in the open position on a standard guitar: 022000.
    static let openChord = ChordShape(frets: [0, 2, 2, 0, 0, 0], score: 0)
    /// F major as a full barre at the first fret: 133211.
    static let barreChord = ChordShape(frets: [1, 3, 3, 2, 1, 1], score: 0)

    private static func canUse(_ shape: ChordShape, pro: Bool) -> Bool {
        let minor = shape == openChord
        return FreeTier.canUseVoicing(shape, root: minor ? 4 : 5, formula: ChordFormula.byId(minor ? "min" : "maj"),
                                      openMidi: ChordLibrary.standardGuitar, pro: pro)
    }

    private static func cell(_ open: Bool) -> Cell { open ? .included : .excluded }

    /// How many a plan allows, found by asking its rule (`canAdd(existing)`) one at a time: unlimited past 999.
    private static func limit(_ canAdd: (Int) -> Bool) -> Cell {
        for existing in 0..<1_000 where !canAdd(existing) { return existing == 0 ? .excluded : .count(existing) }
        return .unlimited
    }
}
