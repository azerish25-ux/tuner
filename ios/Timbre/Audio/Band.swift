import Foundation
import TimbreCore

// MARK: - What the band plays

/// The backing band of one lesson step: drums in the step's meter, a bass line on the roots and, for chord steps,
/// comping on the chords, all in the song's style (`BandStyle`: pop, rock, reggae one-drop, country two-step, funk,
/// ballad, or the courses' standard groove). Rendered offline once per arrangement; equal arrangements share it.
struct BandArrangement: Hashable, Sendable {
    /// One stretch of a bar's harmony: from `beat` (counted from the bar's downbeat) to the next segment or the bar's
    /// end, the chord `root` (pitch class, nil for none) with `tones` above it.
    struct Segment: Hashable, Sendable {
        var beat: Double
        var root: Int?
        var tones: [Int]

        init(beat: Double, root: Int?, tones: [Int] = []) {
            self.beat = beat; self.root = root; self.tones = tones
        }
    }

    /// One bar: the harmony under it and how the drummer treats it.
    struct Bar: Hashable, Sendable {
        /// Root pitch class (C = 0) on the downbeat; nil plays drums only.
        var root: Int?
        /// Chord tones above the root in semitones (the comping); empty for none.
        var tones: [Int] = []
        /// 1 answers the root with the octave instead of the fifth, so a long melody breathes.
        var variation = 0
        /// A short fill closing a four-bar phrase.
        var fill = false
        /// The final chord with a cymbal, for a take that went well.
        var ending = false
        /// The first bar of a phrase after a fill: the bigger styles open it with a crash.
        var lift = false
        /// What the song can be recognised by (`BandCue`: its melody's opening, its chords) and the style its strum
        /// pattern suggests. The style itself is settled when the band renders, off the main thread (`BandSynth.style`),
        /// and survives callers that copy bars into a new arrangement.
        var cues: [String] = []
        var guess: BandStyle = .standard
        /// The chord changes after the downbeat, in beat order (each beat above 0 and inside the bar); empty when one
        /// chord (`root`, `tones`) holds the whole bar. Set them through `segments`.
        var changes: [Segment] = []

        /// The bar's harmony, change by change: the downbeat's chord (`root`, `tones`) at beat 0, then each change.
        /// A bar with one chord is one segment. Setting it puts the earliest segment on the downbeat (its beat read
        /// as 0) and the rest in `changes`, one per beat (the first given wins); an empty list leaves the bar without
        /// a chord (drums only). The band plays each segment's chord from its beat: the bass moves to its root and the
        /// comping to its chord, and whatever was still ringing stops at the change (`BandGroove.changing(at:)`).
        var segments: [Segment] {
            get { [Segment(beat: 0, root: root, tones: tones)] + changes }
            set {
                // In beat order; segments given at the same beat keep the order they came in.
                let indexed = newValue.enumerated().sorted { ($0.element.beat, $0.offset) < ($1.element.beat, $1.offset) }
                let ordered = indexed.map { $0.element }
                root = ordered.first?.root
                tones = ordered.first?.tones ?? []
                var later: [Segment] = []
                for segment in ordered.dropFirst() where segment.beat.isFinite && segment.beat > 1e-6 {
                    if let last = later.last, abs(last.beat - segment.beat) < 1e-6 { continue }
                    later.append(segment)
                }
                changes = later
            }
        }

        /// The chord sounding at `beat` of this bar: the last segment starting at or before it.
        func segment(at beat: Double) -> Segment {
            var found = Segment(beat: 0, root: root, tones: tones)
            for change in changes where change.beat <= beat + 1e-6 { found = change }
            return found
        }
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

    /// A melodic play-along: drums and a bass on the tonic and dominant of the key the notes suggest, in the style of
    /// the song the notes open (when the band knows it). `bass` is off when the player's own instrument is the bass.
    static func melody(_ notes: [TimedNote], bpm: Double, beatsPerBar: Int, reference: Double, bass: Bool) -> BandArrangement {
        let meter = max(1, beatsPerBar)
        let end = notes.map { $0.beat + $0.beats }.max() ?? Double(meter)
        let count = max(1, Int((end / Double(meter)).rounded(.up)))
        let tonic = KeyEstimate.tonic(of: notes)
        let cues = BandCue.melody(notes, meter: meter).map { [$0] } ?? []
        let bars = phrased(Array(repeating: Bar(root: tonic, cues: cues), count: count), alternate: true)
        return BandArrangement(bpm: bpm, beatsPerBar: meter, reference: reference, bars: bars,
                               bass: bass && tonic != nil, pad: false, swing: swung(notes.map(\.beat)))
    }

    /// A strum or progression step: each chord for its bars, bass on the roots, comping on the chord, in the song's
    /// style (recognised by its chords and strum, else guessed from the strum). Without chords (a strum step with
    /// no chord) the band is drums only.
    static func chords(_ chords: [ChordSpec], bars: [Int], pattern: [Double], bpm: Double, beatsPerBar: Int, reference: Double) -> BandArrangement {
        let meter = max(1, beatsPerBar)
        let symbols = BandCue.perBar(chords, bars: bars)
        let cues = [BandCue.chords(symbols, meter: meter, pattern: pattern), BandCue.chords(symbols, meter: meter)].compactMap { $0 }
        let guess = BandStyle.inferred(pattern: pattern, bpm: bpm, meter: meter)
        var list: [Bar] = []
        for (index, chord) in chords.enumerated() {
            let tones = ChordTarget(root: chord.root, formulaId: chord.quality)?.quality.intervals ?? [0, 7]
            let count = index < bars.count ? max(0, bars[index]) : 1
            let bar = Bar(root: PitchMath.pitchClass(midi: chord.root), tones: tones, cues: cues, guess: guess)
            list += Array(repeating: bar, count: count)
        }
        if list.isEmpty { list = Array(repeating: Bar(root: nil, guess: guess), count: max(1, bars.reduce(0, +))) }
        return BandArrangement(bpm: bpm, beatsPerBar: meter, reference: reference, bars: phrased(list, alternate: false),
                               bass: true, pad: true, swing: swung(pattern))
    }

