import Foundation

enum Weekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    nonisolated static func fromISOWeekday(_ value: Int) -> Weekday? {
        Weekday(rawValue: value)
    }

    nonisolated static func isoWeekday(for date: Date, calendar: Calendar = .current, timeZone: TimeZone = .current) -> Weekday {
        var calendar = calendar
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date)
        // Calendar weekday: 1=Sun...7=Sat. Convert to ISO: 1=Mon...7=Sun.
        let iso = ((weekday + 5) % 7) + 1
        return Weekday(rawValue: iso) ?? .monday
    }

    nonisolated static func fromMondayFirstIndex(_ index: Int) -> Weekday? {
        Weekday(rawValue: index + 1)
    }

    nonisolated var mondayFirstIndex: Int {
        rawValue - 1
    }
}
