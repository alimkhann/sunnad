import Foundation

enum StreakCalculator {
    static func streak(
        for habit: Habit,
        completions: [HabitCompletion],
        asOf date: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> Int {
        var calendar = calendar
        calendar.timeZone = timeZone

        var normalized: [Date: HabitCompletion] = [:]
        normalized.reserveCapacity(completions.count)
        for completion in completions {
            let dayKey = calendar.startOfDay(for: completion.dayDate)
            if let existing = normalized[dayKey] {
                if completion.updatedAt >= existing.updatedAt {
                    normalized[dayKey] = completion
                }
            } else {
                normalized[dayKey] = completion
            }
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: date)

        // If current day is not due for this habit, evaluate from the latest previous due day.
        while !habit.isDue(on: cursor, calendar: calendar, timeZone: timeZone) {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = previous
        }

        while true {
            guard let completion = normalized[cursor], completion.isCompleted(for: habit) else {
                break
            }

            streak += 1

            guard let previous = previousDueDate(
                for: habit,
                before: cursor,
                calendar: calendar,
                timeZone: timeZone
            ) else {
                break
            }

            cursor = previous
        }

        return streak
    }

    private static func previousDueDate(
        for habit: Habit,
        before date: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date? {
        var probe = date
        for _ in 0..<14 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: probe) else {
                return nil
            }
            probe = previous
            if habit.isDue(on: probe, calendar: calendar, timeZone: timeZone) {
                return probe
            }
        }
        return nil
    }
}
