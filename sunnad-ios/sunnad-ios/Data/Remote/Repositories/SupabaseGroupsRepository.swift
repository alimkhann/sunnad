import Foundation
import Supabase

final class SupabaseGroupsRepository: GroupsRepository, @unchecked Sendable {
    private struct GroupRow: Decodable {
        let id: UUID
        let ownerID: UUID
        let name: String
        let code: String
        let joinLocked: Bool?
        let createdAtRaw: String?

        var createdAt: Date? {
            createdAtRaw.flatMap(SupabaseGroupsRepository.timestamp(from:))
        }

        enum CodingKeys: String, CodingKey {
            case id
            case ownerID = "owner_id"
            case name
            case code
            case joinLocked = "join_locked"
            case createdAtRaw = "created_at"
        }
    }

    private struct GroupMemberRow: Decodable {
        let groupID: UUID
        let userID: UUID
        let progressDisplayMode: GroupProgressDisplayMode?
        let joinedAtRaw: String?

        var joinedAt: Date? {
            joinedAtRaw.flatMap(SupabaseGroupsRepository.timestamp(from:))
        }

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case userID = "user_id"
            case progressDisplayMode = "progress_display_mode"
            case joinedAtRaw = "joined_at"
        }
    }

    private struct GroupSharedHabitRow: Decodable {
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

    private struct HabitRow: Decodable {
        let id: UUID
        let userID: UUID
        let name: String
        let icon: String
        let iconKey: String?
        let type: String
        let presetCategory: HabitCategoryValue?
        let categoryCustom: String?
        let targetCount: Int?
        let schedule: String?
        let weekdays: [Int]?
        let archived: Bool?
        let createdAtRaw: String?

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case name
            case icon
            case iconKey = "icon_key"
            case type
            case presetCategory = "preset_category"
            case categoryCustom = "category_custom"
            case targetCount = "target_count"
            case schedule
            case weekdays
            case archived
            case createdAtRaw = "created_at"
        }
    }

    private struct CompletionRow: Decodable {
        let value: Int
    }

    private struct CompletionHistoryRow: Decodable {
        let dayDate: String
        let value: Int
        let completedAtRaw: String?
        let updatedAtRaw: String

        enum CodingKeys: String, CodingKey {
            case dayDate = "day_date"
            case value
            case completedAtRaw = "completed_at"
            case updatedAtRaw = "updated_at"
        }
    }

    private struct BatchCompletionHistoryRow: Decodable {
        let habitID: UUID
        let userID: UUID
        let dayDate: String
        let value: Int
        let completedAtRaw: String?
        let updatedAtRaw: String

        enum CodingKeys: String, CodingKey {
            case habitID = "habit_id"
            case userID = "user_id"
            case dayDate = "day_date"
            case value
            case completedAtRaw = "completed_at"
            case updatedAtRaw = "updated_at"
        }
    }

    private struct ProfileRow: Decodable {
        let username: String?
        let avatarPath: String?
        let updatedAtRaw: String?
        let timeZone: String?
        let locale: String?

        var updatedAt: Date? {
            Self.parseProfileTimestamp(updatedAtRaw)
        }

        enum CodingKeys: String, CodingKey {
            case username
            case avatarPath = "avatar_path"
            case updatedAtRaw = "updated_at"
            case timeZone = "time_zone"
            case locale
        }

        private static func parseProfileTimestamp(_ rawValue: String?) -> Date? {
            guard let rawValue, !rawValue.isEmpty else { return nil }

            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = fractional.date(from: rawValue) {
                return parsed
            }

            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            return plain.date(from: rawValue)
        }
    }

    private struct BatchProfileRow: Decodable {
        let id: UUID
        let username: String?
        let avatarPath: String?
        let updatedAtRaw: String?
        let timeZone: String?
        let locale: String?

        enum CodingKeys: String, CodingKey {
            case id
            case username
            case avatarPath = "avatar_path"
            case updatedAtRaw = "updated_at"
            case timeZone = "time_zone"
            case locale
        }
    }

    private struct ResolvedProfile {
        let name: String
        let avatarURL: URL?
        let timeZone: TimeZone
        let locale: String
    }

    private struct GroupMutationRow: Encodable {
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

    private struct NudgeFunctionResponse: Decodable {
        let status: GroupNudgeStatus
        let delivered: Bool?
        let error: String?
    }

    private let client: SupabaseClient
    private let logger: AnalyticsLogging
    private let decoder = JSONDecoder()
    private var supportsProgressDisplayModeColumn: Bool?
    private var supportsProgressDisplayModeRPC: Bool?
    private var supportsHabitContractColumns: Bool?

    init(client: SupabaseClient, logger: AnalyticsLogging) {
        self.client = client
        self.logger = logger
    }

    func fetchGroups() async throws -> [Group] {
        let currentUserID = try await requireCurrentUserID()
        let groupRows = try await fetchGroupRows()
        guard !groupRows.isEmpty else { return [] }

        do {
            let now = Date()
            let groupIDs = groupRows.map(\.id)
            let members = try await fetchGroupMembers(groupIDs: groupIDs)
            let sharedRows = try await fetchSharedHabits(groupIDs: groupIDs).filter(\.shared)
            let memberIDs = Array(Set(members.map(\.userID)))
            let habitIDs = Array(Set(sharedRows.map(\.habitID)))
            let profilesByUserID = try await fetchProfiles(userIDs: memberIDs)
            let habitsByID = try await fetchHabits(habitIDs: habitIDs)
            let contextsByUserID = Dictionary(uniqueKeysWithValues: memberIDs.map { userID in
                let timeZone = profilesByUserID[userID]?.timeZone ?? .current
                return (userID, DayContext(now: now, timeZone: timeZone))
            })
            let historiesByPair = try await fetchCompletionHistories(
                habitIDs: habitIDs,
                userIDs: memberIDs,
                contextsByUserID: contextsByUserID
            )

            return groupRows.map { groupRow in
                let groupMembers = members.filter { $0.groupID == groupRow.id }
                let groupSharedRows = sharedRows.filter { $0.groupID == groupRow.id }
                let currentUserSharedIDs = Set(
                    groupSharedRows
                        .filter { $0.userID == currentUserID }
                        .map(\.habitID)
                )
                let domainMembers = groupMembers.map { member in
                    let memberID = member.userID
                    let profile = profilesByUserID[memberID]
                        ?? ResolvedProfile(name: "Member", avatarURL: nil, timeZone: .current, locale: "en")
                    let context = contextsByUserID[memberID]
                        ?? DayContext(now: now, timeZone: profile.timeZone)
                    let memberSharedRows = groupSharedRows.filter { $0.userID == memberID }
                    var completedTodayDueCount = 0
                    var totalDueCount = 0

                    let sharedHabits = memberSharedRows.map { shared -> SharedHabit in
                        guard let habitRow = habitsByID[shared.habitID] else {
                            return SharedHabit(
                                habitID: shared.habitID,
                                title: "Shared habit",
                                icon: "star.fill",
                                completedToday: false,
                                dueToday: false,
                                streak: 0,
                                rollingCompletionPercent: nil
                            )
                        }

                        let habit = makeDomainHabit(from: habitRow)
                        let pairKey = Self.completionPairKey(habitID: habit.id, userID: memberID)
                        let completions = historiesByPair[pairKey] ?? []
                        let todayCompletion = completions.first {
                            context.calendar.isDate($0.dayDate, inSameDayAs: context.today)
                        }
                        let completedToday = todayCompletion?.isCompleted(for: habit) ?? false
                        let dueToday = habit.schedule.isDue(
                            on: context.now,
                            calendar: context.calendar,
                            timeZone: context.timeZone
                        )
                        if dueToday {
                            totalDueCount += 1
                            if completedToday { completedTodayDueCount += 1 }
                        }

                        let streak = StreakCalculator.streak(
                            for: habit,
                            completions: completions,
                            context: context
                        )
                        var rollingHabit = habit
                        if let memberWindowStart = Self.laterDate(groupRow.createdAt, member.joinedAt) {
                            rollingHabit.createdAt = max(rollingHabit.createdAt, memberWindowStart)
                        }
                        let rollingCompletionPercent = HabitMetricsCalculator.rollingCompletionPercent(
                            for: rollingHabit,
                            completions: completions,
                            context: context,
                            occurrenceLimit: 40
                        )

                        return SharedHabit(
                            habitID: habit.id,
                            title: habit.name,
                            icon: habit.icon,
                            completedToday: completedToday,
                            dueToday: dueToday,
                            streak: streak,
                            rollingCompletionPercent: rollingCompletionPercent
                        )
                    }

                    return GroupMember(
                        id: memberID,
                        name: profile.name,
                        avatarURL: profile.avatarURL,
                        completedToday: completedTodayDueCount,
                        totalSharedHabits: totalDueCount,
                        sharedHabits: sharedHabits
                    )
                }

                return Group(
                    id: groupRow.id,
                    name: groupRow.name,
                    code: groupRow.code,
                    joinLocked: groupRow.joinLocked ?? false,
                    members: domainMembers,
                    sharedHabitIDs: currentUserSharedIDs,
                    ownerMemberID: groupRow.ownerID,
                    currentUserMemberID: currentUserID,
                    progressDisplayMode: groupMembers.first(where: { $0.userID == currentUserID })?.progressDisplayMode ?? .percent
                )
            }
        } catch {
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "groups_fetch_batch_enrichment",
                    "error": error.localizedDescription
                ]
            )
            var fallbacks: [Group] = []
            fallbacks.reserveCapacity(groupRows.count)
            for groupRow in groupRows {
                if let fallback = await resilientFallbackGroup(from: groupRow, currentUserID: currentUserID) {
                    fallbacks.append(fallback)
                } else {
                    fallbacks.append(minimalGroup(from: groupRow, currentUserID: currentUserID))
                }
            }
            return fallbacks
        }
    }

    func createGroup(name: String) async throws -> Group {
        let response = try await client
            .rpc("create_group_with_owner", params: ["group_name": name])
            .execute()

        guard let groupID = Self.decodeUUID(from: response.data) else {
            throw NSError(domain: "SupabaseGroupsRepository", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse created group ID."
            ])
        }

        guard let group = try await refreshGroupWithRetry(groupID: groupID) else {
            throw NSError(domain: "SupabaseGroupsRepository", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Created group could not be fetched."
            ])
        }
        return group
    }

    func joinGroup(code: String) async throws -> Group {
        let normalizedCode = Self.normalizedInviteCode(code)
        let response: PostgrestResponse<Void>
        do {
            response = try await client
                .rpc("join_group_by_code", params: ["invite_code": normalizedCode])
                .execute()
        } catch {
            throw mapJoinError(error)
        }

        guard let groupID = Self.decodeUUID(from: response.data) else {
            throw NSError(domain: "SupabaseGroupsRepository", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse joined group ID."
            ])
        }

        guard let group = try await refreshGroupWithRetry(groupID: groupID) else {
            throw NSError(domain: "SupabaseGroupsRepository", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Joined group could not be fetched."
            ])
        }
        return group
    }

    func renameGroup(groupID: UUID, name: String) async throws {
        _ = try await client
            .rpc("rename_group", params: ["p_group_id": groupID.uuidString, "p_name": name])
            .execute()
    }

    func setJoinLock(groupID: UUID, locked: Bool) async throws {
        _ = try await client
            .rpc(
                "set_group_join_lock",
                params: [
                    "p_group_id": AnyJSON.string(groupID.uuidString),
                    "p_locked": AnyJSON.bool(locked)
                ]
            )
            .execute()
    }

    func rotateInviteCode(groupID: UUID) async throws -> String {
        let response = try await client
            .rpc("rotate_group_invite_code", params: ["p_group_id": groupID.uuidString])
            .execute()

        guard let code = Self.decodeString(from: response.data), !code.isEmpty else {
            throw NSError(domain: "SupabaseGroupsRepository", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse rotated invite code."
            ])
        }

        return code
    }

    func updateSharing(groupID: UUID, habitIDs: Set<UUID>) async throws {
        let currentUserID = try await requireCurrentUserID()
        let validHabitRowsResponse = try await client
            .from("habits")
            .select("id, user_id, name, icon, icon_key, preset_category, category_custom, type, target_count, schedule, weekdays, archived, created_at")
            .eq("user_id", value: currentUserID)
            .execute()
        let validHabitRows = try decoder.decode([HabitRow].self, from: validHabitRowsResponse.data)
        let validHabitIDs = Set(
            validHabitRows
                .filter { !($0.archived ?? false) }
                .map(\.id)
        )
        let sanitizedHabitIDs = habitIDs.intersection(validHabitIDs)
        if sanitizedHabitIDs.count != habitIDs.count {
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "groups_update_sharing_filtered",
                    "group_id": groupID.uuidString,
                    "requested_count": "\(habitIDs.count)",
                    "valid_count": "\(sanitizedHabitIDs.count)"
                ]
            )
        }

        try await client
            .from("group_shared_habits")
            .update(["shared": AnyJSON.bool(false)])
            .eq("group_id", value: groupID)
            .eq("user_id", value: currentUserID)
            .execute()

        guard !sanitizedHabitIDs.isEmpty else {
            return
        }

        let rows = sanitizedHabitIDs.map {
            GroupMutationRow(groupID: groupID, userID: currentUserID, habitID: $0, shared: true)
        }

        try await client
            .from("group_shared_habits")
            .upsert(rows, onConflict: "group_id,user_id,habit_id")
            .execute()
    }

    func leaveGroup(groupID: UUID) async throws {
        let currentUserID = try await requireCurrentUserID()
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupID)
            .eq("user_id", value: currentUserID)
            .execute()
    }

    func deleteGroup(groupID: UUID) async throws {
        try await client
            .from("groups")
            .delete()
            .eq("id", value: groupID)
            .execute()
    }

    func kickMember(groupID: UUID, memberUserID: UUID) async throws {
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupID)
            .eq("user_id", value: memberUserID)
            .execute()
    }

    func setProgressDisplayMode(groupID: UUID, mode: GroupProgressDisplayMode) async throws {
        if supportsProgressDisplayModeRPC == false {
            return
        }
        do {
            _ = try await client
                .rpc(
                    "set_group_progress_display_mode",
                    params: [
                        "p_group_id": AnyJSON.string(groupID.uuidString),
                        "p_mode": AnyJSON.string(mode.rawValue)
                    ]
                )
                .execute()
            supportsProgressDisplayModeRPC = true
        } catch {
            guard Self.isMissingProgressDisplayModeRPCFunctionError(error) else {
                throw error
            }
            supportsProgressDisplayModeRPC = false
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "groups_set_progress_mode_rpc_fallback",
                    "group_id": groupID.uuidString,
                    "error": error.localizedDescription
                ]
            )
        }
    }

    func refreshGroup(groupID: UUID) async throws -> Group? {
        let groups = try await fetchGroups()
        return groups.first(where: { $0.id == groupID })
    }

    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus {
        do {
            let response = try await invokeNudgeFunction(
                groupID: groupID,
                toUserID: toUserID,
                habitID: habitID
            )
            return verifiedNudgeStatus(response)
        } catch FunctionsError.httpError(let code, _) where code == 401 {
            do {
                _ = try await client.auth.refreshSession()
                let response = try await invokeNudgeFunction(
                    groupID: groupID,
                    toUserID: toUserID,
                    habitID: habitID
                )
                return verifiedNudgeStatus(response)
            } catch FunctionsError.httpError(_, let retryData) {
                if let response = decodeNudgeResponse(fromErrorData: retryData) {
                    return verifiedNudgeStatus(response)
                }
                throw NSError(
                    domain: "SupabaseGroupsRepository",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
                )
            }
        } catch FunctionsError.httpError(_, let data) {
            if let response = decodeNudgeResponse(fromErrorData: data) {
                return response.status
            }
            throw NSError(
                domain: "SupabaseGroupsRepository",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not send reminder. Try again."]
            )
        }
    }

    private func fetchGroupRows() async throws -> [GroupRow] {
        do {
            let response = try await client
                .from("groups")
                .select("id, owner_id, name, code, join_locked, created_at")
                .order("created_at", ascending: true)
                .execute()
            return try decoder.decode([GroupRow].self, from: response.data)
        } catch {
            guard Self.isMissingJoinLockedColumnError(error) else {
                throw error
            }

            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "groups_fetch_rows_join_locked_fallback",
                    "error": error.localizedDescription
                ]
            )

            let fallbackResponse = try await client
                .from("groups")
                .select("id, owner_id, name, code, created_at")
                .order("created_at", ascending: true)
                .execute()
            return try decoder.decode([GroupRow].self, from: fallbackResponse.data)
        }
    }

    private func fetchGroupMembers(groupID: UUID) async throws -> [GroupMemberRow] {
        if supportsProgressDisplayModeColumn == false {
            let fallbackResponse = try await client
                .from("group_members")
                .select("group_id, user_id, joined_at")
                .eq("group_id", value: groupID)
                .execute()
            return try decoder.decode([GroupMemberRow].self, from: fallbackResponse.data)
        }

        do {
            let response = try await client
                .from("group_members")
                .select("group_id, user_id, progress_display_mode, joined_at")
                .eq("group_id", value: groupID)
                .execute()
            supportsProgressDisplayModeColumn = true
            return try decoder.decode([GroupMemberRow].self, from: response.data)
        } catch {
            guard Self.isMissingProgressDisplayModeColumnError(error) else {
                throw error
            }
            supportsProgressDisplayModeColumn = false

            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "groups_fetch_members_progress_mode_fallback",
                    "group_id": groupID.uuidString,
                    "error": error.localizedDescription
                ]
            )

            let fallbackResponse = try await client
                .from("group_members")
                .select("group_id, user_id")
                .eq("group_id", value: groupID)
                .execute()
            return try decoder.decode([GroupMemberRow].self, from: fallbackResponse.data)
        }
    }

    private func fetchGroupMembers(groupIDs: [UUID]) async throws -> [GroupMemberRow] {
        guard !groupIDs.isEmpty else { return [] }
        let values = groupIDs.map(\.uuidString)
        if supportsProgressDisplayModeColumn == false {
            let response = try await client
                .from("group_members")
                .select("group_id, user_id, joined_at")
                .in("group_id", values: values)
                .execute()
            return try decoder.decode([GroupMemberRow].self, from: response.data)
        }

        do {
            let response = try await client
                .from("group_members")
                .select("group_id, user_id, progress_display_mode, joined_at")
                .in("group_id", values: values)
                .execute()
            supportsProgressDisplayModeColumn = true
            return try decoder.decode([GroupMemberRow].self, from: response.data)
        } catch {
            guard Self.isMissingProgressDisplayModeColumnError(error) else { throw error }
            supportsProgressDisplayModeColumn = false
            let response = try await client
                .from("group_members")
                .select("group_id, user_id, joined_at")
                .in("group_id", values: values)
                .execute()
            return try decoder.decode([GroupMemberRow].self, from: response.data)
        }
    }

    private func fetchSharedHabits(groupID: UUID) async throws -> [GroupSharedHabitRow] {
        let response = try await client
            .from("group_shared_habits")
            .select("group_id, user_id, habit_id, shared")
            .eq("group_id", value: groupID)
            .execute()
        return try decoder.decode([GroupSharedHabitRow].self, from: response.data)
    }

    private func fetchSharedHabits(groupIDs: [UUID]) async throws -> [GroupSharedHabitRow] {
        guard !groupIDs.isEmpty else { return [] }
        let response = try await client
            .from("group_shared_habits")
            .select("group_id, user_id, habit_id, shared")
            .in("group_id", values: groupIDs.map(\.uuidString))
            .execute()
        return try decoder.decode([GroupSharedHabitRow].self, from: response.data)
    }

    private func fetchProfiles(userIDs: [UUID]) async throws -> [UUID: ResolvedProfile] {
        guard !userIDs.isEmpty else { return [:] }
        let response = try await client
            .from("profiles")
            .select("id, username, avatar_path, updated_at, time_zone, locale")
            .in("id", values: userIDs.map(\.uuidString))
            .execute()
        let rows = try decoder.decode([BatchProfileRow].self, from: response.data)
        return Dictionary(uniqueKeysWithValues: rows.map { row in
            let name = row.username?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = ResolvedProfile(
                name: (name?.isEmpty == false ? name : nil) ?? "Member",
                avatarURL: profileAvatarURL(
                    from: row.avatarPath,
                    updatedAt: row.updatedAtRaw.flatMap(Self.timestamp(from:))
                ),
                timeZone: row.timeZone.flatMap(TimeZone.init(identifier:)) ?? .current,
                locale: ["en", "ru", "kk"].contains(row.locale ?? "") ? row.locale ?? "en" : "en"
            )
            return (row.id, resolved)
        })
    }

    private func fetchHabits(habitIDs: [UUID]) async throws -> [UUID: HabitRow] {
        guard !habitIDs.isEmpty else { return [:] }
        let values = habitIDs.map(\.uuidString)
        let rows: [HabitRow]
        if supportsHabitContractColumns == false {
            let response = try await client
                .from("habits")
                .select("id, user_id, name, icon, type, target_count, schedule, weekdays, archived, created_at")
                .in("id", values: values)
                .execute()
            rows = try decoder.decode([HabitRow].self, from: response.data)
        } else {
            do {
                let response = try await client
                    .from("habits")
                    .select("id, user_id, name, icon, icon_key, preset_category, category_custom, type, target_count, schedule, weekdays, archived, created_at")
                    .in("id", values: values)
                    .execute()
                rows = try decoder.decode([HabitRow].self, from: response.data)
                supportsHabitContractColumns = true
            } catch {
                guard Self.isMissingHabitContractColumnError(error) else { throw error }
                supportsHabitContractColumns = false
                let response = try await client
                    .from("habits")
                    .select("id, user_id, name, icon, type, target_count, schedule, weekdays, archived, created_at")
                    .in("id", values: values)
                    .execute()
                rows = try decoder.decode([HabitRow].self, from: response.data)
            }
        }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
    }

    private func fetchCompletionHistories(
        habitIDs: [UUID],
        userIDs: [UUID],
        contextsByUserID: [UUID: DayContext]
    ) async throws -> [String: [HabitCompletion]] {
        guard !habitIDs.isEmpty, !userIDs.isEmpty else { return [:] }
        let windowStarts = contextsByUserID.values.map { context in
            let start = context.calendar.date(byAdding: .day, value: -370, to: context.today) ?? context.today
            return Self.syncDayDateString(for: start, calendar: context.calendar, timeZone: context.timeZone)
        }
        let earliestWindowStart = windowStarts.min() ?? "1970-01-01"
        let response = try await client
            .from("habit_completions")
            .select("habit_id, user_id, day_date, value, completed_at, updated_at")
            .in("habit_id", values: habitIDs.map(\.uuidString))
            .in("user_id", values: userIDs.map(\.uuidString))
            .gte("day_date", value: earliestWindowStart)
            .execute()
        let rows = try decoder.decode([BatchCompletionHistoryRow].self, from: response.data)
        var result: [String: [HabitCompletion]] = [:]
        for row in rows {
            guard let context = contextsByUserID[row.userID],
                  let dayDate = Self.syncDayDate(
                    row.dayDate,
                    calendar: context.calendar,
                    timeZone: context.timeZone
                  ) else {
                continue
            }
            let key = Self.completionPairKey(habitID: row.habitID, userID: row.userID)
            result[key, default: []].append(
                HabitCompletion(
                    habitID: row.habitID,
                    dayDate: dayDate,
                    value: row.value,
                    completedAt: row.completedAtRaw.flatMap(Self.timestamp(from:)),
                    updatedAt: Self.timestamp(from: row.updatedAtRaw) ?? .distantPast
                )
            )
        }
        return result
    }

    private func resolveProfile(for userID: UUID, cache: inout [UUID: ResolvedProfile]) async throws -> ResolvedProfile {
        if let cached = cache[userID] {
            return cached
        }

        let response = try await client
            .from("profiles")
            .select("username, avatar_path, updated_at, time_zone, locale")
            .eq("id", value: userID)
            .limit(1)
            .execute()

        let row = try decoder.decode([ProfileRow].self, from: response.data).first
        let name = row?.username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarURL = profileAvatarURL(from: row?.avatarPath, updatedAt: row?.updatedAt)
        let resolved = ResolvedProfile(
            name: (name?.isEmpty == false ? name : nil) ?? "Member",
            avatarURL: avatarURL,
            timeZone: row?.timeZone.flatMap(TimeZone.init(identifier:)) ?? .current,
            locale: ["en", "ru", "kk"].contains(row?.locale ?? "") ? row?.locale ?? "en" : "en"
        )
        cache[userID] = resolved
        return resolved
    }

    private func profileAvatarURL(from avatarPath: String?, updatedAt: Date?) -> URL? {
        guard let avatarPath, !avatarPath.isEmpty else {
            return nil
        }

        if avatarPath.lowercased().hasPrefix("http://") || avatarPath.lowercased().hasPrefix("https://") {
            return URL(string: avatarPath)
        }

        guard var publicURL = try? client.storage.from("avatars").getPublicURL(path: avatarPath, download: false) else {
            return nil
        }

        if let updatedAt {
            var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            queryItems.append(URLQueryItem(name: "v", value: String(Int(updatedAt.timeIntervalSince1970))))
            components?.queryItems = queryItems
            if let cacheBusted = components?.url {
                publicURL = cacheBusted
            }
        }

        return publicURL
    }

    private func resolveHabit(_ habitID: UUID, cache: inout [UUID: HabitRow]) async throws -> HabitRow? {
        if let cached = cache[habitID] {
            return cached
        }

        if supportsHabitContractColumns == false {
            let fallbackResponse = try await client
                .from("habits")
                .select("id, user_id, name, icon, type, target_count, schedule, weekdays, archived, created_at")
                .eq("id", value: habitID)
                .limit(1)
                .execute()
            let fallbackRow = try decoder.decode([HabitRow].self, from: fallbackResponse.data).first
            if let fallbackRow {
                cache[habitID] = fallbackRow
            }
            return fallbackRow
        }

        let response: PostgrestResponse<Void>
        do {
            response = try await client
                .from("habits")
                .select("id, user_id, name, icon, icon_key, preset_category, category_custom, type, target_count, schedule, weekdays, archived, created_at")
                .eq("id", value: habitID)
                .limit(1)
                .execute()
            supportsHabitContractColumns = true
        } catch {
            guard Self.isMissingHabitContractColumnError(error) else {
                throw error
            }
            supportsHabitContractColumns = false

            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "groups_resolve_habit_contract_fallback",
                    "habit_id": habitID.uuidString,
                    "error": error.localizedDescription
                ]
            )

            response = try await client
                .from("habits")
                .select("id, user_id, name, icon, type, target_count, schedule, weekdays, archived, created_at")
                .eq("id", value: habitID)
                .limit(1)
                .execute()
        }

        let row = try decoder.decode([HabitRow].self, from: response.data).first
        if let row {
            cache[habitID] = row
        }
        return row
    }

    private func resolveCompletion(
        for habit: HabitRow,
        userID: UUID,
        dayDate: String,
        cache: inout [String: Bool]
    ) async throws -> Bool {
        let cacheKey = "\(habit.id.uuidString)-\(userID.uuidString)-\(dayDate)"
        if let cached = cache[cacheKey] {
            return cached
        }

        let response = try await client
            .from("habit_completions")
            .select("value")
            .eq("habit_id", value: habit.id)
            .eq("user_id", value: userID)
            .eq("day_date", value: dayDate)
            .limit(1)
            .execute()

        let value = try decoder.decode([CompletionRow].self, from: response.data).first?.value ?? 0
        let isCompleted: Bool
        if habit.type == "binary" {
            isCompleted = value > 0
        } else if let target = habit.targetCount, target > 0 {
            isCompleted = value >= target
        } else {
            isCompleted = value > 0
        }

        cache[cacheKey] = isCompleted
        return isCompleted
    }

    private func resolveStreak(
        for habit: HabitRow,
        userID: UUID,
        context: DayContext,
        cache: inout [String: [HabitCompletion]]
    ) async throws -> Int {
        let completions = try await completionHistory(
            for: habit.id,
            userID: userID,
            context: context,
            cache: &cache
        )
        let domainHabit = makeDomainHabit(from: habit)
        return StreakCalculator.streak(
            for: domainHabit,
            completions: completions,
            context: context
        )
    }

    private func resolveRollingCompletionPercent(
        for habit: HabitRow,
        userID: UUID,
        groupCreatedAt: Date?,
        context: DayContext,
        cache: inout [String: [HabitCompletion]]
    ) async throws -> Int? {
        let completions = try await completionHistory(
            for: habit.id,
            userID: userID,
            context: context,
            cache: &cache
        )
        var domainHabit = makeDomainHabit(from: habit)
        if let groupCreatedAt {
            domainHabit.createdAt = max(domainHabit.createdAt, groupCreatedAt)
        }
        return HabitMetricsCalculator.rollingCompletionPercent(
            for: domainHabit,
            completions: completions,
            context: context,
            occurrenceLimit: 40
        )
    }

    private func completionHistory(
        for habitID: UUID,
        userID: UUID,
        context: DayContext,
        cache: inout [String: [HabitCompletion]]
    ) async throws -> [HabitCompletion] {
        let cacheKey = "\(habitID.uuidString)-\(userID.uuidString)"
        if let cached = cache[cacheKey] {
            return cached
        }
        let loaded = try await fetchCompletionHistory(for: habitID, userID: userID, context: context)
        cache[cacheKey] = loaded
        return loaded
    }

    private func fetchCompletionHistory(
        for habitID: UUID,
        userID: UUID,
        context: DayContext
    ) async throws -> [HabitCompletion] {
        let calendar = context.calendar
        let timeZone = context.timeZone
        let windowStart = Self.syncDayDateString(
            for: context.calendar.date(byAdding: .day, value: -370, to: context.today) ?? context.today,
            calendar: calendar,
            timeZone: timeZone
        )

        let response = try await client
            .from("habit_completions")
            .select("day_date, value, completed_at, updated_at")
            .eq("habit_id", value: habitID)
            .eq("user_id", value: userID)
            .gte("day_date", value: windowStart)
            .execute()

        let rows = try decoder.decode([CompletionHistoryRow].self, from: response.data)
        return rows.compactMap { row in
            guard let dayDate = Self.syncDayDate(row.dayDate, calendar: calendar, timeZone: timeZone) else {
                return nil
            }
            return HabitCompletion(
                habitID: habitID,
                dayDate: dayDate,
                value: row.value,
                completedAt: row.completedAtRaw.flatMap(Self.timestamp(from:)),
                updatedAt: Self.timestamp(from: row.updatedAtRaw) ?? Date.distantPast
            )
        }
    }

    private func makeDomainHabit(from row: HabitRow) -> Habit {
        let habitType = HabitType(rawValue: row.type) ?? .binary
        let scheduleValue: HabitSchedule
        if row.schedule == "weekly" {
            let weekdaysSet = Set((row.weekdays ?? []).compactMap(Weekday.fromISOWeekday))
            scheduleValue = .weekly(weekdaysSet)
        } else {
            scheduleValue = .daily
        }

        return Habit(
            id: row.id,
            name: row.name,
            icon: row.icon,
            iconKey: row.iconKey ?? row.icon,
            category: row.presetCategory ?? .spiritual,
            categoryCustom: row.categoryCustom,
            type: habitType,
            targetCount: row.targetCount,
            schedule: scheduleValue,
            archived: row.archived ?? false,
            createdAt: row.createdAtRaw.flatMap(Self.timestamp(from:)) ?? Date()
        )
    }

    private func requireCurrentUserID() async throws -> UUID {
        if let currentUser = client.auth.currentUser {
            return currentUser.id
        }
        if let session = try? await client.auth.session {
            return session.user.id
        }
        throw NSError(domain: "SupabaseGroupsRepository", code: 401, userInfo: [
            NSLocalizedDescriptionKey: "Not authenticated."
        ])
    }

    private static let utcTimeZone = TimeZone(secondsFromGMT: 0) ?? .current

    private static func laterDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (a?, b?): return max(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }

    private static func completionPairKey(habitID: UUID, userID: UUID) -> String {
        "\(habitID.uuidString.lowercased()):\(userID.uuidString.lowercased())"
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        return calendar
    }

    private static func utcDayDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = utcCalendar()
        formatter.timeZone = utcTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func syncDayDateString(for date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func syncDayDate(_ value: String, calendar: Calendar, timeZone: TimeZone) -> Date? {
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

    nonisolated private static func timestamp(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func decodeUUID(from data: Data) -> UUID? {
        if let value = try? JSONDecoder().decode(UUID.self, from: data) {
            return value
        }
        if let string = try? JSONDecoder().decode(String.self, from: data) {
            return UUID(uuidString: string)
        }
        if let wrapped = try? JSONDecoder().decode([String: String].self, from: data),
           let value = wrapped.values.first {
            return UUID(uuidString: value)
        }
        if let arrayWrapped = try? JSONDecoder().decode([String].self, from: data),
           let first = arrayWrapped.first {
            return UUID(uuidString: first)
        }
        return nil
    }

    private static func decodeString(from data: Data) -> String? {
        if let value = try? JSONDecoder().decode(String.self, from: data) {
            return value
        }
        if let wrapped = try? JSONDecoder().decode([String: String].self, from: data),
           let value = wrapped.values.first {
            return value
        }
        if let arrayWrapped = try? JSONDecoder().decode([String].self, from: data) {
            return arrayWrapped.first
        }
        return nil
    }

    private static func normalizedInviteCode(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func invokeNudgeFunction(
        groupID: UUID,
        toUserID: UUID,
        habitID: UUID
    ) async throws -> NudgeFunctionResponse {
        try await client.functions.invoke(
            "send-nudge-push",
            options: FunctionInvokeOptions(
                method: .post,
                body: [
                    "group_id": groupID.uuidString.lowercased(),
                    "to_user_id": toUserID.uuidString.lowercased(),
                    "habit_id": habitID.uuidString.lowercased()
                ]
            )
        )
    }

    private func decodeNudgeResponse(fromErrorData data: Data) -> NudgeFunctionResponse? {
        try? decoder.decode(NudgeFunctionResponse.self, from: data)
    }

    private func verifiedNudgeStatus(_ response: NudgeFunctionResponse) -> GroupNudgeStatus {
        if response.status == .delivered, response.delivered != true {
            return .recipientNotRegistered
        }
        return response.status
    }

    private func refreshGroupWithRetry(groupID: UUID, maxAttempts: Int = 6) async throws -> Group? {
        var attempt = 0
        while attempt < maxAttempts {
            if let group = try await refreshGroup(groupID: groupID) {
                return group
            }
            attempt += 1
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
        }
        return nil
    }

    private func resilientFallbackGroup(from row: GroupRow, currentUserID: UUID) async -> Group? {
        let members = (try? await fetchGroupMembers(groupID: row.id)) ?? []
        if members.isEmpty {
            return nil
        }

        let sharedRows = ((try? await fetchSharedHabits(groupID: row.id)) ?? []).filter(\.shared)
        let currentUserSharedHabitIDs = Set(
            sharedRows
                .filter { $0.userID == currentUserID }
                .map(\.habitID)
        )
        let sharedCountByMemberID = Dictionary(
            sharedRows.map { ($0.userID, 1) },
            uniquingKeysWith: +
        )

        var profilesByUserID: [UUID: ResolvedProfile] = [:]
        var mappedMembers: [GroupMember] = []
        mappedMembers.reserveCapacity(members.count)
        for member in members {
            let profile = (try? await resolveProfile(for: member.userID, cache: &profilesByUserID))
                ?? ResolvedProfile(name: "Member", avatarURL: nil, timeZone: .current, locale: "en")
            mappedMembers.append(
                GroupMember(
                    id: member.userID,
                    name: profile.name,
                    avatarURL: profile.avatarURL,
                    completedToday: 0,
                    totalSharedHabits: sharedCountByMemberID[member.userID] ?? 0,
                    sharedHabits: []
                )
            )
        }

        return Group(
            id: row.id,
            name: row.name,
            code: row.code,
            joinLocked: row.joinLocked ?? false,
            members: mappedMembers,
            sharedHabitIDs: currentUserSharedHabitIDs,
            ownerMemberID: row.ownerID,
            currentUserMemberID: currentUserID,
            progressDisplayMode: members.first(where: { $0.userID == currentUserID })?.progressDisplayMode ?? .percent
        )
    }

    private func minimalGroup(from row: GroupRow, currentUserID: UUID) -> Group {
        Group(
            id: row.id,
            name: row.name,
            code: row.code,
            joinLocked: row.joinLocked ?? false,
            members: [],
            sharedHabitIDs: [],
            ownerMemberID: row.ownerID,
            currentUserMemberID: currentUserID
        )
    }

    private func mapJoinError(_ error: Error) -> Error {
        let message = error.localizedDescription.lowercased()
        if message.contains("group join is locked") || message.contains("locked") {
            return NSError(
                domain: "SupabaseGroupsRepository",
                code: 423,
                userInfo: [NSLocalizedDescriptionKey: "This group is currently locked for joining."]
            )
        }
        if message.contains("invalid invite code") || message.contains("invite code") {
            return NSError(
                domain: "SupabaseGroupsRepository",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Invalid invite code."]
            )
        }
        return error
    }

    private static func isMissingJoinLockedColumnError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("join_locked")
            && (message.contains("does not exist")
                || message.contains("undefined column")
                || message.contains("42703"))
    }

    private static func isMissingProgressDisplayModeColumnError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("progress_display_mode")
            && (message.contains("does not exist")
                || message.contains("undefined column")
                || message.contains("42703"))
    }

    private static func isMissingProgressDisplayModeRPCFunctionError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("set_group_progress_display_mode")
            && (message.contains("pgrst202")
                || message.contains("schema cache")
                || message.contains("no matches were found")
                || message.contains("does not exist")
                || message.contains("undefined function")
                || message.contains("42883"))
    }

    private static func isMissingHabitContractColumnError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        let hasMissingColumnCode = message.contains("does not exist")
            || message.contains("undefined column")
            || message.contains("42703")
        guard hasMissingColumnCode else { return false }
        return message.contains("icon_key")
            || message.contains("preset_category")
            || message.contains("category_custom")
    }

}
