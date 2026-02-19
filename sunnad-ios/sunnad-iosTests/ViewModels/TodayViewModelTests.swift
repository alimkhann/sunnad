import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct TodayViewModelTests {
    @Test
    func loadTodayProducesHabitsAndQuote() async {
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            reminder: HabitReminder(hour: 9, minute: 0)
        )

        let quote = Quote(id: UUID(), locale: "en", text: "Quote", source: "Source", sortOrder: 0, active: true)
        let habitsRepo = FakeHabitsRepository(habits: [habit])
        let completionsRepo = FakeCompletionsRepository(completionsByHabit: [habit.id: []])
        let quotesRepo = FakeQuotesRepository(quoteOfDay: quote)

        let vm = TodayViewModel(
            habitsRepository: habitsRepo,
            completionsRepository: completionsRepo,
            quotesRepository: quotesRepo,
            logger: TestLogger(),
            localeCode: "en",
            now: { fixedDate }
        )

        await vm.loadToday()

        #expect(vm.habits.count == 1)
        #expect(vm.habits[0].displayTitle == "Read Quran")
        #expect(vm.quote.text == "Quote")
        #expect(vm.errorMessage == nil)
    }

    @Test
    func toggleHabitUpdatesCompletionState() async {
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )

        let habitsRepo = FakeHabitsRepository(habits: [habit])
        let completionsRepo = FakeCompletionsRepository(completionsByHabit: [habit.id: []])
        let quotesRepo = FakeQuotesRepository(quoteOfDay: Quote(locale: "en", text: "Quote", source: "Source", sortOrder: 0, active: true))

        let vm = TodayViewModel(
            habitsRepository: habitsRepo,
            completionsRepository: completionsRepo,
            quotesRepository: quotesRepo,
            logger: TestLogger(),
            localeCode: "en",
            now: { fixedDate }
        )

        await vm.loadToday()
        #expect(vm.habits[0].completedToday == false)

        await vm.toggleHabit(habit.id)

        #expect(vm.habits[0].completedToday == true)
    }

    @Test
    func saveQuoteRefreshesSavedQuotes() async {
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )

        let quote = Quote(id: UUID(), locale: "en", text: "Quote", source: "Source", sortOrder: 0, active: true)
        let habitsRepo = FakeHabitsRepository(habits: [habit])
        let completionsRepo = FakeCompletionsRepository(completionsByHabit: [habit.id: []])
        let quotesRepo = FakeQuotesRepository(quoteOfDay: quote)

        let vm = TodayViewModel(
            habitsRepository: habitsRepo,
            completionsRepository: completionsRepo,
            quotesRepository: quotesRepo,
            logger: TestLogger(),
            localeCode: "en",
            now: { fixedDate }
        )

        await vm.loadToday()
        await vm.saveCurrentQuote()

        #expect(vm.savedQuotes.count == 1)
        #expect(vm.savedQuotes[0].text == "Quote")
    }

    @Test
    func loadTodaySurfacesRecoverableError() async {
        let vm = TodayViewModel(
            habitsRepository: ThrowingHabitsRepository(),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [:]),
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            now: { fixedDate }
        )

        await vm.loadToday()

        #expect(vm.errorMessage != nil)
        #expect(vm.habits.isEmpty)
    }

    @Test
    func loadTodayReevaluatesCompletionWhenDayChanges() async {
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )

        var nowDate = makeDate(year: 2026, month: 12, day: 31, hour: 10)
        let dayOneCompletion = HabitCompletion(habitID: habit.id, dayDate: nowDate, value: 1)

        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: [dayOneCompletion]]),
            quotesRepository: FakeQuotesRepository(quoteOfDay: Quote(locale: "en", text: "Quote", source: "Source", sortOrder: 0, active: true)),
            logger: TestLogger(),
            localeCode: "en",
            now: { nowDate }
        )

        await vm.loadToday()
        #expect(vm.habits[0].completedToday)

        nowDate = makeDate(year: 2027, month: 1, day: 1, hour: 10)
        await vm.loadToday()
        #expect(!vm.habits[0].completedToday)
    }

    private var fixedDate: Date {
        makeDate(year: 2026, month: 2, day: 19, hour: 10)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: 0))!
    }
}

final class FakeHabitsRepository: HabitsRepository, @unchecked Sendable {
    var habits: [Habit]

    init(habits: [Habit]) {
        self.habits = habits
    }

    func fetchHabits(includeArchived: Bool) async throws -> [Habit] {
        includeArchived ? habits : habits.filter { !$0.archived }
    }

    func fetchDueHabits(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [Habit] {
        habits.filter { $0.isDue(on: day, calendar: calendar, timeZone: timeZone) }
    }

    func saveHabit(_ habit: Habit) async throws {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }
    }

    func deleteHabit(id: UUID) async throws {
        habits.removeAll { $0.id == id }
    }
}

final class ThrowingHabitsRepository: HabitsRepository, @unchecked Sendable {
    struct TestError: Error {}

    func fetchHabits(includeArchived: Bool) async throws -> [Habit] {
        throw TestError()
    }

    func fetchDueHabits(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [Habit] {
        throw TestError()
    }

    func saveHabit(_ habit: Habit) async throws {
        throw TestError()
    }

    func deleteHabit(id: UUID) async throws {
        throw TestError()
    }
}

final class FakeCompletionsRepository: CompletionsRepository, @unchecked Sendable {
    var completionsByHabit: [UUID: [HabitCompletion]]

    init(completionsByHabit: [UUID: [HabitCompletion]]) {
        self.completionsByHabit = completionsByHabit
    }

    func fetchCompletions(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [HabitCompletion] {
        let target = calendar.startOfDay(for: day)
        return completionsByHabit.values
            .flatMap { $0 }
            .filter { calendar.startOfDay(for: $0.dayDate) == target }
    }

    func fetchCompletions(for habitID: UUID) async throws -> [HabitCompletion] {
        completionsByHabit[habitID, default: []]
    }

    func fetchCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> HabitCompletion? {
        let target = calendar.startOfDay(for: day)
        return completionsByHabit[habitID, default: []].first { calendar.startOfDay(for: $0.dayDate) == target }
    }

    func upsertCompletion(_ completion: HabitCompletion, calendar: Calendar, timeZone: TimeZone) async throws {
        var rows = completionsByHabit[completion.habitID, default: []]
        let target = calendar.startOfDay(for: completion.dayDate)

        if let index = rows.firstIndex(where: { calendar.startOfDay(for: $0.dayDate) == target }) {
            rows[index] = completion
        } else {
            rows.append(completion)
        }

        completionsByHabit[completion.habitID] = rows
    }

    func deleteCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws {
        let target = calendar.startOfDay(for: day)
        completionsByHabit[habitID] = completionsByHabit[habitID, default: []].filter {
            calendar.startOfDay(for: $0.dayDate) != target
        }
    }
}

final class FakeQuotesRepository: QuotesRepository, @unchecked Sendable {
    var quoteOfDay: Quote?
    var savedQuotes: [SavedQuote] = []

    init(quoteOfDay: Quote?) {
        self.quoteOfDay = quoteOfDay
    }

    func fetchQuoteOfDay(locale: String, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> Quote? {
        quoteOfDay
    }

    func fetchSavedQuotes() async throws -> [SavedQuote] {
        savedQuotes.sorted { $0.savedAt > $1.savedAt }
    }

    func saveQuote(_ quote: Quote, savedAt: Date) async throws {
        savedQuotes.append(
            SavedQuote(
                quoteID: quote.id,
                text: quote.text,
                author: quote.source ?? "",
                savedAt: savedAt
            )
        )
    }
}
