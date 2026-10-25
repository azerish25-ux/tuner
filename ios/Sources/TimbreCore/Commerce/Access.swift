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
    /// The end of a subscription's paid period, for showing the renewal date; access never depends on it.
    public let expiresAt: Date?
    public init(productID: String, isSubscription: Bool, revoked: Bool, expiresAt: Date?) {
        self.productID = productID; self.isSubscription = isSubscription; self.revoked = revoked; self.expiresAt = expiresAt
    }
}

public enum AccessPolicy {
    /// Pro when any known product's verified transaction is in the entitlements and not revoked. The entitlements
    /// StoreKit reports (`Transaction.currentEntitlements`) already leave out lapsed subscriptions, and keep one in its
    /// Billing Grace Period although its expiry date has passed, so no date is checked here.
    public static func isPro(_ evidence: [EntitlementEvidence]) -> Bool {
        evidence.contains { item in
            guard TimbreProduct.all.contains(item.productID), !item.revoked else { return false }
            return item.isSubscription ? TimbreProduct.subscriptions.contains(item.productID) : item.productID == TimbreProduct.lifetime
        }
    }

    // MARK: Tunings

    /// Whether the player can pick this instrument and tune it: whenever its standard tuning is open, which on the
    /// free plan it always is.
    public static func canTune(instrument: Instrument, pro: Bool) -> Bool {
        isOpen(tuningId: instrument.defaultTuningId, custom: false, of: instrument, pro: pro)
    }

    /// The free plan tunes every instrument in its standard tuning, and the free instruments (the catalogue's `isFree`:
    /// guitar, bass, ukulele, violin and cello) in every preset and the player's own tunings too. The other
    /// instruments' alternate and custom tunings are Pro, as is everything with Pro.
    public static func canUse(tuning: Tuning, of instrument: Instrument, pro: Bool) -> Bool {
        tuning.instrumentId == instrument.id && isOpen(tuningId: tuning.id, custom: tuning.isCustom, of: instrument, pro: pro)
    }

    private static func isOpen(tuningId: String, custom: Bool, of instrument: Instrument, pro: Bool) -> Bool {
        if pro || instrument.isFree { return true }
        return !custom && tuningId == instrument.defaultTuningId
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
