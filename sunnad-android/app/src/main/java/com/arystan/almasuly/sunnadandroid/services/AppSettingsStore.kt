package com.arystan.almasuly.sunnadandroid.services

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore(name = "sunnad_settings")

data class AppSettings(
    val language: String = "en",
    val appearance: String = "system",
    val onboardingCompleted: Boolean = false,
    val habitRemindersEnabled: Boolean = true,
    val quoteReminderEnabled: Boolean = true,
    val groupRemindersEnabled: Boolean = true,
    val hapticsEnabled: Boolean = true,
    val soundsEnabled: Boolean = false
)

class AppSettingsStore(private val context: Context) {
    private object Keys {
        val language = stringPreferencesKey("language")
        val appearance = stringPreferencesKey("appearance")
        val onboardingCompleted = booleanPreferencesKey("onboarding_completed")
        val habitReminders = booleanPreferencesKey("habit_reminders")
        val quoteReminder = booleanPreferencesKey("quote_reminder")
        val groupReminders = booleanPreferencesKey("group_reminders")
        val haptics = booleanPreferencesKey("haptics")
        val sounds = booleanPreferencesKey("sounds")
    }

    val settings: Flow<AppSettings> = context.settingsDataStore.data.map { prefs ->
        AppSettings(
            language = prefs[Keys.language] ?: "en",
            appearance = prefs[Keys.appearance] ?: "system",
            onboardingCompleted = prefs[Keys.onboardingCompleted] ?: false,
            habitRemindersEnabled = prefs[Keys.habitReminders] ?: true,
            quoteReminderEnabled = prefs[Keys.quoteReminder] ?: true,
            groupRemindersEnabled = prefs[Keys.groupReminders] ?: true,
            hapticsEnabled = prefs[Keys.haptics] ?: true,
            soundsEnabled = prefs[Keys.sounds] ?: false
        )
    }

    suspend fun update(transform: (AppSettings) -> AppSettings) {
        context.settingsDataStore.edit { prefs ->
            val current = prefs.toSettings()
            val next = transform(current)
            prefs[Keys.language] = next.language
            prefs[Keys.appearance] = next.appearance
            prefs[Keys.onboardingCompleted] = next.onboardingCompleted
            prefs[Keys.habitReminders] = next.habitRemindersEnabled
            prefs[Keys.quoteReminder] = next.quoteReminderEnabled
            prefs[Keys.groupReminders] = next.groupRemindersEnabled
            prefs[Keys.haptics] = next.hapticsEnabled
            prefs[Keys.sounds] = next.soundsEnabled
        }
    }

    private fun Preferences.toSettings(): AppSettings {
        return AppSettings(
            language = this[Keys.language] ?: "en",
            appearance = this[Keys.appearance] ?: "system",
            onboardingCompleted = this[Keys.onboardingCompleted] ?: false,
            habitRemindersEnabled = this[Keys.habitReminders] ?: true,
            quoteReminderEnabled = this[Keys.quoteReminder] ?: true,
            groupRemindersEnabled = this[Keys.groupReminders] ?: true,
            hapticsEnabled = this[Keys.haptics] ?: true,
            soundsEnabled = this[Keys.sounds] ?: false
        )
    }
}
