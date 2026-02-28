package com.arystan.almasuly.sunnadandroid.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "groups")
data class GroupEntity(
    @PrimaryKey val id: String,
    val ownerScope: String,
    val name: String,
    val code: String,
    val joinLocked: Boolean,
    val ownerMemberId: String,
    val currentUserMemberId: String?,
    val updatedAtEpochMillis: Long
)
