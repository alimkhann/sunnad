package com.arystan.almasuly.sunnadandroid.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.arystan.almasuly.sunnadandroid.data.local.entity.SyncCursorEntity

@Dao
interface SyncCursorDao {
    @Query("SELECT * FROM sync_cursors WHERE resource = :resource LIMIT 1")
    suspend fun find(resource: String): SyncCursorEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(cursor: SyncCursorEntity)
}
