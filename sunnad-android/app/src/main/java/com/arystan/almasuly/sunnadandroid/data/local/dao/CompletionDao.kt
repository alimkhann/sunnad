package com.arystan.almasuly.sunnadandroid.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.arystan.almasuly.sunnadandroid.data.local.entity.CompletionEntity

@Dao
interface CompletionDao {
    @Query("SELECT * FROM habit_completions WHERE ownerScope = :ownerScope")
    suspend fun fetchByScope(ownerScope: String): List<CompletionEntity>

    @Query("SELECT * FROM habit_completions WHERE ownerScope = :ownerScope AND dayDateIso = :dayDateIso")
    suspend fun fetchByDay(ownerScope: String, dayDateIso: String): List<CompletionEntity>

    @Query("SELECT * FROM habit_completions WHERE ownerScope = :ownerScope AND habitId = :habitId ORDER BY dayDateIso DESC")
    suspend fun fetchByHabit(ownerScope: String, habitId: String): List<CompletionEntity>

    @Query("SELECT * FROM habit_completions WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): CompletionEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: CompletionEntity)

    @Query("DELETE FROM habit_completions WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM habit_completions WHERE ownerScope = :ownerScope")
    suspend fun deleteAllByScope(ownerScope: String)
}
