import AVFoundation
import TimbreCore

/// While the app's own voice speaks (a spoken cue naming the next note), what the microphone hears is set aside
/// (`AudioService`): a syllable is never taken for a note, an attack or a stroke. A hold ends a moment after its speech
/// does (`tail`: the room, the output's latency and the analysis window still holding the voice), or at its deadline if
/// the end never arrives. Read from the analysis queue; any thread may hold or release.
final class SpeechGate: @unchecked Sendable {
    static let shared = SpeechGate()
    /// Seconds the microphone stays set aside after the voice stops.
    static let tail: TimeInterval = 0.15

    private let lock = NSLock()
    /// Each hold's deadline, by key.
    private var holds: [Int: TimeInterval] = [:]
    private var quietUntil: TimeInterval = 0
    private var nextKey = 0

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Sets the microphone aside from now, for speech expected to take about `seconds`; the hold lapses by itself well
    /// after that if nothing releases it.
    func hold(expecting seconds: TimeInterval) -> Int {
        lock.lock(); defer { lock.unlock() }
        nextKey &+= 1
        holds[nextKey] = now + max(0.5, seconds) * 1.5 + 1
        return nextKey
    }

    /// The speech held for under `key` has ended (or never will): the microphone listens again after `tail`.
    func release(_ key: Int) {
        lock.lock(); defer { lock.unlock() }
        guard holds.removeValue(forKey: key) != nil else { return }
        quietUntil = max(quietUntil, now + Self.tail)
    }

    /// The microphone's input is set aside now.
    var isQuiet: Bool {
        lock.lock(); defer { lock.unlock() }
        let time = now
        if holds.values.contains(where: { $0 <= time }) { holds = holds.filter { $0.value > time } }
        return !holds.isEmpty || time < quietUntil
    }
}

/// The voice that names notes during a play-along: the app's own speech synthesizer, in the language the app is shown
/// in, at a known rate, through the app's own audio session (so it mixes with the click and the band). It learns how
/// long it takes to say things from what it has said, so a cue can be chosen to end before the note it names, and it
/// sets the microphone aside while it speaks (`SpeechGate`).
@MainActor
final class CueVoice {
    static let shared = CueVoice()

    private let synthesizer = AVSpeechSynthesizer()
    private let timing = CueTiming()
    private var voice: AVSpeechSynthesisVoice?
    private var voiceLanguage: String?
    /// A little brisker than the default: cues are short and come between notes.
    private static let rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 1.06)

    private init() {
        synthesizer.delegate = timing
    }

    /// Finds the voice ahead of the first cue (as a take starts), so the first note isn't named late.
    func prepare() {
        _ = currentVoice()
    }

    /// About how long `text` takes to say, from asking to the end of the last syllable.
    func estimate(_ text: String) -> TimeInterval {
        timing.estimate(text)
    }

    /// Says `text` now. A cue still being said is cut off: late, it would run into this one and its note.
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = currentVoice()
        utterance.rate = Self.rate
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        timing.begin(utterance, expecting: estimate(text))
        synthesizer.speak(utterance)
    }

    /// A voice for the app's language, looked up again only when the language changes.
    private func currentVoice() -> AVSpeechSynthesisVoice? {
        let language = TimbreLocalization.resolvedLanguage(for: TimbreLocalization.language)
        if language != voiceLanguage {
            voiceLanguage = language
            voice = Self.voice(for: language)
            timing.language(language)
        }
        return voice
    }

    /// The system's voice for a localization code ("de", "pt-BR", "zh-Hans"): as written, then as the speech voices
    /// name it (a region for Chinese scripts), then by its language alone.
    private static func voice(for code: String) -> AVSpeechSynthesisVoice? {
        let scripts = ["zh-Hans": "zh-CN", "zh-Hant": "zh-TW"]
        let base = String(code.split(separator: "-").first ?? Substring(code))
        for candidate in [code, scripts[code] ?? code, base] {
            if let found = AVSpeechSynthesisVoice(language: candidate) { return found }
        }
        return nil
    }
}

/// What `CueVoice` knows about its own timing, kept up to date by the synthesizer as it speaks: how long it takes to
/// start, and how long a character takes to say (both learned from each finished cue). It also holds and releases the
/// microphone around each utterance.
private final class CueTiming: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private struct Spoken {
        let gate: Int
        let asked: TimeInterval
        let characters: Int
        let pauses: Int
        var started: TimeInterval?
    }

    private let lock = NSLock()
    private var spoken: [ObjectIdentifier: Spoken] = [:]
    /// Seconds from asking to the first sound.
    private var startDelay: TimeInterval = 0.12
    /// Seconds per character at the cue rate; one syllable a character in Chinese, Japanese and Korean.
    private var perCharacter: TimeInterval = 0.06
    /// The pause a comma makes.
    private static let pause: TimeInterval = 0.12

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func language(_ code: String) {
        let syllabic = ["zh", "ja", "ko"].contains { code.hasPrefix($0) }
        lock.lock()
        perCharacter = syllabic ? 0.17 : 0.06
        lock.unlock()
    }

    func estimate(_ text: String) -> TimeInterval {
        let (characters, pauses) = Self.measure(text)
        lock.lock(); defer { lock.unlock() }
        return startDelay + Double(characters) * perCharacter + Double(pauses) * Self.pause
    }

    func begin(_ utterance: AVSpeechUtterance, expecting seconds: TimeInterval) {
        let (characters, pauses) = Self.measure(utterance.speechString)
        let gate = SpeechGate.shared.hold(expecting: seconds)
        lock.lock()
        spoken[ObjectIdentifier(utterance)] = Spoken(gate: gate, asked: now, characters: characters, pauses: pauses)
        lock.unlock()
    }

    /// Characters that take time to say, and the pauses commas make.
    private static func measure(_ text: String) -> (characters: Int, pauses: Int) {
        let pauses = text.filter { $0 == "," || $0 == "،" || $0 == "、" || $0 == "，" }.count
        let characters = text.filter { !$0.isWhitespace && !$0.isPunctuation }.count
        return (characters, pauses)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        let time = now
        lock.lock(); defer { lock.unlock() }
        guard var entry = spoken[key] else { return }
        entry.started = time
        spoken[key] = entry
        startDelay = Self.blend(startDelay, time - entry.asked, low: 0.02, high: 0.6)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let time = now
        lock.lock()
        let entry = spoken.removeValue(forKey: ObjectIdentifier(utterance))
        if let entry, let started = entry.started, entry.characters > 0 {
            let speaking = time - started - Double(entry.pauses) * Self.pause
            perCharacter = Self.blend(perCharacter, speaking / Double(entry.characters), low: 0.025, high: 0.3)
        }
        lock.unlock()
        if let entry { SpeechGate.shared.release(entry.gate) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        lock.lock()
        let entry = spoken.removeValue(forKey: ObjectIdentifier(utterance))
        lock.unlock()
        if let entry { SpeechGate.shared.release(entry.gate) }
    }

    /// A running average that follows each new measurement a third of the way, within sane bounds.
    private static func blend(_ current: TimeInterval, _ measured: TimeInterval, low: TimeInterval, high: TimeInterval) -> TimeInterval {
        guard measured.isFinite, measured > 0 else { return current }
        return min(high, max(low, current + (measured - current) / 3))
    }
}
