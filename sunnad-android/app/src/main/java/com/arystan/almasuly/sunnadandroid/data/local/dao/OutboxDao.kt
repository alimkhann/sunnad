package com.arystan.almasuly.sunnadandroid.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.arystan.almasuly.sunnadandroid.data.local.entity.OutboxEventEntity

@Dao
interface OutboxDao {
    @Query("SELECT * FROM outbox_events WHERE ownerScope = :ownerScope ORDER BY createdAtEpochMillis ASC")
    suspend fun fetchPending(ownerScope: String): List<OutboxEventEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(event: OutboxEventEntity)

    @Query("DELETE FROM outbox_events WHERE id = :id")
    suspend fun delete(id: Long)

    @Query("UPDATE outbox_events SET attempts = attempts + 1 WHERE id = :id")
    suspend fun incrementAttempts(id: Long)

    @Query("DELETE FROM outbox_events WHERE ownerScope = :ownerScope")
    suspend fun deleteAllByScope(ownerScope: String)
}
