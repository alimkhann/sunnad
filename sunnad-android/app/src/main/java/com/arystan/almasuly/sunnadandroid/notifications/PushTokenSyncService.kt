package com.arystan.almasuly.sunnadandroid.notifications

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

interface PushTokenSyncService {
    suspend fun registerToken(userId: UUID, token: String)
    suspend fun clearToken(userId: UUID, token: String)
}

class NoOpPushTokenSyncService : PushTokenSyncService {
    override suspend fun registerToken(userId: UUID, token: String) = Unit
    override suspend fun clearToken(userId: UUID, token: String) = Unit
}

class SupabasePushTokenSyncService(
    private val client: SupabaseClient
) : PushTokenSyncService {
    override suspend fun registerToken(userId: UUID, token: String) {
        if (token.isBlank()) return
        client.from("device_tokens").upsert(
            value = DeviceTokenRow(
                userId = userId.toString(),
                platform = "android",
                token = token.trim()
            )
        )
    }

    override suspend fun clearToken(userId: UUID, token: String) {
        if (token.isBlank()) return
        client.from("device_tokens").delete {
            filter {
                eq("user_id", userId.toString())
                eq("token", token.trim())
            }
        }
    }
}

@Serializable
private data class DeviceTokenRow(
    @SerialName("user_id") val userId: String,
    val platform: String,
    val token: String
)
