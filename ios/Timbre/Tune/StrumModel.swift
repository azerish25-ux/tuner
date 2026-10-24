import Foundation
import Observation
import SwiftUI
import TimbreCore

// MARK: - Analysis (audio-analysis queue)

/// Strum to tune, off the main thread. The microphone's raw frames arrive on the audio-analysis queue
/// (`AudioService.frames`) and go to a `PolyTuner` made for the instrument's open strings, rebuilt whenever the
/// sample rate or the strings change. A strum's attack is reported at once, so the strings on screen ring with it,
/// and its reading once the tuner has heard the strings ring (about 0.65 s later). Serialised by its own lock,
/// like `LessonAnalyzer`.
final class StrumListener: @unchecked Sendable {
    /// Attacks closer together than this are one strum (a slow strum trips the detector once per few strings).
    static let strumSpan = 0.3
    private let lock = NSLock()
    private var strings: [Double] = []
    private var rate = 0.0
    private var tuner: PolyTuner?
    private var onsets: OnsetDetector?
    private var lastAttack = -Double.infinity
    private let onAttack: @MainActor () -> Void
    private let onReading: @MainActor (PolyReading) -> Void

    init(onAttack: @escaping @MainActor () -> Void, onReading: @escaping @MainActor (PolyReading) -> Void) {
        self.onAttack = onAttack
        self.onReading = onReading
    }

    /// New open-string pitches (another tuning, reference pitch or temperament): the next frames start a fresh tuner.
    func retune(_ strings: [Double]) {
        lock.lock(); defer { lock.unlock() }
        guard strings != self.strings else { return }
        self.strings = strings
        tuner = nil
    }

    /// One buffer of microphone audio, on the analysis queue.
    func feed(_ samples: [Float], rate: Double) {
        lock.lock(); defer { lock.unlock() }
        guard rate.isFinite, rate >= 8000, !strings.isEmpty, strings.allSatisfy({ $0.isFinite && $0 > 0 }) else { return }
        if tuner == nil || rate != self.rate {
            self.rate = rate
            tuner = PolyTuner(strings: strings, sampleRate: rate)
            onsets = OnsetDetector(sampleRate: rate)
            lastAttack = -.infinity
        }
        if let onsets {
            for time in onsets.process(samples) where time - lastAttack > Self.strumSpan {
                lastAttack = time
                let callback = onAttack
                Task { @MainActor in callback() }
            }
        }
        if let reading = tuner?.feed(samples) {
            let callback = onReading
            Task { @MainActor in callback(reading) }
        }
    }
}

// MARK: - Screen state (main actor)

/// The strum screen's state: the latest strum read (one that reached at least two strings) and when the strings
/// last rang. It owns the `StrumListener` while the screen is up and hands the microphone back when it goes.
@Observable
@MainActor
final class StrumModel {
    /// The latest strum heard on at least two strings (or courses); nil until the first.
    private(set) var reading: PolyReading?
    /// Counts the readings kept, for the effects that play once per strum.
    private(set) var readings = 0
    /// The latest strum's attack, in seconds since the reference date: the strings on screen ring from it.
    private(set) var attackAt: Double?
    /// A strum is ringing on screen (the string canvases pause otherwise).
    private(set) var ringing = false
    /// An attack was heard and its reading has not come yet.
    private(set) var pending = false
    /// The latest strum reached fewer than two strings: "strum them all together", for a few seconds.
    private(set) var thin = false
    /// When the screen opened, in seconds since the reference date: the hint's sweep counts from it.
    let hintStart = Date.timeIntervalSinceReferenceDate

    @ObservationIgnored private var listener: StrumListener?
    @ObservationIgnored private var strings: [Double] = []
    /// Each meter's strings, as positions in `strings` (a unison pair is one meter).
    @ObservationIgnored private var groups: [[Int]] = []
    @ObservationIgnored private var ringTask: Task<Void, Never>?
    @ObservationIgnored private var thinTask: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?

    /// Seconds a strum rings on screen.
    static let ringSeconds = 1.8
    /// Seconds the "strum them all together" nudge stays.
    static let thinSeconds = 2.6

    /// Takes the microphone's frames (and starts listening if it was off).
    func start(store: AppStore) {
        guard listener == nil else { return }
        let made = StrumListener(onAttack: { [weak self] in self?.attacked() },
                                 onReading: { [weak self] reading in self?.received(reading) })
        listener = made
        configure(store)
        store.beginStrum(frames: { samples, rate in made.feed(samples, rate: rate) })
        #if DEBUG
        if Self.demo { playDemo() }
        #endif
    }

