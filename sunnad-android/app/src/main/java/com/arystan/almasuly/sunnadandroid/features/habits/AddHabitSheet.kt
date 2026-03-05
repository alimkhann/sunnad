package com.arystan.almasuly.sunnadandroid.features.habits

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import com.arystan.almasuly.sunnadandroid.features.onboarding.OnboardingTemplateSeed
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactBackButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactCloseButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenPadding
import java.time.DayOfWeek
import java.time.format.TextStyle
import java.util.Locale

private enum class AddHabitStep {
    CHOICE,
    TEMPLATES,
    CUSTOM
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddHabitSheet(
    existingHabits: List<Habit>,
    onDismiss: () -> Unit,
    onAddTemplates: (List<OnboardingTemplateSeed>) -> Unit,
    onAddCustomHabit: (
        name: String,
        icon: String,
        category: HabitCategoryValue,
        categoryCustom: String?,
        schedule: HabitSchedule,
        isDhikr: Boolean,
        targetCount: Int,
        reminderHour: Int?,
        reminderMinute: Int?
    ) -> Unit
) {
    var step by rememberSaveable { mutableStateOf(AddHabitStep.CHOICE) }

    val templates = remember { defaultTemplates() }
    val existingNames = remember(existingHabits) {
        existingHabits.map { it.name.trim().lowercase() }.toSet()
    }

    var selectedTemplateIds by rememberSaveable { mutableStateOf(setOf<String>()) }
    var searchText by rememberSaveable { mutableStateOf("") }

    var customName by rememberSaveable { mutableStateOf("") }
    var customIcon by rememberSaveable { mutableStateOf(HabitIconKey.STAR) }
    var customCategory by rememberSaveable { mutableStateOf(HabitCategoryValue.SPIRITUAL) }
    var customCategoryText by rememberSaveable { mutableStateOf("") }
    var useCustomCategory by rememberSaveable { mutableStateOf(false) }
    var customScheduleWeekly by rememberSaveable { mutableStateOf(false) }
    var customWeekdays by rememberSaveable { mutableStateOf(mondayFirstWeekdays.toSet()) }
    var reminderEnabled by rememberSaveable { mutableStateOf(false) }
    var reminderHour by rememberSaveable { mutableStateOf("09") }
    var reminderMinute by rememberSaveable { mutableStateOf("00") }
    var hasCounter by rememberSaveable { mutableStateOf(false) }
    var targetRaw by rememberSaveable { mutableStateOf("33") }
    var categoryMenuExpanded by remember { mutableStateOf(false) }
    val templateTitlesById = templates.associate { it.id to stringResource(it.titleRes) }
    val categoryTitlesByCategory = HabitCategoryValue.entries.associateWith { category ->
        stringResource(categoryTitleRes(category))
    }

    val availableTemplates = templates.filter { seed ->
        val title = stringResource(seed.titleRes)
        !existingNames.contains(title.trim().lowercase()) &&
            (searchText.isBlank() || title.contains(searchText, ignoreCase = true))
    }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.92f)
                .fillMaxWidth()
                .padding(horizontal = SunnadScreenPadding)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp)
            ) {
                if (step == AddHabitStep.CHOICE) {
                    Spacer(modifier = Modifier.size(38.dp).align(Alignment.CenterStart))
                } else {
                    SunnadCompactBackButton(
                        onClick = { step = AddHabitStep.CHOICE },
                        modifier = Modifier.align(Alignment.CenterStart)
                    )
                }
                Text(
                    text = stringResource(R.string.today_add_habit),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.align(Alignment.Center)
                )
                SunnadCompactCloseButton(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.CenterEnd)
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            when (step) {
                AddHabitStep.CHOICE -> {
                    PrimaryPillButton(
                        title = stringResource(R.string.habit_add_templates),
                        onClick = { step = AddHabitStep.TEMPLATES }
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    SecondaryPillButton(
                        title = stringResource(R.string.habit_add_custom),
                        onClick = { step = AddHabitStep.CUSTOM }
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                }

                AddHabitStep.TEMPLATES -> {
                    Column(modifier = Modifier.fillMaxWidth().weight(1f)) {
                        LazyColumn(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(HabitCategoryValue.entries, key = { it.name }) { category ->
                                val categoryItems = availableTemplates.filter { it.category == category }
                                if (categoryItems.isNotEmpty()) {
                                    Text(
                                        text = stringResource(categoryTitleRes(category)).uppercase(),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontWeight = FontWeight.SemiBold,
                                        modifier = Modifier.padding(top = 2.dp)
                                    )

                                    SunnadCard(contentPadding = 0.dp) {
                                        Column {
                                            categoryItems.forEachIndexed { index, seed ->
                                                val title = stringResource(seed.titleRes)
                                                TemplateToggleRow(
                                                    title = title,
                                                    iconName = seed.iconName,
                                                    isSelected = selectedTemplateIds.contains(seed.id),
                                                    onToggle = {
                                                        selectedTemplateIds = if (selectedTemplateIds.contains(seed.id)) {
                                                            selectedTemplateIds - seed.id
                                                        } else {
                                                            selectedTemplateIds + seed.id
                                                        }
                                                    }
                                                )
                                                if (index < categoryItems.lastIndex) {
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
                            item {
                                Spacer(modifier = Modifier.height(8.dp))
                            }
                        }

                        TextField(
                            value = searchText,
                            onValueChange = { searchText = it },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            placeholder = {
                                Text(
                                    text = stringResource(R.string.common_search),
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.85f)
                                )
                            },
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
                        PrimaryPillButton(
                            title = stringResource(R.string.common_add),
                            modifier = Modifier
                                .padding(top = 10.dp, bottom = 10.dp)
                                .navigationBarsPadding(),
                            enabled = selectedTemplateIds.isNotEmpty(),
                            onClick = {
                                val selected = templates
                                    .filter { selectedTemplateIds.contains(it.id) }
                                    .map { seed ->
                                        seed.toOnboardingSeed(templateTitlesById[seed.id] ?: "").copy(
                                            category = categoryTitlesByCategory[seed.category] ?: ""
                                        )
                                    }
                                onAddTemplates(selected)
                                onDismiss()
                            }
                        )
                    }
                }

                AddHabitStep.CUSTOM -> {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f)
                    ) {
                        LazyColumn(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                            contentPadding = PaddingValues(bottom = 12.dp)
                        ) {
                            item {
                                SunnadCard(contentPadding = 0.dp) {
                                    Column {
                                        FieldLabel(label = stringResource(R.string.habit_name))
                                        TextField(
                                            value = customName,
                                            onValueChange = { customName = it },
                                            singleLine = true,
                                            modifier = Modifier.fillMaxWidth(),
                                            placeholder = {
                                                Text(stringResource(R.string.habit_custom_name_placeholder))
                                            },
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
                            }

                            item {
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
                                            text = if (useCustomCategory) {
                                                customCategoryText.trim().ifBlank { stringResource(R.string.habit_category_custom_option) }
                                            } else {
                                                stringResource(categoryTitleRes(customCategory))
                                            },
                                            color = MaterialTheme.colorScheme.primary,
                                            style = MaterialTheme.typography.bodyLarge,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                    }
                                    DropdownMenu(
                                        expanded = categoryMenuExpanded,
                                        onDismissRequest = { categoryMenuExpanded = false }
                                    ) {
                                        HabitCategoryValue.entries.forEach { category ->
                                            DropdownMenuItem(
                                                text = { Text(stringResource(categoryTitleRes(category))) },
                                                onClick = {
                                                    customCategory = category
                                                    useCustomCategory = false
                                                    categoryMenuExpanded = false
                                                }
                                            )
                                        }
                                        DropdownMenuItem(
                                            text = { Text(stringResource(R.string.habit_category_custom_option)) },
                                            onClick = {
                                                useCustomCategory = true
                                                categoryMenuExpanded = false
                                            }
                                        )
                                    }
                                    if (useCustomCategory) {
                                        Box(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .height(1.dp)
                                                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                                        )
                                        TextField(
                                            value = customCategoryText,
                                            onValueChange = { customCategoryText = it },
                                            singleLine = true,
                                            modifier = Modifier.fillMaxWidth(),
                                            placeholder = {
                                                Text(stringResource(R.string.habit_category_custom_placeholder))
                                            },
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
                            }

                            item {
                                Text(
                                    text = stringResource(R.string.habit_icon).uppercase(),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    fontWeight = FontWeight.SemiBold
                                )
                                SunnadCard {
                                    IconPickerRow(
                                        selectedIcon = customIcon,
                                        onSelect = { customIcon = it }
                                    )
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
                                            selected = !customScheduleWeekly,
                                            onClick = { customScheduleWeekly = false }
                                        )
                                        Box(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .height(1.dp)
                                                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                                        )
                                        ScheduleOptionRow(
                                            title = stringResource(R.string.habit_schedule_weekly),
                                            selected = customScheduleWeekly,
                                            onClick = { customScheduleWeekly = true }
                                        )
                                        if (customScheduleWeekly) {
                                            WeekdaySelectorRow(
                                                selectedWeekdays = customWeekdays,
                                                onToggle = { day ->
                                                    customWeekdays = if (customWeekdays.contains(day)) {
                                                        customWeekdays - day
                                                    } else {
                                                        customWeekdays + day
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }

                            item {
                                Text(
                                    text = stringResource(R.string.habit_counter).uppercase(),
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
                                            text = stringResource(R.string.habit_counter),
                                            style = MaterialTheme.typography.bodyLarge,
                                            fontWeight = FontWeight.Medium,
                                            modifier = Modifier.weight(1f)
                                        )
                                        Switch(checked = hasCounter, onCheckedChange = { hasCounter = it })
                                    }
                                    if (hasCounter) {
                                        OutlinedTextField(
                                            value = targetRaw,
                                            onValueChange = { value ->
                                                targetRaw = value.filter(Char::isDigit).take(3)
                                            },
                                            label = { Text(stringResource(R.string.habit_target_count)) },
                                            singleLine = true,
                                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                            modifier = Modifier.fillMaxWidth()
                                        )
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
                                            OutlinedTextField(
                                                value = reminderHour,
                                                onValueChange = { value ->
                                                    reminderHour = value.filter(Char::isDigit).take(2)
                                                },
                                                label = { Text(stringResource(R.string.habit_reminder_hour)) },
                                                singleLine = true,
                                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                                modifier = Modifier.weight(1f)
                                            )
                                            OutlinedTextField(
                                                value = reminderMinute,
                                                onValueChange = { value ->
                                                    reminderMinute = value.filter(Char::isDigit).take(2)
                                                },
                                                label = { Text(stringResource(R.string.habit_reminder_minute)) },
                                                singleLine = true,
                                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                                modifier = Modifier.weight(1f)
                                            )
                                        }
                                    }
                                }
                            }
                    }
                    PrimaryPillButton(
                        title = stringResource(R.string.common_add),
                        modifier = Modifier
                            .padding(top = 10.dp, bottom = 10.dp)
                            .navigationBarsPadding()
                            .imePadding(),
                        enabled = customName.trim().isNotEmpty(),
                        onClick = {
                            val hour = reminderHour.toIntOrNull()?.coerceIn(0, 23) ?: 9
                            val minute = reminderMinute.toIntOrNull()?.coerceIn(0, 59) ?: 0
                            val schedule = if (customScheduleWeekly) {
                                HabitSchedule.Weekly(customWeekdays.ifEmpty { setOf(Weekday.MONDAY) })
                            } else {
                                HabitSchedule.Daily
                            }
                            onAddCustomHabit(
                                customName.trim(),
                                customIcon,
                                customCategory,
                                if (useCustomCategory) customCategoryText.trim().takeIf { it.isNotEmpty() } else null,
                                schedule,
                                hasCounter,
                                targetRaw.toIntOrNull()?.coerceAtLeast(1) ?: 33,
                                if (reminderEnabled) hour else null,
                                if (reminderEnabled) minute else null
                            )
                            onDismiss()
                        }
                    )
                }
            }
        }
    }
}
}

@Composable
private fun FieldLabel(label: String) {
    Text(
        text = label,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 16.dp, top = 12.dp)
    )
}

@Composable
fun ScheduleOptionRow(
    title: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f)
        )
        if (selected) {
            Icon(
                imageVector = Icons.Rounded.Check,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
fun WeekdaySelectorRow(
    selectedWeekdays: Set<Weekday>,
    onToggle: (Weekday) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        mondayFirstWeekdays.forEach { day ->
            val isSelected = selectedWeekdays.contains(day)
            Box(
                modifier = Modifier
                    .weight(1f)
                    .background(
                        color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(999.dp)
                    )
                    .clickable { onToggle(day) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = weekdayShortLabel(day),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
                )
            }
        }
    }
}

private fun weekdayShortLabel(day: Weekday): String {
    val dayOfWeek = when (day) {
        Weekday.MONDAY -> DayOfWeek.MONDAY
        Weekday.TUESDAY -> DayOfWeek.TUESDAY
        Weekday.WEDNESDAY -> DayOfWeek.WEDNESDAY
        Weekday.THURSDAY -> DayOfWeek.THURSDAY
        Weekday.FRIDAY -> DayOfWeek.FRIDAY
        Weekday.SATURDAY -> DayOfWeek.SATURDAY
        Weekday.SUNDAY -> DayOfWeek.SUNDAY
    }
    val label = dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault())
    return if (label.length > 2) label.take(2) else label
}

@Composable
fun TemplateToggleRow(
    title: String,
    iconName: String,
    isSelected: Boolean,
    onToggle: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(
                    color = MaterialTheme.colorScheme.surfaceContainerHighest,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = iconForHabitName(iconName, title),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        }
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.weight(1f)
        )
        Box(
            modifier = Modifier
                .size(24.dp)
                .background(
                    color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceContainerHighest,
                    shape = CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            if (isSelected) {
                Icon(
                    imageVector = Icons.Rounded.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

@Composable
fun IconPickerRow(
    selectedIcon: String,
    onSelect: (String) -> Unit
) {
    val iconOptions = canonicalHabitIconKeys

    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.height(176.dp)
    ) {
        items(iconOptions.chunked(4)) { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { iconName ->
                    val selected = iconName == selectedIcon
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .background(
                                color = if (selected) {
                                    MaterialTheme.colorScheme.primary.copy(alpha = 0.16f)
                                } else {
                                    MaterialTheme.colorScheme.surfaceContainerHighest
                                },
                                shape = RoundedCornerShape(14.dp)
                            )
                            .clickable { onSelect(iconName) }
                            .padding(vertical = 10.dp, horizontal = 8.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = iconForHabitName(iconName, iconName),
                                contentDescription = null,
                                tint = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            if (selected) {
                                Icon(
                                    imageVector = Icons.Rounded.Check,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
                if (row.size < 4) {
                    repeat(4 - row.size) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}
