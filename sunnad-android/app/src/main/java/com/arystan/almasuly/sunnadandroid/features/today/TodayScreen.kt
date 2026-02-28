package com.arystan.almasuly.sunnadandroid.features.today

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
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Done
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.SelfImprovement
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.app.ShareCompat
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.features.habits.DhikrCounterDialog
import com.arystan.almasuly.sunnadandroid.features.habits.HabitEditorDialog
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadActionCapsule
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadListRow
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadSectionHeader

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayScreen(
    state: TodayUiState,
    onRefresh: () -> Unit,
    onToggleHabit: (java.util.UUID) -> Unit,
    onSaveQuote: () -> Unit,
    onAddHabit: (
        name: String,
        icon: String,
        category: com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue,
        schedule: com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule,
        isDhikr: Boolean,
        targetCount: Int,
        reminderHour: Int?,
        reminderMinute: Int?
    ) -> Unit,
    onSelectHabit: (java.util.UUID?) -> Unit,
    onSetDhikrCount: (java.util.UUID, Int) -> Unit,
    onArchiveHabit: (java.util.UUID) -> Unit,
    onOpenManageHabits: () -> Unit
) {
    val context = LocalContext.current
    var showEditor by remember { mutableStateOf(false) }
    var showCompleted by remember { mutableStateOf(true) }
    var showQuoteSheet by remember { mutableStateOf(false) }
    var showManageSheet by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { onRefresh() }

    val pendingHabits = remember(state.dueHabits) { state.dueHabits.filterNot { it.completedToday } }
    val completedHabits = remember(state.dueHabits) { state.dueHabits.filter { it.completedToday } }

    SunnadScreenSurface {
        if (state.isLoading) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 56.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
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
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = stringResource(R.string.tab_today),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold
                        )
                        SunnadActionCapsule(
                            leftIcon = Icons.Rounded.CalendarMonth,
                            leftContentDescription = stringResource(R.string.today_manage_habits),
                            onLeftClick = {
                                onOpenManageHabits()
                                showManageSheet = true
                            },
                            rightIcon = Icons.Rounded.Add,
                            rightContentDescription = stringResource(R.string.today_add_habit),
                            onRightClick = { showEditor = true }
                        )
                    }
                }

                item {
                    SunnadCard {
                        Text(
                            text = stringResource(R.string.quote_card_title),
                            style = MaterialTheme.typography.labelLarge,
                            color = Color(0xFFF6D84A),
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = state.quote?.text ?: stringResource(R.string.today_quote_empty),
                            style = MaterialTheme.typography.bodyLarge
                        )
                        Text(
                            text = "- ${state.quote?.source ?: stringResource(R.string.today_quote_source_fallback)}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        SecondaryPillButton(
                            title = if (state.isQuoteSaved) {
                                stringResource(R.string.today_quote_saved)
                            } else {
                                stringResource(R.string.today_quote_actions)
                            },
                            onClick = { showQuoteSheet = true }
                        )
                    }
                }

                item {
                    Text(
                        text = stringResource(R.string.today_progress, completedHabits.size, state.dueHabits.size),
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                if (state.dueHabits.isEmpty()) {
                    item {
                        SunnadCard {
                            Text(
                                text = if (state.allHabits.isEmpty()) {
                                    stringResource(R.string.today_empty_title)
                                } else {
                                    stringResource(R.string.today_none_due_title)
                                },
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = if (state.allHabits.isEmpty()) {
                                    stringResource(R.string.today_empty_subtitle)
                                } else {
                                    stringResource(R.string.today_none_due_subtitle)
                                },
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                } else if (pendingHabits.isEmpty()) {
                    item {
                        SunnadCard {
                            Text(
                                text = stringResource(R.string.today_all_done_title),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = stringResource(R.string.today_all_done_subtitle),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                } else {
                    item {
                        SunnadCard(contentPadding = 10.dp) {
                            pendingHabits.forEachIndexed { index, habit ->
                                HabitRow(
                                    habit = habit,
                                    onToggleHabit = onToggleHabit,
                                    onSelectHabit = onSelectHabit
                                )
                                if (index < pendingHabits.lastIndex) {
                                    Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                                }
                            }
                        }
                    }
                }

                if (completedHabits.isNotEmpty()) {
                    item {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            SunnadSectionHeader(
                                title = stringResource(R.string.today_completed_section)
                            )
                            IconButton(onClick = { showCompleted = !showCompleted }) {
                                Icon(
                                    imageVector = if (showCompleted) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
                                    contentDescription = stringResource(R.string.today_completed_toggle)
                                )
                            }
                        }
                    }

                    if (showCompleted) {
                        item {
                            SunnadCard(contentPadding = 10.dp) {
                                completedHabits.forEachIndexed { index, habit ->
                                    HabitRow(
                                        habit = habit,
                                        onToggleHabit = onToggleHabit,
                                        onSelectHabit = onSelectHabit,
                                        isDimmed = true
                                    )
                                    if (index < completedHabits.lastIndex) {
                                        Divider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f))
                                    }
                                }
                            }
                        }
                    }
                }
                item {
                    Box(modifier = Modifier.height(96.dp))
                }
            }
        }
    }

    if (showEditor) {
        HabitEditorDialog(
            onDismiss = { showEditor = false },
            onCreateHabit = { name, icon, category, schedule, isDhikr, target, hour, minute ->
                onAddHabit(name, icon, category, schedule, isDhikr, target, hour, minute)
                showEditor = false
            }
        )
    }

    if (showManageSheet) {
        ModalBottomSheet(onDismissRequest = { showManageSheet = false }) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SunnadScreenPadding, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = stringResource(R.string.today_manage_habits),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold
                )
                if (state.allHabits.isEmpty()) {
                    Text(
                        text = stringResource(R.string.today_empty_subtitle),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    state.allHabits.forEach { habit ->
                        SunnadCard(contentPadding = 10.dp) {
                            Text(
                                text = habit.name,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = scheduleLabel(habit),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                PrimaryPillButton(
                    title = stringResource(R.string.today_add_habit),
                    onClick = {
                        showManageSheet = false
                        showEditor = true
                    }
                )
                Box(modifier = Modifier.height(8.dp))
            }
        }
    }

    if (showQuoteSheet) {
        ModalBottomSheet(onDismissRequest = { showQuoteSheet = false }) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SunnadScreenPadding, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(
                    text = stringResource(R.string.quote_card_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                PrimaryPillButton(
                    title = if (state.isQuoteSaved) stringResource(R.string.today_quote_saved) else stringResource(R.string.today_quote_save),
                    enabled = !state.isQuoteSaved,
                    onClick = {
                        onSaveQuote()
                        showQuoteSheet = false
                    }
                )
                SecondaryPillButton(
                    title = stringResource(R.string.today_quote_share),
                    onClick = {
                        val quote = state.quote
                        if (quote != null) {
                            ShareCompat.IntentBuilder(context)
                                .setType("text/plain")
                                .setText("${quote.text}\n\n- ${quote.source ?: "Sunnad"}")
                                .startChooser()
                        }
                        showQuoteSheet = false
                    }
                )
                Box(modifier = Modifier.height(8.dp))
            }
        }
    }

    val selected = state.selectedHabitId?.let { id -> state.dueHabits.firstOrNull { it.id == id } }
    if (selected != null && selected.isDhikr) {
        DhikrCounterDialog(
            habit = selected,
            onDismiss = { onSelectHabit(null) },
            onSave = {
                onSetDhikrCount(selected.id, it)
                onSelectHabit(null)
            },
            onArchive = {
                onArchiveHabit(selected.id)
                onSelectHabit(null)
            }
        )
    }

    state.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = onRefresh,
            title = { Text(stringResource(R.string.common_error)) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = onRefresh) {
                    Text(stringResource(R.string.common_retry))
                }
            }
        )
    }
}

