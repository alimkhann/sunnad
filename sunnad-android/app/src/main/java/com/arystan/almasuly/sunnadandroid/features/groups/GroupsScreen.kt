package com.arystan.almasuly.sunnadandroid.features.groups

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactBackButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadListRow
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadSectionHeader
import java.util.UUID

@Composable
fun GroupsScreen(
    state: GroupsUiState,
    isGuest: Boolean,
    onLoad: () -> Unit,
    onCreateGroup: (String) -> Unit,
    onJoinGroup: (String) -> Unit,
    onToggleJoinLock: (Group) -> Unit,
    onRotateCode: (Group) -> Unit,
    onRenameGroup: (Group, String) -> Unit,
    onLeaveGroup: (Group) -> Unit,
    onSendNudge: (UUID, UUID, UUID, (GroupNudgeStatus) -> Unit) -> Unit,
    onSignIn: () -> Unit
) {
    var createName by remember { mutableStateOf("") }
    var joinCode by remember { mutableStateOf("") }
    var renameTarget by remember { mutableStateOf<Group?>(null) }
    var renameText by remember { mutableStateOf("") }
    var selectedGroupId by remember { mutableStateOf<UUID?>(null) }
    var showCreateDialog by remember { mutableStateOf(false) }
    var showJoinDialog by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { onLoad() }

    val selectedGroup = remember(state.groups, selectedGroupId) {
        selectedGroupId?.let { id -> state.groups.firstOrNull { it.id == id } }
    }

    selectedGroup?.let { group ->
        GroupDetailScreen(
            group = group,
            onBack = { selectedGroupId = null },
            onRenameGroup = { newName -> onRenameGroup(group, newName) },
            onToggleJoinLock = { onToggleJoinLock(group) },
            onRotateCode = { onRotateCode(group) },
            onLeaveGroup = {
                onLeaveGroup(group)
                selectedGroupId = null
            },
            onSendNudge = onSendNudge
        )
        return
    }

    SunnadScreenSurface {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SunnadScreenPadding),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Text(
                    text = stringResource(R.string.tab_groups),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 12.dp)
                )
            }

            if (isGuest) {
                item {
                    SunnadCard(contentPadding = 18.dp) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 6.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(58.dp)
                                    .background(
                                        color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                        shape = CircleShape
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = Icons.Rounded.Groups,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        Text(
                            text = stringResource(R.string.groups_sign_in_required_title),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = stringResource(R.string.groups_sign_in_required_subtitle),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        PrimaryPillButton(
                            title = stringResource(R.string.auth_sign_in),
                            onClick = onSignIn
                        )
                    }
                }
                return@LazyColumn
            }

            if (state.groups.isEmpty()) {
                item {
                    SunnadCard {
                        Text(
                            text = stringResource(R.string.groups_empty_title),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = stringResource(R.string.groups_empty_subtitle),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                item {
                    SunnadCard(contentPadding = 0.dp) {
                        state.groups.forEachIndexed { index, group ->
                            SunnadListRow(
                                title = group.name,
                                subtitle = stringResource(R.string.groups_members_count, group.members.size),
                                leading = {
                                    Icon(
                                        imageVector = Icons.Rounded.Groups,
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
                                horizontalPadding = 16.dp,
                                verticalPadding = 8.dp,
                                onClick = { selectedGroupId = group.id }
                            )
                            if (index < state.groups.lastIndex) {
                                Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                            }
                        }
                    }
                }
            }

            item {
                PrimaryPillButton(
                    title = stringResource(R.string.groups_create),
                    onClick = { showCreateDialog = true }
                )
                Box(modifier = Modifier.height(10.dp))
                SecondaryPillButton(
                    title = stringResource(R.string.groups_join),
                    onClick = { showJoinDialog = true }
                )
            }

            state.errorMessage?.let { message ->
                item {
                    SunnadCard {
                        Text(
                            text = message,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }
            }

            item {
                Box(modifier = Modifier.height(96.dp))
            }
        }
    }

    if (showCreateDialog) {
        AlertDialog(
            onDismissRequest = { showCreateDialog = false },
            title = { Text(stringResource(R.string.groups_create)) },
            text = {
                GroupDialogField(
                    value = createName,
                    onValueChange = { createName = it },
                    placeholder = stringResource(R.string.groups_create_name)
                )
            },
            dismissButton = {
                TextButton(onClick = { showCreateDialog = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    onCreateGroup(createName)
                    createName = ""
                    showCreateDialog = false
                }) {
                    Text(stringResource(R.string.groups_create))
                }
            }
        )
    }

    if (showJoinDialog) {
        AlertDialog(
            onDismissRequest = { showJoinDialog = false },
            title = { Text(stringResource(R.string.groups_join)) },
            text = {
                GroupDialogField(
                    value = joinCode,
                    onValueChange = { joinCode = it.uppercase() },
                    placeholder = stringResource(R.string.groups_join_code)
                )
            },
            dismissButton = {
                TextButton(onClick = { showJoinDialog = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    onJoinGroup(joinCode)
                    joinCode = ""
                    showJoinDialog = false
                }) {
                    Text(stringResource(R.string.groups_join))
                }
            }
        )
    }

    if (renameTarget != null) {
        AlertDialog(
            onDismissRequest = { renameTarget = null },
            title = { Text(stringResource(R.string.groups_rename)) },
            text = {
                GroupDialogField(
                    value = renameText,
                    onValueChange = { renameText = it },
                    placeholder = stringResource(R.string.groups_create_name)
                )
            },
            dismissButton = {
                TextButton(onClick = { renameTarget = null }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val target = renameTarget ?: return@TextButton
                    onRenameGroup(target, renameText)
                    renameTarget = null
                }) {
                    Text(stringResource(R.string.common_save))
                }
            }
        )
    }
}

@Composable
private fun GroupDialogField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String
) {
    SunnadCard(contentPadding = 10.dp) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 8.dp),
            decorationBox = { inner ->
                if (value.isBlank()) {
                    Text(
                        text = placeholder,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                inner()
            }
        )
    }
}

@Composable
private fun GroupDetailScreen(
    group: Group,
    onBack: () -> Unit,
    onRenameGroup: (String) -> Unit,
    onToggleJoinLock: () -> Unit,
    onRotateCode: () -> Unit,
    onLeaveGroup: () -> Unit,
    onSendNudge: (UUID, UUID, UUID, (GroupNudgeStatus) -> Unit) -> Unit
) {
    var renameDraft by remember(group.id) { mutableStateOf(group.name) }
    var showRename by remember { mutableStateOf(false) }
    var expandedMembers by remember(group.id) { mutableStateOf(setOf<UUID>()) }
    var nudgeStatusText by remember(group.id) { mutableStateOf<String?>(null) }
    val isOwner = group.currentUserMemberId != null && group.currentUserMemberId == group.ownerMemberId

    SunnadScreenSurface {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SunnadScreenPadding),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    SunnadCompactBackButton(onClick = onBack)
                    Text(
                        text = group.name,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            item {
                SunnadCard {
                    Text(
                        text = stringResource(R.string.groups_members_count, group.members.size),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    if (isOwner) {
                        Text(
                            text = stringResource(R.string.groups_code, group.code),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            nudgeStatusText?.let { status ->
                item {
                    SunnadCard {
                        Text(
                            text = status,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }

            item {
                SunnadCard(contentPadding = 0.dp) {
                    group.members.forEachIndexed { index, member ->
                        SunnadListRow(
                            title = member.name,
                            subtitle = "${member.completedToday}/${member.totalSharedHabits}",
                            leading = {
                                Icon(
                                    imageVector = Icons.Rounded.Groups,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            },
                            trailing = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    if (member.sharedHabits.isNotEmpty()) {
                                        Icon(
                                            imageVector = if (expandedMembers.contains(member.id)) Icons.Rounded.Refresh else Icons.Rounded.ChevronRight,
                                            contentDescription = null,
                                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                }
                            },
                            onClick = {
                                expandedMembers = if (expandedMembers.contains(member.id)) {
                                    expandedMembers - member.id
                                } else {
                                    expandedMembers + member.id
                                }
                            },
                            horizontalPadding = 16.dp,
                            verticalPadding = 8.dp
                        )
                        if (expandedMembers.contains(member.id) && member.sharedHabits.isNotEmpty()) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(start = 52.dp, end = 16.dp, bottom = 10.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                member.sharedHabits.forEach { shared ->
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            text = shared.title,
                                            style = MaterialTheme.typography.bodyMedium,
                                            modifier = Modifier.weight(1f)
                                        )
                                        if (group.currentUserMemberId != member.id) {
                                            TextButton(
                                                onClick = {
                                                    onSendNudge(group.id, member.id, shared.habitId) { status ->
                                                        nudgeStatusText = when (status) {
                                                            GroupNudgeStatus.SENT -> "Nudge sent."
                                                            GroupNudgeStatus.DUPLICATE -> "Already nudged recently."
                                                            GroupNudgeStatus.FORBIDDEN -> "Nudge not allowed."
                                                            GroupNudgeStatus.ERROR -> "Could not send nudge."
                                                        }
                                                    }
                                                }
                                            ) {
                                                Text(stringResource(R.string.groups_nudge))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if (index < group.members.lastIndex) {
                            Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        }
                    }
                }
            }

            if (isOwner) {
                item {
                    SunnadSectionHeader(title = stringResource(R.string.profile_settings_section))
                }
                item {
                    SunnadCard(contentPadding = 0.dp) {
                        SunnadListRow(
                            title = stringResource(R.string.groups_rename),
                            horizontalPadding = 16.dp,
                            onClick = {
                                renameDraft = group.name
                                showRename = true
                            }
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        SunnadListRow(
                            title = if (group.joinLocked) stringResource(R.string.groups_unlock) else stringResource(R.string.groups_lock),
                            leading = {
                                Icon(
                                    imageVector = Icons.Rounded.Lock,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            },
                            horizontalPadding = 16.dp,
                            onClick = onToggleJoinLock
                        )
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        SunnadListRow(
                            title = stringResource(R.string.groups_rotate_code),
                            leading = {
                                Icon(
                                    imageVector = Icons.Rounded.Refresh,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            },
                            horizontalPadding = 16.dp,
                            onClick = onRotateCode
                        )
                    }
                }
            }

            item {
                SecondaryPillButton(
                    title = stringResource(R.string.groups_leave),
                    onClick = onLeaveGroup
                )
            }

            item { Box(modifier = Modifier.height(80.dp)) }
        }
    }

    if (showRename) {
        AlertDialog(
            onDismissRequest = { showRename = false },
            title = { Text(stringResource(R.string.groups_rename)) },
            text = {
                GroupDialogField(
                    value = renameDraft,
                    onValueChange = { renameDraft = it },
                    placeholder = stringResource(R.string.groups_create_name)
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    onRenameGroup(renameDraft)
                    showRename = false
                }) {
                    Text(stringResource(R.string.common_save))
                }
            },
            dismissButton = {
                TextButton(onClick = { showRename = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            }
        )
    }
}
