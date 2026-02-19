import Foundation
import SwiftData

@Model
final class DiagnosticEventEntity {
    @Attribute(.unique) var id: UUID
    var event: String
    var metadata: String
    var createdAt: Date

    init(id: UUID = UUID(), event: String, metadata: String, createdAt: Date = Date()) {
        self.id = id
        self.event = event
        self.metadata = metadata
        self.createdAt = createdAt
    }
}
