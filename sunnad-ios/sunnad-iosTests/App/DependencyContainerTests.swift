import Foundation
import Testing
@testable import sunnad_ios

struct DependencyContainerTests {
    @Test
    func deduplicatedHabitsKeepsFirstHabitPerID() {
        let sharedID = UUID()
        let first = Habit(
            id: sharedID,
            name: "Morning dhikr",
            icon: "sun.max.fill",
            category: .spiritual,
            type: .dhikr,
            targetCount: 33,
            schedule: .daily,
            reminder: HabitReminder(hour: 7, minute: 0)
        )
        let duplicate = Habit(
            id: sharedID,
            name: "Duplicate morning dhikr",
            icon: "moon.fill",
            category: .spiritual,
            type: .dhikr,
            targetCount: 99,
            schedule: .daily,
            reminder: HabitReminder(hour: 8, minute: 0)
        )
        let unique = Habit(
            id: UUID(),
            name: "Read Quran",
            icon: "book.fill",
            category: .spiritual,
            type: .binary,
            schedule: .daily,
            reminder: HabitReminder(hour: 21, minute: 0)
        )

        let result = DependencyContainer.deduplicatedHabits([first, duplicate, unique])

        #expect(result.count == 2)
        #expect(result[0].id == sharedID)
        #expect(result[0].name == "Morning dhikr")
        #expect(result[1].id == unique.id)
    }
}