    /// Hands the microphone back to the tuner (still listening). The latest reading stays on screen.
    func stop(store: AppStore) {
        guard listener != nil else { return }
        listener = nil
        ringTask?.cancel(); thinTask?.cancel(); demoTask?.cancel()
        ringing = false
        pending = false
        thin = false
        store.endStrum()
    }

    /// The strings changed under the screen (a tuning, reference pitch or temperament): start over.
    func retune(store: AppStore) {
        configure(store)
        reading = nil
        thin = false
        pending = false
    }

    private func configure(_ store: AppStore) {
        let courses = store.courses
        strings = store.strumTargets
        groups = CourseGrouping.groups(courses).map { group in
            group.courses.compactMap { course in courses.firstIndex { $0.index == course.index } }
        }
        listener?.retune(strings)
    }

    private func attacked() {
        guard listener != nil else { return }
        attackAt = Date.timeIntervalSinceReferenceDate
        ringing = true
        pending = true
        ringTask?.cancel()
        ringTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(StrumModel.ringSeconds))
            guard !Task.isCancelled else { return }
            self?.ringing = false
            self?.pending = false
        }
    }

    private func received(_ reading: PolyReading) {
        // A reading that arrives after the screen let go of the microphone, or made for strings that have since changed.
        guard listener != nil, reading.strings.map(\.targetHz) == strings else { return }
        // The attack can slip past the onset detector (a soft strum): let the strings ring as the reading lands.
        if Date.timeIntervalSinceReferenceDate - (attackAt ?? 0) > 1.5 { attacked() }
        pending = false
        let heard = groups.filter { group in
            guard let lead = group.first, reading.strings.indices.contains(lead) else { return false }
            return reading.strings[lead].isHeard
        }.count
        guard heard >= 2 else {
            thin = true
            thinTask?.cancel()
            thinTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(StrumModel.thinSeconds))
                guard !Task.isCancelled else { return }
                self?.thin = false
            }
            return
        }
        thinTask?.cancel()
        thin = false
        self.reading = reading
        readings += 1
    }

    #if DEBUG
    /// Screenshots and UI tests (TIMBRE_DEMO_PITCH=1) have no microphone: the screen hears one strum of
    /// `StrumDemo.reading` shortly after it opens.
    static var demo: Bool { ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" }

    private func playDemo() {
        demoTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            self.attacked()
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            self.received(StrumDemo.reading(strings: self.strings, groups: self.groups))
        }
    }
    #endif
}

#if DEBUG
/// The demo strum: most strings close, the second well flat (the one to tune first), one sharp, and the fifth
/// approximate (on a guitar, B3 under the low E's third harmonic, as `PolyTuner` reports it in a real strum).
enum StrumDemo {
    /// Cents by meter, in course order.
    static let offsets: [Double] = [-3.2, -12.4, 2.1, 0.4, 3.6, 8.3, -6.2, 1.1, -2.4, 5.2, 0.3, -1.4]
    /// The meter read as `.shared`.
    static let approximate = 4

    static func reading(strings: [Double], groups: [[Int]]) -> PolyReading {
        var cents = [Double](repeating: 0, count: strings.count)
        var shared = [Bool](repeating: false, count: strings.count)
        for (position, group) in groups.enumerated() {
            for slot in group where strings.indices.contains(slot) {
                cents[slot] = offsets[position % offsets.count]
                shared[slot] = position == approximate && groups.count > approximate + 1
            }
        }
        let readings = strings.indices.map { slot in
            PolyReading.StringReading(index: slot, targetHz: strings[slot],
                                      frequencyHz: strings[slot] * PitchMath.ratio(cents: cents[slot]),
                                      confidence: shared[slot] ? 0.45 : 0.9,
                                      evidence: shared[slot] ? .shared : .fundamental)
        }
        return PolyReading(strings: readings, onsetTime: 0, levelDbfs: -24)
    }
}
#endif

// MARK: - What the screen shows

