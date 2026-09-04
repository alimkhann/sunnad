import Foundation
import SwiftData

@Model
final class HabitEntity {
    var id: UUID
    var ownerScope: String = "guest"
    var name: String
    var icon: String
    var iconKey: String?
    var categoryRaw: String
    var categoryCustom: String?
    var typeRaw: String
    var targetCount: Int?
    var scheduleFrequency: String
    var weekdaysISO: String
    var reminderHour: Int?
    var reminderMinute: Int?
    var selectedDhikrKey: String?
    var dhikrCountsJSON: String?
    var dhikrPhraseKey: String?
    var dhikrCustomPhrase: String?
    var sortOrder: Int
    var archived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        ownerScope: String,
        name: String,
        icon: String,
        iconKey: String?,
        categoryRaw: String,
        categoryCustom: String?,
        typeRaw: String,
        targetCount: Int?,
        scheduleFrequency: String,
        weekdaysISO: String,
        reminderHour: Int?,
        reminderMinute: Int?,
        selectedDhikrKey: String?,
        dhikrCountsJSON: String?,
        dhikrPhraseKey: String? = nil,
        dhikrCustomPhrase: String? = nil,
        sortOrder: Int,
        archived: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ownerScope = ownerScope
        self.name = name
        self.icon = icon
        self.iconKey = iconKey
        self.categoryRaw = categoryRaw
        self.categoryCustom = categoryCustom
        self.typeRaw = typeRaw
        self.targetCount = targetCount
        self.scheduleFrequency = scheduleFrequency
        self.weekdaysISO = weekdaysISO
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.selectedDhikrKey = selectedDhikrKey
        self.dhikrCountsJSON = dhikrCountsJSON
        self.dhikrPhraseKey = dhikrPhraseKey
        self.dhikrCustomPhrase = dhikrCustomPhrase
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
        iconKey = habit.iconKey
        self.ownerScope = ownerScope
        categoryRaw = habit.category.rawValue
        categoryCustom = habit.categoryCustom
        typeRaw = habit.type.rawValue
        targetCount = habit.targetCount
        scheduleFrequency = habit.schedule.frequencyRaw
        weekdaysISO = habit.schedule.weekdayCSV
        reminderHour = habit.reminder?.hour
        reminderMinute = habit.reminder?.minute
        dhikrPhraseKey = habit.dhikrPhraseKey
        dhikrCustomPhrase = habit.dhikrCustomPhrase
        selectedDhikrKey = nil
        dhikrCountsJSON = nil
        sortOrder = habit.sortOrder
        archived = habit.archived
        updatedAt = habit.updatedAt
    }

    func asDomainHabit() -> Habit {
        let resolvedType = HabitType(rawValue: typeRaw) ?? .binary
        return Habit(
            id: id,
            name: name,
            icon: icon,
            iconKey: iconKey,
            category: HabitCategoryValue(rawValue: categoryRaw) ?? .spiritual,
            categoryCustom: categoryCustom,
            type: resolvedType,
            targetCount: targetCount,
            schedule: HabitSchedule.fromStorage(frequency: scheduleFrequency, weekdayCSV: weekdaysISO),
            reminder: HabitReminder.fromStorage(hour: reminderHour, minute: reminderMinute),
            dhikrPhraseKey: resolvedType == .dhikr
                ? (dhikrPhraseKey ?? selectedDhikrKey ?? Habit.defaultDhikrPhraseKey)
                : nil,
            dhikrCustomPhrase: resolvedType == .dhikr ? dhikrCustomPhrase : nil,
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
