package com.arystan.almasuly.sunnadandroid.domain.repository

import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import com.arystan.almasuly.sunnadandroid.core.model.GroupProgressDisplayMode
import java.util.UUID

interface GroupsRepository {
    suspend fun fetchGroups(): List<Group>
    suspend fun createGroup(name: String): Group
    suspend fun joinGroup(code: String): Group
    suspend fun renameGroup(groupId: UUID, name: String)
    suspend fun setJoinLock(groupId: UUID, locked: Boolean)
    suspend fun rotateInviteCode(groupId: UUID): String
    suspend fun updateSharing(groupId: UUID, habitIds: Set<UUID>)
    suspend fun leaveGroup(groupId: UUID)
    suspend fun deleteGroup(groupId: UUID)
    suspend fun kickMember(groupId: UUID, memberUserId: UUID)
    suspend fun setProgressDisplayMode(groupId: UUID, mode: GroupProgressDisplayMode)
    suspend fun refreshGroup(groupId: UUID): Group?
    suspend fun sendNudge(groupId: UUID, toUserId: UUID, habitId: UUID): GroupNudgeStatus
}
