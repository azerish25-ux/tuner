import Foundation

public struct UserSettings: Codable, Equatable, Sendable {
    public var referencePitchHz: Double = 440
    public var temperamentId = "equal"
    public var theme = "dark"
    public var skin = "brass"
    public var reducedMotion = false
    public var hapticsEnabled = true
    /// The app language: "system" follows the device (or the language chosen for Timbre in iOS Settings); a code
    /// ("de", "zh-CN") is one picked in Timbre's Settings. `TimbreLocalization` resolves it.
    public var language = TimbreLocalization.system
    public var recentInstrumentIds: [String] = []
    public var analysisWindowOverride: Int?
    public var micSensitivity = 60
    public var confidenceThreshold = 0.75
    public var notation = "english"
    public var capo = 0
    public var transposition = 0
    public var handedness = Handedness.right
    public var lastTuningIds: [String: String] = [:]
    public var selectedInstrumentId = "guitar.acoustic.6"
    public var selectedPhotoAsset: String?
    /// Never set by any screen; kept so older files still decode. Usage sharing is `shareUsageData`.
    public var telemetryEnabled = false
    /// Settings › Share anonymous usage data: nil until the player chooses (sharing is on until then, `sharesUsage`).
    public var shareUsageData: Bool? = nil
    public var selectedVoiceLevel: Int?
    public var onboardingCompleted: Bool?
    public var playerLevel: String?
    public var goal: String?
    public var stageMode: String?
    public var metronomeBpm: Int?
    public var metronomeBeats: Int?
    public var metronomeSubdivision: Int?
    public var metronomeSound: String?
    public var metronomeBeatLevels: [Int]?
    public var droneMidi: Int?
    public var droneVoice: String?
    public var fullTunes: Int?
    /// Daily practice completion: "yyyy-MM-dd" -> activity ids.
    public var dailyDone: [String: [String]]?
    /// Today's tool reps as first shown: "yyyy-MM-dd" -> activity ids (`DailySet.toolReps`), today's day only. Kept
    /// all day so the plan doesn't reshuffle when the tuner switches instrument.
    public var dailyPlan: [String: [String]]?
    public var earLevels: [String: Int]?
    public var customTunings: [CustomTuning]?
    /// XP, quests, achievements and string-health samples.
    public var progress: ProgressState?
    /// Stars and position in the Learn courses.
    public var learn: LearnProgress?
    /// The lock tolerance (`TuningPrecision` raw value); unset means Beginner, the original ±5¢.
    public var tuningPrecision: String?
    /// True once the player picks a note-naming system in Settings; until then `notation` follows the app language.
    public var notationChosen: Bool?
    /// Spaced review's schedule (`ReviewDeck`); unset until the first lesson after it arrived (Learn's weak spots seed it).
    public var spacedReview: ReviewDeck?
    /// The chord last opened in the Chords tool: the tool opens on it again and the Play hub's tile strums it. Unset
    /// until the tool's chord is first changed.
    public var lastChord: ChordChoice?
    /// "Show me" demonstrations that have played by themselves, by course id (`ShowMeKey`, oldest first). The first
    /// time a chord or a strum pattern appears in a course its 3D demonstration plays unasked; after that it waits for
    /// "Show me". Unset until the first one plays.
    public var shownDemos: [String: [String]]?

    // The fields below are plain values with defaults: the lenient decoder gives a file without them (or with a value
    // this version can't read) the default, so they need not be optional.

    /// True once the player picks an app language in Settings. Until then an "en" saved when English was the default
    /// opens as "system", so the app follows the device.
    public var languageChosen = false
    /// The tuner on its own: no quest line, XP or header chips.
    public var simpleTuner = false
    /// No XP pills, counters or rewards that interrupt practice.
    public var calmMode = false
    /// The phone pulses at the beat between the string and its target, slowing as they meet and still at the lock.
    public var tuneByFeel = false
    /// The metronome's beat is felt on the phone as well as heard.
    public var feelTheBeat = false
    /// Lessons play the band on the speaker while the microphone listens (voice processing, after its self-test);
    /// off, the band needs headphones and the speaker plays only the click.
    public var bandOnSpeaker = false
    /// Chord charts drawn as printed (right-handed) even when `handedness` is left-handed.
    public var chartsAsPrinted = false
    /// Onboarding's "Your first chord" has been played or skipped, so it isn't offered again.
    public var firstChordDone = false

