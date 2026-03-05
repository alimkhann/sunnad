package com.arystan.almasuly.sunnadandroid.core.model

import java.time.Instant
import java.time.LocalDate
import java.util.UUID

enum class GroupNudgeStatus {
    SENT,
    DUPLICATE,
    FORBIDDEN,
    ERROR
}

enum class GroupProgressDisplayMode {
    PERCENT,
    STREAK
}

data class SharedHabit(
    val id: UUID = UUID.randomUUID(),
    val habitId: UUID,
    val title: String,
    val icon: String,
    val completedToday: Boolean,
    val streak: Int,
    val rollingCompletionPercent: Int? = null
)

data class GroupMember(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val avatarUrl: String? = null,
    val completedToday: Int,
    val totalSharedHabits: Int,
    val sharedHabits: List<SharedHabit>
)

data class Group(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val code: String,
    val joinLocked: Boolean = false,
    val members: List<GroupMember>,
    val sharedHabitIds: Set<UUID>,
    val ownerMemberId: UUID = members.firstOrNull()?.id ?: UUID.randomUUID(),
    val currentUserMemberId: UUID? = null,
    val progressDisplayMode: GroupProgressDisplayMode = GroupProgressDisplayMode.PERCENT
)

data class Nudge(
    val id: UUID = UUID.randomUUID(),
    val groupId: UUID,
    val fromUserId: UUID,
    val toUserId: UUID,
    val habitId: UUID,
    val day: LocalDate,
    val createdAt: Instant = Instant.now()
)
