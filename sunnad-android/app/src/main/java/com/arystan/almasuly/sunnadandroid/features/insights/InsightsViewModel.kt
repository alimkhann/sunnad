package com.arystan.almasuly.sunnadandroid.features.insights

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
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

data class CategoryPerformanceUi(
    val key: String,
    val category: HabitCategoryValue?,
    val customLabel: String?,
    val percentage: Int,
    val completed: Int,
    val total: Int
)

data class InsightsUiState(
    val points: List<InsightsPointUi> = emptyList(),
    val habitPerformance: List<HabitPerformanceUi> = emptyList(),
    val categoryPerformance: List<CategoryPerformanceUi> = emptyList(),
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
                data class CategoryAggregate(
                    val category: HabitCategoryValue?,
                    val customLabel: String?,
                    var completedDays: Int = 0,
                    var totalDays: Int = 0
                )
                val categoryAggregates = linkedMapOf<String, CategoryAggregate>()

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
                    val categoryDayStatus = linkedMapOf<String, Pair<Int, Int>>()

                    dueHabits.forEach { habit ->
                        val value = completionByHabitId[habit.id]?.get(day) ?: 0
                        val completed = if (habit.isDhikr) value >= habit.normalizedTargetCount else value >= 1
                        if (completed) completedCount += 1 else missedIds += habit.id

                        val identity = categoryIdentity(habit)
                        val aggregate = categoryAggregates.getOrPut(identity.key) {
                            CategoryAggregate(
                                category = identity.category,
                                customLabel = identity.customLabel
                            )
                        }
                        val dayPair = categoryDayStatus[identity.key] ?: (0 to 0)
                        categoryDayStatus[identity.key] = if (completed) {
                            (dayPair.first + 1) to (dayPair.second + 1)
                        } else {
                            (dayPair.first + 1) to dayPair.second
                        }
                        // Keep aggregate's metadata aligned with the latest observed habit label/category.
                        if (aggregate.customLabel == null && identity.customLabel != null) {
                            categoryAggregates[identity.key] = aggregate.copy(customLabel = identity.customLabel)
                        }
                    }

                    categoryDayStatus.forEach { (key, pair) ->
                        val aggregate = categoryAggregates[key] ?: return@forEach
                        aggregate.totalDays += 1
                        if (pair.first > 0 && pair.first == pair.second) {
                            aggregate.completedDays += 1
                        }
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

                val categoryPerformance = categoryAggregates.map { (key, aggregate) ->
                    val percentage = if (aggregate.totalDays == 0) 0 else {
                        ((aggregate.completedDays.toDouble() / aggregate.totalDays.toDouble()) * 100.0).toInt()
                    }
                    CategoryPerformanceUi(
                        key = key,
                        category = aggregate.category,
                        customLabel = aggregate.customLabel,
                        percentage = percentage,
                        completed = aggregate.completedDays,
                        total = aggregate.totalDays.coerceAtMost(totalDays)
                    )
                }.sortedWith(
                    compareByDescending<CategoryPerformanceUi> { it.percentage }.thenBy {
                        it.customLabel ?: it.category?.name ?: it.key
                    }
                )

                val titles = habits.associate { it.id to it.name }
                Quad(points, performance, categoryPerformance, titles)
            }.onSuccess { (points, performance, categoryPerformance, titles) ->
                _state.update {
                    it.copy(
                        points = points,
                        habitPerformance = performance,
                        categoryPerformance = categoryPerformance,
                        habitTitlesById = titles,
                        isLoading = false,
                        errorMessage = null
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        categoryPerformance = emptyList(),
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

private data class CategoryIdentity(
    val key: String,
    val category: HabitCategoryValue?,
    val customLabel: String?
)

private fun categoryIdentity(habit: Habit): CategoryIdentity {
    val customLabel = habit.categoryCustom?.trim().takeUnless { it.isNullOrEmpty() }
    return if (customLabel != null) {
        CategoryIdentity(
            key = "custom:${customLabel.lowercase()}",
            category = null,
            customLabel = customLabel
        )
    } else {
        CategoryIdentity(
            key = "preset:${habit.category.name.lowercase()}",
            category = habit.category,
            customLabel = null
        )
    }
}

private data class Quad<A, B, C, D>(
    val first: A,
    val second: B,
    val third: C,
    val fourth: D
)
