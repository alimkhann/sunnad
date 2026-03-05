import Foundation

protocol GroupsRepository: Sendable {
    func fetchGroups() async throws -> [Group]
    func createGroup(name: String) async throws -> Group
    func joinGroup(code: String) async throws -> Group
    func renameGroup(groupID: UUID, name: String) async throws
    func setJoinLock(groupID: UUID, locked: Bool) async throws
    func rotateInviteCode(groupID: UUID) async throws -> String
    func updateSharing(groupID: UUID, habitIDs: Set<UUID>) async throws
    func leaveGroup(groupID: UUID) async throws
    func deleteGroup(groupID: UUID) async throws
    func kickMember(groupID: UUID, memberUserID: UUID) async throws
    func setProgressDisplayMode(groupID: UUID, mode: GroupProgressDisplayMode) async throws
    func refreshGroup(groupID: UUID) async throws -> Group?
    func sendNudge(groupID: UUID, toUserID: UUID, habitID: UUID) async throws -> GroupNudgeStatus
}
