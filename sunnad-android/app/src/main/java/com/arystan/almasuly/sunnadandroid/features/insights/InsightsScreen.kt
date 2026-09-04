package com.arystan.almasuly.sunnadandroid.features.insights

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactBackButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadSectionHeader
import java.time.format.DateTimeFormatter
import java.time.LocalDate
import java.util.Locale
import java.util.UUID
import kotlin.math.max

@Composable
fun InsightsScreen(
    viewModel: InsightsViewModel,
    onClose: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var expandedHabitIds by remember { mutableStateOf(setOf<UUID>()) }
    var selectedPointDate by remember { mutableStateOf<LocalDate?>(null) }

    LaunchedEffect(Unit) {
        viewModel.load()
    }

    LaunchedEffect(state.points) {
        if (state.points.isEmpty()) {
            selectedPointDate = null
        } else if (selectedPointDate == null || state.points.none { it.date == selectedPointDate }) {
            selectedPointDate = state.points.last().date
        }
    }

    SunnadScreenSurface {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = SunnadScreenPadding),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                SunnadCompactBackButton(onClick = onClose)
                Text(
                    text = stringResource(R.string.profile_insights),
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            if (state.isLoading && state.points.isEmpty()) {
                SunnadCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
            } else {
                SunnadSectionHeader(title = stringResource(R.string.insights_completion_trend))
                SunnadCard {
                    Text(
                        text = stringResource(R.string.insights_window_hint),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    key(state.points.map { "${it.date}:${it.completed}:${it.due}" }) {
                        CompletionTrendChart(
                            points = state.points,
                            selectedDate = selectedPointDate,
                            onSelectDate = { selectedPointDate = it }
                        )
                    }
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        LegendItem(color = Color(0xFFF4C430), title = stringResource(R.string.insights_due_label))
                        LegendItem(color = MaterialTheme.colorScheme.primary, title = stringResource(R.string.insights_completed_label))
                    }

                    val selectedPoint = selectedPointDate?.let { selected ->
                        state.points.minByOrNull { point ->
                            kotlin.math.abs(point.date.toEpochDay() - selected.toEpochDay())
                        }
                    }
                    if (selectedPoint != null) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(1.dp)
                                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                        )
                        Text(
                            text = selectedPoint.date.format(DateTimeFormatter.ofPattern("d MMM", Locale.getDefault())),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = "${selectedPoint.completed} of ${selectedPoint.due} completed",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = stringResource(R.string.insights_missed_habits),
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        val missedTitles = viewModel.missedHabitTitles(selectedPoint)
                        if (missedTitles.isEmpty()) {
                            Text(
                                text = stringResource(R.string.insights_none_missed),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        } else {
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                missedTitles.forEach { title ->
                                    Text(
                                        text = "• $title",
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                }
                            }
                        }
                    }
                }

                SunnadSectionHeader(title = stringResource(R.string.insights_habit_performance))
                SunnadCard(contentPadding = 0.dp) {
                    Column {
                        state.habitPerformance.forEachIndexed { index, habit ->
                            Column {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            expandedHabitIds = if (expandedHabitIds.contains(habit.id)) {
                                                expandedHabitIds - habit.id
                                            } else {
                                                expandedHabitIds + habit.id
                                            }
                                        }
                                        .padding(horizontal = 16.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = habit.title,
                                        style = MaterialTheme.typography.titleLarge,
                                        modifier = Modifier.weight(1f)
                                    )
                                    Text(
                                        text = "${habit.percentage}%",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    Icon(
                                        imageVector = if (expandedHabitIds.contains(habit.id)) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.padding(start = 6.dp)
                                    )
                                }

                                if (expandedHabitIds.contains(habit.id)) {
                                    Habit40DayGrid(days = habit.days)
                                }
                            }

                            if (index < state.habitPerformance.lastIndex) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(1.dp)
                                        .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                                )
                            }
                        }
                    }
                }

                if (state.categoryPerformance.isNotEmpty()) {
                    SunnadSectionHeader(title = stringResource(R.string.insights_category_analytics))
                    SunnadCard(contentPadding = 0.dp) {
                        Column {
                            state.categoryPerformance.forEachIndexed { index, item ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 16.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(
                                        modifier = Modifier.weight(1f),
                                        verticalArrangement = Arrangement.spacedBy(4.dp)
                                    ) {
                                        Text(
                                            text = categoryDisplayTitle(item),
                                            style = MaterialTheme.typography.titleMedium
                                        )
                                        Text(
                                            text = stringResource(
                                                R.string.insights_category_completed_ratio,
                                                item.completed,
                                                item.total
                                            ),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                        CategoryCompletionBar(percentage = item.percentage)
                                    }
                                    Text(
                                        text = "${item.percentage}%",
                                        style = MaterialTheme.typography.titleSmall,
                                        fontWeight = FontWeight.SemiBold,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }

                                if (index < state.categoryPerformance.lastIndex) {
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(1.dp)
                                            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                                    )
                                }
                            }
                        }
                    }
                }
            }

            state.errorMessage?.let { message ->
                SunnadCard {
                    Text(
                        text = message,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }
    }
}

@Composable
private fun CategoryCompletionBar(percentage: Int) {
    val clamped = percentage.coerceIn(0, 100) / 100f
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(7.dp)
            .background(
                color = MaterialTheme.colorScheme.surfaceContainerHighest,
                shape = RoundedCornerShape(999.dp)
            )
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(clamped)
                .height(7.dp)
                .background(
                    brush = Brush.horizontalGradient(
                        colors = listOf(
                            MaterialTheme.colorScheme.primary,
                            Color(0xFFF4C430)
                        )
                    ),
                    shape = RoundedCornerShape(999.dp)
                )
        )
    }
}

