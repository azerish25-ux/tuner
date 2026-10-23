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
    public var earLevels: [String: Int]?
    public var customTunings: [CustomTuning]?
    /// XP, quests, achievements and string-health samples.
    public var progress: ProgressState?
    /// Stars and position in the Learn courses.
    public var learn: LearnProgress?
    /// The lock tolerance (`TuningPrecision` raw value); unset means Beginner, the original ±5¢.
    public var tuningPrecision: String?
    public init() {}
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
    private struct State: Codable, Equatable {
        var version = 1
        var settings = UserSettings()
        var records: [PracticeRecord] = []
        var demonstratedLevels: Set<Int> = []
    }
    private let fileURL: URL
    private var state: State
    public var settings: UserSettings { state.settings }
    public var records: [PracticeRecord] { state.records }
    public var demonstratedLevels: Set<Int> { state.demonstratedLevels }

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
        candidate.settings = settings
        var seen: Set<String> = []
        candidate.settings.recentInstrumentIds = Array(settings.recentInstrumentIds.filter { seen.insert($0).inserted }.prefix(Self.recentInstrumentLimit))
        try persist(candidate)
    }
    public func append(_ record: PracticeRecord) throws {
        var candidate = state
        candidate.records.removeAll { $0.id == record.id }
        candidate.records.append(record)
        candidate.records.sort { $0.date > $1.date }
        if let level = Self.evidencedLevel(record) { candidate.demonstratedLevels.insert(level) }
        try persist(candidate)
    }
    /// Clearing history also removes its vocal progress evidence; settings remain.
    public func clearHistory() throws {
        var candidate = state
        candidate.records = []; candidate.demonstratedLevels = []
        try persist(candidate)
    }
    private func persist(_ candidate: State) throws {
        try Self.validate(candidate)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(candidate)
        try data.write(to: fileURL, options: .atomic)
        let confirmed = try JSONDecoder().decode(State.self, from: Data(contentsOf: fileURL))
        guard confirmed == candidate else { throw LocalStoreError.readBackMismatch }
        state = confirmed
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
