import Foundation
import SwiftData

@MainActor
final class HabitsLocalRepository: HabitsRepository {
    private let modelContext: ModelContext
    private let logger: AnalyticsLogging

    init(modelContext: ModelContext, logger: AnalyticsLogging) {
        self.modelContext = modelContext
        self.logger = logger
    }

    func fetchHabits(includeArchived: Bool) async throws -> [Habit] {
        let descriptor = FetchDescriptor<HabitEntity>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )

        let entities = try modelContext.fetch(descriptor)

        if includeArchived {
            return entities.map { $0.asDomainHabit() }
        }

        return entities
            .map { $0.asDomainHabit() }
            .filter { !$0.archived }
    }

    func fetchDueHabits(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [Habit] {
        let habits = try await fetchHabits(includeArchived: false)
        return habits.filter { $0.isDue(on: day, calendar: calendar, timeZone: timeZone) }
    }

    func saveHabit(_ habit: Habit) async throws {
        let descriptor = FetchDescriptor<HabitEntity>(
            predicate: #Predicate { $0.id == habit.id }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(habit)
            logger.log(.habitUpdated, metadata: ["habit_id": habit.id.uuidString])
        } else {
            let entity = HabitEntity(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                categoryRaw: habit.category.rawValue,
                typeRaw: habit.type.rawValue,
                targetCount: habit.targetCount,
                scheduleFrequency: scheduleFrequency(for: habit.schedule),
                weekdaysISO: weekdayCSV(for: habit.schedule),
                reminderHour: habit.reminder?.hour,
                reminderMinute: habit.reminder?.minute,
                sortOrder: habit.sortOrder,
                archived: habit.archived,
                createdAt: habit.createdAt,
                updatedAt: habit.updatedAt
            )
            modelContext.insert(entity)
            logger.log(.habitCreated, metadata: ["habit_id": habit.id.uuidString])
        }

        try modelContext.save()
    }

    func deleteHabit(id: UUID) async throws {
        let descriptor = FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try modelContext.fetch(descriptor).first else {
            return
        }

        modelContext.delete(entity)
        try modelContext.save()
        logger.log(.habitDeleted, metadata: ["habit_id": id.uuidString])
    }

    private func scheduleFrequency(for schedule: HabitSchedule) -> String {
        switch schedule {
        case .daily:
            return "daily"
        case .weekly:
            return "weekly"
        }
    }

    private func weekdayCSV(for schedule: HabitSchedule) -> String {
        switch schedule {
        case .daily:
            return ""
        case .weekly(let weekdays):
            return weekdays
                .map(\.rawValue)
                .sorted()
                .map(String.init)
                .joined(separator: ",")
        }
    }
}

