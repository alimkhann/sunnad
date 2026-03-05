import Foundation
import Testing
@testable import sunnad_ios

struct StreakCalculatorTests {
    @Test
    func dailyStreakCountsContiguousCompletedDays() {
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!
        let today = makeDate(year: 2026, month: 2, day: 19, timeZone: tz)

        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let completions = [0, 1, 2].map {
            HabitCompletion(
                habitID: habit.id,
                dayDate: calendar.date(byAdding: .day, value: -$0, to: today)!,
                value: 1
            )
        }

        let streak = StreakCalculator.streak(for: habit, completions: completions, asOf: today, calendar: calendar, timeZone: tz)
        #expect(streak == 3)
    }

    @Test
    func streakBreaksOnMissedDueDay() {
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!
        let today = makeDate(year: 2026, month: 2, day: 19, timeZone: tz)

        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let completions = [0, 2].map {
            HabitCompletion(
                habitID: habit.id,
                dayDate: calendar.date(byAdding: .day, value: -$0, to: today)!,
                value: 1
            )
        }

        let streak = StreakCalculator.streak(for: habit, completions: completions, asOf: today, calendar: calendar, timeZone: tz)
        #expect(streak == 1)
    }

    @Test
    func currentDayPendingCompletionCarriesPreviousStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!
        let today = makeDate(year: 2026, month: 2, day: 19, timeZone: tz)

        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let completions = [1, 2].map {
            HabitCompletion(
                habitID: habit.id,
                dayDate: calendar.date(byAdding: .day, value: -$0, to: today)!,
                value: 1
            )
        }

        let streak = StreakCalculator.streak(
            for: habit,
            completions: completions,
            asOf: today,
            calendar: calendar,
            timeZone: tz,
            referenceDate: today
        )
        #expect(streak == 2)
    }

    @Test
    func weeklyStreakSkipsNonDueDays() {
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!
        let thursday = makeDate(year: 2026, month: 2, day: 19, timeZone: tz)

        let habit = Habit(
            name: "Exercise",
            icon: "figure.run",
            type: .binary,
            schedule: .weekly([.monday, .thursday])
        )

        let completionDates = [
            makeDate(year: 2026, month: 2, day: 19, timeZone: tz),
            makeDate(year: 2026, month: 2, day: 16, timeZone: tz),
            makeDate(year: 2026, month: 2, day: 12, timeZone: tz)
        ]

        let completions = completionDates.map {
            HabitCompletion(habitID: habit.id, dayDate: $0, value: 1)
        }

        let streak = StreakCalculator.streak(for: habit, completions: completions, asOf: thursday, calendar: calendar, timeZone: tz)
        #expect(streak == 3)
    }

    @Test
    func dailyStreakCrossesMonthAndYearBoundary() {
        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!
        let jan1 = makeDate(year: 2027, month: 1, day: 1, timeZone: tz)

        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let completionDates = [
            makeDate(year: 2027, month: 1, day: 1, timeZone: tz),
            makeDate(year: 2026, month: 12, day: 31, timeZone: tz),
            makeDate(year: 2026, month: 12, day: 30, timeZone: tz)
        ]
        let completions = completionDates.map {
            HabitCompletion(habitID: habit.id, dayDate: $0, value: 1)
        }

        let streak = StreakCalculator.streak(for: habit, completions: completions, asOf: jan1, calendar: calendar, timeZone: tz)
        #expect(streak == 3)
    }

    private func makeDate(year: Int, month: Int, day: Int, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9, minute: 0))!
    }
}
