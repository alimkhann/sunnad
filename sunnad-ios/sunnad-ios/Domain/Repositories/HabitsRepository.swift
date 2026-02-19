import Foundation

protocol HabitsRepository: Sendable {
    func fetchHabits(includeArchived: Bool) async throws -> [Habit]
    func fetchDueHabits(on day: Date, calendar: Calendar, timeZone: TimeZone) async throws -> [Habit]
    func saveHabit(_ habit: Habit) async throws
    func deleteHabit(id: UUID) async throws
}
