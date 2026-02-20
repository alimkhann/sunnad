import Foundation
import SwiftData

@Model
final class LocalGroupSyncEntity {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var name: String
    var code: String
    var joinLocked: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        ownerID: UUID,
        name: String,
        code: String,
        joinLocked: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.code = code
        self.joinLocked = joinLocked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