/// What the strum screen draws: a meter per string (a unison pair, heard as one pitch, shares one) in the order
/// the strings sit on the instrument (mirrored for left-handed players, as on the string rail), and the verdict
/// on the whole strum.
struct StrumBoard {
    struct Meter: Identifiable, Equatable {
        /// The lead string's course index (the string rail's chip id).
        let id: Int
        /// The strings it stands for, by course index.
        let courses: [Int]
        /// The note and its octave (or cue), as the string rail splits them.
        let name: String
        let cue: String
        /// The label as the tuner shows it ("A2"), for the summary and VoiceOver.
        let note: String
        /// Strings on the meter (2 for a unison pair).
        let count: Int
        /// The number players call the string by, 1 the thinnest (from its peg-head anchor: "s5" on a guitar's A,
        /// "c4" on a mandolin's G pair); nil without one. The lane's chip shows it: colour never names a string.
        let number: Int?
        /// String gauge by pitch: 0 thinnest … 1 thickest.
        let gauge: Double
        /// Cents from the target (positive sharp); nil when not heard.
        let cents: Double?
        let evidence: PolyReading.Evidence?

        var heard: Bool { cents != nil }
        /// Read from a peak shared with another string's overtone: good to a few cents.
        var approximate: Bool { evidence == .shared }
        /// Whole cents, as every tuner number shows them.
        var shown: Int? { cents.map { Int($0.rounded()) } }
        /// Inside the tuner's own lock band (Settings › Precision), judged on the whole cents shown.
        func inTune(band: Double) -> Bool { shown.map { Double(abs($0)) <= band } ?? false }
        /// Flat strings go up (tighten), sharp ones down (loosen).
        var tuneUp: Bool { (cents ?? 0) < 0 }
    }

    enum Verdict: Equatable {
        /// No strum read yet.
        case waiting
        /// Every string heard and inside the lock band.
        case allInTune
        /// The string furthest out, to tune first.
        case tune(Meter)
        /// Every string heard is in tune; this many were not heard.
        case missing(Int)
    }

    let meters: [Meter]
    let verdict: Verdict
    /// Meters inside the lock band.
    let inTune: Int

    var waiting: Bool { verdict == .waiting }
    /// Mean distance from the targets of the strings heard (cents), for the practice record.
    var meanCents: Double {
        let heard = meters.compactMap(\.cents)
        return heard.isEmpty ? 0 : heard.map(abs).reduce(0, +) / Double(heard.count)
    }
    /// The meter to tune first, if any.
    var focus: Int? {
        if case .tune(let meter) = verdict { return meter.id }
        return nil
    }

    /// The one string left once a strum reads every other in tune (5 of 6 on a guitar, 3 of 4 on a ukulele): its
    /// lane zooms into the single-string fine-tune (`StrumFinaleLane`).
    var lastString: Meter? {
        guard meters.count >= 3, case .tune(let meter) = verdict, inTune == meters.count - 1,
              meters.allSatisfy(\.heard) else { return nil }
        return meter
    }

    /// "s6" → 6, "c4" → 4: the digits a peg-head anchor ends in.
    private static func number(anchor: String?) -> Int? {
        guard let anchor else { return nil }
        let digits = String(anchor.reversed().prefix { $0.isNumber }.reversed())
        return digits.isEmpty ? nil : Int(digits)
    }

    @MainActor static func make(store: AppStore, reading: PolyReading?, band: Double) -> StrumBoard {
        let courses = store.courses
        let groups = CourseGrouping.groups(courses)
        let pitches = groups.map { store.target(for: $0.lead) }
        let lowest = max(1, pitches.min() ?? 1), highest = max(lowest, pitches.max() ?? lowest)
        let span = log2(highest / lowest)
        var meters: [Meter] = []
        for (position, group) in groups.enumerated() {
            let label = TargetLabelFormatter.splitCue(store.courseLabel(group.lead))
            let parts = NoteReadout.split(label.main)
            let slot = courses.firstIndex { $0.index == group.lead.index }
            var heard: PolyReading.StringReading?
            if let reading, let slot, reading.strings.indices.contains(slot) { heard = reading.strings[slot] }
            let gauge = span > 0 ? 1 - log2(max(lowest, pitches[position]) / lowest) / span : 0.5
            meters.append(Meter(id: group.id, courses: group.courses.map(\.index), name: parts.name,
                                cue: label.cue ?? parts.octave, note: label.main, count: group.count,
                                number: number(anchor: group.lead.anchorId),
                                gauge: gauge, cents: heard?.cents, evidence: heard?.evidence))
        }
        if store.settings.handedness == "left" { meters.reverse() }
        let inTune = meters.filter { $0.inTune(band: band) }.count
        return StrumBoard(meters: meters, verdict: verdict(meters, read: reading != nil, band: band), inTune: inTune)
    }

