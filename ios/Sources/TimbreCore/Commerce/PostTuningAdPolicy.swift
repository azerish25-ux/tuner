import Foundation

/// Resolved expired/refunded ownership is ad supported, matching Android. Unresolved/pending never is.
public enum AdEntitlement: Sendable {
    case unknown, pending, paid, reviewAccess, free, expired, refunded
    public var isAdSupported: Bool {
        switch self { case .free, .expired, .refunded: return true; default: return false }
    }
}

/// Call exactly at explicit Finish tuning. A skip consumes its ID, so late loads cannot replay it.
/// The caller supplies fresh consent, ownership and lifecycle state using a monotonic clock.
public final class PostTuningAdPolicy: @unchecked Sendable {
    private let lock = NSLock()
    private var consumedCompletions: Set<String> = []
    private var lastClaimElapsedMs: Int?
    public init() {}
    public func claimCompletion(sessionId: String, durationMs: Int, stableReadingCount: Int, elapsedRealtimeMs: Int, entitlement: AdEntitlement, canRequestAds: Bool, adReady: Bool, foreground: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, sessionId.utf16.count <= 128, elapsedRealtimeMs >= 0 else { return false }
        guard consumedCompletions.count < 1024, consumedCompletions.insert(sessionId).inserted else { return false }
        guard entitlement.isAdSupported, canRequestAds, adReady, foreground, durationMs >= 15000, stableReadingCount >= 3 else { return false }
        if let last = lastClaimElapsedMs, elapsedRealtimeMs < last || elapsedRealtimeMs - last < 120000 { return false }
        lastClaimElapsedMs = elapsedRealtimeMs
        return true
    }
}
