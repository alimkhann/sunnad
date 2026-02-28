package com.arystan.almasuly.sunnadandroid.data.local.entity

import androidx.room.Entity

@Entity(
    tableName = "group_members",
    primaryKeys = ["groupId", "userId"]
)
data class GroupMemberEntity(
    val groupId: String,
    val userId: String,
    val name: String,
    val avatarUrl: String?,
    val completedToday: Int,
    val totalSharedHabits: Int,
    val updatedAtEpochMillis: Long
)
