import Foundation
import SwiftData

@Model
final class LocalGroupMemberSyncEntity {
    @Attribute(.unique) var id: String
    var groupID: UUID
    var userID: UUID
    var role: String
    var updatedAt: Date

    init(
        id: String,
        groupID: UUID,
        userID: UUID,
        role: String,
        updatedAt: Date
    ) {
        self.id = id
        self.groupID = groupID
        self.userID = userID
        self.role = role
        self.updatedAt = updatedAt
    }
}
