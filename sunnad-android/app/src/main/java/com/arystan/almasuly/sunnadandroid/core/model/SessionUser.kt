package com.arystan.almasuly.sunnadandroid.core.model

import java.util.UUID

enum class AuthProvider {
    EMAIL,
    GOOGLE,
    APPLE,
    UNKNOWN
}

data class SessionUser(
    val id: UUID,
    val email: String?,
    val username: String?,
    val avatarUrl: String? = null,
    val provider: AuthProvider = AuthProvider.UNKNOWN
) {
    val displayName: String
        get() = when {
            !username.isNullOrBlank() -> username
            !email.isNullOrBlank() -> email
            else -> "User"
        }
}
