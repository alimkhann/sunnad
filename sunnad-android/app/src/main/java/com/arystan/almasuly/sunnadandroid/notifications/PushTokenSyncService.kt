package com.arystan.almasuly.sunnadandroid.notifications

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.exception.PostgrestRestException
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
        val row = DeviceTokenRow(
            userId = userId.toString(),
            platform = "android",
            token = token.trim(),
            oneSignalSubscriptionId = normalizedOneSignal
        )

        runCatching {
            upsertTokenRow(row)
        }.onFailure { error ->
            val duplicateOneSignalSubscription = (error as? PostgrestRestException)?.let { restError ->
                restError.code == "23505" &&
                    restError.message.orEmpty().contains("device_tokens_onesignal_subscription_uidx", ignoreCase = true)
            } ?: false

            if (duplicateOneSignalSubscription && normalizedOneSignal != null) {
                runCatching {
                    client.from("device_tokens").delete {
                        filter { eq("onesignal_subscription_id", normalizedOneSignal) }
                    }
                    upsertTokenRow(row)
                }
            }
        }
    }

    override suspend fun clearToken(userId: UUID, token: String, oneSignalSubscriptionId: String?) {
        if (token.isBlank()) return
        runCatching {
            client.from("device_tokens").delete {
                filter {
                    eq("user_id", userId.toString())
                    eq("token", token.trim())
                }
            }
            val normalizedOneSignal = oneSignalSubscriptionId?.trim()?.takeIf { it.isNotEmpty() } ?: return@runCatching
            client.from("device_tokens").delete {
                filter {
                    eq("user_id", userId.toString())
                    eq("onesignal_subscription_id", normalizedOneSignal)
                }
            }
        }
    }

    private suspend fun upsertTokenRow(row: DeviceTokenRow) {
        client.from("device_tokens").upsert(row) {
            onConflict = "user_id,token"
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
