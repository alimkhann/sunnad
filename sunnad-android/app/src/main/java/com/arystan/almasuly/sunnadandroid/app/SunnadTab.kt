package com.arystan.almasuly.sunnadandroid.app

import androidx.annotation.StringRes
import com.arystan.almasuly.sunnadandroid.R

enum class SunnadTab(
    @StringRes val labelRes: Int,
    @StringRes val contentDescriptionRes: Int,
    val icon: String,
    val route: MainTabRoute
) {
    TODAY(R.string.tab_today, R.string.tab_today, "calendar_month", MainTabRoute.TODAY),
    GROUPS(R.string.tab_groups, R.string.tab_groups, "groups", MainTabRoute.GROUPS),
    PROFILE(R.string.tab_profile, R.string.tab_profile, "account_circle", MainTabRoute.PROFILE)
}
