package com.arystan.almasuly.sunnadandroid.features.insights

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.features.today.TodayHabitUiModel
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import androidx.compose.ui.res.stringResource
import java.util.Locale

@Composable
fun InsightsScreen(
    habits: List<Habit>,
    dueHabits: List<TodayHabitUiModel>,
    onClose: () -> Unit
) {
    val total = habits.size
    val due = dueHabits.size
    val completed = dueHabits.count { it.completedToday }
    val completionRate = if (due == 0) 0 else (completed * 100) / due
    val dhikrCount = habits.count { it.isDhikr }
    val longestStreak = dueHabits.maxOfOrNull { it.streak } ?: 0

    SunnadScreenSurface {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SunnadScreenPadding),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(R.string.profile_insights),
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold
                    )
                    IconButton(onClick = onClose) {
                        Icon(
                            imageVector = Icons.Rounded.Close,
                            contentDescription = stringResource(R.string.common_close)
                        )
                    }
                }
            }

            item {
                SunnadCard {
                    Text(
                        text = stringResource(R.string.insights_today_performance),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = String.format(Locale.US, stringResource(R.string.insights_percent_complete), completionRate),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = stringResource(R.string.insights_due_done, completed, due),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            item {
                SunnadCard {
                    Text(
                        text = stringResource(R.string.insights_habit_breakdown),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    MetricRow(stringResource(R.string.insights_total_habits), total.toString())
                    MetricRow(stringResource(R.string.insights_dhikr_habits), dhikrCount.toString())
                    MetricRow(stringResource(R.string.insights_longest_streak), stringResource(R.string.insights_days_short, longestStreak))
                }
            }

            item {
                SunnadCard {
                    Text(
                        text = stringResource(id = R.string.today_progress, completed, due),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Medium
                    )
                    Box(modifier = Modifier.fillMaxWidth().padding(top = 4.dp)) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(8.dp)
                                .clip(androidx.compose.foundation.shape.RoundedCornerShape(999.dp))
                                .align(Alignment.CenterStart)
                                .background(MaterialTheme.colorScheme.surfaceContainerHighest)
                        )
                        Box(
                            modifier = Modifier
                                .fillMaxWidth((completionRate / 100f).coerceIn(0f, 1f))
                                .height(8.dp)
                                .clip(androidx.compose.foundation.shape.RoundedCornerShape(999.dp))
                                .align(Alignment.CenterStart)
                                .background(MaterialTheme.colorScheme.primary)
                        )
                    }
                }
            }

            item { Box(modifier = Modifier.height(72.dp)) }
        }
    }
}

@Composable
private fun MetricRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold
        )
    }
}
