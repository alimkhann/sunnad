package com.arystan.almasuly.sunnadandroid.features.habits

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.features.today.TodayHabitUiModel

@Composable
fun DhikrCounterDialog(
    habit: TodayHabitUiModel,
    onDismiss: () -> Unit,
    onSave: (Int) -> Unit,
    onArchive: () -> Unit
) {
    var count by remember(habit.id) { mutableIntStateOf(habit.dhikrCount) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(habit.title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.habit_dhikr_counter))
                Text(stringResource(R.string.habit_dhikr_progress, count, habit.dhikrTarget))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    Button(onClick = { count = (count - 1).coerceAtLeast(0) }, modifier = Modifier.weight(1f)) {
                        Text("-")
                    }
                    Button(onClick = { count = (count + 1).coerceAtMost(habit.dhikrTarget) }, modifier = Modifier.weight(1f)) {
                        Text("+")
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
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = onArchive) {
                    Text(stringResource(R.string.habit_archive))
                }
                TextButton(onClick = { onSave(count) }) {
                    Text(stringResource(R.string.common_save))
                }
            }
        }
    )
}
