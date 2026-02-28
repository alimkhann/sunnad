package com.arystan.almasuly.sunnadandroid.core.rules

import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

object QuoteDayKey {
    private val formatter = DateTimeFormatter.ISO_LOCAL_DATE

    fun value(day: LocalDate, locale: String): String {
        return "${locale.lowercase()}-${formatter.format(day)}"
    }

    fun value(nowEpochMillis: Long, locale: String, zoneId: ZoneId): String {
        val day = java.time.Instant.ofEpochMilli(nowEpochMillis).atZone(zoneId).toLocalDate()
        return value(day, locale)
    }

    fun deterministicIndex(dayKey: String, count: Int): Int {
        if (count <= 0) return 0
        var hash = 0
        dayKey.forEach { ch ->
            hash = (hash * 31) + ch.code
        }
        return kotlin.math.abs(hash) % count
    }
}
