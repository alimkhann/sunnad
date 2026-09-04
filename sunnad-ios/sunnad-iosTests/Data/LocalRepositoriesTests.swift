import Foundation
import Testing
import SwiftData
@testable import sunnad_ios

@MainActor
struct LocalRepositoriesTests {
    @Test
    func createUpdateDeleteHabitPersists() async throws {
        let container = try makeInMemoryContainer()
        let logger = TestLogger()
        let ownerScope = makeTestOwnerScopeResolver()
        let repository = HabitsLocalRepository(modelContext: container.mainContext, logger: logger, ownerScopeProvider: ownerScope)

        let originalCreatedAt = date(year: 2025, month: 1, day: 1)
        var habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            sortOrder: 0,
            createdAt: originalCreatedAt
        )

        try await repository.saveHabit(habit)

        var habits = try await repository.fetchHabits(includeArchived: false)
        #expect(habits.count == 1)
        #expect(habits[0].name == "Read Quran")

        habit.name = "Read Surah"
        habit.createdAt = date(year: 2026, month: 2, day: 19)
        try await repository.saveHabit(habit)

        habits = try await repository.fetchHabits(includeArchived: false)
        #expect(habits.count == 1)
        #expect(habits[0].name == "Read Surah")
        #expect(habits[0].createdAt == originalCreatedAt)