    /// Largest offset first; once every string heard is in tune, the ones not heard; then all in tune.
    private static func verdict(_ meters: [Meter], read: Bool, band: Double) -> Verdict {
        guard read else { return .waiting }
        let off = meters.filter { $0.heard && !$0.inTune(band: band) }
        if let worst = off.max(by: { abs($0.cents ?? 0) < abs($1.cents ?? 0) }) { return .tune(worst) }
        let missing = meters.filter { !$0.heard }.count
        return missing == 0 ? .allInTune : .missing(missing)
    }
}

// MARK: - Words

/// The strum screen's sentences, shown and spoken. The cents use the ¢ sign on screen and "cents" aloud.
@MainActor
enum StrumWords {
    /// "Tune A2 up 12¢ first".
    static func tuneFirst(_ meter: StrumBoard.Meter) -> String {
        let amount = abs(meter.shown ?? 0)
        return meter.tuneUp ? String(localized: "Tune \(meter.note) up \(amount)¢ first")
                            : String(localized: "Tune \(meter.note) down \(amount)¢ first")
    }

    /// The tuner's own turn words: "Tighten · 12¢ flat", "Loosen · 8¢ sharp".
    static func turn(_ meter: StrumBoard.Meter) -> String {
        let amount = abs(meter.shown ?? 0)
        return meter.tuneUp ? String(localized: "Tighten · \(amount)¢ flat") : String(localized: "Loosen · \(amount)¢ sharp")
    }

    /// "−12¢"; an em dash when not heard. An approximate reading carries the "≈ estimate" badge beside it.
    static func cents(_ meter: StrumBoard.Meter) -> String {
        NoteReadout.signed(meter.shown)
    }

    /// One announcement for the whole strum.
    static func spoken(_ board: StrumBoard) -> String {
        switch board.verdict {
        case .waiting:
            return String(localized: "Strum all open strings")
        case .allInTune:
            return String(localized: "All strings in tune")
        case .tune(let meter):
            let amount = abs(meter.shown ?? 0)
            let action = meter.tuneUp ? String(localized: "Tune \(meter.note) up \(amount) cents first")
                                      : String(localized: "Tune \(meter.note) down \(amount) cents first")
            return String(localized: "\(board.inTune) of \(board.meters.count) in tune") + ". " + action
        case .missing(let count):
            return String(localized: "\(count) not heard. Strum again.")
        }
    }

    /// "String 2, A2"; a pair "Strings 3 and 4, D4", as the string rail names them.
    static func name(_ meter: StrumBoard.Meter) -> Text {
        if meter.courses.count == 2 { return Text("Strings \(meter.courses[0]) and \(meter.courses[1]), \(meter.note)") }
        return Text("String \(meter.id), \(meter.note)")
    }

    /// "In tune", "12 cents flat", "Not heard"; ", estimate" after an approximate reading (the badge's word).
    static func state(_ meter: StrumBoard.Meter, band: Double, waiting: Bool) -> Text {
        if waiting { return Text(verbatim: "") }
        guard let shown = meter.shown else { return Text("Not heard") }
        let value = Double(abs(shown)) <= band ? String(localized: "In tune") : NoteReadout.spoken(shown, locked: false)
        return meter.approximate ? Text("\(value), estimate") : Text(verbatim: value)
    }

    /// The zoom's announcement: "5 of 6 in tune. Fine-tune A2".
    static func zoomed(_ board: StrumBoard, meter: StrumBoard.Meter) -> String {
        String(localized: "\(board.inTune) of \(board.meters.count) in tune") + ". " + String(localized: "Fine-tune \(meter.note)")
    }

    /// The zoomed lane's live words, as the tuner's status line says them: "Tighten · 12¢ flat", "Hold it…",
    /// "In tune"; "Pluck the string" with no pitch.
    static func live(_ shown: Int?, locked: Bool, band: Double) -> String {
        if locked { return String(localized: "In tune") }
        guard let shown else { return String(localized: "Pluck the string") }
        let amount = abs(shown)
        if Double(amount) <= band { return String(localized: "Hold it…") }
        return shown < 0 ? String(localized: "Tighten · \(amount)¢ flat") : String(localized: "Loosen · \(amount)¢ sharp")
    }
}
