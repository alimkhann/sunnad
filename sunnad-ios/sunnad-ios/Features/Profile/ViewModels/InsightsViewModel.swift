import Combine
import Foundation

struct InsightPoint: Identifiable, Equatable {
    let date: Date
    let completed: Double
    let due: Double
    let missedHabitIDs: [UUID]

    var id: Date { date }
}

struct HabitDayState: Identifiable, Equatable {
    let date: Date
    let scheduled: Bool
    let completed: Bool

    var id: Date { date }
}

struct HabitPerformance: Identifiable, Equatable {
    let id: UUID
    let title: String
    let percentage: Int
    let days: [HabitDayState]
}

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var points: [InsightPoint] = []
    @Published private(set) var habitPerformance: [HabitPerformance] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let habitsRepository: HabitsRepository
    private let completionsRepository: CompletionsRepository
    private let logger: AnalyticsLogging
    private let calendar: Calendar
    private let timeZone: TimeZone
    private let now: () -> Date
    private let totalDays = 40

    private var habitsByID: [UUID: Habit] = [:]
    private var habitTitleByID: [UUID: String] = [:]
    private var completionByHabitAndDay: [UUID: [Date: HabitCompletion]] = [:]

    init(
        habitsRepository: HabitsRepository,
        completionsRepository: CompletionsRepository,
        logger: AnalyticsLogging,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.habitsRepository = habitsRepository
        self.completionsRepository = completionsRepository
        self.logger = logger
        self.calendar = calendar
        self.timeZone = timeZone
        self.now = now
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let today = now()
            let habits = try await habitsRepository.fetchHabits(includeArchived: false)
            habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
            habitTitleByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0.name) })

            var completionLookup: [UUID: [Date: HabitCompletion]] = [:]
            var performances: [HabitPerformance] = []

            let days = timelineDays(asOf: today)
            let daySet = Set(days.map { startOfDay(for: $0) })

            for habit in habits {
                let history = try await completionsRepository.fetchCompletions(for: habit.id)
                let byDay = Dictionary(uniqueKeysWithValues: history.map { (startOfDay(for: $0.dayDate), $0) })
                completionLookup[habit.id] = byDay

                let dayStates = days.map { day in
                    let scheduled = habit.isDue(on: day, calendar: calendar, timeZone: timeZone)
                    let completion = byDay[startOfDay(for: day)]
                    let completed = scheduled && completion?.isCompleted(for: habit) == true
                    return HabitDayState(date: day, scheduled: scheduled, completed: completed)
                }

                let scheduledCount = dayStates.filter(\.scheduled).count
                let completedCount = dayStates.filter(\.completed).count
                let percentage = scheduledCount == 0 ? 0 : Int((Double(completedCount) / Double(scheduledCount) * 100).rounded())

                performances.append(
                    HabitPerformance(
                        id: habit.id,
                        title: habit.name,
                        percentage: percentage,
                        days: dayStates
                    )
                )
            }

            completionByHabitAndDay = completionLookup
            habitPerformance = performances.sorted { lhs, rhs in
                if lhs.percentage == rhs.percentage {
                    return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
                return lhs.percentage > rhs.percentage
            }

            points = days.map { day in
                let scheduledHabits = habits.filter { $0.isDue(on: day, calendar: calendar, timeZone: timeZone) }
                var completedCount = 0
                var missedHabitIDs: [UUID] = []

                for habit in scheduledHabits {
                    let completion = completionLookup[habit.id]?[startOfDay(for: day)]
                    if completion?.isCompleted(for: habit) == true {
                        completedCount += 1
                    } else {
                        missedHabitIDs.append(habit.id)
                    }
                }

                let dueCount = scheduledHabits.count
                let dueValue = max(dueCount, completedCount)

                return InsightPoint(
                    date: day,
                    completed: Double(completedCount),
                    due: Double(dueValue),
                    missedHabitIDs: missedHabitIDs
                )
            }

            // Keep only data inside the active 40-day window to reduce memory churn.
            completionByHabitAndDay = completionByHabitAndDay.mapValues { entries in
                entries.filter { daySet.contains($0.key) }
            }
        } catch {
            errorMessage = error.localizedDescription
            logger.log(.storageFailure, metadata: ["scope": "insights_load", "error": error.localizedDescription])
            points = []
            habitPerformance = []
        }
    }

    func missedHabitTitles(for point: InsightPoint) -> [String] {
        point.missedHabitIDs.compactMap { habitTitleByID[$0] }
    }

    private func timelineDays(asOf today: Date) -> [Date] {
        let todayStart = startOfDay(for: today)
        return (0..<totalDays).compactMap { index in
            calendar.date(byAdding: .day, value: -(totalDays - 1 - index), to: todayStart)
        }
    }

    private func startOfDay(for date: Date) -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }
}
