package com.arystan.almasuly.sunnadandroid.app

import android.content.Context
import android.net.Uri
import com.arystan.almasuly.sunnadandroid.BuildConfig

data class AuthRuntimeConfig(
    val supabaseUrl: String,
    val supabaseAnonKey: String,
    val redirectUrl: String,
    val authScheme: String,
    val authHost: String,
    val isGoogleEnabled: Boolean,
    val isAppleEnabled: Boolean,
    val resendCooldownSeconds: Int,
    val source: String
)

class AuthRuntimeConfigResolver(
    context: Context,
    private val namespace: String
) {
    private val prefs = context.getSharedPreferences("sunnad_auth_runtime", Context.MODE_PRIVATE)

    fun resolve(
        buildUrl: String,
        buildAnonKey: String,
        buildRedirect: String,
        buildGoogleEnabled: Boolean,
        buildAppleEnabled: Boolean,
        buildResendCooldownSeconds: Int
    ): AuthRuntimeConfig? {
        var url = buildUrl.trim()
        var anon = buildAnonKey.trim()
        var redirect = buildRedirect.trim()
        var source = "build"

        if (BuildConfig.DEBUG) {
            resolveEnv(listOf("SUNNAD_SUPABASE_URL", "SUPABASE_URL"))?.let {
                url = it
                source = "env"
            }
            resolveEnv(
                listOf(
                    "SUNNAD_SUPABASE_ANON_KEY",
                    "SUPABASE_ANON_KEY",
                    "SUNNAD_SUPABASE_PUBLISHABLE_KEY",
                    "SUPABASE_PUBLISHABLE_KEY"
                )
            )?.let {
                anon = it
                source = "env"
            }
            resolveEnv(listOf("SUNNAD_AUTH_REDIRECT_URL"))?.let {
                redirect = it
                source = "env"
            }
        }

        if (url.isBlank() || anon.isBlank() || redirect.isBlank()) {
            val allowCached = BuildConfig.DEBUG && resolveBoolEnvOptional("SUNNAD_ALLOW_CACHED_SUPABASE_CONFIG") == true
            if (allowCached) {
                val cachedUrl = prefs.getString(cachedUrlKey(), null).orEmpty().trim()
                val cachedKey = prefs.getString(cachedKeyKey(), null).orEmpty().trim()
                if (cachedUrl.isNotBlank() && cachedKey.isNotBlank()) {
                    url = cachedUrl
                    anon = cachedKey
                    if (redirect.isBlank()) {
                        redirect = "adat://auth-callback"
                    }
                    source = "cache"
                }
            }
        }

        if ((url.isBlank() || anon.isBlank() || redirect.isBlank()) && BuildConfig.DEBUG) {
            val fallbackEnabled = resolveBoolEnvOptional("SUNNAD_ENABLE_LOCAL_SUPABASE_FALLBACK") == true
            if (fallbackEnabled) {
                url = "http://127.0.0.1:55421"
                anon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
                redirect = "adat://auth-callback"
                source = "fallback"
            }
        }

        if (url.isBlank() || anon.isBlank() || redirect.isBlank()) return null

        val redirectUri = runCatching { Uri.parse(redirect) }.getOrNull() ?: return null
        val scheme = redirectUri.scheme ?: return null
        val host = redirectUri.host ?: return null

        if (source == "build" || source == "env") {
            prefs.edit()
                .putString(cachedUrlKey(), url)
                .putString(cachedKeyKey(), anon)
                .apply()
        }

        return AuthRuntimeConfig(
            supabaseUrl = url,
            supabaseAnonKey = anon,
            redirectUrl = redirect,
            authScheme = scheme,
            authHost = host,
            isGoogleEnabled = buildGoogleEnabled,
            isAppleEnabled = buildAppleEnabled,
            resendCooldownSeconds = buildResendCooldownSeconds.coerceAtLeast(30),
            source = source
        )
    }

    fun diagnostics(config: AuthRuntimeConfig?): String {
        val envLabel = BuildConfig.SUNNAD_ENV_LABEL
        if (config == null) {
            return "env=$envLabel auth=UNCONFIGURED namespace=$namespace"
        }
        val host = runCatching { Uri.parse(config.supabaseUrl).host }.getOrNull().orEmpty().ifBlank { "unknown-host" }
        return "env=$envLabel auth=CONFIGURED host=$host source=${config.source} namespace=$namespace"
    }

    private fun resolveEnv(names: List<String>): String? {
        for (name in names) {
            val raw = System.getenv(name)?.trim()?.trim('"', '\'')
            if (!raw.isNullOrEmpty()) return raw
        }
        return null
    }

    private fun resolveBoolEnvOptional(name: String): Boolean? {
        return when (System.getenv(name)?.trim()?.lowercase()) {
            "1", "true", "yes" -> true
            "0", "false", "no" -> false
            else -> null
        }
    }

    private fun cachedUrlKey(): String = "sunnad.cached.supabase.url.$namespace"

    private fun cachedKeyKey(): String = "sunnad.cached.supabase.key.$namespace"
}
