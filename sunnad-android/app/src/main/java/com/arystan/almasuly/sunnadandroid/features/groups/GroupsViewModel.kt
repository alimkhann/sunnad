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

    fun createGroup(name: String) {
        if (name.isBlank()) return
        viewModelScope.launch {
            groupsRepository.createGroup(name.trim())
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadGroups()
        }
    }

    fun joinGroup(code: String) {
        if (code.isBlank()) return
        viewModelScope.launch {
            groupsRepository.joinGroup(code.trim())
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadGroups()
        }
    }

    fun toggleJoinLock(group: Group) {
        viewModelScope.launch {
            groupsRepository.setJoinLock(group.id, !group.joinLocked)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadGroups()
        }
    }

    fun rotateCode(group: Group) {
        viewModelScope.launch {
            groupsRepository.rotateInviteCode(group.id)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadGroups()
        }
    }

    fun renameGroup(group: Group, name: String) {
        if (name.isBlank()) return
        viewModelScope.launch {
            groupsRepository.renameGroup(group.id, name)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadGroups()
        }
    }

    fun leaveGroup(group: Group) {
        viewModelScope.launch {
            groupsRepository.leaveGroup(group.id)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadGroups()
        }
    }

    fun sendNudge(groupId: UUID, toUserId: UUID, habitId: UUID, onResult: (GroupNudgeStatus) -> Unit) {
        viewModelScope.launch {
            val status = groupsRepository.sendNudge(groupId, toUserId, habitId)
            onResult(status)
        }
    }
}
