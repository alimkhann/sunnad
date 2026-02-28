package com.arystan.almasuly.sunnadandroid.domain.repository

import com.arystan.almasuly.sunnadandroid.core.model.Quote
import com.arystan.almasuly.sunnadandroid.core.model.SavedQuote
import java.time.LocalDate
import java.util.UUID

interface QuotesRepository {
    suspend fun fetchQuoteOfDay(locale: String, day: LocalDate): Quote?
    suspend fun fetchSavedQuotes(): List<SavedQuote>
    suspend fun isQuoteSaved(quoteId: UUID): Boolean
    suspend fun saveQuote(quote: Quote)
    suspend fun deleteAllSavedQuotes()
}
