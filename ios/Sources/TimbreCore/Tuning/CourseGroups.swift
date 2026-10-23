import Foundation

/// Strings the tuner shows as one chip: unison partners of a paired course (a mandolin's two G strings)
/// share a peg-head anchor and a target note. Octave partners (a 12-string's E2 and E3) are tuned to
/// different notes, so they keep a chip each. Every string still locks on its own; a group is tuned
/// once all of its strings have locked.
public struct CourseGroup: Identifiable, Equatable, Sendable {
    /// The strings, in course order; one for an ordinary string.
    public let courses: [Course]
    public init(courses: [Course]) {
        precondition(!courses.isEmpty, "a course group needs at least one string")
        self.courses = courses
    }
    /// The first string's course index (also the chip's identity).
    public var id: Int { courses[0].index }
    public var lead: Course { courses[0] }
    public var count: Int { courses.count }
    public func contains(_ index: Int) -> Bool { courses.contains { $0.index == index } }
    /// Every string of the group has locked.
    public func isTuned(_ locked: Set<Int>) -> Bool { courses.allSatisfy { locked.contains($0.index) } }
    /// How many of the group's strings have locked.
    public func lockedCount(_ locked: Set<Int>) -> Int { courses.filter { locked.contains($0.index) }.count }
    /// The string a tap on the group's chip tunes: the first one not locked yet (the first once all are).
    public func nextToTune(_ locked: Set<Int>) -> Course { courses.first { !locked.contains($0.index) } ?? lead }
    /// The partner to move on to once `index` has locked: the next unlocked string of the group
    /// (wrapping round to an earlier one), or nil when the group is done or `index` isn't in it.
    public func partner(after index: Int, locked: Set<Int>) -> Course? {
        guard let position = courses.firstIndex(where: { $0.index == index }), courses.count > 1 else { return nil }
        let rotated = Array(courses[(position + 1)...]) + Array(courses[..<position])
        return rotated.first { !locked.contains($0.index) }
    }
}

public enum CourseGrouping {
    /// The tuning's courses as chips, in course order: unison partners on one anchor share a group.
    /// Courses without an anchor (keys, bars, harmonica holes) are never grouped.
    public static func groups(_ courses: [Course]) -> [CourseGroup] {
        let ordered = courses.sorted { $0.index < $1.index }
        var buckets: [[Course]] = []
        var slots: [String: Int] = [:]
        for course in ordered {
            if let anchor = course.anchorId {
                let key = "\(anchor)|\(course.targetMidi)|\(course.label)"
                if let slot = slots[key] { buckets[slot].append(course); continue }
                slots[key] = buckets.count
            }
            buckets.append([course])
        }
        return buckets.map { CourseGroup(courses: $0) }
    }

    /// Which string of its anchor `course` is, in course order (0 for the first): on a paired course,
    /// which of the two pegs the player turns. 0 for a course without an anchor or not in `courses`.
    public static func position(of course: Course, in courses: [Course]) -> Int {
        guard let anchor = course.anchorId else { return 0 }
        let sharing = courses.filter { $0.anchorId == anchor }.sorted { $0.index < $1.index }
        return sharing.firstIndex { $0.index == course.index } ?? 0
    }

    /// The course a peg name picks: an anchor ("c4") or one string of a pair, the anchor and a letter
    /// in course order ("c4a", "c4b"), as the 3D rigs and studio cards name a paired course's pegs.
    public static func course(forPeg name: String, in courses: [Course]) -> Course? {
        let ordered = courses.sorted { $0.index < $1.index }
        if let course = ordered.first(where: { $0.anchorId == name }) { return course }
        guard name.count > 1, let ascii = name.last?.asciiValue, ascii >= 97, ascii <= 122 else { return nil }
        let anchor = String(name.dropLast())
        let sharing = ordered.filter { $0.anchorId == anchor }
        let position = Int(ascii) - 97
        return position < sharing.count ? sharing[position] : nil
    }

    /// The suffix a rig or studio card gives the string at `position` of a pair ("a", "b", …).
    public static func pegLetter(_ position: Int) -> String? {
        guard position >= 0, position < 26 else { return nil }
        return String(Character(UnicodeScalar(UInt8(97 + position))))
    }
}
