package com.arystan.almasuly.sunnadandroid.features.habits

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactBackButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenSurface
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale
import java.util.UUID

private enum class ScheduleMode {
    ALL,
    UPCOMING,
    WEEK,
    MONTH
}

@Composable
fun ScheduleScreen(
    habits: List<Habit>,
    streakByHabitId: Map<UUID, Int> = emptyMap(),
    onClose: () -> Unit,
    onSelectHabit: (UUID) -> Unit,
    onReorderHabits: (List<UUID>) -> Unit
) {
    var mode by rememberSaveable { mutableStateOf(ScheduleMode.ALL) }
    var reorderMode by rememberSaveable { mutableStateOf(false) }
    var searchText by rememberSaveable { mutableStateOf("") }

    val sortedHabits = remember(habits) { habits.sortedBy { it.sortOrder } }
    val habitMap = remember(habits) { habits.associateBy { it.id } }
    var orderedIds by remember(habits) { mutableStateOf(sortedHabits.map { it.id }) }

    val allModeHabits = orderedIds.mapNotNull { habitMap[it] }
    val filteredHabits = if (reorderMode || searchText.isBlank()) {
        allModeHabits
    } else {
        allModeHabits.filter { it.name.contains(searchText, ignoreCase = true) }
    }

    val locale = Locale.getDefault()
    val dateFormatter = remember(locale) { DateTimeFormatter.ofPattern("EEE, d MMM", locale) }

    fun applyReorderIfNeeded() {
        if (!reorderMode) return
        onReorderHabits(orderedIds)
    }

    SunnadScreenSurface {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = SunnadScreenPadding)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                SunnadCompactBackButton(onClick = {
                    applyReorderIfNeeded()
                    onClose()
                })
                Spacer(modifier = Modifier.weight(1f))
                if (mode == ScheduleMode.ALL) {
                    Box(
                        modifier = Modifier
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(999.dp))
                            .clickable {
                                if (reorderMode) {
                                    applyReorderIfNeeded()
                                } else {
                                    searchText = ""
                                }
                                reorderMode = !reorderMode
                            }
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = if (reorderMode) stringResource(R.string.common_done) else stringResource(R.string.common_reorder),
                            color = MaterialTheme.colorScheme.primary,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Text(
                text = stringResource(R.string.schedule_title),
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 8.dp, bottom = 12.dp)
            )

            SegmentTabs(
                mode = mode,
                onChange = {
                    if (mode == ScheduleMode.ALL && reorderMode) {
                        applyReorderIfNeeded()
                        reorderMode = false
                    }
                    mode = it
                }
            )

            Spacer(modifier = Modifier.height(12.dp))

            Box(modifier = Modifier.weight(1f)) {
                when (mode) {
                    ScheduleMode.ALL -> {
                        if (filteredHabits.isEmpty()) {
                            SunnadCard {
                                Text(
                                    text = stringResource(R.string.schedule_empty),
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        } else {
                            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                item {
                                    SunnadCard(contentPadding = 0.dp) {
                                        Column {
                                            filteredHabits.forEachIndexed { index, habit ->
                                                ScheduleHabitRow(
                                                    habit = habit,
                                                    streak = streakByHabitId[habit.id] ?: 0,
                                                    reorderMode = reorderMode,
                                                    onDragReorder = { deltaY ->
                                                        if (!reorderMode) return@ScheduleHabitRow
                                                        val fromIndex = orderedIds.indexOf(habit.id)
                                                        if (fromIndex < 0) return@ScheduleHabitRow
                                                        val shift = when {
                                                            deltaY > 18f && fromIndex < orderedIds.lastIndex -> 1
                                                            deltaY < -18f && fromIndex > 0 -> -1
                                                            else -> 0
                                                        }
                                                        if (shift == 0) return@ScheduleHabitRow
                                                        val next = orderedIds.toMutableList()
                                                        next.removeAt(fromIndex)
                                                        next.add(fromIndex + shift, habit.id)
                                                        orderedIds = next
                                                    },
                                                    onClick = { if (!reorderMode) onSelectHabit(habit.id) }
                                                )
                                                if (index < filteredHabits.lastIndex) {
                                                    DividerLine()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ScheduleMode.UPCOMING -> {
                        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            items((0..6).toList()) { offset ->
                                val date = LocalDate.now().plusDays(offset.toLong())
                                val due = sortedHabits.filter { it.isDue(date) }
                                Text(
                                    text = when (offset) {
                                        0 -> stringResource(R.string.schedule_today).uppercase()
                                        1 -> stringResource(R.string.schedule_tomorrow).uppercase()
                                        else -> date.format(dateFormatter).uppercase()
                                    },
                                    style = MaterialTheme.typography.labelLarge,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontWeight = FontWeight.SemiBold
                                )
                                if (due.isEmpty()) {
                                    SunnadCard {
                                        Text(
                                            text = stringResource(R.string.schedule_none_for_day),
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                } else {
                                    SunnadCard(contentPadding = 0.dp) {
                                        Column {
                                            due.forEachIndexed { index, habit ->
                                                ScheduleHabitRow(
                                                    habit = habit,
                                                    streak = null,
                                                    reorderMode = false,
                                                    onDragReorder = null,
                                                    onClick = { onSelectHabit(habit.id) }
                                                )
                                                if (index < due.lastIndex) DividerLine()
                                            }
                                        }
                                    }
                                }
                            }
                            item { Spacer(modifier = Modifier.height(8.dp)) }
                        }
                    }

                    ScheduleMode.WEEK -> {
                        SunnadCard(contentPadding = 0.dp) {
                            Column {
                                mondayFirstWeekdays.forEachIndexed { index, weekday ->
                                    val count = sortedHabits.count {
                                        when (val schedule = it.schedule) {
                                            is com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule.Daily -> true
                                            is com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule.Weekly -> schedule.weekdays.contains(weekday)
                                        }
                                    }
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(horizontal = 16.dp, vertical = 14.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(
                                            text = weekday.name.lowercase()
                                                .replaceFirstChar { it.titlecase() },
                                            style = MaterialTheme.typography.headlineSmall,
                                            fontWeight = FontWeight.SemiBold,
                                            modifier = Modifier.weight(1f)
                                        )
                                        Text(
                                            text = "$count",
                                            style = MaterialTheme.typography.headlineSmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                    if (index < mondayFirstWeekdays.lastIndex) DividerLine()
                                }
                            }
                        }
                    }

                    ScheduleMode.MONTH -> {
                        val month = YearMonth.now()
                        val startDate = month.atDay(1)
                        val today = LocalDate.now()
                        val dayOffset = startDate.dayOfWeek.value % 7
                        val daysInMonth = month.lengthOfMonth()

                        val dateCounts = (1..daysInMonth).associateWith { day ->
                            val date = month.atDay(day)
                            sortedHabits.count { it.isDue(date) }
                        }

                        val cells = buildList {
                            repeat(dayOffset) { add(-1) }
                            (1..daysInMonth).forEach { add(it) }
                        }

                        LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            item {
                                SunnadCard {
                                    Text(
                                        text = month.month.getDisplayName(TextStyle.FULL, locale) + " " + month.year,
                                        style = MaterialTheme.typography.headlineMedium,
                                        fontWeight = FontWeight.SemiBold,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    Row(modifier = Modifier.fillMaxWidth()) {
                                        listOf(
                                            DayOfWeek.SUNDAY,
                                            DayOfWeek.MONDAY,
                                            DayOfWeek.TUESDAY,
                                            DayOfWeek.WEDNESDAY,
                                            DayOfWeek.THURSDAY,
                                            DayOfWeek.FRIDAY,
                                            DayOfWeek.SATURDAY
                                        ).forEach { day ->
                                            Text(
                                                text = day.getDisplayName(TextStyle.SHORT, locale),
                                                style = MaterialTheme.typography.labelMedium,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                modifier = Modifier.weight(1f)
                                            )
                                        }
                                    }

                                    LazyVerticalGrid(
                                        columns = GridCells.Fixed(7),
                                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                                        verticalArrangement = Arrangement.spacedBy(6.dp),
                                        modifier = Modifier.height(292.dp)
                                    ) {
                                        gridItems(cells) { day ->
                                            if (day <= 0) {
                                                Spacer(modifier = Modifier.size(40.dp))
                                            } else {
                                                val isToday = today.dayOfMonth == day && today.month == month.month && today.year == month.year
                                                Box(
                                                    modifier = Modifier
                                                        .height(56.dp)
                                                        .background(
                                                            color = if (isToday) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHigh,
                                                            shape = RoundedCornerShape(12.dp)
                                                        )
                                                        .padding(vertical = 6.dp),
                                                    contentAlignment = Alignment.Center
                                                ) {
                                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                                        Text(
                                                            text = "$day",
                                                            style = MaterialTheme.typography.titleLarge,
                                                            fontWeight = FontWeight.SemiBold,
                                                            color = if (isToday) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
                                                        )
                                                        Text(
                                                            text = "${dateCounts[day] ?: 0}",
                                                            style = MaterialTheme.typography.labelMedium,
                                                            color = if (isToday) MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.86f) else MaterialTheme.colorScheme.onSurfaceVariant
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if (mode == ScheduleMode.ALL) {
                Spacer(modifier = Modifier.height(10.dp))
                TextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    singleLine = true,
                    shape = RoundedCornerShape(16.dp),
                    placeholder = {
                        Text(
                            text = stringResource(R.string.common_search),
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.85f)
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 10.dp),
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                        unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                        disabledContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        disabledIndicatorColor = Color.Transparent,
                        cursorColor = MaterialTheme.colorScheme.primary
                    )
                )
            } else {
                Spacer(modifier = Modifier.height(12.dp))
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

@Composable
private fun SegmentTabs(
    mode: ScheduleMode,
    onChange: (ScheduleMode) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(999.dp))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        SegmentTabItem(
            title = stringResource(R.string.schedule_mode_all),
            selected = mode == ScheduleMode.ALL,
            onClick = { onChange(ScheduleMode.ALL) },
            modifier = Modifier.weight(1f)
        )
        SegmentTabItem(
            title = stringResource(R.string.schedule_mode_upcoming),
            selected = mode == ScheduleMode.UPCOMING,
            onClick = { onChange(ScheduleMode.UPCOMING) },
            modifier = Modifier.weight(1f)
        )
        SegmentTabItem(
            title = stringResource(R.string.schedule_mode_week),
            selected = mode == ScheduleMode.WEEK,
            onClick = { onChange(ScheduleMode.WEEK) },
            modifier = Modifier.weight(1f)
        )
        SegmentTabItem(
            title = stringResource(R.string.schedule_mode_month),
            selected = mode == ScheduleMode.MONTH,
            onClick = { onChange(ScheduleMode.MONTH) },
            modifier = Modifier.weight(1f)
        )
    }
}

@Composable
private fun SegmentTabItem(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .background(
                color = if (selected) MaterialTheme.colorScheme.surface else Color.Transparent,
                shape = RoundedCornerShape(999.dp)
            )
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
        )
    }
}

@Composable
private fun ScheduleHabitRow(
    habit: Habit,
    streak: Int?,
    reorderMode: Boolean,
    onDragReorder: ((Float) -> Unit)?,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .pointerInput(reorderMode, habit.id) {
                if (!reorderMode || onDragReorder == null) return@pointerInput
                detectDragGesturesAfterLongPress(
                    onDrag = { change, dragAmount ->
                        change.consume()
                        onDragReorder(dragAmount.y)
                    }
                )
            }
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        if (reorderMode) {
            Icon(
                imageVector = Icons.Rounded.Menu,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Box(
            modifier = Modifier
                .size(34.dp)
                .background(MaterialTheme.colorScheme.surfaceContainerHighest, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = iconForHabitName(habit.icon, habit.name),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = habit.name,
                style = MaterialTheme.typography.titleLarge
            )
            streak?.let {
                Text(
                    text = stringResource(R.string.today_streak, it.coerceAtLeast(0)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        if (reorderMode) {
            Text(
                text = stringResource(R.string.schedule_drag_hint),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            Icon(
                imageVector = Icons.Rounded.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
