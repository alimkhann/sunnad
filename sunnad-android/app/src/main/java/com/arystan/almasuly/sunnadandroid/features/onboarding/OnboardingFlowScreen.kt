package com.arystan.almasuly.sunnadandroid.features.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.SelfImprovement
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.app.OnboardingRoute
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.services.AppLanguage
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCompactBackButton
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SecondaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadScreenScaffold

data class OnboardingTemplateSeed(
    val id: String,
    val title: String,
    val category: String,
    val icon: ImageVector,
    val iconName: String,
    val categoryValue: HabitCategoryValue,
    val isDhikr: Boolean = false,
    val targetCount: Int = 33
)

@Composable
fun OnboardingFlowScreen(
    route: OnboardingRoute,
    onRouteChange: (OnboardingRoute) -> Unit,
    onCompleteAsGuest: (List<OnboardingTemplateSeed>) -> Unit,
    onOpenSignIn: () -> Unit,
    onOpenSignUp: () -> Unit,
    onSetLanguage: (AppLanguage) -> Unit,
    onEnableNotifications: () -> Unit,
    onSkipNotifications: () -> Unit,
    selectedLanguage: AppLanguage,
    modifier: Modifier = Modifier
) {
    val templates = listOf(
        OnboardingTemplateSeed("wake_early", stringResource(R.string.onboarding_template_wake_early), stringResource(R.string.onboarding_category_spiritual), Icons.Rounded.WbSunny, "sun.max.fill", HabitCategoryValue.SPIRITUAL),
        OnboardingTemplateSeed("morning_dhikr", stringResource(R.string.onboarding_template_morning_dhikr), stringResource(R.string.onboarding_category_spiritual), Icons.Rounded.WbSunny, "sun.max.fill", HabitCategoryValue.SPIRITUAL, isDhikr = true),
        OnboardingTemplateSeed("evening_dhikr", stringResource(R.string.onboarding_template_evening_dhikr), stringResource(R.string.onboarding_category_spiritual), Icons.Rounded.Bedtime, "moon.fill", HabitCategoryValue.SPIRITUAL, isDhikr = true),
        OnboardingTemplateSeed("read_quran", stringResource(R.string.onboarding_template_read_quran), stringResource(R.string.onboarding_category_spiritual), Icons.Rounded.MenuBook, "book.fill", HabitCategoryValue.SPIRITUAL),
        OnboardingTemplateSeed("surah_waqiah", stringResource(R.string.onboarding_template_surah_waqiah), stringResource(R.string.onboarding_category_spiritual), Icons.Rounded.MenuBook, "text.book.closed.fill", HabitCategoryValue.SPIRITUAL),
        OnboardingTemplateSeed("surah_yasin", stringResource(R.string.onboarding_template_surah_yasin), stringResource(R.string.onboarding_category_spiritual), Icons.Rounded.MenuBook, "text.book.closed.fill", HabitCategoryValue.SPIRITUAL),
        OnboardingTemplateSeed("study_arabic", stringResource(R.string.onboarding_template_study_arabic), stringResource(R.string.onboarding_category_learning), Icons.Rounded.MenuBook, "character.book.closed.fill", HabitCategoryValue.LEARNING),
        OnboardingTemplateSeed("exercise", stringResource(R.string.onboarding_template_exercise), stringResource(R.string.onboarding_category_physical), Icons.Rounded.FitnessCenter, "figure.run", HabitCategoryValue.PHYSICAL),
        OnboardingTemplateSeed("give_charity", stringResource(R.string.onboarding_template_give_charity), stringResource(R.string.onboarding_category_financial), Icons.Rounded.SelfImprovement, "heart.fill", HabitCategoryValue.FINANCIAL),
        OnboardingTemplateSeed("go_mosque", stringResource(R.string.onboarding_template_go_mosque), stringResource(R.string.onboarding_category_spiritual), Icons.Rounded.Groups, "building.columns.fill", HabitCategoryValue.SPIRITUAL),
        OnboardingTemplateSeed("avoid_debt", stringResource(R.string.onboarding_template_avoid_debt), stringResource(R.string.onboarding_category_financial), Icons.Rounded.SelfImprovement, "creditcard.fill", HabitCategoryValue.FINANCIAL),
        OnboardingTemplateSeed("care_parents", stringResource(R.string.onboarding_template_care_parents), stringResource(R.string.onboarding_category_family), Icons.Rounded.Groups, "person.2.fill", HabitCategoryValue.FAMILY),
        OnboardingTemplateSeed("attention_spouse", stringResource(R.string.onboarding_template_attention_spouse), stringResource(R.string.onboarding_category_social), Icons.Rounded.Groups, "person.2.circle.fill", HabitCategoryValue.SOCIAL),
        OnboardingTemplateSeed("time_children", stringResource(R.string.onboarding_template_time_children), stringResource(R.string.onboarding_category_family), Icons.Rounded.Groups, "figure.2.and.child.holdinghands", HabitCategoryValue.FAMILY)
    )

    var selectedTemplateIds by rememberSaveable { mutableStateOf(emptySet<String>()) }
    var notificationsEnabled by rememberSaveable { mutableStateOf(true) }
    var templateSearch by rememberSaveable { mutableStateOf("") }
    var showLanguagePicker by rememberSaveable { mutableStateOf(false) }

    when (route) {
        OnboardingRoute.WELCOME -> HeroStep(
            modifier = modifier,
            title = stringResource(R.string.onboarding_welcome_title),
            subtitle = stringResource(R.string.onboarding_welcome_subtitle),
            icon = Icons.Rounded.WbSunny,
            primaryTitle = stringResource(R.string.onboarding_continue),
            onPrimary = { onRouteChange(OnboardingRoute.TEMPLATES) },
            trailingTopAction = {
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .background(
                            color = MaterialTheme.colorScheme.surfaceContainerHigh,
                            shape = androidx.compose.foundation.shape.CircleShape
                        )
                        .clickable(onClick = { showLanguagePicker = true }),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Language,
                        contentDescription = stringResource(R.string.profile_language),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        )

        OnboardingRoute.TEMPLATES -> {
            val filtered = templates.filter {
                templateSearch.isBlank() || it.title.contains(templateSearch, ignoreCase = true)
            }
            val grouped = filtered.groupBy { it.category }

            SunnadScreenScaffold(
                modifier = modifier,
                footer = {
                    OutlinedTextField(
                        value = templateSearch,
                        onValueChange = { templateSearch = it },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.common_search)) }
                    )
                    PrimaryPillButton(
                        title = stringResource(R.string.onboarding_continue),
                        enabled = selectedTemplateIds.isNotEmpty(),
                        onClick = { onRouteChange(OnboardingRoute.NOTIFICATIONS) }
                    )
                }
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    SunnadCompactBackButton(
                        onClick = { onRouteChange(OnboardingRoute.WELCOME) }
                    )
                    Text(
                        text = stringResource(R.string.onboarding_templates_title),
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold
                    )
                }
                Text(
                    text = stringResource(R.string.onboarding_templates_subtitle),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                    contentPadding = PaddingValues(bottom = 8.dp)
                ) {
                    grouped.forEach { (category, categoryTemplates) ->
                        item(category) {
                            Text(
                                text = category.uppercase(),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        item("$category-card") {
                            SunnadCard(contentPadding = 0.dp) {
                                Column {
                                    categoryTemplates.forEachIndexed { index, item ->
                                        TemplateRow(
                                            item = item,
                                            isSelected = selectedTemplateIds.contains(item.id),
                                            onToggle = {
                                                selectedTemplateIds = if (selectedTemplateIds.contains(item.id)) {
                                                    selectedTemplateIds - item.id
                                                } else {
                                                    selectedTemplateIds + item.id
                                                }
                                            }
                                        )
                                        if (index < categoryTemplates.lastIndex) {
                                            Box(
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .height(1.dp)
                                                    .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
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

        OnboardingRoute.NOTIFICATIONS -> HeroStep(
            modifier = modifier,
            title = stringResource(R.string.onboarding_notifications_title),
            subtitle = stringResource(R.string.onboarding_notifications_subtitle),
            icon = Icons.Rounded.NotificationsActive,
            onBack = { onRouteChange(OnboardingRoute.TEMPLATES) },
            footer = {
                PrimaryPillButton(
                    title = if (notificationsEnabled) {
                        stringResource(R.string.onboarding_notifications_enable)
                    } else {
                        stringResource(R.string.onboarding_continue)
                    },
                    onClick = {
                        if (notificationsEnabled) onEnableNotifications() else onSkipNotifications()
                        onRouteChange(OnboardingRoute.JOIN_GROUPS)
                    }
                )
                SecondaryPillButton(
                    title = stringResource(R.string.onboarding_not_now),
                    onClick = {
                        notificationsEnabled = false
                        onSkipNotifications()
                        onRouteChange(OnboardingRoute.JOIN_GROUPS)
                    }
                )
            }
        )

        OnboardingRoute.JOIN_GROUPS -> HeroStep(
            modifier = modifier,
            title = stringResource(R.string.onboarding_join_groups_title),
            subtitle = stringResource(R.string.onboarding_join_groups_subtitle),
            icon = Icons.Rounded.Groups,
            onBack = { onRouteChange(OnboardingRoute.NOTIFICATIONS) },
            footer = {
                PrimaryPillButton(
                    title = stringResource(R.string.auth_sign_in),
                    onClick = onOpenSignIn
                )
                SecondaryPillButton(
                    title = stringResource(R.string.auth_sign_up),
                    onClick = onOpenSignUp
                )
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { onCompleteAsGuest(templates.filter { selectedTemplateIds.contains(it.id) }) }
                ) {
                    Text(
                        text = stringResource(R.string.onboarding_continue_as_guest),
                        color = MaterialTheme.colorScheme.primary,
                        style = MaterialTheme.typography.titleMedium
                    )
                }
            }
        )

        OnboardingRoute.SIGN_IN,
        OnboardingRoute.SIGN_UP,
        OnboardingRoute.OTP -> Unit
    }

    if (showLanguagePicker) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showLanguagePicker = false },
            title = { Text(stringResource(R.string.profile_language)) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppLanguage.entries.forEach { language ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = languageDisplayName(language),
                                style = MaterialTheme.typography.bodyLarge
                            )
                            TextButton(onClick = {
                                onSetLanguage(language)
                                showLanguagePicker = false
                            }) {
                                Text(
                                    if (selectedLanguage == language) stringResource(R.string.common_selected)
                                    else stringResource(R.string.common_select)
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showLanguagePicker = false }) {
                    Text(stringResource(R.string.common_done))
                }
            }
        )
    }
}

@Composable
private fun HeroStep(
    title: String,
    subtitle: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    primaryTitle: String? = null,
    onPrimary: (() -> Unit)? = null,
    onBack: (() -> Unit)? = null,
    trailingTopAction: (@Composable () -> Unit)? = null,
    footer: (@Composable () -> Unit)? = null
) {
    SunnadScreenScaffold(
        modifier = modifier,
        contentTopPadding = 8.dp,
        footer = {
            when {
                footer != null -> footer()
                primaryTitle != null && onPrimary != null -> {
                    PrimaryPillButton(
                        title = primaryTitle,
                        onClick = onPrimary
                    )
                }
            }
        }
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (onBack != null) {
                SunnadCompactBackButton(onClick = onBack)
            } else {
                Spacer(modifier = Modifier.size(38.dp))
            }
            if (trailingTopAction != null) {
                trailingTopAction()
            } else {
                Spacer(modifier = Modifier.size(38.dp))
            }
        }

        Spacer(modifier = Modifier.weight(1f))
        Box(
            modifier = Modifier
                .size(102.dp)
                .align(Alignment.CenterHorizontally)
                .background(
                    color = MaterialTheme.colorScheme.primary,
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(28.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier.size(44.dp)
            )
        }
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = subtitle,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.weight(1.1f))
    }
}

@Composable
private fun TemplateRow(
    item: OnboardingTemplateSeed,
    isSelected: Boolean,
    onToggle: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(
                    color = MaterialTheme.colorScheme.surfaceContainerHighest,
                    shape = androidx.compose.foundation.shape.CircleShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = item.icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        }
        Text(
            text = item.title,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.weight(1f)
        )
        Icon(
            imageVector = if (isSelected) Icons.Rounded.Check else Icons.Rounded.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
            modifier = Modifier.size(if (isSelected) 30.dp else 26.dp)
        )
    }
}

@Composable
private fun languageDisplayName(language: AppLanguage): String {
    return when (language) {
        AppLanguage.EN -> stringResource(R.string.language_english)
        AppLanguage.RU -> stringResource(R.string.language_russian)
        AppLanguage.KK -> stringResource(R.string.language_kazakh)
    }
}
