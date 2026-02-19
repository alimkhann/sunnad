import Foundation
import Testing
import UserNotifications
import SwiftData
@testable import sunnad_ios

@MainActor
struct NotificationSchedulerTests {
    @Test
    func permissionFlowReturnsCenterResult() async {
        let center = FakeNotificationCenter()
        center.permissionGranted = true

        let scheduler = UserNotificationReminderScheduler(center: center, logger: TestLogger())
        let granted = await scheduler.requestAuthorizationIfNeeded()

        #expect(granted)
        #expect(center.didRequestAuthorization)
    }

    @Test
    func newDailyHabitSchedulesSingleReminderWithStableIdentifier() async {
        let center = FakeNotificationCenter()
        let scheduler = UserNotificationReminderScheduler(center: center, logger: TestLogger())
        let habitID = UUID()

        let habit = Habit(
            id: habitID,
            name: "Read",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            reminder: HabitReminder(hour: 9, minute: 0)
        )

        await scheduler.syncReminders(for: [habit], enabled: true)

        #expect(center.pending.count == 1)
        #expect(center.pending.keys.contains("habit-reminder-\(habitID.uuidString)"))
    }

    @Test
    func weeklyHabitSchedulesPerSelectedWeekday() async {
        let center = FakeNotificationCenter()
        let scheduler = UserNotificationReminderScheduler(center: center, logger: TestLogger())
        let habitID = UUID()

        let habit = Habit(
            id: habitID,
            name: "Gym",
            icon: "figure.run",
            category: .physical,
            type: .binary,
            schedule: .weekly([.monday, .friday]),
            reminder: HabitReminder(hour: 18, minute: 30)
        )

        await scheduler.syncReminders(for: [habit], enabled: true)

        #expect(center.pending.count == 2)
        #expect(center.pending.keys.contains("habit-reminder-\(habitID.uuidString)-w1"))
        #expect(center.pending.keys.contains("habit-reminder-\(habitID.uuidString)-w5"))
    }

    @Test
    func habitUpdateReusesIdentifierAndReplacesSchedule() async {
        let center = FakeNotificationCenter()
        let scheduler = UserNotificationReminderScheduler(center: center, logger: TestLogger())
        let habitID = UUID()

        let original = Habit(
            id: habitID,
            name: "Read",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            reminder: HabitReminder(hour: 9, minute: 0)
        )

        await scheduler.syncReminders(for: [original], enabled: true)

        let updated = Habit(
            id: habitID,
            name: "Read",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            reminder: HabitReminder(hour: 21, minute: 15)
        )

        await scheduler.syncReminders(for: [updated], enabled: true)

        #expect(center.pending.count == 1)
        let request = center.pending["habit-reminder-\(habitID.uuidString)"]
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 21)
        #expect(trigger?.dateComponents.minute == 15)
    }

    @Test
    func disablingRemindersRemovesAllScheduledRequests() async {
        let center = FakeNotificationCenter()
        let scheduler = UserNotificationReminderScheduler(center: center, logger: TestLogger())
        let habitID = UUID()

        let habit = Habit(
            id: habitID,
            name: "Read",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .weekly([.monday, .wednesday]),
            reminder: HabitReminder(hour: 9, minute: 0)
        )

        await scheduler.syncReminders(for: [habit], enabled: true)
        await scheduler.syncReminders(for: [habit], enabled: false)

        #expect(center.pending.isEmpty)
    }
}

final class FakeNotificationCenter: UserNotificationCenterClient, @unchecked Sendable {
    var permissionGranted = true
    var didRequestAuthorization = false
    var pending: [String: UNNotificationRequest] = [:]

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        didRequestAuthorization = true
        return permissionGranted
    }

    func fetchPendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(pending.values)
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending[request.identifier] = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers {
            pending.removeValue(forKey: id)
        }
    }
}
