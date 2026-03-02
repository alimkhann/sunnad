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
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.storage.storage
import io.ktor.http.ContentType
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
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
    suspend fun updatePassword(newPassword: String): SessionUser
    suspend fun updateProfile(username: String?, avatarUrl: String?): SessionUser
    suspend fun uploadAvatar(data: ByteArray, mimeType: String): SessionUser
    suspend fun removeAvatar(): SessionUser
    suspend fun signInWithGoogle()
    suspend fun signInWithApple()
    suspend fun handleAuthCallback(uri: Uri): SessionUser?
    suspend fun deleteAccount()
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

    override suspend fun updatePassword(newPassword: String): SessionUser {
        throw AuthServiceError.Unavailable
    }

    override suspend fun updateProfile(username: String?, avatarUrl: String?): SessionUser {
        throw AuthServiceError.Unavailable
    }

    override suspend fun uploadAvatar(data: ByteArray, mimeType: String): SessionUser {
        throw AuthServiceError.Unavailable
    }

    override suspend fun removeAvatar(): SessionUser {
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

    override suspend fun deleteAccount() {
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
            client.auth.currentUserOrNull()?.let { toSessionUser(it) }
        }.getOrNull()
    }

    override suspend fun signIn(identifier: String, password: String): SessionUser {
        val normalized = resolveSignInEmail(identifier)
        return runCatching {
            client.auth.signInWith(Email) {
                email = normalized
                this.password = password
            }
            val user = runCatching {
                client.auth.retrieveUserForCurrentSession(updateSession = true)
            }.getOrNull() ?: client.auth.currentUserOrNull()
            if (user == null) throw AuthServiceError.InvalidCredentials
            toSessionUser(user)
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

            val sessionUser = client.auth.currentUserOrNull()?.let { toSessionUser(it) }
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
            toSessionUser(client.auth.retrieveUserForCurrentSession(updateSession = true))
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

    override suspend fun updatePassword(newPassword: String): SessionUser {
        return runCatching {
            client.auth.updateUser {
                password = newPassword
            }
            toSessionUser(client.auth.retrieveUserForCurrentSession(updateSession = true))
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun updateProfile(username: String?, avatarUrl: String?): SessionUser {
        val user = client.auth.currentUserOrNull() ?: throw AuthServiceError.InvalidCredentials
        val trimmedUsername = username?.trim().orEmpty().lowercase()
        if (trimmedUsername.isNotEmpty() && !trimmedUsername.matches(Regex("^[a-z0-9_]{3,20}$"))) {
            throw AuthServiceError.InvalidUsername
        }

        runCatching {
            val payload = buildJsonObject {
                if (trimmedUsername.isBlank()) {
                    put("username", JsonNull)
                } else {
                    put("username", trimmedUsername)
                }
                if (avatarUrl != null) {
                    if (avatarUrl.isBlank()) {
                        put("avatar_path", JsonNull)
                    } else {
                        put("avatar_path", avatarUrl.trim())
                    }
                }
            }
            client.from("profiles").update(payload) {
                filter { eq("id", user.id) }
            }
            client.auth.updateUser {
                if (trimmedUsername.isBlank()) {
                    data = buildJsonObject { put("username", JsonNull) }
                } else {
                    data = buildJsonObject { put("username", trimmedUsername) }
                }
            }
        }.getOrElse { throw mapAuthError(it) }

        return toSessionUser(client.auth.retrieveUserForCurrentSession(updateSession = true))
    }

    override suspend fun uploadAvatar(data: ByteArray, mimeType: String): SessionUser {
        val user = client.auth.currentUserOrNull() ?: throw AuthServiceError.InvalidCredentials
        if (data.isEmpty()) {
            throw AuthServiceError.Unknown("Invalid avatar image.")
        }

        val extension = when (mimeType.lowercase()) {
            "image/png" -> "png"
            "image/webp" -> "webp"
            else -> "jpg"
        }
        val avatarPath = "profiles/${user.id.lowercase()}/avatar.$extension"

        runCatching {
            client.storage.from("avatars").upload(avatarPath, data) {
                upsert = true
                contentType = ContentType.parse(mimeType)
            }
            persistProfileAvatarPath(user.id, avatarPath)
        }.getOrElse { throw mapAuthError(it) }

        return toSessionUser(client.auth.retrieveUserForCurrentSession(updateSession = true))
    }

    override suspend fun removeAvatar(): SessionUser {
        val user = client.auth.currentUserOrNull() ?: throw AuthServiceError.InvalidCredentials
        val profile = fetchProfile(user.id)
        val avatarPath = profile?.avatarPath?.trim().orEmpty()

        runCatching {
            if (avatarPath.isNotEmpty() && !avatarPath.startsWith("http://") && !avatarPath.startsWith("https://")) {
                client.storage.from("avatars").delete(avatarPath)
            }
            persistProfileAvatarPath(user.id, null)
        }.getOrElse { throw mapAuthError(it) }

        return toSessionUser(client.auth.retrieveUserForCurrentSession(updateSession = true))
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
            val user = runCatching {
                client.auth.retrieveUserForCurrentSession(updateSession = true)
            }.getOrNull() ?: client.auth.currentUserOrNull()
            user?.let { toSessionUser(it) }
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun deleteAccount() {
        runCatching {
            client.functions.invoke("delete-account")
            client.auth.signOut()
        }.getOrElse { throw mapAuthError(it) }
    }

    override suspend fun signOut() {
        runCatching {
            client.auth.signOut()
        }.getOrElse { throw mapAuthError(it) }
    }

    private suspend fun toSessionUser(user: UserInfo): SessionUser {
        val profile = fetchProfile(user.id)
        val id = runCatching { UUID.fromString(user.id) }.getOrElse { UUID.randomUUID() }
        val metadataUsername = user.userMetadata?.get("username")?.jsonPrimitive?.contentOrNull
        val provider = when (user.appMetadata?.get("provider")?.jsonPrimitive?.contentOrNull?.lowercase()) {
            "google" -> AuthProvider.GOOGLE
            "apple" -> AuthProvider.APPLE
            "email" -> AuthProvider.EMAIL
            else -> AuthProvider.UNKNOWN
        }
        return SessionUser(
            id = id,
            email = user.email,
            username = profile?.username ?: metadataUsername,
            avatarUrl = avatarUrlFromPath(profile?.avatarPath),
            provider = provider
        )
    }

    private suspend fun fetchProfile(userId: String): ProfileProjection? {
        return runCatching {
            client.from("profiles")
                .select {
                    filter { eq("id", userId) }
                }
                .decodeList<ProfileProjection>()
                .firstOrNull()
        }.getOrNull()
    }

    private suspend fun persistProfileAvatarPath(userId: String, avatarPath: String?) {
        val payload = buildJsonObject {
            put("avatar_path", avatarPath?.let { kotlinx.serialization.json.JsonPrimitive(it) } ?: JsonNull)
        }
        client.from("profiles").update(payload) {
            filter { eq("id", userId) }
        }
    }

    private fun avatarUrlFromPath(path: String?): String? {
        val trimmed = path?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
        return runCatching {
            client.storage.from("avatars").publicUrl(trimmed)
        }.getOrDefault(trimmed)
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
            parseRpcString(result.data).ifBlank { trimmed }
        }.getOrDefault(trimmed)
    }

    private fun parseRpcString(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed.isBlank() || trimmed == "null") return ""

        val element = runCatching { Json.parseToJsonElement(trimmed) }.getOrNull()
        if (element != null) {
            parseJsonValue(element)?.let { return it }
        }

        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length >= 2) {
            return trimmed.substring(1, trimmed.lastIndex)
        }
        return trimmed
    }

    private fun parseJsonValue(element: JsonElement): String? {
        return when (element) {
            is JsonObject -> element["email"]?.let(::parseJsonValue)
                ?: element["value"]?.let(::parseJsonValue)
                ?: element.values.firstNotNullOfOrNull(::parseJsonValue)
            is JsonArray -> element.firstNotNullOfOrNull(::parseJsonValue)
            else -> element.jsonPrimitive.contentOrNull
        }
    }
}

@Serializable
private data class ProfileProjection(
    val username: String? = null,
    @SerialName("avatar_path") val avatarPath: String? = null
)
