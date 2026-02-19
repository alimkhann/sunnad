import Combine
import Foundation
import SwiftData

final class DependencyContainer {
    let environment: AppEnvironment
    let modelContainer: ModelContainer

    let analyticsLogger: AnalyticsLogging
    let habitsRepository: HabitsLocalRepository
    let completionsRepository: CompletionsLocalRepository
    let quotesRepository: QuotesLocalRepository
    let reminderScheduler: LocalReminderScheduling

    init(environment: AppEnvironment = .current) {
        self.environment = environment

        do {
            modelContainer = try ModelContainer(
                for: HabitEntity.self,
                CompletionEntity.self,
                QuoteEntity.self,
                SavedQuoteEntity.self,
                DiagnosticEventEntity.self
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }

        let modelContext = modelContainer.mainContext
        let diagnosticsStore = LocalDiagnosticsStore(modelContext: modelContext)
        let logger = OSLogAnalyticsLogger(diagnosticsStore: diagnosticsStore)

        analyticsLogger = logger
        habitsRepository = HabitsLocalRepository(modelContext: modelContext, logger: logger)
        completionsRepository = CompletionsLocalRepository(modelContext: modelContext, logger: logger)
        quotesRepository = QuotesLocalRepository(modelContext: modelContext, logger: logger)
        reminderScheduler = UserNotificationReminderScheduler(logger: logger)

        seedLocalDataIfNeeded()
    }

    func seedLocalDataIfNeeded() {
        do {
            let modelContext = modelContainer.mainContext
            let existingHabits = try modelContext.fetch(FetchDescriptor<HabitEntity>())
            if existingHabits.isEmpty {
                let seeded = UIFixtures.initialHabits.enumerated().map { index, item in
                    var habit = item.asDomainHabit()
                    habit.sortOrder = index
                    return habit
                }

                for habit in seeded {
                    modelContext.insert(
                        HabitEntity(
                            id: habit.id,
                            name: habit.name,
                            icon: habit.icon,
                            categoryRaw: habit.category.rawValue,
                            typeRaw: habit.type.rawValue,
                            targetCount: habit.targetCount,
                            scheduleFrequency: {
                                switch habit.schedule {
                                case .daily: return "daily"
                                case .weekly: return "weekly"
                                }
                            }(),
                            weekdaysISO: {
                                switch habit.schedule {
                                case .daily:
                                    return ""
                                case .weekly(let weekdays):
                                    return weekdays
                                        .map(\.rawValue)
                                        .sorted()
                                        .map(String.init)
                                        .joined(separator: ",")
                                }
                            }(),
                            reminderHour: habit.reminder?.hour,
                            reminderMinute: habit.reminder?.minute,
                            sortOrder: habit.sortOrder,
                            archived: habit.archived,
                            createdAt: habit.createdAt,
                            updatedAt: habit.updatedAt
                        )
                    )
                }

                try modelContext.save()
            }

            let existingQuotes = try modelContext.fetch(FetchDescriptor<QuoteEntity>())
            if existingQuotes.isEmpty {
                try quotesRepository.upsertQuotes(Self.seedQuotes)
            }
        } catch {
            analyticsLogger.log(.storageFailure, metadata: ["scope": "seed", "error": error.localizedDescription])
        }
    }

    func syncHabitReminders(enabled: Bool) {
        Task { @MainActor in
            do {
                let habits = try await habitsRepository.fetchHabits(includeArchived: false)
                await reminderScheduler.syncReminders(for: habits, enabled: enabled)
            } catch {
                analyticsLogger.log(.storageFailure, metadata: ["scope": "reminder_sync", "error": error.localizedDescription])
            }
        }
    }

    func requestLocalNotificationPermission() {
        Task {
            _ = await reminderScheduler.requestAuthorizationIfNeeded()
        }
    }

    private static var seedQuotes: [Quote] {
        [
            Quote(locale: "en", text: "The best of deeds are those done consistently, even if small.", source: "Prophet Muhammad ﷺ (Bukhari & Muslim)", sortOrder: 0, active: true),
            Quote(locale: "en", text: "Verily, with hardship comes ease.", source: "Quran 94:6", sortOrder: 1, active: true),
            Quote(locale: "ru", text: "Лучшие из дел - те, что совершаются постоянно, даже если они малы.", source: "Пророк Мухаммад ﷺ (Бухари и Муслим)", sortOrder: 0, active: true),
            Quote(locale: "ru", text: "Поистине, за тягостью - облегчение.", source: "Коран 94:6", sortOrder: 1, active: true),
            Quote(locale: "kk", text: "Ең жақсы амалдар - аз болса да, тұрақты жасалатындар.", source: "Мұхаммад Пайғамбар ﷺ (Бұхари және Мүслім)", sortOrder: 0, active: true),
            Quote(locale: "kk", text: "Қиыншылықпен бірге жеңілдік бар.", source: "Құран 94:6", sortOrder: 1, active: true)
        ]
    }
}
