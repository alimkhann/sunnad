package com.arystan.almasuly.sunnadandroid.core.model

import java.time.LocalDateTime
import java.util.UUID

enum class HabitType {
    BINARY,
    DHIKR
}

enum class HabitCategoryValue {
    SPIRITUAL,
    PHYSICAL,
    SOCIAL,
    FINANCIAL,
    LEARNING,
    FAMILY
}

data class HabitReminder(
    val hour: Int,
    val minute: Int
) {
    val normalizedHour: Int = hour.coerceIn(0, 23)
    val normalizedMinute: Int = minute.coerceIn(0, 59)
}

data class Habit(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val icon: String,
    val category: HabitCategoryValue = HabitCategoryValue.SPIRITUAL,
    val type: HabitType,
    val targetCount: Int? = null,
    val schedule: HabitSchedule = HabitSchedule.Daily,
    val reminder: HabitReminder? = null,
    val selectedDhikrKey: String = DEFAULT_DHIKR_KEY,
    val dhikrCountsByKey: Map<String, Int> = emptyMap(),
    val sortOrder: Int = 0,
    val archived: Boolean = false,
    val createdAt: LocalDateTime = LocalDateTime.now(),
    val updatedAt: LocalDateTime = LocalDateTime.now()
) {
    val normalizedTargetCount: Int
        get() = when (type) {
            HabitType.BINARY -> 1
            HabitType.DHIKR -> (targetCount ?: 1).coerceAtLeast(1)
        }

    val isDhikr: Boolean
        get() = type == HabitType.DHIKR

    fun isDue(on: java.time.LocalDate): Boolean = !archived && schedule.isDue(on)

    companion object {
        const val DEFAULT_DHIKR_KEY = "dhikr.choice.subhanallah"
    }
}
