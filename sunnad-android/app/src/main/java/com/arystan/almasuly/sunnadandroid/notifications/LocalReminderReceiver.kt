package com.arystan.almasuly.sunnadandroid.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class LocalReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AlarmLocalReminderScheduler.handleAlarm(context, intent)
    }
}
