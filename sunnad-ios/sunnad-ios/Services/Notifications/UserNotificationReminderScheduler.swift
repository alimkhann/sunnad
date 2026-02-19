import Foundation
import UserNotifications

protocol UserNotificationCenterClient: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func fetchPendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCenterClient {
    func fetchPendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}

final class UserNotificationReminderScheduler: LocalReminderScheduling, @unchecked Sendable {
    private let center: UserNotificationCenterClient
    private let logger: AnalyticsLogging

    init(
        center: UserNotificationCenterClient = UNUserNotificationCenter.current(),
        logger: AnalyticsLogging
    ) {
        self.center = center
        self.logger = logger
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            logger.log(.reminderPermissionRequested, metadata: ["granted": granted ? "true" : "false"])
            return granted
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "notifications_permission", "error": error.localizedDescription])
            return false
        }
    }

    func syncReminders(for habits: [Habit], enabled: Bool) async {
        let requests = await center.fetchPendingNotificationRequests()
        let existingIDs = Set(requests.map(\.identifier).filter { $0.hasPrefix("habit-reminder-") })

        guard enabled else {
            if !existingIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: Array(existingIDs))
            }
            logger.log(.reminderSynced, metadata: ["enabled": "false", "count": "0"])
            return
        }

        let desiredIDs = Set(habits.flatMap(requestIdentifiers(for:)))
        let staleIDs = existingIDs.subtracting(desiredIDs)
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleIDs))
        }

        for habit in habits {
            await scheduleRequests(for: habit)
        }

        logger.log(.reminderSynced, metadata: ["enabled": "true", "count": "\(desiredIDs.count)"])
    }

    func removeReminder(habitID: UUID) async {
        let prefix = reminderPrefix(for: habitID)
        let existing = await center.fetchPendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        guard !existing.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: existing)
        logger.log(.reminderRemoved, metadata: ["habit_id": habitID.uuidString])
    }

    private func requestIdentifiers(for habit: Habit) -> [String] {
        guard !habit.archived, habit.reminder != nil else {
            return []
        }

        switch habit.schedule {
        case .daily:
            return [requestID(for: habit.id, weekday: nil)]
        case .weekly(let weekdays):
            guard !weekdays.isEmpty else {
                return []
            }
            return weekdays.sorted(by: { $0.rawValue < $1.rawValue }).map {
                requestID(for: habit.id, weekday: $0)
            }
        }
    }

    private func scheduleRequests(for habit: Habit) async {
        guard !habit.archived, let reminder = habit.reminder else {
            return
        }

        switch habit.schedule {
        case .daily:
            let components = DateComponents(hour: reminder.hour, minute: reminder.minute)
            await addRequest(
                id: requestID(for: habit.id, weekday: nil),
                habit: habit,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        case .weekly(let weekdays):
            for weekday in weekdays {
                let calendarWeekday = ((weekday.rawValue + 5) % 7) + 1
                let components = DateComponents(
                    hour: reminder.hour,
                    minute: reminder.minute,
                    weekday: calendarWeekday
                )
                await addRequest(
                    id: requestID(for: habit.id, weekday: weekday),
                    habit: habit,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )
            }
        }
    }

    private func addRequest(id: String, habit: Habit, trigger: UNNotificationTrigger) async {
        let content = UNMutableNotificationContent()
        content.title = L10n.t("notifications.habit_reminders")
        content.body = habit.name
        content.sound = .default
        content.userInfo = ["habit_id": habit.id.uuidString]

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            logger.log(
                .storageFailure,
                metadata: [
                    "scope": "schedule_reminder",
                    "habit_id": habit.id.uuidString,
                    "error": error.localizedDescription
                ]
            )
        }
    }

    private func requestID(for habitID: UUID, weekday: Weekday?) -> String {
        if let weekday {
            return "\(reminderPrefix(for: habitID))-w\(weekday.rawValue)"
        }
        return reminderPrefix(for: habitID)
    }

    private func reminderPrefix(for habitID: UUID) -> String {
        "habit-reminder-\(habitID.uuidString)"
    }
}
