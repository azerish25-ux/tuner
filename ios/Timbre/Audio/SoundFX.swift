import AVFoundation
import TimbreCore

/// Preparation may suspend; the ambient-only decision and actual player work must then execute contiguously on
/// MainActor. A competing engine's intent is visible synchronously, before it begins asynchronous session work.
@MainActor
enum InterfaceSoundPlayback {
    static func play(ambientOnly: Bool, prepare: @MainActor () async -> Void,
                     ambientAllowed: @MainActor () -> Bool, action: @MainActor () -> Void) async {
        await prepare()
        guard !ambientOnly || ambientAllowed() else { return }
        action()
    }
}

/// Short interface sounds (right answer, wrong answer, star, count-in click, lock), synthesized once on
/// device: Karplus–Strong plucks for notes, soft harmonic bells for rewards, a two-mode woodblock for clicks,
/// the musical ones in a light baked-in room (`RoomReverb`). They play through AVAudioPlayer so they never
/// interrupt the microphone capture, and stay quiet. Between engines they play in the ambient session the owner keeps
/// for them (`AudioSessionOwner.prepareInterfaceSound`): opening Timbre never stops the user's music or podcast, and
/// once the tuner has stopped, the chimes keep to the Ring/Silent switch.
///
/// The rewards speak the music they reward: a lock rings the string's own pitch (`playLock`), the whole instrument
/// in tune strums its own open strings (`playTuned`), and a lesson's stars ring the triad of its key (`playStar`).
/// `motif` is Timbre's three-note signature (a fifth that resolves to the octave), for welcome, Pro and level-up.
@MainActor
final class SoundFX {
    static let shared = SoundFX()
    typealias Cue = SoundCue
    var enabled = true
    private var players: [Cue: AVAudioPlayer] = [:]
    /// Lock bells by pitch (tenths of a hertz), rendered once per string pitch.
    private var bells: [Int: AVAudioPlayer] = [:]
    /// Star bells by MIDI note, rendered once per note of a key's triad.
    private var stars: [Int: AVAudioPlayer] = [:]
    /// Miss wobbles by pitch (tenths of a hertz), rendered once per pitch.
    private var wobbles: [Int: AVAudioPlayer] = [:]
    /// The full-tune strum of the strings last prepared (their pitches as a key) and its player.
    private var tuned: (key: String, player: AVAudioPlayer)?

    private init() {
        // Before any player is prepared (preparing one can activate the session): ambient, so the app's first sound
        // (the welcome motif) mixes with whatever the user is listening to.
        Task { await AudioSessionOwner.shared.prepareInterfaceSound() }
        // Render every cue off the main thread; a cue asked for before then renders on the spot.
        Task.detached(priority: .utility) { [weak self] in
            let rendered = Cue.allCases.map { ($0, SoundSynth.wav(SoundSynth.render($0), rate: SoundSynth.rate)) }
            await self?.install(rendered)
        }
    }

    private func install(_ rendered: [(Cue, Data)]) {
        for (cue, data) in rendered where players[cue] == nil { players[cue] = Self.player(data, volume: Self.volume(cue)) }
    }

    func play(_ cue: Cue) { play(cue, ambientOnly: false) }

    private func play(_ cue: Cue, ambientOnly: Bool) {
        guard enabled else { return }
        if players[cue] == nil { players[cue] = Self.player(SoundSynth.wav(SoundSynth.render(cue), rate: SoundSynth.rate), volume: Self.volume(cue)) }
        start(players[cue], ambientOnly: ambientOnly)
    }

    /// The welcome: Timbre's motif, played only in the ambient session (`AudioSessionOwner.interfaceSoundMayPlayNow`), so
    /// it mixes with whatever the user is listening to and keeps to the Ring/Silent switch. While an engine holds the
    /// session (the microphone, a lesson's sound) it stays silent rather than sound through it.
    func playWelcome() {
        play(.motif, ambientOnly: true)
    }

    /// A miss near `frequency`: the wobble (two soft bells a few hertz apart, beating like a string just off its note)
    /// at that pitch, raised an octave at a time while it is too low for a phone speaker, so the miss sounds near the
    /// note aimed at. Cached per pitch, like the lock bells.
    func playWobble(frequency: Double) {
        guard enabled, let hz = SoundSynth.bellPitch(frequency) else { return }
        let key = Self.bellKey(hz)
        if wobbles[key] == nil {
            if wobbles.count >= 32 { wobbles.removeAll() }
            wobbles[key] = Self.player(SoundSynth.wav(SoundSynth.wobble(hz), rate: SoundSynth.rate), volume: Self.volume(.wobble))
        }
        start(wobbles[key])
    }

