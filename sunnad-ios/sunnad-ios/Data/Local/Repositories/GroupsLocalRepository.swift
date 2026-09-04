import Foundation

@MainActor
final class GroupsLocalRepository: GroupsRepository {
    private enum Keys {
        static let groups = "sunnad.local.groups.v3"
        static let snapshot = "sunnad.local.groups.snapshot.v3"
    }

    private let userDefaults: UserDefaults
    private let ownerScopeProvider: LocalOwnerScopeProviding?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        ownerScopeProvider: LocalOwnerScopeProviding? = nil
    ) {
        self.userDefaults = userDefaults
        self.ownerScopeProvider = ownerScopeProvider
    }

    func fetchGroups() async throws -> [Group] {
        guard let data = userDefaults.data(forKey: storageKey(prefix: Keys.groups)) else {
            return []
        }
        return try decoder.decode([Group].self, from: data)
    }

    func hasCachedSnapshot() -> Bool {
        userDefaults.bool(forKey: storageKey(prefix: Keys.snapshot))
    }

    func replaceGroups(_ groups: [Group]) throws {
        try persist(groups)
    }

    func upsertGroup(_ group: Group) throws {
        var groups = try fetchGroupsSync()
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        try persist(groups)
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

    func setProgressDisplayMode(groupID: UUID, mode: GroupProgressDisplayMode) async throws {
        try mutate(groupID: groupID) { group in
            group.progressDisplayMode = mode
        }
    }

    func refreshGroup(groupID: UUID) async throws -> Group? {
        try await fetchGroups().first(where: { $0.id == groupID })
    }

    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus {
        _ = (groupID, toUserID, habitID)
        return .recipientNotRegistered
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
        guard let data = userDefaults.data(forKey: storageKey(prefix: Keys.groups)) else {
            return []
        }
        return try decoder.decode([Group].self, from: data)
    }

    private func persist(_ groups: [Group]) throws {
        let data = try encoder.encode(groups)
        userDefaults.set(data, forKey: storageKey(prefix: Keys.groups))
        userDefaults.set(true, forKey: storageKey(prefix: Keys.snapshot))
    }

    private func storageKey(prefix: String) -> String {
        let scope = ownerScopeProvider?.currentOwnerScopeRawValue ?? LocalOwnerScope.guest.rawValue
        return "\(prefix).\(scope)"
    }
}

/// Keeps the last complete server snapshot available while the network is down.
/// Server-owned operations still fail honestly when they require authorization or delivery.
@MainActor
final class CachedGroupsRepository: GroupsRepository {
    private let remote: GroupsRepository
    private let cache: GroupsLocalRepository

    init(remote: GroupsRepository, cache: GroupsLocalRepository) {
        self.remote = remote
        self.cache = cache
    }

    func fetchGroups() async throws -> [Group] {
        do {
            let groups = try await remote.fetchGroups()
            try cache.replaceGroups(groups)
            return groups
        } catch {
            guard cache.hasCachedSnapshot() else { throw error }
            return try await cache.fetchGroups()
        }
    }

    func createGroup(name: String) async throws -> Group {
        let group = try await remote.createGroup(name: name)
        try? cache.upsertGroup(group)
        return group
    }

    func joinGroup(code: String) async throws -> Group {
        let group = try await remote.joinGroup(code: code)
        try? cache.upsertGroup(group)
        return group
    }

    func renameGroup(groupID: UUID, name: String) async throws {
        try await remote.renameGroup(groupID: groupID, name: name)
        try? await cache.renameGroup(groupID: groupID, name: name)
    }

    func setJoinLock(groupID: UUID, locked: Bool) async throws {
        try await remote.setJoinLock(groupID: groupID, locked: locked)
        try? await cache.setJoinLock(groupID: groupID, locked: locked)
    }

    func rotateInviteCode(groupID: UUID) async throws -> String {
        let code = try await remote.rotateInviteCode(groupID: groupID)
        await refreshCachedGroup(groupID: groupID)
        return code
    }

    func updateSharing(groupID: UUID, habitIDs: Set<UUID>) async throws {
        try await remote.updateSharing(groupID: groupID, habitIDs: habitIDs)
        try? await cache.updateSharing(groupID: groupID, habitIDs: habitIDs)
    }

    func leaveGroup(groupID: UUID) async throws {
        try await remote.leaveGroup(groupID: groupID)
        try? await cache.leaveGroup(groupID: groupID)
    }

    func deleteGroup(groupID: UUID) async throws {
        try await remote.deleteGroup(groupID: groupID)
        try? await cache.deleteGroup(groupID: groupID)
    }

    func kickMember(groupID: UUID, memberUserID: UUID) async throws {
        try await remote.kickMember(groupID: groupID, memberUserID: memberUserID)
        try? await cache.kickMember(groupID: groupID, memberUserID: memberUserID)
    }

    func setProgressDisplayMode(groupID: UUID, mode: GroupProgressDisplayMode) async throws {
        try await remote.setProgressDisplayMode(groupID: groupID, mode: mode)
        try? await cache.setProgressDisplayMode(groupID: groupID, mode: mode)
    }

    func refreshGroup(groupID: UUID) async throws -> Group? {
        do {
            let group = try await remote.refreshGroup(groupID: groupID)
            if let group {
                try? cache.upsertGroup(group)
            }
            return group
        } catch {
            guard cache.hasCachedSnapshot() else { throw error }
            return try await cache.refreshGroup(groupID: groupID)
        }
    }

    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus {
        try await remote.sendNudge(groupID: groupID, toUserID: toUserID, habitID: habitID)
    }

    private func refreshCachedGroup(groupID: UUID) async {
        guard let group = try? await remote.refreshGroup(groupID: groupID) else { return }
        try? cache.upsertGroup(group)
    }
}
