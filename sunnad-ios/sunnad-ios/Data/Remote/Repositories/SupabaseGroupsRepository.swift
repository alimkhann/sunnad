import Foundation
import Supabase

final class SupabaseGroupsRepository: GroupsRepository, @unchecked Sendable {
    private struct GroupRow: Decodable {
        let id: UUID
        let ownerID: UUID
        let name: String
        let code: String
        let joinLocked: Bool?

        enum CodingKeys: String, CodingKey {
            case id
            case ownerID = "owner_id"
            case name
            case code
            case joinLocked = "join_locked"
        }
    }

    private struct GroupMemberRow: Decodable {
        let groupID: UUID
        let userID: UUID

        enum CodingKeys: String, CodingKey {
            case groupID = "group_id"
            case userID = "user_id"
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
        let type: String
        let targetCount: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case userID = "user_id"
            case name
            case icon
            case type
            case targetCount = "target_count"
        }
    }

    private struct CompletionRow: Decodable {
        let value: Int
    }

    private struct ProfileRow: Decodable {
        let username: String?
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

    init(client: SupabaseClient, logger: AnalyticsLogging) {
        self.client = client
        self.logger = logger
    }

    func fetchGroups() async throws -> [Group] {
        let currentUserID = try await requireCurrentUserID()
        let groupRows = try await fetchGroupRows()

        var profileNames: [UUID: String] = [:]
        var habitsByID: [UUID: HabitRow] = [:]
        var completionCache: [String: Bool] = [:]
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
                    let memberName = try await resolveProfileName(for: memberID, cache: &profileNames)
                    let memberSharedRows = sharedForGroup.filter { $0.userID == memberID }

                    var memberSharedHabits: [SharedHabit] = []
                    memberSharedHabits.reserveCapacity(memberSharedRows.count)

                    for shared in memberSharedRows {
                        guard let habit = try await resolveHabit(shared.habitID, cache: &habitsByID) else {
                            continue
                        }

                        let completedToday = try await resolveCompletion(
                            for: habit,
                            userID: memberID,
                            dayDate: todayDate,
                            cache: &completionCache
                        )

                        memberSharedHabits.append(
                            SharedHabit(
                                habitID: habit.id,
                                title: habit.name,
                                icon: habit.icon,
                                completedToday: completedToday,
                                streak: 0
                            )
                        )
                    }

                    domainMembers.append(
                        GroupMember(
                            id: memberID,
                            name: memberName,
                            completedToday: memberSharedHabits.filter(\.completedToday).count,
                            totalSharedHabits: memberSharedHabits.count,
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
                        currentUserMemberID: currentUserID
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
                groups.append(minimalGroup(from: groupRow, currentUserID: currentUserID))
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

        try await client
            .from("group_shared_habits")
            .update(["shared": AnyJSON.bool(false)])
            .eq("group_id", value: groupID)
            .eq("user_id", value: currentUserID)
            .execute()

        guard !habitIDs.isEmpty else {
            return
        }

        let rows = habitIDs.map {
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

    func refreshGroup(groupID: UUID) async throws -> Group? {
        let groups = try await fetchGroups()
        return groups.first(where: { $0.id == groupID })
    }

    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus {
        let response: NudgeFunctionResponse = try await client.functions.invoke(
            "send-nudge-push",
            options: FunctionInvokeOptions(
                method: .post,
                body: NudgeFunctionPayload(groupID: groupID, toUserID: toUserID, habitID: habitID)
            )
        )
        logger.log(.syncFinished, metadata: ["scope": "groups_send_nudge", "status": response.status.rawValue])
        return response.status
    }

    private func fetchGroupRows() async throws -> [GroupRow] {
        let response = try await client
            .from("groups")
            .select("id, owner_id, name, code, join_locked")
            .order("created_at", ascending: true)
            .execute()
        return try decoder.decode([GroupRow].self, from: response.data)
    }

    private func fetchGroupMembers(groupID: UUID) async throws -> [GroupMemberRow] {
        let response = try await client
            .from("group_members")
            .select("group_id, user_id")
            .eq("group_id", value: groupID)
            .execute()
        return try decoder.decode([GroupMemberRow].self, from: response.data)
    }

    private func fetchSharedHabits(groupID: UUID) async throws -> [GroupSharedHabitRow] {
        let response = try await client
            .from("group_shared_habits")
            .select("group_id, user_id, habit_id, shared")
            .eq("group_id", value: groupID)
            .execute()
        return try decoder.decode([GroupSharedHabitRow].self, from: response.data)
    }

    private func resolveProfileName(for userID: UUID, cache: inout [UUID: String]) async throws -> String {
        if let cached = cache[userID] {
            return cached
        }

        let response = try await client
            .from("profiles")
            .select("username")
            .eq("id", value: userID)
            .limit(1)
            .execute()

        let row = try decoder.decode([ProfileRow].self, from: response.data).first
        let name = row?.username?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = (name?.isEmpty == false ? name : nil) ?? "Member"
        cache[userID] = resolved
        return resolved
    }

    private func resolveHabit(_ habitID: UUID, cache: inout [UUID: HabitRow]) async throws -> HabitRow? {
        if let cached = cache[habitID] {
            return cached
        }

        let response = try await client
            .from("habits")
            .select("id, user_id, name, icon, type, target_count")
            .eq("id", value: habitID)
            .limit(1)
            .execute()

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

    private static func utcDayDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
}
