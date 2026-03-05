package com.arystan.almasuly.sunnadandroid.notifications

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

interface PushTokenSyncService {
    suspend fun registerToken(userId: UUID, token: String, oneSignalSubscriptionId: String? = null)
    suspend fun clearToken(userId: UUID, token: String, oneSignalSubscriptionId: String? = null)
}

class NoOpPushTokenSyncService : PushTokenSyncService {
    override suspend fun registerToken(userId: UUID, token: String, oneSignalSubscriptionId: String?) = Unit
    override suspend fun clearToken(userId: UUID, token: String, oneSignalSubscriptionId: String?) = Unit
}

class SupabasePushTokenSyncService(
    private val client: SupabaseClient
) : PushTokenSyncService {
    override suspend fun registerToken(userId: UUID, token: String, oneSignalSubscriptionId: String?) {
        if (token.isBlank()) return
        val normalizedOneSignal = oneSignalSubscriptionId
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: run {
                val prefix = "onesignal-subscription:"
                token.trim().takeIf { it.startsWith(prefix) }
                    ?.removePrefix(prefix)
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
            }
        client.from("device_tokens").upsert(
            value = DeviceTokenRow(
                userId = userId.toString(),
                platform = "android",
                token = token.trim(),
                oneSignalSubscriptionId = normalizedOneSignal
            )
        )
    }

    override suspend fun clearToken(userId: UUID, token: String, oneSignalSubscriptionId: String?) {
        if (token.isBlank()) return
        client.from("device_tokens").delete {
            filter {
                eq("user_id", userId.toString())
                eq("token", token.trim())
            }
        }
        val normalizedOneSignal = oneSignalSubscriptionId?.trim()?.takeIf { it.isNotEmpty() } ?: return
        client.from("device_tokens").delete {
            filter {
                eq("user_id", userId.toString())
                eq("onesignal_subscription_id", normalizedOneSignal)
            }
        }
    }
}

@Serializable
private data class DeviceTokenRow(
    @SerialName("user_id") val userId: String,
    val platform: String,
    val token: String,
    @SerialName("onesignal_subscription_id") val oneSignalSubscriptionId: String? = null
)
