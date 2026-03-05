package com.arystan.almasuly.sunnadandroid.features.insights

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
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
import kotlin.math.roundToInt

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
                    CompletionTrendChart(
                        points = state.points,
                        selectedDate = selectedPointDate,
                        onSelectDate = { selectedPointDate = it }
                    )
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
    val maxDue = remember(points) { max(1, points.maxOfOrNull { it.due } ?: 1) }
    val chartWidth = maxOf(340.dp, (points.size * 42).dp)
    val gridColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f)
    val completedColor = MaterialTheme.colorScheme.primary
    val completedLineShadowColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.35f)
    val dueColor = Color(0xFFF4C430)
    val selectedLineColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.35f)
    val selectedIndex = selectedDate?.let { selected ->
        points.indexOfFirst { it.date == selected }.takeIf { it != -1 }
    }

    LaunchedEffect(points.size, scroll.maxValue) {
        if (!didAutoScrollToLatest && points.isNotEmpty() && scroll.maxValue > 0) {
            scroll.scrollTo(scroll.maxValue)
            didAutoScrollToLatest = true
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .horizontalScroll(scroll)
        ) {
            Canvas(
                modifier = Modifier
                    .height(190.dp)
                    .size(width = chartWidth, height = 190.dp)
                    .pointerInput(points, scroll.value) {
                        detectTapGestures { tapOffset ->
                            if (points.isEmpty()) return@detectTapGestures
                            val horizontalInset = 12.dp.toPx()
                            val chartWidth = size.width.toFloat() - horizontalInset * 2f
                            val stepX = if (points.size <= 1) 1f else chartWidth / (points.size - 1).toFloat()
                            val absoluteX = tapOffset.x + scroll.value.toFloat()
                            val normalized = (absoluteX - horizontalInset).coerceIn(0f, chartWidth)
                            val index = (normalized / stepX).roundToInt().coerceIn(0, points.lastIndex)
                            onSelectDate(points[index].date)
                        }
                    }
            ) {
                if (points.isEmpty()) return@Canvas

                val verticalPadding = 18.dp.toPx()
                val horizontalInset = 12.dp.toPx()
                val chartHeight = size.height - verticalPadding * 2f
                val chartWidthPx = size.width - horizontalInset * 2f
                val stepX = if (points.size <= 1) 0f else chartWidthPx / (points.size - 1)
                val baselineY = size.height - verticalPadding
                val minCompletedVisualRatio = 0.035f

                repeat(5) { index ->
                    val y = verticalPadding + chartHeight * (index / 4f)
                    drawLine(
                        color = gridColor,
                        start = Offset(horizontalInset, y),
                        end = Offset(size.width - horizontalInset, y),
                        strokeWidth = 1.dp.toPx()
                    )
                }

                val duePoints = points.mapIndexed { index, point ->
                    val normalized = point.due.toFloat() / maxDue.toFloat()
                    Offset(
                        x = horizontalInset + stepX * index,
                        y = verticalPadding + chartHeight * (1f - normalized)
                    )
                }
                val completedPoints = points.mapIndexed { index, point ->
                    val rawNormalized = point.completed.toFloat() / maxDue.toFloat()
                    val normalized = if (point.completed > 0) {
                        max(rawNormalized, minCompletedVisualRatio)
                    } else {
                        0f
                    }
                    Offset(
                        x = horizontalInset + stepX * index,
                        y = verticalPadding + chartHeight * (1f - normalized)
                    )
                }

                val dueLinePath = smoothPath(duePoints)
                val completedLinePath = smoothPath(completedPoints)
                val completedAreaPath = areaToBaselinePath(completedPoints, baselineY)
                val dueMinusCompletedAreaPath = areaBetweenPathsPath(duePoints, completedPoints)

                drawPath(
                    path = completedAreaPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(completedColor.copy(alpha = 0.28f), completedColor.copy(alpha = 0.02f)),
                        startY = verticalPadding,
                        endY = baselineY
                    )
                )

                drawPath(
                    path = dueMinusCompletedAreaPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(dueColor.copy(alpha = 0.24f), dueColor.copy(alpha = 0.04f)),
                        startY = verticalPadding,
                        endY = baselineY
                    )
                )

                drawPath(
                    path = dueLinePath,
                    color = dueColor,
                    style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
                )
                drawPath(
                    path = completedLinePath,
                    color = completedLineShadowColor,
                    style = Stroke(width = 4.5.dp.toPx(), cap = StrokeCap.Round)
                )
                drawPath(
                    path = completedLinePath,
                    color = completedColor,
                    style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
                )

                completedPoints.forEach {
                    drawCircle(
                        color = completedColor,
                        radius = 2.dp.toPx(),
                        center = it
                    )
                }

                selectedIndex?.let { index ->
                    val x = horizontalInset + stepX * index
                    drawLine(
                        color = selectedLineColor,
                        start = Offset(x, verticalPadding),
                        end = Offset(x, baselineY),
                        strokeWidth = 1.dp.toPx()
                    )
                    drawCircle(
                        color = completedColor,
                        radius = 4.dp.toPx(),
                        center = completedPoints[index]
                    )
                    drawCircle(
                        color = dueColor,
                        radius = 4.dp.toPx(),
                        center = duePoints[index]
                    )
                }
            }
        }

        val formatter = remember { DateTimeFormatter.ofPattern("d MMM", Locale.getDefault()) }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(scroll),
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            points.forEachIndexed { index, point ->
                if (index % 2 == 0 || index == points.lastIndex) {
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

private fun DrawScope.smoothPath(points: List<Offset>): Path {
    val path = Path()
    if (points.isEmpty()) return path
    path.moveTo(points.first().x, points.first().y)
    if (points.size == 1) return path

    for (index in 1 until points.size) {
        val prev = points[index - 1]
        val current = points[index]
        val control = Offset(
            x = (prev.x + current.x) / 2f,
            y = (prev.y + current.y) / 2f
        )
        path.quadraticTo(prev.x, prev.y, control.x, control.y)
    }
    val last = points.last()
    path.lineTo(last.x, last.y)
    return path
}

private fun areaToBaselinePath(points: List<Offset>, baselineY: Float): Path {
    val path = Path()
    if (points.isEmpty()) return path
    path.moveTo(points.first().x, baselineY)
    path.lineTo(points.first().x, points.first().y)
    if (points.size > 1) {
        for (index in 1 until points.size) {
            val prev = points[index - 1]
            val current = points[index]
            val control = Offset(
                x = (prev.x + current.x) / 2f,
                y = (prev.y + current.y) / 2f
            )
            path.quadraticTo(prev.x, prev.y, control.x, control.y)
        }
    }
    path.lineTo(points.last().x, points.last().y)
    path.lineTo(points.last().x, baselineY)
    path.close()
    return path
}

private fun areaBetweenPathsPath(top: List<Offset>, bottom: List<Offset>): Path {
    val path = Path()
    if (top.isEmpty() || bottom.isEmpty()) return path
    path.moveTo(top.first().x, top.first().y)
    if (top.size > 1) {
        for (index in 1 until top.size) {
            val prev = top[index - 1]
            val current = top[index]
            val control = Offset(
                x = (prev.x + current.x) / 2f,
                y = (prev.y + current.y) / 2f
            )
            path.quadraticTo(prev.x, prev.y, control.x, control.y)
        }
    }
    path.lineTo(top.last().x, top.last().y)
    path.lineTo(bottom.last().x, bottom.last().y)
    if (bottom.size > 1) {
        for (index in bottom.lastIndex downTo 1) {
            val current = bottom[index]
            val prev = bottom[index - 1]
            val control = Offset(
                x = (current.x + prev.x) / 2f,
                y = (current.y + prev.y) / 2f
            )
            path.quadraticTo(current.x, current.y, control.x, control.y)
        }
    }
    path.lineTo(bottom.first().x, bottom.first().y)
    path.close()
    return path
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
