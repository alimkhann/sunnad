import Foundation
import SwiftData

@MainActor
final class CompletionsLocalRepository: CompletionsRepository {
    private let modelContext: ModelContext
    private let logger: AnalyticsLogging
    private let ownerScopeProvider: LocalOwnerScopeProviding

    init(
        modelContext: ModelContext,
        logger: AnalyticsLogging,
        ownerScopeProvider: LocalOwnerScopeProviding
    ) {
        self.modelContext = modelContext
        self.logger = logger
        self.ownerScopeProvider = ownerScopeProvider
    }

    func fetchCompletions(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [HabitCompletion] {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let normalizedDay = day.startOfDay(calendar: calendar, timeZone: timeZone)
        let descriptor = FetchDescriptor<CompletionEntity>(
            predicate: #Predicate { $0.dayDate == normalizedDay && $0.ownerScope == ownerScope }
        )
        return try modelContext.fetch(descriptor).map { $0.asDomainCompletion() }
    }

    func fetchCompletions(for habitID: UUID) async throws -> [HabitCompletion] {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<CompletionEntity>(
            predicate: #Predicate { $0.habitID == habitID && $0.ownerScope == ownerScope },
            sortBy: [SortDescriptor(\.dayDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.asDomainCompletion() }
    }

    func fetchCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> HabitCompletion? {
        let key = Self.key(
            habitID: habitID,
            day: day,
            ownerScope: ownerScopeProvider.currentOwnerScopeRawValue,
            calendar: calendar,
            timeZone: timeZone
        )
        let descriptor = FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.id == key })
        return try modelContext.fetch(descriptor).first?.asDomainCompletion()
    }

    func upsertCompletion(_ completion: HabitCompletion, calendar: Calendar, timeZone: TimeZone) async throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let normalizedDay = completion.dayDate.startOfDay(calendar: calendar, timeZone: timeZone)
        let key = Self.key(
            habitID: completion.habitID,
            day: normalizedDay,
            ownerScope: ownerScope,
            calendar: calendar,
            timeZone: timeZone
        )

        let descriptor = FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.id == key })

        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(
                HabitCompletion(
                    habitID: completion.habitID,
                    dayDate: normalizedDay,
                    value: completion.value,
                    completedAt: completion.completedAt,
                    updatedAt: completion.updatedAt
                ),
                key: key,
                ownerScope: ownerScope
            )
        } else {
            let entity = CompletionEntity(
                id: key,
                ownerScope: ownerScope,
                habitID: completion.habitID,
                dayDate: normalizedDay,
                value: completion.value,
                completedAt: completion.completedAt,
                updatedAt: completion.updatedAt
            )
            modelContext.insert(entity)
        }

        try modelContext.save()
        logger.log(.completionUpserted, metadata: ["habit_id": completion.habitID.uuidString])
    }

    func deleteCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws {
        let key = Self.key(
            habitID: habitID,
            day: day,
            ownerScope: ownerScopeProvider.currentOwnerScopeRawValue,
            calendar: calendar,
            timeZone: timeZone
        )
        let descriptor = FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.id == key })
        guard let entity = try modelContext.fetch(descriptor).first else {
            return
        }

        modelContext.delete(entity)
        try modelContext.save()
    }

    static func key(
        habitID: UUID,
        day: Date,
        ownerScope: String,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> String {
        let normalizedDay = day.startOfDay(calendar: calendar, timeZone: timeZone)

        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: normalizedDay)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0

        return "\(ownerScope)|\(habitID.uuidString.lowercased())-\(year)-\(month)-\(day)"
    }
}

private extension Date {
    func startOfDay(calendar: Calendar, timeZone: TimeZone) -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: self)
    }
}
