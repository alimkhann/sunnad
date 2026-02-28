package com.arystan.almasuly.sunnadandroid.data.local.db

import androidx.room.Database
import androidx.room.RoomDatabase
import com.arystan.almasuly.sunnadandroid.data.local.dao.CompletionDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.GroupDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.HabitDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.OutboxDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.QuoteDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.SavedQuoteDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.SyncCursorDao
import com.arystan.almasuly.sunnadandroid.data.local.entity.CompletionEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupMemberEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.GroupSharedHabitEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.HabitEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.OutboxEventEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.QuoteEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.SavedQuoteEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.SyncCursorEntity

@Database(
    entities = [
        HabitEntity::class,
        CompletionEntity::class,
        QuoteEntity::class,
        SavedQuoteEntity::class,
        GroupEntity::class,
        GroupMemberEntity::class,
        GroupSharedHabitEntity::class,
        OutboxEventEntity::class,
        SyncCursorEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class SunnadDatabase : RoomDatabase() {
    abstract fun habitDao(): HabitDao
    abstract fun completionDao(): CompletionDao
    abstract fun quoteDao(): QuoteDao
    abstract fun savedQuoteDao(): SavedQuoteDao
    abstract fun groupDao(): GroupDao
    abstract fun outboxDao(): OutboxDao
    abstract fun syncCursorDao(): SyncCursorDao
}
