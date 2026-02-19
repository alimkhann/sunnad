import Combine
import Foundation

enum HabitSchedule: Codable, Hashable, Sendable {
    case daily
    case weekly(Set<Weekday>)

    func isDue(on date: Date, calendar: Calendar = .current, timeZone: TimeZone = .current) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekly(let weekdays):
            guard !weekdays.isEmpty else { return false }
            let weekday = Weekday.isoWeekday(for: date, calendar: calendar, timeZone: timeZone)
            return weekdays.contains(weekday)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case frequency
        case weekdays
    }

    private enum Frequency: String, Codable {
        case daily
        case weekly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let frequency = try container.decode(Frequency.self, forKey: .frequency)

        switch frequency {
        case .daily:
            self = .daily
        case .weekly:
            let weekdays = try container.decode(Set<Weekday>.self, forKey: .weekdays)
            self = .weekly(weekdays)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .daily:
            try container.encode(Frequency.daily, forKey: .frequency)
        case .weekly(let weekdays):
            try container.encode(Frequency.weekly, forKey: .frequency)
            try container.encode(weekdays, forKey: .weekdays)
        }
    }
}
