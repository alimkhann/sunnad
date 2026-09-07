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

        let transaction = vm.beginHabitToggle(habit.id)
        #expect(transaction != nil)
        #expect(vm.habits[0].completedToday == true)
        if let transaction {
            let didCommit = await vm.commitHabitToggle(transaction)
            #expect(didCommit)
        }
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
        _ = await vm.saveCurrentQuote()

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

    @Test
    func toggleRollbackRestoresPreviousStateWhenCommitFails() async {
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )

        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: ThrowingCompletionsRepository(),
            quotesRepository: FakeQuotesRepository(quoteOfDay: Quote(locale: "en", text: "Quote", source: "Source", sortOrder: 0, active: true)),
            logger: TestLogger(),
            localeCode: "en",
            now: { fixedDate }
        )

        await vm.loadToday()
        let transaction = vm.beginHabitToggle(habit.id)
        let unwrapped = transaction
        #expect(unwrapped != nil)
        #expect(vm.habits.first?.completedToday == true)
        if let unwrapped {
            let didCommit = await vm.commitHabitToggle(unwrapped)
            #expect(!didCommit)
            vm.rollbackHabitToggle(unwrapped)
        }
        #expect(vm.habits.first?.completedToday == false)
    }

    @Test
    func beginHabitToggleRecomputesStreakOptimistically() async {
        let habit = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily
        )
        let yesterday = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: fixedDate)!
        let yesterdayCompletion = HabitCompletion(habitID: habit.id, dayDate: yesterday, value: 1)

        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: [yesterdayCompletion]]),
            quotesRepository: FakeQuotesRepository(quoteOfDay: Quote(locale: "en", text: "Quote", source: "Source", sortOrder: 0, active: true)),
            logger: TestLogger(),
            localeCode: "en",
            now: { fixedDate }
        )

        await vm.loadToday()
        #expect(vm.habits.first?.streak == 1)

        let transaction = vm.beginHabitToggle(habit.id)
        #expect(transaction != nil)
        #expect(vm.habits.first?.completedToday == true)
        #expect(vm.habits.first?.streak == 2)

        if let transaction {
            vm.rollbackHabitToggle(transaction)
        }
        #expect(vm.habits.first?.completedToday == false)
        #expect(vm.habits.first?.streak == 1)
    }

    @Test
    func lateCheckInRecordsYesterdayWithFullTargetAndSource() async throws {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 3, minute: 59))!
        let habit = Habit(
            name: "Custom dhikr",
            icon: "circle",
            type: .dhikr,
            targetCount: 1_000,
            schedule: .daily,
            dhikrCustomPhrase: "Hasbunallahu"
        )
        let completionsRepo = FakeCompletionsRepository(completionsByHabit: [habit.id: []])
        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: completionsRepo,
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            calendar: calendar,
            timeZone: timeZone,
            now: { now }
        )

        await vm.loadToday()
        #expect(vm.lateCheckInCandidates.map(\.id) == [habit.id])
        #expect(await vm.recordLateCheckIn(for: habit.id) == .recorded)

        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        let recorded = try #require(await completionsRepo.fetchCompletion(
            habitID: habit.id,
            on: yesterday,
            calendar: calendar,
            timeZone: timeZone
        ))
        #expect(recorded.value == 1_000)
        #expect(recorded.entrySource == .lateCheckIn)
        #expect(vm.lateCheckInCandidates.isEmpty)
    }

    @Test
    func lateCheckInIsUnavailableAtFourAM() async {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 4))!
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: []]),
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            calendar: calendar,
            timeZone: timeZone,
            now: { now }
        )

        await vm.loadToday()
        #expect(vm.lateCheckInCandidates.isEmpty)
        #expect(await vm.recordLateCheckIn(for: habit.id) == .windowClosed)
    }

    @Test
    func lateCheckInRemovesCandidateOptimisticallyBeforePersistence() async {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 3, minute: 30))!
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let gate = UpsertGate()
        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: GatedCompletionsRepository(
                base: FakeCompletionsRepository(completionsByHabit: [habit.id: []]),
                gate: gate
            ),
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            calendar: calendar,
            timeZone: timeZone,
            now: { now }
        )

        await vm.loadToday()
        #expect(vm.lateCheckInCandidates.map(\.id) == [habit.id])

        let recordTask = Task { await vm.recordLateCheckIn(for: habit.id) }
        await gate.waitUntilWaiting()
        #expect(vm.lateCheckInCandidates.isEmpty)

        gate.open()
        let result = await recordTask.value
        #expect(result == .recorded)
    }

    @Test
    func lateCheckInFailureReinsertsCandidateAtOriginalIndex() async {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 3, minute: 30))!
        let firstHabit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let secondHabit = Habit(name: "Pray", icon: "star", type: .binary, schedule: .daily)
        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [firstHabit, secondHabit]),
            completionsRepository: ThrowingCompletionsRepository(),
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            calendar: calendar,
            timeZone: timeZone,
            now: { now }
        )

        await vm.loadToday()
        #expect(vm.lateCheckInCandidates.map(\.id) == [firstHabit.id, secondHabit.id])

        let result = await vm.recordLateCheckIn(for: secondHabit.id)

        #expect(result == .storageFailure)
        #expect(vm.lateCheckInCandidates.map(\.id) == [firstHabit.id, secondHabit.id])
    }

    @Test
    func lateCheckInWindowClosedAtTapClearsCandidates() async {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var nowDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 3, minute: 59))!
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: []]),
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            calendar: calendar,
            timeZone: timeZone,
            now: { nowDate }
        )

        await vm.loadToday()
        #expect(vm.lateCheckInCandidates.map(\.id) == [habit.id])

        nowDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 4))!
        let result = await vm.recordLateCheckIn(for: habit.id)

        #expect(result == .windowClosed)
        #expect(vm.lateCheckInCandidates.isEmpty)
    }

    @Test
    func clearStaleLateCheckInCandidatesClearsOnlyOutsideWindow() async {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var nowDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 3, minute: 59))!
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: []]),
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            calendar: calendar,
            timeZone: timeZone,
            now: { nowDate }
        )

        await vm.loadToday()
        #expect(vm.lateCheckInCandidates.map(\.id) == [habit.id])

        vm.clearStaleLateCheckInCandidates()
        #expect(vm.lateCheckInCandidates.map(\.id) == [habit.id])

        nowDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 4, minute: 5))!
        vm.clearStaleLateCheckInCandidates()
        #expect(vm.lateCheckInCandidates.isEmpty)
    }

    @Test
    func lateCheckInRecomputesTodayStreakWithoutFullReload() async {
        let timeZone = TimeZone(identifier: "Asia/Almaty")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 3, minute: 59))!
        let habit = Habit(name: "Read", icon: "book", type: .binary, schedule: .daily)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now))!
        let twoDaysAgoCompletion = HabitCompletion(habitID: habit.id, dayDate: twoDaysAgo, value: 1)
        let vm = TodayViewModel(
            habitsRepository: FakeHabitsRepository(habits: [habit]),
            completionsRepository: FakeCompletionsRepository(completionsByHabit: [habit.id: [twoDaysAgoCompletion]]),
            quotesRepository: FakeQuotesRepository(quoteOfDay: nil),
            logger: TestLogger(),
            localeCode: "en",
            calendar: calendar,
            timeZone: timeZone,
            now: { now }
        )

        await vm.loadToday()
        #expect(vm.habits.first?.streak == 1)

        let result = await vm.recordLateCheckIn(for: habit.id)

        #expect(result == .recorded)
        #expect(vm.habits.first?.streak == 2)
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

