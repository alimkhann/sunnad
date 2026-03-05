package com.arystan.almasuly.sunnadandroid.data.local.db

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
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
    version = 2,
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

    companion object {
        val MIGRATION_1_2: Migration = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                if (!db.hasColumn("habits", "iconKey")) {
                    db.execSQL("ALTER TABLE habits ADD COLUMN iconKey TEXT")
                }
                if (!db.hasColumn("habits", "categoryCustom")) {
                    db.execSQL("ALTER TABLE habits ADD COLUMN categoryCustom TEXT")
                }
            }
        }
    }
}

private fun SupportSQLiteDatabase.hasColumn(tableName: String, columnName: String): Boolean {
    query("PRAGMA table_info(`$tableName`)").use { cursor ->
        val nameIndex = cursor.getColumnIndex("name")
        while (cursor.moveToNext()) {
            if (nameIndex >= 0 && cursor.getString(nameIndex) == columnName) {
                return true
            }
        }
    }
    return false
}
