import Combine
import Foundation

enum LateCheckInResult: Equatable {
    case recorded
    case windowClosed
    case storageFailure
}

@MainActor
final class TodayViewModel: ObservableObject {
    struct HabitToggleTransaction {
        let habitID: UUID
        let previousValue: Int
        let nextValue: Int
        let type: String
        let status: String
    }

    @Published private(set) var habits: [UIHabit] = []
    @Published private(set) var quote: UIQuote = UIFixtures.dailyQuote
    @Published private(set) var savedQuotes: [UISavedQuote] = []
    @Published private(set) var lateCheckInCandidates: [UIHabit] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let habitsRepository: HabitsRepository
    private let completionsRepository: CompletionsRepository
    private let quotesRepository: QuotesRepository
    private let logger: AnalyticsLogging
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let now: () -> Date

    private var localeCode: String
    private var domainHabitsByID: [UUID: Habit] = [:]
    private var allDomainHabitsByID: [UUID: Habit] = [:]
    private var completionHistoryByHabitID: [UUID: [HabitCompletion]] = [:]
    private var inFlightLateCheckInHabitIDs: Set<UUID> = []
    private var currentQuote: Quote?

    init(
        habitsRepository: HabitsRepository,
        completionsRepository: CompletionsRepository,
        quotesRepository: QuotesRepository,
        logger: AnalyticsLogging,
        localeCode: String,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.habitsRepository = habitsRepository
        self.completionsRepository = completionsRepository
        self.quotesRepository = quotesRepository
        self.logger = logger
        self.localeCode = localeCode
        self.calendar = calendar
        self.timeZone = timeZone
        self.now = now
    }

    func updateLocale(_ localeCode: String) {
        self.localeCode = localeCode
    }

