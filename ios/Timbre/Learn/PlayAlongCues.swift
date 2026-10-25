import Accessibility
import AVFoundation
import SwiftUI
import TimbreCore

// MARK: - Answering a take as it goes

/// How a play-along answers each note besides the runway: a tap on a perfect note, and a firmer one with a rising swish
/// as the multiplier steps up; the band thinning to drums and bass on a miss and filling back in at four in a row, a
/// crash at ×4 and a choked strum when a run breaks, with a falling swish when the run was ×3 or more; and, with spoken
/// cues, a tick for a note played and a thud for a miss. The swishes are pitchless noise and the band keeps to its kit
/// on the speaker, so the microphone takes none of it for a note.
@MainActor
enum TakeFeedback {
    /// A broken run this long (×3 and up) is marked out loud as well as by the band.
    private static let markedRun = 8

    static func react(_ update: PlayAlongSession.Update, combo: Int, spoken: Bool) {
        for judgment in update.judgments {
            if judgment.grade == .perfect { Haptics.shared.selection() }
            if spoken { Earcons.shared.play(hit: judgment.grade != .miss) }
        }
        if update.tier != nil {
            Haptics.shared.beat(accent: true)
            Earcons.shared.lift()
        }
        if update.tier == 4 { BandFeel.shared.crash() }
        if let broken = update.brokenRun {
            BandFeel.shared.choke()
            if broken >= markedRun { Earcons.shared.drop() }
        }
        if update.judgments.contains(where: { $0.grade == .miss }) {
            BandFeel.shared.thin(true)
        } else if combo >= 4 {
            BandFeel.shared.thin(false)
        }
    }

    /// The count-in felt as well as heard: a tap on each click, firmer on the first.
    static func countIn(_ beat: Int) { Haptics.shared.beat(accent: beat == 0) }
}

// MARK: - Spoken cues

/// The play-along for VoiceOver: each note named ahead of it by the app's own voice ("D, string 4, open"; just "4 open"
/// when notes come too fast for more), timed to end before the note, with the microphone set aside while it speaks; a
/// tick or a thud for each note judged, the count-in felt, the band stepped back and the result said at the end. On
/// whenever VoiceOver runs, unless the player turned it off (the runway's actions).
enum SpokenCues {
    /// The player's choice; unset follows VoiceOver.
    static let storageKey = "along.spokenCues"

    /// Says `text` now through VoiceOver, ahead of whatever it was saying. For what isn't timed against the music (a
    /// take's result); a cue for a note or a chord goes through `schedule`.
    @MainActor static func say(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// Names `note`, which is due `lead` seconds from now, through the app's own voice (`CueVoice`), so the cue is over
    /// before the note begins: in full when that fits and `brief` isn't asked for (the caller's call, from the gap
    /// before the note), else just its place, else nothing at all (a cue running into its note would hide the note
    /// from the microphone and from the ear). The microphone is set aside while it speaks.
    @MainActor static func schedule(_ note: TimedNote, fretted: Bool, lead: TimeInterval, brief: Bool) {
        let short = phrase(note, fretted: fretted, brief: true)
        speak(firstFitting: brief ? [short] : [phrase(note, fretted: fretted, brief: false), short], lead: lead)
    }

    /// Says `text` (a chord's name before its bar) through the app's own voice when it can be over before what it
    /// announces, `lead` seconds from now; otherwise says nothing.
    @MainActor static func schedule(saying text: String, lead: TimeInterval) {
        speak(firstFitting: [text], lead: lead)
    }

    /// How long before its note a cue must be over: time for the microphone to listen again (`SpeechGate.tail`) and
    /// for an early attack; a little less when notes come fast.
    static func margin(lead: TimeInterval) -> TimeInterval { min(0.4, max(0.2, lead * 0.3)) }

    /// The voice is ready before the take's first cue (called as a take with cues starts).
    @MainActor static func prepare() { CueVoice.shared.prepare() }

    @MainActor private static func speak(firstFitting options: [String], lead: TimeInterval) {
        guard lead.isFinite, lead > 0 else { return }
        let voice = CueVoice.shared
        let room = lead - margin(lead: lead)
        guard let text = options.first(where: { voice.estimate($0) <= room }) else { return }
        voice.speak(text)
    }

    /// A note as said: its name and, on a fretted course, where to play it; `brief` keeps only the place, as briefly as
    /// it can be said ("6 open", "5, fret 3").
    static func phrase(_ note: TimedNote, fretted: Bool, brief: Bool) -> String {
        let name = spokenName(note.midi)
        guard fretted, let at = note.at else { return name }
        if brief {
            return at.fret == 0 ? String(localized: "\(at.string) open") : String(localized: "\(at.string), fret \(at.fret)")
        }
        let place = at.fret == 0 ? String(localized: "String \(at.string), open") : String(localized: "String \(at.string), fret \(at.fret)")
        return name + ", " + place
    }

    /// A note's name as said in the app's language and the player's note names: "F sharp", "Fis", "Fa dièse".
    static func spokenName(_ midi: Int) -> String {
        NoteNames.spokenInApp(NoteName.pitchClass(midi))
    }

    /// The take's result as said: "5 of 6 notes, 2 perfect. 83 %".
    static func result(hits: Int, of total: Int, perfect: Int, percent: Int) -> String {
        String(localized: "\(hits) of \(total) notes, \(perfect) perfect") + ". " + percent.formatted(.percent)
    }
}

/// The play-along's sounds besides the band: for spoken cues a soft tick for a note played and a low thud for a miss;
/// for everyone a rising swish as the multiplier steps up and a falling one when a long run breaks. Shaped noise with
/// no pitch, so the microphone never takes one for a note, and safe out of the phone's speaker; quiet, and silent with
/// the app's sounds off. They play in the session the app's own sounds share (`AudioSessionOwner`).
@MainActor
final class Earcons {
    static let shared = Earcons()
    private static let rate = 44_100
    private var tick: AVAudioPlayer?
    private var thud: AVAudioPlayer?
    private var rise: AVAudioPlayer?
    private var fall: AVAudioPlayer?

