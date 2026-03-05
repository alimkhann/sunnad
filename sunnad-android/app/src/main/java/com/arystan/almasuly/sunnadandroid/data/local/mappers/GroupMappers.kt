package com.arystan.almasuly.sunnadandroid.data.local.mappers

import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupMember
import com.arystan.almasuly.sunnadandroid.core.model.SharedHabit
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupMemberEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupSharedHabitEntity
import java.util.UUID

fun GroupEntity.toDomain(members: List<GroupMemberEntity>, shared: List<GroupSharedHabitEntity>): Group {
    val sharedByUser = shared.groupBy { it.userId }

    val domainMembers = members.map { member ->
        val memberShared = sharedByUser[member.userId].orEmpty().filter { it.shared }.map {
            SharedHabit(
                habitId = UUID.fromString(it.habitId),
                title = it.title,
                icon = it.icon,
                completedToday = it.completedToday,
                dueToday = true,
                streak = it.streak
            )
        }
        GroupMember(
            id = UUID.fromString(member.userId),
            name = member.name,
            avatarUrl = member.avatarUrl,
            completedToday = member.completedToday,
            totalSharedHabits = member.totalSharedHabits,
            sharedHabits = memberShared
        )
    }

    val effectiveCurrentUserId = currentUserMemberId ?: ownerMemberId
    val currentShared = shared
        .filter { it.shared && it.userId == effectiveCurrentUserId }
        .map { UUID.fromString(it.habitId) }
        .toSet()

    return Group(
        id = UUID.fromString(id),
        name = name,
        code = code,
        joinLocked = joinLocked,
        members = domainMembers,
        sharedHabitIds = currentShared,
        ownerMemberId = UUID.fromString(ownerMemberId),
        currentUserMemberId = currentUserMemberId?.let(UUID::fromString)
    )
}

fun Group.toEntity(ownerScope: String, nowEpochMillis: Long): GroupEntity {
    return GroupEntity(
        id = id.toString(),
        ownerScope = ownerScope,
        name = name,
        code = code,
        joinLocked = joinLocked,
        ownerMemberId = ownerMemberId.toString(),
        currentUserMemberId = currentUserMemberId?.toString(),
        updatedAtEpochMillis = nowEpochMillis
    )
}

fun Group.toMemberEntities(nowEpochMillis: Long): List<GroupMemberEntity> {
    return members.map { member ->
        GroupMemberEntity(
            groupId = id.toString(),
            userId = member.id.toString(),
            name = member.name,
            avatarUrl = member.avatarUrl,
            completedToday = member.completedToday,
            totalSharedHabits = member.totalSharedHabits,
            updatedAtEpochMillis = nowEpochMillis
        )
    }
}

fun Group.toSharedHabitEntities(nowEpochMillis: Long): List<GroupSharedHabitEntity> {
    val memberShared = members.flatMap { member ->
        member.sharedHabits.map { sharedHabit ->
            GroupSharedHabitEntity(
                groupId = id.toString(),
                userId = member.id.toString(),
                habitId = sharedHabit.habitId.toString(),
                title = sharedHabit.title,
                icon = sharedHabit.icon,
                completedToday = sharedHabit.completedToday,
                streak = sharedHabit.streak,
                shared = true,
                updatedAtEpochMillis = nowEpochMillis
            )
        }
    }

    val currentUserId = (currentUserMemberId ?: ownerMemberId).toString()
    val currentUserSynthetic = sharedHabitIds.map { habitId ->
        GroupSharedHabitEntity(
            groupId = id.toString(),
            userId = currentUserId,
            habitId = habitId.toString(),
            title = "Shared habit",
            icon = "check_circle",
            completedToday = false,
            streak = 0,
            shared = true,
            updatedAtEpochMillis = nowEpochMillis
        )
    }

    return (memberShared + currentUserSynthetic).distinctBy { "${it.groupId}:${it.userId}:${it.habitId}" }
}
