package com.violet.gemma.ui

import android.graphics.BitmapFactory
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.StartOffset
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.violet.gemma.ui.theme.VColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.util.Locale

const val APP_NAME = "SerOAI"

/** Логотип: квадрат Electric Purple с буквой S и точкой Neon Magenta. */
@Composable
fun Logo(size: Dp = 32.dp, modifier: Modifier = Modifier) {
    Box(
        modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.3f))
            .background(VColors.Primary),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "S",
            color = Color.White,
            fontWeight = FontWeight.Black,
            fontFamily = FontFamily.Monospace,
            fontSize = (size.value * 0.55f).sp,
        )
        Box(
            Modifier
                .align(Alignment.BottomEnd)
                .padding(size * 0.14f)
                .size(size * 0.16f)
                .clip(CircleShape)
                .background(VColors.Accent)
        )
    }
}

/** Три точки «печатает». */
@Composable
fun TypingIndicator() {
    val t = rememberInfiniteTransition(label = "typing")
    Row(
        Modifier.padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(3) { i ->
            val p by t.animateFloat(
                0f, 1f,
                infiniteRepeatable(tween(450, easing = FastOutSlowInEasing), RepeatMode.Reverse, StartOffset(i * 150)),
                label = "d$i",
            )
            Box(
                Modifier
                    .size(6.dp)
                    .graphicsLayer {
                        translationY = -4.dp.toPx() * p
                        alpha = 0.3f + 0.7f * p
                    }
                    .clip(CircleShape)
                    .background(VColors.Accent)
            )
        }
    }
}

@Composable
fun StatusDot(color: Color) {
    Box(Modifier.size(6.dp).clip(CircleShape).background(color))
}

/** Основная кнопка. */
@Composable
fun PrimaryButton(
    text: String,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    height: Dp = 52.dp,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) 0.98f else 1f, spring(stiffness = Spring.StiffnessHigh), label = "btn")
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier
            .fillMaxWidth()
            .height(height)
            .graphicsLayer { scaleX = s; scaleY = s }
            .clip(shape)
            .background(VColors.Primary)
            .clickable(interactionSource = interaction, indication = ripple(color = Color.White)) { onClick() },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(text, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Medium)
    }
}

/** Второстепенная кнопка с обводкой. */
@Composable
fun OutlineButton(
    text: String,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    height: Dp = 48.dp,
    tint: Color = VColors.Text,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier
            .fillMaxWidth()
            .height(height)
            .clip(shape)
            .border(BorderStroke(1.dp, VColors.Outline), shape)
            .clickable(onClick = onClick),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(text, color = tint, fontSize = 14.5.sp, fontWeight = FontWeight.Medium)
    }
}

/** Тонкий прогресс-бар. */
@Composable
fun ProgressLine(fraction: Float, indeterminate: Boolean = false, modifier: Modifier = Modifier) {
    val t = rememberInfiniteTransition(label = "bar")
    val x by t.animateFloat(0f, 1f, infiniteRepeatable(tween(1200, easing = LinearEasing)), label = "x")
    Canvas(modifier.fillMaxWidth().height(6.dp)) {
        val r = CornerRadius(size.height / 2f)
        drawRoundRect(VColors.Surface3, cornerRadius = r)
        if (indeterminate) {
            val segW = size.width * 0.3f
            val left = (size.width + segW) * x - segW
            val l = left.coerceAtLeast(0f)
            val rgt = (left + segW).coerceAtMost(size.width)
            if (rgt > l) drawRoundRect(VColors.Accent, topLeft = Offset(l, 0f), size = Size(rgt - l, size.height), cornerRadius = r)
        } else {
            val w = size.width * fraction.coerceIn(0f, 1f)
            if (w > 0f) drawRoundRect(VColors.Primary, size = Size(w, size.height), cornerRadius = r)
        }
    }
}

/** Плавное появление элемента списка (только при первом показе). */
@Composable
fun Appear(id: String, seen: MutableSet<String>, content: @Composable () -> Unit) {
    val first = remember(id) { seen.add(id) }
    val a = remember(id) { Animatable(if (first) 0f else 1f) }
    LaunchedEffect(id) {
        if (a.value < 1f) a.animateTo(1f, tween(260, easing = FastOutSlowInEasing))
    }
    Box(
        Modifier.fillMaxWidth().graphicsLayer {
            alpha = a.value
            translationY = (1f - a.value) * 12.dp.toPx()
        }
    ) { content() }
}

/** Последовательное появление (подсказки на пустом экране). */
@Composable
fun StaggerIn(index: Int, content: @Composable () -> Unit) {
    val a = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(60L + index * 50L)
        a.animateTo(1f, tween(280, easing = FastOutSlowInEasing))
    }
    Box(Modifier.fillMaxWidth().graphicsLayer { alpha = a.value; translationY = (1f - a.value) * 10.dp.toPx() }) { content() }
}

@Composable
fun ImageThumb(path: String, width: Dp = 200.dp) {
    val bmp by produceState<ImageBitmap?>(null, path) {
        value = withContext(Dispatchers.IO) { runCatching { BitmapFactory.decodeFile(path)?.asImageBitmap() }.getOrNull() }
    }
    val b = bmp ?: return
    val ratio = (b.width.toFloat() / b.height.toFloat()).coerceIn(0.6f, 1.8f)
    Image(
        b, null,
        modifier = Modifier
            .width(width)
            .aspectRatio(ratio)
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, VColors.Outline, RoundedCornerShape(14.dp)),
        contentScale = ContentScale.Crop,
    )
}

@Composable
fun ConfirmDialog(title: String, text: String, confirm: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = VColors.Surface2,
        titleContentColor = VColors.Text,
        textContentColor = VColors.Muted,
        shape = RoundedCornerShape(18.dp),
        title = { Text(title, fontWeight = FontWeight.SemiBold, fontSize = 18.sp) },
        text = { Text(text, fontSize = 14.sp) },
        confirmButton = {
            TextButton(onClick = { onConfirm(); onDismiss() }) { Text(confirm, color = VColors.Danger) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Отмена", color = VColors.Muted) }
        },
    )
}

fun fmtBytes(b: Long): String = when {
    b >= 1L shl 30 -> String.format(Locale.US, "%.2f ГБ", b / 1073741824.0)
    b >= 1L shl 20 -> String.format(Locale.US, "%.1f МБ", b / 1048576.0)
    b >= 1024 -> "${b / 1024} КБ"
    else -> "$b Б"
}

fun fmtEta(sec: Long): String = when {
    sec < 60 -> "$sec с"
    sec < 3600 -> "${sec / 60} мин"
    else -> "${sec / 3600} ч ${(sec % 3600) / 60} мин"
}
