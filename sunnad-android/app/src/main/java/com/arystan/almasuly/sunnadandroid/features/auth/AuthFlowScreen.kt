package com.arystan.almasuly.sunnadandroid.features.auth

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalUriHandler
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
    onUpdatePassword: (String) -> Unit = {},
    onContinueAsGuest: (() -> Unit)? = null,
    closeOnLeft: Boolean = false,
    modifier: Modifier = Modifier
) {
    var email by remember(state.step, state.pendingEmail) { mutableStateOf(state.pendingEmail) }
    var username by remember(state.step) { mutableStateOf("") }
    var password by remember(state.step) { mutableStateOf("") }
    var confirmPassword by remember(state.step) { mutableStateOf("") }
    var otp by remember(state.step) { mutableStateOf("") }
    var passwordVisible by rememberSaveable(state.step) { mutableStateOf(false) }
    var confirmVisible by rememberSaveable(state.step) { mutableStateOf(false) }

    val isUnavailableError = state.errorMessageResId == R.string.auth_error_unavailable

    BackHandler(enabled = onBack != null || onClose != null) {
        onBack?.invoke() ?: onClose?.invoke()
    }

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
                onClose = onClose,
                closeOnLeft = closeOnLeft
            )

            state.errorMessageResId?.let { messageId ->
                StatusMessage(text = stringResource(messageId), isError = true)
            }

            state.successMessageResId?.let { messageId ->
                StatusMessage(text = stringResource(messageId), isError = false)
            }

            when (state.step) {
                AuthStep.SIGN_IN -> {
                    SunnadCard(contentPadding = 12.dp) {
                        AuthInputRow(
                            value = email,
                            onValueChange = { email = it },
                            placeholder = stringResource(R.string.auth_email_or_username),
                            keyboardType = KeyboardType.Email
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        AuthInputRow(
                            value = password,
                            onValueChange = { password = it },
                            placeholder = stringResource(R.string.auth_password),
                            visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                            trailing = {
                                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                    Icon(
                                        imageVector = if (passwordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        )
                    }

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        TextAction(
                            text = stringResource(R.string.auth_forgot_password),
                            onClick = { onOpenStep(AuthStep.FORGOT_PASSWORD) }
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
                        AuthInputRow(
                            value = email,
                            onValueChange = { email = it },
                            placeholder = stringResource(R.string.auth_email),
                            keyboardType = KeyboardType.Email
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        AuthInputRow(
                            value = username,
                            onValueChange = { username = it.lowercase() },
                            placeholder = stringResource(R.string.auth_username)
                        )
                        Text(
                            text = stringResource(R.string.auth_username_hint),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        AuthInputRow(
                            value = password,
                            onValueChange = { password = it },
                            placeholder = stringResource(R.string.auth_password),
                            visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                            trailing = {
                                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                    Icon(
                                        imageVector = if (passwordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        )
                        PasswordStrengthMeter(
                            password = password,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 8.dp)
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        AuthInputRow(
                            value = confirmPassword,
                            onValueChange = { confirmPassword = it },
                            placeholder = stringResource(R.string.auth_repeat_password),
                            visualTransformation = if (confirmVisible) VisualTransformation.None else PasswordVisualTransformation(),
                            trailing = {
                                IconButton(onClick = { confirmVisible = !confirmVisible }) {
                                    Icon(
                                        imageVector = if (confirmVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
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

                AuthStep.FORGOT_PASSWORD -> {
                    SunnadCard(contentPadding = 12.dp) {
                        AuthInputRow(
                            value = email,
                            onValueChange = { email = it },
                            placeholder = stringResource(R.string.auth_email),
                            keyboardType = KeyboardType.Email
                        )
                    }
                    PrimaryPillButton(
                        title = stringResource(R.string.auth_send_reset_link),
                        enabled = email.isNotBlank() && !state.isLoading && state.isConfigured,
                        onClick = { onRequestPasswordReset(email.trim()) }
                    )
                }

                AuthStep.OTP -> {
                    SunnadCard {
                        Text(
                            text = stringResource(R.string.auth_otp_subtitle, state.pendingEmail),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        OtpCodeField(
                            code = otp,
                            onCodeChange = { otp = it.filter(Char::isDigit).take(6) }
                        )
                        PrimaryPillButton(
                            title = stringResource(R.string.auth_verify_code),
                            enabled = otp.length == 6 && !state.isLoading && state.isConfigured,
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

                AuthStep.CHANGE_PASSWORD -> {
                    SunnadCard(contentPadding = 12.dp) {
                        AuthInputRow(
                            value = password,
                            onValueChange = { password = it },
                            placeholder = stringResource(R.string.auth_new_password),
                            visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                            trailing = {
                                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                    Icon(
                                        imageVector = if (passwordVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        AuthInputRow(
                            value = confirmPassword,
                            onValueChange = { confirmPassword = it },
                            placeholder = stringResource(R.string.auth_repeat_password),
                            visualTransformation = if (confirmVisible) VisualTransformation.None else PasswordVisualTransformation(),
                            trailing = {
                                IconButton(onClick = { confirmVisible = !confirmVisible }) {
                                    Icon(
                                        imageVector = if (confirmVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        )
                    }
                    PasswordStrengthMeter(password = password)
                    PrimaryPillButton(
                        title = stringResource(R.string.auth_change_password),
                        enabled = password.length >= 8 && password == confirmPassword && !state.isLoading && state.isConfigured,
                        onClick = { onUpdatePassword(password) }
                    )
                }
            }

            if (state.step == AuthStep.SIGN_IN || state.step == AuthStep.SIGN_UP) {
                Spacer(modifier = Modifier.height(12.dp))
                OrDivider()
                SocialButtons(
                    state = state,
                    onGoogleSignIn = onGoogleSignIn,
                    onAppleSignIn = onAppleSignIn
                )
                if (state.step == AuthStep.SIGN_UP) {
                    Spacer(modifier = Modifier.height(16.dp))
                    TermsAndPrivacyText()
                }
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
    onClose: (() -> Unit)?,
    closeOnLeft: Boolean
) {
    val preferCloseOnLeft = closeOnLeft && onClose != null && onBack == null

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        when {
            preferCloseOnLeft -> SunnadCompactCloseButton(onClick = requireNotNull(onClose))
            onBack != null -> SunnadCompactBackButton(onClick = onBack)
            else -> Spacer(modifier = Modifier.widthIn(min = 38.dp))
        }

        Text(
            text = when (state.step) {
                AuthStep.SIGN_IN -> stringResource(R.string.auth_sign_in)
                AuthStep.SIGN_UP -> stringResource(R.string.auth_sign_up)
                AuthStep.OTP -> stringResource(R.string.auth_otp_title)
                AuthStep.FORGOT_PASSWORD -> stringResource(R.string.auth_forgot_password)
                AuthStep.CHANGE_PASSWORD -> stringResource(R.string.auth_change_password)
            },
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 6.dp)
        )

        when {
            !preferCloseOnLeft && onClose != null -> SunnadCompactCloseButton(onClick = onClose)
            else -> Spacer(modifier = Modifier.widthIn(min = 38.dp))
        }
    }
}

@Composable
private fun AuthInputRow(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    trailing: @Composable (() -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .weight(1f)
                .padding(vertical = 12.dp),
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
            visualTransformation = visualTransformation,
            singleLine = true,
            decorationBox = { innerField ->
                if (value.isBlank()) {
                    Text(
                        text = placeholder,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                innerField()
            }
        )
        trailing?.invoke()
    }
}

@Composable
private fun OtpCodeField(
    code: String,
    onCodeChange: (String) -> Unit
) {
    BasicTextField(
        value = code,
        onValueChange = onCodeChange,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        modifier = Modifier.fillMaxWidth(),
        decorationBox = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                repeat(6) { index ->
                    val value = code.getOrNull(index)?.toString() ?: ""
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .border(
                                width = 1.dp,
                                color = if (value.isNotEmpty()) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
                                shape = RoundedCornerShape(12.dp)
                            )
                            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(12.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = value,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
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
                shape = RoundedCornerShape(14.dp)
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
    val googleEnabled = state.isGoogleEnabled && !state.isLoading && state.isConfigured
    val appleEnabled = state.isAppleEnabled && !state.isLoading && state.isConfigured

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SocialProviderButton(
            title = stringResource(R.string.auth_google_continue),
            background = Color.White,
            textColor = Color.Black,
            borderColor = Color(0xFFD0D3DA),
            iconResId = R.drawable.google_logo,
            enabled = googleEnabled,
            onClick = onGoogleSignIn
        )
        SocialProviderButton(
            title = stringResource(R.string.auth_apple_continue),
            background = Color.Black,
            textColor = Color.White,
            borderColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
            iconResId = R.drawable.apple_logo,
            enabled = appleEnabled,
            onClick = onAppleSignIn
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
                shape = RoundedCornerShape(14.dp)
            )
            .border(
                width = 1.dp,
                color = if (enabled) borderColor else borderColor.copy(alpha = 0.4f),
                shape = RoundedCornerShape(14.dp)
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
                tint = Color.Unspecified,
                modifier = Modifier.size(18.dp)
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
private fun PasswordStrengthMeter(
    password: String,
    modifier: Modifier = Modifier
) {
    val score = remember(password) {
        var value = 0
        if (password.length >= 8) value += 1
        if (password.any(Char::isUpperCase) && password.any(Char::isLowerCase)) value += 1
        if (password.any(Char::isDigit)) value += 1
        if (password.any { !it.isLetterOrDigit() }) value += 1
        value.coerceIn(0, 4)
    }

    val strengthColor = when (score) {
        0, 1 -> Color(0xFFFF5252)
        2 -> Color(0xFFFFA726)
        3 -> Color(0xFFFFEE58)
        else -> Color(0xFF35C759)
    }

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        repeat(4) { idx ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(
                        color = if (idx < score) strengthColor else MaterialTheme.colorScheme.surfaceContainerHighest,
                        shape = RoundedCornerShape(10.dp)
                    )
                    .padding(vertical = 2.dp)
            )
        }
    }
}

@Composable
private fun TermsAndPrivacyText() {
    val uriHandler = LocalUriHandler.current
    val termsLabel = stringResource(R.string.profile_terms)
    val privacyLabel = stringResource(R.string.profile_privacy)
    val prefix = stringResource(R.string.auth_terms_prefix)
    val andLabel = stringResource(R.string.common_and)

    val text = remember(prefix, termsLabel, privacyLabel, andLabel) {
        AnnotatedString.Builder().apply {
            append(prefix)
            append(" ")
            pushStringAnnotation(tag = "terms", annotation = "https://sunnad.app/terms")
            withStyle(SpanStyle(color = Color(0xFF35C759), fontWeight = FontWeight.SemiBold)) {
                append(termsLabel)
            }
            pop()
            append(" ")
            append(andLabel)
            append(" ")
            pushStringAnnotation(tag = "privacy", annotation = "https://sunnad.app/privacy")
            withStyle(SpanStyle(color = Color(0xFF35C759), fontWeight = FontWeight.SemiBold)) {
                append(privacyLabel)
            }
            pop()
            append(".")
        }.toAnnotatedString()
    }

    androidx.compose.foundation.text.ClickableText(
        text = text,
        style = MaterialTheme.typography.bodySmall.copy(
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            lineHeight = 18.sp,
            textAlign = TextAlign.Center
        ),
        modifier = Modifier.fillMaxWidth(),
        onClick = { offset ->
            text.getStringAnnotations(start = offset, end = offset)
                .firstOrNull()
                ?.let { uriHandler.openUri(it.item) }
        }
    )
}
