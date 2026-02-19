import Foundation

enum HabitType: String, Codable, Hashable, Sendable {
    case binary
    case dhikr
}

enum HabitCategoryValue: String, Codable, Hashable, Sendable {
    case spiritual
    case physical
    case social
    case financial
    case learning
    case family
}

struct HabitReminder: Codable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    init(date: Date, calendar: Calendar = .current, timeZone: TimeZone = .current) {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = components.hour ?? 9
        self.minute = components.minute ?? 0
    }

    func asDateComponents() -> DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}

struct Habit: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var icon: String
    var category: HabitCategoryValue
    var type: HabitType
    var targetCount: Int?
    var schedule: HabitSchedule
    var reminder: HabitReminder?
    var sortOrder: Int
    var archived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        category: HabitCategoryValue = .spiritual,
        type: HabitType,
        targetCount: Int? = nil,
        schedule: HabitSchedule = .daily,
        reminder: HabitReminder? = nil,
        sortOrder: Int = 0,
        archived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.type = type
        self.targetCount = targetCount
        self.schedule = schedule
        self.reminder = reminder
        self.sortOrder = sortOrder
        self.archived = archived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isDhikr: Bool {
        type == .dhikr
    }

    func isDue(on date: Date, calendar: Calendar = .current, timeZone: TimeZone = .current) -> Bool {
        !archived && schedule.isDue(on: date, calendar: calendar, timeZone: timeZone)
    }

    var normalizedTargetCount: Int {
        switch type {
        case .binary:
            return 1
        case .dhikr:
            return max(targetCount ?? 1, 1)
        }
    }
}
