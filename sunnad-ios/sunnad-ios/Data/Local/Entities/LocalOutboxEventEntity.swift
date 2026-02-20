import Foundation
import SwiftData

@Model
final class LocalOutboxEventEntity {
    @Attribute(.unique) var id: UUID
    var type: String
    var payloadJSON: String
    var createdAt: Date
    var attemptCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        type: String,
        payloadJSON: String,
        createdAt: Date = Date(),
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.type = type
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}