    public init() {}
}

/// Which hand frets, and for a left-handed player how the instrument is strung. Words never mirror, and every string
/// keeps its number (1 is the thinnest) however the instrument is held.
public enum Handedness: String, Codable, CaseIterable, Sendable {
    case right
    /// A left-handed instrument, or one restrung: the mirror image of a right-handed one.
    case left
    /// A right-handed instrument turned over and played left-handed as strung: string 1 nearest the face.
    case leftUpsideDown

    /// The fretting hand is the right one, either left-handed way.
    public var isLeftHanded: Bool { self != .right }
}

extension UserSettings {
    /// Reads what it can and keeps the default for the rest. A missing key (a file from before the field existed), a
    /// value of the wrong type, or one only a later version knows never costs the other settings; an unreadable custom
    /// tuning is dropped on its own. Only a value that isn't a JSON object at all fails.
    public init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func read<Value: Decodable>(_ value: inout Value, _ key: CodingKeys) {
            if let decoded = try? container.decodeIfPresent(Value.self, forKey: key) { value = decoded }
        }
        read(&referencePitchHz, .referencePitchHz)
        read(&temperamentId, .temperamentId)
        read(&theme, .theme)
        read(&skin, .skin)
        read(&reducedMotion, .reducedMotion)
        read(&hapticsEnabled, .hapticsEnabled)
        read(&language, .language)
        read(&recentInstrumentIds, .recentInstrumentIds)
        read(&analysisWindowOverride, .analysisWindowOverride)
        read(&micSensitivity, .micSensitivity)
        read(&confidenceThreshold, .confidenceThreshold)
        read(&notation, .notation)
        read(&capo, .capo)
        read(&transposition, .transposition)
        read(&handedness, .handedness)
        read(&lastTuningIds, .lastTuningIds)
        read(&selectedInstrumentId, .selectedInstrumentId)
        read(&selectedPhotoAsset, .selectedPhotoAsset)
        read(&telemetryEnabled, .telemetryEnabled)
        read(&shareUsageData, .shareUsageData)
        read(&selectedVoiceLevel, .selectedVoiceLevel)
        read(&onboardingCompleted, .onboardingCompleted)
        read(&playerLevel, .playerLevel)
        read(&goal, .goal)
        read(&stageMode, .stageMode)
        read(&metronomeBpm, .metronomeBpm)
        read(&metronomeBeats, .metronomeBeats)
        read(&metronomeSubdivision, .metronomeSubdivision)
        read(&metronomeSound, .metronomeSound)
        read(&metronomeBeatLevels, .metronomeBeatLevels)
        read(&droneMidi, .droneMidi)
        read(&droneVoice, .droneVoice)
        read(&fullTunes, .fullTunes)
        read(&dailyDone, .dailyDone)
        read(&dailyPlan, .dailyPlan)
        read(&earLevels, .earLevels)
        if let tunings = try? container.decodeIfPresent([Lossy<CustomTuning>].self, forKey: .customTunings) {
            customTunings = tunings.compactMap(\.value)
        }
        read(&progress, .progress)
        read(&learn, .learn)
        read(&tuningPrecision, .tuningPrecision)
        read(&notationChosen, .notationChosen)
        read(&spacedReview, .spacedReview)
        read(&lastChord, .lastChord)
        read(&shownDemos, .shownDemos)
        read(&languageChosen, .languageChosen)
        read(&simpleTuner, .simpleTuner)
        read(&calmMode, .calmMode)
        read(&tuneByFeel, .tuneByFeel)
        read(&feelTheBeat, .feelTheBeat)
        read(&bandOnSpeaker, .bandOnSpeaker)
        read(&chartsAsPrinted, .chartsAsPrinted)
        read(&firstChordDone, .firstChordDone)
    }
}

/// A list element decoded on its own: one that can't be read becomes nil instead of failing the whole list.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
}

