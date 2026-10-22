import Foundation

public struct PracticeDay: Identifiable, Equatable, Sendable {
    public let date: Date
    public let sessionCount: Int
    /// nil if any session on this day predates duration recording.
    public let durationMs: Int?
    public let measuredDurationMs: Int
    public let missingDurationCount: Int
    public var id: Date { date }
}
public struct AccuracyWindow: Equatable, Sendable {
    public let sessionCount: Int
    public let measuredSessions: Int
    public let meanAbsCentsError: Double?
}
public struct PracticeComparison: Equatable, Sendable {
    public let recent: AccuracyWindow
    public let earlier: AccuracyWindow?
    /// Recent minus earlier error. Negative means closer to target.
    public let changeCents: Double?
}
public struct ChallengeProgress: Identifiable, Equatable, Sendable {
    public let challengeId: String
    public let bestScore: Int
    public let attempts: Int
    public let lastPlayedAt: Date
    public var id: String { challengeId }
}
public struct PracticeHistorySummary: Sendable {
    public let records: [PracticeRecord]
    public let activity: [PracticeDay]
    public let comparison: PracticeComparison
    public let challenges: [ChallengeProgress]
    public var weekDurationMs: Int? {
        guard activity.allSatisfy({ $0.durationMs != nil }) else { return nil }
        return activity.compactMap(\.durationMs).reduce(0, +)
    }
    public var measuredWeekDurationMs: Int { activity.reduce(0) { $0 + $1.measuredDurationMs } }
}
/// Android HistoryStateHolder rules: fixed 14-day comparison windows, minimum three
/// measured sessions on each side, same non-voice instrument, per-session means.
public enum PracticeAnalytics {
    public static let windowSeconds: TimeInterval = 14 * 24 * 60 * 60
    public static let minimumMeasuredSessions = 3
    public static func summary(records: [PracticeRecord], instrumentId: String? = nil, now: Date = Date(), calendar: Calendar = .current) -> PracticeHistorySummary {
        let selected = records.filter { $0.date <= now && (instrumentId == nil || $0.instrumentId == instrumentId) }.sorted { $0.date > $1.date }
        return PracticeHistorySummary(records: selected, activity: activityDays(records: selected, now: now, calendar: calendar), comparison: compareWindows(records: selected, now: now), challenges: challenges(records: records.filter { $0.date <= now }))
    }
    public static func compareWindows(records: [PracticeRecord], now: Date) -> PracticeComparison {
        let cutoff = now.addingTimeInterval(-windowSeconds)
        let previous = cutoff.addingTimeInterval(-windowSeconds)
        let recent = records.filter { $0.date >= cutoff && $0.date <= now }
        let earlier = records.filter { $0.date >= previous && $0.date < cutoff }
        let recentWindow = accuracyWindow(recent)
        let earlierWindow = earlier.isEmpty ? nil : accuracyWindow(earlier)
        let kinds = Set((recent + earlier).map(\.instrumentId))
        let comparable = kinds.count == 1 && kinds.first != "voice" && recentWindow.measuredSessions >= minimumMeasuredSessions && (earlierWindow?.measuredSessions ?? 0) >= minimumMeasuredSessions
        var change: Double?
        if comparable, let recentMean = recentWindow.meanAbsCentsError, let earlierMean = earlierWindow?.meanAbsCentsError { change = recentMean - earlierMean }
        return PracticeComparison(recent: recentWindow, earlier: earlierWindow, changeCents: change)
    }
    private static func accuracyWindow(_ records: [PracticeRecord]) -> AccuracyWindow {
        let measurements = records.compactMap(\.meanAbsoluteCents).filter { $0.isFinite && $0 >= 0 }
        return AccuracyWindow(sessionCount: records.count, measuredSessions: measurements.count, meanAbsCentsError: measurements.isEmpty ? nil : measurements.reduce(0, +) / Double(measurements.count))
    }
    public static func activityDays(records: [PracticeRecord], now: Date, calendar: Calendar = .current) -> [PracticeDay] {
        let today = calendar.startOfDay(for: now)
        return (0...6).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today), let end = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let day = records.filter { $0.date >= date && $0.date < end && $0.date <= now }
            let measured = day.compactMap(\.durationMs).filter { $0 >= 0 }
            let missing = day.count - measured.count
            let total = measured.reduce(0, +)
            return PracticeDay(date: date, sessionCount: day.count, durationMs: missing == 0 ? total : nil, measuredDurationMs: total, missingDurationCount: missing)
        }
    }
    public static func challenges(records: [PracticeRecord]) -> [ChallengeProgress] {
        // Only scored attempts create challenge progress. Warm-up/range and unsupported
        // captures remain absent rather than creating zero-score attempts.
        let scored = records.filter { $0.kind == "voice" && $0.tuningId != nil && $0.voiceResult?.accuracy != nil }
        return Dictionary(grouping: scored, by: { $0.tuningId! }).compactMap { id, attempts in
            let scores = attempts.compactMap { $0.voiceResult?.accuracy }.filter { (0...100).contains($0) }
            guard let best = scores.max(), let last = attempts.map(\.date).max() else { return nil }
            return ChallengeProgress(challengeId: id, bestScore: best, attempts: scores.count, lastPlayedAt: last)
        }.sorted { $0.lastPlayedAt == $1.lastPlayedAt ? $0.challengeId < $1.challengeId : $0.lastPlayedAt > $1.lastPlayedAt }
    }
}
