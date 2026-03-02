package com.arystan.almasuly.sunnadandroid.features.habits

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.MenuBook
import androidx.compose.material.icons.rounded.MonetizationOn
import androidx.compose.material.icons.rounded.SelfImprovement
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.ui.graphics.vector.ImageVector
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.core.model.Habit
import com.arystan.almasuly.sunnadandroid.core.model.HabitCategoryValue
import com.arystan.almasuly.sunnadandroid.core.model.Weekday
import com.arystan.almasuly.sunnadandroid.features.onboarding.OnboardingTemplateSeed

object HabitIconKey {
    const val SUN = "sunrise.fill"
    const val MOON = "moon.fill"
    const val BOOK = "book.closed.fill"
    const val RUN = "figure.run"
    const val GROUP = "person.2.fill"
    const val HEART = "heart.fill"
    const val MONEY = "banknote.fill"
    const val STAR = "star.fill"
    const val SPA = "sparkles"
}

fun canonicalHabitIconKey(iconName: String, title: String = ""): String {
    val source = iconName.lowercase()
    val titleLower = title.lowercase()
    return when {
        source in setOf("sun", "sunrise", "sunrise.fill", "sun.max.fill", "wb_sunny", "wbsunny") ||
            titleLower.contains("morning") -> HabitIconKey.SUN

        source in setOf("moon", "moon.fill", "moon.stars.fill", "bedtime") ||
            titleLower.contains("evening") -> HabitIconKey.MOON

        source in setOf("book", "book.fill", "book.closed.fill", "menu_book") ||
            titleLower.contains("quran") ||
            titleLower.contains("surah") -> HabitIconKey.BOOK

        source in setOf("run", "figure.run", "fitness_center", "runner") ||
            source.contains("run") ||
            source.contains("fitness") ||
            titleLower.contains("exercise") -> HabitIconKey.RUN

        source in setOf("group", "groups", "person.2.fill", "person.3.fill", "person.2") ||
            source.contains("person") ||
            source.contains("group") -> HabitIconKey.GROUP

        source in setOf("money", "banknote.fill", "creditcard.fill", "credit", "monetization_on") ||
            source.contains("money") ||
            source.contains("credit") -> HabitIconKey.MONEY

        source in setOf("star", "star.fill") -> HabitIconKey.STAR
        source in setOf("heart", "heart.fill", "favorite") -> HabitIconKey.HEART
        source in setOf("dhikr", "sparkles", "spa", "self_improvement") || titleLower.contains("dhikr") -> HabitIconKey.SPA
        else -> HabitIconKey.STAR
    }
}

fun iconForHabitKey(key: String): ImageVector = when (canonicalHabitIconKey(key)) {
    HabitIconKey.SUN -> Icons.Rounded.WbSunny
    HabitIconKey.MOON -> Icons.Rounded.Bedtime
    HabitIconKey.BOOK -> Icons.Rounded.MenuBook
    HabitIconKey.RUN -> Icons.Rounded.FitnessCenter
    HabitIconKey.GROUP -> Icons.Rounded.Groups
    HabitIconKey.MONEY -> Icons.Rounded.MonetizationOn
    HabitIconKey.STAR -> Icons.Rounded.Star
    HabitIconKey.SPA -> Icons.Rounded.Spa
    else -> Icons.Rounded.SelfImprovement
}

fun iconForHabitName(iconName: String, title: String): ImageVector =
    iconForHabitKey(canonicalHabitIconKey(iconName, title))

fun categoryTitleRes(category: HabitCategoryValue): Int = when (category) {
    HabitCategoryValue.SPIRITUAL -> R.string.onboarding_category_spiritual
    HabitCategoryValue.PHYSICAL -> R.string.onboarding_category_physical
    HabitCategoryValue.SOCIAL -> R.string.onboarding_category_social
    HabitCategoryValue.FINANCIAL -> R.string.onboarding_category_financial
    HabitCategoryValue.LEARNING -> R.string.onboarding_category_learning
    HabitCategoryValue.FAMILY -> R.string.onboarding_category_family
}

