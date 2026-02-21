import Foundation
import SwiftData

@Model
final class HabitEntity {
    var id: UUID
    var ownerScope: String = "guest"
    var name: String
    var icon: String
    var categoryRaw: String
    var typeRaw: String
    var targetCount: Int?
    var scheduleFrequency: String
    var weekdaysISO: String
    var reminderHour: Int?
    var reminderMinute: Int?
    var selectedDhikrKey: String?
    var dhikrCountsJSON: String?
    var sortOrder: Int
    var archived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        ownerScope: String,
        name: String,
        icon: String,
        categoryRaw: String,
        typeRaw: String,
        targetCount: Int?,
        scheduleFrequency: String,
        weekdaysISO: String,
        reminderHour: Int?,
        reminderMinute: Int?,
        selectedDhikrKey: String?,
        dhikrCountsJSON: String?,
        sortOrder: Int,
        archived: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ownerScope = ownerScope
        self.name = name
        self.icon = icon
        self.categoryRaw = categoryRaw
        self.typeRaw = typeRaw
        self.targetCount = targetCount
        self.scheduleFrequency = scheduleFrequency
        self.weekdaysISO = weekdaysISO
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.selectedDhikrKey = selectedDhikrKey
        self.dhikrCountsJSON = dhikrCountsJSON
        self.sortOrder = sortOrder
        self.archived = archived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

}

extension HabitEntity {
    func apply(_ habit: Habit, ownerScope: String) {
        name = habit.name
        icon = habit.icon
        self.ownerScope = ownerScope
        categoryRaw = habit.category.rawValue
        typeRaw = habit.type.rawValue
        targetCount = habit.targetCount
        scheduleFrequency = habit.schedule.frequencyRaw
        weekdaysISO = habit.schedule.weekdayCSV
        reminderHour = habit.reminder?.hour
        reminderMinute = habit.reminder?.minute
        selectedDhikrKey = habit.selectedDhikrKey
        dhikrCountsJSON = habit.dhikrCountsByKey.dhikrCountsJSONString
        sortOrder = habit.sortOrder
        archived = habit.archived
        createdAt = habit.createdAt
        updatedAt = habit.updatedAt
    }

    func asDomainHabit() -> Habit {
        Habit(
            id: id,
            name: name,
            icon: icon,
            category: HabitCategoryValue(rawValue: categoryRaw) ?? .spiritual,
            type: HabitType(rawValue: typeRaw) ?? .binary,
            targetCount: targetCount,
            schedule: HabitSchedule.fromStorage(frequency: scheduleFrequency, weekdayCSV: weekdaysISO),
            reminder: HabitReminder.fromStorage(hour: reminderHour, minute: reminderMinute),
            selectedDhikrKey: selectedDhikrKey ?? Habit.defaultDhikrKey,
            dhikrCountsByKey: (dhikrCountsJSON ?? "{}").decodedDhikrCounts,
            sortOrder: sortOrder,
            archived: archived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private extension HabitSchedule {
    static func fromStorage(frequency: String, weekdayCSV: String) -> HabitSchedule {
        if frequency == "weekly" {
            let weekdays = Set(
                weekdayCSV
                    .split(separator: ",")
                    .compactMap { Int($0) }
                    .compactMap { Weekday.fromISOWeekday($0) }
            )
            return .weekly(weekdays)
        }
        return .daily
    }

    var frequencyRaw: String {
        switch self {
        case .daily:
            return "daily"
        case .weekly:
            return "weekly"
        }
    }

    var weekdayCSV: String {
        switch self {
        case .daily:
            return ""
        case .weekly(let weekdays):
            return weekdays
                .map(\.rawValue)
                .sorted()
                .map(String.init)
                .joined(separator: ",")
        }
    }
}

private extension HabitReminder {
    static func fromStorage(hour: Int?, minute: Int?) -> HabitReminder? {
        guard let hour, let minute else {
            return nil
        }
        return HabitReminder(hour: hour, minute: minute)
    }
}

private extension Dictionary where Key == String, Value == Int {
    var dhikrCountsJSONString: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

private extension String {
    var decodedDhikrCounts: [String: Int] {
        guard let data = data(using: .utf8),
              let value = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return value
    }
}
