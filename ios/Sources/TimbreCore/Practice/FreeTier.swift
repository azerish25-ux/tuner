import Foundation

/// What the free plan includes beyond the tuner, in one place (the owner's free-tier table):
/// - the tuner: every instrument's standard tuning, and every preset of the free instruments (`AccessPolicy`);
/// - Chords: the open-position library with Check (`ChordLibrary.isOpenPosition`); barre and movable shapes are Pro;
/// - the metronome: quarters, eighths and triplets, with the click and wood voices; sixteenths, the beep, accents and
///   the speed trainer are Pro;
/// - one custom tuning (`customTunings`);
/// - ten Your songs charts (`YourSongsPolicy.freeChartLimit`);
/// - capo and transpose (Settings).
/// The drone, scales, intonation and every lesson past a course's first unit stay in Pro.
public enum FreeTier {
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