extension UserSettings {
    /// The most demonstrations remembered per course, the oldest forgotten first: far more chords and patterns than
    /// any course teaches, so the file stays small.
    public static let shownDemoLimit = 400

    /// Whether demonstration `key` (`ShowMeKey`) has already played by itself in course `course`.
    public func hasShownDemo(_ key: String, in course: String) -> Bool {
        shownDemos?[course]?.contains(key) ?? false
    }

    /// Remembers that demonstration `key` has played in course `course`, so it plays by itself only once there.
    public mutating func markDemoShown(_ key: String, in course: String) {
        var keys = shownDemos?[course] ?? []
        guard !keys.contains(key) else { return }
        keys.append(key)
        if keys.count > Self.shownDemoLimit { keys.removeFirst(keys.count - Self.shownDemoLimit) }
        var all = shownDemos ?? [:]
        all[course] = keys
        shownDemos = all
    }
}

/// What a "Show me" demonstration teaches, as a key that stays the same wherever it appears in a course: a chord by
/// its shape (the frets from its first one, whatever the lesson calls it or however it numbers the fingers), a strum
/// by its pattern in its bar (whatever the tempo, the chord or the step it comes in).
public enum ShowMeKey {
    public static func chord(_ chord: ChordSpec) -> String {
        let frets = chord.frets.map(String.init).joined(separator: ",")
        let base = max(1, chord.baseFret ?? 1)
        return base > 1 ? "chord:\(frets)@\(base)" : "chord:\(frets)"
    }

    public static func strum(pattern: [Double], beatsPerBar: Int) -> String {
        let beats = pattern.filter(\.isFinite).sorted().map(Self.beat).joined(separator: ",")
        return "strum:\(max(1, beatsPerBar))/\(beats)"
    }

    /// A beat as written: "2" on the beat, "1.5" between.
    private static func beat(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1_000 { return String(Int(value)) }
        return String(value)
    }
}

extension UserSettings {
    /// A chord as the Chords tool picks it: a root pitch class (0 = C) and a quality (`ChordFormula.id`).
    public struct ChordChoice: Codable, Equatable, Sendable {
        public var root: Int
        public var formula: String

        public init(root: Int, formula: String) {
            self.root = root
            self.formula = formula
        }
    }
}

extension UserSettings {
    /// Until the player picks a note-naming system, it follows the app language: German letters (B natural is H)
    /// for German, letters otherwise. A system picked in Settings, or one set before this existed other than
    /// letters (solfège, sargam, numbers), is never changed. `systemLanguage` is the device's language
    /// (e.g. "de-DE"), used when the app language is "system".
    public mutating func applyNotationDefault(systemLanguage: String?) {
        guard notationChosen != true, notation == "english" || notation == "german" else { return }
        notation = NoteNames.defaultSystem(language: language == TimbreLocalization.system ? (systemLanguage ?? "en") : language)
    }
}

extension UserSettings {
    /// Anonymous usage events leave the device: the player's choice once made, on until then.
    public var sharesUsage: Bool { shareUsageData ?? true }
}

extension UserSettings {
    /// The lock tolerance; an unset or unknown value reads as Beginner.
    public var precision: TuningPrecision {
        get { tuningPrecision.flatMap(TuningPrecision.init(rawValue:)) ?? .beginner }
        set { tuningPrecision = newValue.rawValue }
    }
}

public struct PracticeRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var instrumentId: String
    public var tuningId: String?
    public var kind: String
    public var count: Int
    public var stableCount: Int
    public var meanAbsoluteCents: Double?
    public var voiceResult: VoiceResult?
    public var durationMs: Int?
    public init(id: UUID = UUID(), date: Date = Date(), instrumentId: String, tuningId: String? = nil,
                kind: String, count: Int, stableCount: Int, meanAbsoluteCents: Double? = nil,
                voiceResult: VoiceResult? = nil, durationMs: Int? = nil) {
        self.id = id; self.date = date; self.instrumentId = instrumentId; self.tuningId = tuningId
        self.kind = kind; self.count = count; self.stableCount = stableCount
        self.meanAbsoluteCents = meanAbsoluteCents; self.voiceResult = voiceResult
        self.durationMs = durationMs
    }
}