    /// Plays from the top, in the session the app's own sounds share.
    private func start(_ player: AVAudioPlayer?, ambientOnly: Bool = false) {
        guard let player else { return }
        Task { @MainActor in
            await InterfaceSoundPlayback.play(ambientOnly: ambientOnly,
                prepare: { await AudioSessionOwner.shared.prepareInterfaceSound() },
                ambientAllowed: { AudioSessionOwner.shared.interfaceSoundMayPlayNow() }) {
                    guard self.enabled else { return }
                    player.prepareToPlay()
                    player.currentTime = 0
                    player.play()
                }
        }
    }

    /// The lock "ding": a plucked harmonic at the pitch of the string just tuned, raised an octave at a time
    /// while it is too low for a phone speaker. Cached per pitch, so the next lock of that string is instant.
    func playLock(frequency: Double) {
        guard enabled, let hz = SoundSynth.bellPitch(frequency) else { return }
        let key = Self.bellKey(hz)
        if bells[key] == nil { installBell(SoundSynth.wav(SoundSynth.bell(hz), rate: SoundSynth.rate), key: key) }
        start(bells[key])
    }

    /// The lock bell for a MIDI note at A4 = 440 Hz.
    func playLock(midi: Int) { playLock(frequency: SoundSynth.hz(midi)) }

    /// Renders the lock bells of these strings in the background, so the first lock never waits on synthesis.
    func prepareLocks(_ frequencies: [Double]) {
        let missing = Array(Set(frequencies.compactMap(SoundSynth.bellPitch).filter { bells[Self.bellKey($0)] == nil }))
        guard !missing.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            let rendered = missing.map { ($0, SoundSynth.wav(SoundSynth.bell($0), rate: SoundSynth.rate)) }
            await self?.installBells(rendered)
        }
    }

    private func installBells(_ rendered: [(Double, Data)]) {
        for (hz, data) in rendered where bells[Self.bellKey(hz)] == nil { installBell(data, key: Self.bellKey(hz)) }
    }

    private func installBell(_ data: Data, key: Int) {
        if bells.count >= 64 { bells.removeAll() }
        bells[key] = Self.player(data, volume: 0.32)
    }

    private static func bellKey(_ hz: Double) -> Int { Int((hz * 10).rounded()) }

    // MARK: The whole instrument in tune

    /// Every string in tune: the instrument's own open strings (`frequencies`, in string order), rolled one by one
    /// with each string's bell, then strummed together and left to ring (`SoundSynth.tuned`). E standard ends on
    /// E standard, a GCEA ukulele on GCEA. Rendered ahead by `prepareTuned`, else on the spot.
    func playTuned(frequencies: [Double]) {
        guard enabled, !frequencies.isEmpty else { return }
        let key = Self.tunedKey(frequencies)
        if tuned?.key != key, let player = Self.player(SoundSynth.wav(SoundSynth.tuned(frequencies), rate: SoundSynth.rate), volume: Self.tunedVolume) {
            tuned = (key, player)
        }
        start(tuned?.player)
    }

    /// Renders the full-tune strum for these strings in the background, so the last lock never waits on synthesis.
    func prepareTuned(_ frequencies: [Double]) {
        let key = Self.tunedKey(frequencies)
        guard !frequencies.isEmpty, tuned?.key != key else { return }
        Task.detached(priority: .utility) { [weak self] in
            let data = SoundSynth.wav(SoundSynth.tuned(frequencies), rate: SoundSynth.rate)
            await self?.installTuned(data, key: key)
        }
    }

    private func installTuned(_ data: Data, key: String) {
        guard tuned?.key != key, let player = Self.player(data, volume: Self.tunedVolume) else { return }
        tuned = (key, player)
    }

    private static let tunedVolume: Float = 0.42

    private static func tunedKey(_ frequencies: [Double]) -> String {
        frequencies.map { String(Int(($0 * 10).rounded())) }.joined(separator: ",")
    }

    // MARK: Stars in the key

    /// Star `index` (0, 1, 2, then badges) as a bell on the next note of the key's triad: 1, 3, 5, then the octave.
    /// Without a key, C major.
    func playStar(_ index: Int, key: RewardKey?) {
        guard enabled else { return }
        let midi = (key ?? .neutral).starMidi(index)
        if stars[midi] == nil { installStar(SoundSynth.wav(SoundSynth.starBell(SoundSynth.hz(midi)), rate: SoundSynth.rate), midi: midi) }
        start(stars[midi])
    }

    /// Renders a key's star bells in the background as a results screen opens.
    func prepareStars(_ key: RewardKey?) {
        let notes = (0..<4).map { (key ?? .neutral).starMidi($0) }.filter { stars[$0] == nil }
        guard !notes.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            let rendered = notes.map { ($0, SoundSynth.wav(SoundSynth.starBell(SoundSynth.hz($0)), rate: SoundSynth.rate)) }
            await self?.installStars(rendered)
        }
    }

    private func installStars(_ rendered: [(Int, Data)]) {
        for (midi, data) in rendered where stars[midi] == nil { installStar(data, midi: midi) }
    }

    private func installStar(_ data: Data, midi: Int) {
        if stars.count >= 24 { stars.removeAll() }
        stars[midi] = Self.player(data, volume: 0.36)
    }

    private static func player(_ data: Data, volume: Float) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.volume = volume
        return player
    }

    private static func volume(_ cue: Cue) -> Float {
        switch cue {
        case .click, .accent: return 0.5
        case .hit: return 0.32
        case .wrong, .near, .wobble: return 0.3
        case .xpTick: return 0.16
        case .motif, .streak: return 0.4
        default: return 0.36
        }
    }
}

