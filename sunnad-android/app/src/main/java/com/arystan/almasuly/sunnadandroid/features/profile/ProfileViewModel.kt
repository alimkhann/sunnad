package com.arystan.almasuly.sunnadandroid.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arystan.almasuly.sunnadandroid.app.LocalDataResetService
import com.arystan.almasuly.sunnadandroid.core.local.OwnerScopeResolver
import com.arystan.almasuly.sunnadandroid.core.model.SavedQuote
import com.arystan.almasuly.sunnadandroid.domain.repository.QuotesRepository
import com.arystan.almasuly.sunnadandroid.services.AppAppearance
import com.arystan.almasuly.sunnadandroid.services.AppLanguage
import com.arystan.almasuly.sunnadandroid.services.AppSettings
import com.arystan.almasuly.sunnadandroid.services.AppSettingsStore
import com.arystan.almasuly.sunnadandroid.sync.SyncCoordinator
import com.arystan.almasuly.sunnadandroid.sync.SyncTrigger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ProfileUiState(
    val settings: AppSettings = AppSettings(),
    val settingsLoaded: Boolean = false,
    val savedQuotes: List<SavedQuote> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
) {
    val language: AppLanguage
        get() = AppLanguage.fromRaw(settings.language)

    val appearance: AppAppearance
        get() = AppAppearance.fromRaw(settings.appearance)
}

class ProfileViewModel(
    private val quotesRepository: QuotesRepository,
    private val settingsStore: AppSettingsStore,
    private val syncCoordinator: SyncCoordinator,
    private val localDataResetService: LocalDataResetService,
    private val ownerScopeResolver: OwnerScopeResolver
) : ViewModel() {
    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            settingsStore.settings.collect { settings ->
                _state.update { it.copy(settings = settings, settingsLoaded = true) }
            }
        }
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                quotesRepository.fetchSavedQuotes()
            }.onSuccess { saved ->
                _state.update { it.copy(savedQuotes = saved, isLoading = false) }
            }.onFailure { error ->
                _state.update { it.copy(isLoading = false, errorMessage = error.localizedMessage) }
            }
        }
    }

    fun setLanguage(language: AppLanguage) {
        viewModelScope.launch {
            settingsStore.update { it.copy(language = language.localeTag) }
        }
    }

    fun setAppearance(appearance: AppAppearance) {
        viewModelScope.launch {
            settingsStore.update { it.copy(appearance = appearance.name.lowercase()) }
        }
    }

    fun setHabitReminders(enabled: Boolean) {
        viewModelScope.launch {
            settingsStore.update { it.copy(habitRemindersEnabled = enabled) }
        }
    }

    fun setQuoteReminder(enabled: Boolean) {
        viewModelScope.launch {
            settingsStore.update { it.copy(quoteReminderEnabled = enabled) }
        }
    }

    fun setGroupReminders(enabled: Boolean) {
        viewModelScope.launch {
            settingsStore.update { it.copy(groupRemindersEnabled = enabled) }
        }
    }

    fun setHaptics(enabled: Boolean) {
        viewModelScope.launch {
            settingsStore.update { it.copy(hapticsEnabled = enabled) }
        }
    }

    fun setSounds(enabled: Boolean) {
        viewModelScope.launch {
            settingsStore.update { it.copy(soundsEnabled = enabled) }
        }
    }

    fun setOnboardingCompleted(completed: Boolean) {
        _state.update {
            it.copy(settings = it.settings.copy(onboardingCompleted = completed))
        }
        viewModelScope.launch {
            settingsStore.update { it.copy(onboardingCompleted = completed) }
        }
    }

    fun clearSavedQuotes() {
        viewModelScope.launch {
            val quoteIds = _state.value.savedQuotes.mapNotNull { it.quoteId }
            quotesRepository.deleteAllSavedQuotes()
            quoteIds.forEach { syncCoordinator.enqueueSavedQuoteDelete(it) }
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            refresh()
        }
    }

    fun clearAllLocalData() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val ownerScope = ownerScopeResolver.currentOwnerScopeRaw
            runCatching {
                localDataResetService.clearOwnerScope(ownerScope)
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onSuccess {
                _state.update { it.copy(savedQuotes = emptyList(), isLoading = false) }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.localizedMessage ?: "Failed to clear local data"
                    )
                }
            }
        }
    }
}
