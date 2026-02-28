package com.arystan.almasuly.sunnadandroid

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.mutableStateOf
import com.arystan.almasuly.sunnadandroid.app.SunnadApp

class MainActivity : ComponentActivity() {
    private val pendingAuthCallback = mutableStateOf<Uri?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingAuthCallback.value = intent?.data
        enableEdgeToEdge()
        setContent {
            SunnadApp(
                pendingAuthCallback = pendingAuthCallback.value,
                onAuthCallbackConsumed = { pendingAuthCallback.value = null }
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingAuthCallback.value = intent.data
    }
}
