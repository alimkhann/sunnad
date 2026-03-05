package com.arystan.almasuly.sunnadandroid.features.today

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.HabitType
import com.arystan.almasuly.sunnadandroid.core.model.Quote
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import com.arystan.almasuly.sunnadandroid.core.rules.StreakCalculator
import com.arystan.almasuly.sunnadandroid.domain.repository.CompletionsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.HabitsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.QuotesRepository
import com.arystan.almasuly.sunnadandroid.features.habits.canonicalHabitIconKey
import com.arystan.almasuly.sunnadandroid.features.onboarding.OnboardingTemplateSeed
import com.arystan.almasuly.sunnadandroid.sync.SyncCoordinator
import com.arystan.almasuly.sunnadandroid.sync.SyncTrigger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.UUID

data class TodayHabitUiModel(
    val id: UUID,
    val title: String,
    val icon: String,
    val isDhikr: Boolean,
    val completedToday: Boolean,
    val dhikrCount: Int,
    val dhikrTarget: Int,
    val streak: Int,
    val schedule: HabitSchedule,
    val reminderHour: Int?,
    val reminderMinute: Int?
)

data class TodayUiState(
    val allHabits: List<Habit> = emptyList(),
    val dueHabits: List<TodayHabitUiModel> = emptyList(),
    val habitStreakById: Map<UUID, Int> = emptyMap(),
    val pendingHabitToggleIds: Set<UUID> = emptySet(),
    val quote: Quote? = null,
    val isQuoteSaved: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val locale: String = "en",
    val selectedHabitId: UUID? = null
)

