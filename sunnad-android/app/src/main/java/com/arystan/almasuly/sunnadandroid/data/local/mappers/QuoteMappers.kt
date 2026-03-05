package com.arystan.almasuly.sunnadandroid.data.local.mappers

import com.arystan.almasuly.sunnadandroid.core.model.Quote
import com.arystan.almasuly.sunnadandroid.core.model.SavedQuote
import com.arystan.almasuly.sunnadandroid.data.local.entity.QuoteEntity
import com.arystan.almasuly.sunnadandroid.data.local.entity.SavedQuoteEntity
import java.util.UUID

private fun normalizeLegacyBranding(value: String?): String? {
    val trimmed = value?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    return if (trimmed.equals("sunnad", ignoreCase = true)) "Adat" else trimmed
}

fun QuoteEntity.toDomain(): Quote {
    return Quote(
        id = UUID.fromString(id),
        locale = locale,
        text = text,
        source = normalizeLegacyBranding(source),
        sortOrder = sortOrder,
        active = active,
        createdAt = createdAtEpochMillis.toInstantSafe(),
        updatedAt = updatedAtEpochMillis.toInstantSafe()
    )
}

fun Quote.toEntity(): QuoteEntity {
    return QuoteEntity(
        id = id.toString(),
        locale = locale,
        text = text,
        source = normalizeLegacyBranding(source),
        sortOrder = sortOrder,
        active = active,
        createdAtEpochMillis = createdAt.toEpochMillisSafe(),
        updatedAtEpochMillis = updatedAt.toEpochMillisSafe()
    )
}

fun SavedQuoteEntity.toDomain(): SavedQuote {
    return SavedQuote(
        id = UUID.fromString(id),
        quoteId = quoteId?.let(UUID::fromString),
        text = text,
        author = normalizeLegacyBranding(author).orEmpty(),
        savedAt = savedAtEpochMillis.toInstantSafe()
    )
}

fun SavedQuote.toEntity(ownerScope: String): SavedQuoteEntity {
    return SavedQuoteEntity(
        id = id.toString(),
        ownerScope = ownerScope,
        quoteId = quoteId?.toString(),
        text = text,
        author = normalizeLegacyBranding(author).orEmpty(),
        savedAtEpochMillis = savedAt.toEpochMillisSafe()
    )
}