/// The interface sounds `SoundFX` plays (kept outside the main-actor class so they render off the main thread).
enum SoundCue: CaseIterable, Sendable {
    case correct, wrong, star, click, accent, complete, hit
    /// A level reached: a rising roll into the motif.
    case levelUp
    /// Timbre's signature: a fifth resolving to the octave, plucked and belled (welcome, Pro unlocked).
    case motif
    /// One step of an XP count: a soft tick.
    case xpTick
    /// A streak milestone: a warm chord swelling up like a stage lamp coming on, a rising sixth over it.
    case streak
    /// A right answer in an ear drill, with no pitch of its own to colour the next question: two knocks of a
    /// woodblock over a brush.
    case earCorrect
    /// Nearly (a game's near miss): one soft, muted knock.
    case near
    /// A miss: two soft tones a few hertz apart, beating like a string out of tune.
    case wobble
}

/// The key a lesson's music sits in, so its stars ring that key's triad.
struct RewardKey: Equatable, Sendable {
    /// Pitch class, 0 = C.
    var tonic: Int
    var minor: Bool

    static let neutral = RewardKey(tonic: 0, minor: false)

    /// Star `index` as a MIDI note in a bright register: the root (C5…B5), the third, the fifth, then the octave.
    func starMidi(_ index: Int) -> Int {
        let root = 72 + ((tonic % 12) + 12) % 12
        let degrees = [0, minor ? 3 : 4, 7, 12]
        return root + degrees[min(max(0, index), degrees.count - 1)]
    }

    /// The key of the music a lesson plays (its notes and chords, `KeyEstimate`); nil for a lesson with neither.
    static func of(_ lesson: Lesson) -> RewardKey? {
        var notes: [TimedNote] = []
        var chords: [(chord: ChordSpec, bars: Int)] = []
        for step in lesson.steps {
            switch step {
            case let .playNotes(list, _):
                notes += list
            case let .playAlong(list, _, _, _):
                notes += list
            case let .playChord(chord):
                chords.append((chord: chord, bars: 1))
            case let .strum(chord, _, _, bars, _, _, _):
                if let chord { chords.append((chord: chord, bars: max(1, bars))) }
            case let .progression(list, bars, _, _, _, _, _):
                for (index, chord) in list.enumerated() {
                    chords.append((chord: chord, bars: index < bars.count ? max(1, bars[index]) : 1))
                }
            default:
                break
            }
        }
        guard let key = KeyEstimate.key(of: notes, chords: chords) else { return nil }
        return RewardKey(tonic: key.tonic, minor: key.minor)
    }
}

/// Offline synthesis for `SoundFX`: pure functions over sample buffers, normalised to a gentle peak.
enum SoundSynth {
    static let rate = 44_100
    /// Lock bells below this are raised an octave (E2 → E3, bass E1 → E3).
    static let lowestBell = 140.0

