import Foundation

@MainActor
final class SyncingHabitsRepository: HabitsRepository {
    private let base: HabitsRepository
    private let syncCoordinator: SyncCoordinating

    init(base: HabitsRepository, syncCoordinator: SyncCoordinating) {
        self.base = base
        self.syncCoordinator = syncCoordinator
    }

    func fetchHabits(includeArchived: Bool) async throws -> [Habit] {
        try await base.fetchHabits(includeArchived: includeArchived)
    }

    func fetchDueHabits(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [Habit] {
        try await base.fetchDueHabits(on: day, calendar: calendar, timeZone: timeZone)
    }

    func saveHabit(_ habit: Habit) async throws {
        try await base.saveHabit(habit)
        await syncCoordinator.enqueueHabitUpsert(habitID: habit.id)
    }

    func deleteHabit(id: UUID) async throws {
        try await base.deleteHabit(id: id)
        await syncCoordinator.enqueueHabitDelete(habitID: id)
    }
}

@MainActor
final class SyncingCompletionsRepository: CompletionsRepository {
    private let base: CompletionsRepository
    private let syncCoordinator: SyncCoordinating

    init(base: CompletionsRepository, syncCoordinator: SyncCoordinating) {
        self.base = base
        self.syncCoordinator = syncCoordinator
    }

    func fetchCompletions(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [HabitCompletion] {
        try await base.fetchCompletions(on: day, calendar: calendar, timeZone: timeZone)
    }

    func fetchCompletions(for habitID: UUID) async throws -> [HabitCompletion] {
        try await base.fetchCompletions(for: habitID)
    }

    func fetchCompletion(
        habitID: UUID,
        on day: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) async throws -> HabitCompletion? {
        try await base.fetchCompletion(habitID: habitID, on: day, calendar: calendar, timeZone: timeZone)
    }

    func upsertCompletion(_ completion: HabitCompletion, calendar: Calendar, timeZone: TimeZone) async throws {
        try await base.upsertCompletion(completion, calendar: calendar, timeZone: timeZone)
        await syncCoordinator.enqueueCompletionUpsert(
            habitID: completion.habitID,
            dayDate: completion.dayDate,
            calendar: calendar,
            timeZone: timeZone
        )
    }

    func deleteCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws {
        try await base.deleteCompletion(habitID: habitID, on: day, calendar: calendar, timeZone: timeZone)
    }
}

@MainActor
final class SyncingQuotesRepository: QuotesRepository {
    private let base: QuotesRepository
    private let syncCoordinator: SyncCoordinating

    init(base: QuotesRepository, syncCoordinator: SyncCoordinating) {
        self.base = base
        self.syncCoordinator = syncCoordinator
    }

    func fetchQuoteOfDay(locale: String, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> Quote? {
        try await base.fetchQuoteOfDay(locale: locale, on: day, calendar: calendar, timeZone: timeZone)
    }

    func fetchSavedQuotes() async throws -> [SavedQuote] {
        try await base.fetchSavedQuotes()
    }

    func saveQuote(_ quote: Quote, savedAt: Date) async throws {
        try await base.saveQuote(quote, savedAt: savedAt)
        await syncCoordinator.enqueueSavedQuoteInsert(quoteID: quote.id)
    }

    func deleteAllSavedQuotes() async throws {
        let existing = try await base.fetchSavedQuotes()
        try await base.deleteAllSavedQuotes()

        for item in existing {
            guard let quoteID = item.quoteID else { continue }
            await syncCoordinator.enqueueSavedQuoteDelete(quoteID: quoteID)
        }
    }
}
