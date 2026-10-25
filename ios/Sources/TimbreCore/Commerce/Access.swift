import Foundation
import os

/// App Store product identifiers. The yearly plans (the standard year and its price-test arms) and the monthly plan
/// share one subscription group; lifetime is a non-consumable that grants the same Pro access.
public enum TimbreProduct {
    public static let annual = "timbre_pro_annual"
    /// The yearly plan's price-test arms: a paywall variant in the remote settings names one (`annualProductId`) and
    /// sells it in place of the standard year. Each grants Pro like the standard year; where one isn't on sale (not
    /// created in App Store Connect yet, or not in this storefront) the paywall keeps selling the standard year.
    public static let annualB = "timbre_pro_annual_b"
    public static let annualC = "timbre_pro_annual_c"
    public static let monthly = "timbre_pro_monthly"
    public static let lifetime = "timbre_plus_lifetime"
    public static let subscriptionGroupName = "Timbre Pro"
    /// The yearly plans a paywall may sell, the standard one first.
    public static let yearly = [annual, annualB, annualC]
    /// Every product the app loads, in the paywall's order: the year, the month, lifetime, then the year's test arms.
    public static let all = [annual, monthly, lifetime, annualB, annualC]
    public static let subscriptions: Set<String> = [annual, annualB, annualC, monthly]
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

/// Lessons the owner opens to everyone without a new build, on top of each course's own free lessons: the remote
/// settings' `freeSongs` (a seasonal song shelf's first week, by lesson id) and `flags.unit2Free` (every course's second
/// unit, a test of a longer free runway).
public struct FreeOpenings: Equatable, Sendable {
    /// Lessons open to everyone for now, by lesson id.
    public var lessons: Set<String>
    /// The second unit of every teaching course is free too. Song collections keep their own free songs.
    public var unit2: Bool

    public init(lessons: Set<String> = [], unit2: Bool = false) {
        self.lessons = lessons
        self.unit2 = unit2
    }

    /// Nothing beyond the courses' own free lessons.
    public static let none = FreeOpenings()

    private static let state = OSAllocatedUnfairLock(initialState: FreeOpenings.none)

    /// What the remote settings open now. The app sets it whenever they load or change; `none` until then. Safe to read
    /// and set from any thread.
    public static var current: FreeOpenings {
        get { state.withLock { (value: inout FreeOpenings) -> FreeOpenings in value } }
        set { state.withLock { (value: inout FreeOpenings) in value = newValue } }
    }

    /// Whether these openings make `lesson` free: it is listed, or it is in the second unit of a teaching course.
    public func opens(_ lesson: Lesson, courses: [LearnCourse]) -> Bool {
        if lessons.contains(lesson.id) { return true }
        guard unit2 else { return false }
        return courses.contains { course in
            !course.isSongbook && course.units.count > 1 && course.units[1].lessons.contains { $0.id == lesson.id }
        }
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

    /// Free lessons are open to everyone and Pro opens them all. The remote settings may open more for everyone
    /// (`openings`: listed songs, every course's second unit; by default what they open now). On the free plan a
    /// placement adds one more, its placement pass (`placementPass`): only that lesson, only in the course the learner
    /// was placed in, so the first lesson onboarding's plan names is the one that opens.
    public static func canPlay(_ lesson: Lesson, pro: Bool, progress: LearnProgress, courses: [LearnCourse],
                               openings: FreeOpenings = .current) -> Bool {
        if pro || lesson.free || openings.opens(lesson, courses: courses) { return true }
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
