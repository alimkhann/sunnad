package com.arystan.almasuly.sunnadandroid.services

import androidx.compose.runtime.Immutable

@Immutable
enum class AppLanguage(val localeTag: String) {
    EN("en"),
    RU("ru"),
    KK("kk");

    companion object {
        fun fromRaw(raw: String): AppLanguage {
            return entries.firstOrNull { it.localeTag == raw.lowercase() } ?: EN
        }
    }
}

@Immutable
enum class AppAppearance {
    SYSTEM,
    LIGHT,
    DARK;

    companion object {
        fun fromRaw(raw: String): AppAppearance {
            return when (raw.lowercase()) {
                "light" -> LIGHT
                "dark" -> DARK
                else -> SYSTEM
            }
        }
    }
}
