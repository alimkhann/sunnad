package com.arystan.almasuly.sunnadandroid.data.local.entity

import androidx.room.Entity

@Entity(
    tableName = "group_shared_habits",
    primaryKeys = ["groupId", "userId", "habitId"]
)
data class GroupSharedHabitEntity(
    val groupId: String,
    val userId: String,
    val habitId: String,
    val title: String,
    val icon: String,
    val completedToday: Boolean,
    val streak: Int,
    val shared: Boolean,
    val updatedAtEpochMillis: Long
)
