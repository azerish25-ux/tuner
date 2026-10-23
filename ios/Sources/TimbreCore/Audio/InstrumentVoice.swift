import Foundation

/// The sound of "Hear it", chord play buttons, listen steps and the tuner's reference: the instrument being
/// learned or tuned. Plucked voices are Karplus–Strong strings in a light body, `mallet` is a struck bar, and
/// bowed, wind and sung voices are sustained (`ToneSynth` renders them all).
public enum InstrumentVoice: String, CaseIterable, Codable, Sendable {
    case guitar, bass, ukulele, mandolin, banjo, harp, piano
    case mallet
    case violin, cello, flute, reed, brass, voice

    public enum Kind: Sendable { case plucked, struck, sustained }

    public var kind: Kind {
        switch self {
        case .guitar, .bass, .ukulele, .mandolin, .banjo, .harp, .piano: return .plucked
        case .mallet: return .struck
        case .violin, .cello, .flute, .reed, .brass, .voice: return .sustained
        }
    }

    /// A catalogue instrument's voice: by its id, else by its family.
    public init(instrument: Instrument) {
        self = InstrumentVoice(instrumentId: instrument.id) ?? InstrumentVoice.family(instrument.familyId)
    }

    /// The voice of an instrument id ("guitar.acoustic.6", "bass.double.4", or a course's "voice");
    /// nil without one (theory, ear and rhythm courses) or for an id it doesn't know.
    public init?(instrumentId: String?) {
        guard let id = instrumentId?.lowercased() else { return nil }
        let parts = id.split(separator: ".")
        guard let first = parts.first else { return nil }
        let head = String(first)
        let model = parts.count > 1 ? String(parts[1]) : ""
        switch head {
        case "voice", "vocal", "vocals": self = .voice
        case "guitar": self = model == "guitarron" ? .bass : .guitar
        case "bass": self = model == "double" ? .cello : .bass
        case "ukulele": self = model == "bass" ? .bass : .ukulele
        case "mandolin", "mandola", "mandocello", "bouzouki", "charango", "balalaika", "domra": self = .mandolin
        case "banjo", "shamisen", "sarod": self = .banjo
        case "lute", "oud", "pipa": self = .guitar
        case "harp", "koto", "gayageum", "guzheng", "guqin", "kora", "dulcimer", "autoharp", "sitar", "harpsichord": self = .harp
        case "violin", "viola", "fiddle", "erhu": self = .violin
        case "cello": self = .cello
        case "keys": self = model == "piano" ? .piano : model == "accordion" ? .reed : .harp
        case "piano": self = .piano
        case "flute", "recorder", "tin_whistle", "bansuri", "shakuhachi", "ocarina": self = .flute
        case "clarinet", "saxophone", "oboe", "bassoon", "harmonica", "accordion": self = .reed
        case "trumpet", "trombone", "french_horn", "tuba", "didgeridoo": self = .brass
        case "mallet", "marimba", "xylophone", "vibraphone", "kalimba", "handpan", "timpani": self = .mallet
        default: return nil
        }
    }

    /// A family's voice, for an instrument whose id says nothing more.
    public static func family(_ familyId: String) -> InstrumentVoice {
        switch familyId {
        case "ukulele": return .ukulele
        case "mandolin": return .mandolin
        case "bowed_strings": return .violin
        case "keys": return .piano
        case "winds": return .reed
        case "mallet_percussion_hand": return .mallet
        default: return .guitar
        }
    }
}

// MARK: - Voice settings

/// A resonance of the body (or a formant): centre in hertz, Q, and level added to the dry sound.
struct Resonance: Sendable {
    let hz: Double
    let q: Double
    let gain: Double
}

/// A plucked string. `sustain` is seconds to fade 60 dB at 220 Hz (lower notes ring longer); `brightness`
/// (0...1) is the pick and how long the upper partials last; `pick` is the pluck point as a fraction of the
/// string from the bridge (nearer = thinner, twangier); `pairCents` detunes a doubled course in phrases.
struct PluckProfile: Sendable {
    let brightness: Double
    let sustain: Double
    let pick: Double
    var pairCents: Double = 0
    let body: [Resonance]
    let lowpass: Double
    let highpass: Double
}

/// A sustained voice: a band-limited saw, square and sine blend through a lowpass and body formants, with
/// bow or breath noise, a soft attack and release, and vibrato that sets in after `ToneSynth.vibratoOnset`.
struct SustainProfile: Sendable {
    var saw = 0.0, square = 0.0, sine = 0.0
    let lowpass: Double
    var formants: [Resonance] = []
    let dry: Double
    var noise = 0.0
    var noiseHz = 2000.0
    let attack: Double
    let release: Double
    let vibratoRate: Double
    let vibratoCents: Double
}

