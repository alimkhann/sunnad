package com.arystan.almasuly.sunnadandroid.features.habits

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.Weekday

@Composable
fun HabitEditorDialog(
    onDismiss: () -> Unit,
    onCreateHabit: (
        name: String,
        icon: String,
        category: HabitCategoryValue,
        schedule: HabitSchedule,
        isDhikr: Boolean,
        targetCount: Int,
        reminderHour: Int?,
        reminderMinute: Int?
    ) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var icon by remember { mutableStateOf("check_circle") }
    var isDhikr by remember { mutableStateOf(false) }
    var targetCountRaw by remember { mutableStateOf("33") }
    var weekly by remember { mutableStateOf(false) }
    var selectedWeekdays by remember { mutableStateOf(setOf(Weekday.MONDAY, Weekday.WEDNESDAY, Weekday.FRIDAY)) }
    var reminderEnabled by remember { mutableStateOf(false) }
    var reminderHour by remember { mutableIntStateOf(9) }
    var reminderMinute by remember { mutableIntStateOf(0) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.habit_add_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.habit_name)) },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = icon,
                    onValueChange = { icon = it },
                    label = { Text(stringResource(R.string.habit_icon_hint)) },
                    modifier = Modifier.fillMaxWidth()
                )

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.habit_is_dhikr))
                    Checkbox(checked = isDhikr, onCheckedChange = { isDhikr = it })
                }

                if (isDhikr) {
                    OutlinedTextField(
                        value = targetCountRaw,
                        onValueChange = { targetCountRaw = it },
                        label = { Text(stringResource(R.string.habit_target_count)) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.habit_schedule_weekly))
                    Checkbox(checked = weekly, onCheckedChange = { weekly = it })
                }

                if (weekly) {
                    Weekday.entries.forEach { weekday ->
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(weekday.name.lowercase().replaceFirstChar { it.titlecase() })
                            Checkbox(
                                checked = selectedWeekdays.contains(weekday),
                                onCheckedChange = { checked ->
                                    selectedWeekdays = if (checked) {
                                        selectedWeekdays + weekday
                                    } else {
                                        selectedWeekdays - weekday
                                    }
                                }
                            )
                        }
                    }
                }

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(stringResource(R.string.habit_reminder_enabled))
                    Checkbox(checked = reminderEnabled, onCheckedChange = { reminderEnabled = it })
                }

                if (reminderEnabled) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        OutlinedTextField(
                            value = reminderHour.toString(),
                            onValueChange = { reminderHour = it.toIntOrNull()?.coerceIn(0, 23) ?: reminderHour },
                            label = { Text(stringResource(R.string.habit_reminder_hour)) },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = reminderMinute.toString(),
                            onValueChange = { reminderMinute = it.toIntOrNull()?.coerceIn(0, 59) ?: reminderMinute },
                            label = { Text(stringResource(R.string.habit_reminder_minute)) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.common_cancel))
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val schedule = if (weekly) {
                        HabitSchedule.Weekly(selectedWeekdays.ifEmpty { setOf(Weekday.MONDAY) })
                    } else {
                        HabitSchedule.Daily
                    }
                    onCreateHabit(
                        name.trim(),
                        icon.trim().ifEmpty { "check_circle" },
                        HabitCategoryValue.SPIRITUAL,
                        schedule,
                        isDhikr,
                        targetCountRaw.toIntOrNull() ?: 33,
                        if (reminderEnabled) reminderHour else null,
                        if (reminderEnabled) reminderMinute else null
                    )
                },
                enabled = name.isNotBlank()
            ) {
                Text(stringResource(R.string.common_save))
            }
        }
    )
}
