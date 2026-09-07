import Foundation

struct TodaySnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var dateKey: String
    var timeZoneID: String
    var habits: [HabitSnapshot]
    var groups: [GroupSnapshot]
    var sessionExpired: Bool?
    var failedNudgeMemberIDs: [UUID]?

    var completedCount: Int {
        habits.filter(\.completedToday).count
    }

    var totalCount: Int {
        habits.count
    }

    init(
        version: Int = TodaySnapshot.currentVersion,
        dateKey: String,
        timeZoneID: String,
        habits: [HabitSnapshot],
        groups: [GroupSnapshot],
        sessionExpired: Bool? = nil,
        failedNudgeMemberIDs: [UUID]? = nil
    ) {
        self.version = version
        self.dateKey = dateKey
        self.timeZoneID = timeZoneID
        self.habits = habits
        self.groups = groups
        self.sessionExpired = sessionExpired
        self.failedNudgeMemberIDs = failedNudgeMemberIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        guard decodedVersion <= TodaySnapshot.currentVersion else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Snapshot version \(decodedVersion) is newer than supported \(TodaySnapshot.currentVersion)"
            ))
        }
        version = TodaySnapshot.currentVersion
        dateKey = try container.decodeIfPresent(String.self, forKey: .dateKey) ?? ""
        timeZoneID = try container.decodeIfPresent(String.self, forKey: .timeZoneID) ?? TimeZone.current.identifier
        habits = try container.decodeIfPresent([HabitSnapshot].self, forKey: .habits) ?? []
        groups = try container.decodeIfPresent([GroupSnapshot].self, forKey: .groups) ?? []
        sessionExpired = try container.decodeIfPresent(Bool.self, forKey: .sessionExpired)
        failedNudgeMemberIDs = try container.decodeIfPresent([UUID].self, forKey: .failedNudgeMemberIDs)
    }
}

struct HabitSnapshot: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var icon: String
    var isDhikr: Bool
    var dhikrCount: Int
    var targetCount: Int
    var completedToday: Bool
    var streak: Int

    init(
        id: UUID,
        title: String,
        icon: String,
        isDhikr: Bool,
        dhikrCount: Int,
        targetCount: Int,
        completedToday: Bool,
        streak: Int
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isDhikr = isDhikr
        self.dhikrCount = dhikrCount
        self.targetCount = targetCount
        self.completedToday = completedToday
        self.streak = streak
    }
}

struct GroupSnapshot: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var members: [MemberSnapshot]
    var sentNudgeMemberIDs: [UUID]

    init(
        id: UUID,
        name: String,
        members: [MemberSnapshot],
        sentNudgeMemberIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.sentNudgeMemberIDs = sentNudgeMemberIDs
    }
}

struct MemberSnapshot: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var avatarPath: String?
    var habits: [HabitMini]

    var completedCount: Int {
        habits.filter(\.completed).count
    }

    init(
        id: UUID,
        name: String,
        avatarPath: String? = nil,
        habits: [HabitMini]
    ) {
        self.id = id
        self.name = name
        self.avatarPath = avatarPath
        self.habits = habits
    }
}

struct HabitMini: Codable, Equatable, Sendable {
    var habitID: UUID
    var title: String
    var completed: Bool

    init(habitID: UUID, title: String, completed: Bool) {
        self.habitID = habitID
        self.title = title
        self.completed = completed
    }
}
