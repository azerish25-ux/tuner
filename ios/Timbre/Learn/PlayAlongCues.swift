import Accessibility
import AVFoundation
import SwiftUI
import TimbreCore

// MARK: - Answering a take as it goes

/// How a play-along answers each note besides the runway: a tap on a perfect note and a firmer one as the multiplier
/// steps up; the band thinning to drums and bass on a miss and filling back in at four in a row, a crash at ×4 and a
/// choked strum when a run breaks (the band plays in headphones only, so none of it reaches the microphone); and,
/// with spoken cues, a tick for a note played and a thud for a miss.
@MainActor
enum TakeFeedback {
    static func react(_ update: PlayAlongSession.Update, combo: Int, spoken: Bool) {
        for judgment in update.judgments {
            if judgment.grade == .perfect { Haptics.shared.selection() }
            if spoken { Earcons.shared.play(hit: judgment.grade != .miss) }
        }
        if update.tier != nil { Haptics.shared.beat(accent: true) }
        if update.tier == 4 { BandFeel.shared.crash() }
        if update.brokenRun != nil { BandFeel.shared.choke() }
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

/// The play-along for VoiceOver: each note named a beat before it is due ("D, string 4, open"; just the string and
/// fret when notes come too fast for more), a tick or a thud for each note judged, the count-in felt, the band
/// stepped back and the result said at the end. On whenever VoiceOver runs, unless the player turned it off (the
/// runway's actions).
enum SpokenCues {
    /// The player's choice; unset follows VoiceOver.
    static let storageKey = "along.spokenCues"

    /// Says `text` now, ahead of whatever VoiceOver was saying.
    @MainActor static func say(_ text: String) {
        var announcement = AttributedString(text)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// A note as said: its name and, on a fretted course, where to play it; `brief` keeps only the place.
    static func phrase(_ note: TimedNote, fretted: Bool, brief: Bool) -> String {
        let name = spokenName(note.midi)
        guard fretted, let at = note.at else { return name }
        let place = at.fret == 0 ? String(localized: "String \(at.string), open") : String(localized: "String \(at.string), fret \(at.fret)")
        return brief ? place : name + ", " + place
    }

    /// "F sharp", "B flat": accidentals in words, which every voice reads the same way.
    static func spokenName(_ midi: Int) -> String {
        let written = NoteName.pitchClass(midi)
        if written.hasSuffix("♯") {
            let base = String(written.dropLast())
            return String(localized: "\(base) sharp")
        }
        if written.hasSuffix("♭") {
            let base = String(written.dropLast())
            return String(localized: "\(base) flat")
        }
        return written
    }

    /// The take's result as said: "5 of 6 notes, 2 perfect. 83 %".
    static func result(hits: Int, of total: Int, perfect: Int, percent: Int) -> String {
        String(localized: "\(hits) of \(total) notes, \(perfect) perfect") + ". " + percent.formatted(.percent)
    }
}

/// The spoken cues' judgement sounds: a soft tick for a note played, a low thud for a miss. Shaped noise with no
/// pitch, so the microphone never takes one for a note; quiet, and silent with the app's sounds off.
@MainActor
final class Earcons {
    static let shared = Earcons()
    private static let rate = 44_100
    private var tick: AVAudioPlayer?
    private var thud: AVAudioPlayer?

    func play(hit: Bool) {
        guard SoundFX.shared.enabled else { return }
        prepare()
        guard let player = hit ? tick : thud else { return }
        player.currentTime = 0
        player.play()
    }

    /// Renders both sounds (a few milliseconds), ahead of the first note when called as a take starts.
    func prepare() {
        if tick == nil { tick = Self.player(Self.tickSound(), volume: 0.3) }
        if thud == nil { thud = Self.player(Self.thudSound(), volume: 0.45) }
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
/// steps' (one setting); unset, it is on while VoiceOver runs. Never offered to the demo pitch of a UI-test run.
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
