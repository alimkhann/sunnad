package com.arystan.almasuly.sunnadandroid.features.groups

import android.widget.Toast
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Check
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
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.LockOpen
import androidx.compose.material.icons.rounded.PieChart
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
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
import com.arystan.almasuly.sunnadandroid.core.model.GroupProgressDisplayMode
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
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadSectionHeader
import kotlinx.coroutines.delay
import java.util.UUID

private data class GroupNudgePrompt(
    val memberId: UUID,
    val memberName: String,
    val habitId: UUID,
    val habitTitle: String
)

@OptIn(ExperimentalMaterial3Api::class)
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
    onSetProgressDisplayMode: (Group, GroupProgressDisplayMode) -> Unit,
    onUpdateSharing: (Group, Set<UUID>) -> Unit,
    onToggleOwnHabit: (UUID) -> Unit,
    onSendNudge: (UUID, UUID, UUID, (GroupNudgeStatus) -> Unit) -> Unit,
    onSignIn: () -> Unit
) {
    var createName by remember { mutableStateOf("") }
    var joinCode by remember { mutableStateOf("") }
    var selectedGroupId by remember { mutableStateOf<UUID?>(null) }
    var showCreateDialog by rememberSaveable { mutableStateOf(false) }
    var showJoinDialog by rememberSaveable { mutableStateOf(false) }
    var isPullRefreshing by remember { mutableStateOf(false) }

    val selectedGroup = remember(state.groups, selectedGroupId) {
        selectedGroupId?.let { id -> state.groups.firstOrNull { it.id == id } }
    }

    LaunchedEffect(state.hasLoadedOnce) {
        if (!state.hasLoadedOnce && !state.isLoading) {
            onLoad()
        }
    }

    LaunchedEffect(state.isLoading) {
        if (!state.isLoading) {
            isPullRefreshing = false
        }
    }

    selectedGroup?.let { group ->
        GroupDetailScreen(
            group = group,
            dueHabits = dueHabits,
            allHabits = allHabits,
            isRefreshing = isPullRefreshing && state.isLoading,
            onRefresh = {
                isPullRefreshing = true
                onLoad()
            },
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
            onSetProgressDisplayMode = { mode -> onSetProgressDisplayMode(group, mode) },
            onUpdateSharing = { updated -> onUpdateSharing(group, updated) },
            onToggleOwnHabit = onToggleOwnHabit,
            onSendNudge = onSendNudge
        )
        return
    }

    SunnadScreenSurface {
        PullToRefreshBox(
            isRefreshing = isPullRefreshing && state.isLoading,
            onRefresh = {
                isPullRefreshing = true
                onLoad()
            },
            modifier = Modifier.fillMaxWidth()
        ) {
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
                            title = stringResource(R.string.groups_join_with_code),
                            onClick = { showJoinDialog = true }
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
                                    Box(
                                        modifier = Modifier
                                            .size(36.dp)
                                            .background(
                                                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                                shape = CircleShape
                                            ),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            imageVector = Icons.Rounded.Groups,
                                            contentDescription = null,
                                            tint = MaterialTheme.colorScheme.primary
                                        )
                                    }
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

            if (state.groups.isNotEmpty()) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
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
    }

    if (showCreateDialog) {
        GroupInputDialog(
            title = stringResource(R.string.groups_create),
            placeholder = stringResource(R.string.groups_create_name),
            value = createName,
            onValueChange = { createName = it },
            confirmLabel = stringResource(R.string.groups_create),
            onDismiss = {
                showCreateDialog = false
                createName = ""
            },
            onConfirm = {
                onCreateGroup(createName)
                createName = ""
                showCreateDialog = false
            }
        )
    }

    if (showJoinDialog) {
        GroupInputDialog(
            title = stringResource(R.string.groups_join_with_code),
            placeholder = stringResource(R.string.groups_join_code),
            value = joinCode,
            onValueChange = { joinCode = it.uppercase() },
            confirmLabel = stringResource(R.string.groups_join),
            onDismiss = {
                showJoinDialog = false
                joinCode = ""
            },
            onConfirm = {
                onJoinGroup(joinCode)
                joinCode = ""
                showJoinDialog = false
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
private fun GroupInputDialog(
    title: String,
    placeholder: String,
    value: String,
    onValueChange: (String) -> Unit,
    confirmLabel: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            GroupDialogField(
                value = value,
                onValueChange = onValueChange,
                placeholder = placeholder
            )
        },
        confirmButton = {
            TextButton(
                enabled = value.isNotBlank(),
                onClick = onConfirm
            ) {
                Text(confirmLabel)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.common_cancel))
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GroupDetailScreen(
    group: Group,
    dueHabits: List<TodayHabitUiModel>,
    allHabits: List<Habit>,
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    onBack: () -> Unit,
    onRenameGroup: (String) -> Unit,
    onToggleJoinLock: () -> Unit,
    onRotateCode: () -> Unit,
    onLeaveGroup: () -> Unit,
    onDeleteGroup: () -> Unit,
    onKickMember: (UUID) -> Unit,
    onSetProgressDisplayMode: (GroupProgressDisplayMode) -> Unit,
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
    var nudgePrompt by remember(group.id) { mutableStateOf<GroupNudgePrompt?>(null) }
    var showOwnerMenu by remember { mutableStateOf(false) }
    var sharingEditMode by rememberSaveable(group.id) { mutableStateOf(false) }
    var sharedHabitIds by remember(group.id) { mutableStateOf(group.sharedHabitIds) }
    var lastServerSharedHabitIds by remember(group.id) { mutableStateOf(group.sharedHabitIds) }
    var shareRequestVersion by remember(group.id) { mutableStateOf(0) }
    var progressDisplayMode by remember(group.id) { mutableStateOf(group.progressDisplayMode) }
    var ownCompletionOverrides by remember(group.id) { mutableStateOf<Map<UUID, Boolean>>(emptyMap()) }
    var codeCopiedSequence by remember(group.id) { mutableStateOf(0) }
    var showsCopiedCodeSuccess by remember(group.id) { mutableStateOf(false) }
    var isPullRefreshing by remember(group.id) { mutableStateOf(false) }

    val currentUserMemberId = group.currentUserMemberId
    val isOwner = currentUserMemberId != null && currentUserMemberId == group.ownerMemberId

    LaunchedEffect(group.sharedHabitIds) {
        val serverSharedHabitIds = group.sharedHabitIds
        val localHasPendingSelection = sharedHabitIds != lastServerSharedHabitIds
        val staleEchoFromRefresh =
            localHasPendingSelection &&
            serverSharedHabitIds == lastServerSharedHabitIds &&
            serverSharedHabitIds != sharedHabitIds

        if (staleEchoFromRefresh) return@LaunchedEffect

        if (serverSharedHabitIds != lastServerSharedHabitIds || serverSharedHabitIds != sharedHabitIds) {
            lastServerSharedHabitIds = serverSharedHabitIds
            sharedHabitIds = serverSharedHabitIds
        }
    }
    LaunchedEffect(group.progressDisplayMode) {
        progressDisplayMode = group.progressDisplayMode
    }
    LaunchedEffect(sharedHabitIds, dueHabits) {
        val completionById = dueHabits.associate { it.id to it.completedToday }
        ownCompletionOverrides = ownCompletionOverrides.filter { (habitId, optimisticValue) ->
            val current = completionById[habitId] ?: return@filter false
            sharedHabitIds.contains(habitId) && optimisticValue != current
        }
    }

    LaunchedEffect(codeCopiedSequence) {
        if (codeCopiedSequence <= 0) return@LaunchedEffect
        delay(1100)
        showsCopiedCodeSuccess = false
    }

    LaunchedEffect(isRefreshing) {
        if (!isRefreshing) {
            isPullRefreshing = false
        }
    }

    LaunchedEffect(sharedHabitIds) {
        if (sharedHabitIds == lastServerSharedHabitIds) return@LaunchedEffect
        val target = sharedHabitIds
        val requestVersion = shareRequestVersion + 1
        shareRequestVersion = requestVersion
        delay(250)
        if (shareRequestVersion != requestVersion || sharedHabitIds != target) return@LaunchedEffect
        onUpdateSharing(target)
    }

    val ownSharedHabits = remember(dueHabits, sharedHabitIds) {
        dueHabits.filter { sharedHabitIds.contains(it.id) }
    }.map {
        if (ownCompletionOverrides.containsKey(it.id)) {
            it.copy(completedToday = ownCompletionOverrides[it.id] == true)
        } else {
            it
        }
    }
    val ownSharedHabitsById = remember(ownSharedHabits) {
        ownSharedHabits.associateBy { it.id }
    }

    SunnadScreenSurface {
        PullToRefreshBox(
            isRefreshing = isPullRefreshing && isRefreshing,
            onRefresh = {
                isPullRefreshing = true
                onRefresh()
            },
            modifier = Modifier.fillMaxWidth()
        ) {
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
                    Box {
                        IconButton(onClick = { showOwnerMenu = true }) {
                            Icon(Icons.Rounded.MoreVert, contentDescription = null)
                        }
                        DropdownMenu(
                            expanded = showOwnerMenu,
                            onDismissRequest = { showOwnerMenu = false }
                        ) {
                            if (isOwner) {
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
                            }
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.groups_progress_mode_percent)) },
                                leadingIcon = {
                                    Icon(
                                        imageVector = if (progressDisplayMode == GroupProgressDisplayMode.PERCENT) Icons.Rounded.Check else Icons.Rounded.PieChart,
                                        contentDescription = null
                                    )
                                },
                                onClick = {
                                    showOwnerMenu = false
                                    if (progressDisplayMode != GroupProgressDisplayMode.PERCENT) {
                                        progressDisplayMode = GroupProgressDisplayMode.PERCENT
                                        onSetProgressDisplayMode(GroupProgressDisplayMode.PERCENT)
                                    }
                                }
                            )
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.groups_progress_mode_streak)) },
                                leadingIcon = {
                                    Icon(
                                        imageVector = if (progressDisplayMode == GroupProgressDisplayMode.STREAK) Icons.Rounded.Check else Icons.Rounded.LocalFireDepartment,
                                        contentDescription = null
                                    )
                                },
                                onClick = {
                                    showOwnerMenu = false
                                    if (progressDisplayMode != GroupProgressDisplayMode.STREAK) {
                                        progressDisplayMode = GroupProgressDisplayMode.STREAK
                                        onSetProgressDisplayMode(GroupProgressDisplayMode.STREAK)
                                    }
                                }
                            )
                            if (isOwner) {
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
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .border(
                                width = 1.dp,
                                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
                                shape = RoundedCornerShape(12.dp)
                            )
                            .background(
                                color = MaterialTheme.colorScheme.surfaceContainer,
                                shape = RoundedCornerShape(12.dp)
                            )
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = group.code,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold
                            )
                            Icon(
                                imageVector = if (group.joinLocked) Icons.Rounded.Lock else Icons.Rounded.LockOpen,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(start = 8.dp, end = 2.dp)
                            )
                            IconButton(
                                onClick = {
                                    clipboard.setText(AnnotatedString(group.code))
                                    codeCopiedSequence += 1
                                    showsCopiedCodeSuccess = true
                                    Toast.makeText(context, context.getString(R.string.common_copied), Toast.LENGTH_SHORT).show()
                                },
                                modifier = Modifier.size(28.dp)
                            ) {
                                Icon(
                                    imageVector = if (showsCopiedCodeSuccess) Icons.Rounded.CheckCircle else Icons.Rounded.ContentCopy,
                                    contentDescription = null,
                                    tint = if (showsCopiedCodeSuccess) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }
                    Spacer(modifier = Modifier.weight(1f))
                }
            }

            item {
                SunnadSectionHeader(stringResource(R.string.groups_members_section))
            }
            item {
                SunnadCard(contentPadding = 0.dp) {
                    group.members.forEachIndexed { index, member ->
                        val isCurrentUser = member.id == currentUserMemberId
                        val memberHabits: List<SharedHabit> = if (isCurrentUser) {
                            val dueRemoteHabits = member.sharedHabits
                                .filter { it.dueToday }
                            if (dueRemoteHabits.isEmpty()) {
                                ownSharedHabits.map { local ->
                                    SharedHabit(
                                        habitId = local.id,
                                        title = local.title,
                                        icon = local.icon,
                                        completedToday = ownCompletionOverrides[local.id] ?: local.completedToday,
                                        dueToday = true,
                                        streak = local.streak,
                                        rollingCompletionPercent = null
                                    )
                                }
                            } else {
                                dueRemoteHabits
                                .map { remote ->
                                    val local = ownSharedHabitsById[remote.habitId]
                                    SharedHabit(
                                        habitId = remote.habitId,
                                        title = local?.title ?: remote.title,
                                        icon = local?.icon ?: remote.icon,
                                        completedToday = ownCompletionOverrides[remote.habitId]
                                            ?: local?.completedToday
                                            ?: remote.completedToday,
                                        dueToday = true,
                                        streak = local?.streak ?: remote.streak,
                                        rollingCompletionPercent = remote.rollingCompletionPercent
                                    )
                                }
                            }
                        } else {
                            member.sharedHabits.filter { it.dueToday }
                        }

                        val completedCount = memberHabits.count { it.completedToday }
                        val totalCount = memberHabits.size

                        Column {
                            SunnadListRow(
                                title = member.name,
                                subtitle = stringResource(
                                    R.string.groups_member_today_progress,
                                    completedCount,
                                    totalCount
                                ),
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
                                            Box(
                                                modifier = Modifier
                                                    .size(34.dp)
                                                    .background(
                                                        color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                                        shape = CircleShape
                                                    ),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                Icon(
                                                    imageVector = iconForHabitName(sharedHabit.icon, sharedHabit.title),
                                                    contentDescription = null,
                                                    tint = MaterialTheme.colorScheme.primary
                                                )
                                            }
                                            Column(modifier = Modifier.weight(1f)) {
                                                Text(
                                                    text = sharedHabit.title,
                                                    style = MaterialTheme.typography.bodyMedium,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis
                                                )
                                                Text(
                                                    text = when (progressDisplayMode) {
                                                        GroupProgressDisplayMode.STREAK ->
                                                            stringResource(R.string.today_streak, sharedHabit.streak)

                                                        GroupProgressDisplayMode.PERCENT ->
                                                            stringResource(
                                                                R.string.insights_percent_complete,
                                                                sharedHabit.rollingCompletionPercent ?: 0
                                                            )
                                                    },
                                                    style = MaterialTheme.typography.bodySmall,
                                                    color = Color(0xFFE7C857)
                                                )
                                            }

                                            if (isCurrentUser) {
                                                IconButton(onClick = {
                                                    ownCompletionOverrides = ownCompletionOverrides + (
                                                        sharedHabit.habitId to !sharedHabit.completedToday
                                                        )
                                                    onToggleOwnHabit(sharedHabit.habitId)
                                                }) {
                                                    Icon(
                                                        imageVector = if (sharedHabit.completedToday) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                                                        contentDescription = null,
                                                        tint = if (sharedHabit.completedToday) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                                        modifier = Modifier.size(22.dp)
                                                    )
                                                }
                                            } else if (sharedHabit.completedToday) {
                                                Icon(
                                                    imageVector = Icons.Rounded.CheckCircle,
                                                    contentDescription = null,
                                                    tint = MaterialTheme.colorScheme.primary,
                                                    modifier = Modifier.size(22.dp)
                                                )
                                            } else {
                                                IconButton(onClick = {
                                                    nudgePrompt = GroupNudgePrompt(
                                                        memberId = member.id,
                                                        memberName = member.name,
                                                        habitId = sharedHabit.habitId,
                                                        habitTitle = sharedHabit.title
                                                    )
                                                }) {
                                                    Icon(
                                                        imageVector = Icons.Rounded.Notifications,
                                                        contentDescription = null,
                                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                                        modifier = Modifier.size(22.dp)
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
                SunnadSectionHeader(stringResource(R.string.groups_sharing_title))
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
                            text = stringResource(R.string.groups_sharing_summary, sharedHabitIds.size),
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
                                    Box(
                                        modifier = Modifier
                                            .size(30.dp)
                                            .background(
                                                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                                shape = CircleShape
                                            ),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(
                                            imageVector = iconForHabitName(habit.icon, habit.name),
                                            contentDescription = null,
                                            tint = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
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

                item { Box(modifier = Modifier.height(80.dp)) }
            }
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

    nudgePrompt?.let { prompt ->
        AlertDialog(
            onDismissRequest = { nudgePrompt = null },
            title = { Text(stringResource(R.string.groups_nudge)) },
            text = {
                Text(
                    text = stringResource(
                        R.string.groups_nudge_confirm_message,
                        prompt.memberName,
                        prompt.habitTitle
                    )
                )
            },
            dismissButton = {
                TextButton(onClick = { nudgePrompt = null }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    onSendNudge(group.id, prompt.memberId, prompt.habitId) { status ->
                        nudgeStatusText = when (status) {
                            GroupNudgeStatus.SENT -> context.getString(R.string.groups_nudge_sent)
                            GroupNudgeStatus.DUPLICATE -> context.getString(R.string.groups_nudge_duplicate)
                            GroupNudgeStatus.FORBIDDEN -> context.getString(R.string.groups_nudge_forbidden)
                            GroupNudgeStatus.ERROR -> context.getString(R.string.groups_nudge_error)
                        }
                    }
                    nudgePrompt = null
                }) {
                    Text(stringResource(R.string.groups_nudge))
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
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape),
            contentScale = ContentScale.Crop
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
