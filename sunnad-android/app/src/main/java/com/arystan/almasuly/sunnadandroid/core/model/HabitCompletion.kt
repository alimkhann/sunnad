package com.arystan.almasuly.sunnadandroid.core.model

import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class HabitCompletion(
    val habitId: UUID,
    val dayDate: LocalDate,
    val value: Int,
    val completedAt: Instant? = null,
    val updatedAt: Instant = Instant.now()
) {
    fun isValid(forHabit: Habit): Boolean {
        return when (forHabit.type) {
            HabitType.BINARY -> value == 0 || value == 1
            HabitType.DHIKR -> value in 0..forHabit.normalizedTargetCount
        }
    }

    fun isCompleted(forHabit: Habit): Boolean {
        return when (forHabit.type) {
            HabitType.BINARY -> value == 1
            HabitType.DHIKR -> value >= forHabit.normalizedTargetCount
        }
    }

    fun clamped(forHabit: Habit): HabitCompletion {
        val normalizedValue = when (forHabit.type) {
            HabitType.BINARY -> if (value <= 0) 0 else 1
            HabitType.DHIKR -> value.coerceIn(0, forHabit.normalizedTargetCount)
        }
        return copy(value = normalizedValue)
    }
}
