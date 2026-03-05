package com.arystan.almasuly.sunnadandroid

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.content.ContextCompat
import androidx.core.os.LocaleListCompat
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.lifecycle.lifecycleScope
import com.onesignal.OneSignal
import com.arystan.almasuly.sunnadandroid.services.AppLanguage
import com.arystan.almasuly.sunnadandroid.services.AppSettingsStore
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import com.arystan.almasuly.sunnadandroid.app.SunnadApp

class MainActivity : AppCompatActivity() {
    private val pendingAuthCallback = mutableStateOf<Uri?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyStartupLocale()
        pendingAuthCallback.value = intent?.data
        enableEdgeToEdge()
        setContent {
            val permissionLauncher = rememberLauncherForActivityResult(
                contract = ActivityResultContracts.RequestPermission(),
                onResult = {}
            )
            val requestNotificationPermission = remember(permissionLauncher) {
                {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    lifecycleScope.launch {
                        runCatching {
                            OneSignal.Notifications.requestPermission(false)
                        }
                    }
                    Unit
                }
            }
            SunnadApp(
                pendingAuthCallback = pendingAuthCallback.value,
                onAuthCallbackConsumed = { pendingAuthCallback.value = null },
                onRequestNotificationPermission = requestNotificationPermission
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingAuthCallback.value = intent.data
    }

    private fun applyStartupLocale() {
        val startupLanguage = runBlocking {
            AppSettingsStore(applicationContext).settings.first().language
        }
        val localeTag = AppLanguage.fromRaw(startupLanguage).localeTag
        AppCompatDelegate.setApplicationLocales(
            LocaleListCompat.forLanguageTags(localeTag)
        )
    }
}
