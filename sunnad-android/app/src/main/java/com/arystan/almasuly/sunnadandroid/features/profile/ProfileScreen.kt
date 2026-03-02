package com.arystan.almasuly.sunnadandroid.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.arystan.almasuly.sunnadandroid.BuildConfig
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.SessionUser
import com.arystan.almasuly.sunnadandroid.services.AppAppearance
import com.arystan.almasuly.sunnadandroid.services.AppLanguage
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadListRow
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadSectionHeader
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    state: ProfileUiState,
    user: SessionUser?,
    onRefresh: () -> Unit,
    onSetLanguage: (AppLanguage) -> Unit,
    onSetAppearance: (AppAppearance) -> Unit,
    onSetHabitReminder: (Boolean) -> Unit,
    onSetQuoteReminder: (Boolean) -> Unit,
    onSetGroupReminder: (Boolean) -> Unit,
    onSetHaptics: (Boolean) -> Unit,
    onSetSounds: (Boolean) -> Unit,
    onDeleteData: () -> Unit,
    onDeleteAccount: () -> Unit,
    onEditProfile: (String) -> Unit,
    onUploadAvatar: (ByteArray, String) -> Unit,
    onRemoveAvatar: () -> Unit,
    onRequestSignIn: () -> Unit,
    onSignOut: () -> Unit,
    onChangePassword: () -> Unit,
    onOpenSavedQuotes: () -> Unit,
    onOpenInsights: () -> Unit,
    onOpenManageHabits: () -> Unit,
    debugAuthStatus: String? = null
) {
    var showLanguageDialog by remember { mutableStateOf(false) }
    var showAppearanceDialog by remember { mutableStateOf(false) }
    var showNotificationDialog by remember { mutableStateOf(false) }
    var showSoundDialog by remember { mutableStateOf(false) }
    var showFeedbackSheet by remember { mutableStateOf(false) }
    var showSignOutDialog by remember { mutableStateOf(false) }
    var showDeleteDataDialog by remember { mutableStateOf(false) }
    var showDeleteAccountDialog by remember { mutableStateOf(false) }
    var showEditProfileDialog by remember { mutableStateOf(false) }
    var editUsername by remember { mutableStateOf("") }
    val context = LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val pickAvatarLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        scope.launch {
            val data = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (data != null && data.isNotEmpty()) {
                val mimeType = context.contentResolver.getType(uri) ?: "image/jpeg"
                onUploadAvatar(data, mimeType)
            }
        }
    }

    LaunchedEffect(Unit) { onRefresh() }

    SunnadScreenSurface {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SunnadScreenPadding),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Text(
                    text = stringResource(R.string.tab_profile),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            item { SunnadSectionHeader(stringResource(R.string.profile_account_section)) }
            item {
                SunnadCard(contentPadding = 10.dp) {
                    if (user == null) {
                        SunnadListRow(
                            title = stringResource(R.string.profile_guest_mode),
                            subtitle = stringResource(R.string.profile_tap_sign_in_short),
                            leading = {
                                Icon(
                                    imageVector = Icons.Rounded.Person,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            },
                            trailing = {
                                Icon(
                                    imageVector = Icons.Rounded.ChevronRight,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            },
                            onClick = onRequestSignIn
                        )
                    } else {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    editUsername = user.username.orEmpty()
                                    showEditProfileDialog = true
                                }
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            AvatarBadge(user = user, size = 42.dp)
                            Column(
                                modifier = Modifier
                                    .weight(1f)
                                    .padding(start = 12.dp)
                            ) {
                                Text(
                                    text = user.displayName,
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold
                                )
                                Text(
                                    text = user.email ?: "",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = stringResource(R.string.profile_edit_profile),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.padding(top = 2.dp)
                                )
                            }
                            Icon(
                                imageVector = Icons.Rounded.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .size(20.dp)
                                    .padding(start = 2.dp)
                            )
                        }
                    }
                }
            }

            item { SunnadSectionHeader(stringResource(R.string.profile_saved_section)) }
            item {
                SunnadCard(contentPadding = 10.dp) {
                    SunnadListRow(
                        title = stringResource(R.string.profile_saved_quotes),
                        subtitle = stringResource(R.string.profile_saved_quotes_count, state.savedQuotes.size),
                        trailing = {
                            Icon(
                                imageVector = Icons.Rounded.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        },
                        onClick = onOpenSavedQuotes
                    )
                }
            }

            item { SunnadSectionHeader(stringResource(R.string.profile_habits_section)) }
            item {
                SunnadCard(contentPadding = 10.dp) {
                    SunnadListRow(
                        title = stringResource(R.string.profile_manage_habits),
                        trailing = {
                            Icon(
                                imageVector = Icons.Rounded.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        },
                        onClick = onOpenManageHabits
                    )
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                    SunnadListRow(
                        title = stringResource(R.string.profile_insights),
                        trailing = {
                            Icon(
                                imageVector = Icons.Rounded.ChevronRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        },
                        onClick = onOpenInsights
                    )
                }
            }

            item { SunnadSectionHeader(stringResource(R.string.profile_settings_section)) }
            item {
                SunnadCard(contentPadding = 10.dp) {
                    SunnadListRow(
                        title = stringResource(R.string.profile_appearance),
                        subtitle = appearanceDisplayName(state.appearance),
                        trailing = {
                            Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        },
                        onClick = { showAppearanceDialog = true }
                    )
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                    SunnadListRow(
                        title = stringResource(R.string.profile_language),
                        subtitle = languageDisplayName(state.language),
                        trailing = {
                            Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        },
                        onClick = { showLanguageDialog = true }
                    )
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                    SunnadListRow(
                        title = stringResource(R.string.profile_notifications),
                        trailing = {
                            Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        },
                        onClick = { showNotificationDialog = true }
                    )
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                    SunnadListRow(
                        title = stringResource(R.string.profile_sounds_haptics),
                        trailing = {
                            Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        },
                        onClick = { showSoundDialog = true }
                    )
                    if (user != null) {
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        SunnadListRow(
                            title = stringResource(R.string.profile_change_password),
                            trailing = {
                                Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            },
                            onClick = onChangePassword
                        )
                    }
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                    SunnadListRow(
                        title = stringResource(R.string.profile_privacy),
                        trailing = {
                            Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    )
                }
            }

            item { SunnadSectionHeader(stringResource(R.string.profile_support_section)) }
            item {
                SunnadCard(contentPadding = 10.dp) {
                    SunnadListRow(
                        title = stringResource(R.string.profile_help_faq),
                        trailing = { Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant) }
                    )
                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                    SunnadListRow(
                        title = stringResource(R.string.profile_send_feedback),
                        trailing = { Icon(Icons.Rounded.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant) },
                        onClick = { showFeedbackSheet = true }
                    )
                }
            }

            item { SunnadSectionHeader(stringResource(R.string.profile_danger_section)) }
            item {
                SunnadCard(contentPadding = 10.dp) {
                    if (user != null) {
                        SunnadListRow(
                            title = stringResource(R.string.auth_sign_out),
                            leading = {
                                Icon(
                                    imageVector = Icons.Rounded.Warning,
                                    contentDescription = null,
                                    tint = Color(0xFFFF4D5A)
                                )
                            },
                            titleColor = Color(0xFFFF4D5A),
                            trailing = {
                                Icon(
                                    imageVector = Icons.Rounded.ChevronRight,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            },
                            onClick = { showSignOutDialog = true }
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        SunnadListRow(
                            title = stringResource(R.string.profile_delete_account),
                            leading = {
                                Icon(
                                    imageVector = Icons.Rounded.Warning,
                                    contentDescription = null,
                                    tint = Color(0xFFFF4D5A)
                                )
                            },
                            titleColor = Color(0xFFFF4D5A),
                            trailing = {
                                Icon(
                                    imageVector = Icons.Rounded.ChevronRight,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            },
                            onClick = { showDeleteAccountDialog = true }
                        )
                    } else {
                        SunnadListRow(
                            title = stringResource(R.string.profile_delete_data),
                            leading = {
                                Icon(
                                    imageVector = Icons.Rounded.Warning,
                                    contentDescription = null,
                                    tint = Color(0xFFFF4D5A)
                                )
                            },
                            titleColor = Color(0xFFFF4D5A),
                            trailing = {
                                Icon(
                                    imageVector = Icons.Rounded.ChevronRight,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            },
                            onClick = { showDeleteDataDialog = true }
                        )
                    }
                }
            }

            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        text = stringResource(R.string.profile_version, BuildConfig.VERSION_NAME),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    debugAuthStatus?.let {
                        Text(
                            text = it,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.outline
                        )
                    }
                }
            }

            item { Box(modifier = Modifier.height(96.dp)) }
        }
    }

    if (showLanguageDialog) {
        AlertDialog(
            onDismissRequest = { showLanguageDialog = false },
            title = { Text(stringResource(R.string.profile_language)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppLanguage.entries.forEach { language ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(languageDisplayName(language))
                            TextButton(onClick = {
                                onSetLanguage(language)
                                showLanguageDialog = false
                            }) {
                                Text(if (state.language == language) stringResource(R.string.common_selected) else stringResource(R.string.common_select))
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showLanguageDialog = false }) {
                    Text(stringResource(R.string.common_done))
                }
            }
        )
    }

    if (showAppearanceDialog) {
        AlertDialog(
            onDismissRequest = { showAppearanceDialog = false },
            title = { Text(stringResource(R.string.profile_appearance)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppAppearance.entries.forEach { appearance ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(appearanceDisplayName(appearance))
                            TextButton(onClick = {
                                onSetAppearance(appearance)
                                showAppearanceDialog = false
                            }) {
                                Text(if (state.appearance == appearance) stringResource(R.string.common_selected) else stringResource(R.string.common_select))
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showAppearanceDialog = false }) {
                    Text(stringResource(R.string.common_done))
                }
            }
        )
    }

    if (showNotificationDialog) {
        AlertDialog(
            onDismissRequest = { showNotificationDialog = false },
            title = { Text(stringResource(R.string.profile_notifications)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    NotificationToggle(stringResource(R.string.profile_habit_reminders), state.settings.habitRemindersEnabled, onSetHabitReminder)
                    NotificationToggle(stringResource(R.string.profile_quote_reminder), state.settings.quoteReminderEnabled, onSetQuoteReminder)
                    NotificationToggle(stringResource(R.string.profile_group_reminders), state.settings.groupRemindersEnabled, onSetGroupReminder)
                }
            },
            confirmButton = {
                TextButton(onClick = { showNotificationDialog = false }) {
                    Text(stringResource(R.string.common_done))
                }
            }
        )
    }

    if (showSoundDialog) {
        AlertDialog(
            onDismissRequest = { showSoundDialog = false },
            title = { Text(stringResource(R.string.profile_sounds_haptics)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    NotificationToggle(stringResource(R.string.profile_haptics), state.settings.hapticsEnabled, onSetHaptics)
                    NotificationToggle(stringResource(R.string.profile_sounds), state.settings.soundsEnabled, onSetSounds)
                }
            },
            confirmButton = {
                TextButton(onClick = { showSoundDialog = false }) {
                    Text(stringResource(R.string.common_done))
                }
            }
        )
    }

    if (showFeedbackSheet) {
        FeedbackSheet(onDismiss = { showFeedbackSheet = false })
    }

    if (showEditProfileDialog) {
        ModalBottomSheet(onDismissRequest = { showEditProfileDialog = false }) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SunnadScreenPadding, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = stringResource(R.string.profile_edit_profile),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold
                )
                SunnadCard(contentPadding = 0.dp) {
                    TextField(
                        value = editUsername,
                        onValueChange = { editUsername = it.lowercase() },
                        singleLine = true,
                        label = { Text(stringResource(R.string.auth_username)) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = TextFieldDefaults.colors(
                            focusedContainerColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent,
                            disabledContainerColor = Color.Transparent,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent,
                            disabledIndicatorColor = Color.Transparent
                        )
                    )
                    Text(
                        text = stringResource(R.string.auth_username_hint),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                    )
                }
                SunnadCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center
                    ) {
                        AvatarBadge(user = user, size = 72.dp)
                    }
                    PrimaryPillButton(
                        title = stringResource(R.string.profile_change_photo),
                        onClick = {
                            pickAvatarLauncher.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        }
                    )
                    SecondaryPillButton(
                        title = stringResource(R.string.profile_remove_photo),
                        onClick = onRemoveAvatar
                    )
                }
                PrimaryPillButton(
                    title = stringResource(R.string.common_save),
                    onClick = {
                        showEditProfileDialog = false
                        onEditProfile(editUsername.trim())
                    }
                )
                Box(modifier = Modifier.height(8.dp))
            }
        }
    }

    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            title = { Text(stringResource(R.string.auth_sign_out)) },
            text = { Text(stringResource(R.string.profile_sign_out_confirm)) },
            dismissButton = {
                TextButton(onClick = { showSignOutDialog = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showSignOutDialog = false
                    onSignOut()
                }) {
                    Text(stringResource(R.string.auth_sign_out), color = Color(0xFFFF4D5A))
                }
            }
        )
    }

    if (showDeleteDataDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDataDialog = false },
            title = { Text(stringResource(R.string.profile_delete_data)) },
            text = { Text(stringResource(R.string.profile_delete_data_confirm)) },
            dismissButton = {
                TextButton(onClick = { showDeleteDataDialog = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteDataDialog = false
                    onDeleteData()
                }) {
                    Text(stringResource(R.string.common_delete), color = Color(0xFFFF4D5A))
                }
            }
        )
    }

    if (showDeleteAccountDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteAccountDialog = false },
            title = { Text(stringResource(R.string.profile_delete_account)) },
            text = { Text(stringResource(R.string.profile_delete_account_confirm)) },
            dismissButton = {
                TextButton(onClick = { showDeleteAccountDialog = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteAccountDialog = false
                    onDeleteAccount()
                }) {
                    Text(stringResource(R.string.common_delete), color = Color(0xFFFF4D5A))
                }
            }
        )
    }
}

