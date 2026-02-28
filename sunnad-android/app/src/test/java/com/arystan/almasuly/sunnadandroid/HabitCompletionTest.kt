package com.arystan.almasuly.sunnadandroid

import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import com.arystan.almasuly.sunnadandroid.core.model.HabitType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class HabitCompletionTest {
    @Test
    fun binaryCompletionAcceptsOnlyZeroOrOne() {
        val habit = Habit(name = "Read", icon = "book", type = HabitType.BINARY)
        val day = LocalDate.of(2026, 2, 19)

        assertTrue(HabitCompletion(habit.id, day, 0).isValid(habit))
        assertTrue(HabitCompletion(habit.id, day, 1).isValid(habit))
        assertFalse(HabitCompletion(habit.id, day, 2).isValid(habit))
    }

    @Test
    fun dhikrCompletionBoundedByTarget() {
        val habit = Habit(name = "Dhikr", icon = "star", type = HabitType.DHIKR, targetCount = 33)
        val day = LocalDate.of(2026, 2, 19)

        assertTrue(HabitCompletion(habit.id, day, 12).isValid(habit))
        assertFalse(HabitCompletion(habit.id, day, 34).isValid(habit))
    }

    @Test
    fun completionClampNormalizesInvalidValues() {
        val binaryHabit = Habit(name = "Read", icon = "book", type = HabitType.BINARY)
        val dhikrHabit = Habit(name = "Dhikr", icon = "star", type = HabitType.DHIKR, targetCount = 33)
        val day = LocalDate.of(2026, 2, 19)

        val binary = HabitCompletion(binaryHabit.id, day, 7).clamped(binaryHabit)
        val dhikr = HabitCompletion(dhikrHabit.id, day, 99).clamped(dhikrHabit)

        assertEquals(1, binary.value)
        assertEquals(33, dhikr.value)
    }
}
