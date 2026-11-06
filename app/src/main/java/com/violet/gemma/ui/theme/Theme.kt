package com.violet.gemma.ui.theme

import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor

/**
 * Палитра SerOAI.
 *  Midnight Purple  #12091F — фон
 *  Deep Violet      #241138 — плашки / карточки
 *  Electric Purple  #7C3AED — акценты / кнопки
 *  Neon Magenta     #C084FC — подсветка / активные элементы
 *  Soft Silver      #F3F4F6 — текст
 */
object VColors {
    val Bg = Color(0xFF12091F)
    val Surface = Color(0xFF1A0E2B)      // промежуточный слой (шторка, меню)
    val Surface2 = Color(0xFF241138)     // Deep Violet — карточки, пузыри
    val Surface3 = Color(0xFF301A4A)     // нажатое / выбранное
    val Outline = Color(0xFF3A2455)
    val Primary = Color(0xFF7C3AED)      // Electric Purple
    val PrimaryDeep = Color(0xFF7C3AED)
    val Accent = Color(0xFFC084FC)       // Neon Magenta
    val Pink = Color(0xFFC084FC)
    val Text = Color(0xFFF3F4F6)         // Soft Silver
    val Muted = Color(0xFFB4ADC4)
    val Faint = Color(0xFF7D7392)
    val Danger = Color(0xFFF87171)
    val Online = Color(0xFF4ADE80)
    val CodeBg = Color(0xFF0D0717)
}

object VBrush {
    val Primary: Brush = SolidColor(VColors.Primary)
    val UserBubble: Brush = SolidColor(VColors.Surface2)
}

@Composable
fun VioletTheme(content: @Composable () -> Unit) {
    val scheme = darkColorScheme(
        primary = VColors.Primary,
        onPrimary = Color.White,
        primaryContainer = VColors.Primary,
        onPrimaryContainer = Color.White,
        secondary = VColors.Accent,
        onSecondary = VColors.Bg,
        background = VColors.Bg,
        onBackground = VColors.Text,
        surface = VColors.Surface,
        onSurface = VColors.Text,
        surfaceVariant = VColors.Surface2,
        onSurfaceVariant = VColors.Muted,
        surfaceContainerLowest = VColors.Bg,
        surfaceContainerLow = VColors.Surface,
        surfaceContainer = VColors.Surface2,
        surfaceContainerHigh = VColors.Surface2,
        surfaceContainerHighest = VColors.Surface3,
        outline = VColors.Outline,
        outlineVariant = VColors.Outline,
        error = VColors.Danger,
    )
    MaterialTheme(colorScheme = scheme, typography = Typography()) {
        CompositionLocalProvider(LocalContentColor provides VColors.Text, content = content)
    }
}
