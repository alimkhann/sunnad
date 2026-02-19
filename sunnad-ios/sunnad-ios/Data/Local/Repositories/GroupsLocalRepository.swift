import Foundation

@MainActor
final class GroupsLocalRepository: GroupsRepository {
    private enum Keys {
        static let groups = "sunnad.local.groups.v1"
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

    func replaceGroups(_ groups: [Group]) async throws {
        let data = try encoder.encode(groups)
        userDefaults.set(data, forKey: Keys.groups)
    }
}
