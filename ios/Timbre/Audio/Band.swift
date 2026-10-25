import Foundation
import TimbreCore

// MARK: - What the band plays

/// The backing band of one lesson step: drums in the step's meter, a bass line on the roots and,
/// for chord steps, a soft pad. Rendered offline once per arrangement; equal arrangements share it.
struct BandArrangement: Hashable, Sendable {
    /// One bar: the harmony under it and how the drummer treats it.
    struct Bar: Hashable, Sendable {
        /// Root pitch class (C = 0); nil plays drums only.
        var root: Int?
        /// Chord tones above the root in semitones (the pad); empty for none.
        var tones: [Int] = []
        /// 1 answers the root with the octave instead of the fifth, so a long melody breathes.
        var variation = 0
        /// A short snare fill closing a four-bar phrase.
        var fill = false
        /// The final chord with a cymbal, for a take that went well.
        var ending = false
    }

    /// UserDefaults key of the player's band switch (on by default).
    static let preferenceKey = "learn.band"

    let bpm: Double
    let beatsPerBar: Int
    /// Concert A in Hz, so the band agrees with the player's tuning.
    let reference: Double
    /// Bar by bar from the first beat after the count-in; repeats until the step stops.
    let bars: [Bar]
    let bass: Bool
    let pad: Bool
    let swing: Bool

    /// A melodic play-along: drums and a bass on the tonic and dominant of the key the notes suggest.
    /// `bass` is off when the player's own instrument is the bass.
    static func melody(_ notes: [TimedNote], bpm: Double, beatsPerBar: Int, reference: Double, bass: Bool) -> BandArrangement {
        let meter = max(1, beatsPerBar)
        let end = notes.map { $0.beat + $0.beats }.max() ?? Double(meter)
        let count = max(1, Int((end / Double(meter)).rounded(.up)))
        let tonic = KeyEstimate.tonic(of: notes)
        let bars = phrased(Array(repeating: Bar(root: tonic), count: count), alternate: true)
        return BandArrangement(bpm: bpm, beatsPerBar: meter, reference: reference, bars: bars,
                               bass: bass && tonic != nil, pad: false, swing: swung(notes.map(\.beat)))
    }

    /// A strum or progression step: each chord for its bars, bass on the roots, a pad on the chord.
    /// Without chords (a strum step with no chord) the band is drums only.
    static func chords(_ chords: [ChordSpec], bars: [Int], pattern: [Double], bpm: Double, beatsPerBar: Int, reference: Double) -> BandArrangement {
        var list: [Bar] = []
        for (index, chord) in chords.enumerated() {
            let tones = ChordTarget(root: chord.root, formulaId: chord.quality)?.quality.intervals ?? [0, 7]
            let count = index < bars.count ? max(0, bars[index]) : 1
            list += Array(repeating: Bar(root: PitchMath.pitchClass(midi: chord.root), tones: tones), count: count)
        }
        if list.isEmpty { list = Array(repeating: Bar(root: nil), count: max(1, bars.reduce(0, +))) }
        return BandArrangement(bpm: bpm, beatsPerBar: max(1, beatsPerBar), reference: reference, bars: phrased(list, alternate: false),
                               bass: true, pad: true, swing: swung(pattern))
    }

    /// A fill closes every fourth bar and the last one; a melody's bass alternates bar by bar.
    private static func phrased(_ bars: [Bar], alternate: Bool) -> [Bar] {
        var out = bars
        for index in out.indices {
            out[index].variation = alternate ? index % 2 : 0
            out[index].fill = out.count > 1 && (index % 4 == 3 || index == out.count - 1)
        }
        return out
    }

    /// Off-beats on the triplet grid (0.333, 0.667) swing the hi-hat.
    private static func swung(_ beats: [Double]) -> Bool {
        beats.contains { beat in
            let fraction = beat - beat.rounded(.down)
            return abs(fraction - 2.0 / 3.0) < 0.04 || abs(fraction - 1.0 / 3.0) < 0.04
        }
    }
}

