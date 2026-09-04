import Foundation
import SwiftData

@Model
final class CompletionEntity {
    @Attribute(.unique) var id: String
    var ownerScope: String = "guest"
    var habitID: UUID
    var dayDate: Date
    var value: Int
    var completedAt: Date?
    var updatedAt: Date
    var entrySourceRaw: String = CompletionEntrySource.normal.rawValue

    init(
        id: String,
        ownerScope: String,
        habitID: UUID,
        dayDate: Date,
        value: Int,
        completedAt: Date?,
        updatedAt: Date,
        entrySourceRaw: String = CompletionEntrySource.normal.rawValue
    ) {
        self.id = id
        self.ownerScope = ownerScope
        self.habitID = habitID
        self.dayDate = dayDate
        self.value = value
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.entrySourceRaw = entrySourceRaw
    }
}

extension CompletionEntity {
    func apply(_ completion: HabitCompletion, key: String, ownerScope: String) {
        id = key
        self.ownerScope = ownerScope
        habitID = completion.habitID
        dayDate = completion.dayDate
        value = completion.value
        completedAt = completion.completedAt
        updatedAt = completion.updatedAt
        entrySourceRaw = completion.entrySource.rawValue
    }

    func asDomainCompletion() -> HabitCompletion {
        HabitCompletion(
            habitID: habitID,
            dayDate: dayDate,
            value: value,
            completedAt: completedAt,
            updatedAt: updatedAt,
            entrySource: CompletionEntrySource(rawValue: entrySourceRaw) ?? .normal
        )
    }
}
