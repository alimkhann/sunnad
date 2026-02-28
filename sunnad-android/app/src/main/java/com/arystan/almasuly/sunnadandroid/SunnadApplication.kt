package com.arystan.almasuly.sunnadandroid

import android.app.Application
import com.arystan.almasuly.sunnadandroid.app.AppContainer
import com.arystan.almasuly.sunnadandroid.sync.SyncWorker

class SunnadApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        SyncWorker.schedule(this)
    }
}