    func play(hit: Bool) {
        guard SoundFX.shared.enabled else { return }
        prepare()
        start(hit ? tick : thud)
    }

    /// The multiplier stepped up: a short rising swish.
    func lift() {
        guard SoundFX.shared.enabled else { return }
        if rise == nil { rise = Self.player(Self.riseSound(), volume: 0.22) }
        start(rise)
    }

    /// A long run broke: a soft falling swish, a tape slowing to a stop.
    func drop() {
        guard SoundFX.shared.enabled else { return }
        if fall == nil { fall = Self.player(Self.fallSound(), volume: 0.3) }
        start(fall)
    }

    /// Renders the cue sounds (a few milliseconds) and finds the cue voice, ahead of the first note when called as a
    /// take with spoken cues starts.
    func prepare() {
        if tick == nil { tick = Self.player(Self.tickSound(), volume: 0.3) }
        if thud == nil { thud = Self.player(Self.thudSound(), volume: 0.45) }
        SpokenCues.prepare()
    }

    private func start(_ player: AVAudioPlayer?) {
        guard let player else { return }
        AudioSessionOwner.shared.prepareInterfaceSound()
        player.currentTime = 0
        player.play()
    }

    /// Noise through a low-pass whose corner glides from `from` to `to` hertz, with the rumble below 250 Hz taken out:
    /// a swish with a direction and no pitch. `shape` is its loudness over its length (0…1 in, 0…1 out).
    private static func sweep(seconds: Double, from: Double, to: Double, seed: UInt32, shape: (Double) -> Double) -> [Float] {
        let count = Int(seconds * Double(rate))
        var out = [Float](repeating: 0, count: count)
        var noise = SoundNoise(seed: seed)
        var low: Float = 0
        var rumble: Float = 0
        let rumbleK = Float(1 - exp(-2 * Double.pi * 250 / Double(rate)))
        for i in 0..<count {
            let x = Double(i) / Double(max(1, count - 1))
            let corner = from * pow(to / from, x)
            let k = Float(1 - exp(-2 * Double.pi * corner / Double(rate)))
            low += (noise.next() - low) * k
            rumble += (low - rumble) * rumbleK
            out[i] = (low - rumble) * Float(shape(x))
        }
        return SoundSynth.normalised(out, peak: 0.6)
    }

    /// A quarter-second rise: up from a soft hiss to a bright one, then gone in 30 ms.
    private static func riseSound() -> [Float] {
        sweep(seconds: 0.28, from: 700, to: 7_000, seed: 0x2B5E, shape: { x in
            x < 0.88 ? pow(x / 0.88, 2) : (1 - x) / 0.12
        })
    }

    /// A third of a second falling away: a soft start, darkening as it fades.
    private static func fallSound() -> [Float] {
        sweep(seconds: 0.34, from: 3_200, to: 160, seed: 0x6C13, shape: { x in
            min(1, x / 0.06) * pow(1 - x, 1.6)
        })
    }

    /// A bright click: noise through a high-pass, gone in 15 ms.
    private static func tickSound() -> [Float] {
        let count = rate * 4 / 100
        var out = [Float](repeating: 0, count: count)
        var noise = SoundNoise(seed: 0x51A7)
        var lastIn: Float = 0, lastOut: Float = 0
        let a: Float = 0.82
        for i in 0..<count {
            let t = Float(i) / Float(rate)
            let x = noise.next()
            lastOut = a * (lastOut + x - lastIn)
            lastIn = x
            out[i] = lastOut * exp(-t / 0.006) * 0.9
        }
        return out
    }

