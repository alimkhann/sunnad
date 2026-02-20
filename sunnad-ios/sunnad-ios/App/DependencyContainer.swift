import Combine
import Foundation
import SwiftData
import Supabase

final class DependencyContainer {
    private enum CachedSupabaseKeys {
        static let url = "sunnad.cached.supabase.url"
        static let key = "sunnad.cached.supabase.key"
    }

    let environment: AppEnvironment
    let modelContainer: ModelContainer

    let analyticsLogger: AnalyticsLogging
    let habitsRepository: HabitsRepository
    let completionsRepository: CompletionsRepository
    let quotesRepository: QuotesRepository
    let groupsRepository: GroupsRepository
    let syncCoordinator: SyncCoordinating
    let reminderScheduler: LocalReminderScheduling
    let authService: AuthService
    let deviceTokenSyncService: DeviceTokenSyncing
    private let localQuotesRepository: QuotesLocalRepository
    private let userDefaults: UserDefaults

    init(
        environment: AppEnvironment = .current,
        modelContainer: ModelContainer? = nil,
        authService: AuthService? = nil,
        deviceTokenSyncService: DeviceTokenSyncing? = nil,
        syncCoordinator: SyncCoordinating? = nil
    ) {
        self.environment = environment
        self.userDefaults = .standard

        if let modelContainer {
            self.modelContainer = modelContainer
        } else {
            do {
                self.modelContainer = try ModelContainer(
                    for: HabitEntity.self,
                    CompletionEntity.self,
                    QuoteEntity.self,
                    SavedQuoteEntity.self,
                    DiagnosticEventEntity.self,
                    LocalOutboxEventEntity.self,
                    LocalSyncCursorEntity.self,
                    LocalGroupSyncEntity.self,
                    LocalGroupMemberSyncEntity.self,
                    LocalGroupSharedHabitSyncEntity.self
                )
            } catch {
                fatalError("Failed to initialize SwiftData container: \(error)")
            }
        }

        let modelContext = self.modelContainer.mainContext
        let diagnosticsStore: LocalDiagnosticsStore? = Self.isRunningUnitTests
            ? nil
            : LocalDiagnosticsStore(modelContext: modelContext)
        let logger = OSLogAnalyticsLogger(diagnosticsStore: diagnosticsStore)

        analyticsLogger = logger
        let localHabitsRepository = HabitsLocalRepository(modelContext: modelContext, logger: logger)
        let localCompletionsRepository = CompletionsLocalRepository(modelContext: modelContext, logger: logger)
        localQuotesRepository = QuotesLocalRepository(modelContext: modelContext, logger: logger)
        reminderScheduler = UserNotificationReminderScheduler(logger: logger)

        let resolvedSupabase = Self.resolvedSupabaseConfig(
            environment: environment,
            userDefaults: userDefaults
        )

        let supabaseClient: SupabaseClient?
        if let config = resolvedSupabase {
            supabaseClient = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        } else {
            supabaseClient = nil
        }

        let resolvedGroupsRepository: GroupsRepository
        if let client = supabaseClient {
            resolvedGroupsRepository = SupabaseGroupsRepository(client: client, logger: logger)
        } else {
            resolvedGroupsRepository = GroupsLocalRepository()
        }

        if let syncCoordinator {
            self.syncCoordinator = syncCoordinator
        } else if let client = supabaseClient {
            self.syncCoordinator = SupabaseSyncCoordinator(
                client: client,
                modelContext: modelContext,
                logger: logger,
                userDefaults: userDefaults
            )
        } else {
            self.syncCoordinator = NoOpSyncCoordinator()
        }

        habitsRepository = SyncingHabitsRepository(
            base: localHabitsRepository,
            syncCoordinator: self.syncCoordinator
        )
        completionsRepository = SyncingCompletionsRepository(
            base: localCompletionsRepository,
            syncCoordinator: self.syncCoordinator
        )
        quotesRepository = SyncingQuotesRepository(
            base: localQuotesRepository,
            syncCoordinator: self.syncCoordinator
        )
        groupsRepository = SyncingGroupsRepository(
            base: resolvedGroupsRepository,
            syncCoordinator: self.syncCoordinator
        )

        if let authService {
            self.authService = authService
        } else if let config = resolvedSupabase, let client = supabaseClient {
            self.authService = SupabaseAuthService(
                client: client,
                supabaseURL: config.url,
                authRedirectURL: environment.authRedirectURL
            )
            #if DEBUG
            NSLog("Sunnad auth configured with Supabase URL: \(config.url.absoluteString)")
            #endif
        } else {
            self.authService = UnconfiguredAuthService()
            #if DEBUG
            NSLog("Sunnad auth is UNCONFIGURED. Set SUNNAD_SUPABASE_URL and SUNNAD_SUPABASE_PUBLISHABLE_KEY (or SUNNAD_SUPABASE_ANON_KEY).")
            #endif
        }

        if let deviceTokenSyncService {
            self.deviceTokenSyncService = deviceTokenSyncService
        } else if let client = supabaseClient {
            self.deviceTokenSyncService = SupabaseDeviceTokenSyncService(client: client, logger: logger)
        } else {
            self.deviceTokenSyncService = NoOpDeviceTokenSyncService()
        }

        seedLocalDataIfNeeded()
    }

