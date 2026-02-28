package com.arystan.almasuly.sunnadandroid

import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.HabitType
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import com.arystan.almasuly.sunnadandroid.core.rules.StreakCalculator
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class StreakCalculatorTest {
    @Test
    fun dailyStreakCountsContiguousDays() {
        val today = LocalDate.of(2026, 2, 19)
        val habit = Habit(name = "Read", icon = "book", type = HabitType.BINARY, schedule = HabitSchedule.Daily)
        val completions = listOf(
            HabitCompletion(habit.id, today, 1),
            HabitCompletion(habit.id, today.minusDays(1), 1),
            HabitCompletion(habit.id, today.minusDays(2), 1)
        )

        assertEquals(3, StreakCalculator.streak(habit, completions, today))
    }

    @Test
    fun weeklyStreakSkipsNonDueDays() {
        val asOf = LocalDate.of(2026, 2, 19)
        val habit = Habit(
            name = "Exercise",
            icon = "run",
            type = HabitType.BINARY,
            schedule = HabitSchedule.Weekly(setOf(Weekday.MONDAY, Weekday.THURSDAY))
        )
        val completions = listOf(
            HabitCompletion(habit.id, LocalDate.of(2026, 2, 19), 1),
            HabitCompletion(habit.id, LocalDate.of(2026, 2, 16), 1),
            HabitCompletion(habit.id, LocalDate.of(2026, 2, 12), 1)
        )

        assertEquals(3, StreakCalculator.streak(habit, completions, asOf))
    }
}
