package com.arystan.almasuly.sunnadandroid.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.arystan.almasuly.sunnadandroid.data.local.entity.SavedQuoteEntity

@Dao
interface SavedQuoteDao {
    @Query("SELECT * FROM saved_quotes WHERE ownerScope = :ownerScope ORDER BY savedAtEpochMillis DESC")
    suspend fun fetchByScope(ownerScope: String): List<SavedQuoteEntity>

    @Query("SELECT * FROM saved_quotes WHERE ownerScope = :ownerScope AND quoteId = :quoteId LIMIT 1")
    suspend fun findByQuoteId(ownerScope: String, quoteId: String): SavedQuoteEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: SavedQuoteEntity)

    @Query("DELETE FROM saved_quotes WHERE ownerScope = :ownerScope")
    suspend fun deleteAllByScope(ownerScope: String)
}