    static func hz(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    /// The bell's pitch for a string: its own, an octave up at a time while below `lowestBell`.
    static func bellPitch(_ frequency: Double) -> Double? {
        guard frequency.isFinite, frequency > 1 else { return nil }
        var hz = frequency
        while hz < lowestBell { hz *= 2 }
        return min(hz, 4_000)
    }

    /// A cue as it plays: the dry voice in a small warm room (click and accent stay dry, they keep time).
    static func render(_ cue: SoundCue) -> [Float] {
        let dry = voice(cue)
        let wet = room(cue)
        return wet > 0 ? reverberant(dry, wet: wet) : dry
    }

    /// How much room each cue gets (reverb level against the dry sound, at most 20 %).
    private static func room(_ cue: SoundCue) -> Float {
        switch cue {
        case .click, .accent, .xpTick: return 0
        case .hit, .near: return 0.07
        case .earCorrect: return 0.08
        case .wrong, .wobble: return 0.1
        case .correct: return 0.14
        case .star, .complete: return 0.17
        case .levelUp, .motif, .streak: return 0.2
        }
    }

    /// The sound with a short tail appended and a light room mixed under it, brought back to its own peak
    /// so the cue's loudness doesn't change.
    static func reverberant(_ dry: [Float], wet: Float, tail: Double = 0.5) -> [Float] {
        let peak = dry.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0 else { return dry }
        var out = dry
        out.append(contentsOf: [Float](repeating: 0, count: Int(tail * Double(rate))))
        RoomReverb.apply(&out, rate: Double(rate), settings: RoomReverb.Settings(wet: wet))
        RoomReverb.fadeTail(&out, frames: Int(0.12 * Double(rate)))
        return normalised(out, peak: peak)
    }

    private static func voice(_ cue: SoundCue) -> [Float] {
        switch cue {
        case .correct:
            // Two bright plucks a sixth apart, the second ringing with a bell partial on top.
            var b = buffer(0.75)
            pluck(&b, hz: hz(76), at: 0, length: 0.4, gain: 0.8, brightness: 0.75, sustain: 0.6)
            pluck(&b, hz: hz(83), at: 0.075, length: 0.65, gain: 0.85, brightness: 0.8, sustain: 0.8)
            chime(&b, hz: hz(83), at: 0.075, length: 0.6, gain: 0.22)
            return normalised(b, peak: 0.55)
        case .wrong:
            // A soft, muted low pluck stepping down: a gentle "not quite", never a buzzer.
            var b = buffer(0.5)
            pluck(&b, hz: hz(50), at: 0, length: 0.22, gain: 0.9, brightness: 0.35, sustain: 0.18)
            pluck(&b, hz: hz(47), at: 0.1, length: 0.32, gain: 0.8, brightness: 0.3, sustain: 0.22)
            return normalised(b, peak: 0.45)
        case .star:
            // A sparkle: three bells rising through a major triad.
            var b = buffer(1.1)
            for (i, midi) in [84, 88, 91].enumerated() {
                chime(&b, hz: hz(midi), at: Double(i) * 0.07, length: 0.9 - Double(i) * 0.1, gain: 0.7, shimmer: true)
            }
            return normalised(b, peak: 0.5)
        case .click:
            var b = buffer(0.07)
            woodblock(&b, modes: [(1_960, 140, 1), (3_120, 220, 0.45), (900, 110, 0.3)])
            return normalised(b, peak: 0.5)
        case .accent:
            var b = buffer(0.09)
            woodblock(&b, modes: [(2_640, 120, 1), (4_180, 190, 0.4), (1_250, 95, 0.35)])
            return normalised(b, peak: 0.62)
        case .complete:
            // A plucked arpeggio that lands on a ringing bell.
            var b = buffer(1.6)
            for (i, midi) in [72, 76, 79].enumerated() {
                pluck(&b, hz: hz(midi), at: Double(i) * 0.095, length: 0.7, gain: 0.7, brightness: 0.65, sustain: 0.7)
            }
            pluck(&b, hz: hz(84), at: 0.285, length: 1.2, gain: 0.75, brightness: 0.7, sustain: 1)
            chime(&b, hz: hz(84), at: 0.285, length: 1.25, gain: 0.35, shimmer: true)
            return normalised(b, peak: 0.55)
        case .hit:
            // A short soft mallet: fundamental plus the marimba's tuned fourth partial.
            var b = buffer(0.2)
            mallet(&b, hz: hz(84), length: 0.18)
            return normalised(b, peak: 0.45)
        case .levelUp:
            // A soft rising roll that lands on the motif, its octave crowned with a shimmer.
            var b = buffer(2.3)
            for (i, midi) in [60, 64, 67].enumerated() {
                pluck(&b, hz: hz(midi), at: Double(i) * 0.06, length: 0.6, gain: 0.45, brightness: 0.6, sustain: 0.6)
            }
            motif(&b, at: 0.2, gain: 1)
            chime(&b, hz: hz(91), at: 0.56, length: 1.4, gain: 0.18, shimmer: true)
            return normalised(b, peak: 0.55)
        case .motif:
            var b = buffer(2.1)
            motif(&b, at: 0, gain: 1)
            return normalised(b, peak: 0.55)
        case .xpTick:
            // A soft, high tick: a counter's detent, quieter than any click that keeps time.
            var b = buffer(0.03)
            woodblock(&b, modes: [(4_400, 320, 1), (6_300, 460, 0.35)])
            return normalised(b, peak: 0.32)
        case .streak:
            // The lamp comes on: a warm G6 chord swells up under a plucked rising sixth that rings on as a bell.
            var b = buffer(2.4)
            for midi in [55, 62, 67, 71, 76] {
                swell(&b, hz: hz(midi), at: 0, length: 2.2, gain: 0.28)
            }
            pluck(&b, hz: hz(74), at: 0.22, length: 0.7, gain: 0.6, brightness: 0.65, sustain: 0.7)
            pluck(&b, hz: hz(83), at: 0.4, length: 1.6, gain: 0.65, brightness: 0.7, sustain: 1.3)
            chime(&b, hz: hz(83), at: 0.404, length: 1.6, gain: 0.32)
            return normalised(b, peak: 0.55)
        case .earCorrect:
            // Tok-tok over a brush: rhythm without pitch, so the ear stays on the question's notes.
            var b = buffer(0.36)
            brush(&b, at: 0, length: 0.22, gain: 0.25)
            woodblock(&b, modes: [(820, 60, 1), (1_420, 110, 0.4)], at: 0.01)
            woodblock(&b, modes: [(820, 60, 0.9), (1_420, 110, 0.35)], at: 0.13)
            return normalised(b, peak: 0.5)
        case .near:
            var b = buffer(0.16)
            woodblock(&b, modes: [(640, 70, 1), (1_180, 140, 0.3)])
            return normalised(b, peak: 0.4)
        case .wobble:
            return wobbleVoice(hz(57))
        }
    }

    /// The miss's wobble, dry: two soft bells 7 Hz apart at `pitch`, the beating of a string just off its note.
    private static func wobbleVoice(_ pitch: Double) -> [Float] {
        var b = buffer(0.8)
        chime(&b, hz: pitch, at: 0, length: 0.7, gain: 0.5)
        chime(&b, hz: pitch + 7, at: 0, length: 0.7, gain: 0.5)
        return normalised(b, peak: 0.4)
    }

    /// The wobble at `pitch` as it plays, in the room every wobble gets (`SoundFX.playWobble`).
    static func wobble(_ pitch: Double) -> [Float] {
        reverberant(wobbleVoice(pitch), wet: room(.wobble))
    }

    /// The motif: a plucked fifth that resolves to the octave (C5, G5, C6), each note with its bell, the last ringing
    /// over a soft low C. Timbre's three-note signature.
    static func motif(_ out: inout [Float], at start: Double, gain: Float) {
        let notes: [(midi: Int, at: Double, length: Double)] = [(72, 0, 0.55), (79, 0.15, 0.65), (84, 0.32, 1.6)]
        for note in notes {
            let time = start + note.at
            pluck(&out, hz: hz(note.midi), at: time, length: note.length, gain: 0.6 * gain, brightness: 0.7, sustain: note.length)
            chime(&out, hz: hz(note.midi), at: time + 0.004, length: note.length + 0.1, gain: 0.34 * gain)
        }
        pluck(&out, hz: hz(60), at: start + 0.32, length: 1.6, gain: 0.32 * gain, brightness: 0.45, sustain: 1.4)
    }

    // MARK: The whole instrument in tune

    /// Seconds between strings as the full-tune strum rolls across them: slow enough on six strings to hear each one
    /// ring with its bell, quicker on a twelve-string so the roll stays under a second.
    static func tunedRoll(count: Int) -> Double { min(0.12, 0.72 / Double(max(1, count))) }

    /// When the roll's strings are struck together again and left to bloom.
    static func tunedBloom(count: Int) -> Double { Double(max(1, count)) * tunedRoll(count: count) + 0.12 }

    /// The full-tune strum, from the strings' own pitches in string order (`SoundFX.playTuned`): each string plucked
    /// in turn with its lock bell, then all of them strummed at once and left to ring, the top string's octave as a
    /// light over it. Strings too low for a phone's speaker sound an octave up at a time, as the lock bells do.
    static func tuned(_ frequencies: [Double]) -> [Float] {
        let strings = frequencies.map(strumPitch)
        let count = strings.count
        let roll = tunedRoll(count: count)
        let bloom = tunedBloom(count: count)
        var b = buffer(bloom + 2.3)
        for (i, hz) in strings.enumerated() {
            let at = Double(i) * roll
            // Rings until the bloom strikes this string again.
            let length = bloom + Double(i) * 0.016 - at + 0.03
            pluck(&b, hz: hz, at: at, length: length, gain: 0.5, brightness: 0.62, sustain: 1.4)
            if let bell = bellPitch(hz) { chime(&b, hz: bell, at: at + 0.004, length: 1.2, gain: 0.2) }
        }
        for (i, hz) in strings.enumerated() {
            pluck(&b, hz: hz, at: bloom + Double(i) * 0.016, length: 2.1, gain: 0.52, brightness: 0.7, sustain: 1.7)
        }
        if let top = strings.max(), let light = bellPitch(top * 2) {
            chime(&b, hz: light, at: bloom + 0.06, length: 1.9, gain: 0.24, shimmer: true)
        }
        return reverberant(normalised(b, peak: 0.55), wet: 0.2)
    }

    /// A string's pitch for the strum: an octave up at a time while it is below what a phone's speaker plays.
    private static func strumPitch(_ frequency: Double) -> Double {
        guard frequency.isFinite, frequency > 1 else { return 110 }
        var hz = frequency
        while hz < 70 { hz *= 2 }
        return min(hz, 2_000)
    }

    /// A reward star's bell: a bright harmonic bell with a glint on top, in the results' room.
    static func starBell(_ hz: Double) -> [Float] {
        var b = buffer(1.2)
        chime(&b, hz: hz, at: 0, length: 1.1, gain: 0.75, shimmer: true)
        chime(&b, hz: hz * 2, at: 0.012, length: 0.5, gain: 0.12)
        return reverberant(normalised(b, peak: 0.5), wet: 0.17)
    }

    /// The lock bell: a pluck for the attack and a harmonic bell that rings on, like a natural harmonic.
    /// Its partials are whole multiples of `hz`, so it reads as exactly that pitch.
    static func bell(_ hz: Double) -> [Float] {
        var b = buffer(1.3)
        pluck(&b, hz: hz, at: 0, length: 0.5, gain: 0.45, brightness: 0.6, sustain: 0.35)
        chime(&b, hz: hz, at: 0.004, length: 1.25, gain: 0.8)
        return reverberant(normalised(b, peak: 0.5), wet: 0.14)
    }

    // MARK: Voices

    static func buffer(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: Int(seconds * Double(rate))) }