    private static func resolvedSupabaseConfig(
        environment: AppEnvironment,
        userDefaults: UserDefaults
    ) -> AppEnvironment.SupabaseConfig? {
        if let config = environment.supabaseConfig {
            userDefaults.set(config.url.absoluteString, forKey: CachedSupabaseKeys.url)
            userDefaults.set(config.anonKey, forKey: CachedSupabaseKeys.key)
            return config
        }

        guard shouldUseCachedSupabaseConfig else {
            #if DEBUG
            if
                let cachedURL = userDefaults.string(forKey: CachedSupabaseKeys.url),
                !cachedURL.isEmpty
            {
                NSLog("Sunnad auth ignored cached Supabase config because SUNNAD_ALLOW_CACHED_SUPABASE_CONFIG is not enabled.")
            }
            #endif
            return nil
        }

        if
            let urlString = userDefaults.string(forKey: CachedSupabaseKeys.url),
            let key = userDefaults.string(forKey: CachedSupabaseKeys.key),
            let url = URL(string: urlString),
            !key.isEmpty
        {
            #if DEBUG
            NSLog("Sunnad auth configured from cached Supabase config: \(url.absoluteString)")
            #endif
            return .init(url: url, anonKey: key)
        }

        return nil
    }

    private static var shouldUseCachedSupabaseConfig: Bool {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["SUNNAD_ALLOW_CACHED_SUPABASE_CONFIG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return raw == "1" || raw == "true" || raw == "yes"
        #else
        return false
        #endif
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
                            selectedDhikrKey: habit.selectedDhikrKey,
                            dhikrCountsJSON: {
                                guard let data = try? JSONEncoder().encode(habit.dhikrCountsByKey),
                                      let string = String(data: data, encoding: .utf8) else {
                                    return "{}"
                                }
                                return string
                            }(),
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
                try localQuotesRepository.upsertQuotes(Self.seedQuotes)
            }
        } catch {
            analyticsLogger.log(.storageFailure, metadata: ["scope": "seed", "error": error.localizedDescription])
        }
    }

    func syncHabitReminders(enabled: Bool) {
        Task { @MainActor in
            do {
                let habits = try await habitsRepository.fetchHabits(includeArchived: false)
                let today = Date()
                let completions = try await completionsRepository.fetchCompletions(
                    on: today,
                    calendar: .current,
                    timeZone: .current
                )
                let habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
                let completedHabitIDs: Set<UUID> = Set(
                    completions.compactMap { completion in
                        guard let habit = habitsByID[completion.habitID], completion.isCompleted(for: habit) else {
                            return nil
                        }
                        return completion.habitID
                    }
                )

                await reminderScheduler.syncReminders(
                    for: habits,
                    enabled: enabled,
                    excludingHabitIDs: completedHabitIDs
                )
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

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