        try await repository.deleteHabit(id: habit.id)
        habits = try await repository.fetchHabits(includeArchived: false)
        #expect(habits.isEmpty)
    }

    @Test
    func dueHabitsFilterExcludesNotScheduled() async throws {
        let container = try makeInMemoryContainer()
        let logger = TestLogger()
        let ownerScope = makeTestOwnerScopeResolver()
        let repository = HabitsLocalRepository(modelContext: container.mainContext, logger: logger, ownerScopeProvider: ownerScope)

        let mondayOnly = Habit(
            id: UUID(),
            name: "Gym",
            icon: "figure.run",
            category: .physical,
            type: .binary,
            schedule: .weekly([.monday]),
            sortOrder: 0
        )

        let daily = Habit(
            id: UUID(),
            name: "Dhikr",
            icon: "star",
            category: .spiritual,
            type: .dhikr,
            targetCount: 33,
            schedule: .daily,
            sortOrder: 1
        )

        try await repository.saveHabit(mondayOnly)
        try await repository.saveHabit(daily)

        let tuesday = date(year: 2026, month: 2, day: 17)
        let due = try await repository.fetchDueHabits(on: tuesday, calendar: .gregorianUTC, timeZone: .utc)

        #expect(due.count == 1)
        #expect(due.first?.id == daily.id)
    }

    @Test
    func completionUpsertIsIdempotentForSameDay() async throws {
        let container = try makeInMemoryContainer()
        let logger = TestLogger()
        let ownerScope = makeTestOwnerScopeResolver()
        let repository = CompletionsLocalRepository(modelContext: container.mainContext, logger: logger, ownerScopeProvider: ownerScope)

        let habitID = UUID()
        let day = date(year: 2026, month: 2, day: 19)

        let first = HabitCompletion(habitID: habitID, dayDate: day, value: 1)
        try await repository.upsertCompletion(first, calendar: .gregorianUTC, timeZone: .utc)

        let second = HabitCompletion(habitID: habitID, dayDate: day, value: 0)
        try await repository.upsertCompletion(second, calendar: .gregorianUTC, timeZone: .utc)

        let rows = try await repository.fetchCompletions(on: day, calendar: .gregorianUTC, timeZone: .utc)

        #expect(rows.count == 1)
        #expect(rows[0].value == 0)
    }

    @Test
    func savedQuotesAreReturnedInDescendingOrder() async throws {
        let container = try makeInMemoryContainer()
        let logger = TestLogger()
        let ownerScope = makeTestOwnerScopeResolver()
        let repository = QuotesLocalRepository(modelContext: container.mainContext, logger: logger, ownerScopeProvider: ownerScope)

        let first = Quote(id: UUID(), locale: "en", text: "Q1", source: "S1", sortOrder: 0, active: true)
        let second = Quote(id: UUID(), locale: "en", text: "Q2", source: "S2", sortOrder: 1, active: true)

        try await repository.saveQuote(first, savedAt: date(year: 2026, month: 2, day: 19, hour: 8))
        try await repository.saveQuote(second, savedAt: date(year: 2026, month: 2, day: 20, hour: 8))

        let saved = try await repository.fetchSavedQuotes()

        #expect(saved.count == 2)
        #expect(saved[0].savedAt > saved[1].savedAt)
    }

    @Test
    func habitsAreFetchedByPersistedSortOrder() async throws {
        let container = try makeInMemoryContainer()
        let logger = TestLogger()
        let ownerScope = makeTestOwnerScopeResolver()
        let repository = HabitsLocalRepository(modelContext: container.mainContext, logger: logger, ownerScopeProvider: ownerScope)

        let first = Habit(
            id: UUID(),
            name: "First",
            icon: "1.circle",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            sortOrder: 1
        )

        let second = Habit(
            id: UUID(),
            name: "Second",
            icon: "2.circle",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            sortOrder: 0
        )

        try await repository.saveHabit(first)
        try await repository.saveHabit(second)

        let fetched = try await repository.fetchHabits(includeArchived: false)
        #expect(fetched.map(\.id) == [second.id, first.id])
    }

    @Test
    func dhikrPhrasePersistsWithoutHabitLevelCounts() async throws {
        let container = try makeInMemoryContainer()
        let logger = TestLogger()
        let ownerScope = makeTestOwnerScopeResolver()
        let repository = HabitsLocalRepository(modelContext: container.mainContext, logger: logger, ownerScopeProvider: ownerScope)

        let habit = Habit(
            id: UUID(),
            name: "Morning dhikr",
            icon: "sun.max.fill",
            category: .spiritual,
            type: .dhikr,
            targetCount: 33,
            schedule: .daily,
            dhikrPhraseKey: "dhikr.choice.alhamdulillah"
        )

        try await repository.saveHabit(habit)
        let fetched = try await repository.fetchHabits(includeArchived: false)

        #expect(fetched.count == 1)
        #expect(fetched[0].dhikrPhraseKey == "dhikr.choice.alhamdulillah")
        #expect(fetched[0].dhikrCustomPhrase == nil)
    }

    @Test
    func ownerScopeIsolationAllowsSameHabitIDAcrossScopes() async throws {
        let container = try makeInMemoryContainer()
        let logger = TestLogger()
        let ownerScope = makeTestOwnerScopeResolver(namespace: "owner-scope-isolation")
        let repository = HabitsLocalRepository(modelContext: container.mainContext, logger: logger, ownerScopeProvider: ownerScope)

        let sharedHabitID = UUID()
        let guestHabit = Habit(
            id: sharedHabitID,
            name: "Guest Habit",
            icon: "person",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )
        try await repository.saveHabit(guestHabit)

        let userID = UUID()
        ownerScope.setSignedInUserID(userID)
        let accountHabit = Habit(
            id: sharedHabitID,
            name: "Account Habit",
            icon: "person.crop.circle",
            category: .physical,
            type: .binary,
            schedule: .daily
        )
        try await repository.saveHabit(accountHabit)

        let signedInHabits = try await repository.fetchHabits(includeArchived: false)
        #expect(signedInHabits.count == 1)
        #expect(signedInHabits.first?.name == "Account Habit")

        ownerScope.setSignedInUserID(nil)
        let guestHabits = try await repository.fetchHabits(includeArchived: false)
        #expect(guestHabits.count == 1)
        #expect(guestHabits.first?.name == "Guest Habit")
    }

    @Test
    func clearLocalDataForScopeDoesNotReseedHabitsOnContainerRebuild() async throws {
        let container = try makeInMemoryContainer()
        let authService = FakeAuthService(currentUserValue: nil)

        let dependencies = DependencyContainer(
            modelContainer: container,
            authService: authService,
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )

        let habit = Habit(
            id: UUID(),
            name: "Temporary Habit",
            icon: "trash",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )
        try await dependencies.habitsRepository.saveHabit(habit)

        try await dependencies.clearLocalDataForCurrentScope()

        let rebuiltDependencies = DependencyContainer(
            modelContainer: container,
            authService: authService,
            deviceTokenSyncService: FakeDeviceTokenSyncService()
        )

        let habitsAfterRebuild = try await rebuiltDependencies.habitsRepository.fetchHabits(includeArchived: true)
        #expect(habitsAfterRebuild.isEmpty)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        let calendar = Calendar.gregorianUTC
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: 0))!
    }
}

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .utc
        return calendar
    }
}

private extension TimeZone {
    static var utc: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }
}
