import Foundation

protocol LocalReminderScheduling: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func syncReminders(for habits: [Habit], enabled: Bool, excludingHabitIDs: Set<UUID>) async
    func removeReminder(habitID: UUID) async
}

protocol ReminderSchedulingDebugInspectable: Sendable {
    func debugPendingReminderRequestIdentifiers() async -> [String]
}
