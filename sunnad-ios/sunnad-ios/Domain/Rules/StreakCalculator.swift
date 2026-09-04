import Foundation

enum StreakCalculator {
    static func streak(
        for habit: Habit,
        completions: [HabitCompletion],
        context: DayContext
    ) -> Int {
        HabitMetricsCalculator.streak(
            for: habit,
            completions: completions,
            context: context
        )
    }
}