/// The key a melody suggests: Krumhansl–Schmuckler on duration-weighted pitch classes, with the last
/// note (melodies tend to end at home) counted again. With fewer than three pitch classes, the last note.
enum KeyEstimate {
    private static let major: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    private static let minor: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    static func tonic(of notes: [TimedNote]) -> Int? {
        guard var last = notes.first else { return nil }
        var weights = [Double](repeating: 0, count: 12)
        for note in notes {
            weights[PitchMath.pitchClass(midi: note.midi)] += max(0.25, note.beats)
            if note.beat >= last.beat { last = note }
        }
        let home = PitchMath.pitchClass(midi: last.midi)
        weights[home] += max(0.5, last.beats)
        guard weights.filter({ $0 > 0 }).count >= 3 else { return home }
        var best = home
        var bestScore = -Double.infinity
        for tonic in 0..<12 {
            for profile in [major, minor] {
                let score = correlation(weights, profile, tonic: tonic)
                if score > bestScore { bestScore = score; best = tonic }
            }
        }
        return best
    }

    /// The key a song is in (its song sheet), from its melody and its chords, each chord with the bars it lasts:
    /// Krumhansl–Schmuckler over both, less the share of the music a key can't spell (minor may raise its sixth
    /// and seventh), and a lean to the key the chords open and close on. "Jingle Bells" stays in C (its F rules
    /// out E minor), "Drunken Sailor" in D minor (its chords start and end there). Nil with neither.
    static func key(of notes: [TimedNote], chords: [(chord: ChordSpec, bars: Int)] = []) -> (tonic: Int, minor: Bool)? {
        var weights = [Double](repeating: 0, count: 12)
        var last: TimedNote?
        for note in notes {
            weights[PitchMath.pitchClass(midi: note.midi)] += max(0.25, note.beats)
            if note.beat >= (last?.beat ?? -Double.infinity) { last = note }
        }
        if let last { weights[PitchMath.pitchClass(midi: last.midi)] += max(0.5, last.beats) }
        for entry in chords {
            let tones = ChordTarget(root: entry.chord.root, formulaId: entry.chord.quality)?.quality.intervals ?? [0, 7]
            for tone in tones { weights[PitchMath.pitchClass(midi: entry.chord.root + tone)] += Double(max(1, entry.bars)) }
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        let ends = [chords.first?.chord, chords.last?.chord].compactMap { $0 }
        var best: (score: Double, tonic: Int, minor: Bool)?
        for tonic in 0..<12 {
            for isMinor in [false, true] {
                let scale = isMinor ? minorScale : majorScale
                var outside = 0.0
                for pc in 0..<12 where !scale.contains((pc - tonic + 12) % 12) { outside += weights[pc] }
                var score = correlation(weights, isMinor ? minor : major, tonic: tonic) - 2 * outside / total
                for chord in ends where PitchMath.pitchClass(midi: chord.root) == tonic {
                    let mode = chordIsMinor(chord)
                    if mode == nil || mode == isMinor { score += 0.15 }
                }
                if score > (best?.score ?? -Double.infinity) { best = (score: score, tonic: tonic, minor: isMinor) }
            }
        }
        return best.map { (tonic: $0.tonic, minor: $0.minor) }
    }

    /// Degrees of a major scale, and of minor with its raised sixth and seventh (melodic and harmonic minor).
    private static let majorScale: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
    private static let minorScale: Set<Int> = [0, 2, 3, 5, 7, 8, 9, 10, 11]

    /// True for a minor chord, false for a major one, nil for one without a third (sus, power chords).
    private static func chordIsMinor(_ chord: ChordSpec) -> Bool? {
        guard let intervals = ChordTarget(root: chord.root, formulaId: chord.quality)?.quality.intervals else { return nil }
        if intervals.contains(3) { return true }
        return intervals.contains(4) ? false : nil
    }

    private static func correlation(_ weights: [Double], _ profile: [Double], tonic: Int) -> Double {
        let meanX = weights.reduce(0, +) / 12
        let meanY = profile.reduce(0, +) / 12
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for pc in 0..<12 {
            let dx = weights[pc] - meanX
            let dy = profile[(pc - tonic + 12) % 12] - meanY
            sxy += dx * dy; sxx += dx * dx; syy += dy * dy
        }
        return sxx > 0 && syy > 0 ? sxy / (sxx * syy).squareRoot() : 0
    }
}

// MARK: - The rendered band

/// Every distinct bar of an arrangement (plus the ending) rendered once, back to back in one buffer.
/// Each part runs a bar plus a release tail, so a bar's last notes ring over the next downbeat.
/// Immutable after init; the render thread only reads it.
final class BandTrack: @unchecked Sendable {
    let sampleRate: Int
    let samples: UnsafeMutableBufferPointer<Float>
    let starts: [Int]
    let lengths: [Int]
    /// Part to start on each bar of the arrangement (repeats when the step runs longer).
    let sequence: [Int]
    /// The final-chord part.
    let ending: Int

