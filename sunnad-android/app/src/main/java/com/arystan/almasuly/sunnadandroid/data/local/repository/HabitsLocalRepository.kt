package com.arystan.almasuly.sunnadandroid.data.local.repository

import com.arystan.almasuly.sunnadandroid.core.local.OwnerScopeResolver
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.domain.repository.HabitsRepository
import com.arystan.almasuly.sunnadandroid.data.local.dao.HabitDao
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toDomain
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toEntity
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.UUID

class HabitsLocalRepository(
    private val habitDao: HabitDao,
    private val ownerScopeResolver: OwnerScopeResolver
) : HabitsRepository {

    override suspend fun fetchHabits(includeArchived: Boolean): List<Habit> {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        val rows = if (includeArchived) {
            habitDao.fetchByScope(scope)
        } else {
            habitDao.fetchActiveByScope(scope)
        }
        return rows.map { it.toDomain() }
    }

    override suspend fun fetchDueHabits(day: LocalDate): List<Habit> {
        return fetchHabits(includeArchived = false).filter { it.isDue(day) }
    }

    override suspend fun saveHabit(habit: Habit) {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        val now = LocalDateTime.now()
        habitDao.upsert(habit.copy(updatedAt = now).toEntity(scope))
    }

    override suspend fun deleteHabit(id: UUID) {
        habitDao.delete(ownerScopeResolver.currentOwnerScopeRaw, id.toString())
    }
}
