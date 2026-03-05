import Foundation
import SwiftData
import Supabase

enum SyncTrigger: String, Sendable {
    case auth
    case restore
    case foreground
    case background
    case manual
}

protocol SyncCoordinating: Sendable {
    func setSignedInUserID(_ userID: UUID?) async
    func promoteGuestDataIfNeeded(to userID: UUID) async
    func promoteLocalDataIfNeeded() async
    func runSyncCycle(trigger: SyncTrigger) async
    func enqueueHabitUpsert(habitID: UUID) async
    func enqueueHabitDelete(habitID: UUID) async
    func enqueueCompletionUpsert(habitID: UUID, dayDate: Date, calendar: Calendar, timeZone: TimeZone) async
    func enqueueSavedQuoteInsert(quoteID: UUID) async
    func enqueueSavedQuoteDelete(quoteID: UUID) async
    func enqueueGroupSharedHabitUpsert(groupID: UUID, habitID: UUID, shared: Bool) async
}

struct NoOpSyncCoordinator: SyncCoordinating {
    func setSignedInUserID(_ userID: UUID?) async {
        _ = userID
    }

    func promoteGuestDataIfNeeded(to userID: UUID) async {
        _ = userID
    }

    func promoteLocalDataIfNeeded() async {}
    func runSyncCycle(trigger: SyncTrigger) async {
        _ = trigger
    }

    func enqueueHabitUpsert(habitID: UUID) async {
        _ = habitID
    }

    func enqueueHabitDelete(habitID: UUID) async {
        _ = habitID
    }

    func enqueueCompletionUpsert(habitID: UUID, dayDate: Date, calendar: Calendar, timeZone: TimeZone) async {
        _ = (habitID, dayDate, calendar, timeZone)
    }

    func enqueueSavedQuoteInsert(quoteID: UUID) async {
        _ = quoteID
    }

    func enqueueSavedQuoteDelete(quoteID: UUID) async {
        _ = quoteID
    }

    func enqueueGroupSharedHabitUpsert(groupID: UUID, habitID: UUID, shared: Bool) async {
        _ = (groupID, habitID, shared)
    }
}

@MainActor
final class SupabaseSyncCoordinator: SyncCoordinating {
    private enum Keys {
        static let guestPromotionPrefix = "sunnad.sync.promoted.guest.v2."
        static let outboxPromotionPrefix = "sunnad.sync.promoted.outbox.v2."
    }

    private enum Resource: String, CaseIterable {
        case habits
        case completions
        case savedQuotes = "saved_quotes"
        case quotes
        case groups
        case groupMembers = "group_members"
        case groupSharedHabits = "group_shared_habits"
    }

    private enum EventType: String {
        case upsertHabit = "upsert_habit"
        case deleteHabit = "delete_habit"
        case upsertCompletion = "upsert_completion"
        case upsertGroupSharedHabit = "upsert_group_shared_habit"
        case insertSavedQuote = "insert_saved_quote"
        case deleteSavedQuote = "delete_saved_quote"
    }

    private struct HabitPayload: Codable {
        let habitID: UUID

        enum CodingKeys: String, CodingKey {
            case habitID = "habit_id"
        }
    }

    private struct CompletionPayload: Codable {
        let completionKey: String
        let habitID: UUID
        let dayDate: String

        enum CodingKeys: String, CodingKey {
            case completionKey = "completion_key"
            case habitID = "habit_id"
            case dayDate = "day_date"
        }
    }

    private struct SavedQuotePayload: Codable {
        let quoteID: UUID

        enum CodingKeys: String, CodingKey {
            case quoteID = "quote_id"
        }
    }