    /// Karplus–Strong: a noise burst circulating in a delay line one period long, softened each pass by a
    /// two-point average and tuned exactly with a first-order all-pass. `sustain` is roughly seconds to fade 60 dB
    /// at the fundamental; `brightness` (0...1) shapes the pick (darker = softer, rounder).
    static func pluck(_ out: inout [Float], hz: Double, at start: Double, length: Double, gain: Float, brightness: Double, sustain: Double) {
        guard hz > 20, hz < Double(rate) / 4 else { return }
        let period = Double(rate) / hz
        let whole = max(2, Int(period - 0.5 - 0.1))
        let fraction = period - 0.5 - Double(whole)          // all-pass delay, 0.1...1.1 samples
        let coefficient = Float((1 - fraction) / (1 + fraction))
        let loss = Float(pow(0.001, 1 / max(0.05, sustain) / hz))   // per pass, so the fundamental fades 60 dB in `sustain`
        var noise = SystemNoise(seed: UInt64(hz * 1000))
        var line = [Float](repeating: 0, count: whole)
        var low: Float = 0
        let smoothing = Float(0.15 + 0.8 * (1 - max(0, min(1, brightness))))
        for i in 0..<whole {
            low += (noise.next() - low) * (1 - smoothing)
            line[i] = low
        }
        // No DC in the loop: it would otherwise linger as a slow thump.
        let mean = line.reduce(0, +) / Float(whole)
        for i in 0..<whole { line[i] -= mean }
        let first = Int(start * Double(rate))
        let count = min(Int(length * Double(rate)), out.count - first)
        guard count > 0 else { return }
        let fade = Int(0.03 * Double(rate))
        var index = 0
        var previous: Float = 0, apIn: Float = 0, apOut: Float = 0
        for n in 0..<count {
            let current = line[index]
            var envelope: Float = 1
            if n > count - fade { envelope = Float(count - n) / Float(fade) }
            out[first + n] += current * gain * envelope
            let averaged = loss * 0.5 * (current + previous)
            let tuned = coefficient * averaged + apIn - coefficient * apOut
            apIn = averaged; apOut = tuned
            line[index] = tuned
            previous = current
            index += 1
            if index == whole { index = 0 }
        }
    }

