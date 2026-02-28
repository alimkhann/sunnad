package com.arystan.almasuly.sunnadandroid.domain.repository

import com.arystan.almasuly.sunnadandroid.core.model.Habit
import java.time.LocalDate
import java.util.UUID

interface HabitsRepository {
    suspend fun fetchHabits(includeArchived: Boolean): List<Habit>
    suspend fun fetchDueHabits(day: LocalDate): List<Habit>
    suspend fun saveHabit(habit: Habit)
    suspend fun deleteHabit(id: UUID)
}
