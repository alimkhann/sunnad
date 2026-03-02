package com.arystan.almasuly.sunnadandroid.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.arystan.almasuly.sunnadandroid.data.local.entity.HabitEntity

@Dao
interface HabitDao {
    @Query("SELECT * FROM habits WHERE ownerScope = :ownerScope ORDER BY sortOrder ASC, createdAtEpochMillis ASC")
    suspend fun fetchByScope(ownerScope: String): List<HabitEntity>

    @Query("SELECT * FROM habits WHERE ownerScope = :ownerScope AND archived = 0 ORDER BY sortOrder ASC, createdAtEpochMillis ASC")
    suspend fun fetchActiveByScope(ownerScope: String): List<HabitEntity>

    @Query("SELECT * FROM habits WHERE ownerScope = :ownerScope AND id = :id LIMIT 1")
    suspend fun findById(ownerScope: String, id: String): HabitEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: HabitEntity)

    @Query("DELETE FROM habits WHERE ownerScope = :ownerScope AND id = :id")
    suspend fun delete(ownerScope: String, id: String)

    @Query("DELETE FROM habits WHERE ownerScope = :ownerScope")
    suspend fun deleteAllByScope(ownerScope: String)
}
