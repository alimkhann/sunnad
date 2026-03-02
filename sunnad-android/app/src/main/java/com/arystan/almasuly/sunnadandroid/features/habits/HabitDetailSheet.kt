package com.arystan.almasuly.sunnadandroid.features.habits

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.HabitReminder
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.HabitType
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactCloseButton
import java.time.LocalDateTime
import java.util.UUID

private enum class HabitDetailTab {
    DETAILS,
    COUNTER
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HabitDetailSheet(
    habit: Habit,
    streak: Int,
    completedToday: Boolean,
    initialCompletionValue: Int,
    onDismiss: () -> Unit,
    onSaveHabit: (Habit) -> Unit,
    onDeleteHabit: (UUID) -> Unit,
    onSetCompletionValue: (UUID, Int) -> Unit
) {
    var selectedTab by rememberSaveable(habit.id) {
        mutableStateOf(if (habit.isDhikr) HabitDetailTab.COUNTER else HabitDetailTab.DETAILS)
    }

    var name by rememberSaveable(habit.id) { mutableStateOf(habit.name) }
    var iconName by rememberSaveable(habit.id) { mutableStateOf(habit.icon) }
    var category by rememberSaveable(habit.id) { mutableStateOf(habit.category) }
    var weeklySchedule by rememberSaveable(habit.id) { mutableStateOf(habit.schedule is HabitSchedule.Weekly) }
    var selectedWeekdays by rememberSaveable(habit.id) {
        mutableStateOf((habit.schedule as? HabitSchedule.Weekly)?.weekdays ?: mondayFirstWeekdays.toSet())
    }
    var reminderEnabled by rememberSaveable(habit.id) { mutableStateOf(habit.reminder != null) }
    var reminderHour by rememberSaveable(habit.id) { mutableStateOf((habit.reminder?.normalizedHour ?: 9).toString().padStart(2, '0')) }
    var reminderMinute by rememberSaveable(habit.id) { mutableStateOf((habit.reminder?.normalizedMinute ?: 0).toString().padStart(2, '0')) }

    var categoryMenuExpanded by remember { mutableStateOf(false) }

    var selectedDhikrKey by rememberSaveable(habit.id) { mutableStateOf(habit.selectedDhikrKey) }
    var dhikrCounts by rememberSaveable(habit.id) { mutableStateOf(habit.dhikrCountsByKey) }
    var counterValue by rememberSaveable(habit.id) { mutableIntStateOf(initialCompletionValue.coerceAtLeast(0)) }
    var targetValue by rememberSaveable(habit.id) { mutableIntStateOf(habit.normalizedTargetCount.coerceAtLeast(1)) }

    val dhikrKeys = remember {
        listOf(
            "dhikr.choice.subhanallah",
            "dhikr.choice.alhamdulillah",
            "dhikr.choice.allahu_akbar"
        )
    }

    fun persistDetailsAndDismiss() {
        val updated = habit
            .copy(
                name = name.trim().ifBlank { habit.name },
                icon = iconName,
                category = category,
                schedule = if (weeklySchedule) {
                    HabitSchedule.Weekly(selectedWeekdays.ifEmpty { setOf(Weekday.MONDAY) })
                } else {
                    HabitSchedule.Daily
                },
                type = if (habit.isDhikr) HabitType.DHIKR else HabitType.BINARY,
                targetCount = if (habit.isDhikr) targetValue.coerceAtLeast(1) else null,
                reminder = if (reminderEnabled) {
                    HabitReminder(
                        reminderHour.toIntOrNull()?.coerceIn(0, 23) ?: 9,
                        reminderMinute.toIntOrNull()?.coerceIn(0, 59) ?: 0
                    )
                } else {
                    null
                },
                selectedDhikrKey = if (habit.isDhikr) selectedDhikrKey else habit.selectedDhikrKey,
                dhikrCountsByKey = if (habit.isDhikr) dhikrCounts else habit.dhikrCountsByKey,
                updatedAt = LocalDateTime.now()
            )
        onSaveHabit(updated)
        if (habit.isDhikr) {
            onSetCompletionValue(habit.id, counterValue.coerceIn(0, targetValue))
        }
        onDismiss()
    }

    ModalBottomSheet(onDismissRequest = { persistDetailsAndDismiss() }) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        ) {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(38.dp)
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh, CircleShape)
                            .clickable {
                                onDeleteHabit(habit.id)
                                onDismiss()
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Delete,
                            contentDescription = null,
                            tint = Color(0xFFFF4D5A)
                        )
                    }

                    Text(
                        text = habit.name,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 10.dp)
                    )

                    SunnadCompactCloseButton(onClick = { persistDetailsAndDismiss() })
                }
            }

            if (habit.isDhikr) {
                item {
                    TabRow(selectedTabIndex = if (selectedTab == HabitDetailTab.DETAILS) 0 else 1) {
                        Tab(
                            selected = selectedTab == HabitDetailTab.DETAILS,
                            onClick = { selectedTab = HabitDetailTab.DETAILS },
                            text = { Text(stringResource(R.string.habit_details)) }
                        )
                        Tab(
                            selected = selectedTab == HabitDetailTab.COUNTER,
                            onClick = { selectedTab = HabitDetailTab.COUNTER },
                            text = { Text(stringResource(R.string.habit_counter)) }
                        )
                    }
                }
            }

            if (!habit.isDhikr || selectedTab == HabitDetailTab.DETAILS) {
                item {
                    Text(
                        text = stringResource(R.string.habit_last_7_days).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.SemiBold
                    )
                    SunnadCard {
                        Last7DaysRow(streak = streak, completedToday = completedToday)
                    }
                }

                item {
                    Text(
                        text = stringResource(R.string.habit_name).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.SemiBold
                    )
                    SunnadCard(contentPadding = 0.dp) {
                        TextField(
                            value = name,
                            onValueChange = { name = it },
                            singleLine = true,
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
                    }
                }

                item {
                    Text(
                        text = stringResource(R.string.habit_category).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.SemiBold
                    )
                    SunnadCard(contentPadding = 0.dp) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { categoryMenuExpanded = true }
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = stringResource(R.string.habit_category),
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Medium
                            )
                            Spacer(modifier = Modifier.weight(1f))
                            Text(
                                text = stringResource(categoryTitleRes(category)),
                                color = MaterialTheme.colorScheme.primary,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                        DropdownMenu(
                            expanded = categoryMenuExpanded,
                            onDismissRequest = { categoryMenuExpanded = false }
                        ) {
                            HabitCategoryValue.entries.forEach { option ->
                                DropdownMenuItem(
                                    text = { Text(stringResource(categoryTitleRes(option))) },
                                    onClick = {
                                        category = option
                                        categoryMenuExpanded = false
                                    }
                                )
                            }
                        }
                    }
                }

                item {
                    Text(
                        text = stringResource(R.string.habit_icon).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.SemiBold
                    )
                    SunnadCard {
                        IconPickerRow(selectedIcon = iconName, onSelect = { iconName = it })
                    }
                }

                item {
                    Text(
                        text = stringResource(R.string.habit_schedule).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.SemiBold
                    )
                    SunnadCard(contentPadding = 0.dp) {
                        Column {
                            ScheduleOptionRow(
                                title = stringResource(R.string.habit_schedule_daily),
                                selected = !weeklySchedule,
                                onClick = { weeklySchedule = false }
                            )
                            DividerLine()
                            ScheduleOptionRow(
                                title = stringResource(R.string.habit_schedule_weekly),
                                selected = weeklySchedule,
                                onClick = { weeklySchedule = true }
                            )
                            if (weeklySchedule) {
                                WeekdaySelectorRow(
                                    selectedWeekdays = selectedWeekdays,
                                    onToggle = { day ->
                                        selectedWeekdays = if (selectedWeekdays.contains(day)) {
                                            selectedWeekdays - day
                                        } else {
                                            selectedWeekdays + day
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                item {
                    Text(
                        text = stringResource(R.string.habit_reminder).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontWeight = FontWeight.SemiBold
                    )
                    SunnadCard {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = stringResource(R.string.habit_reminder),
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.Medium,
                                modifier = Modifier.weight(1f)
                            )
                            Switch(checked = reminderEnabled, onCheckedChange = { reminderEnabled = it })
                        }
                        if (reminderEnabled) {
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                TextField(
                                    value = reminderHour,
                                    onValueChange = { reminderHour = it.filter(Char::isDigit).take(2) },
                                    singleLine = true,
                                    label = { Text(stringResource(R.string.habit_reminder_hour)) },
                                    modifier = Modifier.weight(1f)
                                )
                                TextField(
                                    value = reminderMinute,
                                    onValueChange = { reminderMinute = it.filter(Char::isDigit).take(2) },
                                    singleLine = true,
                                    label = { Text(stringResource(R.string.habit_reminder_minute)) },
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }
                    }
                }

            } else {
                item {
                    SunnadCard {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            dhikrKeys.forEach { key ->
                                val selected = selectedDhikrKey == key
                                Box(
                                    modifier = Modifier
                                        .background(
                                            color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest,
                                            shape = RoundedCornerShape(999.dp)
                                        )
                                        .clickable {
                                            val previousCounts = dhikrCounts.toMutableMap()
                                            previousCounts[selectedDhikrKey] = counterValue
                                            selectedDhikrKey = key
                                            counterValue = previousCounts[key] ?: 0
                                            dhikrCounts = previousCounts
                                        }
                                        .padding(horizontal = 14.dp, vertical = 10.dp)
                                ) {
                                    Text(
                                        text = stringResource(
                                            when (key) {
                                                "dhikr.choice.subhanallah" -> R.string.dhikr_choice_subhanallah
                                                "dhikr.choice.alhamdulillah" -> R.string.dhikr_choice_alhamdulillah
                                                else -> R.string.dhikr_choice_allahu_akbar
                                            }
                                        ),
                                        style = MaterialTheme.typography.labelLarge,
                                        fontWeight = FontWeight.SemiBold,
                                        color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
                                    )
                                }
                            }
                        }

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 10.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(252.dp)
                                    .background(MaterialTheme.colorScheme.surfaceContainerHighest, CircleShape)
                                    .clickable {
                                        counterValue = (counterValue + 1).coerceAtMost(targetValue)
                                        dhikrCounts = dhikrCounts + (selectedDhikrKey to counterValue)
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(
                                        text = "$counterValue",
                                        style = MaterialTheme.typography.displayLarge,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = stringResource(R.string.habit_dhikr_of_target, targetValue),
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }

                        PrimaryPillButton(
                            title = stringResource(R.string.dhikr_tap_to_count),
                            onClick = {
                                counterValue = (counterValue + 1).coerceAtMost(targetValue)
                                dhikrCounts = dhikrCounts + (selectedDhikrKey to counterValue)
                            }
                        )

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(14.dp))
                                    .clickable {
                                        counterValue = 0
                                        dhikrCounts = dhikrCounts + (selectedDhikrKey to 0)
                                    }
                                    .padding(vertical = 14.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = stringResource(R.string.dhikr_reset),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }

                            Row(
                                modifier = Modifier
                                    .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(14.dp))
                                    .padding(horizontal = 8.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = stringResource(R.string.dhikr_target),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold
                                )
                                Box(
                                    modifier = Modifier
                                        .size(30.dp)
                                        .background(MaterialTheme.colorScheme.surfaceContainerHighest, CircleShape)
                                        .clickable {
                                            targetValue = (targetValue - 1).coerceAtLeast(1)
                                            counterValue = counterValue.coerceAtMost(targetValue)
                                        },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Rounded.Remove,
                                        contentDescription = null
                                    )
                                }
                                Text(
                                    text = "$targetValue",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold
                                )
                                Box(
                                    modifier = Modifier
                                        .size(30.dp)
                                        .background(MaterialTheme.colorScheme.surfaceContainerHighest, CircleShape)
                                        .clickable {
                                            targetValue = (targetValue + 1).coerceAtMost(999)
                                        },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Rounded.Add,
                                        contentDescription = null
                                    )
                                }
                            }
                        }
                    }
                }
                item {
                    Spacer(modifier = Modifier.height(10.dp))
                }
            }
            }
            if (!habit.isDhikr || selectedTab == HabitDetailTab.DETAILS) {
                PrimaryPillButton(
                    title = stringResource(R.string.habit_save_changes),
                    modifier = Modifier
                        .padding(top = 10.dp, bottom = 10.dp)
                        .navigationBarsPadding()
                        .imePadding(),
                    onClick = { persistDetailsAndDismiss() }
                )
            } else {
                Spacer(
                    modifier = Modifier
                        .height(10.dp)
                        .navigationBarsPadding()
                )
            }
        }
    }
}

@Composable
private fun Last7DaysRow(streak: Int, completedToday: Boolean) {
    val priorStreak = if (completedToday) (streak - 1).coerceAtLeast(0) else streak
    val priorDays = priorStreak.coerceAtMost(6)
    val marks = List(6) { index -> index >= (6 - priorDays) } + completedToday
    val labels = listOf("M", "T", "W", "T", "F", "S", "S")

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        marks.forEachIndexed { index, checked ->
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.weight(1f)) {
                Box(
                    modifier = Modifier
                        .size(30.dp)
                        .background(
                            color = if (checked) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest,
                            shape = RoundedCornerShape(8.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (checked) {
                        Icon(
                            imageVector = Icons.Rounded.Check,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
                Text(
                    text = labels[index],
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun DividerLine() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
    )
}
