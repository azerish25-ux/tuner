import Foundation

/// How a pick crosses a chord's strings, so a chord built from single recorded notes sounds strummed rather than
/// struck: when each string sounds after the stroke starts and how hard. A downstroke runs low string to high, the
/// pick gathering a little speed and losing a little weight as it goes (the first strings it meets ring loudest); an
/// upstroke runs high to low, mostly catching the top four strings, lighter, with the bass strings barely brushed.
/// Each string lands off the even spacing by a few milliseconds and its weight varies by a few percent, seeded, so
/// equal strokes render the same audio and neighbouring strokes (`seed`) differ the way two real strokes do.
public enum StrumFeel {
    public enum Stroke: Sendable { case down, up }

    /// One string of a stroke: its index among the chord's strings (0 the lowest), its delay after the stroke starts
    /// in seconds (the first string at 0) and its velocity.
    public struct Hit: Equatable, Sendable {
        public let string: Int
        public let delay: Double
        public let velocity: Double
    }

    /// Voices whose chords are strummed rather than rolled: the fretted, picked instruments.
    public static func strums(_ voice: InstrumentVoice) -> Bool {
        switch voice {
        case .guitar, .ukulele, .mandolin, .banjo: return true
        default: return false
        }
    }

    /// A relaxed downstroke's span across `strings` strings: about 16 ms from string to string (80 ms over six).
    public static func span(strings: Int) -> Double { 0.016 * Double(max(0, strings - 1)) }

    /// The strings a stroke sounds, in the order it meets them. `span` is the seconds from the first string to the
    /// last; `velocity` the stroke's weight (0...1).
    public static func hits(strings count: Int, stroke: Stroke, span: Double, velocity: Double, seed: UInt64) -> [Hit] {
        guard count > 0 else { return [] }
        var feel = ToneNoise(seed: 0x57_2D_F3_E1 &+ seed &* 0x9E37_79B9)
        let order: [Int] = stroke == .down ? Array(0..<count) : Array((0..<count).reversed())
        let gap = count > 1 ? max(0, span) / Double(count - 1) : 0
        var hits: [Hit] = []
        var previous = 0.0
        for (rank, string) in order.enumerated() {
            let along = count > 1 ? Double(rank) / Double(count - 1) : 0
            // The pick speeds up a touch through a stroke (an exponent under 1 would slow it).
            var delay = rank == 0 ? 0 : span * pow(along, 1.08) + gap * 0.18 * Double(feel.next()) + 0.0006 * Double(feel.next())
            delay = rank == 0 ? 0 : max(previous + 0.001, delay)
            previous = delay
            let weight: Double
            switch stroke {
            case .down:
                weight = 1 - 0.16 * along
            case .up:
                // An upstroke leads with the treble; past the fourth string it only brushes.
                weight = rank < 4 ? 0.82 * (1 - 0.22 * Double(rank) / 3) : 0.34
            }
            let strength = max(0, velocity * weight * (1 + 0.07 * Double(feel.next())))
            hits.append(Hit(string: string, delay: delay, velocity: strength))
        }
        return hits
    }
}