    init(sampleRate: Int, parts: [[Float]], sequence: [Int], ending: Int) {
        self.sampleRate = sampleRate
        self.sequence = sequence
        self.ending = ending
        var peak: Float = 0
        var total = 0
        for part in parts {
            total += part.count
            for value in part { peak = max(peak, abs(value)) }
        }
        // Mixed under the player: the loudest moment of the band stays well below full scale.
        let scale: Float = peak > 0.35 ? 0.35 / peak : 1
        samples = UnsafeMutableBufferPointer<Float>.allocate(capacity: max(1, total))
        samples.initialize(repeating: 0)
        var starts: [Int] = []
        var lengths: [Int] = []
        var offset = 0
        for part in parts {
            starts.append(offset); lengths.append(part.count)
            for (index, value) in part.enumerated() { samples[offset + index] = value * scale }
            offset += part.count
        }
        self.starts = starts
        self.lengths = lengths
    }

    deinit { samples.deallocate() }
}

/// Render-thread side of the band. It never keeps time itself: the metronome's own downbeats start
/// each bar (`downbeat`), so the band is sample-locked to the click and pauses with it.
/// Two read heads: the bar now playing and the tail of the one before. Allocates nothing.
final class BandPlayer {
    private enum State { case playing, ending, stopped }
    private let track: BandTrack
    /// The metronome bar (0 = the count-in bar) on which the band's first bar starts.
    private let firstBar: Int
    private var state = State.playing
    private var position = 0, end = 0
    private var tailPosition = 0, tailEnd = 0
    private var tailGain: Float = 1, tailFade: Float = 0
    private var gain: Float = 1, target: Float = 1
    private let ramp: Float

    init(track: BandTrack, firstBar: Int) {
        self.track = track
        self.firstBar = firstBar
        ramp = 1 / Float(max(1, Double(track.sampleRate) * 0.04))
    }

    /// Something is coming out (the click ducks under it).
    var isSounding: Bool { gain > 0.001 && (position < end || tailPosition < tailEnd) }

    /// A metronome downbeat: bar `bar` counted from the metronome's first click.
    func downbeat(_ bar: Int) {
        guard state == .playing, !track.sequence.isEmpty else { return }
        let index = bar - firstBar
        guard index >= 0 else { return }
        start(track.sequence[index % track.sequence.count], tailFade: 0)
    }

    /// The final chord now; the bar under it fades out quickly.
    func finish() {
        guard state == .playing else { return }
        guard isSounding else { stop(); return }
        state = .ending
        start(track.ending, tailFade: 1 / Float(max(1, Double(track.sampleRate) * 0.12)))
    }

    /// Fades out. Without `force` a final chord already ringing is left to finish.
    func stop(force: Bool = true) {
        guard force || state != .ending else { return }
        state = .stopped
        target = 0
    }

    private func start(_ part: Int, tailFade fade: Float) {
        tailPosition = position; tailEnd = end
        tailGain = 1; tailFade = fade
        position = track.starts[part]
        end = position + track.lengths[part]
    }

