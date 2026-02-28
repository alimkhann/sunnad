package com.arystan.almasuly.sunnadandroid.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "saved_quotes")
data class SavedQuoteEntity(
    @PrimaryKey val id: String,
    val ownerScope: String,
    val quoteId: String?,
    val text: String,
    val author: String,
    val savedAtEpochMillis: Long
)
