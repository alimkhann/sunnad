import Foundation

struct QuoteReminderPlan: Sendable {
    let identifier: String
    let title: String
    let body: String
    let dateComponents: DateComponents
}

protocol LocalReminderScheduling: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func syncReminders(for habits: [Habit], enabled: Bool, excludingHabitIDs: Set<UUID>) async
    func syncQuoteReminders(enabled: Bool, plans: [QuoteReminderPlan]) async
    func removeReminder(habitID: UUID) async
}

protocol ReminderSchedulingDebugInspectable: Sendable {
    func debugPendingReminderRequestIdentifiers() async -> [String]
}
