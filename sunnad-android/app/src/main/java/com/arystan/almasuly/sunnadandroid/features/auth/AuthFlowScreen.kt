package com.arystan.almasuly.sunnadandroid.features.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactBackButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactCloseButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface

@Composable
fun AuthFlowScreen(
    state: AuthUiState,
    onBack: (() -> Unit)?,
    onClose: (() -> Unit)?,
    onOpenStep: (AuthStep) -> Unit,
    onSignIn: (String, String) -> Unit,
    onSignUp: (String, String, String) -> Unit,
    onRequestPasswordReset: (String) -> Unit,
    onVerifyOtp: (String) -> Unit,
    onResendOtp: () -> Unit,
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit,
    onContinueAsGuest: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    var email by remember(state.step) { mutableStateOf(state.pendingEmail) }
    var username by remember(state.step) { mutableStateOf("") }
    var password by remember(state.step) { mutableStateOf("") }
    var confirmPassword by remember(state.step) { mutableStateOf("") }
    var otp by remember(state.step) { mutableStateOf("") }
    var passwordVisible by rememberSaveable(state.step) { mutableStateOf(false) }
    var confirmVisible by rememberSaveable(state.step) { mutableStateOf(false) }

    val isUnavailableError = state.errorMessage?.contains("not configured", ignoreCase = true) == true

    SunnadScreenSurface(modifier = modifier) {
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(horizontal = SunnadScreenPadding, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            AuthHeader(
                state = state,
                onBack = onBack,
                onClose = onClose
            )

            state.errorMessage?.takeIf { it.isNotBlank() }?.let {
                StatusMessage(
                    text = it,
                    isError = true
                )
            }

            state.successMessage?.takeIf { it.isNotBlank() }?.let {
                StatusMessage(
                    text = it,
                    isError = false
                )
            }

            when (state.step) {
                AuthStep.SIGN_IN -> {
                    SunnadCard(contentPadding = 12.dp) {
                        OutlinedTextField(
                            value = email,
                            onValueChange = { email = it },
                            label = { Text(stringResource(R.string.auth_email_or_username)) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                        PasswordField(
                            value = password,
                            onValueChange = { password = it },
                            label = stringResource(R.string.auth_password),
                            visible = passwordVisible,
                            onVisibilityChange = { passwordVisible = !passwordVisible }
                        )
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextAction(
                            text = stringResource(R.string.auth_forgot_password),
                            onClick = { onRequestPasswordReset(email.trim()) }
                        )
                    }

                    PrimaryPillButton(
                        title = stringResource(R.string.auth_sign_in),
                        enabled = email.isNotBlank() && password.isNotBlank() && !state.isLoading && state.isConfigured,
                        onClick = { onSignIn(email.trim(), password) }
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = stringResource(R.string.auth_no_account),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        TextAction(
                            text = stringResource(R.string.auth_open_sign_up),
                            onClick = { onOpenStep(AuthStep.SIGN_UP) }
                        )
                    }
                }

                AuthStep.SIGN_UP -> {
                    SunnadCard(contentPadding = 12.dp) {
                        OutlinedTextField(
                            value = email,
                            onValueChange = { email = it },
                            label = { Text(stringResource(R.string.auth_email)) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
                        )
                        OutlinedTextField(
                            value = username,
                            onValueChange = { username = it.lowercase() },
                            label = { Text(stringResource(R.string.auth_username)) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                        Text(
                            text = stringResource(R.string.auth_username_hint),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        PasswordField(
                            value = password,
                            onValueChange = { password = it },
                            label = stringResource(R.string.auth_password),
                            visible = passwordVisible,
                            onVisibilityChange = { passwordVisible = !passwordVisible }
                        )
                        PasswordStrengthMeter(password = password)
                        PasswordField(
                            value = confirmPassword,
                            onValueChange = { confirmPassword = it },
                            label = stringResource(R.string.auth_repeat_password),
                            visible = confirmVisible,
                            onVisibilityChange = { confirmVisible = !confirmVisible }
                        )
                    }

                    PrimaryPillButton(
                        title = stringResource(R.string.auth_sign_up),
                        enabled = email.isNotBlank() &&
                            username.isNotBlank() &&
                            password.length >= 8 &&
                            password == confirmPassword &&
                            !state.isLoading &&
                            state.isConfigured,
                        onClick = { onSignUp(email.trim(), username.trim().lowercase(), password) }
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = stringResource(R.string.auth_have_account),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        TextAction(
                            text = stringResource(R.string.auth_open_sign_in),
                            onClick = { onOpenStep(AuthStep.SIGN_IN) }
                        )
                    }
                }

                AuthStep.OTP -> {
                    SunnadCard {
                        Text(
                            text = stringResource(R.string.auth_otp_subtitle, state.pendingEmail),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        OutlinedTextField(
                            value = otp,
                            onValueChange = { otp = it.filter(Char::isDigit).take(6) },
                            label = { Text(stringResource(R.string.auth_otp_code)) },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true
                        )
                        PrimaryPillButton(
                            title = stringResource(R.string.auth_verify_code),
                            enabled = otp.length >= 4 && !state.isLoading && state.isConfigured,
                            onClick = { onVerifyOtp(otp) }
                        )
                        SecondaryPillButton(
                            title = if (state.otpResendSecondsRemaining <= 0) {
                                stringResource(R.string.auth_resend_code)
                            } else {
                                stringResource(R.string.auth_resend_in_seconds, state.otpResendSecondsRemaining)
                            },
                            enabled = state.otpResendSecondsRemaining <= 0 && !state.isLoading && state.isConfigured,
                            onClick = onResendOtp
                        )
                    }
                }

                AuthStep.FORGOT_PASSWORD -> {
                    SunnadCard {
                        OutlinedTextField(
                            value = email,
                            onValueChange = { email = it },
                            label = { Text(stringResource(R.string.auth_email)) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
                        )
                        PrimaryPillButton(
                            title = stringResource(R.string.auth_send_recovery_code),
                            enabled = email.isNotBlank() && !state.isLoading && state.isConfigured,
                            onClick = { onRequestPasswordReset(email.trim()) }
                        )
                    }
                    SecondaryPillButton(
                        title = stringResource(R.string.auth_back_to_sign_in),
                        onClick = { onOpenStep(AuthStep.SIGN_IN) }
                    )
                }
            }

            if (state.step != AuthStep.OTP && state.step != AuthStep.FORGOT_PASSWORD) {
                OrDivider()
                SocialButtons(
                    state = state,
                    onGoogleSignIn = onGoogleSignIn,
                    onAppleSignIn = onAppleSignIn
                )
            }

            if (!state.isConfigured || isUnavailableError) {
                onContinueAsGuest?.let {
                    SecondaryPillButton(
                        title = stringResource(R.string.onboarding_continue_as_guest),
                        onClick = it
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}

@Composable
private fun AuthHeader(
    state: AuthUiState,
    onBack: (() -> Unit)?,
    onClose: (() -> Unit)?
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (onBack != null) {
            SunnadCompactBackButton(onClick = onBack)
        } else {
            Spacer(modifier = Modifier.widthIn(min = 38.dp))
        }
        Text(
            text = when (state.step) {
                AuthStep.SIGN_IN -> stringResource(R.string.auth_sign_in)
                AuthStep.SIGN_UP -> stringResource(R.string.auth_sign_up)
                AuthStep.OTP -> stringResource(R.string.auth_otp_title)
                AuthStep.FORGOT_PASSWORD -> stringResource(R.string.auth_forgot_password)
            },
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 6.dp)
        )
        if (onClose != null) {
            SunnadCompactCloseButton(onClick = onClose)
        } else {
            Spacer(modifier = Modifier.widthIn(min = 38.dp))
        }
    }
}

@Composable
private fun PasswordField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    visible: Boolean,
    onVisibilityChange: () -> Unit
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        trailingIcon = {
            IconButton(onClick = onVisibilityChange) {
                Icon(
                    imageVector = if (visible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    )
}

@Composable
private fun StatusMessage(text: String, isError: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp)
            )
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(
            imageVector = if (isError) Icons.Rounded.Error else Icons.Rounded.CheckCircle,
            contentDescription = null,
            tint = if (isError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun SocialButtons(
    state: AuthUiState,
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit
) {
    val appleEnabled = state.isAppleEnabled && !state.isLoading && state.isConfigured
    val googleEnabled = state.isGoogleEnabled && !state.isLoading && state.isConfigured
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SocialProviderButton(
            title = stringResource(R.string.auth_apple_continue),
            background = Color.Black,
            textColor = Color.White,
            borderColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
            iconResId = R.drawable.apple_logo,
            enabled = appleEnabled,
            onClick = onAppleSignIn
        )
        SocialProviderButton(
            title = stringResource(R.string.auth_google_continue),
            background = Color.White,
            textColor = Color.Black,
            borderColor = Color(0xFFD0D3DA),
            iconResId = R.drawable.google_logo,
            enabled = googleEnabled,
            onClick = onGoogleSignIn
        )
        if (!state.isAppleEnabled) {
            Text(
                text = stringResource(R.string.auth_apple_coming_soon),
                style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 2.dp),
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun OrDivider() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
        )
        Text(
            text = stringResource(R.string.auth_or_short),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .height(1.dp)
                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
        )
    }
}

@Composable
private fun TextAction(text: String, onClick: () -> Unit) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.primary,
        fontWeight = FontWeight.Medium,
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 2.dp)
    )
}

@Composable
private fun SocialProviderButton(
    title: String,
    background: Color,
    textColor: Color,
    borderColor: Color,
    iconResId: Int,
    enabled: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = if (enabled) background else background.copy(alpha = 0.45f),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp)
            )
            .border(
                width = 1.dp,
                color = if (enabled) borderColor else borderColor.copy(alpha = 0.4f),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp)
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Icon(
                painter = painterResource(id = iconResId),
                contentDescription = null,
                tint = Color.Unspecified
            )
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = if (enabled) textColor else textColor.copy(alpha = 0.65f),
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun PasswordStrengthMeter(password: String) {
    val score = remember(password) {
        var value = 0
        if (password.length >= 8) value += 1
        if (password.any(Char::isUpperCase) && password.any(Char::isLowerCase)) value += 1
        if (password.any(Char::isDigit)) value += 1
        if (password.any { !it.isLetterOrDigit() }) value += 1
        value.coerceIn(0, 4)
    }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        repeat(4) { idx ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(
                        color = if (idx < score) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest,
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp)
                    )
                    .padding(vertical = 2.dp)
            )
        }
    }
}
