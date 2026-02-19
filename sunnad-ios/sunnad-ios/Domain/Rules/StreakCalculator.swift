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

        let normalized = Dictionary(uniqueKeysWithValues: completions.map {
            (calendar.startOfDay(for: $0.dayDate), $0)
        })

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
