import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct InsightsViewModelTests {
    @Test
    func loadBuildsPointsFromPersistedCompletions() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = makeDate(year: 2026, month: 2, day: 19, hour: 10)
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )
        let completion = HabitCompletion(habitID: habit.id, dayDate: today, value: 1)

        let vm = InsightsViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: [completion]]),
            logger: TestLogger(),
            calendar: calendar,
            timeZone: calendar.timeZone,
            now: { today }
        )

        await vm.load()

        let todayStart = calendar.startOfDay(for: today)
        let todayPoint = vm.points.first(where: { calendar.startOfDay(for: $0.date) == todayStart })
        #expect(todayPoint != nil)
        #expect(todayPoint?.completed == 1)
        #expect(todayPoint?.due == 1)
        #expect((vm.habitPerformance.first?.percentage ?? 0) > 0)
    }

    @Test
    func missedHabitTitlesUsesMappedHabitNames() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = makeDate(year: 2026, month: 2, day: 19, hour: 10)
        let habit = Habit(
            id: UUID(),
            name: "Workout",
            icon: "figure.run",
            category: .physical,
            type: .binary,
            schedule: .daily
        )

        let vm = InsightsViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: []]),
            logger: TestLogger(),
            calendar: calendar,
            timeZone: calendar.timeZone,
            now: { today }
        )

        await vm.load()

        let todayStart = calendar.startOfDay(for: today)
        guard let todayPoint = vm.points.first(where: { calendar.startOfDay(for: $0.date) == todayStart }) else {
            #expect(Bool(false))
            return
        }

        #expect(vm.missedHabitTitles(for: todayPoint) == ["Workout"])
    }

    @Test
    func loadCapsCategoryTotalsToRolling40DayWindow() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = makeDate(year: 2026, month: 3, day: 5, hour: 10)
        let habit = Habit(
            id: UUID(),
            name: "Morning dhikr",
            icon: "sparkles",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )
        let completions = [
            HabitCompletion(habitID: habit.id, dayDate: today, value: 1),
            HabitCompletion(habitID: habit.id, dayDate: calendar.date(byAdding: .day, value: -1, to: today)!, value: 1),
            HabitCompletion(habitID: habit.id, dayDate: calendar.date(byAdding: .day, value: -41, to: today)!, value: 1)
        ]

        let vm = InsightsViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: completions]),
            logger: TestLogger(),
            calendar: calendar,
            timeZone: calendar.timeZone,
            now: { today }
        )

        await vm.load()

        let category = try #require(vm.categoryPerformance.first)
        #expect(vm.points.count == 40)
        #expect(category.total == 40)
        #expect(category.completed == 2)
        #expect(category.percentage == 5)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: 0))!
    }
}
