import Foundation

struct HabitCompletion: Codable, Hashable, Sendable {
    var habitID: UUID
    var dayDate: Date
    var value: Int
    var completedAt: Date?
    var updatedAt: Date

    init(
        habitID: UUID,
        dayDate: Date,
        value: Int,
        completedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.habitID = habitID
        self.dayDate = dayDate
        self.value = value
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }

    func isValid(for habit: Habit) -> Bool {
        switch habit.type {
        case .binary:
            return value == 0 || value == 1
        case .dhikr:
            return value >= 0 && value <= habit.normalizedTargetCount
        }
    }

    func isCompleted(for habit: Habit) -> Bool {
        switch habit.type {
        case .binary:
            return value == 1
        case .dhikr:
            return value >= habit.normalizedTargetCount
        }
    }

    func clamped(for habit: Habit) -> HabitCompletion {
        var copy = self

        switch habit.type {
        case .binary:
            copy.value = value <= 0 ? 0 : 1
        case .dhikr:
            copy.value = min(max(value, 0), habit.normalizedTargetCount)
        }

        return copy
    }
}
