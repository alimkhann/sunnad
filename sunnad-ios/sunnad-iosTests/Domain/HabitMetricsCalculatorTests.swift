import Foundation
import Testing
@testable import sunnad_ios

struct HabitMetricsCalculatorTests {
    @Test
    func pendingTodayDoesNotBreakExistingStreak() {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        let now = date(2026, 8, 29, 14, timeZone)
        let context = DayContext(now: now, timeZone: timeZone)
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let completions = [1, 2, 3].map {
            HabitCompletion(
                habitID: habit.id,
                dayDate: context.calendar.date(byAdding: .day, value: -$0, to: context.today)!,
                value: 1
            )
        }

        #expect(HabitMetricsCalculator.streak(for: habit, completions: completions, context: context) == 3)
    }

    @Test
    func missedYesterdayRemainsRecoverableBeforeFourAM() {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        let now = date(2026, 8, 29, 3, timeZone, minute: 59)
        let context = DayContext(now: now, timeZone: timeZone)
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let twoDaysAgo = context.calendar.date(byAdding: .day, value: -2, to: context.today)!
        let completions = [HabitCompletion(habitID: habit.id, dayDate: twoDaysAgo, value: 1)]

        #expect(context.isWithinLateCheckInWindow)
        #expect(HabitMetricsCalculator.streak(for: habit, completions: completions, context: context) == 1)
    }

    @Test
    func missedYesterdayBreaksStreakAtFourAM() {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        let now = date(2026, 8, 29, 4, timeZone)
        let context = DayContext(now: now, timeZone: timeZone)
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let twoDaysAgo = context.calendar.date(byAdding: .day, value: -2, to: context.today)!
        let completions = [HabitCompletion(habitID: habit.id, dayDate: twoDaysAgo, value: 1)]

        #expect(!context.isWithinLateCheckInWindow)
        #expect(HabitMetricsCalculator.streak(for: habit, completions: completions, context: context) == 0)
    }

    @Test
    func weeklyHabitDueYesterdayRemainsRecoverableBeforeFourAM() {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        let now = date(2026, 8, 29, 3, timeZone, minute: 59) // Saturday
        let context = DayContext(now: now, timeZone: timeZone)
        let habit = Habit(
            name: "Friday review",
            icon: "book",
            type: .binary,
            schedule: .weekly([.friday])
        )
        let priorFriday = context.calendar.date(byAdding: .day, value: -8, to: context.today)!
        let completions = [HabitCompletion(habitID: habit.id, dayDate: priorFriday, value: 1)]

        #expect(HabitMetricsCalculator.streak(for: habit, completions: completions, context: context) == 1)
    }

    @Test
    func rollingPercentageUsesEligibleOccurrencesAndExcludesToday() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(2026, 8, 29, 12, timeZone)
        let context = DayContext(now: now, timeZone: timeZone)
        let createdAt = context.calendar.date(byAdding: .day, value: -4, to: context.today)!
        let habit = Habit(
            name: "Read",
            icon: "book",
            type: .binary,
            schedule: .daily,
            createdAt: createdAt
        )
        let completions = [1, 3].map {
            HabitCompletion(
                habitID: habit.id,
                dayDate: context.calendar.date(byAdding: .day, value: -$0, to: context.today)!,
                value: 1
            )
        }

        #expect(HabitMetricsCalculator.rollingCompletionPercent(
            for: habit,
            completions: completions,
            context: context,
            occurrenceLimit: 40
        ) == 50)
    }

    @Test
    func newHabitHasNoRollingPercentage() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(2026, 8, 29, 12, timeZone)
        let context = DayContext(now: now, timeZone: timeZone)
        let habit = Habit(
            name: "New",
            icon: "star",
            type: .binary,
            createdAt: now
        )

        #expect(HabitMetricsCalculator.rollingCompletionPercent(
            for: habit,
            completions: [],
            context: context
        ) == nil)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ timeZone: TimeZone,
        minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
