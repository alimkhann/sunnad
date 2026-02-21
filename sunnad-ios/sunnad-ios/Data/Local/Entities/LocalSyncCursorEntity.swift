import Foundation
import SwiftData

@Model
final class LocalSyncCursorEntity {
    var ownerScope: String = "guest"
    var resource: String = ""
    var lastPulledAt: Date

    init(ownerScope: String, resource: String, lastPulledAt: Date) {
        self.ownerScope = ownerScope
        self.resource = resource
        self.lastPulledAt = lastPulledAt
    }
}
