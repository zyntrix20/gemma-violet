package com.violet.gemma.ui.theme

import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

object VColors {
    val Bg = Color(0xFF0A0712)
    val Surface = Color(0xFF120D1C)
    val Surface2 = Color(0xFF1A1328)
    val Surface3 = Color(0xFF251C38)
    val Outline = Color(0xFF2E2445)
    val Primary = Color(0xFFA78BFA)
    val PrimaryDeep = Color(0xFF7C3AED)
    val Accent = Color(0xFFD8B4FE)
    val Pink = Color(0xFFE879F9)
    val Text = Color(0xFFF2EEFF)
    val Muted = Color(0xFF9F95BA)
    val Faint = Color(0xFF6C6387)
    val Danger = Color(0xFFFF6B8B)
    val Online = Color(0xFF6EE7B7)
    val CodeBg = Color(0xFF0E0A17)
}

object VBrush {
    val Primary = Brush.linearGradient(listOf(Color(0xFF8B5CF6), Color(0xFF6D28D9)))
    val Title = Brush.linearGradient(listOf(Color(0xFFFAF5FF), Color(0xFFD8B4FE), Color(0xFFA78BFA)))
    val UserBubble = Brush.linearGradient(listOf(Color(0xFF7C3AED), Color(0xFF9D4EDD)))
}

@Composable
fun VioletTheme(content: @Composable () -> Unit) {
    val scheme = darkColorScheme(
        primary = VColors.Primary,
        onPrimary = Color.White,
        primaryContainer = VColors.PrimaryDeep,
        onPrimaryContainer = Color.White,
        secondary = VColors.Accent,
        onSecondary = Color.Black,
        background = VColors.Bg,
        onBackground = VColors.Text,
        surface = VColors.Surface,
        onSurface = VColors.Text,
        surfaceVariant = VColors.Surface2,
        onSurfaceVariant = VColors.Muted,
        surfaceContainerLowest = VColors.Bg,
        surfaceContainerLow = VColors.Surface,
        surfaceContainer = VColors.Surface2,
        surfaceContainerHigh = VColors.Surface3,
        surfaceContainerHighest = VColors.Surface3,
        outline = VColors.Outline,
        outlineVariant = VColors.Outline,
        error = VColors.Danger,
    )
    MaterialTheme(colorScheme = scheme) {
        CompositionLocalProvider(LocalContentColor provides VColors.Text, content = content)
    }
}