@Composable
private fun categoryDisplayTitle(item: CategoryPerformanceUi): String {
    val custom = item.customLabel?.trim().orEmpty()
    if (custom.isNotEmpty()) return custom
    return when (item.category ?: HabitCategoryValue.SPIRITUAL) {
        HabitCategoryValue.SPIRITUAL -> stringResource(R.string.onboarding_category_spiritual)
        HabitCategoryValue.PHYSICAL -> stringResource(R.string.onboarding_category_physical)
        HabitCategoryValue.SOCIAL -> stringResource(R.string.onboarding_category_social)
        HabitCategoryValue.FINANCIAL -> stringResource(R.string.onboarding_category_financial)
        HabitCategoryValue.LEARNING -> stringResource(R.string.onboarding_category_learning)
        HabitCategoryValue.FAMILY -> stringResource(R.string.onboarding_category_family)
        HabitCategoryValue.WORK -> stringResource(R.string.onboarding_category_work)
        HabitCategoryValue.HOBBY -> stringResource(R.string.onboarding_category_hobby)
    }
}

@Composable
private fun CompletionTrendChart(
    points: List<InsightsPointUi>,
    selectedDate: LocalDate?,
    onSelectDate: (LocalDate?) -> Unit
) {
    val scroll = rememberScrollState()
    var didAutoScrollToLatest by remember(points) { mutableStateOf(false) }
    val chartScaleMax = remember(points) {
        points.maxOfOrNull { max(it.due, it.completed) }?.coerceAtLeast(1) ?: 1
    }
    val chartHeight = 158.dp
    val slotWidth = 46.dp
    val completedColor = MaterialTheme.colorScheme.primary
    val dueColor = Color(0xFFF4C430)
    val selectedIndex = selectedDate?.let { selected ->
        points.indexOfFirst { it.date == selected }.takeIf { it != -1 }
    }
    val latestIndex = points.lastIndex

    LaunchedEffect(points.size, scroll.maxValue) {
        if (!didAutoScrollToLatest && points.isNotEmpty() && scroll.maxValue > 0) {
            repeat(3) {
                scroll.scrollTo(scroll.maxValue)
                withFrameNanos { }
            }
            didAutoScrollToLatest = true
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(scroll),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            val formatter = remember { DateTimeFormatter.ofPattern("d MMM", Locale.getDefault()) }
            points.forEachIndexed { index, point ->
                val isSelected = index == selectedIndex
                val dueHeight = if (point.due > 0) {
                    (chartHeight * (point.due.toFloat() / chartScaleMax.toFloat())).coerceAtLeast(6.dp)
                } else {
                    0.dp
                }
                val completedHeight = if (point.completed > 0) {
                    (chartHeight * (point.completed.toFloat() / chartScaleMax.toFloat())).coerceAtLeast(6.dp)
                } else {
                    0.dp
                }
                val showCompletedMarker = point.completed > 0 && (isSelected || index == latestIndex)

                Column(
                    modifier = Modifier
                        .width(slotWidth)
                        .clickable { onSelectDate(point.date) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(chartHeight + 18.dp)
                            .background(
                                color = if (isSelected) {
                                    MaterialTheme.colorScheme.surfaceContainerHighest.copy(alpha = 0.55f)
                                } else {
                                    Color.Transparent
                                },
                                shape = RoundedCornerShape(10.dp)
                            )
                            .padding(horizontal = 8.dp, vertical = 8.dp),
                        contentAlignment = Alignment.BottomCenter
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.Bottom
                        ) {
                            TrendBar(
                                height = dueHeight,
                                color = dueColor.copy(alpha = 0.5f)
                            )
                            TrendBar(
                                height = completedHeight,
                                color = completedColor,
                                showMarker = showCompletedMarker
                            )
                        }
                    }
                    Text(
                        text = point.date.format(formatter),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun TrendBar(
    height: Dp,
    color: Color,
    showMarker: Boolean = false
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        if (showMarker) {
            Box(
                modifier = Modifier
                    .size(4.dp)
                    .background(color, RoundedCornerShape(999.dp))
            )
        }
        Box(
            modifier = Modifier
                .width(11.dp)
                .height(height)
                .background(color, RoundedCornerShape(topStart = 999.dp, topEnd = 999.dp))
        )
    }
}

@Composable
private fun LegendItem(color: Color, title: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .background(color, RoundedCornerShape(999.dp))
        )
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun Habit40DayGrid(days: List<HabitDayUi>) {
    Text(
        text = stringResource(R.string.insights_last_40_days),
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 16.dp, top = 2.dp, bottom = 8.dp)
    )

    val columns = 7
    val rows = (days.size + columns - 1) / columns
    Column(
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        repeat(rows) { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                repeat(columns) { column ->
                    val index = row * columns + column
                    val cell = days.getOrNull(index)
                    val color = when {
                        cell == null -> Color.Transparent
                        !cell.scheduled -> MaterialTheme.colorScheme.surfaceContainerHigh
                        cell.completed -> MaterialTheme.colorScheme.primary
                        else -> MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.95f)
                    }
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .background(color, RoundedCornerShape(3.dp))
                            .border(
                                width = 0.5.dp,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f),
                                shape = RoundedCornerShape(3.dp)
                            )
                    )
                }
            }
        }
    }
}