    func nextSample() -> Float {
        var value: Float = 0
        if position < end { value += track.samples[position]; position += 1 }
        if tailPosition < tailEnd {
            value += track.samples[tailPosition] * tailGain
            tailPosition += 1
            if tailFade > 0 {
                tailGain = max(0, tailGain - tailFade)
                if tailGain == 0 { tailPosition = tailEnd }
            }
        }
        if gain != target { gain = gain < target ? min(target, gain + ramp) : max(target, gain - ramp) }
        return value * gain
    }
}

// MARK: - Offline synthesis

/// The band, written into plain buffers off the main thread, humanized and set in a light room. With the app's
/// recorded instruments (`samples`): a real drum kit, an electric bass and a grand piano comping the chords; without
/// them, or for any part whose recording can't be read, the synthesized drums (sine-drop kick, noise snare,
/// filtered-noise hat), plucked bass and detuned pad. Deterministic: the same arrangement renders the same audio.
enum BandSynth {
    /// The recorded kit under the bass and piano (its hits are levelled loud for a kit on its own).
    private static let drumLevel = 0.7
    /// Comping chords sit under the player: a soft touch on the piano.
    private static let compVelocity = 0.5

    static func render(_ arrangement: BandArrangement, sampleRate: Int, samples: SampleLibrary? = nil) -> BandTrack {
        let rate = Double(max(8000, sampleRate))
        let meter = max(1, arrangement.beatsPerBar)
        let beat = 60 / min(300, max(20, arrangement.bpm)) * rate
        let barLength = max(1, Int((beat * Double(meter)).rounded()))
        let tail = Int(0.6 * rate)
        let reference = arrangement.reference.isFinite && arrangement.reference > 0 ? arrangement.reference : 440

        // Distinct bars only; a forty-bar melody is a handful of parts.
        var specs: [BandArrangement.Bar] = []
        var lookup: [BandArrangement.Bar: Int] = [:]
        var sequence: [Int] = []
        for bar in arrangement.bars {
            if let known = lookup[bar] { sequence.append(known); continue }
            lookup[bar] = specs.count
            sequence.append(specs.count)
            specs.append(bar)
        }
        let last = arrangement.bars.last
        specs.append(BandArrangement.Bar(root: last?.root, tones: last?.tones ?? [], ending: true))

        let table = Wavetable(partials: [1, 0.35, 0.12, 0.05])
        let push = 0.006 * rate
        let kit = samples?.instrument(id: "drums")
        let bassSet = samples?.instrument(id: "bass")
        let keys = samples?.instrument(id: "piano")
        let recorded = kit != nil || bassSet != nil || keys != nil
        var parts: [[Float]] = []
        for (number, spec) in specs.enumerated() {
            let sounding = spec.ending ? Int(1.3 * rate) : barLength
            var out = [Float](repeating: 0, count: sounding + tail)
            var noise = Noise(seed: UInt32(truncatingIfNeeded: 0x2545F491 &+ number &* 7919))
            // The drummer's feel, apart from the drums' own noise so their sound stays the same.
            var feel = Noise(seed: UInt32(truncatingIfNeeded: 0x51ED_270B &+ number &* 104_729))
            let hits = spec.ending ? [Hit(beat: 0, drum: .kick, velocity: 1), Hit(beat: 0, drum: .crash, velocity: 1)]
                                   : groove(meter: meter, fill: spec.fill, swing: arrangement.swing)
            for (index, hit) in hits.enumerated() {
                var at = Int((hit.beat * beat).rounded())
                // Played, not programmed: every hit within ±8 % of its velocity, hats and snares off the grid
                // by up to ±6 ms. Kicks and anything on the downbeat stay exact, so the band stays
                // sample-locked to the click.
                let velocity = hit.velocity * Float(1 + 0.08 * feel.next())
                if hit.beat > 0, hit.drum == .hat || hit.drum == .snare {
                    at = max(0, at + Int((push * feel.next()).rounded()))
                }
                // The recorded kit when there is one, its round robins alternating hit by hit.
                if let kit, let samples, kit.has(piece: hit.drum.piece),
                   samples.addHit(kit, piece: hit.drum.piece, velocity: Double(min(1, velocity)), variation: number + index,
                                  into: &out, start: at, rate: rate, gain: drumLevel) {
                    continue
                }
                switch hit.drum {
                case .kick: kick(&out, at: at, velocity: velocity, rate: rate)
                case .snare: snare(&out, at: at, velocity: velocity, rate: rate, noise: &noise)
                case .hat: hat(&out, at: at, velocity: velocity, rate: rate, noise: &noise)
                case .crash: crash(&out, at: at, velocity: velocity, rate: rate, noise: &noise)
                }
            }
            if arrangement.bass, let root = spec.root {
                for note in bassLine(meter: meter, bar: spec) {
                    let at = Int((note.beat * beat).rounded())
                    let length = spec.ending ? min(Int(note.beats * beat), Int(1.1 * rate)) : Int(note.beats * beat)
                    let hz = PitchMath.frequency(midi: Double(bassMidi(root) + note.interval), reference: reference)
                    // The recorded bass: the note, then the same 60 ms let-go as the synthesized one.
                    let release = Int(0.06 * rate)
                    if let bassSet, let samples, bassSet.covers(hz),
                       samples.addNote(bassSet, hz: hz, velocity: 0.8 * Double(note.velocity), into: &out, start: at,
                                       length: length + release, rate: rate, release: 0.06) {
                        continue
                    }
                    bass(&out, at: at, length: length, hz: hz, velocity: note.velocity, rate: rate)
                }
            }
            if arrangement.pad, let root = spec.root, !spec.tones.isEmpty {
                let voices = padVoicing(root: root, tones: spec.tones).map { PitchMath.frequency(midi: Double($0), reference: reference) }
                var comped = false
                if let keys, let samples, voices.allSatisfy({ keys.covers($0) }) {
                    comped = comp(&out, frequencies: voices, meter: meter, beat: beat, bar: spec, swing: arrangement.swing,
                                  keys: keys, samples: samples, rate: rate, feel: &feel)
                }
                if !comped {
                    pad(&out, length: spec.ending ? Int(0.9 * rate) : barLength, frequencies: voices, rate: rate, table: table)
                }
            }
            // The same small room as the cues, its tail ringing into the release so it carries over the
            // next downbeat; kick and bass stay dry under its low cut. Recordings bring their own room: less of it.
            RoomReverb.apply(&out, rate: rate, settings: RoomReverb.Settings(wet: recorded ? 0.09 : 0.16, feedback: 0.78, damping: 0.4, lowCut: 280))
            RoomReverb.fadeTail(&out, frames: Int(0.04 * rate))
            parts.append(out)
        }
        return BandTrack(sampleRate: Int(rate), parts: parts, sequence: sequence, ending: specs.count - 1)
    }