    /// A soft bell from harmonic partials (each decaying faster than the one below); `shimmer` adds a faint
    /// inharmonic glint for celebration cues. Partials use recursive oscillators, so a bell costs little.
    static func chime(_ out: inout [Float], hz: Double, at start: Double, length: Double, gain: Float, shimmer: Bool = false) {
        var partials: [(ratio: Double, amplitude: Double, sustain: Double)] = [
            (1, 1, 1.2), (2, 0.42, 0.8), (3, 0.2, 0.55), (4, 0.11, 0.4), (5, 0.06, 0.3), (6, 0.035, 0.25),
        ]
        if shimmer { partials.append((2.76, 0.07, 0.35)); partials.append((5.4, 0.035, 0.2)) }
        let first = Int(start * Double(rate))
        let count = min(Int(length * Double(rate)), out.count - first)
        guard count > 0 else { return }
        let attack = 0.003 * Double(rate)
        let fade = Int(0.04 * Double(rate))
        for partial in partials {
            let frequency = hz * partial.ratio
            guard frequency < Double(rate) / 2.2 else { continue }
            let omega = 2 * Double.pi * frequency / Double(rate)
            let step = 2 * cos(omega)
            var y1 = 0.0, y2 = -sin(omega)        // sin(0) and sin(-ω): a unit sine from n = 0
            let decay = pow(0.001, 1 / (partial.sustain * Double(rate)))
            var level = partial.amplitude * Double(gain)
            for n in 0..<count {
                let y = step * y1 - y2
                y2 = y1; y1 = y
                var envelope = min(1, Double(n) / attack)
                if n > count - fade { envelope *= Double(count - n) / Double(fade) }
                out[first + n] += Float(y2 * level * envelope)
                level *= decay
            }
        }
    }

