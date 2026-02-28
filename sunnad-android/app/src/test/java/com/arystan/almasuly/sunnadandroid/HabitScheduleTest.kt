package com.arystan.almasuly.sunnadandroid

import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class HabitScheduleTest {
    @Test
    fun dailyScheduleAlwaysDue() {
        val schedule: HabitSchedule = HabitSchedule.Daily
        assertTrue(schedule.isDue(LocalDate.of(2026, 2, 19)))
    }

    @Test
    fun weeklyScheduleOnlySelectedDays() {
        val schedule: HabitSchedule = HabitSchedule.Weekly(setOf(Weekday.MONDAY, Weekday.WEDNESDAY, Weekday.FRIDAY))
        assertTrue(schedule.isDue(LocalDate.of(2026, 2, 16)))
        assertFalse(schedule.isDue(LocalDate.of(2026, 2, 17)))
    }

    @Test
    fun isoWeekdayMappingWorks() {
        assertTrue(Weekday.isoWeekday(LocalDate.of(2026, 2, 16)) == Weekday.MONDAY)
        assertTrue(Weekday.isoWeekday(LocalDate.of(2026, 2, 15)) == Weekday.SUNDAY)
    }

    @Test
    fun weeklyAcrossYearBoundary() {
        val schedule: HabitSchedule = HabitSchedule.Weekly(setOf(Weekday.THURSDAY))
        assertTrue(schedule.isDue(LocalDate.of(2026, 12, 31)))
        assertFalse(schedule.isDue(LocalDate.of(2027, 1, 1)))
    }
}