public enum LocalStoreError: Error, Equatable {
    /// A write that would leave the saved state outside its bounds; nothing was written.
    case invalidState(String)
}

/// One atomic snapshot keeps settings, history and demonstrated evidence consistent.
/// Caller serializes access (the app uses its main actor).
///
/// Opening never locks anyone out. The file is read leniently (`UserSettings.init(from:)`; an unreadable practice
/// record is dropped on its own) and brought back inside the bounds every write is checked against. A file that
/// can't be read as a state at all is set aside as `timbre-state.corrupt-<time>.json`, and the copy kept before the
/// last save (`timbre-state.bak.json`) opens instead, else a fresh start; `recovery` says which, so the app can tell
/// the player. `init` throws only when the system won't hand the file over (it is protected until the first unlock,
/// say), and then the file is left exactly as it is.
public final class LocalStore {
    public static let recentInstrumentLimit = 12
    public static let fileName = "timbre-state.json"
    /// The file as it stood before the latest save: what opens if the file itself can't be read.
    public static let backupFileName = "timbre-state.bak.json"
    /// Files set aside because they couldn't be read start with this, then the time they were set aside.
    public static let quarantinePrefix = "timbre-state.corrupt-"
    /// The format this version writes. Earlier files open; a later version's file opens for what this one understands.
    public static let currentVersion = 1
    /// Past this many records, old history rolls up (`rolledUp`) so the file stops growing with every session.
    public static let recordLimit = 2_000
    /// Practice from the last this many days is always kept session by session (recaps, comparisons and the coach
    /// read a few weeks at most).
    public static let rollUpAfterDays = 180
    /// Set-aside files kept for diagnosis; older ones are deleted.
    static let quarantineLimit = 3

