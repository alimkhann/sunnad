package com.arystan.almasuly.sunnadandroid.data.local.repository

import com.arystan.almasuly.sunnadandroid.core.local.OwnerScopeResolver
import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupMember
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import com.arystan.almasuly.sunnadandroid.core.model.GroupProgressDisplayMode
import com.arystan.almasuly.sunnadandroid.domain.repository.GroupsRepository
import com.arystan.almasuly.sunnadandroid.data.local.dao.GroupDao
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toDomain
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toEntity
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toMemberEntities
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toSharedHabitEntities
import java.util.UUID

class GroupsLocalRepository(
    private val groupDao: GroupDao,
    private val ownerScopeResolver: OwnerScopeResolver
) : GroupsRepository {
    override suspend fun fetchGroups(): List<Group> {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        val groups = groupDao.fetchGroups(scope)
        return groups.map { group ->
            val members = groupDao.fetchMembers(group.id)
            val shared = groupDao.fetchSharedHabits(group.id)
            group.toDomain(members, shared)
        }
    }

    override suspend fun createGroup(name: String): Group {
        val me = GroupMember(name = "You", completedToday = 0, totalSharedHabits = 0, sharedHabits = emptyList())
        val group = Group(
            name = name,
            code = UUID.randomUUID().toString().take(8).uppercase(),
            members = listOf(me),
            sharedHabitIds = emptySet(),
            ownerMemberId = me.id,
            currentUserMemberId = me.id
        )
        persistGroup(group)
        return group
    }

    override suspend fun joinGroup(code: String): Group {
        val me = GroupMember(name = "You", completedToday = 0, totalSharedHabits = 0, sharedHabits = emptyList())
        val group = Group(
            name = "Group ${code.uppercase()}",
            code = code.uppercase(),
            members = listOf(me),
            sharedHabitIds = emptySet(),
            ownerMemberId = me.id,
            currentUserMemberId = me.id
        )
        persistGroup(group)
        return group
    }

    override suspend fun renameGroup(groupId: UUID, name: String) {
        mutate(groupId) { it.copy(name = name) }
    }

    override suspend fun setJoinLock(groupId: UUID, locked: Boolean) {
        mutate(groupId) { it.copy(joinLocked = locked) }
    }

    override suspend fun rotateInviteCode(groupId: UUID): String {
        val next = UUID.randomUUID().toString().take(8).uppercase()
        mutate(groupId) { it.copy(code = next) }
        return next
    }

    override suspend fun updateSharing(groupId: UUID, habitIds: Set<UUID>) {
        mutate(groupId) { it.copy(sharedHabitIds = habitIds) }
    }

    override suspend fun leaveGroup(groupId: UUID) {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        groupDao.deleteGroup(scope, groupId.toString())
        groupDao.deleteMembers(groupId.toString())
        groupDao.deleteSharedHabits(groupId.toString())
    }

    override suspend fun deleteGroup(groupId: UUID) {
        leaveGroup(groupId)
    }

    override suspend fun kickMember(groupId: UUID, memberUserId: UUID) {
        mutate(groupId) { group ->
            group.copy(members = group.members.filterNot { it.id == memberUserId })
        }
    }

    override suspend fun setProgressDisplayMode(groupId: UUID, mode: GroupProgressDisplayMode) {
        mutate(groupId) { group ->
            group.copy(progressDisplayMode = mode)
        }
    }

    override suspend fun refreshGroup(groupId: UUID): Group? {
        return fetchGroups().firstOrNull { it.id == groupId }
    }

    override suspend fun sendNudge(groupId: UUID, toUserId: UUID, habitId: UUID): GroupNudgeStatus {
        Triple(groupId, toUserId, habitId)
        return GroupNudgeStatus.SENT
    }

    private suspend fun mutate(groupId: UUID, update: (Group) -> Group) {
        val existing = refreshGroup(groupId) ?: return
        persistGroup(update(existing))
    }

    private suspend fun persistGroup(group: Group) {
        val now = System.currentTimeMillis()
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        groupDao.replaceGroupSnapshot(
            group = group.toEntity(scope, now),
            members = group.toMemberEntities(now),
            sharedHabits = group.toSharedHabitEntities(now)
        )
    }
}
