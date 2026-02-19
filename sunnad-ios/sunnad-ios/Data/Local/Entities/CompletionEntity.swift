import Foundation
import SwiftData

@Model
final class CompletionEntity {
    @Attribute(.unique) var id: String
    var habitID: UUID
    var dayDate: Date
    var value: Int
    var completedAt: Date?
    var updatedAt: Date

    init(
        id: String,
        habitID: UUID,
        dayDate: Date,
        value: Int,
        completedAt: Date?,
        updatedAt: Date
    ) {
        self.id = id
        self.habitID = habitID
        self.dayDate = dayDate
        self.value = value
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}

extension CompletionEntity {
    func apply(_ completion: HabitCompletion, key: String) {
        id = key
        habitID = completion.habitID
        dayDate = completion.dayDate
        value = completion.value
        completedAt = completion.completedAt
        updatedAt = completion.updatedAt
    }

    func asDomainCompletion() -> HabitCompletion {
        HabitCompletion(
            habitID: habitID,
            dayDate: dayDate,
            value: value,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
    }
}
