package com.arystan.almasuly.sunnadandroid.features.insights

import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.HabitType
import com.arystan.almasuly.sunnadandroid.domain.repository.CompletionsRepository
import com.arystan.almasuly.sunnadandroid.domain.repository.HabitsRepository
import com.arystan.almasuly.sunnadandroid.features.habits.canonicalHabitIconKey
import com.arystan.almasuly.sunnadandroid.features.habits.canonicalHabitIconKeys
import com.arystan.almasuly.sunnadandroid.features.habits.iconForHabitKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.UUID

class InsightsAndIconContractTest {
    @Test
    fun canonicalHabitIconKeyNormalizesLegacyAndTitleDrivenValues() {
        assertEquals("sunrise.fill", canonicalHabitIconKey("wb_sunny"))
        assertEquals("moon.fill", canonicalHabitIconKey("bedtime"))
        assertEquals("book.closed.fill", canonicalHabitIconKey("menu_book"))
        assertEquals("building.columns.fill", canonicalHabitIconKey("mosque"))
        assertEquals("sunrise.fill", canonicalHabitIconKey("anything", title = "Morning dhikr"))
        assertEquals("figure.run", canonicalHabitIconKey("anything", title = "Exercise after fajr"))
    }

    @Test
    fun canonicalIconCatalogStaysCuratedAndResolvable() {
        assertTrue(canonicalHabitIconKeys.size in 30..50)
        canonicalHabitIconKeys.forEach { key ->
            assertNotNull("Expected icon vector for $key", iconForHabitKey(key))
        }
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun insightsClampCategoryTotalsToRolling40DayWindow() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        Dispatchers.setMain(dispatcher)
        try {
            val today = LocalDate.now()
            val habit = Habit(
                id = UUID.randomUUID(),
                name = "Morning dhikr",
                icon = "sparkles",
                category = HabitCategoryValue.SPIRITUAL,
                type = HabitType.BINARY,
                schedule = HabitSchedule.Daily
            )
            val completions = listOf(
                HabitCompletion(habitId = habit.id, dayDate = today, value = 1),
                HabitCompletion(habitId = habit.id, dayDate = today.minusDays(1), value = 1),
                HabitCompletion(habitId = habit.id, dayDate = today.minusDays(41), value = 1)
            )

            val viewModel = InsightsViewModel(
                habitsRepository = FakeHabitsRepository(listOf(habit)),
                completionsRepository = FakeCompletionsRepository(mapOf(habit.id to completions))
            )

            viewModel.load()
            advanceUntilIdle()

            val state = viewModel.state.value
            assertEquals(40, state.points.size)
            assertEquals(1, state.categoryPerformance.size)
            val category = state.categoryPerformance.single()
            assertEquals(40, category.total)
            assertEquals(2, category.completed)
            assertEquals(5, category.percentage)
        } finally {
            Dispatchers.resetMain()
        }
    }
}

private class FakeHabitsRepository(
    private val habits: List<Habit>
) : HabitsRepository {
    override suspend fun fetchHabits(includeArchived: Boolean): List<Habit> = habits

    override suspend fun fetchDueHabits(day: LocalDate): List<Habit> = habits.filter { it.isDue(day) }

    override suspend fun saveHabit(habit: Habit) = Unit

    override suspend fun deleteHabit(id: UUID) = Unit
}

private class FakeCompletionsRepository(
    private val completionsByHabit: Map<UUID, List<HabitCompletion>>
) : CompletionsRepository {
    override suspend fun fetchCompletions(day: LocalDate): List<HabitCompletion> {
        return completionsByHabit.values.flatten().filter { it.dayDate == day }
    }

    override suspend fun fetchCompletions(habitId: UUID): List<HabitCompletion> {
        return completionsByHabit[habitId].orEmpty()
    }

    override suspend fun fetchCompletion(habitId: UUID, day: LocalDate): HabitCompletion? {
        return completionsByHabit[habitId].orEmpty().firstOrNull { it.dayDate == day }
    }

    override suspend fun upsertCompletion(completion: HabitCompletion) = Unit

    override suspend fun deleteCompletion(habitId: UUID, day: LocalDate) = Unit
}
