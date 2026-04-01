package com.arystan.almasuly.sunnadandroid.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import com.arystan.almasuly.sunnadandroid.data.local.entity.QuoteEntity

@Dao
interface QuoteDao {
    @Query("SELECT * FROM quotes WHERE locale = :locale AND active = 1 ORDER BY sortOrder ASC")
    suspend fun fetchActiveByLocale(locale: String): List<QuoteEntity>

    @Query("DELETE FROM quotes")
    suspend fun deleteAll()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entities: List<QuoteEntity>)

    @Transaction
    suspend fun replaceAll(entities: List<QuoteEntity>) {
        deleteAll()
        upsertAll(entities)
    }
}
