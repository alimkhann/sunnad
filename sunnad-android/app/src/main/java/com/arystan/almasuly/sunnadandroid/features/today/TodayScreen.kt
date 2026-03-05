package com.arystan.almasuly.sunnadandroid.features.today

import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.app.ShareCompat
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.features.habits.AddHabitSheet
import com.arystan.almasuly.sunnadandroid.features.habits.HabitDetailSheet
import com.arystan.almasuly.sunnadandroid.features.habits.iconForHabitName
import com.arystan.almasuly.sunnadandroid.features.onboarding.OnboardingTemplateSeed
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
        categoryCustom: String?,
        schedule: com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule,
        isDhikr: Boolean,
        targetCount: Int,
        reminderHour: Int?,
        reminderMinute: Int?
    ) -> Unit,
    onAddTemplates: (List<OnboardingTemplateSeed>) -> Unit,
    onSelectHabit: (java.util.UUID?) -> Unit,
    onSetDhikrCount: (java.util.UUID, Int) -> Unit,
    onSaveHabit: (Habit) -> Unit,
    onDeleteHabit: (java.util.UUID) -> Unit,
    onOpenManageHabits: () -> Unit
) {
    val context = LocalContext.current
    val quoteSourceFallback = stringResource(R.string.today_quote_source_fallback)
    var showAddHabitSheet by remember { mutableStateOf(false) }
    var showCompleted by remember { mutableStateOf(true) }
    var showQuoteSheet by remember { mutableStateOf(false) }

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
                            onLeftClick = onOpenManageHabits,
                            rightIcon = Icons.Rounded.Add,
                            rightContentDescription = stringResource(R.string.today_add_habit),
                            onRightClick = { showAddHabitSheet = true }
                        )
                    }
                }

                item {
                    SunnadCard(
                        modifier = Modifier.clickable(onClick = { showQuoteSheet = true })
                    ) {
                        Text(
                            text = stringResource(R.string.quote_card_title),
                            style = MaterialTheme.typography.labelLarge,
                            color = androidx.compose.ui.graphics.Color(0xFFF6D84A),
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
                        SunnadCard(contentPadding = 0.dp) {
                            pendingHabits.forEachIndexed { index, habit ->
                                HabitRow(
                                    habit = habit,
                                    onToggleHabit = onToggleHabit,
                                    onSelectHabit = onSelectHabit,
                                    isTogglePending = state.pendingHabitToggleIds.contains(habit.id)
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
                            SunnadCard(contentPadding = 0.dp) {
                                completedHabits.forEachIndexed { index, habit ->
                                    HabitRow(
                                        habit = habit,
                                        onToggleHabit = onToggleHabit,
                                        onSelectHabit = onSelectHabit,
                                        isDimmed = true,
                                        isTogglePending = state.pendingHabitToggleIds.contains(habit.id)
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

    if (showAddHabitSheet) {
        AddHabitSheet(
            existingHabits = state.allHabits,
            onDismiss = { showAddHabitSheet = false },
            onAddTemplates = { templates ->
                onAddTemplates(templates)
                showAddHabitSheet = false
            },
            onAddCustomHabit = { name, icon, category, categoryCustom, schedule, isDhikr, targetCount, reminderHour, reminderMinute ->
                onAddHabit(
                    name,
                    icon,
                    category,
                    categoryCustom,
                    schedule,
                    isDhikr,
                    targetCount,
                    reminderHour,
                    reminderMinute
                )
                showAddHabitSheet = false
            }
        )
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
                SunnadCard {
                    Text(
                        text = state.quote?.text ?: stringResource(R.string.today_quote_empty),
                        style = MaterialTheme.typography.bodyLarge
                    )
                    Text(
                        text = "- ${state.quote?.source ?: quoteSourceFallback}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
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
                                .setText("${quote.text}\n\n- ${quote.source ?: quoteSourceFallback}")
                                .startChooser()
                        }
                        showQuoteSheet = false
                    }
                )
                Box(modifier = Modifier.height(8.dp))
            }
        }
    }

    val selectedHabit = state.selectedHabitId?.let { id -> state.allHabits.firstOrNull { it.id == id } }
    val selectedTodayModel = state.selectedHabitId?.let { id -> state.dueHabits.firstOrNull { it.id == id } }
    if (selectedHabit != null) {
        HabitDetailSheet(
            habit = selectedHabit,
            streak = selectedTodayModel?.streak ?: 0,
            completedToday = selectedTodayModel?.completedToday ?: false,
            initialCompletionValue = selectedTodayModel?.dhikrCount ?: 0,
            onDismiss = { onSelectHabit(null) },
            onSaveHabit = onSaveHabit,
            onDeleteHabit = {
                onDeleteHabit(it)
                onSelectHabit(null)
            },
            onSetCompletionValue = { id, value ->
                onSetDhikrCount(id, value)
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
    isDimmed: Boolean = false,
    isTogglePending: Boolean = false
) {
    val completedFill = MaterialTheme.colorScheme.primary
    val incompleteFill = MaterialTheme.colorScheme.surfaceContainerHighest
    SunnadListRow(
        title = habit.title,
        subtitle = stringResource(R.string.today_streak, habit.streak),
        leading = {
            Icon(
                imageVector = iconForHabitName(habit.icon, habit.title),
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
                Box(
                    modifier = Modifier
                        .size(22.dp)
                        .background(
                            color = if (habit.completedToday) completedFill else incompleteFill,
                            shape = CircleShape
                        )
                        .border(
                            width = if (habit.completedToday) 0.dp else 1.dp,
                            color = MaterialTheme.colorScheme.outline.copy(alpha = 0.7f),
                            shape = CircleShape
                        )
                        .clickable(enabled = !isTogglePending) { onToggleHabit(habit.id) },
                    contentAlignment = Alignment.Center
                ) {
                    if (habit.completedToday) {
                        Icon(
                            imageVector = Icons.Rounded.Check,
                            contentDescription = stringResource(R.string.today_toggle_completion),
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.size(13.dp)
                        )
                    }
                }
            }
        },
        onClick = {
            onSelectHabit(habit.id)
        },
        titleColor = if (isDimmed) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
        verticalPadding = 4.dp,
        horizontalPadding = 16.dp,
        minHeight = 42.dp,
        rowAlpha = when {
            isDimmed -> 0.64f
            isTogglePending -> 0.74f
            else -> 1f
        }
    )
}
