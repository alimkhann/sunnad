import Foundation

struct HabitMetrics: Hashable, Sendable {
    let streak: Int
    let rollingCompletionPercent: Int?
}

enum HabitMetricsCalculator {
    static func metrics(
        for habit: Habit,
        completions: [HabitCompletion],
        context: DayContext,
        occurrenceLimit: Int = 40
    ) -> HabitMetrics {
        HabitMetrics(
            streak: streak(for: habit, completions: completions, context: context),
            rollingCompletionPercent: rollingCompletionPercent(
                for: habit,
                completions: completions,
                context: context,
                occurrenceLimit: occurrenceLimit
            )
        )
    }

    static func streak(
        for habit: Habit,
        completions: [HabitCompletion],
        context: DayContext
    ) -> Int {
        let completionsByDay = normalizedCompletions(completions, context: context)
        var cursor = context.today

        guard let firstDueDate = dueDate(
            for: habit,
            onOrBefore: cursor,
            context: context
        ) else {
            return 0
        }
        cursor = firstDueDate

        if !isCompleted(on: cursor, for: habit, completionsByDay: completionsByDay, context: context) {
            if cursor == context.today {
                guard let previous = previousDueDate(for: habit, before: cursor, context: context) else {
                    return 0
                }
                cursor = previous
            } else if context.isWithinLateCheckInWindow, cursor == context.yesterday {
                // The grace-window branch below advances past recoverable yesterday.
            } else {
                return 0
            }
        }

        if context.isWithinLateCheckInWindow,
           cursor == context.yesterday,
           !isCompleted(on: cursor, for: habit, completionsByDay: completionsByDay, context: context) {
            guard let previous = previousDueDate(for: habit, before: cursor, context: context) else {
                return 0
            }
            cursor = previous
        }

        var result = 0
        while isCompleted(on: cursor, for: habit, completionsByDay: completionsByDay, context: context) {
            result += 1
            guard let previous = previousDueDate(for: habit, before: cursor, context: context) else {
                break
            }
            cursor = previous
        }
        return result
    }

    static func rollingCompletionPercent(
        for habit: Habit,
        completions: [HabitCompletion],
        context: DayContext,
        occurrenceLimit: Int = 40
    ) -> Int? {
        guard occurrenceLimit > 0 else { return nil }
        let completionsByDay = normalizedCompletions(completions, context: context)
        let createdDay = context.startOfDay(for: habit.createdAt)
        var cursor = context.yesterday
        var eligible = 0
        var completed = 0
        var inspectedDays = 0

        while eligible < occurrenceLimit, cursor >= createdDay, inspectedDays < 4_000 {
            if habit.isDue(on: cursor, calendar: context.calendar, timeZone: context.timeZone) {
                eligible += 1
                if isCompleted(
                    on: cursor,
                    for: habit,
                    completionsByDay: completionsByDay,
                    context: context
                ) {
                    completed += 1
                }
            }
            inspectedDays += 1
            guard let previous = context.calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        guard eligible > 0 else { return nil }
        return Int((Double(completed) / Double(eligible) * 100).rounded())
    }

    private static func normalizedCompletions(
        _ completions: [HabitCompletion],
        context: DayContext
    ) -> [Date: HabitCompletion] {
        completions.reduce(into: [:]) { result, completion in
            let key = context.startOfDay(for: completion.dayDate)
            if let existing = result[key], existing.updatedAt > completion.updatedAt {
                return
            }
            result[key] = completion
        }
    }

    private static func isCompleted(
        on day: Date,
        for habit: Habit,
        completionsByDay: [Date: HabitCompletion],
        context: DayContext
    ) -> Bool {
        completionsByDay[context.startOfDay(for: day)]?.isCompleted(for: habit) == true
    }

    private static func dueDate(
        for habit: Habit,
        onOrBefore date: Date,
        context: DayContext
    ) -> Date? {
        var probe = context.startOfDay(for: date)
        for _ in 0..<370 {
            if habit.isDue(on: probe, calendar: context.calendar, timeZone: context.timeZone) {
                return probe
            }
            guard let previous = context.calendar.date(byAdding: .day, value: -1, to: probe) else {
                return nil
            }
            probe = previous
        }
        return nil
    }

    private static func previousDueDate(
        for habit: Habit,
        before date: Date,
        context: DayContext
    ) -> Date? {
        guard let previous = context.calendar.date(byAdding: .day, value: -1, to: date) else {
            return nil
        }
        return dueDate(for: habit, onOrBefore: previous, context: context)
    }
}
