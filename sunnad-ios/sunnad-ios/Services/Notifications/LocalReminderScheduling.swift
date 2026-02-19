import Foundation

protocol LocalReminderScheduling: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func syncReminders(for habits: [Habit], enabled: Bool) async
    func removeReminder(habitID: UUID) async
}
