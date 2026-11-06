package com.violet.gemma.ui

import android.graphics.BitmapFactory
import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.violet.gemma.ui.theme.VBrush
import com.violet.gemma.ui.theme.VColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import java.util.Locale

/** Плавно «дышащий» фон с фиолетовыми бликами. */
@Composable
fun AuroraBackground() {
    val t = rememberInfiniteTransition(label = "aurora")
    val a by t.animateFloat(0f, 1f, infiniteRepeatable(tween(17000, easing = LinearEasing), RepeatMode.Reverse), label = "a")
    val b by t.animateFloat(0f, 1f, infiniteRepeatable(tween(23000, easing = LinearEasing), RepeatMode.Reverse), label = "b")
    Canvas(Modifier.fillMaxSize()) {
        drawRect(VColors.Bg)
        val w = size.width
        val h = size.height
        fun blob(cx: Float, cy: Float, r: Float, c: Color) {
            drawCircle(
                Brush.radialGradient(listOf(c, Color.Transparent), center = Offset(cx, cy), radius = r),
                radius = r, center = Offset(cx, cy),
            )
        }
        blob(w * (0.1f + 0.6f * a), h * (0.08f + 0.12f * b), w * 0.95f, Color(0xFF7C3AED).copy(alpha = 0.20f))
        blob(w * (0.95f - 0.5f * b), h * (0.5f + 0.2f * a), w * 0.8f, Color(0xFFC026D3).copy(alpha = 0.09f))
        blob(w * (0.25f + 0.4f * b), h * (1.0f - 0.12f * a), w * 1.0f, Color(0xFF4C1D95).copy(alpha = 0.26f))
    }
}