    // MARK: Parts

    private enum Drum {
        case kick, snare, hat, crash
        /// The recorded kit's piece (SampleLibrary "drums").
        var piece: String {
            switch self {
            case .kick: return "kick"
            case .snare: return "snare"
            case .hat: return "hat"
            case .crash: return "crash"
            }
        }
    }
    private struct Hit { let beat: Double; let drum: Drum; let velocity: Float }
    private struct BassNote { let beat: Double; let beats: Double; let interval: Int; let velocity: Float }

    /// A gentle groove per meter: 4/4 kick on 1 and 3, snare on 2 and 4; 3/4 a waltz; 6/8 (and 9/8,
    /// 12/8) in dotted groups; anything else kick on 1, snare on the off beats. Hi-hat throughout.
    private static func groove(meter: Int, fill: Bool, swing: Bool) -> [Hit] {
        let compound = meter >= 6 && meter % 3 == 0
        let offbeat = swing ? 2.0 / 3.0 : 0.5
        let fills = fill && meter >= 2
        let fillStart = fills ? Double(compound ? meter - 2 : meter - 1) : Double(meter)
        var hits: [Hit] = []
        for b in 0..<meter where Double(b) < fillStart {
            let beat = Double(b)
            if compound {
                if b % 3 == 0 {
                    let group = b / 3
                    hits.append(Hit(beat: beat, drum: group % 2 == 0 ? .kick : .snare, velocity: group == 0 ? 1 : 0.7))
                }
                hits.append(Hit(beat: beat, drum: .hat, velocity: b % 3 == 0 ? 0.8 : 0.5))
                continue
            }
            switch meter {
            case 3:
                hits.append(Hit(beat: beat, drum: b == 0 ? .kick : .snare, velocity: b == 0 ? 1 : 0.4))
            case 4:
                hits.append(Hit(beat: beat, drum: b % 2 == 0 ? .kick : .snare, velocity: b == 0 ? 1 : 0.75))
            default:
                if b == 0 { hits.append(Hit(beat: beat, drum: .kick, velocity: 1)) }
                else if b % 2 == 1 { hits.append(Hit(beat: beat, drum: .snare, velocity: 0.65)) }
            }
            hits.append(Hit(beat: beat, drum: .hat, velocity: b == 0 ? 0.8 : 0.65))
            hits.append(Hit(beat: beat + offbeat, drum: .hat, velocity: 0.4))
        }
        if fills {
            let steps: [Double] = compound ? [0, 1, 1.5] : [0, 0.25, 0.5, 0.75]
            for (index, step) in steps.enumerated() {
                hits.append(Hit(beat: fillStart + step, drum: .snare, velocity: 0.45 + 0.14 * Float(index)))
            }
        }
        return hits
    }

