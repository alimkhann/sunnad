package com.arystan.almasuly.sunnadandroid.core.model

import java.time.Instant
import java.util.UUID

data class Quote(
    val id: UUID = UUID.randomUUID(),
    val locale: String,
    val text: String,
    val source: String?,
    val sortOrder: Int = 0,
    val active: Boolean = true,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now()
)

data class SavedQuote(
    val id: UUID = UUID.randomUUID(),
    val quoteId: UUID? = null,
    val text: String,
    val author: String,
    val savedAt: Instant = Instant.now()
)
