package com.arystan.almasuly.sunnadandroid

import com.arystan.almasuly.sunnadandroid.core.rules.QuoteDayKey
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class QuoteDayKeyTest {
    @Test
    fun dayKeyIncludesLocaleAndDate() {
        val key = QuoteDayKey.value(LocalDate.of(2026, 2, 19), "ru")
        assertEquals("ru-2026-02-19", key)
    }

    @Test
    fun deterministicIndexIsStable() {
        val key = "en-2026-02-19"
        val first = QuoteDayKey.deterministicIndex(key, 10)
        val second = QuoteDayKey.deterministicIndex(key, 10)
        assertEquals(first, second)
    }

    @Test
    fun deterministicIndexHandlesZeroCount() {
        assertEquals(0, QuoteDayKey.deterministicIndex("en-2026-02-19", 0))
    }
}