    /// Root on the downbeat, answered by the fifth (or the octave) mid-bar, with a pickup in 4/4.
    private static func bassLine(meter: Int, bar: BandArrangement.Bar) -> [BassNote] {
        let fifth = bar.tones.isEmpty || bar.tones.contains(7) ? 7 : 0
        let answer = bar.variation == 0 ? fifth : 12
        if bar.ending { return [BassNote(beat: 0, beats: Double(min(meter, 2)), interval: 0, velocity: 1)] }
        switch meter {
        case 4:
            var notes = [BassNote(beat: 0, beats: 1.8, interval: 0, velocity: 1), BassNote(beat: 2, beats: 1.3, interval: answer, velocity: 0.85)]
            if !bar.fill { notes.append(BassNote(beat: 3.5, beats: 0.4, interval: bar.variation == 0 ? 12 : fifth, velocity: 0.6)) }
            return notes
        case 3:
            return [BassNote(beat: 0, beats: 1.8, interval: 0, velocity: 1), BassNote(beat: 2, beats: 0.9, interval: answer, velocity: 0.75)]
        case 2:
            return [BassNote(beat: 0, beats: 0.9, interval: 0, velocity: 1), BassNote(beat: 1, beats: 0.9, interval: answer, velocity: 0.8)]
        default:
            if meter >= 6 && meter % 3 == 0 {
                var notes: [BassNote] = []
                for b in stride(from: 0, to: meter, by: 3) {
                    let interval: Int = (b / 3) % 2 == 0 ? 0 : answer
                    let velocity: Float = b == 0 ? 1 : 0.8
                    notes.append(BassNote(beat: Double(b), beats: 2.7, interval: interval, velocity: velocity))
                }
                return notes
            }
            if meter >= 4 {
                let half = meter / 2
                return [BassNote(beat: 0, beats: Double(half) - 0.2, interval: 0, velocity: 1),
                        BassNote(beat: Double(half), beats: Double(meter - half) - 0.2, interval: answer, velocity: 0.8)]
            }
            return [BassNote(beat: 0, beats: Double(meter) * 0.9, interval: 0, velocity: 1)]
        }
    }

    /// Roots between F1 and E2, where a bass guitar sits.
    private static func bassMidi(_ root: Int) -> Int {
        let pc = PitchMath.pitchClass(midi: root)
        return pc >= 5 ? 24 + pc : 36 + pc
    }

