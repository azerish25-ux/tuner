import Foundation

/// A campaign's Gregorian local days in the player's current time zone, start inclusive and end exclusive.
/// A supplied window with missing, malformed or reversed dates grants nothing. No window means permanent access.
public struct FreeSongWindow: Codable, Equatable, Sendable {
    public var startDate: String?
    public var endDate: String?

    public init(startDate: String?, endDate: String?) {
        self.startDate = startDate
        self.endDate = endDate
    }

    public func includes(at now: Date = Date(), timeZone: TimeZone = .current) -> Bool {
        guard let range = bounds(timeZone: timeZone) else { return false }
        return now >= range.start && now < range.end
    }

    public func nextBoundary(after now: Date = Date(), timeZone: TimeZone = .current) -> Date? {
        guard let range = bounds(timeZone: timeZone) else { return nil }
        if now < range.start { return range.start }
        return now < range.end ? range.end : nil
    }

    private func bounds(timeZone: TimeZone) -> (start: Date, end: Date)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let start = Self.day(startDate, calendar: calendar), let end = Self.day(endDate, calendar: calendar),
              start < end else { return nil }
        return (start, end)
    }

    private static func day(_ text: String?, calendar: Calendar) -> Date? {
        guard let text, text.utf8.count == 10 else { return nil }
        let bytes = Array(text.utf8)
        guard bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({ $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element) }) else { return nil }
        let pieces = text.split(separator: "-")
        guard pieces.count == 3, let year = Int(pieces[0]), let month = Int(pieces[1]), let day = Int(pieces[2]),
              (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }
}
