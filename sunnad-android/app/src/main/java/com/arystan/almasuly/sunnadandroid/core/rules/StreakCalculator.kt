package com.arystan.almasuly.sunnadandroid.core.rules

import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import java.time.LocalDate

object StreakCalculator {
    fun streak(
        habit: Habit,
        completions: List<HabitCompletion>,
        asOf: LocalDate
    ): Int {
        val normalized = completions
            .groupBy { it.dayDate }
            .mapValues { (_, rows) -> rows.maxBy { it.updatedAt } }

        var streak = 0
        var cursor = asOf

        // Bounded to 14 days to prevent infinite loop if habit has no valid due days.
        var seekLimit = 14
        while (!habit.isDue(cursor)) {
            seekLimit--
            if (seekLimit <= 0) return 0
            cursor = cursor.minusDays(1)
        }

        if (habit.isDue(cursor)) {
            val currentCompletion = normalized[cursor]
            val isCompleted = currentCompletion?.isCompleted(habit) == true
            if (!isCompleted) {
                val previous = previousDueDate(habit, cursor)
                if (cursor == asOf && previous != null) {
                    cursor = previous
                } else {
                    return 0
                }
            }
        }

        while (true) {
            val completion = normalized[cursor] ?: break
            if (!completion.isCompleted(habit)) break

            streak += 1
            cursor = previousDueDate(habit, cursor) ?: break
        }

        return streak
    }

    private fun previousDueDate(habit: Habit, before: LocalDate): LocalDate? {
        var probe = before
        repeat(14) {
            probe = probe.minusDays(1)
            if (habit.isDue(probe)) {
                return probe
            }
        }
        return null
    }
}
