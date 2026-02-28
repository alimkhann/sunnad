package com.arystan.almasuly.sunnadandroid.core.local

import java.util.UUID

sealed class OwnerScope {
    data object Guest : OwnerScope()
    data class User(val userId: UUID) : OwnerScope()

    val rawValue: String
        get() = when (this) {
            Guest -> "guest"
            is User -> "user:${userId.toString().lowercase()}"
        }

    companion object {
        fun fromRaw(raw: String): OwnerScope? {
            if (raw == "guest") return Guest
            if (raw.startsWith("user:")) {
                val id = raw.removePrefix("user:")
                return UUID.fromString(id).let(::User)
            }
            return null
        }
    }
}
