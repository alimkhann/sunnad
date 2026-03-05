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
    const val PRAYER = "building.columns.fill"
}

val canonicalHabitIconKeys: List<String> = listOf(
    "star.fill",
    "heart.fill",
    "sun.max.fill",
    "sunrise.fill",
    "moon.stars.fill",
    "moon.fill",
    "book.closed.fill",
    "book.fill",
    "text.book.closed.fill",
    "bookmark.fill",
    "figure.run",
    "figure.walk",
    "dumbbell.fill",
    "flame.fill",
    "bolt.fill",
    "drop.fill",
    "leaf.fill",
    "fork.knife",
    "cup.and.saucer.fill",
    "bed.double.fill",
    "alarm.fill",
    "clock.fill",
    "calendar",
    "checkmark.circle.fill",
    "target",
    "brain.head.profile",
    "sparkles",
    "hands.sparkles.fill",
    "building.columns.fill",
    "person.2.fill",
    "figure.2.and.child.holdinghands",
    "phone.fill",
    "message.fill",
    "briefcase.fill",
    "chart.bar.fill",
    "banknote.fill",
    "creditcard.fill",
    "cart.fill",
    "graduationcap.fill",
    "paintpalette.fill",
    "music.note",
    "globe"
)

private val canonicalHabitIconKeySet = canonicalHabitIconKeys.toSet()

fun canonicalHabitIconKey(iconName: String, title: String = ""): String {
    val source = iconName.lowercase()
    val titleLower = title.lowercase()
    if (source in canonicalHabitIconKeySet) {
        return source
    }
    return when {
        source in setOf("sun", "sunrise", "sunrise.fill", "sun.max.fill", "wb_sunny", "wbsunny") ||
            titleLower.contains("morning") -> HabitIconKey.SUN

        source in setOf("moon", "moon.fill", "moon.stars.fill", "bedtime", "bed.double.fill") ||
            titleLower.contains("evening") -> HabitIconKey.MOON

        source in setOf(
            "book",
            "book.fill",
            "book.closed.fill",
            "text.book.closed.fill",
            "bookmark.fill",
            "menu_book",
            "graduationcap.fill"
        ) ||
            titleLower.contains("quran") ||
            titleLower.contains("surah") -> HabitIconKey.BOOK

        source in setOf("run", "figure.run", "figure.walk", "fitness_center", "runner", "dumbbell.fill") ||
            source.contains("run") ||
            source.contains("fitness") ||
            titleLower.contains("exercise") -> HabitIconKey.RUN

        source in setOf(
            "group",
            "groups",
            "person.2.fill",
            "person.3.fill",
            "person.2",
            "figure.2.and.child.holdinghands",
            "phone.fill",
            "message.fill"
        ) ||
            source.contains("person") ||
            source.contains("group") -> HabitIconKey.GROUP

        source in setOf(
            "money",
            "banknote.fill",
            "creditcard.fill",
            "credit",
            "monetization_on",
            "cart.fill",
            "chart.bar.fill",
            "briefcase.fill"
        ) ||
            source.contains("money") ||
            source.contains("credit") -> HabitIconKey.MONEY

        source in setOf(
            "star",
            "star.fill",
            "target",
            "alarm.fill",
            "clock.fill",
            "calendar",
            "checkmark.circle.fill",
            "bolt.fill",
            "music.note",
            "globe"
        ) -> HabitIconKey.STAR
        source in setOf("heart", "heart.fill", "favorite") -> HabitIconKey.HEART
        source in setOf("building.columns.fill", "building.columns", "mosque") ||
            source.contains("prayer") ||
            titleLower.contains("prayer") ||
            titleLower.contains("намаз") -> HabitIconKey.PRAYER
        source in setOf(
            "dhikr",
            "sparkles",
            "hands.sparkles.fill",
            "flame.fill",
            "drop.fill",
            "leaf.fill",
            "spa",
            "self_improvement",
            "brain.head.profile",
            "cup.and.saucer.fill",
            "fork.knife",
            "paintpalette.fill"
        ) || titleLower.contains("dhikr") -> HabitIconKey.SPA
        else -> HabitIconKey.STAR
    }
}

