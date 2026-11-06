package com.violet.gemma.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.FolderOpen
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import com.violet.gemma.ui.theme.VColors

@Composable
fun SetupScreen(vm: ChatViewModel) {
    val d = vm.download
    val busy = d.active || d.importing
    val view = LocalView.current
    DisposableEffect(busy) {
        view.keepScreenOn = busy
        onDispose { view.keepScreenOn = false }
    }
    val importer = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) vm.importModel(uri)
    }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 20.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Logo(30.dp)
            Spacer(Modifier.width(10.dp))
            Text(APP_NAME, color = VColors.Text, fontSize = 19.sp, fontWeight = FontWeight.Bold)
        }

        Spacer(Modifier.height(56.dp))
        Text(
            "Ассистент, который\nработает без интернета",
            color = VColors.Text, fontSize = 28.sp, fontWeight = FontWeight.SemiBold, lineHeight = 34.sp,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "Все запросы обрабатываются прямо на телефоне — ничего не уходит на сервер. " +
                "Для работы нужно один раз скачать модель.",
            color = VColors.Muted, fontSize = 15.sp, lineHeight = 22.sp,
        )

        Spacer(Modifier.height(28.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(VColors.Surface2)
                .border(1.dp, VColors.Outline, RoundedCornerShape(16.dp))
        ) {
            InfoRow("Модель", "Gemma 4 E2B-it")
            HorizontalDivider(color = VColors.Outline)
            InfoRow("Размер", "≈ 2.6 ГБ")
            HorizontalDivider(color = VColors.Outline)
            InfoRow("Источник", "Hugging Face")
            HorizontalDivider(color = VColors.Outline)
            InfoRow("Нужно места", "≈ 3 ГБ")
        }

        Spacer(Modifier.height(28.dp))

        AnimatedContent(
            targetState = busy,
            transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(150)) },
            label = "setup",
        ) { isBusy ->
            if (isBusy) {
                DownloadProgress(d, onCancel = vm::pauseDownload)
            } else {
                Column(Modifier.fillMaxWidth()) {
                    if (vm.modelPresent) {
                        PrimaryButton("Запустить", Icons.Rounded.PlayArrow) { vm.loadModel() }
                        Spacer(Modifier.height(10.dp))
                        OutlineButton("Удалить модель и скачать заново", Icons.Rounded.DeleteOutline, tint = VColors.Muted) {
                            vm.deleteModel()
                        }
                    } else {
                        val resume = d.downloaded > 0
                        PrimaryButton(
                            if (resume) "Продолжить (${fmtBytes(d.downloaded)})" else "Скачать модель",
                            Icons.Rounded.Download,
                        ) { vm.startDownload() }
                        Spacer(Modifier.height(10.dp))
                        OutlineButton("Выбрать файл .litertlm", Icons.Rounded.FolderOpen) {
                            importer.launch(arrayOf("*/*"))
                        }
                        Spacer(Modifier.height(12.dp))
                        Text(
                            "Лучше качать по Wi‑Fi. Если связь оборвётся, загрузка продолжится с того же места.",
                            color = VColors.Faint, fontSize = 12.5.sp, lineHeight = 17.sp,
                        )
                    }
                }
            }
        }

        val err = d.error ?: vm.errorText
        AnimatedVisibility(
            visible = err != null && !busy,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically(),
        ) {
            Row(
                Modifier
                    .padding(top = 16.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(VColors.Danger.copy(alpha = 0.08f))
                    .border(1.dp, VColors.Danger.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                    .padding(12.dp),
            ) {
                Icon(Icons.Rounded.ErrorOutline, null, tint = VColors.Danger, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(10.dp))
                Text(err ?: "", color = VColors.Text, fontSize = 13.sp, lineHeight = 18.sp)
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = VColors.Muted, fontSize = 14.sp, modifier = Modifier.weight(1f))
        Text(value, color = VColors.Text, fontSize = 14.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun DownloadProgress(d: DownloadUi, onCancel: () -> Unit) {
    val frac = if (d.total > 0) (d.downloaded.toFloat() / d.total).coerceIn(0f, 1f) else 0f
    val anim by animateFloatAsState(frac, tween(400), label = "frac")
    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                if (d.importing) "Копирую файл" else "Скачиваю модель",
                color = VColors.Text, fontSize = 15.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f),
            )
            Text(
                if (d.total > 0) "${(anim * 100).toInt()}%" else "",
                color = VColors.Accent, fontSize = 15.sp, fontFamily = FontFamily.Monospace,
            )
        }
        Spacer(Modifier.height(12.dp))
        ProgressLine(anim, indeterminate = d.total <= 0)
        Spacer(Modifier.height(10.dp))
        Row {
            Text(
                if (d.total > 0) "${fmtBytes(d.downloaded)} / ${fmtBytes(d.total)}" else fmtBytes(d.downloaded),
                color = VColors.Muted, fontSize = 12.5.sp, fontFamily = FontFamily.Monospace, modifier = Modifier.weight(1f),
            )
            if (d.speed > 0) {
                val eta = if (d.total > 0) (d.total - d.downloaded) / d.speed.coerceAtLeast(1L) else 0L
                Text(
                    "${fmtBytes(d.speed)}/с" + if (d.total > 0) " · ${fmtEta(eta)}" else "",
                    color = VColors.Muted, fontSize = 12.5.sp, fontFamily = FontFamily.Monospace,
                )
            }
        }
        Spacer(Modifier.height(20.dp))
        OutlineButton(if (d.importing) "Отменить" else "Пауза", Icons.Rounded.Pause, onClick = onCancel)
        Spacer(Modifier.height(10.dp))
        Text(
            "Не закрывайте приложение до конца загрузки.",
            color = VColors.Faint, fontSize = 12.5.sp,
        )
    }
}

@Composable
fun LoadingScreen(vm: ChatViewModel) {
    val t = rememberInfiniteTransition(label = "load")
    val p by t.animateFloat(0.9f, 1f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "p")
    Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Logo(52.dp, Modifier.graphicsLayer { scaleX = p; scaleY = p })
            Spacer(Modifier.height(24.dp))
            AnimatedContent(
                targetState = vm.loadStatus,
                transitionSpec = { fadeIn(tween(200)) togetherWith fadeOut(tween(150)) },
                label = "status",
            ) { s -> Text(s, color = VColors.Text, fontSize = 16.sp, fontWeight = FontWeight.Medium) }
            Spacer(Modifier.height(16.dp))
            ProgressLine(0f, indeterminate = true, modifier = Modifier.width(160.dp))
            Spacer(Modifier.height(14.dp))
            Text(
                "Первый запуск дольше обычного —\nдо минуты.",
                color = VColors.Faint, fontSize = 13.sp, textAlign = TextAlign.Center, lineHeight = 18.sp,
            )
        }
    }
}
