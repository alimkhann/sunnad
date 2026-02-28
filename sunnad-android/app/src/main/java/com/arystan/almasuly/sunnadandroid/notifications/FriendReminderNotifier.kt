package com.arystan.almasuly.sunnadandroid.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import com.arystan.almasuly.sunnadandroid.R

data class FriendReminderPayload(
    val habitTitle: String,
    val fromDisplayName: String?
)

class FriendReminderNotifier(private val context: Context) {
    private val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun show(payload: FriendReminderPayload) {
        ensureChannel()
        val title = payload.fromDisplayName?.let {
            context.getString(R.string.notification_friend_reminder_title_named, it)
        } ?: context.getString(R.string.notification_friend_reminder_title_default)
        val body = context.getString(R.string.notification_friend_reminder, payload.habitTitle)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_friends),
            NotificationManager.IMPORTANCE_DEFAULT
        )
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "friend_reminders"
    }
}
