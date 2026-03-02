package com.arystan.almasuly.sunnadandroid.features.groups

import android.widget.Toast
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
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.PersonRemove
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Group
import com.arystan.almasuly.sunnadandroid.core.model.GroupNudgeStatus
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.SharedHabit
import com.arystan.almasuly.sunnadandroid.features.habits.iconForHabitName
import com.arystan.almasuly.sunnadandroid.features.today.TodayHabitUiModel
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactBackButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadListRow
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import kotlinx.coroutines.delay
import java.util.UUID

@Composable
fun GroupsScreen(
    state: GroupsUiState,
    isGuest: Boolean,
    dueHabits: List<TodayHabitUiModel>,
    allHabits: List<Habit>,
    onLoad: () -> Unit,
    onCreateGroup: (String) -> Unit,
    onJoinGroup: (String) -> Unit,
    onToggleJoinLock: (Group) -> Unit,
    onRotateCode: (Group) -> Unit,
    onRenameGroup: (Group, String) -> Unit,
    onLeaveGroup: (Group) -> Unit,
    onDeleteGroup: (Group) -> Unit,
    onKickMember: (Group, UUID) -> Unit,
    onUpdateSharing: (Group, Set<UUID>) -> Unit,
    onToggleOwnHabit: (UUID) -> Unit,
    onSendNudge: (UUID, UUID, UUID, (GroupNudgeStatus) -> Unit) -> Unit,
    onSignIn: () -> Unit
) {
    var createName by remember { mutableStateOf("") }
    var joinCode by remember { mutableStateOf("") }
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
            dueHabits = dueHabits,
            allHabits = allHabits,
            onBack = { selectedGroupId = null },
            onRenameGroup = { newName -> onRenameGroup(group, newName) },
            onToggleJoinLock = { onToggleJoinLock(group) },
            onRotateCode = { onRotateCode(group) },
            onLeaveGroup = {
                onLeaveGroup(group)
                selectedGroupId = null
            },
            onDeleteGroup = {
                onDeleteGroup(group)
                selectedGroupId = null
            },
            onKickMember = { memberUserId -> onKickMember(group, memberUserId) },
            onUpdateSharing = { updated -> onUpdateSharing(group, updated) },
            onToggleOwnHabit = onToggleOwnHabit,
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
                    modifier = Modifier.padding(top = 8.dp)
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
                            val avatar = group.members.firstOrNull()
                            SunnadListRow(
                                title = group.name,
                                subtitle = stringResource(R.string.groups_members_count, group.members.size),
                                leading = {
                                    AvatarCircle(
                                        name = avatar?.name ?: group.name,
                                        avatarUrl = avatar?.avatarUrl,
                                        size = 36.dp
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
                                verticalPadding = 10.dp,
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

            item { Box(modifier = Modifier.height(96.dp)) }
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
    dueHabits: List<TodayHabitUiModel>,
    allHabits: List<Habit>,
    onBack: () -> Unit,
    onRenameGroup: (String) -> Unit,
    onToggleJoinLock: () -> Unit,
    onRotateCode: () -> Unit,
    onLeaveGroup: () -> Unit,
    onDeleteGroup: () -> Unit,
    onKickMember: (UUID) -> Unit,
    onUpdateSharing: (Set<UUID>) -> Unit,
    onToggleOwnHabit: (UUID) -> Unit,
    onSendNudge: (UUID, UUID, UUID, (GroupNudgeStatus) -> Unit) -> Unit
) {
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current

    var renameDraft by remember(group.id) { mutableStateOf(group.name) }
    var showRename by rememberSaveable(group.id) { mutableStateOf(false) }
    var showLeaveConfirm by rememberSaveable(group.id) { mutableStateOf(false) }
    var showDeleteConfirm by rememberSaveable(group.id) { mutableStateOf(false) }
    var expandedMembers by remember(group.id) { mutableStateOf(setOf<UUID>()) }
    var nudgeStatusText by remember(group.id) { mutableStateOf<String?>(null) }
    var showOwnerMenu by remember { mutableStateOf(false) }
    var sharingEditMode by rememberSaveable(group.id) { mutableStateOf(false) }
    var sharedHabitIds by remember(group.id) { mutableStateOf(group.sharedHabitIds) }
    var syncedSharedHabitIds by remember(group.id) { mutableStateOf(group.sharedHabitIds) }

    val currentUserMemberId = group.currentUserMemberId
    val isOwner = currentUserMemberId != null && currentUserMemberId == group.ownerMemberId

    LaunchedEffect(group.sharedHabitIds) {
        if (group.sharedHabitIds != syncedSharedHabitIds) {
            syncedSharedHabitIds = group.sharedHabitIds
            sharedHabitIds = group.sharedHabitIds
        }
    }

    LaunchedEffect(sharedHabitIds) {
        if (sharedHabitIds != syncedSharedHabitIds) {
            delay(250)
            onUpdateSharing(sharedHabitIds)
            syncedSharedHabitIds = sharedHabitIds
        }
    }

    val ownSharedHabits = remember(dueHabits, sharedHabitIds) {
        dueHabits.filter { sharedHabitIds.contains(it.id) }
    }

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
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    if (isOwner) {
                        Box {
                            IconButton(onClick = { showOwnerMenu = true }) {
                                Icon(Icons.Rounded.MoreVert, contentDescription = null)
                            }
                            DropdownMenu(
                                expanded = showOwnerMenu,
                                onDismissRequest = { showOwnerMenu = false }
                            ) {
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.groups_rename)) },
                                    leadingIcon = { Icon(Icons.Rounded.Edit, contentDescription = null) },
                                    onClick = {
                                        showOwnerMenu = false
                                        renameDraft = group.name
                                        showRename = true
                                    }
                                )
                                DropdownMenuItem(
                                    text = { Text(if (group.joinLocked) stringResource(R.string.groups_unlock) else stringResource(R.string.groups_lock)) },
                                    leadingIcon = { Icon(Icons.Rounded.Lock, contentDescription = null) },
                                    onClick = {
                                        showOwnerMenu = false
                                        onToggleJoinLock()
                                    }
                                )
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.groups_rotate_code)) },
                                    leadingIcon = { Icon(Icons.Rounded.Refresh, contentDescription = null) },
                                    onClick = {
                                        showOwnerMenu = false
                                        onRotateCode()
                                    }
                                )
                                DropdownMenuItem(
                                    text = { Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error) },
                                    leadingIcon = { Icon(Icons.Rounded.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error) },
                                    onClick = {
                                        showOwnerMenu = false
                                        showDeleteConfirm = true
                                    }
                                )
                            }
                        }
                    }
                }
            }

            item {
                SunnadCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = group.code,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.weight(1f)
                        )
                        if (group.joinLocked) {
                            Icon(
                                imageVector = Icons.Rounded.Lock,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(end = 8.dp)
                            )
                        }
                        IconButton(
                            onClick = {
                                clipboard.setText(AnnotatedString(group.code))
                                Toast.makeText(context, context.getString(R.string.common_copied), Toast.LENGTH_SHORT).show()
                            }
                        ) {
                            Icon(Icons.Rounded.ContentCopy, contentDescription = null)
                        }
                    }
                    Text(
                        text = stringResource(R.string.groups_members_count, group.members.size),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            item {
                SunnadCard(contentPadding = 0.dp) {
                    group.members.forEachIndexed { index, member ->
                        val isCurrentUser = member.id == currentUserMemberId
                        val memberHabits: List<SharedHabit> = if (isCurrentUser) {
                            ownSharedHabits.map {
                                SharedHabit(
                                    habitId = it.id,
                                    title = it.title,
                                    icon = it.icon,
                                    completedToday = it.completedToday,
                                    streak = it.streak
                                )
                            }
                        } else {
                            member.sharedHabits
                        }

                        val completedCount = memberHabits.count { it.completedToday }
                        val totalCount = memberHabits.size

                        Column {
                            SunnadListRow(
                                title = member.name,
                                subtitle = "$completedCount/$totalCount",
                                leading = {
                                    AvatarCircle(
                                        name = member.name,
                                        avatarUrl = member.avatarUrl,
                                        size = 36.dp
                                    )
                                },
                                trailing = {
                                    Icon(
                                        imageVector = if (expandedMembers.contains(member.id)) Icons.Rounded.ExpandMore else Icons.Rounded.ChevronRight,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                },
                                horizontalPadding = 16.dp,
                                verticalPadding = 10.dp,
                                onClick = {
                                    expandedMembers = if (expandedMembers.contains(member.id)) {
                                        expandedMembers - member.id
                                    } else {
                                        expandedMembers + member.id
                                    }
                                }
                            )

                            if (expandedMembers.contains(member.id)) {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(start = 64.dp, end = 18.dp, bottom = 10.dp),
                                    verticalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    memberHabits.forEach { sharedHabit ->
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Icon(
                                                imageVector = iconForHabitName(sharedHabit.icon, sharedHabit.title),
                                                contentDescription = null,
                                                tint = MaterialTheme.colorScheme.primary,
                                                modifier = Modifier.padding(end = 8.dp)
                                            )
                                            Column(modifier = Modifier.weight(1f)) {
                                                Text(
                                                    text = sharedHabit.title,
                                                    style = MaterialTheme.typography.bodyMedium,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis
                                                )
                                                Text(
                                                    text = stringResource(R.string.today_streak, sharedHabit.streak),
                                                    style = MaterialTheme.typography.bodySmall,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                                )
                                            }

                                            if (isCurrentUser) {
                                                IconButton(onClick = { onToggleOwnHabit(sharedHabit.habitId) }) {
                                                    Icon(
                                                        imageVector = if (sharedHabit.completedToday) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                                                        contentDescription = null,
                                                        tint = if (sharedHabit.completedToday) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                                    )
                                                }
                                            } else if (sharedHabit.completedToday) {
                                                Icon(
                                                    imageVector = Icons.Rounded.CheckCircle,
                                                    contentDescription = null,
                                                    tint = MaterialTheme.colorScheme.primary
                                                )
                                            } else {
                                                IconButton(onClick = {
                                                    onSendNudge(group.id, member.id, sharedHabit.habitId) { status ->
                                                        nudgeStatusText = when (status) {
                                                            GroupNudgeStatus.SENT -> context.getString(R.string.groups_nudge_sent)
                                                            GroupNudgeStatus.DUPLICATE -> context.getString(R.string.groups_nudge_duplicate)
                                                            GroupNudgeStatus.FORBIDDEN -> context.getString(R.string.groups_nudge_forbidden)
                                                            GroupNudgeStatus.ERROR -> context.getString(R.string.groups_nudge_error)
                                                        }
                                                    }
                                                }) {
                                                    Icon(
                                                        imageVector = Icons.Rounded.Notifications,
                                                        contentDescription = null,
                                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                                    )
                                                }
                                            }
                                        }
                                    }

                                    if (isOwner && !isCurrentUser) {
                                        TextButton(onClick = { onKickMember(member.id) }) {
                                            Icon(
                                                imageVector = Icons.Rounded.PersonRemove,
                                                contentDescription = null,
                                                tint = MaterialTheme.colorScheme.error
                                            )
                                            Text(
                                                text = stringResource(R.string.groups_kick_member),
                                                color = MaterialTheme.colorScheme.error,
                                                modifier = Modifier.padding(start = 8.dp)
                                            )
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

            item {
                SunnadCard(contentPadding = 0.dp) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = stringResource(R.string.groups_sharing_title),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.weight(1f)
                        )
                        TextButton(onClick = { sharingEditMode = !sharingEditMode }) {
                            Text(text = if (sharingEditMode) stringResource(R.string.common_done) else stringResource(R.string.common_edit))
                        }
                    }

                    if (sharingEditMode) {
                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                        allHabits.sortedBy { it.sortOrder }.forEachIndexed { index, habit ->
                            SunnadListRow(
                                title = habit.name,
                                leading = {
                                    Icon(
                                        imageVector = iconForHabitName(habit.icon, habit.name),
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary
                                    )
                                },
                                trailing = {
                                    Icon(
                                        imageVector = if (sharedHabitIds.contains(habit.id)) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                                        contentDescription = null,
                                        tint = if (sharedHabitIds.contains(habit.id)) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                },
                                horizontalPadding = 16.dp,
                                verticalPadding = 8.dp,
                                onClick = {
                                    sharedHabitIds = if (sharedHabitIds.contains(habit.id)) {
                                        sharedHabitIds - habit.id
                                    } else {
                                        sharedHabitIds + habit.id
                                    }
                                }
                            )
                            if (index < allHabits.lastIndex) {
                                Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                            }
                        }
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
                SecondaryPillButton(
                    title = if (isOwner) stringResource(R.string.common_delete) else stringResource(R.string.groups_leave),
                    onClick = {
                        if (isOwner) showDeleteConfirm = true else showLeaveConfirm = true
                    }
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

    if (showLeaveConfirm) {
        AlertDialog(
            onDismissRequest = { showLeaveConfirm = false },
            title = { Text(stringResource(R.string.groups_leave)) },
            text = { Text(stringResource(R.string.groups_leave_confirm)) },
            dismissButton = {
                TextButton(onClick = { showLeaveConfirm = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showLeaveConfirm = false
                    onLeaveGroup()
                }) {
                    Text(stringResource(R.string.groups_leave), color = MaterialTheme.colorScheme.error)
                }
            }
        )
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(stringResource(R.string.common_delete)) },
            text = { Text(stringResource(R.string.groups_delete_confirm)) },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    onDeleteGroup()
                }) {
                    Text(stringResource(R.string.common_delete), color = MaterialTheme.colorScheme.error)
                }
            }
        )
    }
}

@Composable
private fun AvatarCircle(
    name: String,
    avatarUrl: String?,
    size: androidx.compose.ui.unit.Dp
) {
    if (!avatarUrl.isNullOrBlank()) {
        AsyncImage(
            model = avatarUrl,
            contentDescription = null,
            modifier = Modifier
                .size(size)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape)
        )
    } else {
        Box(
            modifier = Modifier
                .size(size)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = name.trim().take(1).uppercase(),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}
