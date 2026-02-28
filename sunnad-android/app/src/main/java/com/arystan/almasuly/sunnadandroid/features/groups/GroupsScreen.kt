package com.arystan.almasuly.sunnadandroid.features.groups

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadActionCapsule
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadListRow
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadSectionHeader

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
    onSignIn: () -> Unit
) {
    var createName by remember { mutableStateOf("") }
    var joinCode by remember { mutableStateOf("") }
    var renameTarget by remember { mutableStateOf<Group?>(null) }
    var renameText by remember { mutableStateOf("") }
    var selectedGroup by remember { mutableStateOf<Group?>(null) }
    var showCreateDialog by remember { mutableStateOf(false) }
    var showJoinDialog by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { onLoad() }

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
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = stringResource(R.string.tab_groups),
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold
                    )
                    if (!isGuest) {
                        SunnadActionCapsule(
                            leftIcon = Icons.Rounded.Add,
                            leftContentDescription = stringResource(R.string.groups_create),
                            onLeftClick = { showCreateDialog = true },
                            rightIcon = Icons.Rounded.PersonAdd,
                            rightContentDescription = stringResource(R.string.groups_join),
                            onRightClick = { showJoinDialog = true }
                        )
                    }
                }
            }

            if (isGuest) {
                item {
                    SunnadCard(contentPadding = 18.dp) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                imageVector = Icons.Rounded.Groups,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary
                            )
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
                        PrimaryPillButton(
                            title = stringResource(R.string.groups_create),
                            onClick = { showCreateDialog = true }
                        )
                        SecondaryPillButton(
                            title = stringResource(R.string.groups_join),
                            onClick = { showJoinDialog = true }
                        )
                    }
                }
            } else {
                item {
                    SunnadSectionHeader(title = stringResource(R.string.groups_members_section))
                }

                item {
                    SunnadCard(contentPadding = 10.dp) {
                        state.groups.forEachIndexed { index, group ->
                            SunnadListRow(
                                title = group.name,
                                subtitle = stringResource(
                                    R.string.groups_members_and_code,
                                    group.members.size,
                                    group.code
                                ),
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
                                onClick = { selectedGroup = group }
                            )
                            if (index < state.groups.lastIndex) {
                                Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                            }
                        }
                    }
                }
            }

            item {
                Box(modifier = Modifier.height(96.dp))
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
        }
    }

    if (showCreateDialog) {
        AlertDialog(
            onDismissRequest = { showCreateDialog = false },
            title = { Text(stringResource(R.string.groups_create)) },
            text = {
                OutlinedTextField(
                    value = createName,
                    onValueChange = { createName = it },
                    label = { Text(stringResource(R.string.groups_create_name)) },
                    modifier = Modifier.fillMaxWidth()
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
                OutlinedTextField(
                    value = joinCode,
                    onValueChange = { joinCode = it },
                    label = { Text(stringResource(R.string.groups_join_code)) },
                    modifier = Modifier.fillMaxWidth()
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
                OutlinedTextField(
                    value = renameText,
                    onValueChange = { renameText = it },
                    label = { Text(stringResource(R.string.groups_create_name)) },
                    modifier = Modifier.fillMaxWidth()
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

    selectedGroup?.let { group ->
        AlertDialog(
            onDismissRequest = { selectedGroup = null },
            title = { Text(group.name) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.groups_code, group.code))
                    Text(stringResource(R.string.groups_members_count, group.members.size))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        TextButton(onClick = {
                            renameTarget = group
                            renameText = group.name
                            selectedGroup = null
                        }) {
                            Text(stringResource(R.string.common_rename))
                        }
                        TextButton(onClick = {
                            onToggleJoinLock(group)
                        }) {
                            Icon(Icons.Rounded.Lock, contentDescription = null)
                            Text(
                                if (group.joinLocked) {
                                    stringResource(R.string.groups_unlock)
                                } else {
                                    stringResource(R.string.groups_lock)
                                }
                            )
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        TextButton(onClick = { onRotateCode(group) }) {
                            Icon(Icons.Rounded.Refresh, contentDescription = null)
                            Text(stringResource(R.string.groups_rotate_code))
                        }
                        TextButton(onClick = {
                            onLeaveGroup(group)
                            selectedGroup = null
                        }) {
                            Text(stringResource(R.string.groups_leave))
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { selectedGroup = null }) {
                    Text(stringResource(R.string.common_done))
                }
            }
        )
    }
}
