package com.arystan.almasuly.sunnadandroid.features.auth

import android.net.Uri
import com.arystan.almasuly.sunnadandroid.core.model.AuthProvider
import com.arystan.almasuly.sunnadandroid.core.model.SessionUser
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.OtpType
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.exception.AuthErrorCode
import io.github.jan.supabase.auth.exception.AuthRestException
import io.github.jan.supabase.auth.exception.AuthWeakPasswordException
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.util.UUID

enum class OtpFlowMode {
    SIGN_UP,
    RECOVERY
}

sealed class AuthServiceError(message: String) : Exception(message) {
    data object Unavailable : AuthServiceError("Authentication is not configured.")
    data object InvalidCredentials : AuthServiceError("Invalid email/username or password.")
    data object InvalidOtp : AuthServiceError("Verification code is invalid or expired.")
    data object InvalidRecoveryLink : AuthServiceError("Recovery link is invalid or expired.")
    data object InvalidUsername : AuthServiceError("Username must be 3-20 characters, lowercase letters, numbers, or underscore.")
    data object EmailAlreadyInUse : AuthServiceError("An account with this email already exists.")
    data object UsernameAlreadyInUse : AuthServiceError("This username is already taken.")
    data object WeakPassword : AuthServiceError("Password is too weak.")
    data object EmailNotConfirmed : AuthServiceError("Please verify your email before signing in.")
    data object RateLimited : AuthServiceError("Too many attempts. Please wait and try again.")
    class ProviderUnavailable(provider: String) : AuthServiceError("$provider sign in is not available yet.")
    class Unknown(message: String) : AuthServiceError(message)
}

interface AuthService {
    val isConfigured: Boolean
    val isGoogleEnabled: Boolean
    val isAppleEnabled: Boolean
    val resendCooldownSeconds: Int

    suspend fun currentUser(): SessionUser?
    suspend fun signIn(identifier: String, password: String): SessionUser
    suspend fun signUp(email: String, username: String, password: String): SessionUser
    suspend fun requestPasswordReset(email: String)
    suspend fun verifyOtp(email: String, otp: String, flowMode: OtpFlowMode): SessionUser
    suspend fun resendOtp(email: String, flowMode: OtpFlowMode)
    suspend fun signInWithGoogle()
    suspend fun signInWithApple()
    suspend fun handleAuthCallback(uri: Uri): SessionUser?
    suspend fun signOut()
}

class UnconfiguredAuthService(
    override val resendCooldownSeconds: Int = 120
) : AuthService {
    override val isConfigured: Boolean = false
    override val isGoogleEnabled: Boolean = false
    override val isAppleEnabled: Boolean = false

    override suspend fun currentUser(): SessionUser? = null

    override suspend fun signIn(identifier: String, password: String): SessionUser {
        throw AuthServiceError.Unavailable
    }

    override suspend fun signUp(email: String, username: String, password: String): SessionUser {
        throw AuthServiceError.Unavailable
    }

    override suspend fun requestPasswordReset(email: String) {
        throw AuthServiceError.Unavailable
    }

    override suspend fun verifyOtp(email: String, otp: String, flowMode: OtpFlowMode): SessionUser {
        throw AuthServiceError.Unavailable
    }

    override suspend fun resendOtp(email: String, flowMode: OtpFlowMode) {
        throw AuthServiceError.Unavailable
    }

    override suspend fun signInWithGoogle() {
        throw AuthServiceError.Unavailable
    }

    override suspend fun signInWithApple() {
        throw AuthServiceError.ProviderUnavailable("Apple")
    }

    override suspend fun handleAuthCallback(uri: Uri): SessionUser? {
        throw AuthServiceError.Unavailable
    }

    override suspend fun signOut() = Unit
}

