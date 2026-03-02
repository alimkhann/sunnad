package com.arystan.almasuly.sunnadandroid.features.insights

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.domain.repository.CompletionsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.HabitsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.util.UUID

data class InsightsPointUi(
    val date: LocalDate,
    val due: Int,
    val completed: Int,
    val missedHabitIds: List<UUID>
)

data class HabitDayUi(
    val date: LocalDate,
    val scheduled: Boolean,
    val completed: Boolean
)

data class HabitPerformanceUi(
    val id: UUID,
    val title: String,
    val percentage: Int,
    val days: List<HabitDayUi>
)

data class InsightsUiState(
    val points: List<InsightsPointUi> = emptyList(),
    val habitPerformance: List<HabitPerformanceUi> = emptyList(),
    val habitTitlesById: Map<UUID, String> = emptyMap(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
)

class InsightsViewModel(
    private val habitsRepository: HabitsRepository,
    private val completionsRepository: CompletionsRepository
) : ViewModel() {
    private val _state = MutableStateFlow(InsightsUiState())
    val state: StateFlow<InsightsUiState> = _state.asStateFlow()

    private val totalDays = 40

    fun load() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            runCatching {
                val habits = habitsRepository.fetchHabits(includeArchived = false)
                val timeline = timelineDays(LocalDate.now())
                val completionByHabitId = mutableMapOf<UUID, Map<LocalDate, Int>>()

                habits.forEach { habit ->
                    val completionMap = completionsRepository
                        .fetchCompletions(habit.id)
                        .associate { it.dayDate to it.value }
                    completionByHabitId[habit.id] = completionMap
                }

                val points = timeline.map { day ->
                    val dueHabits = habits.filter { it.isDue(day) }
                    var completedCount = 0
                    val missedIds = mutableListOf<UUID>()

                    dueHabits.forEach { habit ->
                        val value = completionByHabitId[habit.id]?.get(day) ?: 0
                        val completed = if (habit.isDhikr) value >= habit.normalizedTargetCount else value >= 1
                        if (completed) completedCount += 1 else missedIds += habit.id
                    }

                    InsightsPointUi(
                        date = day,
                        due = dueHabits.size,
                        completed = completedCount,
                        missedHabitIds = missedIds
                    )
                }

                val performance = habits.map { habit ->
                    val dayStates = timeline.map { day ->
                        val scheduled = habit.isDue(day)
                        val value = completionByHabitId[habit.id]?.get(day) ?: 0
                        val completed = if (habit.isDhikr) value >= habit.normalizedTargetCount else value >= 1
                        HabitDayUi(day, scheduled, scheduled && completed)
                    }

                    val scheduledCount = dayStates.count { it.scheduled }
                    val completedCount = dayStates.count { it.completed }
                    val percentage = if (scheduledCount == 0) 0 else {
                        ((completedCount.toDouble() / scheduledCount.toDouble()) * 100.0).toInt()
                    }

                    HabitPerformanceUi(
                        id = habit.id,
                        title = habit.name,
                        percentage = percentage,
                        days = dayStates
                    )
                }.sortedWith(compareByDescending<HabitPerformanceUi> { it.percentage }.thenBy { it.title })

                val titles = habits.associate { it.id to it.name }
                Triple(points, performance, titles)
            }.onSuccess { (points, performance, titles) ->
                _state.update {
                    it.copy(
                        points = points,
                        habitPerformance = performance,
                        habitTitlesById = titles,
                        isLoading = false,
                        errorMessage = null
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.localizedMessage ?: "Insights load failed"
                    )
                }
            }
        }
    }

    private fun timelineDays(today: LocalDate): List<LocalDate> {
        return (0 until totalDays).map { index ->
            today.minusDays((totalDays - 1L) - index.toLong())
        }
    }

    fun missedHabitTitles(point: InsightsPointUi): List<String> {
        return point.missedHabitIds.mapNotNull { _state.value.habitTitlesById[it] }
    }
}
