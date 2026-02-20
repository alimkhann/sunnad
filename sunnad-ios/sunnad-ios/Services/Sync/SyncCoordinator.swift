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
        static let promotionPrefix = "sunnad.sync.promoted."
    }

    private enum Resource: String, CaseIterable {
        case habits
        case completions
        case savedQuotes = "saved_quotes"
        case quotes
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
        let habitID: UUID
        let dayDate: String

        enum CodingKeys: String, CodingKey {
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

    private let client: SupabaseClient
    private let modelContext: ModelContext
    private let logger: AnalyticsLogging
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var activeUserID: UUID?
    private var isRunningCycle = false

    init(
        client: SupabaseClient,
        modelContext: ModelContext,
        logger: AnalyticsLogging,
        userDefaults: UserDefaults = .standard
    ) {
        self.client = client
        self.modelContext = modelContext
        self.logger = logger
        self.userDefaults = userDefaults
    }

    func setSignedInUserID(_ userID: UUID?) async {
        activeUserID = userID
    }

    func promoteLocalDataIfNeeded() async {
        guard let activeUserID else { return }

        let key = "\(Keys.promotionPrefix)\(activeUserID.uuidString)"
        if userDefaults.bool(forKey: key) {
            return
        }

        do {
            let habits = try modelContext.fetch(FetchDescriptor<HabitEntity>())
            for habit in habits {
                await enqueueHabitUpsert(habitID: habit.id)
            }

            let completions = try modelContext.fetch(FetchDescriptor<CompletionEntity>())
            for completion in completions {
                await enqueueCompletionUpsert(
                    habitID: completion.habitID,
                    dayDate: completion.dayDate,
                    calendar: .gregorianUTC,
                    timeZone: .utc
                )
            }

            let savedQuotes = try modelContext.fetch(FetchDescriptor<SavedQuoteEntity>())
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

        logger.log(.syncStarted, metadata: ["scope": "sync_cycle", "trigger": trigger.rawValue])

        defer {
            isRunningCycle = false
            logger.log(.syncFinished, metadata: ["scope": "sync_cycle", "trigger": trigger.rawValue])
        }

        do {
            try await pushOutbox(activeUserID: activeUserID)
            try await pullPersonalData(activeUserID: activeUserID)
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "sync_cycle", "error": error.localizedDescription])
        }
    }

    func enqueueHabitUpsert(habitID: UUID) async {
        await enqueue(type: .upsertHabit, payload: HabitPayload(habitID: habitID))
    }

    func enqueueHabitDelete(habitID: UUID) async {
        await enqueue(type: .deleteHabit, payload: HabitPayload(habitID: habitID))
    }

    func enqueueCompletionUpsert(habitID: UUID, dayDate: Date, calendar: Calendar, timeZone: TimeZone) async {
        let payload = CompletionPayload(
            habitID: habitID,
            dayDate: Self.dayDateString(for: dayDate, calendar: calendar, timeZone: timeZone)
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
        do {
            let data = try encoder.encode(payload)
            guard let payloadJSON = String(data: data, encoding: .utf8) else {
                return
            }

            modelContext.insert(
                LocalOutboxEventEntity(
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

    private func pushOutbox(activeUserID: UUID) async throws {
        let descriptor = FetchDescriptor<LocalOutboxEventEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let events = try modelContext.fetch(descriptor)

        for event in events {
            do {
                try await apply(event: event, activeUserID: activeUserID)
                modelContext.delete(event)
                try modelContext.save()
            } catch {
                event.attemptCount += 1
                event.lastError = error.localizedDescription
                try modelContext.save()
                throw error
            }
        }
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
        let descriptor = FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.id == habitID })
        guard let local = try modelContext.fetch(descriptor).first else { return }

        let row = HabitPushRow(
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
            .upsert(row, onConflict: "id")
            .execute()
    }

    private func pushCompletion(payload: CompletionPayload, activeUserID: UUID) async throws {
        guard let dayDate = Self.dayDate(from: payload.dayDate) else { return }

        let key = CompletionsLocalRepository.key(
            habitID: payload.habitID,
            day: dayDate,
            calendar: .gregorianUTC,
            timeZone: .utc
        )
        let descriptor = FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.id == key })
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
        let quoteID: UUID? = payload.quoteID
        let descriptor = FetchDescriptor<SavedQuoteEntity>(
            predicate: #Predicate { $0.quoteID == quoteID }
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

    private func pullPersonalData(activeUserID: UUID) async throws {
        for resource in Resource.allCases {
            let cursor = try cursorDate(for: resource.rawValue)
            let cursorString = Self.timestampString(cursor)
            switch resource {
            case .habits:
                try await pullHabits(activeUserID: activeUserID, cursorString: cursorString)
            case .completions:
                try await pullCompletions(activeUserID: activeUserID, cursorString: cursorString)
            case .savedQuotes:
                try await pullSavedQuotes(activeUserID: activeUserID, cursorString: cursorString)
            case .quotes:
                try await pullQuotes(cursorString: cursorString)
            }
            try setCursorDate(Date(), for: resource.rawValue)
        }
    }

    private func pullHabits(activeUserID: UUID, cursorString: String) async throws {
        let response = try await client
            .from("habits")
            .select("id,name,icon,type,target_count,schedule,weekdays,reminder_enabled,reminder_time,sort_order,archived,created_at,updated_at")
            .eq("user_id", value: activeUserID)
            .gt("updated_at", value: cursorString)
            .order("updated_at", ascending: true)
            .execute()

        let rows = try decoder.decode([HabitPullRow].self, from: response.data)
        for row in rows {
            try mergeHabit(row)
        }
        if !rows.isEmpty {
            try modelContext.save()
        }
    }

    private func mergeHabit(_ row: HabitPullRow) throws {
        let habitID = row.id
        let updatedAt = Self.timestamp(from: row.updatedAt) ?? Date()
        let createdAt = row.createdAt.flatMap(Self.timestamp(from:)) ?? updatedAt
        let reminder = Self.timeComponents(from: row.reminderTime)
        let weekdaysCSV = (row.weekdays ?? [])
            .sorted()
            .map(String.init)
            .joined(separator: ",")

        let descriptor = FetchDescriptor<HabitEntity>(predicate: #Predicate { $0.id == habitID })
        if let existing = try modelContext.fetch(descriptor).first {
            guard updatedAt >= existing.updatedAt else { return }
            existing.name = row.name
            existing.icon = row.icon ?? "checkmark.circle"
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
                name: row.name,
                icon: row.icon ?? "checkmark.circle",
                categoryRaw: HabitCategoryValue.spiritual.rawValue,
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

    private func pullCompletions(activeUserID: UUID, cursorString: String) async throws {
        let windowStart = Self.dayDateString(
            for: Date().addingTimeInterval(-40 * 24 * 60 * 60),
            calendar: .gregorianUTC,
            timeZone: .utc
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
    }

    private func mergeCompletion(_ row: CompletionPullRow) throws {
        guard let dayDate = Self.dayDate(from: row.dayDate) else { return }
        let key = CompletionsLocalRepository.key(
            habitID: row.habitID,
            day: dayDate,
            calendar: .gregorianUTC,
            timeZone: .utc
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
                habitID: row.habitID,
                dayDate: dayDate,
                value: row.value,
                completedAt: completedAt,
                updatedAt: updatedAt
            )
        )
    }

    private func pullSavedQuotes(activeUserID: UUID, cursorString: String) async throws {
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
    }

    private func mergeSavedQuote(_ row: SavedQuotePullRow) throws {
        let quoteID: UUID? = row.quoteID
        let savedAt = Self.timestamp(from: row.savedAt) ?? Date()
        let remoteUpdatedAt = Self.timestamp(from: row.updatedAt) ?? savedAt
        let descriptor = FetchDescriptor<SavedQuoteEntity>(
            predicate: #Predicate { $0.quoteID == quoteID }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            guard remoteUpdatedAt >= existing.savedAt else { return }
            existing.savedAt = savedAt
            return
        }

        modelContext.insert(
            SavedQuoteEntity(
                id: UUID(),
                quoteID: row.quoteID,
                text: "",
                author: "",
                savedAt: savedAt
            )
        )
    }

    private func pullQuotes(cursorString: String) async throws {
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

    private func decode<T: Decodable>(_ type: T.Type, from payloadJSON: String) throws -> T {
        let data = payloadJSON.data(using: .utf8) ?? Data()
        return try decoder.decode(type, from: data)
    }

    private func cursorDate(for resource: String) throws -> Date {
        let descriptor = FetchDescriptor<LocalSyncCursorEntity>(
            predicate: #Predicate { $0.resource == resource }
        )
        return try modelContext.fetch(descriptor).first?.lastPulledAt ?? .distantPast
    }

    private func setCursorDate(_ date: Date, for resource: String) throws {
        let descriptor = FetchDescriptor<LocalSyncCursorEntity>(
            predicate: #Predicate { $0.resource == resource }
        )
        if let cursor = try modelContext.fetch(descriptor).first {
            cursor.lastPulledAt = date
        } else {
            modelContext.insert(LocalSyncCursorEntity(resource: resource, lastPulledAt: date))
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

    private static func dayDateString(for date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone
        let day = calendar.startOfDay(for: date)

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: day)
    }

    private static func dayDate(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
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
}

private extension Calendar {
    static var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .utc
        return calendar
    }
}

private extension TimeZone {
    static var utc: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }
}
