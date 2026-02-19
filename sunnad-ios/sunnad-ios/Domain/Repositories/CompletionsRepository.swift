import Foundation

protocol CompletionsRepository: Sendable {
    func fetchCompletions(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [HabitCompletion]
    func fetchCompletions(for habitID: UUID) async throws -> [HabitCompletion]
    func fetchCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> HabitCompletion?
    func upsertCompletion(_ completion: HabitCompletion, calendar: Calendar, timeZone: TimeZone) async throws
    func deleteCompletion(habitID: UUID, on day: Date, calendar: Calendar, timeZone: TimeZone) async throws
}