/** Светящаяся переливающаяся сфера — «лицо» Gemma. */
@Composable
fun GlowOrb(dimension: Dp, pulsing: Boolean = false) {
    val t = rememberInfiniteTransition(label = "orb")
    val rot by t.animateFloat(0f, 360f, infiniteRepeatable(tween(8000, easing = LinearEasing)), label = "rot")
    val pulse by t.animateFloat(
        0.93f, 1.05f,
        infiniteRepeatable(tween(if (pulsing) 800 else 2800, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "pulse",
    )
    Canvas(Modifier.size(dimension)) {
        val r = size.minDimension / 2f
        scale(pulse) {
            drawCircle(
                Brush.radialGradient(
                    listOf(Color(0xFF8B5CF6).copy(alpha = 0.55f), Color(0xFF8B5CF6).copy(alpha = 0.12f), Color.Transparent),
                    center = center, radius = r,
                ),
                radius = r,
            )
            rotate(rot) {
                drawCircle(
                    Brush.sweepGradient(
                        listOf(Color(0xFF7C3AED), Color(0xFFE879F9), Color(0xFF6366F1), Color(0xFFC084FC), Color(0xFF7C3AED)),
                        center = center,
                    ),
                    radius = r * 0.56f,
                )
            }
            drawCircle(
                Brush.radialGradient(
                    listOf(Color.Transparent, Color(0xFF0A0712).copy(alpha = 0.35f)),
                    center = center, radius = r * 0.56f,
                ),
                radius = r * 0.56f,
            )
            val hl = center + Offset(-r * 0.17f, -r * 0.19f)
            drawCircle(
                Brush.radialGradient(listOf(Color.White.copy(alpha = 0.65f), Color.Transparent), center = hl, radius = r * 0.28f),
                radius = r * 0.28f, center = hl,
            )
        }
    }
}

/** Три прыгающие точки «Gemma печатает». */
@Composable
fun TypingIndicator() {
    val t = rememberInfiniteTransition(label = "typing")
    Row(
        Modifier.padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(3) { i ->
            val p by t.animateFloat(
                0f, 1f,
                infiniteRepeatable(tween(520, easing = FastOutSlowInEasing), RepeatMode.Reverse, StartOffset(i * 170)),
                label = "d$i",
            )
            Box(
                Modifier
                    .size(8.dp)
                    .graphicsLayer {
                        translationY = -7.dp.toPx() * p
                        alpha = 0.35f + 0.65f * p
                    }
                    .clip(CircleShape)
                    .background(VColors.Primary)
            )
        }
    }
}

@Composable
fun PulseDot(color: Color) {
    val t = rememberInfiniteTransition(label = "dot")
    val a by t.animateFloat(0.35f, 1f, infiniteRepeatable(tween(1000), RepeatMode.Reverse), label = "a")
    val c by animateColorAsState(color, tween(400), label = "c")
    Box(Modifier.size(7.dp).graphicsLayer { alpha = a }.clip(CircleShape).background(c))
}

/** Главная кнопка с градиентом и пружинным нажатием. */
@Composable
fun GradientButton(
    text: String,
    icon: ImageVector?,
    modifier: Modifier = Modifier,
    height: Dp = 56.dp,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) 0.96f else 1f, spring(dampingRatio = 0.5f, stiffness = 700f), label = "btn")
    val shape = RoundedCornerShape(18.dp)
    Box(
        modifier
            .fillMaxWidth()
            .height(height)
            .graphicsLayer { scaleX = s; scaleY = s }
            .shadow(20.dp, shape, ambientColor = VColors.PrimaryDeep, spotColor = VColors.PrimaryDeep)
            .clip(shape)
            .background(VBrush.Primary)
            .clickable(interactionSource = interaction, indication = ripple(color = Color.White)) { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) {
                Icon(icon, null, tint = Color.White, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(10.dp))
            }
            Text(text, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

/** Прогресс-бар с градиентом и бегущим бликом. */
@Composable
fun GradientProgressBar(fraction: Float, indeterminate: Boolean = false, modifier: Modifier = Modifier) {
    val t = rememberInfiniteTransition(label = "bar")
    val x by t.animateFloat(-0.4f, 1.4f, infiniteRepeatable(tween(1500, easing = LinearEasing)), label = "x")
    val grad = listOf(Color(0xFF7C3AED), Color(0xFFC084FC), Color(0xFFE879F9))
    Canvas(modifier.fillMaxWidth().height(10.dp)) {
        val r = CornerRadius(size.height / 2f)
        drawRoundRect(VColors.Surface3, cornerRadius = r)
        if (indeterminate) {
            val segW = size.width * 0.35f
            val left = size.width * x - segW / 2f
            clipRect {
                drawRoundRect(
                    Brush.horizontalGradient(grad, startX = left, endX = left + segW),
                    topLeft = Offset(left, 0f), size = Size(segW, size.height), cornerRadius = r,
                )
            }
        } else {
            val w = size.width * fraction.coerceIn(0f, 1f)
            if (w > 0f) {
                drawRoundRect(Brush.horizontalGradient(grad, endX = size.width), size = Size(w, size.height), cornerRadius = r)
                val sx = size.width * x
                clipRect(right = w) {
                    drawRect(
                        Brush.horizontalGradient(
                            listOf(Color.Transparent, Color.White.copy(alpha = 0.4f), Color.Transparent),
                            startX = sx - 140f, endX = sx + 140f,
                        ),
                        size = Size(w, size.height),
                    )
                }
            }
        }
    }
}

/** Плавное появление элемента списка (только при первом показе). */
@Composable
fun Appear(id: String, seen: MutableSet<String>, content: @Composable () -> Unit) {
    val first = remember(id) { seen.add(id) }
    val a = remember(id) { Animatable(if (first) 0f else 1f) }
    LaunchedEffect(id) {
        if (a.value < 1f) a.animateTo(1f, spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow))
    }
    Box(
        Modifier.fillMaxWidth().graphicsLayer {
            alpha = a.value
            translationY = (1f - a.value) * 36.dp.toPx()
            val sc = 0.96f + 0.04f * a.value
            scaleX = sc; scaleY = sc
        }
    ) { content() }
}

/** Каскадное появление (для подсказок и т.п.). */
@Composable
fun StaggerIn(index: Int, content: @Composable () -> Unit) {
    val a = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        delay(120L + index * 80L)
        a.animateTo(1f, spring(dampingRatio = 0.75f, stiffness = Spring.StiffnessLow))
    }
    Box(Modifier.fillMaxWidth().graphicsLayer { alpha = a.value; translationY = (1f - a.value) * 28.dp.toPx() }) { content() }
}

@Composable
fun FeaturePill(icon: ImageVector, text: String) {
    Row(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(VColors.Surface2.copy(alpha = 0.8f))
            .border(1.dp, VColors.Outline, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = VColors.Accent, modifier = Modifier.size(15.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, color = VColors.Text, fontSize = 12.5.sp)
    }
}

@Composable
fun ImageThumb(path: String, width: Dp = 210.dp) {
    val bmp by produceState<ImageBitmap?>(null, path) {
        value = withContext(Dispatchers.IO) { runCatching { BitmapFactory.decodeFile(path)?.asImageBitmap() }.getOrNull() }
    }
    val a by animateFloatAsState(if (bmp != null) 1f else 0f, tween(350), label = "img")
    val b = bmp
    if (b != null) {
        val ratio = (b.width.toFloat() / b.height.toFloat()).coerceIn(0.6f, 1.8f)
        Image(
            b, null,
            modifier = Modifier
                .width(width)
                .aspectRatio(ratio)
                .graphicsLayer { alpha = a; val s = 0.92f + 0.08f * a; scaleX = s; scaleY = s }
                .clip(RoundedCornerShape(18.dp))
                .border(1.dp, VColors.Outline, RoundedCornerShape(18.dp)),
            contentScale = ContentScale.Crop,
        )
    }
}

@Composable
fun ConfirmDialog(title: String, text: String, confirm: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = VColors.Surface2,
        titleContentColor = VColors.Text,
        textContentColor = VColors.Muted,
        title = { Text(title, fontWeight = FontWeight.SemiBold) },
        text = { Text(text) },
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
    sec < 3600 -> "${sec / 60} мин ${sec % 60} с"
    else -> "${sec / 3600} ч ${(sec % 3600) / 60} мин"
}
