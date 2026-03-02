package com.arystan.almasuly.sunnadandroid.app

import com.arystan.almasuly.sunnadandroid.data.local.dao.CompletionDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.GroupDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.HabitDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.OutboxDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.SavedQuoteDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.SyncCursorDao

class LocalDataResetService(
    private val habitDao: HabitDao,
    private val completionDao: CompletionDao,
    private val groupDao: GroupDao,
    private val savedQuoteDao: SavedQuoteDao,
    private val outboxDao: OutboxDao,
    private val syncCursorDao: SyncCursorDao
) {
    suspend fun clearOwnerScope(ownerScope: String) {
        completionDao.deleteAllByScope(ownerScope)
        habitDao.deleteAllByScope(ownerScope)
        groupDao.deleteAllMembersByScope(ownerScope)
        groupDao.deleteAllSharedHabitsByScope(ownerScope)
        groupDao.deleteAllGroupsByScope(ownerScope)
        savedQuoteDao.deleteAllByScope(ownerScope)
        outboxDao.deleteAllByScope(ownerScope)
        syncCursorDao.deleteAll()
    }
}