    /// A pianist comping the bar's chord on the recorded piano: half-bar chords with a soft push before the next bar
    /// in 4/4, the waltz's "pah-pah" in 3/4, one chord per dotted group in compound meters; a fill bar holds one chord
    /// under the drums and the ending rings out. Each chord is rolled low to high a few milliseconds apart, and only
    /// off-downbeat chords move off the grid. False when a note couldn't be read (the pad plays instead).
    private static func comp(_ out: inout [Float], frequencies: [Double], meter: Int, beat: Double, bar: BandArrangement.Bar,
                             swing: Bool, keys: SampledInstrument, samples: SampleLibrary, rate: Double, feel: inout Noise) -> Bool {
        let compound = meter >= 6 && meter % 3 == 0
        let push = swing ? 2.0 / 3.0 : 0.5
        var chords: [(beat: Double, beats: Double, velocity: Double)]
        if bar.ending {
            chords = [(beat: 0, beats: 1.25 * rate / max(1, beat), velocity: 0.62)]
        } else if bar.fill {
            chords = [(beat: 0, beats: Double(meter) - 0.1, velocity: 0.55)]
        } else if compound {
            chords = stride(from: 0, to: meter, by: 3).map { (beat: Double($0), beats: 2.8, velocity: $0 == 0 ? 0.58 : 0.46) }
        } else {
            switch meter {
            case 4: chords = [(beat: 0, beats: 1.9, velocity: 0.6), (beat: 2, beats: 1.4, velocity: 0.5),
                              (beat: 3 + push, beats: 0.45, velocity: 0.36)]
            case 3: chords = [(beat: 0, beats: 0.9, velocity: 0.4), (beat: 1, beats: 0.8, velocity: 0.45), (beat: 2, beats: 0.8, velocity: 0.42)]
            case 2: chords = [(beat: 0, beats: 0.9, velocity: 0.55), (beat: 1, beats: 0.9, velocity: 0.45)]
            default: chords = [(beat: 0, beats: Double(meter) - 0.1, velocity: 0.55)]
            }
        }
        let ordered = frequencies.sorted()
        for chord in chords {
            var at = Int((chord.beat * beat).rounded())
            if chord.beat > 0 { at = max(0, at + Int((0.004 * rate * feel.next()).rounded())) }
            let length = max(1, Int(chord.beats * beat))
            for (rank, hz) in ordered.enumerated() {
                let roll = rank == 0 ? 0 : Int((Double(rank) * 0.006 + 0.002 * feel.next()) * rate)
                let velocity = compVelocity * chord.velocity / 0.6 * (1 + 0.06 * feel.next())
                guard samples.addNote(keys, hz: hz, velocity: velocity, into: &out, start: at + roll,
                                      length: length + Int(0.2 * rate), rate: rate, release: 0.2) else { return false }
            }
        }
        return true
    }

    /// Chord tones packed between G3 and A#4: close voicings that move little from chord to chord.
    private static func padVoicing(root: Int, tones: [Int]) -> [Int] {
        var midis: [Int] = []
        for tone in tones {
            var midi = 60 + PitchMath.pitchClass(midi: root) + tone
            while midi > 70 { midi -= 12 }
            while midi < 55 { midi += 12 }
            if !midis.contains(midi) { midis.append(midi) }
        }
        return midis
    }

    // MARK: Voices

    private static func kick(_ out: inout [Float], at start: Int, velocity: Float, rate: Double) {
        let count = min(Int(0.34 * rate), out.count - start)
        guard start >= 0, count > 0 else { return }
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / rate
            phase += 2 * Double.pi * (45 + 95 * exp(-t / 0.03)) / rate
            let envelope = min(1, t / 0.002) * exp(-t / 0.12)
            out[start + i] += Float(sin(phase) * envelope) * 0.55 * velocity
        }
    }

    private static func snare(_ out: inout [Float], at start: Int, velocity: Float, rate: Double, noise: inout Noise) {
        let count = min(Int(0.22 * rate), out.count - start)
        guard start >= 0, count > 0 else { return }
        var filter = HighPass(cutoff: 1400, rate: rate)
        for i in 0..<count {
            let t = Double(i) / rate
            let hiss = filter.process(noise.next()) * exp(-t / 0.055)
            let body = sin(2 * Double.pi * 185 * t) * exp(-t / 0.03) * 0.6
            out[start + i] += Float((hiss + body) * min(1, t / 0.001)) * 0.24 * velocity
        }
    }

    private static func hat(_ out: inout [Float], at start: Int, velocity: Float, rate: Double, noise: inout Noise) {
        let count = min(Int(0.07 * rate), out.count - start)
        guard start >= 0, count > 0 else { return }
        var first = HighPass(cutoff: 7000, rate: rate)
        var second = HighPass(cutoff: 7000, rate: rate)
        for i in 0..<count {
            let t = Double(i) / rate
            out[start + i] += Float(second.process(first.process(noise.next())) * exp(-t / 0.018)) * 0.1 * velocity
        }
    }

