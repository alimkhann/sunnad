package com.arystan.almasuly.sunnadandroid.core.model

import java.time.DayOfWeek
import java.time.LocalDate

enum class Weekday(val isoValue: Int) {
    MONDAY(1),
    TUESDAY(2),
    WEDNESDAY(3),
    THURSDAY(4),
    FRIDAY(5),
    SATURDAY(6),
    SUNDAY(7);

    val mondayFirstIndex: Int
        get() = isoValue - 1

    companion object {
        fun fromIsoWeekday(value: Int): Weekday? = entries.firstOrNull { it.isoValue == value }

        fun isoWeekday(date: LocalDate): Weekday {
            val iso = date.dayOfWeek.value
            return fromIsoWeekday(iso) ?: MONDAY
        }

        fun fromMondayFirstIndex(index: Int): Weekday? = fromIsoWeekday(index + 1)

        fun fromDayOfWeek(dayOfWeek: DayOfWeek): Weekday = fromIsoWeekday(dayOfWeek.value) ?: MONDAY
    }
}
