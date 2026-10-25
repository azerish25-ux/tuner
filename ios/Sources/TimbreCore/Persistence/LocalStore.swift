import Foundation

public struct UserSettings: Codable, Equatable, Sendable {
    public var referencePitchHz: Double = 440
    public var temperamentId = "equal"
    public var theme = "dark"
    public var skin = "brass"
    public var reducedMotion = false
    public var hapticsEnabled = true
    public var language = "en"
    public var recentInstrumentIds: [String] = []
    public var analysisWindowOverride: Int?
    public var micSensitivity = 60
    public var confidenceThreshold = 0.75
    public var notation = "english"
    public var capo = 0
    public var transposition = 0
    public var handedness = "right"
    public var lastTuningIds: [String: String] = [:]
    public var selectedInstrumentId = "guitar.acoustic.6"
    public var selectedPhotoAsset: String?
    public var telemetryEnabled = false
    public var selectedVoiceLevel: Int?
    // v2 (all optional so earlier files still decode)
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
    public init() {}
}

extension UserSettings {
    /// Until the player picks a note-naming system, it follows the app language: German letters (B natural is H)
    /// for German, letters otherwise. A system picked in Settings, or one set before this existed other than
    /// letters (solfège, sargam, numbers), is never changed. `systemLanguage` is the device's language
    /// (e.g. "de-DE"), used when the app language is "system".
    public mutating func applyNotationDefault(systemLanguage: String?) {
        guard notationChosen != true, notation == "english" || notation == "german" else { return }
        notation = NoteNames.defaultSystem(language: language == "system" ? (systemLanguage ?? "en") : language)
    }
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
    case unsupportedVersion(Int)
    case invalidState(String)
    case readBackMismatch
}

/// One atomic snapshot keeps settings, history and demonstrated evidence consistent.
/// Caller serializes access (the app uses its main actor).
public final class LocalStore {
    public static let recentInstrumentLimit = 12
    public static let fileName = "timbre-state.json"
    /// Past this many records, old history rolls up (`rolledUp`) so the file stops growing with every session.
    public static let recordLimit = 2_000
    /// Practice from the last this many days is always kept session by session (recaps, comparisons and the coach
    /// read a few weeks at most).
    public static let rollUpAfterDays = 180
    private struct State: Codable, Equatable {
        var version = 1
        var settings = UserSettings()
        var records: [PracticeRecord] = []
        var demonstratedLevels: Set<Int> = []
    }
    private let fileURL: URL
    private var state: State
    /// Settings made current by `stageSettings` and not written yet.
    private var staged = false
    /// The history size that triggers a roll-up (tests lower it).
    public var historyLimit = LocalStore.recordLimit
    public var settings: UserSettings { state.settings }
    public var records: [PracticeRecord] { state.records }
    public var demonstratedLevels: Set<Int> { state.demonstratedLevels }
    /// Staged settings are waiting for `flush()` (or the next write, which carries them).
    public var hasUnsavedChanges: Bool { staged }

    public init(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(Self.fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: fileURL))
            try Self.validate(state)
        } else { state = State() }
    }
    public func saveSettings(_ settings: UserSettings) throws {
        var candidate = state
        candidate.settings = Self.normalized(settings)
        try persist(candidate)
    }
    /// Validates settings and makes them current without writing the file, so a burst of changes costs one write:
    /// `flush()` writes them, as does any other save in the meantime. Invalid settings throw and change nothing.
    public func stageSettings(_ settings: UserSettings) throws {
        var candidate = state
        candidate.settings = Self.normalized(settings)
        try Self.validate(candidate)
        state = candidate
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
    /// Validates, encodes and atomically replaces the file; memory changes only once the write succeeded. (An atomic
    /// write either lands whole or leaves the old file, so the file is not read back and decoded again.)
    private func persist(_ candidate: State) throws {
        try Self.validate(candidate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(candidate)
        try data.write(to: fileURL, options: .atomic)
        state = candidate
        staged = false
    }
    private static func normalized(_ settings: UserSettings) -> UserSettings {
        var result = settings
        var seen: Set<String> = []
        result.recentInstrumentIds = Array(settings.recentInstrumentIds.filter { seen.insert($0).inserted }.prefix(recentInstrumentLimit))
        return result
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
    private static func validate(_ value: State) throws {
        guard value.version == 1 else { throw LocalStoreError.unsupportedVersion(value.version) }
        let settings = value.settings
        guard settings.referencePitchHz.isFinite, (415...466).contains(settings.referencePitchHz),
              (0...100).contains(settings.micSensitivity), settings.confidenceThreshold.isFinite,
              (0...1).contains(settings.confidenceThreshold), (0...12).contains(settings.capo),
              (-12...12).contains(settings.transposition), settings.lastTuningIds.count <= 128,
              settings.selectedVoiceLevel.map({ (1...8).contains($0) }) ?? true,
              settings.recentInstrumentIds.count <= recentInstrumentLimit,
              settings.analysisWindowOverride.map({ $0 > 0 && $0 <= 65536 }) ?? true,
              (settings.customTunings ?? []).count <= 200,
              (settings.customTunings ?? []).allSatisfy({ !$0.midis.isEmpty && $0.midis.count <= 48 && $0.midis.allSatisfy { (0...127).contains($0) } && $0.name.count <= 60 }),
              settings.progress?.isValid ?? true,
              settings.learn?.isValid ?? true else {
            throw LocalStoreError.invalidState("Invalid settings")
        }
        guard Set(value.records.map(\.id)).count == value.records.count,
              value.demonstratedLevels.allSatisfy({ (2...8).contains($0) && $0 != 7 }) else {
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
