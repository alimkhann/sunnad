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

    private struct ProfileRow: Decodable {
        let username: String?
        let avatarPath: String?
        let updatedAtRaw: String?

        var updatedAt: Date? {
            Self.parseProfileTimestamp(updatedAtRaw)
        }

        enum CodingKeys: String, CodingKey {
            case username
            case avatarPath = "avatar_path"
            case updatedAtRaw = "updated_at"
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

    private struct ResolvedProfile {
        let name: String
        let avatarURL: URL?
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

    private struct NudgeFunctionPayload: Encodable {
        let groupID: UUID
        let toUserID: UUID
        let habitID: UUID

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case toUserID = "to_user_id"
            case habitID = "habit_id"
        }
    }

    private struct NudgeFunctionResponse: Decodable {
        let status: GroupNudgeStatus
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
        let metricsCalendar = Self.utcCalendar()
        let metricsTimeZone = Self.utcTimeZone

        var profilesByUserID: [UUID: ResolvedProfile] = [:]
        var habitsByID: [UUID: HabitRow] = [:]
        var completionCache: [String: Bool] = [:]
        var completionHistoryCache: [String: [HabitCompletion]] = [:]
        let todayDate = Self.utcDayDateString(for: Date())

        var groups: [Group] = []
        groups.reserveCapacity(groupRows.count)

        for groupRow in groupRows {
            do {
                let members = try await fetchGroupMembers(groupID: groupRow.id)
                let sharedRows = try await fetchSharedHabits(groupID: groupRow.id)

                let sharedForGroup = sharedRows.filter(\.shared)
                let currentUserSharedIDs = Set(
                    sharedForGroup
                        .filter { $0.userID == currentUserID }
                        .map(\.habitID)
                )

                var domainMembers: [GroupMember] = []
                domainMembers.reserveCapacity(members.count)

                for member in members {
                    let memberID = member.userID
                    let profile = (try? await resolveProfile(for: memberID, cache: &profilesByUserID))
                        ?? ResolvedProfile(name: "Member", avatarURL: nil)
                    let memberSharedRows = sharedForGroup.filter { $0.userID == memberID }

                    var memberSharedHabits: [SharedHabit] = []
                    memberSharedHabits.reserveCapacity(memberSharedRows.count)
                    var completedTodayDueCount = 0
                    var totalDueCount = 0

                    for shared in memberSharedRows {
                        if let habit = try await resolveHabit(shared.habitID, cache: &habitsByID) {
                            let domainHabit = makeDomainHabit(from: habit)
                            let completedToday = (try? await resolveCompletion(
                                for: habit,
                                userID: memberID,
                                dayDate: todayDate,
                                cache: &completionCache
                            )) ?? false
                            let streak = (try? await resolveStreak(
                                for: habit,
                                userID: memberID,
                                cache: &completionHistoryCache
                            )) ?? 0
                            let memberWindowStart = Self.laterDate(groupRow.createdAt, member.joinedAt)
                            let rollingCompletionPercent = (try? await resolveRollingCompletionPercent(
                                for: habit,
                                userID: memberID,
                                groupCreatedAt: memberWindowStart,
                                cache: &completionHistoryCache
                            )) ?? 0
                            if domainHabit.schedule.isDue(on: Date(), calendar: metricsCalendar, timeZone: metricsTimeZone) {
                                totalDueCount += 1
                                if completedToday {
                                    completedTodayDueCount += 1
                                }
                            }

                            memberSharedHabits.append(
                                SharedHabit(
                                    habitID: habit.id,
                                    title: habit.name,
                                    icon: habit.icon,
                                    completedToday: completedToday,
                                    dueToday: domainHabit.schedule.isDue(on: Date(), calendar: metricsCalendar, timeZone: metricsTimeZone),
                                    streak: streak,
                                    rollingCompletionPercent: rollingCompletionPercent
                                )
                            )
                        } else {
                            memberSharedHabits.append(
                                SharedHabit(
                                    habitID: shared.habitID,
                                    title: "Shared habit",
                                    icon: "star.fill",
                                    completedToday: false,
                                    dueToday: false,
                                    streak: 0,
                                    rollingCompletionPercent: 0
                                )
                            )
                        }
                    }

                    domainMembers.append(
                        GroupMember(
                            id: memberID,
                            name: profile.name,
                            avatarURL: profile.avatarURL,
                            completedToday: completedTodayDueCount,
                            totalSharedHabits: totalDueCount,
                            sharedHabits: memberSharedHabits
                        )
                    )
                }

                groups.append(
                    Group(
                        id: groupRow.id,
                        name: groupRow.name,
                        code: groupRow.code,
                        joinLocked: groupRow.joinLocked ?? false,
                        members: domainMembers,
                        sharedHabitIDs: currentUserSharedIDs,
                        ownerMemberID: groupRow.ownerID,
                        currentUserMemberID: currentUserID,
                        progressDisplayMode: members.first(where: { $0.userID == currentUserID })?.progressDisplayMode ?? .percent
                    )
                )
            } catch {
                logger.log(
                    .storageFailure,
                    metadata: [
                        "scope": "groups_fetch_enrichment",
                        "group_id": groupRow.id.uuidString,
                        "error": error.localizedDescription
                    ]
                )
                if let fallback = await resilientFallbackGroup(from: groupRow, currentUserID: currentUserID) {
                    groups.append(fallback)
                } else {
                    groups.append(minimalGroup(from: groupRow, currentUserID: currentUserID))
                }
            }
        }

        return groups
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
            .select("id, user_id, name, icon, icon_key, preset_category, category_custom, type, target_count, schedule, weekdays, archived")
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
                habitID: habitID,
                forceRefresh: false
            )
            logger.log(.syncFinished, metadata: ["scope": "groups_send_nudge", "status": response.status.rawValue])
            return response.status
        } catch FunctionsError.httpError(let code, _) where code == 401 {
            do {
                let response = try await invokeNudgeFunction(
                    groupID: groupID,
                    toUserID: toUserID,
                    habitID: habitID,
                    forceRefresh: true
                )
                logger.log(
                    .syncFinished,
                    metadata: [
                        "scope": "groups_send_nudge",
                        "status": response.status.rawValue,
                        "retry": "refresh_session"
                    ]
                )
                return response.status
            } catch FunctionsError.httpError(_, let retryData) {
                if let status = decodeNudgeStatus(fromErrorData: retryData) {
                    logger.log(
                        .syncFinished,
                        metadata: [
                            "scope": "groups_send_nudge",
                            "status": status.rawValue,
                            "retry": "refresh_session"
                        ]
                    )
                    return status
                }
                throw NSError(
                    domain: "SupabaseGroupsRepository",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
                )
            }
        } catch FunctionsError.httpError(_, let data) {
            if let status = decodeNudgeStatus(fromErrorData: data) {
                logger.log(.syncFinished, metadata: ["scope": "groups_send_nudge", "status": status.rawValue])
                return status
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

    private func fetchSharedHabits(groupID: UUID) async throws -> [GroupSharedHabitRow] {
        let response = try await client
            .from("group_shared_habits")
            .select("group_id, user_id, habit_id, shared")
            .eq("group_id", value: groupID)
            .execute()
        return try decoder.decode([GroupSharedHabitRow].self, from: response.data)
    }

    private func resolveProfile(for userID: UUID, cache: inout [UUID: ResolvedProfile]) async throws -> ResolvedProfile {
        if let cached = cache[userID] {
            return cached
        }

        let response = try await client
            .from("profiles")
            .select("username, avatar_path, updated_at")
            .eq("id", value: userID)
            .limit(1)
            .execute()

        let row = try decoder.decode([ProfileRow].self, from: response.data).first
        let name = row?.username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarURL = profileAvatarURL(from: row?.avatarPath, updatedAt: row?.updatedAt)
        let resolved = ResolvedProfile(
            name: (name?.isEmpty == false ? name : nil) ?? "Member",
            avatarURL: avatarURL
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
                .select("id, user_id, name, icon, type, target_count, schedule, weekdays, archived")
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
                .select("id, user_id, name, icon, icon_key, preset_category, category_custom, type, target_count, schedule, weekdays, archived")
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
                .select("id, user_id, name, icon, type, target_count, schedule, weekdays, archived")
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
        cache: inout [String: [HabitCompletion]]
    ) async throws -> Int {
        let completions = try await completionHistory(for: habit.id, userID: userID, cache: &cache)
        let domainHabit = makeDomainHabit(from: habit)
        return StreakCalculator.streak(
            for: domainHabit,
            completions: completions,
            asOf: Date(),
            calendar: Self.utcCalendar(),
            timeZone: Self.utcTimeZone
        )
    }

    private func resolveRollingCompletionPercent(
        for habit: HabitRow,
        userID: UUID,
        groupCreatedAt: Date?,
        cache: inout [String: [HabitCompletion]]
    ) async throws -> Int {
        let completions = try await completionHistory(for: habit.id, userID: userID, cache: &cache)
        let domainHabit = makeDomainHabit(from: habit)
        return Self.rollingCompletionPercent(
            for: domainHabit,
            completions: completions,
            groupCreatedAt: groupCreatedAt,
            asOf: Date(),
            calendar: Self.utcCalendar(),
            timeZone: Self.utcTimeZone
        )
    }

    private func completionHistory(
        for habitID: UUID,
        userID: UUID,
        cache: inout [String: [HabitCompletion]]
    ) async throws -> [HabitCompletion] {
        let cacheKey = "\(habitID.uuidString)-\(userID.uuidString)"
        if let cached = cache[cacheKey] {
            return cached
        }
        let loaded = try await fetchCompletionHistory(for: habitID, userID: userID)
        cache[cacheKey] = loaded
        return loaded
    }

    private func fetchCompletionHistory(for habitID: UUID, userID: UUID) async throws -> [HabitCompletion] {
        let calendar = Self.utcCalendar()
        let timeZone = Self.utcTimeZone
        let windowStart = Self.syncDayDateString(
            for: Date().addingTimeInterval(-40 * 24 * 60 * 60),
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

    private static func rollingCompletionPercent(
        for habit: Habit,
        completions: [HabitCompletion],
        groupCreatedAt: Date?,
        asOf: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Int {
        var normalizedCalendar = calendar
        normalizedCalendar.timeZone = timeZone
        let today = normalizedCalendar.startOfDay(for: asOf)
        let createdDay = normalizedCalendar.startOfDay(for: groupCreatedAt ?? today)
        let inclusiveAge = max((normalizedCalendar.dateComponents([.day], from: createdDay, to: today).day ?? 0) + 1, 1)
        let windowDays = min(inclusiveAge, 40)
        let windowStart = normalizedCalendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today

        var completionsByDay: [Date: HabitCompletion] = [:]
        for completion in completions {
            let day = normalizedCalendar.startOfDay(for: completion.dayDate)
            guard day >= windowStart, day <= today else { continue }
            if let existing = completionsByDay[day] {
                if completion.updatedAt >= existing.updatedAt {
                    completionsByDay[day] = completion
                }
            } else {
                completionsByDay[day] = completion
            }
        }

        var scheduledDays = 0
        var completedScheduledDays = 0

        for offset in 0..<windowDays {
            guard let day = normalizedCalendar.date(byAdding: .day, value: offset, to: windowStart) else {
                continue
            }
            guard habit.schedule.isDue(on: day, calendar: normalizedCalendar, timeZone: timeZone) else {
                continue
            }
            scheduledDays += 1
            if let completion = completionsByDay[normalizedCalendar.startOfDay(for: day)],
               completion.isCompleted(for: habit) {
                completedScheduledDays += 1
            }
        }

        guard scheduledDays > 0 else { return 0 }
        let percent = (Double(completedScheduledDays) / Double(scheduledDays)) * 100.0
        return Int(percent.rounded())
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
            archived: row.archived ?? false
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
        habitID: UUID,
        forceRefresh: Bool
    ) async throws -> NudgeFunctionResponse {
        let accessToken = try await resolveAccessToken(forceRefresh: forceRefresh)
        return try await client.functions.invoke(
            "send-nudge-push",
            options: FunctionInvokeOptions(
                method: .post,
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: NudgeFunctionPayload(groupID: groupID, toUserID: toUserID, habitID: habitID)
            )
        )
    }

    private func resolveAccessToken(forceRefresh: Bool) async throws -> String {
        if forceRefresh {
            return try await client.auth.refreshSession().accessToken
        }

        if let token = client.auth.currentSession?.accessToken, !token.isEmpty {
            return token
        }

        let session = try await client.auth.session
        return session.accessToken
    }

    private func decodeNudgeStatus(fromErrorData data: Data) -> GroupNudgeStatus? {
        guard let response = try? decoder.decode(NudgeFunctionResponse.self, from: data) else {
            return nil
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
                ?? ResolvedProfile(name: "Member", avatarURL: nil)
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
