package com.arystan.almasuly.sunnadandroid.data.remote

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.ktor.client.engine.okhttp.OkHttp

class SupabaseClientProvider(
    private val url: String,
    private val anonKey: String,
    private val authScheme: String,
    private val authHost: String,
    private val authRedirectUrl: String
) {
    fun create(): SupabaseClient {
        return createSupabaseClient(
            supabaseUrl = url,
            supabaseKey = anonKey
        ) {
            // Explicitly pin OkHttp engine to avoid runtime engine discovery failures.
            httpEngine = OkHttp.create {}
            install(Auth) {
                scheme = authScheme
                host = authHost
                defaultRedirectUrl = authRedirectUrl
                autoLoadFromStorage = true
                autoSaveToStorage = true
            }
            install(Postgrest)
            install(Functions)
            install(Realtime)
        }
    }
}