    func loadToday(preloadedHistories: [UUID: [HabitCompletion]]? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let today = now()
            let allHabits = Self.deduplicatedHabits(
                try await habitsRepository.fetchHabits(includeArchived: false)
            )
            let habits = Self.deduplicatedHabits(
                try await habitsRepository.fetchDueHabits(on: today, calendar: calendar, timeZone: timeZone)
            )
            let completions = Self.deduplicatedCompletions(
                try await completionsRepository.fetchCompletions(on: today, calendar: calendar, timeZone: timeZone)
            )
            let completionByHabitID = completions.reduce(into: [UUID: HabitCompletion]()) { partialResult, completion in
                partialResult[completion.habitID] = completion
            }

            domainHabitsByID = habits.reduce(into: [UUID: Habit]()) { partialResult, habit in
                partialResult[habit.id] = habit
            }
            allDomainHabitsByID = allHabits.reduce(into: [UUID: Habit]()) { partialResult, habit in
                partialResult[habit.id] = habit
            }

            var uiHabits: [UIHabit] = []
            uiHabits.reserveCapacity(habits.count)
            var historyByHabitID: [UUID: [HabitCompletion]] = [:]

            for habit in habits {
                let completion = completionByHabitID[habit.id] ?? HabitCompletion(habitID: habit.id, dayDate: today, value: 0)
                let history: [HabitCompletion]
                if let preloaded = preloadedHistories?[habit.id] {
                    history = preloaded
                } else {
                    history = try await completionsRepository.fetchCompletions(for: habit.id)
                }
                historyByHabitID[habit.id] = history
                let streak = StreakCalculator.streak(
                    for: habit,
                    completions: history,
                    context: DayContext(now: today, calendar: calendar, timeZone: timeZone)
                )

                let uiHabit = habit.asUIHabit(
                    completedToday: completion.isCompleted(for: habit),
                    streak: streak,
                    completionValue: completion.value,
                    calendar: calendar,
                    timeZone: timeZone
                )
                uiHabits.append(uiHabit)
            }

            self.habits = uiHabits
            completionHistoryByHabitID = historyByHabitID
            lateCheckInCandidates = try await resolveLateCheckInCandidates(
                from: allHabits,
                asOf: today,
                preloadedHistories: preloadedHistories
            )

            if let quote = try await quotesRepository.fetchQuoteOfDay(
                locale: localeCode,
                on: today,
                calendar: calendar,
                timeZone: timeZone
            ) {
                currentQuote = quote
                self.quote = quote.asUIQuote()
            }

            let saved = try await quotesRepository.fetchSavedQuotes()
            savedQuotes = saved.map { $0.asUISavedQuote() }

            logger.log(.todayLoaded, metadata: ["habits_count": "\(self.habits.count)"])
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "today_load", "error": error.localizedDescription])
        }

        isLoading = false
    }

    func recordLateCheckIn(for habitID: UUID) async -> LateCheckInResult {
        let context = DayContext(now: now(), calendar: calendar, timeZone: timeZone)
        guard context.isWithinLateCheckInWindow else {
            lateCheckInCandidates.removeAll()
            return .windowClosed
        }
        guard let habit = allDomainHabitsByID[habitID],
              habit.isDue(on: context.yesterday, calendar: calendar, timeZone: timeZone) else {
            lateCheckInCandidates.removeAll { $0.id == habitID }
            return .windowClosed
        }
        guard !inFlightLateCheckInHabitIDs.contains(habitID) else {
            return .recorded
        }
        guard let previousIndex = lateCheckInCandidates.firstIndex(where: { $0.id == habitID }) else {
            return .recorded
        }
        let candidate = lateCheckInCandidates[previousIndex]

        inFlightLateCheckInHabitIDs.insert(habitID)
        defer { inFlightLateCheckInHabitIDs.remove(habitID) }

        lateCheckInCandidates.remove(at: previousIndex)

        do {
            if let existing = try await completionsRepository.fetchCompletion(
                habitID: habitID,
                on: context.yesterday,
                calendar: calendar,
                timeZone: timeZone
            ), existing.isCompleted(for: habit) {
                return .recorded
            }

            let timestamp = now()
            let completion = HabitCompletion(
                habitID: habitID,
                dayDate: context.yesterday,
                value: habit.normalizedTargetCount,
                completedAt: timestamp,
                updatedAt: timestamp,
                entrySource: .lateCheckIn
            )
            try await completionsRepository.upsertCompletion(
                completion,
                calendar: calendar,
                timeZone: timeZone
            )
            completionHistoryByHabitID[habitID] = updatedHistory(for: habitID, completion: completion)
            refreshTodayStreakAfterLateCheckIn(for: habit)
            logger.log(.habitToggled, metadata: [
                "habit_id": habitID.uuidString,
                "value": "\(habit.normalizedTargetCount)",
                "source": "late_check_in"
            ])
            return .recorded
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: [
                "scope": "late_check_in",
                "error": error.localizedDescription
            ])
            let rollbackIndex = min(previousIndex, lateCheckInCandidates.count)
            lateCheckInCandidates.insert(candidate, at: rollbackIndex)
            return .storageFailure
        }
    }

    func clearStaleLateCheckInCandidates() {
        let context = DayContext(now: now(), calendar: calendar, timeZone: timeZone)
        guard !context.isWithinLateCheckInWindow else { return }
        lateCheckInCandidates.removeAll()
    }

    private func refreshTodayStreakAfterLateCheckIn(for habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let today = now()
        habits[index].streak = StreakCalculator.streak(
            for: habit,
            completions: completionHistoryByHabitID[habit.id] ?? [],
            context: DayContext(now: today, calendar: calendar, timeZone: timeZone)
        )
    }

    private static func deduplicatedHabits(_ habits: [Habit]) -> [Habit] {
        var seen = Set<UUID>()
        var result: [Habit] = []
        result.reserveCapacity(habits.count)

        for habit in habits {
            guard seen.insert(habit.id).inserted else {
                continue
            }
            result.append(habit)
        }

        return result
    }

    private static func deduplicatedCompletions(_ completions: [HabitCompletion]) -> [HabitCompletion] {
        var seen = Set<UUID>()
        var result: [HabitCompletion] = []
        result.reserveCapacity(completions.count)

        for completion in completions {
            guard seen.insert(completion.habitID).inserted else {
                continue
            }
            result.append(completion)
        }

        return result
    }

    func beginHabitToggle(_ habitID: UUID) -> HabitToggleTransaction? {
        guard let habit = domainHabitsByID[habitID] else {
            return nil
        }
        guard let index = habits.firstIndex(where: { $0.id == habitID }) else {
            return nil
        }

        let currentValue: Int
        if habit.type == .binary {
            currentValue = habits[index].completedToday ? 1 : 0
        } else {
            currentValue = habits[index].dhikrCount
        }

        let nextValue: Int
        switch habit.type {
        case .binary:
            nextValue = currentValue == 1 ? 0 : 1
        case .dhikr:
            nextValue = currentValue >= habit.normalizedTargetCount ? 0 : habit.normalizedTargetCount
        }

        var updatedHabit = habits[index]
        let today = now()
        let optimisticCompletion = HabitCompletion(
            habitID: habitID,
            dayDate: today,
            value: nextValue,
            completedAt: nextValue > 0 ? today : nil,
            updatedAt: today
        )
        let optimisticHistory = updatedHistory(for: habitID, completion: optimisticCompletion)
        let optimisticStreak = StreakCalculator.streak(
            for: habit,
            completions: optimisticHistory,
            context: DayContext(now: today, calendar: calendar, timeZone: timeZone)
        )
        if habit.type == .binary {
            updatedHabit.completedToday = nextValue > 0
        } else {
            updatedHabit.dhikrCount = nextValue
            updatedHabit.completedToday = nextValue >= habit.normalizedTargetCount
        }
        updatedHabit.streak = optimisticStreak
        habits[index] = updatedHabit

        return HabitToggleTransaction(
            habitID: habitID,
            previousValue: currentValue,
            nextValue: nextValue,
            type: habit.type.rawValue,
            status: nextValue > 0 ? "completed" : "uncompleted"
        )
    }

    func commitHabitToggle(_ transaction: HabitToggleTransaction) async -> Bool {
        guard domainHabitsByID[transaction.habitID] != nil else {
            return false
        }
        do {
            let today = now()
            let completion = HabitCompletion(
                habitID: transaction.habitID,
                dayDate: today,
                value: transaction.nextValue,
                completedAt: transaction.nextValue > 0 ? today : nil,
                updatedAt: today
            )

            try await completionsRepository.upsertCompletion(completion, calendar: calendar, timeZone: timeZone)
            completionHistoryByHabitID[transaction.habitID] = updatedHistory(for: transaction.habitID, completion: completion)
            logger.log(.habitToggled, metadata: ["habit_id": transaction.habitID.uuidString, "value": "\(transaction.nextValue)"])
            return true
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "today_toggle", "error": error.localizedDescription])
            return false
        }
    }

    func rollbackHabitToggle(_ transaction: HabitToggleTransaction) {
        guard let habit = domainHabitsByID[transaction.habitID] else {
            return
        }
        guard let index = habits.firstIndex(where: { $0.id == transaction.habitID }) else {
            return
        }

        var restoredHabit = habits[index]
        if habit.type == .binary {
            restoredHabit.completedToday = transaction.previousValue > 0
        } else {
            restoredHabit.dhikrCount = transaction.previousValue
            restoredHabit.completedToday = transaction.previousValue >= habit.normalizedTargetCount
        }
        let today = now()
        let restoredCompletion = HabitCompletion(
            habitID: transaction.habitID,
            dayDate: today,
            value: transaction.previousValue,
            completedAt: transaction.previousValue > 0 ? today : nil,
            updatedAt: today
        )
        restoredHabit.streak = StreakCalculator.streak(
            for: habit,
            completions: updatedHistory(for: transaction.habitID, completion: restoredCompletion),
            context: DayContext(now: today, calendar: calendar, timeZone: timeZone)
        )
        habits[index] = restoredHabit
    }

    func saveCurrentQuote() async -> Bool {
        do {
            let quoteToSave: Quote
            if let currentQuote {
                quoteToSave = currentQuote
            } else {
                quoteToSave = Quote(locale: localeCode, text: quote.text, source: quote.author, sortOrder: 0, active: true)
            }

            try await quotesRepository.saveQuote(quoteToSave, savedAt: now())
            let saved = try await quotesRepository.fetchSavedQuotes()
            savedQuotes = saved.map { $0.asUISavedQuote() }
            return true
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "save_quote", "error": error.localizedDescription])
            return false
        }
    }

    private func updatedHistory(for habitID: UUID, completion: HabitCompletion) -> [HabitCompletion] {
        var normalizedCalendar = calendar
        normalizedCalendar.timeZone = timeZone
        let targetDay = normalizedCalendar.startOfDay(for: completion.dayDate)
        let prior = completionHistoryByHabitID[habitID, default: []].filter {
            normalizedCalendar.startOfDay(for: $0.dayDate) != targetDay
        }
        return (prior + [completion]).sorted { $0.dayDate < $1.dayDate }
    }

    private func resolveLateCheckInCandidates(
        from habits: [Habit],
        asOf now: Date,
        preloadedHistories: [UUID: [HabitCompletion]]?
    ) async throws -> [UIHabit] {
        let context = DayContext(now: now, calendar: calendar, timeZone: timeZone)
        guard context.isWithinLateCheckInWindow else { return [] }

        let dueHabits = habits.filter {
            $0.isDue(on: context.yesterday, calendar: calendar, timeZone: timeZone)
        }
        let completionsRepository = self.completionsRepository
        let preloaded = preloadedHistories

        var historiesByHabitID: [UUID: Result<[HabitCompletion], Error>] = [:]
        historiesByHabitID.reserveCapacity(dueHabits.count)

        await withTaskGroup(of: (UUID, Result<[HabitCompletion], Error>).self) { group in
            var nextIndex = 0
            let maxConcurrent = min(8, dueHabits.count)

            func enqueueNext() {
                guard nextIndex < dueHabits.count else { return }
                let habit = dueHabits[nextIndex]
                nextIndex += 1
                group.addTask {
                    if let preloadedHistory = preloaded?[habit.id] {
                        return (habit.id, .success(preloadedHistory))
                    }
                    do {
                        let history = try await completionsRepository.fetchCompletions(for: habit.id)
                        return (habit.id, .success(history))
                    } catch {
                        return (habit.id, .failure(error))
                    }
                }
            }

            for _ in 0..<maxConcurrent {
                enqueueNext()
            }
            for await (habitID, history) in group {
                historiesByHabitID[habitID] = history
                enqueueNext()
            }
        }

        var candidates: [UIHabit] = []
        candidates.reserveCapacity(dueHabits.count)
        for habit in dueHabits {
            guard let historyResult = historiesByHabitID[habit.id] else { continue }
            let history = try historyResult.get()
            completionHistoryByHabitID[habit.id] = history
            let yesterdayCompletion = history.first {
                context.calendar.isDate($0.dayDate, inSameDayAs: context.yesterday)
            }
            guard yesterdayCompletion?.isCompleted(for: habit) != true else { continue }

            candidates.append(
                habit.asUIHabit(
                    completedToday: false,
                    streak: StreakCalculator.streak(for: habit, completions: history, context: context),
                    completionValue: 0,
                    calendar: calendar,
                    timeZone: timeZone
                )
            )
        }
        return candidates
    }
}
