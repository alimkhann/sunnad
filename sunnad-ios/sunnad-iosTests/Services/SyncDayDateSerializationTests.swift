import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct SyncDayDateSerializationTests {
    @Test
    func syncDayDateRoundTripPreservesLocalDayComponents() {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let source = calendar.date(from: DateComponents(year: 2026, month: 2, day: 21, hour: 0, minute: 30))!
        let dayKey = SupabaseSyncCoordinator.syncDayDateString(for: source, calendar: calendar, timeZone: timeZone)

        #expect(dayKey == "2026-02-21")

        let parsed = SupabaseSyncCoordinator.syncDayDate(dayKey, calendar: calendar, timeZone: timeZone)
        #expect(parsed != nil)

        let parsedComponents = calendar.dateComponents([.year, .month, .day], from: parsed!)
        #expect(parsedComponents.year == 2026)
        #expect(parsedComponents.month == 2)
        #expect(parsedComponents.day == 21)
    }

    @Test
    func singleCompletionDayDoesNotInflateStreakInNonUTCTimezone() {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let asOf = calendar.date(from: DateComponents(year: 2026, month: 2, day: 21, hour: 10, minute: 0))!
        let localCompletionDay = calendar.startOfDay(for: asOf)
        let parsedCompletionDay = SupabaseSyncCoordinator.syncDayDate(
            "2026-02-21",
            calendar: calendar,
            timeZone: timeZone
        )

        #expect(parsedCompletionDay != nil)

        let habit = Habit(name: "Read", icon: "book.fill", type: .binary, schedule: .daily)
        let completions = [
            HabitCompletion(
                habitID: habit.id,
                dayDate: localCompletionDay,
                value: 1,
                updatedAt: asOf
            ),
            HabitCompletion(
                habitID: habit.id,
                dayDate: parsedCompletionDay!,
                value: 1,
                updatedAt: asOf.addingTimeInterval(60)
            )
        ]

        let streak = StreakCalculator.streak(
            for: habit,
            completions: completions,
            asOf: asOf,
            calendar: calendar,
            timeZone: timeZone
        )

        #expect(streak == 1)
    }
}
