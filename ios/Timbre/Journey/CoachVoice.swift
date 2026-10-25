import SwiftUI
import TimbreCore
#if canImport(FoundationModels) && COACH_MODEL
import FoundationModels
#endif

// MARK: - Takes heard this session

/// The timing of the takes played in this session's lessons, for the coach (`CoachTake`). In memory only, the most
/// recent few: a play-along or strummed step hands its take over as it finishes; the lesson's results read the
/// takes since the lesson started, Progress the ones from the last hours.
@MainActor final class CoachTakes {
    static let shared = CoachTakes()
    private(set) var takes: [CoachTake] = []
    private static let kept = 24

    func record(_ take: CoachTake?) {
        guard let take, !take.hits.isEmpty else { return }
        takes.append(take)
        if takes.count > Self.kept { takes.removeFirst(takes.count - Self.kept) }
    }

    func takes(since date: Date) -> [CoachTake] { takes.filter { $0.date >= date } }
}

// MARK: - Words

/// How the coach words a note: one template per fact in the app's strings, every number taken from the fact. A
/// rewording on device (`CoachPolish`) may only rephrase it.
struct CoachVoice {
    /// A string's name as the tuner labels it ("G"), from its anchor id.
    var stringName: (String) -> String = { $0 }
    /// A lesson's title, for "Replay …".
    var lessonTitle: (String) -> String? = { _ in nil }
    /// How long the weak-spot drill runs (its lesson's minutes).
    var drillMinutes = 4
    /// Said for a clean run where the screen's headline already says it was clean (the lesson's results): the next
    /// step rather than the same praise twice. Nil keeps the clean run's own words.
    var nextStep: String? = nil

    // MARK: The note

    func text(_ note: CoachNote) -> String {
        if case .clean = note.fact, let nextStep { return nextStep }
        switch note.fact {
        case let .change(from, to, milliseconds, beat, missed, count, bpm):
            return changeText(from: Self.name(from), to: Self.name(to), milliseconds: milliseconds, beat: beat, missed: missed, count: count,
                              loop: loopTempo(note) ?? bpm, chords: Coach.changesChord(from: from, to: to))
        case let .nextLevel(from, to, milliseconds, beat):
            return nextLevelText(from: Self.name(from), to: Self.name(to), milliseconds: milliseconds, beat: beat,
                                 chords: Coach.changesChord(from: from, to: to))
        case let .lean(milliseconds, _, bpm):
            if milliseconds >= 0 {
                return String(localized: "Your notes sat about \(milliseconds) ms behind the click. Play along with the metronome at \(bpm) BPM and land right on it.")
            }
            return String(localized: "Your notes ran about \(abs(milliseconds)) ms ahead of the click. Play with the metronome at \(bpm) BPM and let each beat come to you.")
        case let .slipped(items, percent):
            return slippedText(items.map(Self.name), percent: percent, drill: note.action != nil)
        case let .split(strong, strongPercent, weak, weakPercent):
            return splitText(strong: strong, strongPercent: strongPercent, weak: weak, weakPercent: weakPercent)
        case let .belowTempo(percent, bpm):
            return String(localized: "\(percent)%, but only below the lesson tempo, so two stars. One take at the full \(bpm) BPM earns the third.")
        case let .finalTake(percent, needed):
            return String(localized: "Your play-along came in at \(percent)%. Three stars need \(needed)% on it.")
        case let .clean(items):
            return String(localized: "Clean run: \(items) of \(items) at 90% or better. Nothing slipped.")
        case let .drift(anchor, centsPerDay):
            let name = stringName(anchor)
            if centsPerDay < 0 {
                return String(localized: "Your \(name) string drifts \(abs(centsPerDay))¢ flat a day. Time for new strings; until then, tune up before you play.")
            }
            return String(localized: "Your \(name) string drifts \(centsPerDay)¢ sharp a day. Tune up before you play, and check it is wound firmly at the peg.")
        case let .oldStrings(weeks):
            return String(localized: "Your strings went on \(weeks) weeks ago. A fresh set holds its tune and sounds brighter.")
        case let .streak(days):
            return String(localized: "Your \(days)-day streak is still on. A one-minute tune-up keeps it going.")
        case let .today(done, total, next, minutes):
            return String(localized: "\(done) of \(total) done today. Next up: \(Self.activity(next)), about \(minutes) min.")
        case let .moreTime(minutes, percent):
            return String(localized: "\(minutes) minutes this week, \(percent)% more than last week. That is how it sticks.")
        case let .closerTuning(cents, before):
            let now = cents.formatted(.number.precision(.fractionLength(1)))
            let then = before.formatted(.number.precision(.fractionLength(1)))
            return String(localized: "Your tune-ups land within ±\(now)¢ now, down from ±\(then)¢ a few weeks ago.")
        }
    }

