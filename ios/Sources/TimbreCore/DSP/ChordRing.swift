import Foundation

/// Which strings of a strummed chord really rang, from one `PolyTuner` reading of the chord's own pitches: the check
/// behind "Every string rings", and the one that can say "String 3 isn't ringing".
///
/// One strum can't tell everything apart. A string an octave (or a twelfth) above another sounding string sits on
/// that string's harmonic: heard or not, the solver may read the shared peak. Such a string is never called dead;
/// it is `unsure`, and the chord's own reading vouches for it. A string clear of every other string's harmonics is
/// judged on its own: not heard means it didn't ring.
public enum ChordRing {
    public enum State: String, Equatable, Sendable {
        /// Its own pitch was heard.
        case rings
        /// It sits clear of the other strings' harmonics and wasn't heard: muted, or not pressed down.
        case dead
        /// It shares its pitch with another string's harmonic: one strum can't say.
        case unsure
    }

    /// Harmonics up to this one count as a coincidence…
    static let harmonics = 8
    /// …when they land this close (cents) to a string's pitch.
    static let coincideCents = 25.0

    /// One state per string of `reading`, in the order the tuner was given `pitches` (Hz).
    public static func states(_ reading: PolyReading, pitches: [Double]) -> [State] {
        reading.strings.map { string in
            let clear = isClear(string.index, among: pitches)
            guard string.isHeard else { return clear ? .dead : .unsure }
            if string.evidence == .shared && !clear { return .unsure }
            return .rings
        }
    }

    /// No other string's fundamental or harmonic (up to the 8th) lands within `coincideCents` of string `index`.
    public static func isClear(_ index: Int, among pitches: [Double]) -> Bool {
        guard pitches.indices.contains(index), pitches[index] > 0 else { return false }
        let pitch = pitches[index]
        for (other, base) in pitches.enumerated() where other != index && base > 0 {
            for h in 1...harmonics where abs(PitchMath.cents(target: Double(h) * base, measured: pitch)) < coincideCents {
                return false
            }
        }
        return true
    }
}
