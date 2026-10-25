import Foundation
import Observation
import TimbreCore

/// The tuner's own state: what it tunes to (a string, or any note in chromatic mode), how that was chosen, which
/// strings have locked this session, and what the session has measured for its practice record.
///
/// `AppStore` owns one (`AppStore.tuner`) and forwards its tuner API to it, so screens keep reading
/// `store.selectedCourse`. Being observed on its own is the point: an automatic string change, a chromatic note
/// change, a lock or a lesson's next target redraws only the views that read them, never every screen that observes
/// the store. What changes with every reading (about 60 a second) is bookkeeping and is not observed at all.
@Observable
@MainActor
final class TunerSession {
    /// Chromatic mode: any note, named as it is heard, instead of the instrument's strings.
    var referenceMode = false
    /// The note chromatic mode tunes to, as MIDI (12...119).
    private(set) var referenceMidi = 69
    /// The string being tuned, by `Course.index`.
    var selectedCourse = 0
    /// The tuner follows what is played: the nearest string, or in chromatic mode the nearest note. Choosing a
    /// string or a note by hand turns it off.
    var automatic = true
    /// The strings that have locked in tune this session.
    private(set) var lockedCourses: Set<Int> = []
    /// Moves on with every full tune (every string locked), for the celebration.
    private(set) var celebrate = 0
    /// Seconds from the session's first reading to its last string locking, for the celebration and the share card.
    private(set) var lastTuneSeconds: Int?
    /// While true, readings target the octave (the intonation check) and never count as tuning.
    var intonationMode = false
    /// The pitch an ear game, a lesson or a song sets as the target; readings then never count as tuning.
    var gameTargetHz: Double?

    /// Automatic string detection pauses until then (system uptime, seconds), while the lock bell rings.
    @ObservationIgnored var autoQuietUntil: TimeInterval = 0
    /// Readings of the string being tuned this session (`count`).
    @ObservationIgnored private(set) var readingCount = 0
    @ObservationIgnored private var stableCount = 0
    @ObservationIgnored private var totalError = 0.0
    @ObservationIgnored private var started: (date: Date, uptime: TimeInterval)?
    /// Automatic detection: the string the last confident readings were nearest, and how many in a row.
    @ObservationIgnored private var heardCourse: Int?
    @ObservationIgnored private var heardCount = 0
    /// Strings whose first steady reading this session has gone into the string-health log.
    @ObservationIgnored private var sampledCourses: Set<Int> = []

    /// Readings count as tuning: not the intonation check, not a game's or a lesson's own target.
    var measuring: Bool { !intonationMode && gameTargetHz == nil }

    /// Every one of `courses` (`Course.index`) has locked this session.
    func allLocked(_ courses: [Int]) -> Bool { !courses.isEmpty && Set(courses).isSubset(of: lockedCourses) }

    // MARK: Choosing what to tune

    /// A string chosen by hand: the tuner stays on it.
    func choose(course index: Int) {
        selectedCourse = index
        automatic = false
    }

    /// A chromatic note chosen by hand: the tuner stays on it.
    func choose(referenceNote midi: Int) {
        referenceMidi = Self.clamped(midi)
        automatic = false
    }

    /// Chromatic mode, following the note played.
    func startChromatic() {
        referenceMode = true
        automatic = true
    }

    /// A confident reading nearest `course`. The tuner moves to a string once three readings running are nearest
    /// it; true when it moved.
    func heard(course index: Int) -> Bool {
        if heardCourse == index { heardCount += 1 } else { heardCourse = index; heardCount = 1 }
        guard heardCount >= 3, selectedCourse != index else { return false }
        selectedCourse = index
        return true
    }

    /// A reading too quiet or unsure to follow: the run of readings toward one string starts again.
    func heardNothing() {
        heardCourse = nil
        heardCount = 0
    }

    /// Chromatic mode heard `midi` (clamped to 12...119): the tuner names that note.
    func heard(note midi: Int) {
        let note = Self.clamped(midi)
        if note != referenceMidi { referenceMidi = note }
    }

    // MARK: Measuring

    /// Listening began: the session's clock starts, unless it is already running.
    func beginSession(at date: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if started == nil { started = (date, uptime) }
    }

    /// When the session began; nil before listening has.
    var startedAt: Date? { started?.date }

    /// How long the session has run, ms; nil before listening began.
    func elapsedMs(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int? {
        started.map { Int(max(0, uptime - $0.uptime) * 1000) }
    }

    /// A reading toward the session's record (while readings count as tuning): how many there were, how many held
    /// still, and how close the still ones were.
    func count(_ reading: TuningReading) {
        guard measuring, let cents = reading.cents, reading.frequency != nil else { return }
        readingCount += 1
        if reading.stable {
            stableCount += 1
            totalError += abs(cents)
        }
    }

    /// The first steady reading of `course` this session goes into its string-health log: true the first time only.
    func sampleOnce(_ course: Int) -> Bool { sampledCourses.insert(course).inserted }

    /// `course` came into tune. `fresh`: it hadn't locked yet this session; `completed`: it was the last of `courses`
    /// to lock.
    func lock(_ course: Int, of courses: [Int]) -> (fresh: Bool, completed: Bool) {
        guard !lockedCourses.contains(course) else { return (false, false) }
        let before = allLocked(courses)
        lockedCourses.insert(course)
        return (true, !before && allLocked(courses))
    }

    /// Strum to tune read every string in tune: those not locked yet lock now. Returns them in `courses` order
    /// (empty when every string had already locked).
    func lockAll(_ courses: [Int]) -> [Int] {
        let fresh = courses.filter { !lockedCourses.contains($0) }
        if !fresh.isEmpty { lockedCourses.formUnion(fresh) }
        return fresh
    }

    /// Every string locked: the celebration runs, timed from the session's first reading.
    func completeFullTune(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        lastTuneSeconds = started.map { Int((uptime - $0.uptime).rounded()) }
        celebrate += 1
    }

    /// What a tuning session's practice record says.
    struct Summary: Equatable {
        let started: Date
        let readings: Int
        let stableReadings: Int
        let meanAbsoluteCents: Double?
        let durationMs: Int
    }

    /// The session, once it is worth a practice record: three readings or more over four seconds or more.
    func summary(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Summary? {
        guard readingCount >= 3, let started else { return nil }
        let duration = max(0, Int((uptime - started.uptime) * 1000))
        guard duration >= 4000 else { return nil }
        return Summary(started: started.date, readings: readingCount, stableReadings: stableCount,
                       meanAbsoluteCents: stableCount > 0 ? totalError / Double(stableCount) : nil, durationMs: duration)
    }

    /// A fresh session: nothing measured, nothing locked, automatic detection counting from nothing (a new
    /// instrument, tuning or mode, or a session just saved).
    func resetMeasurements() {
        restartCounts()
        started = nil
        sampledCourses = []
        if !lockedCourses.isEmpty { lockedCourses = [] }
    }

    /// The session so far has its practice record (strum to tune saved one): measuring starts again, from now while
    /// listening, and the locked strings stay locked.
    func restartMeasuring(listening: Bool, at date: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        restartCounts()
        started = listening ? (date, uptime) : nil
    }

    private func restartCounts() {
        readingCount = 0
        stableCount = 0
        totalError = 0
        heardNothing()
    }

    private static func clamped(_ midi: Int) -> Int { min(119, max(12, midi)) }
}