    /// Between chords it is a "change"; between single notes, a "move".
    private func changeText(from: String, to: String, milliseconds: Int?, beat: Int, missed: Int, count: Int, loop: Int, chords: Bool) -> String {
        guard let milliseconds else {
            if chords {
                return String(localized: "\(from) → \(to) didn’t land (\(missed) of \(count)). Practice the change at \(loop) BPM until your hand knows the way.")
            }
            return String(localized: "\(from) → \(to) didn’t land (\(missed) of \(count)). Practice the move at \(loop) BPM until your hand knows the way.")
        }
        if milliseconds >= 0 {
            if chords {
                return String(localized: "\(from) → \(to) was \(milliseconds) ms late on beat \(beat). Practice the change at \(loop) BPM until it lands.")
            }
            return String(localized: "\(from) → \(to) was \(milliseconds) ms late on beat \(beat). Practice the move at \(loop) BPM until it lands.")
        }
        if chords {
            return String(localized: "\(from) → \(to) came in \(abs(milliseconds)) ms early on beat \(beat). Practice the change at \(loop) BPM and wait for the click.")
        }
        return String(localized: "\(from) → \(to) came in \(abs(milliseconds)) ms early on beat \(beat). Practice the move at \(loop) BPM and wait for the click.")
    }

    /// A flawless run's tip: the one change (or move) still off the beat, as the next level rather than a fix.
    private func nextLevelText(from: String, to: String, milliseconds: Int, beat: Int, chords: Bool) -> String {
        if milliseconds >= 0 {
            if chords {
                return String(localized: "Next level: \(from) → \(to) came \(milliseconds) ms late on beat \(beat). Land that change right on the click.")
            }
            return String(localized: "Next level: \(from) → \(to) came \(milliseconds) ms late on beat \(beat). Land that move right on the click.")
        }
        if chords {
            return String(localized: "Next level: \(from) → \(to) came \(abs(milliseconds)) ms early on beat \(beat). Let that change wait for the click.")
        }
        return String(localized: "Next level: \(from) → \(to) came \(abs(milliseconds)) ms early on beat \(beat). Let that move wait for the click.")
    }

    private func slippedText(_ names: [String], percent: Int, drill: Bool) -> String {
        if names.count >= 2 {
            let said = String(localized: "\(names[0]) and \(names[1]) slipped; \(names[0]) was only \(percent)% clean.")
            return drill ? said + " " + String(localized: "A few minutes of the drill will steady them.") : said
        }
        let said = String(localized: "\(names.first ?? "") slipped: only \(percent)% clean.")
        return drill ? said + " " + String(localized: "A few minutes of the drill will steady it.") : said
    }

    private func splitText(strong: CoachSkill, strongPercent: Int, weak: CoachSkill, weakPercent: Int) -> String {
        let nailed = Self.skill(strong)
        switch weak {
        case .chords: return String(localized: "You nail \(nailed) (\(strongPercent)%), but chords are your weak spot (\(weakPercent)%).")
        case .notes: return String(localized: "You nail \(nailed) (\(strongPercent)%), but single notes are your weak spot (\(weakPercent)%).")
        case .rhythm: return String(localized: "You nail \(nailed) (\(strongPercent)%), but rhythm is your weak spot (\(weakPercent)%).")
        case .ear: return String(localized: "You nail \(nailed) (\(strongPercent)%), but ear questions are your weak spot (\(weakPercent)%).")
        }
    }

    /// The metronome tempo the note's action sets.
    private func loopTempo(_ note: CoachNote) -> Int? {
        if case let .metronome(bpm) = note.action { return bpm }
        return nil
    }

