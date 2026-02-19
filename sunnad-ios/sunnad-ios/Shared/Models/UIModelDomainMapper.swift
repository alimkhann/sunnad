import Foundation

extension UIHabit {
    func asDomainHabit(now: Date = Date(), calendar: Calendar = .current, timeZone: TimeZone = .current) -> Habit {
        let reminder = reminderTime.map { HabitReminder(date: $0, calendar: calendar, timeZone: timeZone) }

        return Habit(
            id: id,
            name: displayTitle,
            icon: iconSystemName,
            category: HabitCategoryValue(rawValue: category.rawValue) ?? .spiritual,
            type: isDhikr ? .dhikr : .binary,
            targetCount: isDhikr ? dhikrTarget : nil,
            schedule: HabitSchedule.fromUI(schedule, weekdays: weekdays),
            reminder: reminder,
            sortOrder: 0,
            archived: false,
            createdAt: now,
            updatedAt: now
        )
    }
}

extension Habit {
    func asUIHabit(
        completedToday: Bool,
        streak: Int,
        completionValue: Int = 0,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> UIHabit {
        var reminderDate: Date?
        if let reminder {
            var calendar = calendar
            calendar.timeZone = timeZone
            reminderDate = calendar.date(
                bySettingHour: reminder.hour,
                minute: reminder.minute,
                second: 0,
                of: Date()
            )
        }

        return UIHabit(
            id: id,
            customTitle: name,
            iconSystemName: icon,
            category: HabitCategory(rawValue: category.rawValue) ?? .spiritual,
            completedToday: completedToday,
            streak: streak,
            schedule: schedule.asUI,
            weekdays: schedule.uiWeekdays,
            reminderTime: reminderDate,
            isDhikr: type == .dhikr,
            dhikrCount: completionValue,
            dhikrTarget: normalizedTargetCount
        )
    }
}

extension HabitSchedule {
    static func fromUI(_ schedule: UIHabitSchedule, weekdays: Set<Int>) -> HabitSchedule {
        switch schedule {
        case .daily:
            return .daily
        case .weekly:
            let mapped = Set(weekdays.compactMap { Weekday.fromMondayFirstIndex($0) })
            return .weekly(mapped)
        }
    }

    var asUI: UIHabitSchedule {
        switch self {
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        }
    }

    var uiWeekdays: Set<Int> {
        switch self {
        case .daily:
            return Set(0...6)
        case .weekly(let weekdays):
            return Set(weekdays.map(\.mondayFirstIndex))
        }
    }
}

extension SavedQuote {
    func asUISavedQuote() -> UISavedQuote {
        UISavedQuote(id: id, text: text, author: author, savedAt: savedAt)
    }
}

extension Quote {
    func asUIQuote() -> UIQuote {
        UIQuote(rawText: text, rawAuthor: source ?? "")
    }
}