    private struct GroupSharedHabitPayload: Codable {
        let groupID: UUID
        let habitID: UUID
        let shared: Bool

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case habitID = "habit_id"
            case shared
        }
    }

    private struct HabitPushRow: Encodable {
        let id: UUID
        let userID: UUID
        let name: String
        let icon: String
        let iconKey: String?
        let presetCategory: String
        let categoryCustom: String?
        let type: String
        let targetCount: Int?
        let schedule: String
        let weekdays: [Int]
        let reminderEnabled: Bool
        let reminderTime: String?
        let sortOrder: Int
        let archived: Bool
        let createdAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case name
            case icon
            case iconKey = "icon_key"
            case presetCategory = "preset_category"
            case categoryCustom = "category_custom"
            case type
            case targetCount = "target_count"
            case schedule
            case weekdays
            case reminderEnabled = "reminder_enabled"
            case reminderTime = "reminder_time"
            case sortOrder = "sort_order"
            case archived
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct HabitPushLegacyRow: Encodable {
        let id: UUID
        let userID: UUID
        let name: String
        let icon: String
        let type: String
        let targetCount: Int?
        let schedule: String
        let weekdays: [Int]
        let reminderEnabled: Bool
        let reminderTime: String?
        let sortOrder: Int
        let archived: Bool
        let createdAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case name
            case icon
            case type
            case targetCount = "target_count"
            case schedule
            case weekdays
            case reminderEnabled = "reminder_enabled"
            case reminderTime = "reminder_time"
            case sortOrder = "sort_order"
            case archived
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct HabitPushNoIconKeyRow: Encodable {
        let id: UUID
        let userID: UUID
        let name: String
        let icon: String
        let presetCategory: String
        let categoryCustom: String?
        let type: String
        let targetCount: Int?
        let schedule: String
        let weekdays: [Int]
        let reminderEnabled: Bool
        let reminderTime: String?
        let sortOrder: Int
        let archived: Bool
        let createdAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case name
            case icon
            case presetCategory = "preset_category"
            case categoryCustom = "category_custom"
            case type
            case targetCount = "target_count"
            case schedule
            case weekdays
            case reminderEnabled = "reminder_enabled"
            case reminderTime = "reminder_time"
            case sortOrder = "sort_order"
            case archived
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct CompletionPushRow: Encodable {
        let userID: UUID
        let habitID: UUID
        let dayDate: String
        let value: Int
        let completedAt: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case habitID = "habit_id"
            case dayDate = "day_date"
            case value
            case completedAt = "completed_at"
            case updatedAt = "updated_at"
        }
    }

    private struct SavedQuotePushRow: Encodable {
        let userID: UUID
        let quoteID: UUID
        let savedAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case quoteID = "quote_id"
            case savedAt = "saved_at"
            case updatedAt = "updated_at"
        }
    }

    private struct GroupSharedHabitPushRow: Encodable {
        let groupID: UUID
        let userID: UUID
        let habitID: UUID
        let shared: Bool

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case userID = "user_id"
            case habitID = "habit_id"
            case shared
        }
    }

    private struct HabitPullRow: Decodable {
        let id: UUID
        let name: String
        let icon: String?
        let iconKey: String?
        let presetCategory: String?
        let categoryCustom: String?
        let type: String
        let targetCount: Int?
        let schedule: String
        let weekdays: [Int]?
        let reminderEnabled: Bool
        let reminderTime: String?
        let sortOrder: Int?
        let archived: Bool?
        let createdAt: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case icon
            case iconKey = "icon_key"
            case presetCategory = "preset_category"
            case categoryCustom = "category_custom"
            case type
            case targetCount = "target_count"
            case schedule
            case weekdays
            case reminderEnabled = "reminder_enabled"
            case reminderTime = "reminder_time"
            case sortOrder = "sort_order"
            case archived
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct HabitPullLegacyRow: Decodable {
        let id: UUID
        let name: String
        let icon: String?
        let type: String
        let targetCount: Int?
        let schedule: String
        let weekdays: [Int]?
        let reminderEnabled: Bool
        let reminderTime: String?
        let sortOrder: Int?
        let archived: Bool?
        let createdAt: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case icon
            case type
            case targetCount = "target_count"
            case schedule
            case weekdays
            case reminderEnabled = "reminder_enabled"
            case reminderTime = "reminder_time"
            case sortOrder = "sort_order"
            case archived
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }

        func asContractRow() -> HabitPullRow {
            HabitPullRow(
                id: id,
                name: name,
                icon: icon,
                iconKey: nil,
                presetCategory: nil,
                categoryCustom: nil,
                type: type,
                targetCount: targetCount,
                schedule: schedule,
                weekdays: weekdays,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
                sortOrder: sortOrder,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    private struct CompletionPullRow: Decodable {
        let habitID: UUID
        let dayDate: String
        let value: Int
        let completedAt: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case habitID = "habit_id"
            case dayDate = "day_date"
            case value
            case completedAt = "completed_at"
            case updatedAt = "updated_at"
        }
    }

    private struct SavedQuotePullRow: Decodable {
        let quoteID: UUID
        let savedAt: String
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case quoteID = "quote_id"
            case savedAt = "saved_at"
            case updatedAt = "updated_at"
        }
    }

    private struct QuotePullRow: Decodable {
        let id: UUID
        let locale: String
        let text: String
        let source: String?
        let sortOrder: Int?
        let active: Bool?
        let createdAt: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case locale
            case text
            case source
            case sortOrder = "sort_order"
            case active
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct GroupPullRow: Decodable {
        let id: UUID
        let ownerID: UUID
        let name: String
        let code: String
        let joinLocked: Bool?
        let createdAt: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case ownerID = "owner_id"
            case name
            case code
            case joinLocked = "join_locked"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct GroupMemberPullRow: Decodable {
        let groupID: UUID
        let userID: UUID
        let role: String?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case userID = "user_id"
            case role
            case updatedAt = "updated_at"
        }
    }

    private struct GroupSharedHabitPullRow: Decodable {
        let groupID: UUID
        let userID: UUID
        let habitID: UUID
        let shared: Bool?
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case userID = "user_id"
            case habitID = "habit_id"
            case shared
            case updatedAt = "updated_at"
        }
    }

    private let client: SupabaseClient
    private let modelContext: ModelContext
    private let logger: AnalyticsLogging
    private let analytics: AnalyticsClient
    private let userDefaults: UserDefaults
    private let ownerScopeProvider: LocalOwnerScopeProviding
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let outboxMaxAttempts = 5

    private var activeUserID: UUID?
    private var isRunningCycle = false

    init(
        client: SupabaseClient,
        modelContext: ModelContext,
        logger: AnalyticsLogging,
        analytics: AnalyticsClient,
        userDefaults: UserDefaults = .standard,
        ownerScopeProvider: LocalOwnerScopeProviding
    ) {
        self.client = client
        self.modelContext = modelContext
        self.logger = logger
        self.analytics = analytics
        self.userDefaults = userDefaults
        self.ownerScopeProvider = ownerScopeProvider
    }

    func setSignedInUserID(_ userID: UUID?) async {
        activeUserID = userID
        ownerScopeProvider.setSignedInUserID(userID)
    }

    func promoteGuestDataIfNeeded(to userID: UUID) async {
        let promotionKey = "\(Keys.guestPromotionPrefix)\(userID.uuidString.lowercased())"
        guard !userDefaults.bool(forKey: promotionKey) else { return }

        let guestScope = LocalOwnerScope.guest.rawValue
        let userScope = LocalOwnerScope.user(userID).rawValue

        do {
            let guestHabits = try modelContext.fetch(
                FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.ownerScope == guestScope })
            )
            let userHabits = try modelContext.fetch(
                FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.ownerScope == userScope })
            )
            var userHabitsByID = Dictionary(uniqueKeysWithValues: userHabits.map { ($0.id, $0) })
            for guestHabit in guestHabits {
                if let existing = userHabitsByID[guestHabit.id] {
                    guard guestHabit.updatedAt > existing.updatedAt else { continue }
                    existing.ownerScope = userScope
                    existing.name = guestHabit.name
                    existing.icon = guestHabit.icon
                    existing.iconKey = guestHabit.iconKey
                    existing.categoryRaw = guestHabit.categoryRaw
                    existing.categoryCustom = guestHabit.categoryCustom
                    existing.typeRaw = guestHabit.typeRaw
                    existing.targetCount = guestHabit.targetCount
                    existing.scheduleFrequency = guestHabit.scheduleFrequency
                    existing.weekdaysISO = guestHabit.weekdaysISO
                    existing.reminderHour = guestHabit.reminderHour
                    existing.reminderMinute = guestHabit.reminderMinute
                    existing.selectedDhikrKey = guestHabit.selectedDhikrKey
                    existing.dhikrCountsJSON = guestHabit.dhikrCountsJSON
                    existing.sortOrder = guestHabit.sortOrder
                    existing.archived = guestHabit.archived
                    existing.createdAt = min(existing.createdAt, guestHabit.createdAt)
                    existing.updatedAt = guestHabit.updatedAt
                    continue
                }

                let inserted = HabitEntity(
                    id: guestHabit.id,
                    ownerScope: userScope,
                    name: guestHabit.name,
                    icon: guestHabit.icon,
                    iconKey: guestHabit.iconKey,
                    categoryRaw: guestHabit.categoryRaw,
                    categoryCustom: guestHabit.categoryCustom,
                    typeRaw: guestHabit.typeRaw,
                    targetCount: guestHabit.targetCount,
                    scheduleFrequency: guestHabit.scheduleFrequency,
                    weekdaysISO: guestHabit.weekdaysISO,
                    reminderHour: guestHabit.reminderHour,
                    reminderMinute: guestHabit.reminderMinute,
                    selectedDhikrKey: guestHabit.selectedDhikrKey,
                    dhikrCountsJSON: guestHabit.dhikrCountsJSON,
                    sortOrder: guestHabit.sortOrder,
                    archived: guestHabit.archived,
                    createdAt: guestHabit.createdAt,
                    updatedAt: guestHabit.updatedAt
                )
                modelContext.insert(inserted)
                userHabitsByID[guestHabit.id] = inserted
            }

            let guestCompletions = try modelContext.fetch(
                FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.ownerScope == guestScope })
            )
            let userCompletions = try modelContext.fetch(
                FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.ownerScope == userScope })
            )
            var userCompletionsByID = Dictionary(uniqueKeysWithValues: userCompletions.map { ($0.id, $0) })
            for guestCompletion in guestCompletions {
                let userCompletionID = completionID(
                    from: guestCompletion.id,
                    sourceScope: guestScope,
                    targetScope: userScope
                )
                if let existing = userCompletionsByID[userCompletionID] {
                    guard guestCompletion.updatedAt > existing.updatedAt else { continue }
                    existing.ownerScope = userScope
                    existing.habitID = guestCompletion.habitID
                    existing.dayDate = guestCompletion.dayDate
                    existing.value = guestCompletion.value
                    existing.completedAt = guestCompletion.completedAt
                    existing.updatedAt = guestCompletion.updatedAt
                    continue
                }

                let inserted = CompletionEntity(
                    id: userCompletionID,
                    ownerScope: userScope,
                    habitID: guestCompletion.habitID,
                    dayDate: guestCompletion.dayDate,
                    value: guestCompletion.value,
                    completedAt: guestCompletion.completedAt,
                    updatedAt: guestCompletion.updatedAt
                )
                modelContext.insert(inserted)
                userCompletionsByID[userCompletionID] = inserted
            }

            let guestSavedQuotes = try modelContext.fetch(
                FetchDescriptor<SavedQuoteEntity>(predicate: #Predicate { $0.ownerScope == guestScope })
            )
            let userSavedQuotes = try modelContext.fetch(
                FetchDescriptor<SavedQuoteEntity>(predicate: #Predicate { $0.ownerScope == userScope })
            )
            var userSavedQuotesByKey = Dictionary(
                uniqueKeysWithValues: userSavedQuotes.map { (Self.savedQuoteMatchKey($0.quoteID), $0) }
            )
            for guestSavedQuote in guestSavedQuotes {
                let savedQuoteKey = Self.savedQuoteMatchKey(guestSavedQuote.quoteID)
                if let existing = userSavedQuotesByKey[savedQuoteKey] {
                    guard guestSavedQuote.savedAt > existing.savedAt else { continue }
                    existing.text = guestSavedQuote.text
                    existing.author = guestSavedQuote.author
                    existing.savedAt = guestSavedQuote.savedAt
                    continue
                }

                let inserted = SavedQuoteEntity(
                    id: UUID(),
                    ownerScope: userScope,
                    quoteID: guestSavedQuote.quoteID,
                    text: guestSavedQuote.text,
                    author: guestSavedQuote.author,
                    savedAt: guestSavedQuote.savedAt
                )
                modelContext.insert(inserted)
                userSavedQuotesByKey[savedQuoteKey] = inserted
            }

            try modelContext.save()
            userDefaults.set(true, forKey: promotionKey)
            logger.log(.syncFinished, metadata: ["scope": "sync_promote_guest_to_user", "status": "copied"])
        } catch {
            logger.log(
                .storageFailure,
                metadata: ["scope": "sync_promote_guest_to_user", "error": error.localizedDescription]
            )
        }
    }

    func promoteLocalDataIfNeeded() async {
        guard let activeUserID else { return }
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue

        let key = "\(Keys.outboxPromotionPrefix)\(activeUserID.uuidString.lowercased())"
        if userDefaults.bool(forKey: key) {
            return
        }

        do {
            let habits = try modelContext.fetch(
                FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.ownerScope == ownerScope })
            )
            for habit in habits {
                await enqueueHabitUpsert(habitID: habit.id)
            }

            let completions = try modelContext.fetch(
                FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.ownerScope == ownerScope })
            )
            for completion in completions {
                await enqueueCompletionUpsert(
                    habitID: completion.habitID,
                    dayDate: completion.dayDate,
                    calendar: .current,
                    timeZone: .current
                )
            }

            let savedQuotes = try modelContext.fetch(
                FetchDescriptor<SavedQuoteEntity>(predicate: #Predicate { $0.ownerScope == ownerScope })
            )
            for savedQuote in savedQuotes {
                guard let quoteID = savedQuote.quoteID else { continue }
                await enqueueSavedQuoteInsert(quoteID: quoteID)
            }

            userDefaults.set(true, forKey: key)
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "sync_promote_guest", "error": error.localizedDescription])
        }
    }

    func runSyncCycle(trigger: SyncTrigger) async {
        guard let activeUserID else { return }
        guard !isRunningCycle else { return }
        isRunningCycle = true
        let startedAt = Date()
        var pushedCount = 0
        var pulledCount = 0
        var status = "success"
        var stage: String?
        var errorCode: String?

        logger.log(.syncStarted, metadata: ["scope": "sync_cycle", "trigger": trigger.rawValue])

        defer {
            isRunningCycle = false
            logger.log(.syncFinished, metadata: ["scope": "sync_cycle", "trigger": trigger.rawValue])
        }

        do {
            pushedCount = try await pushOutbox(activeUserID: activeUserID)
            pulledCount = try await pullPersonalData(activeUserID: activeUserID)
        } catch {
            status = "failed"
            stage = "sync_cycle"
            errorCode = Self.syncErrorCode(from: error)
            logger.log(.storageFailure, metadata: ["scope": "sync_cycle", "error": error.localizedDescription])
        }

        let durationMs = max(Int(Date().timeIntervalSince(startedAt) * 1000), 0)
        analytics.trackSync(
            .result(
                trigger: trigger.rawValue,
                status: status,
                durationMs: durationMs,
                pulled: pulledCount,
                pushed: pushedCount,
                stage: stage,
                code: errorCode
            )
        )
    }

    func enqueueHabitUpsert(habitID: UUID) async {
        await enqueue(type: .upsertHabit, payload: HabitPayload(habitID: habitID))
    }

    func enqueueHabitDelete(habitID: UUID) async {
        await enqueue(type: .deleteHabit, payload: HabitPayload(habitID: habitID))
    }

    func enqueueCompletionUpsert(habitID: UUID, dayDate: Date, calendar: Calendar, timeZone: TimeZone) async {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let payload = CompletionPayload(
            completionKey: CompletionsLocalRepository.key(
                habitID: habitID,
                day: dayDate,
                ownerScope: ownerScope,
                calendar: calendar,
                timeZone: timeZone
            ),
            habitID: habitID,
            dayDate: Self.syncDayDateString(for: dayDate, calendar: calendar, timeZone: timeZone)
        )
        await enqueue(type: .upsertCompletion, payload: payload)
    }

    func enqueueSavedQuoteInsert(quoteID: UUID) async {
        await enqueue(type: .insertSavedQuote, payload: SavedQuotePayload(quoteID: quoteID))
    }

    func enqueueSavedQuoteDelete(quoteID: UUID) async {
        await enqueue(type: .deleteSavedQuote, payload: SavedQuotePayload(quoteID: quoteID))
    }

    func enqueueGroupSharedHabitUpsert(groupID: UUID, habitID: UUID, shared: Bool) async {
        await enqueue(
            type: .upsertGroupSharedHabit,
            payload: GroupSharedHabitPayload(groupID: groupID, habitID: habitID, shared: shared)
        )
    }

    private func enqueue<T: Encodable>(type: EventType, payload: T) async {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        do {
            let data = try encoder.encode(payload)
            guard let payloadJSON = String(data: data, encoding: .utf8) else {
                return
            }

            modelContext.insert(
                LocalOutboxEventEntity(
                    ownerScope: ownerScope,
                    type: type.rawValue,
                    payloadJSON: payloadJSON
                )
            )
            try modelContext.save()
        } catch {
            logger.log(
                .storageFailure,
                metadata: ["scope": "sync_enqueue_\(type.rawValue)", "error": error.localizedDescription]
            )
        }
    }

    private func pushOutbox(activeUserID: UUID) async throws -> Int {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<LocalOutboxEventEntity>(
            predicate: #Predicate { $0.ownerScope == ownerScope },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let events = try modelContext.fetch(descriptor)
        var pushedCount = 0

        for event in events {
            if event.attemptCount >= outboxMaxAttempts {
                continue
            }

            do {
                try await apply(event: event, activeUserID: activeUserID)
                modelContext.delete(event)
                try modelContext.save()
                pushedCount += 1
            } catch {
                event.attemptCount += 1
                event.lastError = error.localizedDescription
                try modelContext.save()
                let status = event.attemptCount >= outboxMaxAttempts ? "quarantined" : "retrying"
                logger.log(
                    .storageFailure,
                    metadata: [
                        "scope": "sync_outbox_apply",
                        "type": event.type,
                        "status": status,
                        "attempt_count": String(event.attemptCount),
                        "error": error.localizedDescription
                    ]
                )
            }
        }
        return pushedCount
    }

    private func apply(event: LocalOutboxEventEntity, activeUserID: UUID) async throws {
        guard let type = EventType(rawValue: event.type) else {
            return
        }

        switch type {
        case .upsertHabit:
            let payload = try decode(HabitPayload.self, from: event.payloadJSON)
            try await pushHabit(habitID: payload.habitID, activeUserID: activeUserID)
        case .deleteHabit:
            let payload = try decode(HabitPayload.self, from: event.payloadJSON)
            try await client
                .from("habits")
                .delete()
                .eq("id", value: payload.habitID)
                .eq("user_id", value: activeUserID)
                .execute()
        case .upsertCompletion:
            let payload = try decode(CompletionPayload.self, from: event.payloadJSON)
            try await pushCompletion(payload: payload, activeUserID: activeUserID)
        case .insertSavedQuote:
            let payload = try decode(SavedQuotePayload.self, from: event.payloadJSON)
            try await pushSavedQuoteInsert(payload: payload, activeUserID: activeUserID)
        case .deleteSavedQuote:
            let payload = try decode(SavedQuotePayload.self, from: event.payloadJSON)
            try await client
                .from("saved_quotes")
                .delete()
                .eq("user_id", value: activeUserID)
                .eq("quote_id", value: payload.quoteID)
                .execute()
        case .upsertGroupSharedHabit:
            let payload = try decode(GroupSharedHabitPayload.self, from: event.payloadJSON)
            let row = GroupSharedHabitPushRow(
                groupID: payload.groupID,
                userID: activeUserID,
                habitID: payload.habitID,
                shared: payload.shared
            )
            try await client
                .from("group_shared_habits")
                .upsert(row, onConflict: "group_id,user_id,habit_id")
                .execute()
        }
    }

    private func pushHabit(habitID: UUID, activeUserID: UUID) async throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<HabitEntity>(
            predicate: #Predicate { $0.id == habitID && $0.ownerScope == ownerScope }
        )
        guard let local = try modelContext.fetch(descriptor).first else { return }

        let row = HabitPushRow(
            id: local.id,
            userID: activeUserID,
            name: local.name,
            icon: local.icon,
            iconKey: local.iconKey ?? local.icon,
            presetCategory: local.categoryRaw.lowercased(),
            categoryCustom: local.categoryCustom,
            type: local.typeRaw,
            targetCount: local.targetCount,
            schedule: local.scheduleFrequency,
            weekdays: Self.isoWeekdays(from: local.weekdaysISO),
            reminderEnabled: local.reminderHour != nil && local.reminderMinute != nil,
            reminderTime: Self.timeString(hour: local.reminderHour, minute: local.reminderMinute),
            sortOrder: local.sortOrder,
            archived: local.archived,
            createdAt: Self.timestampString(local.createdAt),
            updatedAt: Self.timestampString(local.updatedAt)
        )

        do {
            try await client
                .from("habits")
                .upsert(row, onConflict: "id")
                .execute()
        } catch {
            if !Self.requiresIconKeyFallback(error) {
                throw error
            }
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "sync_push_habit_contract_fallback",
                    "habit_id": local.id.uuidString,
                    "error": error.localizedDescription
                ]
            )

            let noIconKeyRow = HabitPushNoIconKeyRow(
                id: local.id,
                userID: activeUserID,
                name: local.name,
                icon: local.icon,
                presetCategory: local.categoryRaw.lowercased(),
                categoryCustom: local.categoryCustom,
                type: local.typeRaw,
                targetCount: local.targetCount,
                schedule: local.scheduleFrequency,
                weekdays: Self.isoWeekdays(from: local.weekdaysISO),
                reminderEnabled: local.reminderHour != nil && local.reminderMinute != nil,
                reminderTime: Self.timeString(hour: local.reminderHour, minute: local.reminderMinute),
                sortOrder: local.sortOrder,
                archived: local.archived,
                createdAt: Self.timestampString(local.createdAt),
                updatedAt: Self.timestampString(local.updatedAt)
            )
            do {
                try await client
                    .from("habits")
                    .upsert(noIconKeyRow, onConflict: "id")
                    .execute()
            } catch {
                if !Self.requiresCategoryContractFallback(error) {
                    throw error
                }
                logger.log(
                    .storageFailure,
                    metadata: [
                        "scope": "sync_push_habit_legacy_minimal_fallback",
                        "habit_id": local.id.uuidString,
                        "error": error.localizedDescription
                    ]
                )

                let legacyRow = HabitPushLegacyRow(
                    id: local.id,
                    userID: activeUserID,
                    name: local.name,
                    icon: local.icon,
                    type: local.typeRaw,
                    targetCount: local.targetCount,
                    schedule: local.scheduleFrequency,
                    weekdays: Self.isoWeekdays(from: local.weekdaysISO),
                    reminderEnabled: local.reminderHour != nil && local.reminderMinute != nil,
                    reminderTime: Self.timeString(hour: local.reminderHour, minute: local.reminderMinute),
                    sortOrder: local.sortOrder,
                    archived: local.archived,
                    createdAt: Self.timestampString(local.createdAt),
                    updatedAt: Self.timestampString(local.updatedAt)
                )

                try await client
                    .from("habits")
                    .upsert(legacyRow, onConflict: "id")
                    .execute()
            }
        }
    }

    private func pushCompletion(payload: CompletionPayload, activeUserID: UUID) async throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<CompletionEntity>(
            predicate: #Predicate { $0.id == payload.completionKey && $0.ownerScope == ownerScope }
        )
        guard let local = try modelContext.fetch(descriptor).first else { return }

        let row = CompletionPushRow(
            userID: activeUserID,
            habitID: local.habitID,
            dayDate: payload.dayDate,
            value: local.value,
            completedAt: local.completedAt.map(Self.timestampString),
            updatedAt: Self.timestampString(local.updatedAt)
        )

        try await client
            .from("habit_completions")
            .upsert(row, onConflict: "user_id,habit_id,day_date")
            .execute()
    }

    private func pushSavedQuoteInsert(payload: SavedQuotePayload, activeUserID: UUID) async throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let quoteID: UUID? = payload.quoteID
        let descriptor = FetchDescriptor<SavedQuoteEntity>(
            predicate: #Predicate { $0.quoteID == quoteID && $0.ownerScope == ownerScope }
        )
        guard let local = try modelContext.fetch(descriptor).first else { return }

        let row = SavedQuotePushRow(
            userID: activeUserID,
            quoteID: payload.quoteID,
            savedAt: Self.timestampString(local.savedAt),
            updatedAt: Self.timestampString(local.savedAt)
        )

        try await client
            .from("saved_quotes")
            .upsert(row, onConflict: "user_id,quote_id")
            .execute()
    }

    private func pullPersonalData(activeUserID: UUID) async throws -> Int {
        var pulledCount = 0
        for resource in Resource.allCases {
            let cursor = try cursorDate(for: resource.rawValue)
            let cursorString = Self.timestampString(cursor)
            switch resource {
            case .habits:
                pulledCount += try await pullHabits(activeUserID: activeUserID, cursorString: cursorString)
            case .completions:
                pulledCount += try await pullCompletions(activeUserID: activeUserID, cursorString: cursorString)
            case .savedQuotes:
                pulledCount += try await pullSavedQuotes(activeUserID: activeUserID, cursorString: cursorString)
            case .quotes:
                pulledCount += try await pullQuotes(cursorString: cursorString)
            case .groups:
                pulledCount += try await pullGroups(activeUserID: activeUserID, cursorString: cursorString)
            case .groupMembers:
                pulledCount += try await pullGroupMembers(activeUserID: activeUserID, cursorString: cursorString)
            case .groupSharedHabits:
                pulledCount += try await pullGroupSharedHabits(activeUserID: activeUserID, cursorString: cursorString)
            }
            try setCursorDate(Date(), for: resource.rawValue)
        }
        return pulledCount
    }

    private func pullHabits(activeUserID: UUID, cursorString: String) async throws -> Int {
        let rows: [HabitPullRow]
        do {
            let response = try await client
                .from("habits")
                .select("id,name,icon,icon_key,preset_category,category_custom,type,target_count,schedule,weekdays,reminder_enabled,reminder_time,sort_order,archived,created_at,updated_at")
                .eq("user_id", value: activeUserID)
                .gt("updated_at", value: cursorString)
                .order("updated_at", ascending: true)
                .execute()
            rows = try decoder.decode([HabitPullRow].self, from: response.data)
        } catch {
            if !Self.requiresIconKeyFallback(error) {
                throw error
            }
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "sync_pull_habits_contract_fallback",
                    "error": error.localizedDescription
                ]
            )

            do {
                let compatibilityResponse = try await client
                    .from("habits")
                    .select("id,name,icon,preset_category,category_custom,type,target_count,schedule,weekdays,reminder_enabled,reminder_time,sort_order,archived,created_at,updated_at")
                    .eq("user_id", value: activeUserID)
                    .gt("updated_at", value: cursorString)
                    .order("updated_at", ascending: true)
                    .execute()
                rows = try decoder.decode([HabitPullRow].self, from: compatibilityResponse.data)
            } catch {
                if !Self.requiresCategoryContractFallback(error) {
                    throw error
                }
                logger.log(
                    .storageFailure,
                    metadata: [
                        "scope": "sync_pull_habits_legacy_minimal_fallback",
                        "error": error.localizedDescription
                    ]
                )
                let legacyResponse = try await client
                    .from("habits")
                    .select("id,name,icon,type,target_count,schedule,weekdays,reminder_enabled,reminder_time,sort_order,archived,created_at,updated_at")
                    .eq("user_id", value: activeUserID)
                    .gt("updated_at", value: cursorString)
                    .order("updated_at", ascending: true)
                    .execute()
                let legacyRows = try decoder.decode([HabitPullLegacyRow].self, from: legacyResponse.data)
                rows = legacyRows.map { $0.asContractRow() }
            }
        }

        for row in rows {
            try mergeHabit(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
        return rows.count
    }

    private func mergeHabit(_ row: HabitPullRow) throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let habitID = row.id
        let updatedAt = Self.timestamp(from: row.updatedAt) ?? Date()
        let createdAt = row.createdAt.flatMap(Self.timestamp(from:)) ?? updatedAt
        let reminder = Self.timeComponents(from: row.reminderTime)
        let weekdaysCSV = (row.weekdays ?? [])
            .sorted()
            .map(String.init)
            .joined(separator: ",")

        let descriptor = FetchDescriptor<HabitEntity>(
            predicate: #Predicate { $0.id == habitID && $0.ownerScope == ownerScope }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            guard updatedAt >= existing.updatedAt else { return }
            existing.name = row.name
            existing.icon = row.icon ?? row.iconKey ?? "checkmark.circle"
            existing.iconKey = row.iconKey ?? row.icon
            existing.categoryRaw = row.presetCategory ?? HabitCategoryValue.spiritual.rawValue
            existing.categoryCustom = row.categoryCustom
            existing.typeRaw = row.type
            existing.targetCount = row.targetCount
            existing.scheduleFrequency = row.schedule
            existing.weekdaysISO = weekdaysCSV
            existing.reminderHour = row.reminderEnabled ? reminder?.hour : nil
            existing.reminderMinute = row.reminderEnabled ? reminder?.minute : nil
            existing.sortOrder = row.sortOrder ?? existing.sortOrder
            existing.archived = row.archived ?? false
            existing.createdAt = createdAt
            existing.updatedAt = updatedAt
            return
        }

        modelContext.insert(
            HabitEntity(
                id: row.id,
                ownerScope: ownerScope,
                name: row.name,
                icon: row.icon ?? row.iconKey ?? "checkmark.circle",
                iconKey: row.iconKey ?? row.icon,
                categoryRaw: row.presetCategory ?? HabitCategoryValue.spiritual.rawValue,
                categoryCustom: row.categoryCustom,
                typeRaw: row.type,
                targetCount: row.targetCount,
                scheduleFrequency: row.schedule,
                weekdaysISO: weekdaysCSV,
                reminderHour: row.reminderEnabled ? reminder?.hour : nil,
                reminderMinute: row.reminderEnabled ? reminder?.minute : nil,
                selectedDhikrKey: Habit.defaultDhikrKey,
                dhikrCountsJSON: "{}",
                sortOrder: row.sortOrder ?? 0,
                archived: row.archived ?? false,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        )
    }

    private func pullCompletions(activeUserID: UUID, cursorString: String) async throws -> Int {
        let windowStart = Self.syncDayDateString(
            for: Date().addingTimeInterval(-40 * 24 * 60 * 60),
            calendar: .current,
            timeZone: .current
        )

        let response = try await client
            .from("habit_completions")
            .select("habit_id,day_date,value,completed_at,updated_at")
            .eq("user_id", value: activeUserID)
            .gte("day_date", value: windowStart)
            .gt("updated_at", value: cursorString)
            .order("updated_at", ascending: true)
            .execute()

        let rows = try decoder.decode([CompletionPullRow].self, from: response.data)
        for row in rows {
            try mergeCompletion(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
        return rows.count
    }

    private func mergeCompletion(_ row: CompletionPullRow) throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let calendar = Calendar.current
        let timeZone = TimeZone.current
        guard let dayDate = Self.syncDayDate(row.dayDate, calendar: calendar, timeZone: timeZone) else { return }
        let key = CompletionsLocalRepository.key(
            habitID: row.habitID,
            day: dayDate,
            ownerScope: ownerScope,
            calendar: calendar,
            timeZone: timeZone
        )
        let updatedAt = Self.timestamp(from: row.updatedAt) ?? Date()
        let completedAt = row.completedAt.flatMap(Self.timestamp(from:))

        let descriptor = FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.id == key })
        if let existing = try modelContext.fetch(descriptor).first {
            guard updatedAt >= existing.updatedAt else { return }
            existing.value = row.value
            existing.completedAt = completedAt
            existing.updatedAt = updatedAt
            return
        }

        modelContext.insert(
            CompletionEntity(
                id: key,
                ownerScope: ownerScope,
                habitID: row.habitID,
                dayDate: dayDate,
                value: row.value,
                completedAt: completedAt,
                updatedAt: updatedAt
            )
        )
    }

    private func pullSavedQuotes(activeUserID: UUID, cursorString: String) async throws -> Int {
        let response = try await client
            .from("saved_quotes")
            .select("quote_id,saved_at,updated_at")
            .eq("user_id", value: activeUserID)
            .gt("updated_at", value: cursorString)
            .order("updated_at", ascending: true)
            .execute()

        let rows = try decoder.decode([SavedQuotePullRow].self, from: response.data)
        for row in rows {
            try mergeSavedQuote(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
        return rows.count
    }

    private func mergeSavedQuote(_ row: SavedQuotePullRow) throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let quoteID: UUID? = row.quoteID
        let savedAt = Self.timestamp(from: row.savedAt) ?? Date()
        let remoteUpdatedAt = Self.timestamp(from: row.updatedAt) ?? savedAt
        let descriptor = FetchDescriptor<SavedQuoteEntity>(
            predicate: #Predicate { $0.quoteID == quoteID && $0.ownerScope == ownerScope }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            guard remoteUpdatedAt >= existing.savedAt else { return }
            existing.savedAt = savedAt
            return
        }

        modelContext.insert(
            SavedQuoteEntity(
                id: UUID(),
                ownerScope: ownerScope,
                quoteID: row.quoteID,
                text: "",
                author: "",
                savedAt: savedAt
            )
        )
    }

    private func pullQuotes(cursorString: String) async throws -> Int {
        let response = try await client
            .from("quotes")
            .select("id,locale,text,source,sort_order,active,created_at,updated_at")
            .gt("updated_at", value: cursorString)
            .order("updated_at", ascending: true)
            .execute()

        let rows = try decoder.decode([QuotePullRow].self, from: response.data)
        for row in rows {
            try mergeQuote(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
        return rows.count
    }

    private func mergeQuote(_ row: QuotePullRow) throws {
        let quoteID = row.id
        let updatedAt = Self.timestamp(from: row.updatedAt) ?? Date()
        let createdAt = row.createdAt.flatMap(Self.timestamp(from:)) ?? updatedAt
        let descriptor = FetchDescriptor<QuoteEntity>(predicate: #Predicate { $0.id == quoteID })
        if let existing = try modelContext.fetch(descriptor).first {
            guard updatedAt >= existing.updatedAt else { return }
            existing.locale = row.locale
            existing.text = row.text
            existing.source = row.source
            existing.sortOrder = row.sortOrder ?? 0
            existing.active = row.active ?? true
            existing.createdAt = createdAt
            existing.updatedAt = updatedAt
            return
        }

        modelContext.insert(
            QuoteEntity(
                id: row.id,
                locale: row.locale,
                text: row.text,
                source: row.source,
                sortOrder: row.sortOrder ?? 0,
                active: row.active ?? true,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        )
    }

    private func pullGroups(activeUserID: UUID, cursorString: String) async throws -> Int {
        let response: PostgrestResponse<Void>
        do {
            response = try await client
                .from("groups")
                .select("id,owner_id,name,code,join_locked,created_at,updated_at")
                .gt("updated_at", value: cursorString)
                .order("updated_at", ascending: true)
                .execute()
        } catch {
            guard Self.isMissingJoinLockedColumnError(error) else {
                throw error
            }
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "sync_pull_groups_join_locked_fallback",
                    "error": error.localizedDescription
                ]
            )
            response = try await client
                .from("groups")
                .select("id,owner_id,name,code,created_at,updated_at")
                .gt("updated_at", value: cursorString)
                .order("updated_at", ascending: true)
                .execute()
        }

        let rows = try decoder.decode([GroupPullRow].self, from: response.data)
        for row in rows {
            try mergeGroup(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
        _ = activeUserID
        return rows.count
    }

    private func mergeGroup(_ row: GroupPullRow) throws {
        let groupID = row.id
        let updatedAt = Self.timestamp(from: row.updatedAt) ?? Date()
        let createdAt = row.createdAt.flatMap(Self.timestamp(from:)) ?? updatedAt
        let descriptor = FetchDescriptor<LocalGroupSyncEntity>(predicate: #Predicate { $0.id == groupID })
        if let existing = try modelContext.fetch(descriptor).first {
            guard updatedAt >= existing.updatedAt else { return }
            existing.ownerID = row.ownerID
            existing.name = row.name
            existing.code = row.code
            existing.joinLocked = row.joinLocked ?? false
            existing.createdAt = createdAt
            existing.updatedAt = updatedAt
            return
        }

        modelContext.insert(
            LocalGroupSyncEntity(
                id: row.id,
                ownerID: row.ownerID,
                name: row.name,
                code: row.code,
                joinLocked: row.joinLocked ?? false,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        )
    }

    private func pullGroupMembers(activeUserID: UUID, cursorString: String) async throws -> Int {
        let response = try await client
            .from("group_members")
            .select("group_id,user_id,role,updated_at")
            .gt("updated_at", value: cursorString)
            .order("updated_at", ascending: true)
            .execute()

        let rows = try decoder.decode([GroupMemberPullRow].self, from: response.data)
        for row in rows {
            try mergeGroupMember(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
        _ = activeUserID
        return rows.count
    }

    private func mergeGroupMember(_ row: GroupMemberPullRow) throws {
        let id = "\(row.groupID.uuidString)-\(row.userID.uuidString)"
        let updatedAt = Self.timestamp(from: row.updatedAt) ?? Date()
        let descriptor = FetchDescriptor<LocalGroupMemberSyncEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            guard updatedAt >= existing.updatedAt else { return }
            existing.role = row.role ?? "member"
            existing.updatedAt = updatedAt
            return
        }

        modelContext.insert(
            LocalGroupMemberSyncEntity(
                id: id,
                groupID: row.groupID,
                userID: row.userID,
                role: row.role ?? "member",
                updatedAt: updatedAt
            )
        )
    }

    private func pullGroupSharedHabits(activeUserID: UUID, cursorString: String) async throws -> Int {
        let response = try await client
            .from("group_shared_habits")
            .select("group_id,user_id,habit_id,shared,updated_at")
            .gt("updated_at", value: cursorString)
            .order("updated_at", ascending: true)
            .execute()

        let rows = try decoder.decode([GroupSharedHabitPullRow].self, from: response.data)
        for row in rows {
            try mergeGroupSharedHabit(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
        _ = activeUserID
        return rows.count
    }

    private func mergeGroupSharedHabit(_ row: GroupSharedHabitPullRow) throws {
        let id = "\(row.groupID.uuidString)-\(row.userID.uuidString)-\(row.habitID.uuidString)"
        let updatedAt = Self.timestamp(from: row.updatedAt) ?? Date()
        let descriptor = FetchDescriptor<LocalGroupSharedHabitSyncEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            guard updatedAt >= existing.updatedAt else { return }
            existing.shared = row.shared ?? true
            existing.updatedAt = updatedAt
            return
        }

        modelContext.insert(
            LocalGroupSharedHabitSyncEntity(
                id: id,
                groupID: row.groupID,
                userID: row.userID,
                habitID: row.habitID,
                shared: row.shared ?? true,
                updatedAt: updatedAt
            )
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from payloadJSON: String) throws -> T {
        let data = payloadJSON.data(using: .utf8) ?? Data()
        return try decoder.decode(type, from: data)
    }

    private func cursorDate(for resource: String) throws -> Date {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<LocalSyncCursorEntity>(
            predicate: #Predicate { $0.ownerScope == ownerScope && $0.resource == resource }
        )
        return try modelContext.fetch(descriptor).first?.lastPulledAt ?? .distantPast
    }

    private func setCursorDate(_ date: Date, for resource: String) throws {
        let ownerScope = ownerScopeProvider.currentOwnerScopeRawValue
        let descriptor = FetchDescriptor<LocalSyncCursorEntity>(
            predicate: #Predicate { $0.ownerScope == ownerScope && $0.resource == resource }
        )
        if let cursor = try modelContext.fetch(descriptor).first {
            cursor.lastPulledAt = date
        } else {
            modelContext.insert(LocalSyncCursorEntity(ownerScope: ownerScope, resource: resource, lastPulledAt: date))
        }
        try modelContext.save()
    }

    private static func isoWeekdays(from csv: String) -> [Int] {
        csv
            .split(separator: ",")
            .compactMap { Int($0) }
            .filter { (1...7).contains($0) }
            .sorted()
    }

    private static func timeString(hour: Int?, minute: Int?) -> String? {
        guard let hour, let minute else { return nil }
        return String(format: "%02d:%02d:00", hour, minute)
    }

    private static func timeComponents(from value: String?) -> (hour: Int, minute: Int)? {
        guard let value, !value.isEmpty else { return nil }
        let components = value.split(separator: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return nil
        }
        return (hour, minute)
    }

    static func syncDayDateString(for date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func syncDayDate(_ value: String, calendar: Calendar, timeZone: TimeZone) -> Date? {
        let parts = value.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var normalizedCalendar = calendar
        normalizedCalendar.timeZone = timeZone
        let components = DateComponents(timeZone: timeZone, year: year, month: month, day: day)
        guard let materialized = normalizedCalendar.date(from: components) else {
            return nil
        }
        return normalizedCalendar.startOfDay(for: materialized)
    }

    private static func timestampString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func timestamp(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func syncErrorCode(from error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain)#\(nsError.code)"
    }

    private func completionID(from existingID: String, sourceScope: String, targetScope: String) -> String {
        let sourcePrefix = "\(sourceScope)|"
        if existingID.hasPrefix(sourcePrefix) {
            return "\(targetScope)|\(existingID.dropFirst(sourcePrefix.count))"
        }
        if let separator = existingID.firstIndex(of: "|") {
            return "\(targetScope)|\(existingID[existingID.index(after: separator)...])"
        }
        return existingID
    }

    private static func isMissingJoinLockedColumnError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("join_locked")
            && (message.contains("does not exist")
                || message.contains("undefined column")
                || message.contains("42703"))
    }

    private static func requiresIconKeyFallback(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        guard message.contains("does not exist")
            || message.contains("undefined column")
            || message.contains("42703")
        else {
            return false
        }

        return message.contains("habits.icon_key")
    }

    private static func requiresCategoryContractFallback(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        guard message.contains("does not exist")
            || message.contains("undefined column")
            || message.contains("42703")
        else {
            return false
        }

        return message.contains("habits.preset_category")
            || message.contains("habits.category_custom")
            || message.contains("habits.category")
    }

    private static func savedQuoteMatchKey(_ quoteID: UUID?) -> String {
        quoteID?.uuidString.lowercased() ?? "nil"
    }
}
