import Foundation

/// What the free plan includes beyond the tuner, in one place (the owner's free-tier table):
/// - the tuner: every instrument's standard tuning, and every preset of the free instruments (`AccessPolicy`);
/// - Chords: the open-position library with Check (`ChordLibrary.isOpenPosition`); barre and movable shapes are Pro;
/// - the metronome: quarters, eighths and triplets, with the click and wood voices; sixteenths, the beep, accents and
///   the speed trainer are Pro;
/// - Bullseye, and ear training's pitch-direction drill;
/// - one custom tuning (`customTunings`);
/// - ten Your songs charts (`YourSongsPolicy.freeChartLimit`);
/// - capo and transpose (Settings).
/// The drone, scales, intonation, the strobe's precision, temperaments, naming intervals and chords by ear, and every
/// lesson past a course's first unit stay in Pro. The paywall's Free and Pro table is built from these rules
/// (`PlanComparison`), so it can't promise more or less than the app gives.
public enum FreeTier {
    /// The practice tools and tuner features the Free and Pro table names.
    public enum Tool: String, CaseIterable, Sendable {
        /// The Chords tool with Check, on open-position shapes (`canUseVoicing`).
        case chords
        case scales, intonation, drone
        /// The tuner's strobe at pro precision.
        case strobe
        /// Just, meantone and the other historical temperaments.
        case temperaments
        /// The metronome's basics (`subdivisions`, `metronomeSounds`).
        case metronome
        /// Bullseye, the pitch game.
        case bullseye
        /// Ear training's "higher or lower?" drill.
        case pitchDirection
        /// Naming intervals and chords by ear.
        case earNaming
        case capo, transpose
    }

    /// The tools the free plan opens; every other `Tool` is Pro.
    public static let freeTools: Set<Tool> = [.chords, .metronome, .bullseye, .pitchDirection, .capo, .transpose]

    /// Whether the free plan opens `tool` (its basics, where it has Pro extras: open chords, the metronome's basics).
    public static func opens(_ tool: Tool) -> Bool { freeTools.contains(tool) }

    /// Custom tunings the free plan keeps, across every instrument.
    public static let customTunings = 1
    /// Metronome subdivisions open on the free plan: 1 quarters, 2 eighths, 3 triplets (4, sixteenths, is Pro).
    public static let subdivisions: Set<Int> = [1, 2, 3]
    /// Metronome voices open on the free plan, by `MetronomeRenderer.Sound` raw value.
    public static let metronomeSounds: Set<String> = ["click", "wood"]

    /// Whether a new custom tuning can be made: always with Pro, or while the free plan has room.
    public static func canAddCustomTuning(saved: Int, pro: Bool) -> Bool { pro || saved < customTunings }

    /// Whether a custom tuning can be saved: always with Pro; on the free plan an edit of one already saved, or a new
    /// one while there is room.
    public static func canSaveCustomTuning(id: String, saved: [CustomTuning], pro: Bool) -> Bool {
        pro || saved.contains { $0.id == id } || saved.count < customTunings
    }

    public static func canUseSubdivision(_ value: Int, pro: Bool) -> Bool { pro || subdivisions.contains(value) }

    public static func canUseMetronomeSound(_ id: String, pro: Bool) -> Bool { pro || metronomeSounds.contains(id) }

    /// A chord shape in the Chords tool: open-position shapes for everyone, the rest with Pro.
    public static func canUseVoicing(_ shape: ChordShape, root: Int, formula: ChordFormula, openMidi: [Int], pro: Bool) -> Bool {
        pro || ChordLibrary.isOpenPosition(shape, root: root, formula: formula, openMidi: openMidi)
    }
}