val mondayFirstWeekdays = listOf(
    Weekday.MONDAY,
    Weekday.TUESDAY,
    Weekday.WEDNESDAY,
    Weekday.THURSDAY,
    Weekday.FRIDAY,
    Weekday.SATURDAY,
    Weekday.SUNDAY
)

fun defaultTemplates(): List<TemplateSeed> = listOf(
    TemplateSeed("wake_early", R.string.onboarding_template_wake_early, HabitCategoryValue.SPIRITUAL, HabitIconKey.SUN, false, 33),
    TemplateSeed("morning_dhikr", R.string.onboarding_template_morning_dhikr, HabitCategoryValue.SPIRITUAL, HabitIconKey.SUN, true, 33),
    TemplateSeed("evening_dhikr", R.string.onboarding_template_evening_dhikr, HabitCategoryValue.SPIRITUAL, HabitIconKey.MOON, true, 33),
    TemplateSeed("read_quran", R.string.onboarding_template_read_quran, HabitCategoryValue.SPIRITUAL, HabitIconKey.BOOK, false, 33),
    TemplateSeed("surah_waqiah", R.string.onboarding_template_surah_waqiah, HabitCategoryValue.SPIRITUAL, HabitIconKey.BOOK, false, 33),
    TemplateSeed("surah_yasin", R.string.onboarding_template_surah_yasin, HabitCategoryValue.SPIRITUAL, HabitIconKey.BOOK, false, 33),
    TemplateSeed("study_arabic", R.string.onboarding_template_study_arabic, HabitCategoryValue.LEARNING, HabitIconKey.BOOK, false, 33),
    TemplateSeed("exercise", R.string.onboarding_template_exercise, HabitCategoryValue.PHYSICAL, HabitIconKey.RUN, false, 33),
    TemplateSeed("give_charity", R.string.onboarding_template_give_charity, HabitCategoryValue.FINANCIAL, HabitIconKey.HEART, false, 33),
    TemplateSeed("go_mosque", R.string.onboarding_template_go_mosque, HabitCategoryValue.SPIRITUAL, HabitIconKey.GROUP, false, 33),
    TemplateSeed("avoid_debt", R.string.onboarding_template_avoid_debt, HabitCategoryValue.FINANCIAL, HabitIconKey.MONEY, false, 33),
    TemplateSeed("care_parents", R.string.onboarding_template_care_parents, HabitCategoryValue.FAMILY, HabitIconKey.GROUP, false, 33),
    TemplateSeed("attention_spouse", R.string.onboarding_template_attention_spouse, HabitCategoryValue.SOCIAL, HabitIconKey.GROUP, false, 33),
    TemplateSeed("time_children", R.string.onboarding_template_time_children, HabitCategoryValue.FAMILY, HabitIconKey.GROUP, false, 33)
)

data class TemplateSeed(
    val id: String,
    val titleRes: Int,
    val category: HabitCategoryValue,
    val iconName: String,
    val isDhikr: Boolean,
    val targetCount: Int
)

fun TemplateSeed.toOnboardingSeed(title: String): OnboardingTemplateSeed = OnboardingTemplateSeed(
    id = id,
    title = title,
    category = "",
    icon = iconForHabitName(iconName, title),
    iconName = iconName,
    categoryValue = category,
    isDhikr = isDhikr,
    targetCount = targetCount
)

fun Habit.withUpdatedSchedule(
    weekly: Boolean,
    selectedWeekdays: Set<Weekday>
): Habit = copy(
    schedule = if (weekly) {
        com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule.Weekly(
            selectedWeekdays.ifEmpty { setOf(Weekday.MONDAY) }
        )
    } else {
        com.arystan.almasuly.sunnadandroid.core.model.HabitSchedule.Daily
    }
)
