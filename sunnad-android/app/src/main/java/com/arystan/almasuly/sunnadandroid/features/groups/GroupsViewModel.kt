package com.arystan.almasuly.sunnadandroid.features.groups

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import com.arystan.almasuly.sunnadandroid.core.model.GroupProgressDisplayMode
import com.arystan.almasuly.sunnadandroid.domain.repository.GroupsRepository
import com.arystan.almasuly.sunnadandroid.sync.SyncCoordinator
import com.arystan.almasuly.sunnadandroid.sync.SyncTrigger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

data class GroupsUiState(
    val groups: List<Group> = emptyList(),
    val isLoading: Boolean = false,
    val hasLoadedOnce: Boolean = false,
    val errorMessage: String? = null
)

class GroupsViewModel(
    private val groupsRepository: GroupsRepository,
    private val syncCoordinator: SyncCoordinator
) : ViewModel() {
    private data class SharingPipelineState(
        val desiredHabitIds: Set<UUID>,
        val committedHabitIds: Set<UUID>,
        val isInFlight: Boolean
    )

    private val _state = MutableStateFlow(GroupsUiState())
    val state: StateFlow<GroupsUiState> = _state.asStateFlow()
    private val sharingPipelines = mutableMapOf<UUID, SharingPipelineState>()

    fun loadGroups() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching { groupsRepository.fetchGroups() }
                .onSuccess { groups ->
                    val merged = groups.map { group ->
                        group.copy(
                            sharedHabitIds = resolvedSharedHabitIds(
                                groupId = group.id,
                                fallback = group.sharedHabitIds
                            )
                        )
                    }
                    syncSharingPipelines(merged)
                    _state.update { it.copy(groups = merged, isLoading = false, hasLoadedOnce = true) }
                }
                .onFailure { error ->
                    _state.update { it.copy(isLoading = false, hasLoadedOnce = true, errorMessage = error.localizedMessage) }
                }
        }
    }

    fun clearError() {
        _state.update { it.copy(errorMessage = null) }
    }

    fun createGroup(name: String) {
        if (name.isBlank()) return
        viewModelScope.launch {
            runCatching {
                val group = groupsRepository.createGroup(name.trim())
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
                group
            }.onSuccess {
                loadGroups()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to create group")) }
            }
        }
    }

    fun joinGroup(code: String) {
        if (code.isBlank()) return
        viewModelScope.launch {
            runCatching {
                val group = groupsRepository.joinGroup(code.trim())
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
                group
            }.onSuccess {
                loadGroups()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to join group")) }
            }
        }
    }

    fun toggleJoinLock(group: Group) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.setJoinLock(group.id, !group.joinLocked)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                refreshGroup(group.id)
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to update group settings")) }
            }
        }
    }

    fun rotateCode(group: Group) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.rotateInviteCode(group.id)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                refreshGroup(group.id)
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to rotate invite code")) }
            }
        }
    }

    fun renameGroup(group: Group, name: String) {
        if (name.isBlank()) return
        viewModelScope.launch {
            runCatching {
                groupsRepository.renameGroup(group.id, name)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                refreshGroup(group.id)
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to rename group")) }
            }
        }
    }

    fun leaveGroup(group: Group) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.leaveGroup(group.id)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                sharingPipelines.remove(group.id)
                loadGroups()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to leave group")) }
            }
        }
    }

    fun updateSharing(group: Group, habitIds: Set<UUID>) {
        viewModelScope.launch {
            val currentSharedHabitIds = _state.value.groups
                .firstOrNull { it.id == group.id }
                ?.sharedHabitIds
                ?: group.sharedHabitIds

            applyOptimisticSharing(group.id, habitIds)
            val currentPipeline = sharingPipelines[group.id]
            sharingPipelines[group.id] = SharingPipelineState(
                desiredHabitIds = habitIds,
                committedHabitIds = currentPipeline?.committedHabitIds ?: currentSharedHabitIds,
                isInFlight = currentPipeline?.isInFlight ?: false
            )

            flushSharingPipeline(group.id)
        }
    }

    fun kickMember(group: Group, memberUserId: UUID) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.kickMember(group.id, memberUserId)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                refreshGroup(group.id)
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to remove member")) }
            }
        }
    }

    fun deleteGroup(group: Group) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.deleteGroup(group.id)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                sharingPipelines.remove(group.id)
                loadGroups()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to delete group")) }
            }
        }
    }

    fun setProgressDisplayMode(group: Group, mode: GroupProgressDisplayMode) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.setProgressDisplayMode(group.id, mode)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                refreshGroup(group.id)
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to update progress mode")) }
            }
        }
    }

    fun sendNudge(groupId: UUID, toUserId: UUID, habitId: UUID, onResult: (GroupNudgeStatus) -> Unit) {
        viewModelScope.launch {
            val status = groupsRepository.sendNudge(groupId, toUserId, habitId)
            onResult(status)
        }
    }

    private suspend fun refreshGroup(groupId: UUID) {
        runCatching { groupsRepository.refreshGroup(groupId) }
            .onSuccess { refreshed ->
                if (refreshed == null) {
                    sharingPipelines.remove(groupId)
                    _state.update { state ->
                        state.copy(groups = state.groups.filterNot { it.id == groupId })
                    }
                    return
                }
                val merged = refreshed.copy(
                    sharedHabitIds = resolvedSharedHabitIds(
                        groupId = refreshed.id,
                        fallback = refreshed.sharedHabitIds
                    )
                )
                syncSharingPipelineForGroup(merged.id, merged.sharedHabitIds)
                _state.update { state ->
                    val updated = state.groups.toMutableList()
                    val index = updated.indexOfFirst { it.id == merged.id }
                    if (index >= 0) {
                        updated[index] = merged
                    } else {
                        updated.add(merged)
                    }
                    state.copy(groups = updated)
                }
            }
            .onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to refresh group")) }
            }
    }

    private suspend fun flushSharingPipeline(groupId: UUID) {
        val pipeline = sharingPipelines[groupId] ?: return
        if (pipeline.isInFlight) return
        if (pipeline.desiredHabitIds == pipeline.committedHabitIds) return

        val targetHabitIds = pipeline.desiredHabitIds
        val previousCommittedIds = pipeline.committedHabitIds
        sharingPipelines[groupId] = pipeline.copy(isInFlight = true)

        runCatching {
            groupsRepository.updateSharing(groupId, targetHabitIds)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            groupsRepository.refreshGroup(groupId)
        }.onSuccess { refreshed ->
            val current = sharingPipelines[groupId]
                ?: SharingPipelineState(targetHabitIds, targetHabitIds, isInFlight = false)

            val committedIds = refreshed?.sharedHabitIds ?: targetHabitIds
            val serverCorrectedSelection =
                committedIds != targetHabitIds && current.desiredHabitIds == targetHabitIds

            sharingPipelines[groupId] = if (serverCorrectedSelection) {
                SharingPipelineState(
                    desiredHabitIds = committedIds,
                    committedHabitIds = committedIds,
                    isInFlight = false
                )
            } else {
                current.copy(
                    committedHabitIds = committedIds,
                    isInFlight = false
                )
            }

            if (refreshed != null) {
                val merged = refreshed.copy(
                    sharedHabitIds = resolvedSharedHabitIds(
                        groupId = refreshed.id,
                        fallback = refreshed.sharedHabitIds
                    )
                )
                _state.update { state ->
                    val updated = state.groups.toMutableList()
                    val index = updated.indexOfFirst { it.id == merged.id }
                    if (index >= 0) updated[index] = merged else updated.add(merged)
                    state.copy(groups = updated, errorMessage = null)
                }
            } else {
                applyOptimisticSharing(groupId, committedIds)
            }

            if (serverCorrectedSelection) {
                applyOptimisticSharing(groupId, committedIds)
                _state.update {
                    it.copy(
                        errorMessage = "Some habits are not synced yet. Please wait a moment and try sharing again."
                    )
                }
                return@onSuccess
            }

            val latest = sharingPipelines[groupId]
            if (latest != null && latest.desiredHabitIds != latest.committedHabitIds) {
                flushSharingPipeline(groupId)
            } else if (previousCommittedIds != committedIds) {
                syncSharingPipelineForGroup(groupId, committedIds)
            }
        }.onFailure { error ->
            val current = sharingPipelines[groupId] ?: pipeline
            val hasNewerDesired = current.desiredHabitIds != targetHabitIds
            sharingPipelines[groupId] = current.copy(isInFlight = false)

            if (hasNewerDesired) {
                flushSharingPipeline(groupId)
                return@onFailure
            }

            applyOptimisticSharing(groupId, current.committedHabitIds)
            _state.update {
                it.copy(errorMessage = friendlyGroupError(error, "Failed to update sharing"))
            }
        }
    }

    private fun applyOptimisticSharing(groupId: UUID, habitIds: Set<UUID>) {
        _state.update { state ->
            val updated = state.groups.map { group ->
                if (group.id == groupId) group.copy(sharedHabitIds = habitIds) else group
            }
            state.copy(groups = updated)
        }
    }

    private fun syncSharingPipelines(groups: List<Group>) {
        val knownGroupIds = groups.map { it.id }.toSet()
        sharingPipelines.keys.retainAll(knownGroupIds)
        groups.forEach { group ->
            val existing = sharingPipelines[group.id]
            if (existing == null || (!existing.isInFlight && existing.desiredHabitIds == existing.committedHabitIds)) {
                sharingPipelines[group.id] = SharingPipelineState(
                    desiredHabitIds = group.sharedHabitIds,
                    committedHabitIds = group.sharedHabitIds,
                    isInFlight = false
                )
            }
        }
    }

    private fun syncSharingPipelineForGroup(groupId: UUID, sharedHabitIds: Set<UUID>) {
        val existing = sharingPipelines[groupId]
        if (existing != null && (existing.isInFlight || existing.desiredHabitIds != existing.committedHabitIds)) {
            return
        }
        sharingPipelines[groupId] = SharingPipelineState(
            desiredHabitIds = sharedHabitIds,
            committedHabitIds = sharedHabitIds,
            isInFlight = false
        )
    }

    private fun resolvedSharedHabitIds(groupId: UUID, fallback: Set<UUID>): Set<UUID> {
        val pipeline = sharingPipelines[groupId] ?: return fallback
        return if (pipeline.isInFlight || pipeline.desiredHabitIds != pipeline.committedHabitIds) {
            pipeline.desiredHabitIds
        } else {
            fallback
        }
    }

    private fun friendlyGroupError(error: Throwable, fallback: String): String {
        val message = error.localizedMessage?.trim().orEmpty()
        if (message.isBlank()) return fallback
        val lower = message.lowercase()
        return when {
            "invalid" in lower && "code" in lower -> "Invalid invite code."
            "locked" in lower || "closed" in lower -> "This group is closed to new members."
            "already" in lower && "member" in lower -> "You are already in this group."
            "group_shared_habits_habit_id_fkey" in lower ->
                "Some habits are not synced yet. Please wait a moment and try sharing again."
            "permission" in lower || "forbidden" in lower -> "You do not have permission for this action."
            else -> message
        }
    }
}
