package com.arystan.almasuly.sunnadandroid.features.groups

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
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
    val errorMessage: String? = null
)

class GroupsViewModel(
    private val groupsRepository: GroupsRepository,
    private val syncCoordinator: SyncCoordinator
) : ViewModel() {
    private val _state = MutableStateFlow(GroupsUiState())
    val state: StateFlow<GroupsUiState> = _state.asStateFlow()

    fun loadGroups() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching { groupsRepository.fetchGroups() }
                .onSuccess { groups ->
                    _state.update { it.copy(groups = groups, isLoading = false) }
                }
                .onFailure { error ->
                    _state.update { it.copy(isLoading = false, errorMessage = error.localizedMessage) }
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
                groupsRepository.createGroup(name.trim())
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
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
                groupsRepository.joinGroup(code.trim())
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
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
                loadGroups()
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
                loadGroups()
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
                loadGroups()
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
                loadGroups()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to leave group")) }
            }
        }
    }

    fun updateSharing(group: Group, habitIds: Set<UUID>) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.updateSharing(group.id, habitIds)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                loadGroups()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to update sharing")) }
            }
        }
    }

    fun kickMember(group: Group, memberUserId: UUID) {
        viewModelScope.launch {
            runCatching {
                groupsRepository.kickMember(group.id, memberUserId)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                loadGroups()
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
                loadGroups()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = friendlyGroupError(error, "Failed to delete group")) }
            }
        }
    }

    fun sendNudge(groupId: UUID, toUserId: UUID, habitId: UUID, onResult: (GroupNudgeStatus) -> Unit) {
        viewModelScope.launch {
            val status = groupsRepository.sendNudge(groupId, toUserId, habitId)
            onResult(status)
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
            "permission" in lower || "forbidden" in lower -> "You do not have permission for this action."
            else -> message
        }
    }
}