    /// A soft low knock: noise through a low-pass under a quick fall, gone in a tenth of a second.
    private static func thudSound() -> [Float] {
        let count = rate * 12 / 100
        var out = [Float](repeating: 0, count: count)
        var noise = SoundNoise(seed: 0x7D0B)
        var low: Float = 0
        let k: Float = 0.035
        for i in 0..<count {
            let t = Float(i) / Float(rate)
            low += (noise.next() - low) * k
            out[i] = low * exp(-t / 0.03) * min(1, t / 0.002) * 7
        }
        return out
    }

    private static func player(_ samples: [Float], volume: Float) -> AVAudioPlayer? {
        // Preparing a player can activate the session: it is ambient first unless an engine holds it.
        AudioSessionOwner.shared.prepareInterfaceSound()
        guard let player = try? AVAudioPlayer(data: wav(samples)) else { return nil }
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    /// 16-bit mono PCM in a WAV container.
    private static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        func word(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func half(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); word(36 + bytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); word(16); half(1); half(1)
        word(UInt32(rate)); word(UInt32(rate * 2)); half(2); half(16)
        data.append(contentsOf: Array("data".utf8)); word(bytes)
        for sample in samples {
            let value = Int16(max(-1, min(1, sample)) * Float(Int16.max))
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }

    /// White noise in -1...1 (xorshift), the same every launch.
    private struct SoundNoise {
        private var state: UInt32
        init(seed: UInt32) { state = seed == 0 ? 0x9E37_79B9 : seed }
        mutating func next() -> Float {
            state ^= state << 13
            state ^= state >> 17
            state ^= state << 5
            return Float(Double(state) / Double(UInt32.max) * 2 - 1)
        }
    }
}

// MARK: - Starting on the first note

/// "Start on first strum" for a play-along: while a take waits, the microphone listens, and the first note played on
/// the instrument starts the count-in, so both hands stay on it. A note counts when an attack is followed by a steady
/// pitch the take plays somewhere (a voice, a cough or a tap on the phone rarely is). The same switch as the rhythm
/// steps' (one setting); unset, it is on while VoiceOver runs. Never offered to the demonstration pitch, which has no
/// attack to hear.
enum StrumStart {
    /// The player's choice, shared with the rhythm steps.
    static let storageKey = "lesson.startOnStrum"

    /// The switch can do anything here: a real microphone the player has allowed.
    @MainActor static var offered: Bool { !LessonMicrophone.demo && LessonMicrophone.granted }

    /// The pitch classes a take plays: a note heard in one of them starts it.
    static func pitchClasses(_ notes: [TimedNote]) -> Set<Int> { Set(notes.map { PitchMath.pitchClass(midi: $0.midi) }) }
}

/// The switch for "Start on first strum" beside a play-along's other controls: the microphone in a ring, tinted when
/// on, its waves running while it listens. A 34 pt face in a 44 pt target, as the calibrate and band buttons beside it.
struct StrumStartToggle: View {
    @Binding var isOn: Bool
    let accent: Color
    /// Listening for the first note now.
    var listening = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isOn.toggle()
            Haptics.shared.selection()
        } label: {
            ZStack {
                Circle().fill(isOn ? accent.opacity(0.16) : Palette.surface)
                Circle().strokeBorder(isOn ? accent.opacity(0.45) : Palette.hairline, lineWidth: 1)
                Image(systemName: isOn ? "mic.fill" : "mic")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isOn ? accent : Palette.inkSoft)
                    .symbolEffect(.variableColor.iterative, isActive: listening && !reduceMotion)
            }
            .frame(width: 34, height: 34)
            .frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("Start on first strum"))
        .accessibilityAddTraits(isOn ? [.isToggle, .isSelected] : [.isToggle])
        .accessibilityIdentifier("along.strumstart")
    }
}

/// Esc stops a take from a keyboard: a hidden button carrying the shortcut, behind the visible Stop.
struct StopKey: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { EmptyView() }
            .keyboardShortcut(.escape, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// Over the waiting runway while "Start on first strum" listens.
struct StrumToStartHint: View {
    let accent: Color

    var body: some View {
        Label("Play a note to start", systemImage: "waveform")
            .font(Typeface.label(.body))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Palette.stageDeep.opacity(0.85)))
            .overlay(Capsule().strokeBorder(accent.opacity(0.5), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

// MARK: - Saying what happened

/// A good take's headline as a fact rather than praise: "6 for 6, on the beat", "All 24 notes", "22 of 24 notes".
enum TakeFact {
    static func headline(hits: Int, of total: Int, meanOffset: Double?) -> LocalizedStringKey {
        let onBeat = meanOffset.map { abs($0) < 0.035 } ?? false
        if hits == total && onBeat { return "\(hits) for \(total), on the beat" }
        if hits == total { return "All \(total) notes" }
        return "\(hits) of \(total) notes"
    }
}
