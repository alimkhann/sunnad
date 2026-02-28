package com.arystan.almasuly.sunnadandroid.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val LightScheme = lightColorScheme(
    primary = SunnadPrimary,
    onPrimary = SunnadOnPrimary,
    primaryContainer = SunnadPrimaryContainer,
    onPrimaryContainer = SunnadOnPrimaryContainer,
    secondary = SunnadSecondary,
    onSecondary = SunnadOnSecondary,
    secondaryContainer = SunnadSecondaryContainer,
    onSecondaryContainer = SunnadOnSecondaryContainer,
    background = SunnadBackground,
    onBackground = SunnadOnBackground,
    surface = SunnadSurface,
    onSurface = SunnadOnSurface,
    surfaceContainer = SunnadSurfaceContainer,
    outline = SunnadOutline,
    outlineVariant = SunnadOutlineVariant
)

private val DarkScheme = darkColorScheme(
    primary = SunnadPrimary,
    onPrimary = SunnadOnPrimary,
    primaryContainer = SunnadPrimaryContainer,
    onPrimaryContainer = SunnadOnPrimaryContainer,
    secondary = SunnadSecondary,
    onSecondary = SunnadOnSecondary,
    secondaryContainer = SunnadSecondaryContainer,
    onSecondaryContainer = SunnadOnSecondaryContainer,
    background = SunnadBackgroundDark,
    onBackground = SunnadOnBackgroundDark,
    surface = SunnadSurfaceDark,
    onSurface = SunnadOnSurfaceDark,
    surfaceContainer = SunnadSurfaceContainerDark,
    outline = SunnadOutlineDark,
    outlineVariant = SunnadOutlineVariantDark
)

@Composable
fun SunnadTheme(
    forcedDarkTheme: Boolean? = null,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val darkTheme = forcedDarkTheme ?: isSystemInDarkTheme()
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && forcedDarkTheme == null -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkScheme
        else -> LightScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
