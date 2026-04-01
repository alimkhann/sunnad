import Combine
import Foundation

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
    private var completionHistoryByHabitID: [UUID: [HabitCompletion]] = [:]
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
            let habits = try await habitsRepository.fetchDueHabits(on: today, calendar: calendar, timeZone: timeZone)
            let completions = try await completionsRepository.fetchCompletions(on: today, calendar: calendar, timeZone: timeZone)
            let completionByHabitID = Dictionary(uniqueKeysWithValues: completions.map { ($0.habitID, $0) })

            domainHabitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })

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
                    asOf: today,
                    calendar: calendar,
                    timeZone: timeZone,
                    referenceDate: today
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
            asOf: today,
            calendar: calendar,
            timeZone: timeZone,
            referenceDate: today
        )
        if habit.type == .binary {
            updatedHabit.completedToday = nextValue > 0
        } else {
            updatedHabit.dhikrCount = nextValue
            updatedHabit.completedToday = nextValue >= habit.normalizedTargetCount
            updatedHabit.dhikrCountsByKey[updatedHabit.selectedDhikrKey] = nextValue
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
            restoredHabit.dhikrCountsByKey[restoredHabit.selectedDhikrKey] = transaction.previousValue
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
            asOf: today,
            calendar: calendar,
            timeZone: timeZone,
            referenceDate: today
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
}
