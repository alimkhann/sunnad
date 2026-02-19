import Foundation

protocol GroupsRepository: Sendable {
    func fetchGroups() async throws -> [Group]
    func replaceGroups(_ groups: [Group]) async throws
}
