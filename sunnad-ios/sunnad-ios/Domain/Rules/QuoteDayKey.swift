import Combine
import Foundation

enum QuoteDayKey {
    static func value(for day: Date, locale: String, calendar: Calendar = .current, timeZone: TimeZone = .current) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: day)

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withFullDate]

        return "\(locale.lowercased())-\(formatter.string(from: start))"
    }

    static func deterministicIndex(for dayKey: String, count: Int) -> Int {
        guard count > 0 else { return 0 }

        let hash = dayKey.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }

        return abs(hash) % count
    }
}