fun iconForHabitKey(key: String): ImageVector {
    return when (canonicalHabitIconKey(key)) {
        "sun.max.fill", "sunrise.fill" -> Icons.Rounded.WbSunny
        "moon.stars.fill", "moon.fill", "bed.double.fill" -> Icons.Rounded.Bedtime
        "book.closed.fill", "book.fill", "text.book.closed.fill", "bookmark.fill", "graduationcap.fill" -> Icons.Rounded.MenuBook
        "figure.run", "figure.walk", "dumbbell.fill" -> Icons.Rounded.FitnessCenter
        "person.2.fill", "figure.2.and.child.holdinghands", "phone.fill", "message.fill" -> Icons.Rounded.Groups
        "banknote.fill", "creditcard.fill", "cart.fill", "chart.bar.fill", "briefcase.fill" -> Icons.Rounded.MonetizationOn
        "sparkles", "hands.sparkles.fill", "drop.fill", "leaf.fill", "cup.and.saucer.fill", "fork.knife", "brain.head.profile", "paintpalette.fill" -> Icons.Rounded.Spa
        "building.columns.fill", "flame.fill" -> Icons.Rounded.SelfImprovement
        "star.fill", "heart.fill", "bolt.fill", "alarm.fill", "clock.fill", "calendar", "checkmark.circle.fill", "target", "music.note", "globe" -> Icons.Rounded.Star
        HabitIconKey.SUN -> Icons.Rounded.WbSunny
        HabitIconKey.MOON -> Icons.Rounded.Bedtime
        HabitIconKey.BOOK -> Icons.Rounded.MenuBook
        HabitIconKey.RUN -> Icons.Rounded.FitnessCenter
        HabitIconKey.GROUP -> Icons.Rounded.Groups
        HabitIconKey.MONEY -> Icons.Rounded.MonetizationOn
        HabitIconKey.SPA -> Icons.Rounded.Spa
        HabitIconKey.PRAYER -> Icons.Rounded.SelfImprovement
        else -> Icons.Rounded.Star
    }
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
    HabitCategoryValue.WORK -> R.string.onboarding_category_work
    HabitCategoryValue.HOBBY -> R.string.onboarding_category_hobby
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
    TemplateSeed("time_children", R.string.onboarding_template_time_children, HabitCategoryValue.FAMILY, HabitIconKey.GROUP, false, 33),
    TemplateSeed("work_focus", R.string.onboarding_template_work_focus, HabitCategoryValue.WORK, HabitIconKey.STAR, false, 33),
    TemplateSeed("hobby_practice", R.string.onboarding_template_hobby_practice, HabitCategoryValue.HOBBY, HabitIconKey.STAR, false, 33),
    TemplateSeed("five_times_prayer", R.string.onboarding_template_five_times_prayer, HabitCategoryValue.SPIRITUAL, HabitIconKey.PRAYER, false, 33),
    TemplateSeed("fajr_prayer", R.string.onboarding_template_fajr, HabitCategoryValue.SPIRITUAL, HabitIconKey.PRAYER, false, 33),
    TemplateSeed("dhuhr_prayer", R.string.onboarding_template_dhuhr, HabitCategoryValue.SPIRITUAL, HabitIconKey.PRAYER, false, 33),
    TemplateSeed("asr_prayer", R.string.onboarding_template_asr, HabitCategoryValue.SPIRITUAL, HabitIconKey.PRAYER, false, 33),
    TemplateSeed("maghrib_prayer", R.string.onboarding_template_maghrib, HabitCategoryValue.SPIRITUAL, HabitIconKey.PRAYER, false, 33),
    TemplateSeed("isha_prayer", R.string.onboarding_template_isha, HabitCategoryValue.SPIRITUAL, HabitIconKey.PRAYER, false, 33)
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
