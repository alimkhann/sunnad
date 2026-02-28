package com.arystan.almasuly.sunnadandroid.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "habits")
data class HabitEntity(
    @PrimaryKey val id: String,
    val ownerScope: String,
    val name: String,
    val icon: String,
    val category: String,
    val type: String,
    val targetCount: Int?,
    val scheduleFrequency: String,
    val weekdaysIsoCsv: String,
    val reminderHour: Int?,
    val reminderMinute: Int?,
    val selectedDhikrKey: String,
    val dhikrCountsJson: String,
    val sortOrder: Int,
    val archived: Boolean,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long
)
