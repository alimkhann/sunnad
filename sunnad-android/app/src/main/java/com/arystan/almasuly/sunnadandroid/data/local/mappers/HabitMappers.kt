package com.arystan.almasuly.sunnadandroid.data.local.mappers

import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.HabitReminder
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.HabitType
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import com.arystan.almasuly.sunnadandroid.data.local.entity.HabitEntity
import kotlinx.serialization.json.Json
import java.util.UUID

private val json = Json { ignoreUnknownKeys = true }

fun HabitEntity.toDomain(): Habit {
    val weekdaysIso = weekdaysIsoCsv
        .split(',')
        .mapNotNull { value -> value.trim().takeIf { it.isNotEmpty() }?.toIntOrNull() }
        .toSet()

    val counts = runCatching { json.decodeFromString<Map<String, Int>>(dhikrCountsJson) }
        .getOrDefault(emptyMap())

    return Habit(
        id = UUID.fromString(id),
        name = name,
        icon = icon,
        category = runCatching { HabitCategoryValue.valueOf(category) }.getOrDefault(HabitCategoryValue.SPIRITUAL),
        type = runCatching { HabitType.valueOf(type) }.getOrDefault(HabitType.BINARY),
        targetCount = targetCount,
        schedule = HabitSchedule.fromStorage(scheduleFrequency, weekdaysIso),
        reminder = if (reminderHour == null || reminderMinute == null) null else HabitReminder(reminderHour, reminderMinute),
        selectedDhikrKey = selectedDhikrKey,
        dhikrCountsByKey = counts,
        sortOrder = sortOrder,
        archived = archived,
        createdAt = createdAtEpochMillis.toLocalDateTimeUtc(),
        updatedAt = updatedAtEpochMillis.toLocalDateTimeUtc()
    )
}

fun Habit.toEntity(ownerScope: String): HabitEntity {
    val frequency = when (schedule) {
        HabitSchedule.Daily -> "daily"
        is HabitSchedule.Weekly -> "weekly"
    }
    val weekdays = when (schedule) {
        HabitSchedule.Daily -> emptyList()
        is HabitSchedule.Weekly -> schedule.weekdays.map(Weekday::isoValue).sorted()
    }
    val weekdaysCsv = weekdays.joinToString(",")

    val countsJson = runCatching { json.encodeToString(dhikrCountsByKey) }.getOrDefault("{}")

    return HabitEntity(
        id = id.toString(),
        ownerScope = ownerScope,
        name = name,
        icon = icon,
        category = category.name,
        type = type.name,
        targetCount = targetCount,
        scheduleFrequency = frequency,
        weekdaysIsoCsv = weekdaysCsv,
        reminderHour = reminder?.normalizedHour,
        reminderMinute = reminder?.normalizedMinute,
        selectedDhikrKey = selectedDhikrKey,
        dhikrCountsJson = countsJson,
        sortOrder = sortOrder,
        archived = archived,
        createdAtEpochMillis = createdAt.toEpochMillisUtc(),
        updatedAtEpochMillis = updatedAt.toEpochMillisUtc()
    )
}
