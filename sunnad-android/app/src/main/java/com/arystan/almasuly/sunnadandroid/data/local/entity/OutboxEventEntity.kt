package com.arystan.almasuly.sunnadandroid.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "outbox_events")
data class OutboxEventEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ownerScope: String,
    val eventType: String,
    val payloadJson: String,
    val createdAtEpochMillis: Long,
    val attempts: Int
)