extension InstrumentVoice {
    var pluck: PluckProfile? {
        switch self {
        case .guitar:
            return PluckProfile(brightness: 0.6, sustain: 3.6, pick: 0.18,
                                body: [Resonance(hz: 98, q: 6, gain: 0.9), Resonance(hz: 205, q: 5, gain: 0.6), Resonance(hz: 400, q: 3, gain: 0.35)],
                                lowpass: 6500, highpass: 60)
        case .bass:
            // Deep and long: a darker pick near the bridge pickup, little body.
            return PluckProfile(brightness: 0.4, sustain: 4.5, pick: 0.12,
                                body: [Resonance(hz: 70, q: 2, gain: 0.3), Resonance(hz: 160, q: 2, gain: 0.25)],
                                lowpass: 3500, highpass: 30)
        case .ukulele:
            return PluckProfile(brightness: 0.5, sustain: 1.8, pick: 0.25,
                                body: [Resonance(hz: 260, q: 5, gain: 0.7), Resonance(hz: 520, q: 4, gain: 0.4)],
                                lowpass: 5500, highpass: 90)
        case .mandolin:
            return PluckProfile(brightness: 0.8, sustain: 2.0, pick: 0.12, pairCents: 1.5,
                                body: [Resonance(hz: 300, q: 6, gain: 0.6), Resonance(hz: 700, q: 4, gain: 0.35), Resonance(hz: 1500, q: 3, gain: 0.2)],
                                lowpass: 8000, highpass: 110)
        case .banjo:
            // Brighter and shorter: a taut head and a pick right by the bridge.
            return PluckProfile(brightness: 0.9, sustain: 1.2, pick: 0.1,
                                body: [Resonance(hz: 350, q: 4, gain: 0.5), Resonance(hz: 2200, q: 2, gain: 0.4)],
                                lowpass: 9000, highpass: 120)
        case .harp:
            return PluckProfile(brightness: 0.7, sustain: 3.5, pick: 0.3,
                                body: [Resonance(hz: 250, q: 3, gain: 0.4), Resonance(hz: 600, q: 3, gain: 0.3)],
                                lowpass: 7000, highpass: 70)
        case .piano:
            // A felt hammer an eighth of the way along, ringing into a soundboard.
            return PluckProfile(brightness: 0.45, sustain: 5.0, pick: 0.125,
                                body: [Resonance(hz: 110, q: 2, gain: 0.3), Resonance(hz: 320, q: 2, gain: 0.25), Resonance(hz: 900, q: 2, gain: 0.2)],
                                lowpass: 5000, highpass: 40)
        default:
            return nil
        }
    }

    var sustain: SustainProfile? {
        switch self {
        case .violin:
            return SustainProfile(saw: 1, lowpass: 7000,
                                  formants: [Resonance(hz: 280, q: 4, gain: 0.5), Resonance(hz: 470, q: 5, gain: 0.6),
                                             Resonance(hz: 1100, q: 3, gain: 0.25), Resonance(hz: 2900, q: 2.5, gain: 0.55)],
                                  dry: 0.35, noise: 0.02, noiseHz: 3000, attack: 0.09, release: 0.14, vibratoRate: 5.6, vibratoCents: 14)
        case .cello:
            return SustainProfile(saw: 1, lowpass: 4500,
                                  formants: [Resonance(hz: 110, q: 3, gain: 0.5), Resonance(hz: 220, q: 4, gain: 0.55),
                                             Resonance(hz: 420, q: 4, gain: 0.4), Resonance(hz: 1400, q: 2.5, gain: 0.3)],
                                  dry: 0.4, noise: 0.015, noiseHz: 1800, attack: 0.11, release: 0.16, vibratoRate: 5.2, vibratoCents: 16)
        case .flute:
            return SustainProfile(saw: 0.3, sine: 1, lowpass: 4000, dry: 1, noise: 0.05, noiseHz: 2500,
                                  attack: 0.07, release: 0.1, vibratoRate: 5.0, vibratoCents: 9)
        case .reed:
            return SustainProfile(saw: 0.4, square: 0.6, lowpass: 3500,
                                  formants: [Resonance(hz: 1200, q: 2, gain: 0.4), Resonance(hz: 2500, q: 3, gain: 0.25)],
                                  dry: 0.6, noise: 0.01, attack: 0.05, release: 0.1, vibratoRate: 5.2, vibratoCents: 7)
        case .brass:
            return SustainProfile(saw: 1, lowpass: 3000,
                                  formants: [Resonance(hz: 1000, q: 1.5, gain: 0.5), Resonance(hz: 2400, q: 2, gain: 0.3)],
                                  dry: 0.5, attack: 0.06, release: 0.1, vibratoRate: 5.0, vibratoCents: 6)
        case .voice:
            // A sung "ah": a glottal saw through the vowel's first three formants.
            return SustainProfile(saw: 1, lowpass: 3200,
                                  formants: [Resonance(hz: 750, q: 8, gain: 1), Resonance(hz: 1150, q: 11, gain: 0.5), Resonance(hz: 2800, q: 18, gain: 0.25)],
                                  dry: 0.08, noise: 0.01, noiseHz: 1500, attack: 0.08, release: 0.15, vibratoRate: 5.5, vibratoCents: 22)
        default:
            return nil
        }
    }
}
