import Combine
import Foundation
import SwiftData
import Supabase

final class DependencyContainer {
    private enum CachedSupabaseKeys {
        static func url(namespace: String) -> String {
            "sunnad.cached.supabase.url.\(namespace)"
        }

        static func key(namespace: String) -> String {
            "sunnad.cached.supabase.key.\(namespace)"
        }
    }

    let environment: AppEnvironment
    let modelContainer: ModelContainer

    let analytics: AnalyticsClient
    let analyticsLogger: AnalyticsLogging
    let habitsRepository: HabitsRepository
    let completionsRepository: CompletionsRepository
    let quotesRepository: QuotesRepository
    let groupsRepository: GroupsRepository
    let syncCoordinator: SyncCoordinating
    let reminderScheduler: LocalReminderScheduling
    let interactionFeedback: InteractionFeedbackClient
    let authService: AuthService
    let deviceTokenSyncService: DeviceTokenSyncing
    let ownerScopeResolver: LocalOwnerScopeResolver
    private let localQuotesRepository: QuotesLocalRepository
    private let userDefaults: UserDefaults

    @MainActor
    init(
        environment: AppEnvironment? = nil,
        modelContainer: ModelContainer? = nil,
        analytics: AnalyticsClient? = nil,
        interactionFeedback: InteractionFeedbackClient? = nil,
        authService: AuthService? = nil,
        deviceTokenSyncService: DeviceTokenSyncing? = nil,
        syncCoordinator: SyncCoordinating? = nil
    ) {
        let resolvedEnvironment = environment ?? .current
        self.environment = resolvedEnvironment
        self.userDefaults = .standard
        self.ownerScopeResolver = LocalOwnerScopeResolver(
            namespace: resolvedEnvironment.storageNamespace,
            userDefaults: userDefaults
        )

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
        if let analytics {
            self.analytics = analytics
        } else if let posthogClient = PostHogAnalyticsClient(environment: resolvedEnvironment) {
            self.analytics = posthogClient
        } else {
            self.analytics = NoopAnalyticsClient()
        }
        let localHabitsRepository = HabitsLocalRepository(
            modelContext: modelContext,
            logger: logger,
            ownerScopeProvider: ownerScopeResolver
        )
        let localCompletionsRepository = CompletionsLocalRepository(
            modelContext: modelContext,
            logger: logger,
            ownerScopeProvider: ownerScopeResolver
        )
        localQuotesRepository = QuotesLocalRepository(
            modelContext: modelContext,
            logger: logger,
            ownerScopeProvider: ownerScopeResolver
        )
        reminderScheduler = UserNotificationReminderScheduler(logger: logger)
        self.interactionFeedback = interactionFeedback ?? SystemInteractionFeedbackClient()

        let resolvedSupabase = Self.resolvedSupabaseConfig(
            environment: resolvedEnvironment,
            userDefaults: userDefaults,
            cacheNamespace: resolvedEnvironment.storageNamespace
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
                analytics: self.analytics,
                userDefaults: userDefaults,
                ownerScopeProvider: ownerScopeResolver
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
                authRedirectURL: resolvedEnvironment.authRedirectURL
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
        userDefaults: UserDefaults,
        cacheNamespace: String
    ) -> AppEnvironment.SupabaseConfig? {
        if let config = environment.supabaseConfig {
            userDefaults.set(config.url.absoluteString, forKey: CachedSupabaseKeys.url(namespace: cacheNamespace))
            userDefaults.set(config.anonKey, forKey: CachedSupabaseKeys.key(namespace: cacheNamespace))
            return config
        }

        guard shouldUseCachedSupabaseConfig else {
            #if DEBUG
            if
                let cachedURL = userDefaults.string(forKey: CachedSupabaseKeys.url(namespace: cacheNamespace)),
                !cachedURL.isEmpty
            {
                NSLog("Sunnad auth ignored cached Supabase config because SUNNAD_ALLOW_CACHED_SUPABASE_CONFIG is not enabled.")
            }
            #endif
            return nil
        }

        if
            let urlString = userDefaults.string(forKey: CachedSupabaseKeys.url(namespace: cacheNamespace)),
            let key = userDefaults.string(forKey: CachedSupabaseKeys.key(namespace: cacheNamespace)),
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
            .lowercased(),
              !raw.isEmpty else {
            return false
        }
        return raw == "1" || raw == "true" || raw == "yes"
        #else
        return false
        #endif
    }

    @MainActor
    func seedLocalDataIfNeeded() {
        do {
            let modelContext = modelContainer.mainContext
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

    func syncQuoteReminders(enabled: Bool, locale: String) {
        Task { @MainActor in
            guard enabled else {
                await reminderScheduler.syncQuoteReminders(enabled: false, plans: [])
                return
            }

            do {
                let calendar = Calendar.current
                let timeZone = TimeZone.current
                let startOfDay = calendar.startOfDay(for: Date())
                let dayFormatter = Self.quoteDayFormatter(calendar: calendar, timeZone: timeZone)
                var plans: [QuoteReminderPlan] = []
                plans.reserveCapacity(7)

                for offset in 0 ..< 7 {
                    guard let day = calendar.date(byAdding: .day, value: offset, to: startOfDay) else {
                        continue
                    }

                    guard let quote = try await quotesRepository.fetchQuoteOfDay(
                        locale: locale,
                        on: day,
                        calendar: calendar,
                        timeZone: timeZone
                    ) else {
                        continue
                    }

                    let snippet = Self.quoteReminderSnippet(from: quote.text)
                    guard !snippet.isEmpty else {
                        continue
                    }

                    var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
                    dateComponents.hour = 9
                    dateComponents.minute = 0
                    dateComponents.timeZone = timeZone

                    plans.append(
                        QuoteReminderPlan(
                            identifier: "quote-reminder-\(dayFormatter.string(from: day))",
                            title: Self.quoteReminderTitle(from: quote.source),
                            body: snippet,
                            dateComponents: dateComponents
                        )
                    )
                }

                await reminderScheduler.syncQuoteReminders(enabled: true, plans: plans)
            } catch {
                analyticsLogger.log(
                    .storageFailure,
                    metadata: ["scope": "quote_reminder_sync", "error": error.localizedDescription]
                )
            }
        }
    }

    func requestLocalNotificationPermission() {
        Task {
            _ = await reminderScheduler.requestAuthorizationIfNeeded()
        }
    }

    @MainActor
    func clearLocalDataForCurrentScope() async throws {
        let scope = ownerScopeResolver.currentOwnerScopeRawValue
        let modelContext = modelContainer.mainContext

        let habits = try modelContext.fetch(
            FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.ownerScope == scope })
        )
        for habit in habits {
            await reminderScheduler.removeReminder(habitID: habit.id)
            modelContext.delete(habit)
        }

        let completions = try modelContext.fetch(
            FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.ownerScope == scope })
        )
        for completion in completions {
            modelContext.delete(completion)
        }