    // MARK: The action

    func actionTitle(_ action: CoachAction, for note: CoachNote) -> String {
        switch action {
        case .review:
            if case let .slipped(items, _) = note.fact, !items.isEmpty {
                let names = items.map(Self.name).joined(separator: "–")
                return String(localized: "\(names) drill · \(drillMinutes) min")
            }
            return String(localized: "Weak-spot drill · \(drillMinutes) min")
        case let .lesson(id):
            if case .belowTempo = note.fact { return String(localized: "Play it again") }
            if case .finalTake = note.fact { return String(localized: "Play it again") }
            if let title = lessonTitle(id) { return String(localized: "Replay “\(title)”") }
            return String(localized: "Play it again")
        case let .metronome(bpm): return String(localized: "Metronome · \(bpm) BPM")
        case .tune: return String(localized: "Tune up")
        case .today: return String(localized: "Today’s set")
        }
    }

    static func symbol(_ action: CoachAction) -> String {
        switch action {
        case .review: return "scope"
        case .lesson: return "arrow.counterclockwise"
        case .metronome: return "metronome.fill"
        case .tune: return "tuningfork"
        case .today: return "sun.max.fill"
        }
    }

    /// For analytics: which kind of action was taken (no ids, no numbers).
    static func kind(_ action: CoachAction) -> String {
        switch action {
        case .review: return "review"
        case .lesson: return "lesson"
        case .metronome: return "metronome"
        case .tune: return "tune"
        case .today: return "today"
        }
    }

    // MARK: Look

    static func symbol(_ note: CoachNote) -> String {
        switch note.fact {
        case .change, .lean, .nextLevel: return "metronome"
        case .slipped: return "scope"
        case .clean: return "checkmark.seal"
        case .split: return "chart.bar"
        case .belowTempo: return "speedometer"
        case .finalTake: return "star.leadinghalf.filled"
        case .drift, .oldStrings: return "tuningfork"
        case .streak: return "flame"
        case .today: return "sun.max"
        case .moreTime: return "chart.line.uptrend.xyaxis"
        case .closerTuning: return "target"
        }
    }

    /// The note's glyph: the streak's lamp for the streak, else the note's symbol (`symbol(_:)`).
    static func glyph(_ note: CoachNote, size: CGFloat, tint: Color) -> Glyph {
        if case .streak = note.fact { return Glyph(.lamp, size: size, tint: tint) }
        return Glyph(symbol(note), size: size, tint: tint)
    }

    /// Something to fix in the status amber (`Palette.adjust`, as the weak spots), praise in the screen's accent, the
    /// habit in the streak's lamp light.
    static func tint(_ note: CoachNote, accent: Color = Palette.mint) -> Color {
        switch note.tone {
        case .fix: return Palette.adjust
        case .praise: return accent
        case .habit: return Palette.flame
        }
    }

    // MARK: Names

    /// "Em", "G3": as the weak-spot chips name them.
    static func name(_ item: PracticeItem) -> String { WeakSpotChips.name(item) }

    private static func skill(_ skill: CoachSkill) -> String {
        switch skill {
        case .notes: return String(localized: "single notes")
        case .chords: return String(localized: "chords")
        case .rhythm: return String(localized: "rhythm")
        case .ear: return String(localized: "ear questions")
        }
    }

    private static func activity(_ kind: DailyActivity.Kind) -> String {
        switch kind {
        case .tune: return String(localized: "a tune-up")
        case .ear: return String(localized: "ear training")
        case .chord: return String(localized: "the chord of the day")
        case .scale: return String(localized: "a scale workout")
        case .rhythm: return String(localized: "rhythm practice")
        case .voice: return String(localized: "a voice warm-up")
        case .drone: return String(localized: "the drone")
        case .lesson: return String(localized: "your next lesson")
        case .review: return String(localized: "a review")
        }
    }

    /// The names a rewording must keep word for word (chords, notes, the string).
    func names(_ note: CoachNote) -> [String] {
        switch note.fact {
        case let .change(from, to, _, _, _, _, _): return [Self.name(from), Self.name(to)]
        case let .nextLevel(from, to, _, _): return [Self.name(from), Self.name(to)]
        case let .slipped(items, _): return items.map(Self.name)
        case let .drift(anchor, _): return [stringName(anchor)]
        default: return []
        }
    }