class TodayViewModel(
    private val habitsRepository: HabitsRepository,
    private val completionsRepository: CompletionsRepository,
    private val quotesRepository: QuotesRepository,
    private val syncCoordinator: SyncCoordinator
) : ViewModel() {
    private val _state = MutableStateFlow(TodayUiState())
    val state: StateFlow<TodayUiState> = _state.asStateFlow()

    fun updateLocale(locale: String) {
        _state.update { it.copy(locale = locale) }
        loadToday()
    }

    fun loadToday() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                val today = LocalDate.now()
                val allHabits = habitsRepository.fetchHabits(includeArchived = false).sortedBy { it.sortOrder }
                val dueHabits = habitsRepository.fetchDueHabits(today).sortedBy { it.sortOrder }
                val completionByHabitId = completionsRepository.fetchCompletions(today).associateBy { it.habitId }
                val streakById = mutableMapOf<UUID, Int>()

                allHabits.forEach { habit ->
                    val history = completionsRepository.fetchCompletions(habit.id)
                    streakById[habit.id] = StreakCalculator.streak(habit, history, today)
                }

                val uiHabits = dueHabits.map { habit ->
                    val completion = completionByHabitId[habit.id] ?: HabitCompletion(
                        habitId = habit.id,
                        dayDate = today,
                        value = 0
                    )
                    val streak = streakById[habit.id] ?: 0
                    todayUiModel(habit, completion, streak)
                }

                val quote = quotesRepository.fetchQuoteOfDay(
                    locale = _state.value.locale,
                    day = today
                )
                val isQuoteSaved = quote?.let { quotesRepository.isQuoteSaved(it.id) } ?: false

                _state.update {
                    it.copy(
                        allHabits = allHabits,
                        dueHabits = uiHabits,
                        habitStreakById = streakById,
                        quote = quote,
                        isQuoteSaved = isQuoteSaved,
                        isLoading = false
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(isLoading = false, errorMessage = error.localizedMessage)
                }
            }
        }
    }

    fun toggleHabit(habitId: UUID) {
        toggleHabit(habitId, onSettled = null)
    }

    fun toggleHabit(habitId: UUID, onSettled: (() -> Unit)?) {
        viewModelScope.launch {
            val current = _state.value
            if (current.pendingHabitToggleIds.contains(habitId)) return@launch
            val model = current.dueHabits.firstOrNull { it.id == habitId } ?: return@launch
            val habit = current.allHabits.firstOrNull { it.id == habitId } ?: return@launch
            val nextValue = when {
                habit.type == HabitType.BINARY && model.completedToday -> 0
                habit.type == HabitType.BINARY && !model.completedToday -> 1
                model.dhikrCount >= model.dhikrTarget -> 0
                else -> model.dhikrTarget
            }
            val optimisticModel = model.copy(
                completedToday = nextValue >= model.dhikrTarget,
                dhikrCount = nextValue
            )

            _state.update { state ->
                state.copy(
                    dueHabits = state.dueHabits.map { due ->
                        if (due.id == habitId) optimisticModel else due
                    },
                    pendingHabitToggleIds = state.pendingHabitToggleIds + habitId,
                    errorMessage = null
                )
            }

            val nowInstant = Instant.now()
            val completion = HabitCompletion(
                habitId = habitId,
                dayDate = LocalDate.now(),
                value = nextValue,
                completedAt = if (nextValue > 0) nowInstant else null,
                updatedAt = nowInstant
            )

            runCatching {
                completionsRepository.upsertCompletion(completion)
                syncCoordinator.enqueueCompletionUpsert(habitId, LocalDate.now())
                syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            }.onFailure { error ->
                _state.update { state ->
                    state.copy(
                        dueHabits = state.dueHabits.map { due ->
                            if (due.id == habitId) model else due
                        },
                        errorMessage = error.localizedMessage
                    )
                }
            }

            _state.update { state ->
                state.copy(
                    pendingHabitToggleIds = state.pendingHabitToggleIds - habitId
                )
            }
            onSettled?.invoke()
        }
    }

    fun saveQuoteOfDay() {
        viewModelScope.launch {
            val quote = _state.value.quote ?: return@launch
            if (_state.value.isQuoteSaved) return@launch
            quotesRepository.saveQuote(quote)
            syncCoordinator.enqueueSavedQuoteInsert(quote.id)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            _state.update { it.copy(isQuoteSaved = true) }
        }
    }

    fun seedHabitsFromTemplates(templates: List<OnboardingTemplateSeed>) {
        viewModelScope.launch {
            if (templates.isEmpty()) return@launch
            val existing = habitsRepository.fetchHabits(includeArchived = false)
            val existingNames = existing.map { it.name.trim().lowercase() }.toSet()
            var nextOrder = (existing.maxOfOrNull { it.sortOrder } ?: -1) + 1

            templates.forEach { template ->
                if (existingNames.contains(template.title.trim().lowercase())) return@forEach
                val habit = Habit(
                    name = template.title,
                    icon = canonicalHabitIconKey(template.iconName, template.title),
                    iconKey = canonicalHabitIconKey(template.iconName, template.title),
                    category = template.categoryValue,
                    type = if (template.isDhikr) HabitType.DHIKR else HabitType.BINARY,
                    targetCount = if (template.isDhikr) template.targetCount.coerceAtLeast(1) else null,
                    schedule = HabitSchedule.Daily,
                    reminder = null,
                    sortOrder = nextOrder++,
                    createdAt = LocalDateTime.now(),
                    updatedAt = LocalDateTime.now()
                )
                habitsRepository.saveHabit(habit)
                syncCoordinator.enqueueHabitUpsert(habit.id)
            }
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadToday()
        }
    }

    fun addHabit(
        name: String,
        icon: String,
        category: HabitCategoryValue,
        categoryCustom: String?,
        schedule: HabitSchedule,
        isDhikr: Boolean,
        targetCount: Int,
        reminderHour: Int?,
        reminderMinute: Int?
    ) {
        viewModelScope.launch {
            val order = (_state.value.allHabits.maxOfOrNull { it.sortOrder } ?: -1) + 1
            val reminder = if (reminderHour == null || reminderMinute == null) null else {
                com.arystan.almasuly.sunnadandroid.core.model.HabitReminder(reminderHour, reminderMinute)
            }
            val habit = Habit(
                name = name,
                icon = canonicalHabitIconKey(icon, name),
                iconKey = canonicalHabitIconKey(icon, name),
                category = category,
                categoryCustom = categoryCustom?.trim()?.takeIf { it.isNotEmpty() },
                type = if (isDhikr) HabitType.DHIKR else HabitType.BINARY,
                targetCount = if (isDhikr) targetCount.coerceAtLeast(1) else null,
                schedule = schedule,
                reminder = reminder,
                sortOrder = order,
                createdAt = LocalDateTime.now(),
                updatedAt = LocalDateTime.now()
            )
            habitsRepository.saveHabit(habit)
            syncCoordinator.enqueueHabitUpsert(habit.id)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadToday()
        }
    }

    fun setDhikrCount(habitId: UUID, count: Int) {
        viewModelScope.launch {
            val habit = _state.value.allHabits.firstOrNull { it.id == habitId } ?: return@launch
            if (habit.type != HabitType.DHIKR) return@launch
            val next = count.coerceIn(0, habit.normalizedTargetCount)
            val completion = HabitCompletion(
                habitId = habitId,
                dayDate = LocalDate.now(ZoneId.systemDefault()),
                value = next,
                completedAt = if (next > 0) Instant.now() else null,
                updatedAt = Instant.now()
            )
            completionsRepository.upsertCompletion(completion)
            syncCoordinator.enqueueCompletionUpsert(habitId, LocalDate.now())
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadToday()
        }
    }

    fun archiveHabit(habitId: UUID) {
        viewModelScope.launch {
            val habit = _state.value.allHabits.firstOrNull { it.id == habitId } ?: return@launch
            habitsRepository.saveHabit(habit.copy(archived = true, updatedAt = LocalDateTime.now()))
            syncCoordinator.enqueueHabitUpsert(habitId)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadToday()
        }
    }

    fun updateHabit(habit: Habit) {
        viewModelScope.launch {
            habitsRepository.saveHabit(
                habit.copy(
                    icon = canonicalHabitIconKey(habit.icon, habit.name),
                    iconKey = canonicalHabitIconKey(habit.icon, habit.name),
                    updatedAt = LocalDateTime.now()
                )
            )
            syncCoordinator.enqueueHabitUpsert(habit.id)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadToday()
        }
    }

    fun deleteHabit(habitId: UUID) {
        viewModelScope.launch {
            habitsRepository.deleteHabit(habitId)
            syncCoordinator.enqueueHabitDelete(habitId)
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadToday()
        }
    }

    fun reorderHabits(orderedIds: List<UUID>) {
        viewModelScope.launch {
            val habitById = _state.value.allHabits.associateBy { it.id }
            orderedIds.forEachIndexed { index, id ->
                val habit = habitById[id] ?: return@forEachIndexed
                habitsRepository.saveHabit(habit.copy(sortOrder = index, updatedAt = LocalDateTime.now()))
                syncCoordinator.enqueueHabitUpsert(id)
            }
            syncCoordinator.runSyncCycle(SyncTrigger.MANUAL)
            loadToday()
        }
    }

    fun chooseHabit(habitId: UUID?) {
        _state.update { it.copy(selectedHabitId = habitId) }
    }

    private fun todayUiModel(habit: Habit, completion: HabitCompletion, streak: Int): TodayHabitUiModel {
        val selectedValue = completion.value
        return TodayHabitUiModel(
            id = habit.id,
            title = habit.name,
            icon = habit.icon,
            isDhikr = habit.isDhikr,
            completedToday = completion.isCompleted(habit),
            dhikrCount = selectedValue,
            dhikrTarget = habit.normalizedTargetCount,
            streak = streak,
            schedule = habit.schedule,
            reminderHour = habit.reminder?.normalizedHour,
            reminderMinute = habit.reminder?.normalizedMinute
        )
    }

    fun defaultWeekdaySet(): Set<Weekday> = setOf(
        Weekday.MONDAY,
        Weekday.TUESDAY,
        Weekday.WEDNESDAY,
        Weekday.THURSDAY,
        Weekday.FRIDAY,
        Weekday.SATURDAY,
        Weekday.SUNDAY
    )
}
