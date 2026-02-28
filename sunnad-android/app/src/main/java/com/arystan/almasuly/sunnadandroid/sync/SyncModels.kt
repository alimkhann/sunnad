package com.arystan.almasuly.sunnadandroid.sync

enum class SyncTrigger {
    AUTH,
    RESTORE,
    FOREGROUND,
    BACKGROUND,
    MANUAL
}

enum class OutboxEventType {
    UPSERT_HABIT,
    DELETE_HABIT,
    UPSERT_COMPLETION,
    INSERT_SAVED_QUOTE,
    DELETE_SAVED_QUOTE,
    UPSERT_GROUP_SHARED_HABIT
}