    // MARK: Checking a rewording

    /// A rewording is used only when it keeps exactly the template's numbers (none dropped, none added) and every
    /// name, and stays about as short.
    static func faithful(_ text: String, to template: String, names: [String]) -> Bool {
        guard !text.isEmpty, text.count <= template.count * 2 + 40, !text.contains("\n") else { return false }
        guard numbers(in: text).sorted() == numbers(in: template).sorted() else { return false }
        return names.allSatisfy { text.contains($0) }
    }

    /// Every run of digits ("410", "0.9", the 3 in "G3"), decimal separators kept inside a number.
    static func numbers(in text: String) -> [String] {
        var found: [String] = []
        var current = ""
        for character in text {
            if character.isWholeNumber {
                current.append(character)
            } else if (character == "." || character == ","), !current.isEmpty {
                current.append(character)
            } else if !current.isEmpty {
                found.append(current.trimmingCharacters(in: CharacterSet(charactersIn: ".,")))
                current = ""
            }
        }
        if !current.isEmpty { found.append(current.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))) }
        return found
    }
}

// MARK: - Rewording on device

/// The template, reworded in a warmer voice by the on-device language model where there is one (iOS 26 with
/// Apple Intelligence on and ready, in the language the tips are written in), checked to keep every number and
/// name; nil keeps the template, which carries every fact on its own.
///
/// On with the `COACH_MODEL` compilation condition (the Timbre target in project.yml), which also weak-links
/// FoundationModels for the iOS 18 deployment target (`OTHER_LDFLAGS: -weak_framework FoundationModels`). Every use
/// of the framework sits behind `canImport`, `@available(iOS 26.0, *)` with its `#available` check, and the model's
/// own availability, so iOS 18 to 25, devices without Apple Intelligence and unsupported languages keep the templates.
@MainActor enum CoachPolish {
    private static var cache: [String: String] = [:]
    /// Tips the model already answered without keeping to the facts (or couldn't answer): not asked again.
    private static var declined: Set<String> = []
    /// Off whenever the app runs under automation (`TestSupport.isAutomated`, never in a release build), so every check
    /// and capture reads the templates word for word.
    private static let enabled = !TestSupport.isAutomated

    static func polish(_ template: String, names: [String]) async -> String? {
        if let cached = cache[template] { return cached }
        #if canImport(FoundationModels) && COACH_MODEL
        guard enabled else { return nil }
        guard #available(iOS 26.0, *) else { return nil }
        // Not ready yet (Apple Intelligence off, the model still downloading): ask again another time.
        guard !declined.contains(template), CoachModel.ready else { return nil }
        let reworded = await CoachModel.reword(template)
        // Moved on to another tip before the model answered: nothing learned about this one.
        if Task.isCancelled { return nil }
        let quotes = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”"))
        guard let text = reworded?.trimmingCharacters(in: quotes), CoachVoice.faithful(text, to: template, names: names) else {
            declined.insert(template)
            return nil
        }
        cache[template] = text
        return text
        #else
        return nil
        #endif
    }
}

#if canImport(FoundationModels) && COACH_MODEL
@available(iOS 26.0, *)
private enum CoachModel {
    /// Apple Intelligence is on and its model ready, and it speaks the language the app's tips are written in (the
    /// app's own strings, which may differ from the device region).
    static var ready: Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        let tips = Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en").languageCode
        return model.supportedLanguages.contains { $0.languageCode == tips }
    }

    /// The tip reworded, or nil when the model fails, refuses or the request is cancelled. A fresh session each
    /// time, so one tip's wording never leans on another's.
    static func reword(_ template: String) async -> String? {
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: template, options: GenerationOptions(temperature: 0.4))
            return response.content
        } catch {
            return nil
        }
    }

    private static let instructions = """
        You are the practice coach inside Timbre, a music app. Reword the tip you are given so it sounds warm, direct \
        and encouraging, like a good teacher talking to a student. Use one or two short sentences, in the same language \
        as the tip. Keep every number, unit, note name and chord name exactly as written. Add no new facts, numbers or \
        advice. Reply with the reworded tip only.
        """
}
#endif