        let savedQuotes = try modelContext.fetch(
            FetchDescriptor<SavedQuoteEntity>(predicate: #Predicate { $0.ownerScope == scope })
        )
        for savedQuote in savedQuotes {
            modelContext.delete(savedQuote)
        }

        let outbox = try modelContext.fetch(
            FetchDescriptor<LocalOutboxEventEntity>(predicate: #Predicate { $0.ownerScope == scope })
        )
        for event in outbox {
            modelContext.delete(event)
        }

        let cursors = try modelContext.fetch(
            FetchDescriptor<LocalSyncCursorEntity>(predicate: #Predicate { $0.ownerScope == scope })
        )
        for cursor in cursors {
            modelContext.delete(cursor)
        }

        try modelContext.save()
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

    private static func quoteDayFormatter(calendar: Calendar, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func quoteReminderSnippet(from text: String, maxLength: Int = 110) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !normalized.isEmpty else {
            return ""
        }
        if normalized.count <= maxLength {
            return normalized
        }
        let endIndex = normalized.index(normalized.startIndex, offsetBy: maxLength)
        return String(normalized[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func quoteReminderTitle(from source: String?) -> String {
        let normalizedAuthor = source?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        if let normalizedAuthor, !normalizedAuthor.isEmpty {
            return "- \(normalizedAuthor)"
        }
        return L10n.t("notifications.quote_daily_fallback_title")
    }
}
