package com.arystan.almasuly.sunnadandroid.data.local.mappers

import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import com.arystan.almasuly.sunnadandroid.data.local.entity.CompletionEntity
import java.util.UUID

fun CompletionEntity.toDomain(): HabitCompletion {
    return HabitCompletion(
        habitId = UUID.fromString(habitId),
        dayDate = dayDateIso.toLocalDateSafe(),
        value = value,
        completedAt = completedAtEpochMillis?.toInstantSafe(),
        updatedAt = updatedAtEpochMillis.toInstantSafe()
    )
}

fun completionStorageKey(ownerScope: String, habitId: UUID, dayDateIso: String): String {
    return "$ownerScope|${habitId.toString().lowercase()}-$dayDateIso"
}

fun HabitCompletion.toEntity(ownerScope: String): CompletionEntity {
    val dayIso = dayDate.toIsoString()
    return CompletionEntity(
        id = completionStorageKey(ownerScope, habitId, dayIso),
        ownerScope = ownerScope,
        habitId = habitId.toString(),
        dayDateIso = dayIso,
        value = value,
        completedAtEpochMillis = completedAt?.toEpochMillisSafe(),
        updatedAtEpochMillis = updatedAt.toEpochMillisSafe()
    )
}
