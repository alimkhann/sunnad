import Foundation
import SwiftData

@Model
final class LocalOutboxEventEntity {
    @Attribute(.unique) var id: UUID
    var ownerScope: String = "guest"
    var type: String
    var payloadJSON: String
    var createdAt: Date
    var attemptCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        ownerScope: String,
        type: String,
        payloadJSON: String,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.ownerScope = ownerScope
        self.type = type
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}
