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
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
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
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.violet.gemma.data.ModelInfo
import com.violet.gemma.ui.theme.VBrush
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

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            GlowOrb(170.dp, pulsing = busy)
            Spacer(Modifier.height(26.dp))
            Text(
                "Gemma 4 E2B",
                style = TextStyle(brush = VBrush.Title, fontSize = 34.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp),
            )
            Spacer(Modifier.height(10.dp))
            Text(
                "Мощный ИИ прямо на вашем телефоне.\nБез серверов. Без интернета. Приватно.",
                color = VColors.Muted, fontSize = 15.sp, lineHeight = 22.sp, textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(20.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FeaturePill(Icons.Rounded.WifiOff, "Офлайн")
                FeaturePill(Icons.Rounded.Lock, "Приватно")
                FeaturePill(Icons.Rounded.Visibility, "Видит фото")
            }
            Spacer(Modifier.height(40.dp))

            AnimatedContent(
                targetState = busy,
                transitionSpec = {
                    (fadeIn(tween(400)) + scaleIn(tween(400), initialScale = 0.94f)) togetherWith
                        (fadeOut(tween(200)) + scaleOut(tween(200), targetScale = 0.96f))
                },
                label = "setup",
            ) { isBusy ->
                if (isBusy) {
                    DownloadProgress(d, onCancel = vm::pauseDownload)
                } else {
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        if (vm.modelPresent) {
                            GradientButton("Запустить модель", Icons.Rounded.PlayArrow) { vm.loadModel() }
                            Spacer(Modifier.height(10.dp))
                            TextButton(onClick = vm::deleteModel) {
                                Icon(Icons.Rounded.DeleteOutline, null, tint = VColors.Muted, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("Удалить модель и скачать заново", color = VColors.Muted)
                            }
                        } else {
                            val resume = d.downloaded > 0
                            GradientButton(
                                if (resume) "Продолжить загрузку · ${fmtBytes(d.downloaded)}" else "Скачать модель · ~2.6 ГБ",
                                Icons.Rounded.Download,
                            ) { vm.startDownload() }
                            Spacer(Modifier.height(10.dp))
                            TextButton(onClick = { importer.launch(arrayOf("*/*")) }) {
                                Icon(Icons.Rounded.FolderOpen, null, tint = VColors.Accent, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text("У меня уже есть файл .litertlm", color = VColors.Accent)
                            }
                            Spacer(Modifier.height(8.dp))
                            Text(
                                "Источник: huggingface.co/${ModelInfo.REPO}\nНужно ~3 ГБ свободного места. Лучше по Wi‑Fi.",
                                color = VColors.Faint, fontSize = 12.sp, textAlign = TextAlign.Center, lineHeight = 17.sp,
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
                        .padding(top = 20.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(VColors.Danger.copy(alpha = 0.1f))
                        .border(1.dp, VColors.Danger.copy(alpha = 0.35f), RoundedCornerShape(14.dp))
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Rounded.ErrorOutline, null, tint = VColors.Danger)
                    Spacer(Modifier.width(10.dp))
                    Text(err ?: "", color = VColors.Text, fontSize = 13.5.sp, lineHeight = 19.sp)
                }
            }
        }
    }
}

@Composable
private fun DownloadProgress(d: DownloadUi, onCancel: () -> Unit) {
    val frac = if (d.total > 0) (d.downloaded.toFloat() / d.total).coerceIn(0f, 1f) else 0f
    val anim by animateFloatAsState(frac, tween(450), label = "frac")
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            if (d.total > 0) "${(anim * 100).toInt()}%" else "…",
            style = TextStyle(brush = VBrush.Title, fontSize = 48.sp, fontWeight = FontWeight.Bold),
        )
        Text(if (d.importing) "Импорт модели" else "Скачивание модели", color = VColors.Muted, fontSize = 14.sp)
        Spacer(Modifier.height(20.dp))
        GradientProgressBar(anim, indeterminate = d.total <= 0)
        Spacer(Modifier.height(14.dp))
        Text(
            if (d.total > 0) "${fmtBytes(d.downloaded)} из ${fmtBytes(d.total)}" else fmtBytes(d.downloaded),
            color = VColors.Text, fontSize = 14.sp,
        )
        if (d.speed > 0) {
            val eta = if (d.total > 0) (d.total - d.downloaded) / d.speed.coerceAtLeast(1L) else 0L
            Text(
                "${fmtBytes(d.speed)}/с" + if (d.total > 0) " · осталось ${fmtEta(eta)}" else "",
                color = VColors.Faint, fontSize = 13.sp,
            )
        }
        Spacer(Modifier.height(22.dp))
        OutlinedButton(
            onClick = onCancel,
            border = BorderStroke(1.dp, VColors.Outline),
            shape = RoundedCornerShape(14.dp),
        ) {
            Icon(Icons.Rounded.Pause, null, tint = VColors.Text, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(if (d.importing) "Отменить" else "Пауза", color = VColors.Text)
        }
        Spacer(Modifier.height(8.dp))
        Text("Экран не погаснет, пока идёт загрузка", color = VColors.Faint, fontSize = 12.sp)
    }
}

@Composable
fun LoadingScreen(vm: ChatViewModel) {
    Column(
        Modifier.fillMaxSize().padding(36.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        GlowOrb(190.dp, pulsing = true)
        Spacer(Modifier.height(30.dp))
        AnimatedContent(
            targetState = vm.loadStatus,
            transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(200)) },
            label = "status",
        ) { s ->
            Text(s, style = TextStyle(brush = VBrush.Title, fontSize = 20.sp, fontWeight = FontWeight.SemiBold))
        }
        Spacer(Modifier.height(18.dp))
        GradientProgressBar(0f, indeterminate = true, modifier = Modifier.width(220.dp))
        Spacer(Modifier.height(14.dp))
        Text(
            "Первый запуск может занять до минуты —\nмодель оптимизируется под ваш телефон",
            color = VColors.Faint, fontSize = 13.sp, textAlign = TextAlign.Center, lineHeight = 18.sp,
        )
    }
}
