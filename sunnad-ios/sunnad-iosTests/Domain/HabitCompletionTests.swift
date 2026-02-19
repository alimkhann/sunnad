import Foundation
import Testing
@testable import sunnad_ios

struct HabitCompletionTests {
    @Test
    func binaryCompletionAcceptsOnlyZeroOrOne() {
        let habit = Habit(name: "Read", icon: "book", type: .binary)
        let day = Date()

        #expect(HabitCompletion(habitID: habit.id, dayDate: day, value: 0).isValid(for: habit))
        #expect(HabitCompletion(habitID: habit.id, dayDate: day, value: 1).isValid(for: habit))
        #expect(!HabitCompletion(habitID: habit.id, dayDate: day, value: 2).isValid(for: habit))
    }

    @Test
    func dhikrCompletionIsBoundedByTarget() {
        let habit = Habit(name: "Dhikr", icon: "star", type: .dhikr, targetCount: 33)
        let day = Date()

        #expect(HabitCompletion(habitID: habit.id, dayDate: day, value: 12).isValid(for: habit))
        #expect(!HabitCompletion(habitID: habit.id, dayDate: day, value: 34).isValid(for: habit))
    }

    @Test
    func completionClampNormalizesInvalidValues() {
        let binaryHabit = Habit(name: "Read", icon: "book", type: .binary)
        let dhikrHabit = Habit(name: "Dhikr", icon: "star", type: .dhikr, targetCount: 33)
        let day = Date()

        let binary = HabitCompletion(habitID: binaryHabit.id, dayDate: day, value: 7).clamped(for: binaryHabit)
        let dhikr = HabitCompletion(habitID: dhikrHabit.id, dayDate: day, value: 99).clamped(for: dhikrHabit)

        #expect(binary.value == 1)
        #expect(dhikr.value == 33)
    }
}