class SupabaseAuthService(
    private val client: SupabaseClient,
    private val redirectUrl: String,
    override val isGoogleEnabled: Boolean,
    override val isAppleEnabled: Boolean,
    override val resendCooldownSeconds: Int
) : AuthService {
    override val isConfigured: Boolean = true

    override suspend fun currentUser(): SessionUser? {
        return runCatching {
            client.auth.loadFromStorage(autoRefresh = true)
            client.auth.awaitInitialization()
            client.auth.currentUserOrNull()?.toSessionUser()
        }.getOrNull()
    }

    override suspend fun signIn(identifier: String, password: String): SessionUser {
        val normalized = resolveSignInEmail(identifier)
        return runCatching {
            client.auth.signInWith(Email) {
                email = normalized
                this.password = password
            }
            client.auth.retrieveUserForCurrentSession(updateSession = true).toSessionUser()
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun signUp(email: String, username: String, password: String): SessionUser {
        val normalizedEmail = email.trim()
        val normalizedUsername = username.trim().lowercase()
        if (!normalizedUsername.matches(Regex("^[a-z0-9_]{3,20}$"))) {
            throw AuthServiceError.InvalidUsername
        }

        return runCatching {
            client.auth.signUpWith(Email, redirectUrl) {
                this.email = normalizedEmail
                this.password = password
                data = buildJsonObject { put("username", normalizedUsername) }
            }

            val sessionUser = client.auth.currentUserOrNull()?.toSessionUser()
            sessionUser ?: throw AuthServiceError.EmailNotConfirmed
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun requestPasswordReset(email: String) {
        runCatching {
            client.auth.resetPasswordForEmail(email.trim(), redirectUrl)
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun verifyOtp(email: String, otp: String, flowMode: OtpFlowMode): SessionUser {
        val otpType = when (flowMode) {
            OtpFlowMode.SIGN_UP -> OtpType.Email.SIGNUP
            OtpFlowMode.RECOVERY -> OtpType.Email.RECOVERY
        }

        return runCatching {
            client.auth.verifyEmailOtp(otpType, email.trim(), otp.trim())
            client.auth.retrieveUserForCurrentSession(updateSession = true).toSessionUser()
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun resendOtp(email: String, flowMode: OtpFlowMode) {
        runCatching {
            when (flowMode) {
                OtpFlowMode.SIGN_UP -> client.auth.resendEmail(OtpType.Email.SIGNUP, email.trim(), redirectUrl)
                OtpFlowMode.RECOVERY -> client.auth.resetPasswordForEmail(email.trim(), redirectUrl)
            }
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun signInWithGoogle() {
        if (!isGoogleEnabled) throw AuthServiceError.ProviderUnavailable("Google")

        runCatching {
            client.auth.signInWith(Google, redirectUrl) {
                scopes.addAll(listOf("email", "profile"))
            }
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun signInWithApple() {
        throw AuthServiceError.ProviderUnavailable("Apple")
    }

    override suspend fun handleAuthCallback(uri: Uri): SessionUser? {
        return runCatching {
            client.auth.exchangeCodeForSession(uri.toString())
            client.auth.retrieveUserForCurrentSession(updateSession = true).toSessionUser()
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun signOut() {
        runCatching {
            client.auth.signOut()
        }.getOrElse { throw mapAuthError(it) }
    }

    private fun UserInfo.toSessionUser(): SessionUser {
        val id = runCatching { UUID.fromString(this.id) }.getOrElse { UUID.randomUUID() }
        val metadataUsername = userMetadata?.get("username")?.jsonPrimitive?.contentOrNull
        val provider = when (appMetadata?.get("provider")?.jsonPrimitive?.contentOrNull?.lowercase()) {
            "google" -> AuthProvider.GOOGLE
            "apple" -> AuthProvider.APPLE
            "email" -> AuthProvider.EMAIL
            else -> AuthProvider.UNKNOWN
        }
        return SessionUser(
            id = id,
            email = email,
            username = metadataUsername,
            provider = provider
        )
    }

    private fun mapAuthError(error: Throwable): AuthServiceError {
        if (error is AuthServiceError) return error
        if (error is AuthWeakPasswordException) return AuthServiceError.WeakPassword
        if (error is AuthRestException) {
            return when (error.errorCode) {
                AuthErrorCode.InvalidCredentials -> AuthServiceError.InvalidCredentials
                AuthErrorCode.EmailExists,
                AuthErrorCode.UserAlreadyExists -> AuthServiceError.EmailAlreadyInUse

                AuthErrorCode.EmailNotConfirmed -> AuthServiceError.EmailNotConfirmed
                AuthErrorCode.OtpExpired,
                AuthErrorCode.BadJson,
                AuthErrorCode.ValidationFailed -> AuthServiceError.InvalidOtp

                AuthErrorCode.WeakPassword -> AuthServiceError.WeakPassword
                AuthErrorCode.OverRequestRateLimit,
                AuthErrorCode.OverEmailSendRateLimit -> AuthServiceError.RateLimited

                else -> AuthServiceError.Unknown(error.errorDescription)
            }
        }

        return AuthServiceError.Unknown(error.message ?: "Unknown auth error")
    }

    private suspend fun resolveSignInEmail(identifier: String): String {
        val trimmed = identifier.trim()
        if (trimmed.isEmpty() || trimmed.contains("@")) return trimmed

        return runCatching {
            val result = client.postgrest.rpc(
                function = "resolve_sign_in_email",
                parameters = buildJsonObject { put("identifier", trimmed) }
            )
            result.decodeSingle<String>().ifBlank { trimmed }
        }.getOrDefault(trimmed)
    }
}
