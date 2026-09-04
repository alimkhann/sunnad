import Foundation

struct LateCheckInPolicy: Hashable, Sendable {
    let graceHours: Int

    init(graceHours: Int = 4) {
        self.graceHours = min(max(graceHours, 0), 23)
    }
}

struct DayContext: Hashable, Sendable {
    let now: Date
    let calendar: Calendar
    let timeZone: TimeZone
    let lateCheckInPolicy: LateCheckInPolicy

    init(
        now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian),
        timeZone: TimeZone = .current,
        lateCheckInPolicy: LateCheckInPolicy = LateCheckInPolicy()
    ) {
        var resolvedCalendar = calendar
        resolvedCalendar.timeZone = timeZone
        self.now = now
        self.calendar = resolvedCalendar
        self.timeZone = timeZone
        self.lateCheckInPolicy = lateCheckInPolicy
    }

    var today: Date {
        calendar.startOfDay(for: now)
    }

    var yesterday: Date {
        calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }

    var isWithinLateCheckInWindow: Bool {
        guard lateCheckInPolicy.graceHours > 0 else { return false }
        let hour = calendar.component(.hour, from: now)
        return hour < lateCheckInPolicy.graceHours
    }

    func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