    private static func crash(_ out: inout [Float], at start: Int, velocity: Float, rate: Double, noise: inout Noise) {
        let count = min(Int(1.6 * rate), out.count - start)
        guard start >= 0, count > 0 else { return }
        var filter = HighPass(cutoff: 4500, rate: rate)
        for i in 0..<count {
            let t = Double(i) / rate
            out[start + i] += Float(filter.process(noise.next()) * min(1, t / 0.003) * exp(-t / 0.45)) * 0.11 * velocity
        }
    }

    /// A round plucked bass: the upper partials fade first.
    private static func bass(_ out: inout [Float], at start: Int, length: Int, hz: Double, velocity: Float, rate: Double) {
        let release = Int(0.06 * rate)
        let count = min(length + release, out.count - start)
        guard start >= 0, length > 0, count > 0 else { return }
        let step = 2 * Double.pi * hz / rate
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / rate
            var envelope = min(1, t / 0.008) * (0.45 + 0.55 * exp(-t / 0.4))
            if i >= length { envelope *= 1 - Double(i - length) / Double(max(1, release)) }
            let bright = exp(-t / 0.15)
            let wave = sin(phase) + (0.22 + 0.3 * bright) * sin(2 * phase) + 0.12 * bright * sin(3 * phase)
            out[start + i] += Float(wave * envelope) * 0.2 * velocity
            phase += step
            if phase > 2 * Double.pi { phase -= 2 * Double.pi }
        }
    }

    /// Two slightly detuned oscillators per chord tone, slow attack, long release into the next bar.
    private static func pad(_ out: inout [Float], length: Int, frequencies: [Double], rate: Double, table: Wavetable) {
        let attack = 0.25 * rate
        let release = Int(0.5 * rate)
        let count = min(length + release, out.count)
        guard length > 0, count > 0 else { return }
        for (voice, hz) in frequencies.enumerated() {
            for detune in [-5.0, 5.0] {
                let increment = hz * pow(2, detune / 1200) / rate
                var phase = Double(voice) * 0.29 + (detune > 0 ? 0.5 : 0)
                phase -= phase.rounded(.down)
                for i in 0..<count {
                    var envelope = min(1, Double(i) / attack)
                    if i >= length {
                        let left = 1 - Double(i - length) / Double(max(1, release))
                        envelope *= left * left
                    }
                    out[i] += table.sample(phase) * Float(envelope) * 0.03
                    phase += increment
                    if phase >= 1 { phase -= 1 }
                }
            }
        }
    }

    // MARK: Helpers

    private struct Noise {
        private var state: UInt32
        init(seed: UInt32) { state = seed == 0 ? 0x9E37_79B9 : seed }
        /// White noise in -1…1 (xorshift).
        mutating func next() -> Double {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return Double(state) / Double(UInt32.max) * 2 - 1
        }
    }

    private struct HighPass {
        private let a: Double
        private var lastIn = 0.0, lastOut = 0.0
        init(cutoff: Double, rate: Double) {
            let rc = 1 / (2 * Double.pi * cutoff)
            a = rc / (rc + 1 / rate)
        }
        mutating func process(_ x: Double) -> Double {
            lastOut = a * (lastOut + x - lastIn)
            lastIn = x
            return lastOut
        }
    }

    /// One cycle of a soft, rounded wave, read with linear interpolation.
    private struct Wavetable {
        static let size = 2048
        private let table: [Float]
        init(partials: [Double]) {
            var values = [Float](repeating: 0, count: Self.size + 1)
            var peak: Float = 0
            for i in 0...Self.size {
                let x = 2 * Double.pi * Double(i) / Double(Self.size)
                var value = 0.0
                for (k, weight) in partials.enumerated() { value += weight * sin(Double(k + 1) * x) }
                values[i] = Float(value)
                peak = max(peak, abs(Float(value)))
            }
            if peak > 0 { for i in values.indices { values[i] /= peak } }
            table = values
        }
        func sample(_ phase: Double) -> Float {
            let position = phase * Double(Self.size)
            let index = min(Self.size - 1, max(0, Int(position)))
            let fraction = Float(position - Double(index))
            return table[index] + (table[index + 1] - table[index]) * fraction
        }
    }
}
