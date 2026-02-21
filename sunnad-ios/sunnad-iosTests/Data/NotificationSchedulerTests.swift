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

        await scheduler.syncReminders(for: [habit], enabled: true, excludingHabitIDs: [])

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

        await scheduler.syncReminders(for: [habit], enabled: true, excludingHabitIDs: [])

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

        await scheduler.syncReminders(for: [original], enabled: true, excludingHabitIDs: [])

        let updated = Habit(
            id: habitID,
            name: "Read",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            reminder: HabitReminder(hour: 21, minute: 15)
        )

        await scheduler.syncReminders(for: [updated], enabled: true, excludingHabitIDs: [])

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

        await scheduler.syncReminders(for: [habit], enabled: true, excludingHabitIDs: [])
        await scheduler.syncReminders(for: [habit], enabled: false, excludingHabitIDs: [])

        #expect(center.pending.isEmpty)
    }

    @Test
    func completedHabitsAreExcludedFromScheduling() async {
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

        await scheduler.syncReminders(for: [habit], enabled: true, excludingHabitIDs: [habitID])

        #expect(center.pending.isEmpty)
    }

    @Test
    func quoteRemindersScheduleAtNineAM() async {
        let center = FakeNotificationCenter()
        let scheduler = UserNotificationReminderScheduler(center: center, logger: TestLogger())

        let plans = [
            QuoteReminderPlan(
                identifier: "quote-reminder-2026-02-21",
                body: "The best deeds are consistent, even if small.",
                dateComponents: DateComponents(year: 2026, month: 2, day: 21, hour: 9, minute: 0)
            )
        ]

        await scheduler.syncQuoteReminders(enabled: true, plans: plans)

        let request = center.pending["quote-reminder-2026-02-21"]
        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        #expect(request != nil)
        #expect(trigger?.dateComponents.hour == 9)
        #expect(trigger?.dateComponents.minute == 0)
        #expect(request?.content.body == plans[0].body)
    }

    @Test
    func disablingQuoteRemindersRemovesPendingRequests() async {
        let center = FakeNotificationCenter()
        let scheduler = UserNotificationReminderScheduler(center: center, logger: TestLogger())

        let plans = [
            QuoteReminderPlan(
                identifier: "quote-reminder-2026-02-22",
                body: "Verily, with hardship comes ease.",
                dateComponents: DateComponents(year: 2026, month: 2, day: 22, hour: 9, minute: 0)
            )
        ]

        await scheduler.syncQuoteReminders(enabled: true, plans: plans)
        #expect(center.pending["quote-reminder-2026-02-22"] != nil)

        await scheduler.syncQuoteReminders(enabled: false, plans: [])
        #expect(center.pending["quote-reminder-2026-02-22"] == nil)
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
