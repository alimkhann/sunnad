package com.arystan.almasuly.sunnadandroid.data.local.repository

import com.arystan.almasuly.sunnadandroid.core.local.OwnerScopeResolver
import com.arystan.almasuly.sunnadandroid.core.model.Quote
import com.arystan.almasuly.sunnadandroid.core.model.SavedQuote
import com.arystan.almasuly.sunnadandroid.core.rules.QuoteDayKey
import com.arystan.almasuly.sunnadandroid.domain.repository.QuotesRepository
import com.arystan.almasuly.sunnadandroid.data.local.dao.QuoteDao
import com.arystan.almasuly.sunnadandroid.data.local.dao.SavedQuoteDao
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toDomain
import com.arystan.almasuly.sunnadandroid.data.local.mappers.toEntity
import java.time.LocalDate
import java.util.UUID

class QuotesLocalRepository(
    private val quoteDao: QuoteDao,
    private val savedQuoteDao: SavedQuoteDao,
    private val ownerScopeResolver: OwnerScopeResolver
) : QuotesRepository {

    override suspend fun fetchQuoteOfDay(locale: String, day: LocalDate): Quote? {
        val localized = quoteDao.fetchActiveByLocale(locale).map { it.toDomain() }
        val fallback = if (localized.isNotEmpty()) localized else quoteDao.fetchActiveByLocale("en").map { it.toDomain() }
        if (fallback.isEmpty()) return null

        val dayKey = QuoteDayKey.value(day, locale)
        val index = QuoteDayKey.deterministicIndex(dayKey, fallback.size)
        return fallback[index]
    }

    override suspend fun fetchSavedQuotes(): List<SavedQuote> {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        return savedQuoteDao.fetchByScope(scope).map { it.toDomain() }
    }

    override suspend fun isQuoteSaved(quoteId: UUID): Boolean {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        return savedQuoteDao.findByQuoteId(scope, quoteId.toString()) != null
    }

    override suspend fun saveQuote(quote: Quote) {
        val scope = ownerScopeResolver.currentOwnerScopeRaw
        val existing = savedQuoteDao.findByQuoteId(scope, quote.id.toString())
        if (existing != null) return

        val item = SavedQuote(quoteId = quote.id, text = quote.text, author = quote.source ?: "")
        savedQuoteDao.upsert(item.toEntity(scope))
    }

    override suspend fun deleteAllSavedQuotes() {
        savedQuoteDao.deleteAllByScope(ownerScopeResolver.currentOwnerScopeRaw)
    }
}
