import Combine
import Foundation

enum GroupNudgeStatus: String, Codable, Hashable, Sendable {
    case sent
    case duplicate
    case forbidden
    case error
}

struct SharedHabit: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var habitID: UUID
    var title: String
    var icon: String
    var completedToday: Bool
    var streak: Int

    init(
        id: UUID = UUID(),
        habitID: UUID,
        title: String,
        icon: String,
        completedToday: Bool,
        streak: Int
    ) {
        self.id = id
        self.habitID = habitID
        self.title = title
        self.icon = icon
        self.completedToday = completedToday
        self.streak = streak
    }
}

struct GroupMember: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var avatarURL: URL?
    var completedToday: Int
    var totalSharedHabits: Int
    var sharedHabits: [SharedHabit]

    init(
        id: UUID = UUID(),
        name: String,
        avatarURL: URL? = nil,
        completedToday: Int,
        totalSharedHabits: Int,
        sharedHabits: [SharedHabit]
    ) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.completedToday = completedToday
        self.totalSharedHabits = totalSharedHabits
        self.sharedHabits = sharedHabits
    }
}

struct Group: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var code: String
    var joinLocked: Bool
    var members: [GroupMember]
    var sharedHabitIDs: Set<UUID>
    var ownerMemberID: UUID
    var currentUserMemberID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        code: String,
        joinLocked: Bool = false,
        members: [GroupMember],
        sharedHabitIDs: Set<UUID>,
        ownerMemberID: UUID? = nil,
        currentUserMemberID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.code = code
        self.joinLocked = joinLocked
        self.members = members
        self.sharedHabitIDs = sharedHabitIDs
        self.ownerMemberID = ownerMemberID ?? members.first?.id ?? UUID()
        self.currentUserMemberID = currentUserMemberID
    }
}

struct Nudge: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var groupID: UUID
    var fromUserID: UUID
    var toUserID: UUID
    var habitID: UUID
    var day: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        groupID: UUID,
        fromUserID: UUID,
        toUserID: UUID,
        habitID: UUID,
        day: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupID = groupID
        self.fromUserID = fromUserID
        self.toUserID = toUserID
        self.habitID = habitID
        self.day = day
        self.createdAt = createdAt
    }
}