    /// Where the app keeps its state: Application Support/Timbre. Tests and UI tests pass their own directory.
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Timbre", isDirectory: true)
    }

    /// How opening got past a file it couldn't read.
    public enum Recovery: Equatable, Sendable {
        /// The copy from before the last save opened; that save's change may be missing.
        case restoredBackup
        /// Nothing could be read: a fresh start (the unreadable file is kept, `quarantinedFile`).
        case startedFresh
    }

    private struct State: Codable, Equatable {
        var version = LocalStore.currentVersion
        var settings = UserSettings()
        var records: [PracticeRecord] = []
        var demonstratedLevels: Set<Int> = []

        init() {}

        /// Settings and history must be there; a record or a level that can't be read is dropped on its own.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? 1
            settings = try container.decode(UserSettings.self, forKey: .settings)
            records = try container.decode([Lossy<PracticeRecord>].self, forKey: .records).compactMap(\.value)
            let levels = (try? container.decodeIfPresent([Lossy<Int>].self, forKey: .demonstratedLevels)) ?? []
            demonstratedLevels = Set(levels.compactMap(\.value))
        }
    }

    private let fileURL: URL
    private let backupURL: URL
    private var state: State
    /// The file on disk is one this store opened or wrote, so it may become the backup.
    private var fileIsGood = false
    /// Settings made current by `stageSettings` and not written yet.
    private var staged = false
    /// The history size that triggers a roll-up (tests lower it).
    public var historyLimit = LocalStore.recordLimit
    public var settings: UserSettings { state.settings }
    public var records: [PracticeRecord] { state.records }
    public var demonstratedLevels: Set<Int> { state.demonstratedLevels }
    /// Staged settings are waiting for `flush()` (or the next write, which carries them).
    public var hasUnsavedChanges: Bool { staged }
    /// Set when opening had to get past a file it couldn't read.
    public private(set) var recovery: Recovery?
    /// Where the unreadable file was set aside, if one was.
    public private(set) var quarantinedFile: URL?

    public init(directory: URL) throws {
        let files = FileManager.default
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(Self.fileName)
        backupURL = directory.appendingPathComponent(Self.backupFileName)
        var unreadable = false
        if files.fileExists(atPath: fileURL.path) {
            // A read the system refuses throws from here and leaves the file alone: it is fine, just not available yet.
            let data = try Data(contentsOf: fileURL)
            if let opened = Self.open(data) {
                state = opened
                fileIsGood = true
                return
            }
            unreadable = true
            quarantinedFile = try? Self.setAside(in: directory)
        }
        // No file, or one set aside: the backup if there is one (a file set aside on an earlier launch included).
        if let backup = try? Data(contentsOf: backupURL), let opened = Self.open(backup) {
            state = opened
            recovery = .restoredBackup
        } else {
            state = State()
            if unreadable { recovery = .startedFresh }
        }
        // The recovered state becomes the file at once; if that fails, the next save writes it.
        if recovery != nil { try? persist(state) }
    }

    /// Moves the state file in `directory` aside as `timbre-state.corrupt-<time>.json`, so the next opening starts
    /// from the backup or afresh; the newest few set-aside files are kept. Nil when there is no state file.
    @discardableResult
    public static func setAside(in directory: URL, now: Date = Date()) throws -> URL? {
        let files = FileManager.default
        let source = directory.appendingPathComponent(fileName)
        guard files.fileExists(atPath: source.path) else { return nil }
        let stamp = quarantineStamp(now)
        var destination = directory.appendingPathComponent(quarantinePrefix + stamp + ".json")
        var attempt = 1
        while files.fileExists(atPath: destination.path) {
            destination = directory.appendingPathComponent(quarantinePrefix + stamp + "-\(attempt).json")
            attempt += 1
        }
        try files.moveItem(at: source, to: destination)
        pruneQuarantine(in: directory)
        return destination
    }

    public func saveSettings(_ settings: UserSettings) throws {
        try persist(candidate(settings))
    }
    /// Validates settings and makes them current without writing the file, so a burst of changes costs one write:
    /// `flush()` writes them, as does any other save in the meantime. Invalid settings throw and change nothing.
    public func stageSettings(_ settings: UserSettings) throws {
        let next = candidate(settings)
        try Self.validate(next)
        state = next
        staged = true
    }
    /// Writes staged settings; nothing to do when none are waiting. On failure they stay staged (and current).
    public func flush() throws {
        guard staged else { return }
        try persist(state)
    }
    public func append(_ record: PracticeRecord) throws {
        var candidate = state
        candidate.records.removeAll { $0.id == record.id }
        candidate.records.append(record)
        candidate.records.sort { $0.date > $1.date }
        if candidate.records.count > historyLimit {
            candidate.records = Self.rolledUp(candidate.records, now: Date(), calendar: .current)
        }
        if let level = Self.evidencedLevel(record) { candidate.demonstratedLevels.insert(level) }
        try persist(candidate)
    }
    /// Clearing history also removes its vocal progress evidence; settings remain.
    public func clearHistory() throws {
        var candidate = state
        candidate.records = []; candidate.demonstratedLevels = []
        try persist(candidate)
    }

    /// The state with `settings` in it. A language set after opening is the player's own choice, so it is marked
    /// chosen and never follows the device again.
    private func candidate(_ settings: UserSettings) -> State {
        var next = Self.normalized(settings)
        if next.language != state.settings.language { next.languageChosen = true }
        var candidate = state
        candidate.settings = next
        return candidate
    }

    /// Validates, encodes and atomically replaces the file; memory changes only once the write succeeded. (An atomic
    /// write either lands whole or leaves the old file, so the file is not read back and decoded again.) The file as
    /// it stood is copied to the backup first, when it is one this store opened or wrote.
    private func persist(_ candidate: State) throws {
        try Self.validate(candidate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(candidate)
        if fileIsGood { keepBackup() }
        try data.write(to: fileURL, options: .atomic)
        state = candidate
        staged = false
        fileIsGood = true
    }

    /// Best effort: a backup that can't be made never stops a save. (On APFS the copy is a clone, not a second write.)
    private func keepBackup() {
        let files = FileManager.default
        try? files.removeItem(at: backupURL)
        try? files.copyItem(at: fileURL, to: backupURL)
    }

    private static func normalized(_ settings: UserSettings) -> UserSettings {
        var result = settings
        var seen: Set<String> = []
        result.recentInstrumentIds = Array(settings.recentInstrumentIds.filter { seen.insert($0).inserted }.prefix(recentInstrumentLimit))
        return result
    }

    // MARK: Opening

    /// A file's state, read leniently and repaired into bounds; nil when it can't be read as a state at all.
    private static func open(_ data: Data) -> State? {
        guard let decoded = try? JSONDecoder().decode(State.self, from: data) else { return nil }
        let state = repaired(decoded)
        do { try validate(state) } catch { return nil }
        return state
    }

    /// Brings a decoded state inside the bounds `validate` checks, keeping all it can: values are clamped rather than
    /// reset, a practice record is dropped only without a date or an instrument (so streak days survive), and a
    /// progress block is dropped only if clamping can't make it valid.
    private static func repaired(_ loaded: State) -> State {
        var state = loaded
        state.version = currentVersion
        state.settings = repaired(loaded.settings)
        var seen = Set<UUID>()
        state.records = loaded.records.compactMap { (record: PracticeRecord) -> PracticeRecord? in
            guard seen.insert(record.id).inserted else { return nil }
            return repaired(record)
        }
        state.demonstratedLevels = loaded.demonstratedLevels.filter { isEvidenceLevel($0) }
        return state
    }

    private static func repaired(_ settings: UserSettings) -> UserSettings {
        let defaults = UserSettings()
        var result = normalized(settings)
        result.referencePitchHz = result.referencePitchHz.isFinite ? clamp(result.referencePitchHz, referencePitchRange) : defaults.referencePitchHz
        result.micSensitivity = clamp(result.micSensitivity, micSensitivityRange)
        result.confidenceThreshold = result.confidenceThreshold.isFinite ? clamp(result.confidenceThreshold, 0...1) : defaults.confidenceThreshold
        result.capo = clamp(result.capo, capoRange)
        result.transposition = clamp(result.transposition, transpositionRange)
        if result.lastTuningIds.count > tuningMemoryLimit {
            // The instruments in use keep theirs; the rest fill up in a stable order.
            let inUse = Set([result.selectedInstrumentId] + result.recentInstrumentIds)
            var kept = result.lastTuningIds.filter { inUse.contains($0.key) }
            for key in result.lastTuningIds.keys.sorted() where kept.count < tuningMemoryLimit { kept[key] = result.lastTuningIds[key] }
            result.lastTuningIds = kept
        }
        if let level = result.selectedVoiceLevel, !voiceLevelRange.contains(level) { result.selectedVoiceLevel = nil }
        if let window = result.analysisWindowOverride, !analysisWindowRange.contains(window) { result.analysisWindowOverride = nil }
        if let tunings = result.customTunings { result.customTunings = Array(tunings.compactMap { repaired($0) }.prefix(customTuningLimit)) }
        if let progress = result.progress { result.progress = repaired(progress) }
        if let learn = result.learn { result.learn = repaired(learn) }
        // English used to be the default: an "en" nobody picked follows the device now. Any other code was picked.
        if !result.languageChosen {
            if result.language == "en" { result.language = TimbreLocalization.system }
            else if result.language != TimbreLocalization.system { result.languageChosen = true }
        }
        return result
    }

    private static func repaired(_ record: PracticeRecord) -> PracticeRecord? {
        guard record.date.timeIntervalSinceReferenceDate.isFinite, !record.instrumentId.isEmpty else { return nil }
        var result = record
        result.count = max(0, record.count)
        result.stableCount = min(max(0, record.stableCount), result.count)
        if let cents = record.meanAbsoluteCents, !(cents.isFinite && cents >= 0) { result.meanAbsoluteCents = nil }
        if let duration = record.durationMs, duration < 0 { result.durationMs = nil }
        return result
    }

    private static func repaired(_ tuning: CustomTuning) -> CustomTuning? {
        guard isValid(midis: tuning.midis) else { return nil }
        var result = tuning
        if result.name.count > customTuningNameLimit { result.name = String(result.name.prefix(customTuningNameLimit)) }
        return result
    }

    private static func repaired(_ progress: ProgressState) -> ProgressState? {
        guard !progress.isValid else { return progress }
        var result = progress
        result.xp = clamp(result.xp, 0...50_000_000)
        result.stats = result.stats.mapValues { max(0, $0) }
        result.questProgress = result.questProgress.mapValues { max(0, $0) }
        result.questsClaimed = Array(result.questsClaimed.prefix(16))
        result.achievements = Array(result.achievements.prefix(128))
        result.instrumentsTuned = Array(result.instrumentsTuned.prefix(128))
        result.stringSamples = Array(result.stringSamples.filter { $0.cents.isFinite && abs($0.cents) <= 1200 }.suffix(ProgressState.sampleLimit))
        if let freezes = result.streakFreezes { result.streakFreezes = clamp(freezes, 0...StreakFreeze.cap) }
        if let days = result.frozenDays { result.frozenDays = Array(days.suffix(400)) }
        if let tuned = result.tunedToday { result.tunedToday = tuned.count <= 128 ? tuned.mapValues { Array($0.prefix(64)) } : nil }
        return result.isValid ? result : nil
    }

    private static func repaired(_ learn: LearnProgress) -> LearnProgress? {
        guard !learn.isValid else { return learn }
        var result = learn
        result.stars = result.stars.filter { (1...3).contains($0.value) }
        result.bestAccuracy = result.bestAccuracy.filter { (0...1).contains($0.value) }
        result.placedThrough = result.placedThrough.filter { (0...99).contains($0.value) }
        // Weak spots and review counts rebuild themselves from the next lessons.
        if !result.isValid { result.weakSpots = [:]; result.sinceReview = [:] }
        return result.isValid ? result : nil
    }

    private static func clamp<Value: Comparable>(_ value: Value, _ range: ClosedRange<Value>) -> Value {
        min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: Set-aside files

    /// "20261025-143012": UTC, so names sort in the order the files were set aside.
    private static func quarantineStamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d%02d%02d-%02d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }

    private static func pruneQuarantine(in directory: URL) {
        let files = FileManager.default
        guard let names = try? files.contentsOfDirectory(atPath: directory.path) else { return }
        let kept = names.filter { $0.hasPrefix(quarantinePrefix) }.sorted(by: >)
        for name in kept.dropFirst(quarantineLimit) { try? files.removeItem(at: directory.appendingPathComponent(name)) }
    }

    // MARK: History roll-up

    private struct RollUpKey: Hashable {
        let day: Date
        let instrumentId: String
        let tuningId: String?
        let kind: String
    }

    /// Long histories, compacted without losing what streaks and stats read: practice older than `rollUpAfterDays`
    /// becomes one record per day, instrument, tuning and kind, dated at that day's last session, with the same
    /// minutes, readings and stable readings, and the mean accuracy weighted by stable readings. Every practised
    /// day, the streaks, the total minutes and the order of recent instruments stay exactly as they were; scored
    /// voice results (challenges, evidence) and the recent months are kept session by session. Newest first.
    public static func rolledUp(_ records: [PracticeRecord], now: Date, calendar: Calendar) -> [PracticeRecord] {
        guard let cutoff = calendar.date(byAdding: .day, value: -rollUpAfterDays, to: calendar.startOfDay(for: now)) else { return records }
        var kept: [PracticeRecord] = []
        var groups: [RollUpKey: [PracticeRecord]] = [:]
        for record in records {
            if record.date >= cutoff || record.voiceResult != nil { kept.append(record); continue }
            let key = RollUpKey(day: calendar.startOfDay(for: record.date), instrumentId: record.instrumentId, tuningId: record.tuningId, kind: record.kind)
            groups[key, default: []].append(record)
        }
        for group in groups.values { if let record = merged(group) { kept.append(record) } }
        return kept.sorted { $0.date > $1.date }
    }

    private static func merged(_ group: [PracticeRecord]) -> PracticeRecord? {
        guard let latest = group.max(by: { $0.date < $1.date }) else { return nil }
        guard group.count > 1 else { return latest }
        let durations = group.compactMap(\.durationMs)
        let measured = group.filter { $0.meanAbsoluteCents != nil }
        let weight = measured.reduce(0) { $0 + $1.stableCount }
        var cents: Double?
        if !measured.isEmpty {
            if weight > 0 {
                cents = measured.reduce(0.0) { $0 + ($1.meanAbsoluteCents ?? 0) * Double($1.stableCount) } / Double(weight)
            } else {
                cents = measured.reduce(0.0) { $0 + ($1.meanAbsoluteCents ?? 0) } / Double(measured.count)
            }
        }
        return PracticeRecord(id: latest.id, date: latest.date, instrumentId: latest.instrumentId, tuningId: latest.tuningId,
                              kind: latest.kind, count: group.reduce(0) { $0 + $1.count }, stableCount: group.reduce(0) { $0 + $1.stableCount },
                              meanAbsoluteCents: cents, voiceResult: nil, durationMs: durations.isEmpty ? nil : durations.reduce(0, +))
    }
    private static func evidencedLevel(_ record: PracticeRecord) -> Int? {
        guard record.kind == "voice", let id = record.tuningId, let level = Int(id.split(separator: ".").last ?? ""),
              (2...8).contains(level), level != 7, id == VoiceExercise(level: level).id,
              let result = record.voiceResult, result.demonstrated,
              let accuracy = result.accuracy, (70...100).contains(accuracy) else { return nil }
        let exercise = VoiceExercise(level: level)
        guard result.longestHoldMs >= exercise.holdMs, result.toleranceCents.isFinite,
              result.toleranceCents > 0, result.toleranceCents <= exercise.toleranceCents,
              result.readingCount >= 10, result.stableReadingCount >= 10 else { return nil }
        if level == 4 && !(result.stability.map { (60...100).contains($0) } ?? false) { return nil }
        return level
    }

    // MARK: Bounds

    static let referencePitchRange: ClosedRange<Double> = 415...466
    static let micSensitivityRange = 0...100
    static let capoRange = 0...12
    static let transpositionRange = -12...12
    static let voiceLevelRange = 1...8
    static let analysisWindowRange = 1...65_536
    static let tuningMemoryLimit = 128
    static let customTuningLimit = 200
    static let customTuningCourseLimit = 48
    static let customTuningNameLimit = 60

    private static func isEvidenceLevel(_ level: Int) -> Bool { (2...8).contains(level) && level != 7 }

    private static func isValid(midis: [Int]) -> Bool {
        !midis.isEmpty && midis.count <= customTuningCourseLimit && midis.allSatisfy { (0...127).contains($0) }
    }

    /// What every write must satisfy. Opening repairs a file into these bounds rather than refusing it.
    private static func validate(_ value: State) throws {
        let settings = value.settings
        guard settings.referencePitchHz.isFinite, referencePitchRange.contains(settings.referencePitchHz),
              micSensitivityRange.contains(settings.micSensitivity), settings.confidenceThreshold.isFinite,
              (0...1).contains(settings.confidenceThreshold), capoRange.contains(settings.capo),
              transpositionRange.contains(settings.transposition), settings.lastTuningIds.count <= tuningMemoryLimit,
              settings.selectedVoiceLevel.map({ voiceLevelRange.contains($0) }) ?? true,
              settings.recentInstrumentIds.count <= recentInstrumentLimit,
              settings.analysisWindowOverride.map({ analysisWindowRange.contains($0) }) ?? true,
              (settings.customTunings ?? []).count <= customTuningLimit,
              (settings.customTunings ?? []).allSatisfy({ isValid(midis: $0.midis) && $0.name.count <= customTuningNameLimit }),
              settings.progress?.isValid ?? true,
              settings.learn?.isValid ?? true else {
            throw LocalStoreError.invalidState("Invalid settings")
        }
        guard Set(value.records.map(\.id)).count == value.records.count,
              value.demonstratedLevels.allSatisfy({ isEvidenceLevel($0) }) else {
            throw LocalStoreError.invalidState("Invalid history or progress")
        }
        for record in value.records {
            guard record.date.timeIntervalSinceReferenceDate.isFinite, !record.instrumentId.isEmpty,
                  record.count >= 0, record.stableCount >= 0, record.stableCount <= record.count,
                  record.meanAbsoluteCents.map({ $0.isFinite && $0 >= 0 }) ?? true,
                  record.durationMs.map({ $0 >= 0 }) ?? true else {
                throw LocalStoreError.invalidState("Invalid practice record")
            }
        }
    }
}