    /// A fill closes every fourth bar and the last one, and the bar after a fill lifts; a melody's bass alternates
    /// bar by bar.
    private static func phrased(_ bars: [Bar], alternate: Bool) -> [Bar] {
        var out = bars
        for index in out.indices {
            out[index].variation = alternate ? index % 2 : 0
            out[index].fill = out.count > 1 && (index % 4 == 3 || index == out.count - 1)
            out[index].lift = out.count > 4 && index > 0 && index % 4 == 0
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

/// Every distinct bar of an arrangement (plus the ending) rendered once, back to back, in three layers: the kit (drums
/// and cymbals, nothing with a pitch the microphone could take for a note), the pitched rhythm section (the bass line
/// and the toms) and the harmony (the comping). So the band can thin to drums and bass and fill back in, and keep to
/// its kit on the phone's speaker, without a second rendering. After the bars come two one-shots the take can fire
/// over the band, in the kit layer: a crash (the multiplier reaching ×4) and a choked strum (a run broken). Each part
/// runs a bar plus a release tail, so a bar's last notes ring over the next downbeat. Immutable after init; the render
/// thread only reads it.
final class BandTrack: @unchecked Sendable {
    let sampleRate: Int
    /// The kit, and the one-shots.
    let kit: UnsafeMutableBufferPointer<Float>
    /// The bass line and the toms, at the same offsets as `kit`; nil when the arrangement has neither.
    let bass: UnsafeMutableBufferPointer<Float>?
    /// The comping, at the same offsets; nil when the arrangement has none.
    let harmony: UnsafeMutableBufferPointer<Float>?
    let starts: [Int]
    let lengths: [Int]
    /// Part to start on each bar of the arrangement (repeats when the step runs longer).
    let sequence: [Int]
    /// The final-chord part.
    let ending: Int
    /// The one-shot parts.
    let crash: Int
    let choke: Int

    /// `bass[i]` and `harmony[i]` lie under `kit[i]` (a missing or shorter one is silent there); `crash` and `choke`
    /// are parts of `kit`.
    init(sampleRate: Int, kit: [[Float]], bass: [[Float]], harmony: [[Float]], sequence: [Int], ending: Int, crash: Int, choke: Int) {
        self.sampleRate = sampleRate
        self.sequence = sequence
        self.ending = ending
        self.crash = crash
        self.choke = choke
        var peak: Float = 0
        var total = 0
        for (index, part) in kit.enumerated() {
            total += part.count
            let low = index < bass.count ? bass[index] : []
            let high = index < harmony.count ? harmony[index] : []
            for (frame, value) in part.enumerated() {
                let under = (frame < low.count ? low[frame] : 0) + (frame < high.count ? high[frame] : 0)
                peak = max(peak, abs(value + under))
            }
        }
        // Mixed under the player: the loudest moment of the band stays well below full scale.
        let scale: Float = peak > 0.35 ? 0.35 / peak : 1
        let lengths = kit.map { $0.count }
        var starts: [Int] = []
        var offset = 0
        for length in lengths {
            starts.append(offset)
            offset += length
        }
        self.starts = starts
        self.lengths = lengths
        self.kit = Self.layer(kit, starts: starts, lengths: lengths, total: total, scale: scale)
        self.bass = Self.audible(bass) ? Self.layer(bass, starts: starts, lengths: lengths, total: total, scale: scale) : nil
        self.harmony = Self.audible(harmony) ? Self.layer(harmony, starts: starts, lengths: lengths, total: total, scale: scale) : nil
    }

    /// Whether any part of a layer sounds at all.
    private static func audible(_ parts: [[Float]]) -> Bool {
        parts.contains { part in part.contains { $0 != 0 } }
    }

    /// One layer laid out at the parts' offsets, each part cut to its length.
    private static func layer(_ parts: [[Float]], starts: [Int], lengths: [Int], total: Int, scale: Float) -> UnsafeMutableBufferPointer<Float> {
        let buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: max(1, total))
        buffer.initialize(repeating: 0)
        for (index, part) in parts.enumerated() where index < starts.count {
            let start = starts[index]
            for (frame, value) in part.prefix(lengths[index]).enumerated() { buffer[start + frame] = value * scale }
        }
        return buffer
    }

    deinit {
        kit.deallocate()
        bass?.deallocate()
        harmony?.deallocate()
    }
}

/// What the take asks of the band as it goes, from the main thread to the render thread: thin to the drums and bass
/// (a note missed) or play in full (a run of four again), step back under spoken cues (VoiceOver), keep to its kit
/// (on the phone's speaker while the microphone listens), and the one-shots over it (a crash at ×4, a choked strum
/// when a run breaks). The render thread only ever `try`s the lock (it skips a read rather than wait).
final class BandFeel: @unchecked Sendable {
    struct State: Equatable {
        var thin = false
        var duck = false
        /// The band plays its kit only (the band on the phone's speaker, where the microphone hears it): drums are
        /// aperiodic, so the pitch detector rejects them. Off unless the route asks for it.
        var kitOnly = false
        /// How many crashes and chokes have been asked for: a player fires each new one once.
        var crashes = 0
        var chokes = 0
    }

    static let shared = BandFeel()
    private let lock = NSLock()
    private var state = State()

    /// The state, unless the main thread holds it this moment.
    func read() -> State? {
        guard lock.try() else { return nil }
        defer { lock.unlock() }
        return state
    }

    private func change(_ edit: (inout State) -> Void) {
        lock.lock()
        edit(&state)
        lock.unlock()
    }

    /// The comping drops out (true) or comes back (false).
    func thin(_ on: Bool) { change { $0.thin = on } }
    /// The band steps back (true), so spoken cues come through.
    func duck(_ on: Bool) { change { $0.duck = on } }
    /// The band plays its kit layer only (true) or in full (false): no bass, no toms, no comping, and the kit voiced
    /// for a phone's speaker. A setting of the route, not of the take: `reset` keeps it. `AudioService` sets it from
    /// the route and the microphone (on the speaker while it listens) and holds the band to its kit there whatever
    /// this says; a screen may also ask for the kit anywhere.
    func kitOnly(_ on: Bool) { change { $0.kitOnly = on } }
    /// Whether the band is playing its kit only (`kitOnly(_:)`).
    var isKitOnly: Bool {
        lock.lock()
        defer { lock.unlock() }
        return state.kitOnly
    }
    func crash() { change { $0.crashes &+= 1 } }
    func choke() { change { $0.chokes &+= 1 } }
    /// A new take: the full band (in kit only, while the route asks for that).
    func reset(duck: Bool = false) { change { $0.thin = false; $0.duck = duck } }
}

/// Render-thread side of the band. It never keeps time itself: the metronome's own downbeats start
/// each bar (`downbeat`), so the band is sample-locked to the click and pauses with it.
/// Two read heads: the bar now playing and the tail of the one before, each over the three layers; a third plays the
/// one-shots. It follows `BandFeel` every few milliseconds. Allocates nothing.
final class BandPlayer {
    private enum State { case playing, ending, stopped }
    private let track: BandTrack
    private let kitLayer: UnsafeMutableBufferPointer<Float>
    private let bassLayer: UnsafeMutableBufferPointer<Float>?
    private let harmonyLayer: UnsafeMutableBufferPointer<Float>?
    private let feel: BandFeel
    /// The metronome bar (0 = the count-in bar) on which the band's first bar starts.
    private let firstBar: Int
    private var state = State.playing
    private var position = 0, end = 0
    private var tailPosition = 0, tailEnd = 0
    private var tailGain: Float = 1, tailFade: Float = 0
    private var gain: Float = 1, target: Float = 1
    private let ramp: Float
    /// Each layer's level, easing to its target over about 150 ms: the comping (0 thinned, or kit only), the bass and
    /// toms (0 kit only), the kit (stepping back when a kit on its own is thinned), how far the kit is voiced for the
    /// speaker, and the whole band under spoken cues.
    private var harmony: Float = 1, harmonyTarget: Float = 1
    private var low: Float = 1, lowTarget: Float = 1
    private var drumsLevel: Float = 1, drumsTarget: Float = 1
    private var speaker: Float = 0, speakerTarget: Float = 0
    private var duck: Float = 1, duckTarget: Float = 1
    private let ease: Float
    private var shotPosition = 0, shotEnd = 0
    private var crashes = 0, chokes = 0
    /// The take's last word on thinning (kept while `BandFeel` can't be read).
    private var thinned = false
    /// The route holds the band to its kit (`AudioService`: on the speaker while the microphone listens), whatever
    /// `BandFeel` says. Set under the output's lock.
    var routeKitOnly = false
    /// The kit as a phone's speaker plays it: nothing under 200 Hz (the kick's boom, the snare's body), which a phone
    /// can't play anyway and the pitch detector could take for a low note.
    private var speakerFilter: SpeakerFilter
    /// Frames until `BandFeel` is read again (about 5 ms).
    private var poll = 0
    private static let pollFrames = 256
    private static let duckLevel: Float = 0.4
    /// The kit on the speaker sits a little under its headphone level, so the microphone hears the instrument first.
    private static let speakerLevel: Float = 0.8
    /// A kit on its own, thinned after a miss, steps back this far (there is no comping to drop), and comes back in
    /// full at four in a row.
    private static let thinKit: Float = 0.5

    init(track: BandTrack, firstBar: Int, kitOnly: Bool = false, feel: BandFeel = .shared) {
        self.track = track
        kitLayer = track.kit
        bassLayer = track.bass
        harmonyLayer = track.harmony
        self.feel = feel
        self.firstBar = firstBar
        routeKitOnly = kitOnly
        ramp = 1 / Float(max(1, Double(track.sampleRate) * 0.04))
        ease = 1 / Float(max(1, Double(track.sampleRate) * 0.15))
        speakerFilter = SpeakerFilter(cutoff: 200, rate: Double(track.sampleRate))
        let now = feel.read()
        crashes = now?.crashes ?? 0
        chokes = now?.chokes ?? 0
        aim(now)
        harmony = harmonyTarget; low = lowTarget; drumsLevel = drumsTarget; speaker = speakerTarget; duck = duckTarget
    }

    /// Something is coming out (the click ducks under it).
    var isSounding: Bool { gain > 0.001 && (position < end || tailPosition < tailEnd || shotPosition < shotEnd) }

    /// A metronome downbeat: bar `bar` counted from the metronome's first click.
    func downbeat(_ bar: Int) {
        guard state == .playing, !track.sequence.isEmpty else { return }
        let index = bar - firstBar
        guard index >= 0 else { return }
        start(track.sequence[index % track.sequence.count], tailFade: 0)
    }

    /// The final chord now, with the whole band (just its kit where the route keeps it to that); the bar under it
    /// fades out quickly.
    func finish() {
        guard state == .playing else { return }
        guard isSounding else { stop(); return }
        state = .ending
        aim(feel.read())
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

    /// The layers' targets from what the take and the route ask; with `now` nil (the main thread holds it), the
    /// take's last word stands. A final chord is never thinned.
    private func aim(_ now: BandFeel.State?) {
        if let now {
            duckTarget = now.duck ? Self.duckLevel : 1
            thinned = now.thin
        }
        let kitOnly = routeKitOnly || (now?.kitOnly ?? (speakerTarget > 0))
        let thin = state == .playing && thinned
        harmonyTarget = kitOnly || thin ? 0 : 1
        lowTarget = kitOnly ? 0 : 1
        drumsTarget = kitOnly && thin ? Self.thinKit : 1
        speakerTarget = kitOnly ? 1 : 0
    }

    /// Reads what the take asks for: the band's thinning, ducking and kit, and any new one-shot.
    private func follow() {
        let now = feel.read()
        aim(now)
        if !isSounding {
            // Nothing is coming out yet (the count-in): the band starts as asked, with no fade to hear.
            harmony = harmonyTarget; low = lowTarget; drumsLevel = drumsTarget; speaker = speakerTarget
        }
        guard let now else { return }
        guard state == .playing else {
            crashes = now.crashes; chokes = now.chokes
            return
        }
        if now.crashes != crashes {
            crashes = now.crashes
            shoot(track.crash)
        }
        if now.chokes != chokes {
            chokes = now.chokes
            shoot(track.choke)
        }
    }

    private func shoot(_ part: Int) {
        guard track.starts.indices.contains(part) else { return }
        shotPosition = track.starts[part]
        shotEnd = shotPosition + track.lengths[part]
    }

    private static func approach(_ value: Float, _ goal: Float, by step: Float) -> Float {
        value < goal ? min(goal, value + step) : max(goal, value - step)
    }

    func nextSample() -> Float {
        if poll == 0 {
            poll = Self.pollFrames
            follow()
        } else {
            poll -= 1
        }
        if harmony != harmonyTarget { harmony = Self.approach(harmony, harmonyTarget, by: ease) }
        if low != lowTarget { low = Self.approach(low, lowTarget, by: ease) }
        if drumsLevel != drumsTarget { drumsLevel = Self.approach(drumsLevel, drumsTarget, by: ease) }
        if speaker != speakerTarget { speaker = Self.approach(speaker, speakerTarget, by: ease) }
        if duck != duckTarget { duck = Self.approach(duck, duckTarget, by: ease) }
        var drums: Float = 0
        var bass: Float = 0
        var chords: Float = 0
        if position < end {
            drums += kitLayer[position]
            if let bassLayer { bass += bassLayer[position] }
            if let harmonyLayer { chords += harmonyLayer[position] }
            position += 1
        }
        if tailPosition < tailEnd {
            drums += kitLayer[tailPosition] * tailGain
            if let bassLayer { bass += bassLayer[tailPosition] * tailGain }
            if let harmonyLayer { chords += harmonyLayer[tailPosition] * tailGain }
            tailPosition += 1
            if tailFade > 0 {
                tailGain = max(0, tailGain - tailFade)
                if tailGain == 0 { tailPosition = tailEnd }
            }
        }
        // The one-shots ring out in full over a kit that has stepped back.
        var kit = drums * drumsLevel
        if shotPosition < shotEnd {
            kit += kitLayer[shotPosition]
            shotPosition += 1
        }
        // The filter runs on every sample, so moving to and from the speaker's voicing never clicks.
        let filtered = speakerFilter.process(kit)
        if speaker > 0 {
            let voiced = kit + (filtered - kit) * speaker
            kit = voiced * (1 - (1 - Self.speakerLevel) * speaker)
        }
        if gain != target { gain = Self.approach(gain, target, by: ramp) }
        return (kit + bass * low + chords * harmony) * gain * duck
    }
}

/// A second-order high-pass (Butterworth, an RBJ biquad) for the render thread: no allocation, its state in doubles.
private struct SpeakerFilter {
    private let b0, b1, b2, a1, a2: Double
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    init(cutoff: Double, rate: Double) {
        let omega = 2 * Double.pi * min(cutoff, rate * 0.45) / max(1, rate)
        let alpha = sin(omega) / (2 * 0.7071)
        let cosine = cos(omega)
        let a0 = 1 + alpha
        b0 = (1 + cosine) / 2 / a0
        b1 = -(1 + cosine) / a0
        b2 = (1 + cosine) / 2 / a0
        a1 = -2 * cosine / a0
        a2 = (1 - alpha) / a0
    }

    mutating func process(_ input: Float) -> Float {
        let x = Double(input)
        var y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        // Settles to exact silence rather than lingering in subnormal numbers.
        if abs(y) < 1e-15 { y = 0 }
        x2 = x1
        x1 = x
        y2 = y1
        y1 = y
        return Float(y)
    }
}

// MARK: - Offline synthesis

/// The band, written into plain buffers off the main thread, humanized and set in a light room, in the song's style
/// (`BandGroove` says what each player does bar by bar). With the app's recorded instruments (`samples`): a real drum
/// kit (cross-stick, toms, tambourine and shaker included), an electric bass, a grand piano and a hollowbody electric
/// guitar strumming string by string (`StrumFeel`); without them, or for any part whose recording can't be read, the
/// synthesized drums (sine-drop kick and toms, noise snare, filtered-noise hat), plucked bass and detuned pad, the
/// piano standing in for a missing guitar. Deterministic: the same arrangement renders the same audio.
enum BandSynth {
    /// The recorded kit under the bass and piano (its hits are levelled loud for a kit on its own).
    private static let drumLevel = 0.7
    /// Comping chords sit under the player and a touch under the bass: a soft touch on the piano.
    private static let compVelocity = 0.42
    /// The recorded bass's touch at a bass line's full velocity.
    private static let bassVelocity = 0.9
    /// The electric guitar's level: its strokes stack three to five strings.
    private static let guitarLevel = 0.7

    /// The recorded players the band can use (each nil when the app ships without it).
    private struct Players {
        let kit: SampledInstrument?
        let bass: SampledInstrument?
        let keys: SampledInstrument?
        let guitar: SampledInstrument?
        let chops: SampledInstrument?
        let samples: SampleLibrary?
    }

    /// The style the arrangement's song is played in: the one its cues name (the first time, this reads the
    /// curriculum: call it off the main thread), else the one its strum suggested.
    static func style(of arrangement: BandArrangement) -> BandStyle {
        guard let first = arrangement.bars.first else { return .standard }
        if !first.cues.isEmpty {
            let index = BandStyleIndex.shared
            for cue in first.cues {
                if let known = index.style(forCue: cue) { return known }
            }
        }
        return first.guess
    }

    static func render(_ arrangement: BandArrangement, sampleRate: Int, samples: SampleLibrary? = nil) -> BandTrack {
        let rate = Double(max(8000, sampleRate))
        let meter = max(1, arrangement.beatsPerBar)
        let beat = 60 / min(300, max(20, arrangement.bpm)) * rate
        let barLength = max(1, Int((beat * Double(meter)).rounded()))
        let tail = Int(0.6 * rate)
        let reference = arrangement.reference.isFinite && arrangement.reference > 0 ? arrangement.reference : 440
        let style = Self.style(of: arrangement)

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
        // The final chord is the one the last bar ends on.
        let closing = arrangement.bars.last?.segments.last
        specs.append(BandArrangement.Bar(root: closing?.root, tones: closing?.tones ?? [], ending: true))

        let table = Wavetable(partials: [1, 0.35, 0.12, 0.05])
        let push = 0.006 * rate
        let players = Players(kit: samples?.instrument(id: "drums"), bass: samples?.instrument(id: "bass"),
                              keys: samples?.instrument(id: "piano"), guitar: samples?.instrument(id: "eguitar"),
                              chops: samples?.instrument(id: "chops"), samples: samples)
        let recorded = players.kit != nil || players.bass != nil || players.keys != nil
        // The same small room as the cues, its tail ringing into the release so it carries over the next downbeat;
        // kick and bass stay dry under its low cut. Recordings bring their own room: less of it.
        let room = RoomReverb.Settings(wet: recorded ? 0.09 : 0.16, feedback: 0.78, damping: 0.4, lowCut: 280)
        let fade = Int(0.04 * rate)
        var kits: [[Float]] = []
        var lows: [[Float]] = []
        var harmony: [[Float]] = []
        for (number, spec) in specs.enumerated() {
            let sounding = spec.ending ? Int(1.3 * rate) : barLength
            var kit = [Float](repeating: 0, count: sounding + tail)
            var low = [Float](repeating: 0, count: sounding + tail)
            var chords = [Float](repeating: 0, count: sounding + tail)
            var noise = Noise(seed: UInt32(truncatingIfNeeded: 0x2545F491 &+ number &* 7919))
            // The drummer's feel, apart from the drums' own noise so their sound stays the same.
            var feel = Noise(seed: UInt32(truncatingIfNeeded: 0x51ED_270B &+ number &* 104_729))
            // The groove follows the downbeat's chord; each note and stroke then sounds the chord of the change it
            // starts under, and nothing rings across a change.
            let changes = spec.changes.map { $0.beat }.filter { $0 < Double(meter) }
            let chorded = spec.segments.contains { $0.root != nil && !$0.tones.isEmpty }
            let context = BandGroove.Context(meter: meter, bpm: arrangement.bpm, swing: arrangement.swing, fill: spec.fill,
                                             lift: spec.lift, ending: spec.ending, variation: spec.variation,
                                             chord: chorded, fifth: fifth(of: spec.tones))
            let groove = BandGroove.bar(style, context).changing(at: changes)
            let toms = drums(&kit, &low, groove.hits, beat: beat, push: push, number: number, players: players, rate: rate,
                             noise: &noise, feel: &feel)
            var bassed = false
            if arrangement.bass {
                bassed = bassLine(&low, groove.bass, bar: spec, fifth: context.fifth, beat: beat, reference: reference,
                                  players: players, rate: rate)
            }
            var harmonised = false
            if arrangement.pad, chorded {
                harmonised = true
                let comped = comp(&chords, groove.comp, bar: spec, beat: beat, number: number, reference: reference,
                                  players: players, rate: rate, feel: &feel)
                if !comped {
                    // The piano couldn't play the whole bar: the pad holds its chords instead (nothing half-comped).
                    chords = [Float](repeating: 0, count: sounding + tail)
                    padChords(&chords, bar: spec, meter: meter, beat: beat, length: spec.ending ? Int(0.9 * rate) : barLength,
                              reference: reference, rate: rate, table: table)
                }
            }
            RoomReverb.apply(&kit, rate: rate, settings: room)
            RoomReverb.fadeTail(&kit, frames: fade)
            let pitched = toms || bassed
            if pitched {
                RoomReverb.apply(&low, rate: rate, settings: room)
                RoomReverb.fadeTail(&low, frames: fade)
            }
            if harmonised {
                RoomReverb.apply(&chords, rate: rate, settings: room)
                RoomReverb.fadeTail(&chords, frames: fade)
            }
            kits.append(kit)
            lows.append(pitched ? low : [])
            harmony.append(harmonised ? chords : [])
        }
        let ending = specs.count - 1
        kits.append(crashShot(players: players, rate: rate, room: room))
        kits.append(chokeShot(rate: rate))
        return BandTrack(sampleRate: Int(rate), kit: kits, bass: lows, harmony: harmony, sequence: sequence, ending: ending,
                         crash: ending + 1, choke: ending + 2)
    }

    /// The fifth a bass may answer a chord's root with: 7, or 0 (the root again) for a chord without one.
    private static func fifth(of tones: [Int]) -> Int { tones.isEmpty || tones.contains(7) ? 7 : 0 }

    /// The crash a take fires at ×4: the recorded kit's cymbal, else the synthesized one, in the band's room.
    private static func crashShot(players: Players, rate: Double, room: RoomReverb.Settings) -> [Float] {
        var out = [Float](repeating: 0, count: Int(1.8 * rate))
        let piece = BandGroove.Piece.crash.rawValue
        var played = false
        if let kit = players.kit, let samples = players.samples, kit.has(piece: piece) {
            played = samples.addHit(kit, piece: piece, velocity: 0.85, variation: 3, into: &out, start: 0, rate: rate, gain: drumLevel)
        }
        if !played {
            var noise = Noise(seed: 0x0C2A_5B1D)
            crash(&out, at: 0, velocity: 0.85, rate: rate, noise: &noise)
        }
        RoomReverb.apply(&out, rate: rate, settings: room)
        RoomReverb.fadeTail(&out, frames: Int(0.08 * rate))
        return out
    }

    /// A broken run's choked strum: a short scrape of noise in the guitar's middle register over a soft thump, gone
    /// in a tenth of a second. Unpitched, so it never sounds like a wrong note.
    private static func chokeShot(rate: Double) -> [Float] {
        let count = Int(0.14 * rate)
        var out = [Float](repeating: 0, count: count)
        var noise = Noise(seed: 0x7F4A_7C15)
        var highPass = HighPass(cutoff: 650, rate: rate)
        let smooth = exp(-2 * Double.pi * 2600 / rate)
        var low = 0.0
        for i in 0..<count {
            let t = Double(i) / rate
            low = (1 - smooth) * highPass.process(noise.next()) + smooth * low
            let scrape = low * exp(-t / 0.03) * 1.6
            let thump = sin(2 * Double.pi * 95 * t) * exp(-t / 0.025) * 0.45
            out[i] = Float((scrape + thump) * min(1, t / 0.002)) * 0.3
        }
        return out
    }

    // MARK: Parts

    /// The kit: played, not programmed. Every hit within ±8 % of its velocity, everything but the kick and the crash
    /// off the grid by up to ±6 ms; kicks and anything on the downbeat stay exact, so the band stays sample-locked
    /// to the click. The recorded kit when it has the piece (its round robins alternating hit by hit), else synthesized.
    /// The toms go to `toms` (the pitched layer: a tom rings at a pitch the microphone could take for a note); true
    /// when any did.
    private static func drums(_ out: inout [Float], _ toms: inout [Float], _ hits: [BandGroove.Hit], beat: Double, push: Double,
                              number: Int, players: Players, rate: Double, noise: inout Noise, feel: inout Noise) -> Bool {
        var tomsPlayed = false
        for (index, hit) in hits.enumerated() {
            var at = Int((hit.beat * beat).rounded())
            let velocity = hit.velocity * Float(1 + 0.08 * feel.next())
            if hit.beat > 0, hit.piece != .kick, hit.piece != .crash {
                at = max(0, at + Int((push * feel.next()).rounded()))
            }
            let variation = number + index
            if hit.piece == .tomhi || hit.piece == .tomlo {
                tomsPlayed = true
                if !recordedHit(&toms, hit.piece, at: at, velocity: velocity, variation: variation, players: players, rate: rate) {
                    tom(&toms, at: at, hz: hit.piece == .tomhi ? 165 : 110, velocity: velocity, rate: rate)
                }
                continue
            }
            if recordedHit(&out, hit.piece, at: at, velocity: velocity, variation: variation, players: players, rate: rate) {
                continue
            }
            switch hit.piece {
            case .kick: kick(&out, at: at, velocity: velocity, rate: rate)
            case .snare: snare(&out, at: at, velocity: velocity, rate: rate, noise: &noise)
            case .xstick: snare(&out, at: at, velocity: velocity * 0.45, rate: rate, noise: &noise)
            case .hat, .ride: hat(&out, at: at, velocity: velocity, rate: rate, noise: &noise)
            case .tamb: hat(&out, at: at, velocity: velocity * 0.7, rate: rate, noise: &noise)
            case .shaker: hat(&out, at: at, velocity: velocity * 0.5, rate: rate, noise: &noise)
            case .openhat: crash(&out, at: at, velocity: velocity * 0.4, rate: rate, noise: &noise)
            case .crash: crash(&out, at: at, velocity: velocity, rate: rate, noise: &noise)
            case .tomhi, .tomlo: break
            }
        }
        return tomsPlayed
    }

    /// One hit of the recorded kit, when it has the piece and it can be read.
    private static func recordedHit(_ out: inout [Float], _ piece: BandGroove.Piece, at: Int, velocity: Float, variation: Int,
                                    players: Players, rate: Double) -> Bool {
        guard let kit = players.kit, let samples = players.samples, kit.has(piece: piece.rawValue) else { return false }
        return samples.addHit(kit, piece: piece.rawValue, velocity: Double(min(1, velocity)), variation: variation, into: &out,
                              start: at, rate: rate, gain: drumLevel)
    }

    /// The bass line, each note on the root of the chord it starts under (`Bar.segment(at:)`; nothing under no chord):
    /// the recorded bass (each note, then a 60 ms let-go), else the synthesized one. An answer on the fifth stays on the
    /// root under a later chord that has no fifth. True when it played anything.
    private static func bassLine(_ out: inout [Float], _ notes: [BandGroove.Note], bar: BandArrangement.Bar, fifth: Int,
                                 beat: Double, reference: Double, players: Players, rate: Double) -> Bool {
        var played = false
        for note in notes {
            let segment = bar.segment(at: note.beat)
            guard let root = segment.root else { continue }
            var interval = note.interval
            if segment.beat > 0, fifth != 0, interval == fifth, Self.fifth(of: segment.tones) == 0 { interval = 0 }
            let at = Int((note.beat * beat).rounded())
            let length = bar.ending ? min(Int(note.beats * beat), Int(1.1 * rate)) : Int(note.beats * beat)
            let hz = PitchMath.frequency(midi: Double(bassMidi(root) + interval), reference: reference)
            let release = Int(0.06 * rate)
            played = true
            if let set = players.bass, let samples = players.samples, set.covers(hz),
               samples.addNote(set, hz: hz, velocity: bassVelocity * Double(note.velocity), into: &out, start: at,
                               length: length + release, rate: rate, release: 0.06) {
                continue
            }
            bass(&out, at: at, length: length, hz: hz, velocity: note.velocity, rate: rate)
        }
        return played
    }

    /// Roots between F1 and E2, where a bass guitar sits.
    private static func bassMidi(_ root: Int) -> Int {
        let pc = PitchMath.pitchClass(midi: root)
        return pc >= 5 ? 24 + pc : 36 + pc
    }

    /// The bar's chord strokes, each on the chord it starts under (`Bar.segment(at:)`; none under no chord). The piano
    /// rolls its chord low to high a few milliseconds apart, or breaks it one tone at a time over the pedal; the guitar
    /// strums its power chord, its staccato upper voicing or its let-ring chord string by string, down or up (the piano
    /// covers a guitar stroke it can't play). Only off-downbeat strokes move off the grid. False when the piano couldn't
    /// be read (the pad plays instead).
    private static func comp(_ out: inout [Float], _ strokes: [BandGroove.Stroke], bar: BandArrangement.Bar, beat: Double,
                             number: Int, reference: Double, players: Players, rate: Double, feel: inout Noise) -> Bool {
        let hz = { (midi: Int) in PitchMath.frequency(midi: Double(midi), reference: reference) }
        for (index, stroke) in strokes.enumerated() {
            let segment = bar.segment(at: stroke.beat)
            guard let root = segment.root, !segment.tones.isEmpty else { continue }
            let tones = segment.tones
            let chord = padVoicing(root: root, tones: tones).sorted().map(hz)
            var at = Int((stroke.beat * beat).rounded())
            if stroke.beat > 0 { at = max(0, at + Int((0.004 * rate * feel.next()).rounded())) }
            let length = max(1, Int(stroke.beats * beat))
            switch stroke.part {
            case .piano:
                guard piano(&out, chord, at: at, length: length, velocity: stroke.velocity, players: players, rate: rate,
                            feel: &feel) else { return false }
            case .arpeggio:
                let broken = arpeggioVoicing(root: root, tones: tones).map(hz)
                guard let keys = players.keys, let samples = players.samples, !broken.isEmpty else { return false }
                let note = broken[stroke.tone % broken.count]
                guard keys.covers(note) else { return false }
                let velocity = compVelocity * stroke.velocity / 0.6 * (1 + 0.06 * feel.next())
                guard samples.addNote(keys, hz: note, velocity: velocity, into: &out, start: at, length: length + Int(0.3 * rate),
                                      rate: rate, release: 0.3) else { return false }
            case .power, .chop, .ring:
                let voicing: [Int]
                switch stroke.part {
                case .power: voicing = powerVoicing(root: root, tones: tones)
                case .chop: voicing = chopVoicing(root: root, tones: tones)
                default: voicing = ringVoicing(root: root, tones: tones)
                }
                let set = stroke.part == .chop ? players.chops : players.guitar
                let strummed = guitar(&out, voicing.map(hz), stroke: stroke, at: at, length: length, set: set,
                                      seed: UInt64(number * 64 + index), players: players, rate: rate)
                if !strummed {
                    // No guitar recording: the piano plays the stroke, short and a touch softer.
                    guard piano(&out, chord, at: at, length: length, velocity: stroke.velocity * 0.8, players: players,
                                rate: rate, feel: &feel) else { return false }
                }
            }
        }
        return true
    }

    /// The pad under each of the bar's chords, from its change to the next (the last one for `length` frames from the
    /// downbeat).
    private static func padChords(_ out: inout [Float], bar: BandArrangement.Bar, meter: Int, beat: Double, length: Int,
                                  reference: Double, rate: Double, table: Wavetable) {
        let segments = bar.segments.filter { $0.beat < Double(meter) }
        for (index, segment) in segments.enumerated() {
            guard let root = segment.root, !segment.tones.isEmpty else { continue }
            let start = index == 0 ? 0 : Int((segment.beat * beat).rounded())
            let stop = index + 1 < segments.count ? Int((segments[index + 1].beat * beat).rounded()) : length
            let voices = padVoicing(root: root, tones: segment.tones).map { PitchMath.frequency(midi: Double($0), reference: reference) }
            let last = index + 1 == segments.count
            pad(&out, start: start, length: max(1, stop - start), fade: last ? 0.5 : 0.08, frequencies: voices, rate: rate,
                table: table)
        }
    }

    /// The piano's chord at `at`, rolled low to high.
    private static func piano(_ out: inout [Float], _ chord: [Double], at: Int, length: Int, velocity: Double, players: Players,
                              rate: Double, feel: inout Noise) -> Bool {
        guard let keys = players.keys, let samples = players.samples, !chord.isEmpty, chord.allSatisfy({ keys.covers($0) }) else { return false }
        for (rank, hz) in chord.enumerated() {
            let roll = rank == 0 ? 0 : Int((Double(rank) * 0.006 + 0.002 * feel.next()) * rate)
            let touch = compVelocity * velocity / 0.6 * (1 + 0.06 * feel.next())
            guard samples.addNote(keys, hz: hz, velocity: touch, into: &out, start: at + roll,
                                  length: length + Int(0.2 * rate), rate: rate, release: 0.2) else { return false }
        }
        return true
    }

    /// One guitar stroke across `strings` (low to high): a quick pick for a chop, a little slower for a power chord,
    /// slower again for a let-ring chord. False when the guitar can't play it (no recording, out of its range).
    private static func guitar(_ out: inout [Float], _ strings: [Double], stroke: BandGroove.Stroke, at: Int, length: Int,
                               set: SampledInstrument?, seed: UInt64, players: Players, rate: Double) -> Bool {
        guard let set, let samples = players.samples, !strings.isEmpty, strings.allSatisfy({ set.covers($0) }) else { return false }
        let perString = stroke.part == .chop ? 0.005 : stroke.part == .power ? 0.008 : 0.012
        let release = stroke.part == .chop ? 0.03 : stroke.part == .power ? 0.05 : 0.2
        let hits = StrumFeel.hits(strings: strings.count, stroke: stroke.up ? .up : .down,
                                  span: perString * Double(strings.count - 1), velocity: stroke.velocity, seed: seed)
        for hit in hits {
            guard samples.addNote(set, hz: strings[hit.string], velocity: hit.velocity, into: &out,
                                  start: at + Int(hit.delay * rate), length: length + Int(release * rate), rate: rate,
                                  release: release, gain: guitarLevel) else { return false }
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

    /// A broken chord for the left and right hands: the root between C3 and B3, then the close voicing above it.
    private static func arpeggioVoicing(root: Int, tones: [Int]) -> [Int] {
        let bass = 48 + PitchMath.pitchClass(midi: root)
        return [bass] + padVoicing(root: root, tones: tones).sorted().filter { $0 > bass }
    }

    /// The fifth a power chord stacks on its root: the chord's own (diminished and augmented chords keep theirs).
    private static func powerFifth(_ tones: [Int]) -> Int {
        if tones.contains(7) { return 7 }
        return tones.first { $0 == 6 || $0 == 8 } ?? 7
    }

    /// Root, fifth and octave on the guitar's low strings (the root between E2 and D#3).
    private static func powerVoicing(root: Int, tones: [Int]) -> [Int] {
        let low = 40 + (PitchMath.pitchClass(midi: root) - 4 + 12) % 12
        return [low, low + powerFifth(tones), low + 12]
    }

    /// The chord's tones on the top strings, between D4 and D5: a skank's, a chick's or a scratch's voicing.
    private static func chopVoicing(root: Int, tones: [Int]) -> [Int] {
        var midis: [Int] = []
        for tone in tones {
            var midi = 60 + PitchMath.pitchClass(midi: root) + tone
            while midi > 74 { midi -= 12 }
            while midi < 62 { midi += 12 }
            if !midis.contains(midi) { midis.append(midi) }
        }
        return midis.sorted()
    }

    /// An open, ringing chord: the power chord with the rest of the chord's tones above it.
    private static func ringVoicing(root: Int, tones: [Int]) -> [Int] {
        let power = powerVoicing(root: root, tones: tones)
        let top = padVoicing(root: root, tones: tones).filter { $0 > power[2] && !power.contains($0) }
        return (power + top).sorted()
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

    /// A tom: a sine that drops a little from its strike pitch to `hz`.
    private static func tom(_ out: inout [Float], at start: Int, hz: Double, velocity: Float, rate: Double) {
        let count = min(Int(0.4 * rate), out.count - start)
        guard start >= 0, count > 0 else { return }
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / rate
            phase += 2 * Double.pi * hz * (1 + 0.35 * exp(-t / 0.04)) / rate
            let envelope = min(1, t / 0.002) * exp(-t / 0.16)
            out[start + i] += Float(sin(phase) * envelope) * 0.4 * velocity
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
    /// From `start`, for `length` frames; `fade` seconds of release (short where the next chord takes over).
    private static func pad(_ out: inout [Float], start: Int, length: Int, fade: Double, frequencies: [Double], rate: Double,
                            table: Wavetable) {
        let attack = 0.25 * rate
        let release = Int(fade * rate)
        let count = min(length + release, out.count - start)
        guard start >= 0, length > 0, count > 0 else { return }
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
                    out[start + i] += table.sample(phase) * Float(envelope) * 0.03
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
