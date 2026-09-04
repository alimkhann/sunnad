import Foundation
import Testing
@testable import sunnad_ios

@MainActor
struct GroupsCacheRepositoryTests {
    @Test
    func returnsTheLastServerSnapshotWhenRefreshIsOffline() async throws {
        let suiteName = "sunnad.tests.groups-cache.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let owner = LocalOwnerScopeResolver(namespace: suiteName, userDefaults: defaults)
        owner.setSignedInUserID(UUID())
        let expected = makeGroup(name: "Family")
        let remote = GroupsCacheRemote(groups: [expected])
        let cache = GroupsLocalRepository(userDefaults: defaults, ownerScopeProvider: owner)
        let repository = CachedGroupsRepository(remote: remote, cache: cache)

        #expect(try await repository.fetchGroups() == [expected])
        remote.shouldFailFetch = true
        #expect(try await repository.fetchGroups() == [expected])
    }

    @Test
    func keepsCachedGroupsSeparateForEachAccount() async throws {
        let suiteName = "sunnad.tests.groups-scope.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let owner = LocalOwnerScopeResolver(namespace: suiteName, userDefaults: defaults)
        let firstUserID = UUID()
        owner.setSignedInUserID(firstUserID)
        let remote = GroupsCacheRemote(groups: [makeGroup(name: "First account")])
        let cache = GroupsLocalRepository(userDefaults: defaults, ownerScopeProvider: owner)
        let repository = CachedGroupsRepository(remote: remote, cache: cache)
        _ = try await repository.fetchGroups()

        owner.setSignedInUserID(UUID())
        remote.shouldFailFetch = true
        var didThrow = false
        do {
            _ = try await repository.fetchGroups()
        } catch {
            didThrow = true
        }

        #expect(didThrow)
    }

    private func makeGroup(name: String) -> Group {
        let member = GroupMember(
            name: "Member",
            completedToday: 0,
            totalSharedHabits: 0,
            sharedHabits: []
        )
        return Group(
            name: name,
            code: "ABC123",
            members: [member],
            sharedHabitIDs: [],
            ownerMemberID: member.id,
            currentUserMemberID: member.id
        )
    }
}

@MainActor
private final class GroupsCacheRemote: GroupsRepository {
    var groups: [Group]
    var shouldFailFetch = false

    init(groups: [Group]) {
        self.groups = groups
    }

    func fetchGroups() async throws -> [Group] {
        if shouldFailFetch { throw URLError(.notConnectedToInternet) }
        return groups
    }

    func createGroup(name: String) async throws -> Group {
        let member = GroupMember(name: "Member", completedToday: 0, totalSharedHabits: 0, sharedHabits: [])
        let group = Group(name: name, code: "ABC123", members: [member], sharedHabitIDs: [])
        groups.append(group)
        return group
    }

    func joinGroup(code: String) async throws -> Group { try await createGroup(name: code) }
    func renameGroup(groupID: UUID, name: String) async throws { mutate(groupID) { $0.name = name } }
    func setJoinLock(groupID: UUID, locked: Bool) async throws { mutate(groupID) { $0.joinLocked = locked } }
    func rotateInviteCode(groupID: UUID) async throws -> String { "NEWCODE" }
    func updateSharing(groupID: UUID, habitIDs: Set<UUID>) async throws { mutate(groupID) { $0.sharedHabitIDs = habitIDs } }
    func leaveGroup(groupID: UUID) async throws { groups.removeAll { $0.id == groupID } }
    func deleteGroup(groupID: UUID) async throws { try await leaveGroup(groupID: groupID) }
    func kickMember(groupID: UUID, memberUserID: UUID) async throws {
        mutate(groupID) { $0.members.removeAll { $0.id == memberUserID } }
    }
    func setProgressDisplayMode(groupID: UUID, mode: GroupProgressDisplayMode) async throws {
        mutate(groupID) { $0.progressDisplayMode = mode }
    }
    func refreshGroup(groupID: UUID) async throws -> Group? {
        if shouldFailFetch { throw URLError(.notConnectedToInternet) }
        return groups.first { $0.id == groupID }
    }
    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus {
        .delivered
    }

    private func mutate(_ groupID: UUID, mutation: (inout Group) -> Void) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        mutation(&groups[index])
    }
}
