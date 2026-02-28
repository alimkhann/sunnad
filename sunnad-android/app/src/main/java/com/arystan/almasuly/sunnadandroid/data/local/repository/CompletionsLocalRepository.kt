package com.arystan.almasuly.sunnadandroid.data.local.repository

import com.arystan.almasuly.sunnadandroid.core.local.OwnerScopeResolver
import com.arystan.almasuly.sunnadandroid.core.model.HabitCompletion
import com.arystan.almasuly.sunnadandroid.domain.repository.CompletionsRepository
import com.arystan.almasuly.sunnadandroid.data.local.dao.CompletionDao
import com.arystan.almasuly.sunnadandroid.data.local.mappers.completionStorageKey
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toDomain
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toEntity
import java.time.LocalDate
import java.util.UUID

class CompletionsLocalRepository(
    private val completionDao: CompletionDao,
    private val ownerScopeResolver: OwnerScopeResolver
) : CompletionsRepository {

    override suspend fun fetchCompletions(day: LocalDate): List<HabitCompletion> {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        return completionDao.fetchByDay(scope, day.toString()).map { it.toDomain() }
    }

    override suspend fun fetchCompletions(habitId: UUID): List<HabitCompletion> {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        return completionDao.fetchByHabit(scope, habitId.toString()).map { it.toDomain() }
    }

    override suspend fun fetchCompletion(habitId: UUID, day: LocalDate): HabitCompletion? {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        val key = completionStorageKey(scope, habitId, day.toString())
        return completionDao.findById(key)?.toDomain()
    }

    override suspend fun upsertCompletion(completion: HabitCompletion) {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        completionDao.upsert(completion.toEntity(scope))
    }

    override suspend fun deleteCompletion(habitId: UUID, day: LocalDate) {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        val key = completionStorageKey(scope, habitId, day.toString())
        completionDao.deleteById(key)
    }
}
