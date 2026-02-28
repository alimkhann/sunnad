package com.arystan.almasuly.sunnadandroid.features.auth

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
    FORGOT_PASSWORD
}

data class AuthUiState(
    val user: SessionUser? = null,
    val step: AuthStep = AuthStep.SIGN_IN,
    val isConfigured: Boolean = false,
    val pendingEmail: String = "",
    val otpFlowMode: OtpFlowMode = OtpFlowMode.SIGN_UP,
    val otpResendSecondsRemaining: Int = 0,
    val isGoogleEnabled: Boolean = false,
    val isAppleEnabled: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val successMessage: String? = null
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
            _state.update { it.copy(isLoading = true, errorMessage = null) }
            val user = authService.currentUser()
            _state.update { it.copy(isLoading = false, user = user) }
        }
    }

    fun openStep(step: AuthStep) {
        _state.update { it.copy(step = step, errorMessage = null, successMessage = null) }
    }

    fun clearMessages() {
        _state.update { it.copy(errorMessage = null, successMessage = null) }
    }

    fun signIn(identifier: String, password: String) {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
                authService.signIn(identifier = identifier, password = password)
            }.onSuccess { user ->
                _state.update { it.copy(user = user, isLoading = false) }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Sign-in failed"
                    )
                }
            }
        }
    }

    fun signUp(email: String, username: String, password: String) {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
                authService.signUp(email = email, username = username, password = password)
            }.onSuccess { user ->
                _state.update { it.copy(user = user, isLoading = false) }
            }.onFailure { error ->
                if (error is AuthServiceError.EmailNotConfirmed) {
                    _state.update {
                        it.copy(
                            isLoading = false,
                            step = AuthStep.OTP,
                            pendingEmail = email.trim(),
                            otpFlowMode = OtpFlowMode.SIGN_UP,
                            successMessage = "Verification code sent",
                            errorMessage = null
                        )
                    }
                    startOtpCooldown()
                } else {
                    _state.update {
                        it.copy(
                            isLoading = false,
                            errorMessage = error.message ?: "Sign-up failed"
                        )
                    }
                }
            }
        }
    }

    fun requestPasswordReset(email: String) {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
                authService.requestPasswordReset(email.trim())
            }.onSuccess {
                _state.update {
                    it.copy(
                        isLoading = false,
                        step = AuthStep.OTP,
                        pendingEmail = email.trim(),
                        otpFlowMode = OtpFlowMode.RECOVERY,
                        successMessage = "Recovery code sent"
                    )
                }
                startOtpCooldown()
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Failed to send recovery code"
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
                _state.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
                authService.verifyOtp(
                    email = email,
                    otp = code,
                    flowMode = _state.value.otpFlowMode
                )
            }.onSuccess { user ->
                _state.update { it.copy(user = user, isLoading = false) }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "OTP verification failed"
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
                _state.update { it.copy(successMessage = "Verification code sent") }
                startOtpCooldown()
            }.onFailure { error ->
                _state.update { it.copy(errorMessage = error.message ?: "Failed to resend code") }
            }
        }
    }

    fun signInWithGoogle() {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
                authService.signInWithGoogle()
            }.onSuccess {
                _state.update {
                    it.copy(
                        isLoading = false,
                        successMessage = "Continue in browser to complete Google sign-in"
                    )
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Google auth failed"
                    )
                }
            }
        }
    }

    fun signInWithApplePrewired() {
        viewModelScope.launch {
            runCatching {
                _state.update { it.copy(isLoading = true, errorMessage = null, successMessage = null) }
                authService.signInWithApple()
            }.onSuccess {
                _state.update { it.copy(isLoading = false) }
            }.onFailure { error ->
                _state.update {
                    it.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Apple sign-in is not available"
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
                    _state.update { it.copy(user = user, errorMessage = null, successMessage = null) }
                }
            }.onFailure { error ->
                _state.update {
                    it.copy(errorMessage = error.message ?: "Auth callback failed")
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
                    isConfigured = authService.isConfigured,
                    isGoogleEnabled = authService.isGoogleEnabled,
                    isAppleEnabled = authService.isAppleEnabled
                )
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
}
