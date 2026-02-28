package com.arystan.almasuly.sunnadandroid.data.remote.generated

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class HabitRowDto(
    val id: String,
    @SerialName("user_id") val userId: String,
    val name: String,
    val icon: String?,
    val type: String,
    @SerialName("target_count") val targetCount: Int? = null,
    val schedule: String,
    val weekdays: List<Int> = emptyList(),
    @SerialName("reminder_enabled") val reminderEnabled: Boolean,
    @SerialName("reminder_time") val reminderTime: String? = null,
    @SerialName("sort_order") val sortOrder: Int,
    val archived: Boolean,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class CompletionRowDto(
    @SerialName("user_id") val userId: String,
    @SerialName("habit_id") val habitId: String,
    @SerialName("day_date") val dayDate: String,
    val value: Int,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class GroupRowDto(
    val id: String,
    @SerialName("owner_id") val ownerId: String,
    val name: String,
    val code: String,
    @SerialName("join_locked") val joinLocked: Boolean = false
)

@Serializable
data class GroupMemberRowDto(
    @SerialName("group_id") val groupId: String,
    @SerialName("user_id") val userId: String,
    val role: String,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class GroupSharedHabitRowDto(
    @SerialName("group_id") val groupId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("habit_id") val habitId: String,
    val shared: Boolean,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class CreateGroupWithOwnerRequest(
    @SerialName("group_name") val groupName: String
)

@Serializable
data class JoinGroupByCodeRequest(
    @SerialName("invite_code") val inviteCode: String
)
