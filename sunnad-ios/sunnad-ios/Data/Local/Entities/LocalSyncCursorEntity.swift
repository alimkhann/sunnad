import Foundation
import SwiftData

@Model
final class LocalSyncCursorEntity {
    @Attribute(.unique) var resource: String
    var lastPulledAt: Date

    init(resource: String, lastPulledAt: Date) {
        self.resource = resource
        self.lastPulledAt = lastPulledAt
    }
}
