import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var user: UIUserState = .guest
    @Published private(set) var habits: [UIHabit] = []
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

    init(
        habitsRepository: HabitsRepository,
        completionsRepository: CompletionsRepository,
        quotesRepository: QuotesRepository,
        logger: AnalyticsLogging,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.habitsRepository = habitsRepository
        self.completionsRepository = completionsRepository
        self.quotesRepository = quotesRepository
        self.logger = logger
        self.calendar = calendar
        self.timeZone = timeZone
        self.now = now
    }

    func updateUser(_ user: UIUserState) {
        self.user = user
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let today = now()
            let domainHabits = try await habitsRepository.fetchHabits(includeArchived: false)
            let todayCompletions = try await completionsRepository.fetchCompletions(
                on: today,
                calendar: calendar,
                timeZone: timeZone
            )
            let completionsByHabitID = Dictionary(uniqueKeysWithValues: todayCompletions.map { ($0.habitID, $0) })

            var mappedHabits: [UIHabit] = []
            mappedHabits.reserveCapacity(domainHabits.count)

            for habit in domainHabits {
                let completion = completionsByHabitID[habit.id] ?? HabitCompletion(habitID: habit.id, dayDate: today, value: 0)
                let history = try await completionsRepository.fetchCompletions(for: habit.id)
                let streak = StreakCalculator.streak(
                    for: habit,
                    completions: history,
                    asOf: today,
                    calendar: calendar,
                    timeZone: timeZone,
                    referenceDate: today
                )
                mappedHabits.append(
                    habit.asUIHabit(
                        completedToday: completion.isCompleted(for: habit),
                        streak: streak,
                        completionValue: completion.value,
                        calendar: calendar,
                        timeZone: timeZone
                    )
                )
            }

            habits = mappedHabits
            let saved = try await quotesRepository.fetchSavedQuotes()
            savedQuotes = saved.map { $0.asUISavedQuote() }
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "profile_load", "error": error.localizedDescription])
        }
    }
}
