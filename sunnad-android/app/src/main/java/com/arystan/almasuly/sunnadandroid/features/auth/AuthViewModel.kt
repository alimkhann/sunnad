package com.arystan.almasuly.sunnadandroid.features.auth

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.SessionUser
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class AuthStep {
    SIGN_IN,
    SIGN_UP,
    OTP,
    FORGOT_PASSWORD,
    CHANGE_PASSWORD
}

data class AuthUiState(
    val user: SessionUser? = null,
    val step: AuthStep = AuthStep.SIGN_IN,
    val hasRestoredSession: Boolean = false,
    val isConfigured: Boolean = false,
    val pendingEmail: String = "",
    val otpFlowMode: OtpFlowMode = OtpFlowMode.SIGN_UP,
    val otpResendSecondsRemaining: Int = 0,
    val isGoogleEnabled: Boolean = false,
    val isAppleEnabled: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessageResId: Int? = null,
    val successMessageResId: Int? = null
)

class AuthViewModel(
    private val authService: AuthService
) : ViewModel() {
    private val _state = MutableStateFlow(
        AuthUiState(
            isConfigured = authService.isConfigured,
            isGoogleEnabled = authService.isGoogleEnabled,
            isAppleEnabled = authService.isAppleEnabled
        )
    )
    val state: StateFlow<AuthUiState> = _state.asStateFlow()

    private var otpCooldownJob: Job? = null

    fun restoreSession() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, errorMessageResId = null) }
            val user = authService.currentUser()
            _state.update {
                it.copy(
                    isLoading = false,
                    user = user ?: it.user,
                    hasRestoredSession = true
                )
            }
        }
    }

    fun openStep(step: AuthStep) {
        _state.update { it.copy(step = step, errorMessageResId = null, successMessageResId = null) }
    }

    fun clearMessages() {
        _state.update { it.copy(errorMessageResId = null, successMessageResId = null) }
    }

    fun signIn(identifier: String, password: String) {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.signIn(identifier = identifier, password = password)
            }.onSuccess { user ->
                _state.update { it.copy(user = user, isLoading = false, hasRestoredSession = true) }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_sign_in_failed)
                    )
                }
            }
        }
    }

    fun signUp(email: String, username: String, password: String) {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.signUp(email = email, username = username, password = password)
            }.onSuccess { user ->
                _state.update { it.copy(user = user, isLoading = false, hasRestoredSession = true) }
            }.onFailure { error ->
                if (error is AuthServiceError.EmailNotConfirmed) {
                    _state.update {
                        it.copy(
                            isLoading = false,
                            step = AuthStep.OTP,
                            pendingEmail = email.trim(),
                            otpFlowMode = OtpFlowMode.SIGN_UP,
                            successMessageResId = R.string.auth_success_verification_sent,
                            errorMessageResId = null
                        )
                    }
                    startOtpCooldown()
                } else {
                    _state.update {
                        it.copy(
                            isLoading = false,
                            errorMessageResId = errorMessageResId(error, R.string.auth_error_sign_up_failed)
                        )
                    }
                }
            }
        }
    }

    fun requestPasswordReset(email: String) {
        val trimmed = email.trim()
        if (trimmed.isBlank()) {
            _state.update { it.copy(errorMessageResId = R.string.auth_error_enter_email) }
            return
        }
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.requestPasswordReset(trimmed)
            }.onSuccess {
                _state.update {
                    it.copy(
                        isLoading = false,
                        step = AuthStep.OTP,
                        pendingEmail = trimmed,
                        otpFlowMode = OtpFlowMode.RECOVERY,
                        successMessageResId = R.string.auth_success_recovery_code_sent
                    )
                }
                startOtpCooldown()
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_send_recovery_failed)
                    )
                }
            }
        }
    }

    fun verifyOtp(code: String) {
        val email = _state.value.pendingEmail
        if (email.isBlank()) return

        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.verifyOtp(
                    email = email,
                    otp = code,
                    flowMode = _state.value.otpFlowMode
                )
            }.onSuccess { user ->
                if (_state.value.otpFlowMode == OtpFlowMode.RECOVERY) {
                    _state.update {
                        it.copy(
                            user = user,
                            isLoading = false,
                            hasRestoredSession = true,
                            step = AuthStep.CHANGE_PASSWORD,
                            successMessageResId = R.string.auth_success_code_verified
                        )
                    }
                } else {
                    _state.update { it.copy(user = user, isLoading = false, hasRestoredSession = true) }
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_otp_failed)
                    )
                }
            }
        }
    }

    fun resendOtp() {
        val snapshot = _state.value
        if (snapshot.pendingEmail.isBlank() || snapshot.otpResendSecondsRemaining > 0) return

        viewModelScope.launch {
            runCatching {
                authService.resendOtp(snapshot.pendingEmail, snapshot.otpFlowMode)
            }.onSuccess {
                _state.update { it.copy(successMessageResId = R.string.auth_success_verification_sent) }
                startOtpCooldown()
            }.onFailure { error ->
                _state.update { it.copy(errorMessageResId = errorMessageResId(error, R.string.auth_error_resend_failed)) }
            }
        }
    }

    fun updatePassword(newPassword: String) {
        if (newPassword.length < 8) {
            _state.update { it.copy(errorMessageResId = R.string.auth_error_password_short) }
            return
        }
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.updatePassword(newPassword)
            }.onSuccess { user ->
                _state.update {
                    it.copy(
                        user = user,
                        isLoading = false,
                        hasRestoredSession = true,
                        step = AuthStep.SIGN_IN,
                        successMessageResId = R.string.auth_success_password_changed
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_update_password_failed)
                    )
                }
            }
        }
    }

    fun updateProfile(username: String, avatarUrl: String?) {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.updateProfile(username = username, avatarUrl = avatarUrl)
            }.onSuccess { user ->
                _state.update { it.copy(user = user, isLoading = false, hasRestoredSession = true) }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_sign_up_failed)
                    )
                }
            }
        }
    }

    fun signInWithGoogle() {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.signInWithGoogle()
            }.onSuccess {
                _state.update {
                    it.copy(
                        isLoading = false,
                        successMessageResId = R.string.auth_success_continue_browser
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_google_failed)
                    )
                }
            }
        }
    }

    fun signInWithApplePrewired() {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.signInWithApple()
            }.onSuccess {
                _state.update { it.copy(isLoading = false) }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_apple_unavailable)
                    )
                }
            }
        }
    }

    fun handleAuthCallback(uri: Uri) {
        viewModelScope.launch {
            runCatching {
                authService.handleAuthCallback(uri)
            }.onSuccess { user ->
                if (user != null) {
                    _state.update {
                        it.copy(
                            user = user,
                            hasRestoredSession = true,
                            errorMessageResId = null,
                            successMessageResId = null
                        )
                    }
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(errorMessageResId = errorMessageResId(error, R.string.auth_error_callback_failed))
                }
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            runCatching { authService.signOut() }
            otpCooldownJob?.cancel()
            _state.update {
                AuthUiState(
                    step = AuthStep.SIGN_IN,
                    hasRestoredSession = true,
                    isConfigured = authService.isConfigured,
                    isGoogleEnabled = authService.isGoogleEnabled,
                    isAppleEnabled = authService.isAppleEnabled
                )
            }
        }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessageResId = null, successMessageResId = null) }
                authService.deleteAccount()
            }.onSuccess {
                otpCooldownJob?.cancel()
                _state.update {
                    AuthUiState(
                        step = AuthStep.SIGN_IN,
                        hasRestoredSession = true,
                        isConfigured = authService.isConfigured,
                        isGoogleEnabled = authService.isGoogleEnabled,
                        isAppleEnabled = authService.isAppleEnabled
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessageResId = errorMessageResId(error, R.string.auth_error_sign_in_failed)
                    )
                }
            }
        }
    }

    private fun startOtpCooldown(seconds: Int = authService.resendCooldownSeconds) {
        otpCooldownJob?.cancel()
        otpCooldownJob = viewModelScope.launch {
            for (remaining in seconds downTo 1) {
                _state.update { it.copy(otpResendSecondsRemaining = remaining) }
                delay(1_000)
            }
            _state.update { it.copy(otpResendSecondsRemaining = 0) }
        }
    }

    private fun errorMessageResId(error: Throwable, fallbackResId: Int): Int {
        return when (error) {
            is AuthServiceError.Unavailable -> R.string.auth_error_unavailable
            is AuthServiceError.InvalidCredentials -> R.string.auth_error_invalid_credentials
            is AuthServiceError.InvalidOtp -> R.string.auth_error_invalid_otp
            is AuthServiceError.InvalidRecoveryLink -> R.string.auth_error_invalid_recovery_link
            is AuthServiceError.InvalidUsername -> R.string.auth_error_invalid_username
            is AuthServiceError.EmailAlreadyInUse -> R.string.auth_error_email_in_use
            is AuthServiceError.UsernameAlreadyInUse -> R.string.auth_error_username_in_use
            is AuthServiceError.WeakPassword -> R.string.auth_error_weak_password
            is AuthServiceError.EmailNotConfirmed -> R.string.auth_error_email_not_confirmed
            is AuthServiceError.RateLimited -> R.string.auth_error_rate_limited
            is AuthServiceError.ProviderUnavailable -> R.string.auth_error_provider_unavailable
            is AuthServiceError.Unknown -> fallbackResId
            else -> fallbackResId
        }
    }
}
