package com.arystan.almasuly.sunnadandroid.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "habit_completions")
data class CompletionEntity(
    @PrimaryKey val id: String,
    val ownerScope: String,
    val habitId: String,
    val dayDateIso: String,
    val value: Int,
    val completedAtEpochMillis: Long?,
    val updatedAtEpochMillis: Long
)