@Composable
private fun AvatarBadge(
    user: SessionUser?,
    size: androidx.compose.ui.unit.Dp
) {
    if (!user?.avatarUrl.isNullOrBlank()) {
        AsyncImage(
            model = user?.avatarUrl,
            contentDescription = null,
            modifier = Modifier
                .size(size)
                .background(MaterialTheme.colorScheme.surfaceContainerHighest, CircleShape)
        )
    } else {
        Box(
            modifier = Modifier
                .size(size)
                .background(MaterialTheme.colorScheme.surfaceContainerHighest, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = user?.displayName?.trim()?.take(1)?.uppercase()
                    ?: stringResource(R.string.profile_guest_mode).take(1),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SavedQuotesSheet(
    state: ProfileUiState,
    onDismiss: () -> Unit
) {
    androidx.compose.material3.ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SunnadScreenPadding, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = stringResource(R.string.profile_saved_quotes),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold
            )
            if (state.savedQuotes.isEmpty()) {
                Text(
                    text = stringResource(R.string.profile_saved_quotes_empty),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                state.savedQuotes.forEach { quote ->
                    SunnadCard {
                        Text(quote.text, style = MaterialTheme.typography.bodyLarge)
                        Text(
                            text = quote.author,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
            Box(modifier = Modifier.height(12.dp))
        }
    }
}

@Composable
private fun NotificationToggle(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun languageDisplayName(language: AppLanguage): String {
    return when (language) {
        AppLanguage.EN -> stringResource(R.string.language_english)
        AppLanguage.RU -> stringResource(R.string.language_russian)
        AppLanguage.KK -> stringResource(R.string.language_kazakh)
    }
}

@Composable
private fun appearanceDisplayName(appearance: AppAppearance): String {
    return when (appearance) {
        AppAppearance.SYSTEM -> stringResource(R.string.appearance_system)
        AppAppearance.LIGHT -> stringResource(R.string.appearance_light)
        AppAppearance.DARK -> stringResource(R.string.appearance_dark)
    }
}