    /// A short mallet: fundamental, the marimba's fourth partial and a click of the bar.
    static func mallet(_ out: inout [Float], hz: Double, length: Double) {
        let count = min(Int(length * Double(rate)), out.count)
        for (ratio, amplitude, sustain) in [(1.0, 1.0, 0.16), (4.0, 0.3, 0.05), (9.9, 0.08, 0.02)] {
            let frequency = hz * ratio
            guard frequency < Double(rate) / 2.2 else { continue }
            let omega = 2 * Double.pi * frequency / Double(rate)
            let decay = pow(0.001, 1 / (sustain * Double(rate)))
            var level = amplitude
            for n in 0..<count {
                let envelope = min(1, Double(n) / (0.0015 * Double(rate)))
                out[n] += Float(sin(omega * Double(n)) * level * envelope)
                level *= decay
            }
        }
    }

    /// A woodblock: a few fast-decaying resonant modes (hertz, decay per second, level) struck by a sub-millisecond
    /// noise tick, `start` seconds in.
    static func woodblock(_ out: inout [Float], modes: [(Double, Double, Double)], at start: Double = 0) {
        let first = max(0, Int(start * Double(rate)))
        let count = out.count - first
        guard count > 0 else { return }
        var noise = SystemNoise(seed: 7)
        let tick = Int(0.0008 * Double(rate))
        for n in 0..<min(tick, count) { out[first + n] += noise.next() * 0.35 * Float(1 - Double(n) / Double(tick)) }
        for (frequency, damping, amplitude) in modes {
            let omega = 2 * Double.pi * frequency / Double(rate)
            for n in 0..<count {
                let t = Double(n) / Double(rate)
                out[first + n] += Float(amplitude * exp(-damping * t) * sin(omega * Double(n)) * min(1, t / 0.0004))
            }
        }
    }

    /// A slow swell: a few harmonic partials that rise over a fifth of a second and fade over `length` (a lamp
    /// warming up rather than a string struck).
    static func swell(_ out: inout [Float], hz: Double, at start: Double, length: Double, gain: Float) {
        let first = max(0, Int(start * Double(rate)))
        let count = min(Int(length * Double(rate)), out.count - first)
        guard count > 0 else { return }
        let rise = 0.2 * Double(rate)
        let fade = Double(count)
        for (ratio, amplitude) in [(1.0, 1.0), (2.0, 0.3), (3.0, 0.12)] {
            let frequency = hz * ratio
            guard frequency < Double(rate) / 2.2 else { continue }
            let omega = 2 * Double.pi * frequency / Double(rate)
            for n in 0..<count {
                let x = Double(n)
                let envelope = min(1, x / rise) * pow(1 - x / fade, 2)
                out[first + n] += Float(sin(omega * x) * amplitude * envelope) * gain
            }
        }
    }

    /// A brush: soft noise with a quick swell and fall, darkened by a one-pole low-pass (no pitch of its own).
    static func brush(_ out: inout [Float], at start: Double, length: Double, gain: Float) {
        let first = max(0, Int(start * Double(rate)))
        let count = min(Int(length * Double(rate)), out.count - first)
        guard count > 0 else { return }
        var noise = SystemNoise(seed: 11)
        var low: Float = 0
        let peak = Double(count) * 0.25
        for n in 0..<count {
            let x = Double(n)
            let envelope = x < peak ? x / peak : pow(1 - (x - peak) / (Double(count) - peak), 2)
            low += (noise.next() - low) * 0.35
            out[first + n] += low * Float(envelope) * gain
        }
    }

