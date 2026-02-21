import Foundation

@MainActor
final class GroupsLocalRepository: GroupsRepository {
    private enum Keys {
        static let groups = "sunnad.local.groups.v2"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func fetchGroups() async throws -> [Group] {
        guard let data = userDefaults.data(forKey: Keys.groups) else {
            return []
        }
        return try decoder.decode([Group].self, from: data)
    }

    func createGroup(name: String) async throws -> Group {
        var groups = try await fetchGroups()
        let me = GroupMember(name: "You", completedToday: 0, totalSharedHabits: 0, sharedHabits: [])
        let group = Group(
            name: name,
            code: String(UUID().uuidString.prefix(8)).uppercased(),
            joinLocked: false,
            members: [me],
            sharedHabitIDs: [],
            ownerMemberID: me.id,
            currentUserMemberID: me.id
        )
        groups.append(group)
        try persist(groups)
        return group
    }

    func joinGroup(code: String) async throws -> Group {
        var groups = try await fetchGroups()
        let me = GroupMember(name: "You", completedToday: 0, totalSharedHabits: 0, sharedHabits: [])
        let group = Group(
            name: "Group \(code.uppercased())",
            code: code.uppercased(),
            joinLocked: false,
            members: [me],
            sharedHabitIDs: [],
            ownerMemberID: me.id,
            currentUserMemberID: me.id
        )
        groups.append(group)
        try persist(groups)
        return group
    }

    func renameGroup(groupID: UUID, name: String) async throws {
        try mutate(groupID: groupID) { group in
            group.name = name
        }
    }

    func setJoinLock(groupID: UUID, locked: Bool) async throws {
        try mutate(groupID: groupID) { group in
            group.joinLocked = locked
        }
    }

    func rotateInviteCode(groupID: UUID) async throws -> String {
        let newCode = String(UUID().uuidString.prefix(8)).uppercased()
        try mutate(groupID: groupID) { group in
            group.code = newCode
        }
        return newCode
    }

    func updateSharing(groupID: UUID, habitIDs: Set<UUID>) async throws {
        try mutate(groupID: groupID) { group in
            group.sharedHabitIDs = habitIDs
        }
    }

    func leaveGroup(groupID: UUID) async throws {
        var groups = try await fetchGroups()
        groups.removeAll { $0.id == groupID }
        try persist(groups)
    }

    func deleteGroup(groupID: UUID) async throws {
        try await leaveGroup(groupID: groupID)
    }

    func kickMember(groupID: UUID, memberUserID: UUID) async throws {
        try mutate(groupID: groupID) { group in
            group.members.removeAll { $0.id == memberUserID }
        }
    }

    func refreshGroup(groupID: UUID) async throws -> Group? {
        try await fetchGroups().first(where: { $0.id == groupID })
    }

    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus {
        _ = (groupID, toUserID, habitID)
        return .sent
    }

    private func mutate(groupID: UUID, _ mutation: (inout Group) -> Void) throws {
        var groups = try fetchGroupsSync()
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        mutation(&groups[index])
        try persist(groups)
    }

    private func fetchGroupsSync() throws -> [Group] {
        guard let data = userDefaults.data(forKey: Keys.groups) else {
            return []
        }
        return try decoder.decode([Group].self, from: data)
    }

    private func persist(_ groups: [Group]) throws {
        let data = try encoder.encode(groups)
        userDefaults.set(data, forKey: Keys.groups)
    }
}
