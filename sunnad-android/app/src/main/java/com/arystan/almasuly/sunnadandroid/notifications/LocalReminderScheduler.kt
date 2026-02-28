package com.arystan.almasuly.sunnadandroid.notifications

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID
import kotlin.math.abs

interface LocalReminderScheduler {
    suspend fun syncHabitReminders(habits: List<Habit>, enabled: Boolean, completedHabitIds: Set<UUID>)
    suspend fun syncQuoteReminders(enabled: Boolean, locale: String, startDay: LocalDate)
}

class NoOpLocalReminderScheduler : LocalReminderScheduler {
    override suspend fun syncHabitReminders(habits: List<Habit>, enabled: Boolean, completedHabitIds: Set<UUID>) = Unit
    override suspend fun syncQuoteReminders(enabled: Boolean, locale: String, startDay: LocalDate) = Unit
}

class AlarmLocalReminderScheduler(
    private val context: Context
) : LocalReminderScheduler {
    private val appContext = context.applicationContext
    private val alarmManager: AlarmManager = appContext.getSystemService() ?: error("AlarmManager unavailable")
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override suspend fun syncHabitReminders(
        habits: List<Habit>,
        enabled: Boolean,
        completedHabitIds: Set<UUID>
    ) {
        val previouslyScheduled = prefs.getStringSet(KEY_HABIT_IDS, emptySet())?.toSet().orEmpty()
        if (!enabled) {
            previouslyScheduled.forEach { id ->
                runCatching { UUID.fromString(id) }.getOrNull()?.let(::cancelHabitAlarm)
            }
            prefs.edit()
                .putStringSet(KEY_HABIT_IDS, emptySet())
                .putBoolean(KEY_HABITS_ENABLED, false)
                .apply()
            return
        }

        val activeIds = mutableSetOf<String>()
        val now = ZonedDateTime.now()
        val today = LocalDate.now()

        habits
            .filter { !it.archived && it.reminder != null }
            .forEach { habit ->
                val reminder = habit.reminder ?: return@forEach
                val startDate = if (completedHabitIds.contains(habit.id) && habit.schedule.isDue(today)) {
                    today.plusDays(1)
                } else {
                    today
                }
                val triggerAt = nextTriggerAt(
                    schedule = habit.schedule,
                    hour = reminder.normalizedHour,
                    minute = reminder.normalizedMinute,
                    now = now,
                    startDate = startDate
                )

                if (triggerAt == null) {
                    cancelHabitAlarm(habit.id)
                    return@forEach
                }

                scheduleHabitAlarm(
                    habit = habit,
                    triggerAt = triggerAt,
                    hour = reminder.normalizedHour,
                    minute = reminder.normalizedMinute
                )
                activeIds += habit.id.toString()
            }

        (previouslyScheduled - activeIds).forEach { id ->
            runCatching { UUID.fromString(id) }.getOrNull()?.let(::cancelHabitAlarm)
        }
        prefs.edit()
            .putStringSet(KEY_HABIT_IDS, activeIds)
            .putBoolean(KEY_HABITS_ENABLED, true)
            .apply()
    }

    override suspend fun syncQuoteReminders(enabled: Boolean, locale: String, startDay: LocalDate) {
        val previousLocale = prefs.getString(KEY_QUOTE_LOCALE, null)
        if (previousLocale != null && previousLocale != locale) {
            cancelQuoteAlarm(previousLocale)
        }

        if (!enabled) {
            previousLocale?.let(::cancelQuoteAlarm)
            prefs.edit()
                .remove(KEY_QUOTE_LOCALE)
                .putBoolean(KEY_QUOTES_ENABLED, false)
                .apply()
            return
        }

        val triggerAt = nextQuoteTrigger(startDay)
        scheduleQuoteAlarm(locale = locale, triggerAt = triggerAt)
        prefs.edit()
            .putString(KEY_QUOTE_LOCALE, locale)
            .putBoolean(KEY_QUOTES_ENABLED, true)
            .apply()
    }

    private fun scheduleHabitAlarm(habit: Habit, triggerAt: ZonedDateTime, hour: Int, minute: Int) {
        val scheduleType = when (habit.schedule) {
            HabitSchedule.Daily -> "daily"
            is HabitSchedule.Weekly -> "weekly"
        }
        val weekdayCsv = (habit.schedule as? HabitSchedule.Weekly)
            ?.weekdays
            ?.map { it.isoValue.toString() }
            ?.sorted()
            ?.joinToString(",")
            .orEmpty()

        val intent = Intent(appContext, LocalReminderReceiver::class.java).apply {
            action = ACTION_HABIT
            putExtra(EXTRA_HABIT_ID, habit.id.toString())
            putExtra(EXTRA_HABIT_TITLE, habit.name)
            putExtra(EXTRA_SCHEDULE_TYPE, scheduleType)
            putExtra(EXTRA_WEEKDAYS, weekdayCsv)
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }

        setExact(triggerAt.toInstant(), pendingIntentForHabit(habit.id, intent))
    }

    private fun scheduleQuoteAlarm(locale: String, triggerAt: ZonedDateTime) {
        val intent = Intent(appContext, LocalReminderReceiver::class.java).apply {
            action = ACTION_QUOTE
            putExtra(EXTRA_QUOTE_LOCALE, locale)
            putExtra(EXTRA_HOUR, QUOTE_REMINDER_HOUR)
            putExtra(EXTRA_MINUTE, QUOTE_REMINDER_MINUTE)
        }
        setExact(triggerAt.toInstant(), pendingIntentForQuote(locale, intent))
    }

    private fun cancelHabitAlarm(habitId: UUID) {
        val intent = Intent(appContext, LocalReminderReceiver::class.java).apply {
            action = ACTION_HABIT
            putExtra(EXTRA_HABIT_ID, habitId.toString())
        }
        alarmManager.cancel(pendingIntentForHabit(habitId, intent))
    }

    private fun cancelQuoteAlarm(locale: String) {
        val intent = Intent(appContext, LocalReminderReceiver::class.java).apply {
            action = ACTION_QUOTE
            putExtra(EXTRA_QUOTE_LOCALE, locale)
        }
        alarmManager.cancel(pendingIntentForQuote(locale, intent))
    }

    private fun pendingIntentForHabit(habitId: UUID, intent: Intent): PendingIntent {
        return PendingIntent.getBroadcast(
            appContext,
            requestCode("habit:$habitId"),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun pendingIntentForQuote(locale: String, intent: Intent): PendingIntent {
        return PendingIntent.getBroadcast(
            appContext,
            requestCode("quote:$locale"),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun setExact(triggerAt: Instant, pendingIntent: PendingIntent) {
        val triggerAtMillis = triggerAt.toEpochMilli()
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms() -> {
                    setInexact(triggerAtMillis, pendingIntent)
                }

                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }

                else -> {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            }
        } catch (_: SecurityException) {
            // Never crash app startup if exact alarm permission is unavailable.
            setInexact(triggerAtMillis, pendingIntent)
        }
    }

    private fun setInexact(triggerAtMillis: Long, pendingIntent: PendingIntent) {
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }

                else -> {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                }
            }
        } catch (_: SecurityException) {
            // Ignore scheduling failure; reminders can be re-attempted later from settings/sync.
        }
    }

    private fun nextQuoteTrigger(startDay: LocalDate): ZonedDateTime {
        val now = ZonedDateTime.now()
        var candidate = ZonedDateTime.of(
            startDay,
            LocalTime.of(QUOTE_REMINDER_HOUR, QUOTE_REMINDER_MINUTE),
            ZoneId.systemDefault()
        )
        while (!candidate.isAfter(now.plusSeconds(20))) {
            candidate = candidate.plusDays(1)
        }
        return candidate
    }

    private fun nextTriggerAt(
        schedule: HabitSchedule,
        hour: Int,
        minute: Int,
        now: ZonedDateTime,
        startDate: LocalDate
    ): ZonedDateTime? {
        val zone = ZoneId.systemDefault()
        for (offset in 0..14) {
            val date = startDate.plusDays(offset.toLong())
            if (!schedule.isDue(date)) continue
            val candidate = ZonedDateTime.of(LocalDateTime.of(date, LocalTime.of(hour, minute)), zone)
            if (candidate.isAfter(now.plusSeconds(20))) return candidate
        }
        return null
    }

    private fun requestCode(raw: String): Int = abs(raw.hashCode())

    companion object {
        private const val PREFS_NAME = "sunnad_local_reminders"
        private const val KEY_HABIT_IDS = "habit_ids"
        private const val KEY_QUOTE_LOCALE = "quote_locale"
        private const val KEY_HABITS_ENABLED = "habit_enabled"
        private const val KEY_QUOTES_ENABLED = "quote_enabled"
        private const val QUOTE_REMINDER_HOUR = 9
        private const val QUOTE_REMINDER_MINUTE = 0
        private const val CHANNEL_HABITS = "habit_reminders"
        private const val CHANNEL_QUOTES = "quote_reminders"
        const val ACTION_HABIT = "com.arystan.almasuly.sunnadandroid.notifications.HABIT_REMINDER"
        const val ACTION_QUOTE = "com.arystan.almasuly.sunnadandroid.notifications.QUOTE_REMINDER"
        const val EXTRA_HABIT_ID = "habit_id"
        const val EXTRA_HABIT_TITLE = "habit_title"
        const val EXTRA_SCHEDULE_TYPE = "schedule_type"
        const val EXTRA_WEEKDAYS = "weekdays_csv"
        const val EXTRA_HOUR = "hour"
        const val EXTRA_MINUTE = "minute"
        const val EXTRA_QUOTE_LOCALE = "quote_locale"

        fun handleAlarm(context: Context, intent: Intent?) {
            if (intent == null) return
            val appContext = context.applicationContext
            val manager = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            ensureChannels(appContext, manager)
            when (intent.action) {
                ACTION_HABIT -> {
                    val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    if (!prefs.getBoolean(KEY_HABITS_ENABLED, true)) return
                    val habitId = intent.getStringExtra(EXTRA_HABIT_ID) ?: return
                    val activeIds = prefs.getStringSet(KEY_HABIT_IDS, emptySet()).orEmpty()
                    if (!activeIds.contains(habitId)) return
                    val title = appContext.getString(R.string.notification_habit_reminder_title)
                    val habitTitle = intent.getStringExtra(EXTRA_HABIT_TITLE)
                        ?: appContext.getString(R.string.app_name)
                    val body = appContext.getString(R.string.notification_habit_reminder_body, habitTitle)
                    val notification = NotificationCompat.Builder(appContext, CHANNEL_HABITS)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentTitle(title)
                        .setContentText(body)
                        .setAutoCancel(true)
                        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                        .build()
                    manager.notify(requestCode("notify:habit:$habitId"), notification)
                    rescheduleHabitFromIntent(appContext, intent)
                }

                ACTION_QUOTE -> {
                    val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    if (!prefs.getBoolean(KEY_QUOTES_ENABLED, true)) return
                    val locale = intent.getStringExtra(EXTRA_QUOTE_LOCALE).orEmpty()
                    val notification = NotificationCompat.Builder(appContext, CHANNEL_QUOTES)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentTitle(appContext.getString(R.string.notification_quote_reminder_title))
                        .setContentText(appContext.getString(R.string.notification_quote_reminder_body))
                        .setAutoCancel(true)
                        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                        .build()
                    manager.notify(requestCode("notify:quote:$locale"), notification)
                    rescheduleQuoteFromIntent(appContext, intent)
                }
            }
        }

        private fun rescheduleHabitFromIntent(context: Context, sourceIntent: Intent) {
            val habitIdRaw = sourceIntent.getStringExtra(EXTRA_HABIT_ID) ?: return
            val habitId = runCatching { UUID.fromString(habitIdRaw) }.getOrNull() ?: return
            val hour = sourceIntent.getIntExtra(EXTRA_HOUR, -1).takeIf { it in 0..23 } ?: return
            val minute = sourceIntent.getIntExtra(EXTRA_MINUTE, -1).takeIf { it in 0..59 } ?: return
            val schedule = parseSchedule(
                type = sourceIntent.getStringExtra(EXTRA_SCHEDULE_TYPE).orEmpty(),
                weekdaysCsv = sourceIntent.getStringExtra(EXTRA_WEEKDAYS).orEmpty()
            )

            val now = ZonedDateTime.now()
            val scheduler = AlarmLocalReminderScheduler(context)
            val triggerAt = scheduler.nextTriggerAt(
                schedule = schedule,
                hour = hour,
                minute = minute,
                now = now,
                startDate = now.toLocalDate().plusDays(1)
            ) ?: return

            val nextIntent = Intent(context, LocalReminderReceiver::class.java).apply {
                action = ACTION_HABIT
                putExtra(EXTRA_HABIT_ID, habitId.toString())
                putExtra(EXTRA_HABIT_TITLE, sourceIntent.getStringExtra(EXTRA_HABIT_TITLE).orEmpty())
                putExtra(EXTRA_SCHEDULE_TYPE, sourceIntent.getStringExtra(EXTRA_SCHEDULE_TYPE).orEmpty())
                putExtra(EXTRA_WEEKDAYS, sourceIntent.getStringExtra(EXTRA_WEEKDAYS).orEmpty())
                putExtra(EXTRA_HOUR, hour)
                putExtra(EXTRA_MINUTE, minute)
            }
            scheduler.setExact(triggerAt.toInstant(), scheduler.pendingIntentForHabit(habitId, nextIntent))
        }

        private fun rescheduleQuoteFromIntent(context: Context, sourceIntent: Intent) {
            val locale = sourceIntent.getStringExtra(EXTRA_QUOTE_LOCALE).orEmpty()
            val hour = sourceIntent.getIntExtra(EXTRA_HOUR, QUOTE_REMINDER_HOUR).coerceIn(0, 23)
            val minute = sourceIntent.getIntExtra(EXTRA_MINUTE, QUOTE_REMINDER_MINUTE).coerceIn(0, 59)
            val scheduler = AlarmLocalReminderScheduler(context)
            val now = ZonedDateTime.now()
            var next = ZonedDateTime.of(
                now.toLocalDate().plusDays(1),
                LocalTime.of(hour, minute),
                ZoneId.systemDefault()
            )
            while (!next.isAfter(now.plusSeconds(20))) {
                next = next.plusDays(1)
            }
            val nextIntent = Intent(context, LocalReminderReceiver::class.java).apply {
                action = ACTION_QUOTE
                putExtra(EXTRA_QUOTE_LOCALE, locale)
                putExtra(EXTRA_HOUR, hour)
                putExtra(EXTRA_MINUTE, minute)
            }
            scheduler.setExact(next.toInstant(), scheduler.pendingIntentForQuote(locale, nextIntent))
        }

        private fun parseSchedule(type: String, weekdaysCsv: String): HabitSchedule {
            return if (type.equals("weekly", ignoreCase = true)) {
                val weekdays = weekdaysCsv
                    .split(",")
                    .mapNotNull { it.trim().toIntOrNull() }
                    .mapNotNull(Weekday::fromIsoWeekday)
                    .toSet()
                HabitSchedule.Weekly(weekdays)
            } else {
                HabitSchedule.Daily
            }
        }

        private fun ensureChannels(context: Context, manager: NotificationManager) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            if (manager.getNotificationChannel(CHANNEL_HABITS) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_HABITS,
                        context.getString(R.string.notification_channel_habits),
                        NotificationManager.IMPORTANCE_DEFAULT
                    )
                )
            }
            if (manager.getNotificationChannel(CHANNEL_QUOTES) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_QUOTES,
                        context.getString(R.string.notification_channel_quotes),
                        NotificationManager.IMPORTANCE_DEFAULT
                    )
                )
            }
        }

        private fun requestCode(raw: String): Int = abs(raw.hashCode())
    }
}
