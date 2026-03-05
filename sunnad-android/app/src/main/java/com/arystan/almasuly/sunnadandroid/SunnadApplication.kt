package com.arystan.almasuly.sunnadandroid

import android.app.Application
import com.onesignal.OneSignal
import com.arystan.almasuly.sunnadandroid.app.AppContainer
import com.arystan.almasuly.sunnadandroid.sync.SyncWorker

class SunnadApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        val oneSignalAppId = BuildConfig.SUNNAD_ONESIGNAL_APP_ID.trim()
        if (oneSignalAppId.isNotBlank()) {
            runCatching {
                OneSignal.initWithContext(this, oneSignalAppId)
            }
        }
        container = AppContainer(this)
        SyncWorker.schedule(this)
    }
}