    static func normalised(_ samples: [Float], peak: Float) -> [Float] {
        let largest = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard largest > 0 else { return samples }
        let scale = peak / largest
        return samples.map { $0 * scale }
    }

    static func wav(_ samples: [Float], rate: Int) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes)); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(rate)); append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(bytes))
        for sample in samples { append(Int16(max(-1, min(1, sample)) * Float(Int16.max))) }
        return data
    }
}

/// A small, warm room for offline renders (cues and the lesson band): Schroeder–Freeverb, eight damped
/// comb filters in parallel into four all-passes in series, mono. The send is high-passed so kicks and bass
/// stay dry, a short pre-delay keeps every attack clean, and the wet level is set against the dry sound's
/// energy, so `wet` means the same on a click and on a chord. Runs once per render, never in real time.
enum RoomReverb {
    struct Settings: Sendable {
        /// Reverb against the dry sound, by energy; capped at 20 %.
        var wet: Float
        /// Comb feedback: 0.8 fades 60 dB in under a second (a short tail).
        var feedback: Float = 0.8
        /// High frequencies fade faster in the tail (0 bright … 1 dark).
        var damping: Float = 0.35
        /// Nothing below this reaches the room (hertz).
        var lowCut: Double = 180
        /// Seconds between the dry attack and the room.
        var preDelay: Double = 0.012
    }

    /// Freeverb's delay lengths at 44.1 kHz (mutually prime, so the echoes never line up).
    private static let combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private static let allPasses = [556, 441, 341, 225]

    static func apply(_ samples: inout [Float], rate: Double, settings: Settings) {
        let wet = min(0.2, max(0, settings.wet))
        guard wet > 0, samples.count > 1, rate > 0 else { return }
        let scale = rate / 44_100
        let count = samples.count
        // The send: one-pole high-pass, at Freeverb's fixed input gain.
        var send = [Float](repeating: 0, count: count)
        let rc = 1 / (2 * Double.pi * max(20, settings.lowCut))
        let a = Float(rc / (rc + 1 / rate))
        var lastIn: Float = 0, lastOut: Float = 0
        for i in 0..<count {
            lastOut = a * (lastOut + samples[i] - lastIn)
            lastIn = samples[i]
            send[i] = lastOut * 0.015
        }
        var room = [Float](repeating: 0, count: count)
        let feedback = min(0.95, max(0, settings.feedback))
        let damping = min(0.95, max(0, settings.damping))
        for tuning in combs {
            let size = max(1, Int((Double(tuning) * scale).rounded()))
            var line = [Float](repeating: 0, count: size)
            var index = 0
            var low: Float = 0
            for i in 0..<count {
                let out = line[index]
                low = out * (1 - damping) + low * damping
                line[index] = send[i] + low * feedback
                index += 1
                if index == size { index = 0 }
                room[i] += out
            }
        }
        for tuning in allPasses {
            let size = max(1, Int((Double(tuning) * scale).rounded()))
            var line = [Float](repeating: 0, count: size)
            var index = 0
            for i in 0..<count {
                let buffered = line[index]
                let input = room[i]
                line[index] = input + buffered * 0.5
                room[i] = buffered - input
                index += 1
                if index == size { index = 0 }
            }
        }
        var dryEnergy: Float = 0, wetEnergy: Float = 0
        for i in 0..<count { dryEnergy += samples[i] * samples[i]; wetEnergy += room[i] * room[i] }
        guard dryEnergy > 0, wetEnergy > 0 else { return }
        let gain = wet * (dryEnergy / wetEnergy).squareRoot()
        let delay = max(0, Int(settings.preDelay * rate))
        guard delay < count else { return }
        for i in 0..<(count - delay) { samples[i + delay] += room[i] * gain }
    }

    /// A linear fade over the last `frames`, so a cut tail never clicks.
    static func fadeTail(_ samples: inout [Float], frames: Int) {
        let length = min(samples.count, max(0, frames))
        guard length > 0 else { return }
        let start = samples.count - length
        for i in 0..<length { samples[start + i] *= Float(length - i) / Float(length) }
    }
}

/// Deterministic white noise in -1...1 (xorshift), so every cue renders the same each launch.
struct SystemNoise {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> Float {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Float(Double(state >> 11) / Double(1 << 53)) * 2 - 1
    }
}
