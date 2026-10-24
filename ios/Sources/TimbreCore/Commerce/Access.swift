import Foundation

/// App Store product identifiers. Annual and monthly share one subscription group;
/// lifetime is a non-consumable that grants the same Pro access.
public enum TimbreProduct {
    public static let annual = "timbre_pro_annual"
    public static let monthly = "timbre_pro_monthly"
    public static let lifetime = "timbre_plus_lifetime"
    public static let subscriptionGroupName = "Timbre Pro"
    public static let all = [annual, monthly, lifetime]
    public static let subscriptions: Set<String> = [annual, monthly]
}

/// A verified entitlement as StoreKit reports it, reduced to what access depends on.
public struct EntitlementEvidence: Equatable, Sendable {
    public let productID: String
    public let isSubscription: Bool
    public let revoked: Bool
    public let expiresAt: Date?
    public init(productID: String, isSubscription: Bool, revoked: Bool, expiresAt: Date?) {
        self.productID = productID; self.isSubscription = isSubscription; self.revoked = revoked; self.expiresAt = expiresAt
    }
}

public enum AccessPolicy {
    /// Pro when any known product is verified, not revoked and (for subscriptions) not expired.
    public static func isPro(_ evidence: [EntitlementEvidence], now: Date = Date()) -> Bool {
        evidence.contains { item in
            guard TimbreProduct.all.contains(item.productID), !item.revoked else { return false }
            if item.isSubscription { return item.expiresAt.map { $0 > now } ?? true }
            return item.productID == TimbreProduct.lifetime
        }
    }

    /// Free users tune the free instruments in every preset tuning. Pro opens everything. The free set is the
    /// catalogue's `isFree` flag: guitar, bass, ukulele, violin and cello (viola, double bass and the rest are Pro).
    public static func canTune(instrument: Instrument, pro: Bool) -> Bool { pro || instrument.isFree }

    public static func canUse(tuning: Tuning, of instrument: Instrument, pro: Bool) -> Bool {
        tuning.instrumentId == instrument.id && canTune(instrument: instrument, pro: pro)
    }

    // MARK: Lessons

    /// Free lessons are open to everyone and Pro opens them all. On the free plan a placement adds one more,
    /// its placement pass (`placementPass`): only that lesson, only in the course the learner was placed in,
    /// so the first lesson onboarding's plan names is the one that opens.
    public static func canPlay(_ lesson: Lesson, pro: Bool, progress: LearnProgress, courses: [LearnCourse]) -> Bool {
        if pro || lesson.free { return true }
        return progress.placedThrough.keys.contains { courseId in
            guard let course = courses.first(where: { $0.id == courseId }) else { return false }
            return placementPass(in: course, progress: progress)?.id == lesson.id
        }
    }

    /// A course's placement pass: the first lesson of the unit the learner was placed in (the one after the
    /// placed units); nil when the course has no placement or no unit after it.
    public static func placementPass(in course: LearnCourse, progress: LearnProgress) -> Lesson? {
        guard let placed = progress.placedThrough[course.id], placed >= 0 else { return nil }
        for unit in course.units.dropFirst(placed + 1) {
            if let first = unit.lessons.first { return first }
        }
        return nil
    }
}
