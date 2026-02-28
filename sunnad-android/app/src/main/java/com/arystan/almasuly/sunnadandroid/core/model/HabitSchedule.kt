package com.arystan.almasuly.sunnadandroid.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDate

@Serializable
sealed class HabitSchedule {
    abstract fun isDue(on: LocalDate): Boolean

    @Serializable
    @SerialName("daily")
    data object Daily : HabitSchedule() {
        override fun isDue(on: LocalDate): Boolean = true
    }

    @Serializable
    @SerialName("weekly")
    data class Weekly(val weekdays: Set<Weekday>) : HabitSchedule() {
        override fun isDue(on: LocalDate): Boolean {
            if (weekdays.isEmpty()) return false
            return weekdays.contains(Weekday.isoWeekday(on))
        }
    }

    companion object {
        fun fromStorage(frequency: String, weekdayIsoValues: Set<Int>): HabitSchedule {
            return when (frequency.lowercase()) {
                "weekly" -> Weekly(weekdayIsoValues.mapNotNull { Weekday.fromIsoWeekday(it) }.toSet())
                else -> Daily
            }
        }
    }
}
