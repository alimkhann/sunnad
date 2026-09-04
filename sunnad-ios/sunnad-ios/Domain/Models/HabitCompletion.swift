import Foundation

enum CompletionEntrySource: String, Codable, Hashable, Sendable {
    case normal
    case lateCheckIn = "late_check_in"
}

struct HabitCompletion: Codable, Hashable, Sendable {
    var habitID: UUID
    var dayDate: Date
    var value: Int
    var completedAt: Date?
    var updatedAt: Date
    var entrySource: CompletionEntrySource

    init(
        habitID: UUID,
        dayDate: Date,
        value: Int,
        completedAt: Date? = nil,
        updatedAt: Date = Date(),
        entrySource: CompletionEntrySource = .normal
    ) {
        self.habitID = habitID
        self.dayDate = dayDate
        self.value = value
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.entrySource = entrySource
    }

    func isValid(for habit: Habit) -> Bool {
        switch habit.type {
        case .binary:
            return value == 0 || value == 1
        case .dhikr:
            return value >= 0
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
            copy.value = max(value, 0)
        }

        return copy
    }
}
