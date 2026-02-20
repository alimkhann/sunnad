import Foundation
import SwiftData

@Model
final class LocalGroupSharedHabitSyncEntity {
    @Attribute(.unique) var id: String
    var groupID: UUID
    var userID: UUID
    var habitID: UUID
    var shared: Bool
    var updatedAt: Date

    init(
        id: String,
        groupID: UUID,
        userID: UUID,
        habitID: UUID,
        shared: Bool,
        updatedAt: Date
    ) {
        self.id = id
        self.groupID = groupID
        self.userID = userID
        self.habitID = habitID
        self.shared = shared
        self.updatedAt = updatedAt
    }
}
