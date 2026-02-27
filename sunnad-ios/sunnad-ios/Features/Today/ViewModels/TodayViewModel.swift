import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    struct HabitToggleResult {
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

    func loadToday() async {
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

            for habit in habits {
                let completion = completionByHabitID[habit.id] ?? HabitCompletion(habitID: habit.id, dayDate: today, value: 0)
                let history = try await completionsRepository.fetchCompletions(for: habit.id)
                let streak = StreakCalculator.streak(
                    for: habit,
                    completions: history,
                    asOf: today,
                    calendar: calendar,
                    timeZone: timeZone
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

    func toggleHabit(_ habitID: UUID) async -> HabitToggleResult? {
        guard let habit = domainHabitsByID[habitID] else {
            return nil
        }

        do {
            let today = now()
            let existing = try await completionsRepository.fetchCompletion(
                habitID: habitID,
                on: today,
                calendar: calendar,
                timeZone: timeZone
            )

            let currentValue = existing?.value ?? 0
            let nextValue: Int

            switch habit.type {
            case .binary:
                nextValue = currentValue == 1 ? 0 : 1
            case .dhikr:
                nextValue = currentValue >= habit.normalizedTargetCount ? 0 : habit.normalizedTargetCount
            }

            let completion = HabitCompletion(
                habitID: habitID,
                dayDate: today,
                value: nextValue,
                completedAt: nextValue > 0 ? today : nil,
                updatedAt: today
            )

            try await completionsRepository.upsertCompletion(completion, calendar: calendar, timeZone: timeZone)
            logger.log(.habitToggled, metadata: ["habit_id": habitID.uuidString, "value": "\(nextValue)"])

            await loadToday()
            return HabitToggleResult(
                type: habit.type.rawValue,
                status: nextValue > 0 ? "completed" : "uncompleted"
            )
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "today_toggle", "error": error.localizedDescription])
            return nil
        }
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
}
