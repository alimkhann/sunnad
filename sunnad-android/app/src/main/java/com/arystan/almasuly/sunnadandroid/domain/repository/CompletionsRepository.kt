package com.arystan.almasuly.sunnadandroid.domain.repository

import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import java.time.LocalDate
import java.util.UUID

interface CompletionsRepository {
    suspend fun fetchCompletions(day: LocalDate): List<HabitCompletion>
    suspend fun fetchCompletions(habitId: UUID): List<HabitCompletion>
    suspend fun fetchCompletion(habitId: UUID, day: LocalDate): HabitCompletion?
    suspend fun upsertCompletion(completion: HabitCompletion)
    suspend fun deleteCompletion(habitId: UUID, day: LocalDate)
}