final class ThrowingCompletionsRepository: CompletionsRepository, @unchecked Sendable {
    struct TestError: Error {}

    func fetchCompletions(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [HabitCompletion] {
        []
    }

    func fetchCompletions(for habitID: UUID) async throws -> [HabitCompletion] {
        []
    }

    func fetchCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> HabitCompletion? {
        nil
    }

    func upsertCompletion(_ completion: HabitCompletion, calendar: Calendar, timeZone: TimeZone) async throws {
        throw TestError()
    }

    func deleteCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws {}
}

final class UpsertGate: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isWaitingFlag = false
    private let lock = NSLock()

    private var isWaiting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isWaitingFlag
    }

    func waitUntilWaiting() async {
        while !isWaiting {
            await Task.yield()
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            isWaitingFlag = true
            lock.unlock()
        }
    }

    func open() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        isWaitingFlag = false
        lock.unlock()
        continuation?.resume()
    }
}

final class GatedCompletionsRepository: CompletionsRepository, @unchecked Sendable {
    let base: FakeCompletionsRepository
    let gate: UpsertGate

    init(base: FakeCompletionsRepository, gate: UpsertGate) {
        self.base = base
        self.gate = gate
    }

    func fetchCompletions(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [HabitCompletion] {
        try await base.fetchCompletions(on: day, calendar: calendar, timeZone: timeZone)
    }

    func fetchCompletions(for habitID: UUID) async throws -> [HabitCompletion] {
        try await base.fetchCompletions(for: habitID)
    }

    func fetchCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> HabitCompletion? {
        try await base.fetchCompletion(habitID: habitID, on: day, calendar: calendar, timeZone: timeZone)
    }

    func upsertCompletion(_ completion: HabitCompletion, calendar: Calendar, timeZone: TimeZone) async throws {
        await gate.wait()
        try await base.upsertCompletion(completion, calendar: calendar, timeZone: timeZone)
    }

    func deleteCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws {
        try await base.deleteCompletion(habitID: habitID, on: day, calendar: calendar, timeZone: timeZone)
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

    func deleteAllSavedQuotes() async throws {
        savedQuotes = []
    }
}