@Composable
private fun HabitRow(
    habit: TodayHabitUiModel,
    onToggleHabit: (java.util.UUID) -> Unit,
    onSelectHabit: (java.util.UUID?) -> Unit,
    isDimmed: Boolean = false
) {
    val subtitle = if (habit.isDhikr) {
        stringResource(R.string.habit_dhikr_progress, habit.dhikrCount, habit.dhikrTarget)
    } else {
        stringResource(R.string.today_streak, habit.streak)
    }
    val rowSubtitle = if (!habit.isDhikr && habit.streak <= 0) null else subtitle

    SunnadListRow(
        title = habit.title,
        subtitle = rowSubtitle,
        leading = {
            Icon(
                imageVector = iconForHabit(habit.icon, habit.title),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        },
        trailing = {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(
                    imageVector = Icons.Rounded.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                IconButton(onClick = { onToggleHabit(habit.id) }) {
                    Icon(
                        imageVector = if (habit.completedToday) Icons.Rounded.Done else Icons.Rounded.RadioButtonUnchecked,
                        contentDescription = stringResource(R.string.today_toggle_completion),
                        tint = if (habit.completedToday) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline
                    )
                }
            }
        },
        onClick = {
            if (habit.isDhikr) {
                onSelectHabit(habit.id)
            } else {
                onToggleHabit(habit.id)
            }
        },
        titleColor = if (isDimmed) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
        subtitleColor = if (isDimmed) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.onSurfaceVariant
    )
}

private fun iconForHabit(iconName: String, title: String) = when {
    iconName.contains("menu_book", ignoreCase = true) -> Icons.Rounded.MenuBook
    iconName.contains("group", ignoreCase = true) -> Icons.Rounded.Groups
    iconName.contains("fitness", ignoreCase = true) -> Icons.Rounded.SelfImprovement
    iconName.contains("sun", ignoreCase = true) -> Icons.Rounded.WbSunny
    iconName.contains("bed", ignoreCase = true) -> Icons.Rounded.Bedtime
    iconName.contains("self", ignoreCase = true) -> Icons.Rounded.SelfImprovement
    title.contains("quran", ignoreCase = true) -> Icons.Rounded.MenuBook
    title.contains("parent", ignoreCase = true) -> Icons.Rounded.Groups
    title.contains("exercise", ignoreCase = true) -> Icons.Rounded.SelfImprovement
    title.contains("morning", ignoreCase = true) -> Icons.Rounded.WbSunny
    title.contains("evening", ignoreCase = true) -> Icons.Rounded.Bedtime
    title.contains("dhikr", ignoreCase = true) -> Icons.Rounded.SelfImprovement
    else -> Icons.Rounded.SelfImprovement
}

@Composable
private fun scheduleLabel(habit: Habit): String {
    return when (val schedule = habit.schedule) {
        HabitSchedule.Daily -> stringResource(R.string.habit_schedule_daily)
        is HabitSchedule.Weekly -> {
            val days = schedule.weekdays.sortedBy { it.ordinal }.joinToString(", ") { it.name.take(3) }
            stringResource(R.string.habit_schedule_weekly_label, days)
        }
    }
}
