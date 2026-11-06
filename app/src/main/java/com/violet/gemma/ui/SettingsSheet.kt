package com.violet.gemma.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material.icons.rounded.Psychology
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.violet.gemma.data.AppSettings
import com.violet.gemma.data.DEFAULT_SYSTEM_PROMPT
import com.violet.gemma.ui.theme.VBrush
import com.violet.gemma.ui.theme.VColors
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsSheet(vm: ChatViewModel, onDismiss: () -> Unit) {
    var draft by remember { mutableStateOf(vm.settings) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var confirmModel by remember { mutableStateOf(false) }
    var confirmChats by remember { mutableStateOf(false) }

    fun apply() {
        vm.updateSettings(draft)
        onDismiss()
    }

    ModalBottomSheet(
        onDismissRequest = { apply() },
        sheetState = sheetState,
        containerColor = VColors.Bg,
        scrimColor = Color.Black.copy(alpha = 0.55f),
        dragHandle = { BottomSheetDefaults.DragHandle(color = VColors.Outline) },
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .navigationBarsPadding()
                .padding(bottom = 24.dp)
        ) {
            Text("Настройки", color = VColors.Text, fontSize = 22.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(16.dp))

            // Карточка модели
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(VColors.Surface2)
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Logo(40.dp)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(APP_NAME, color = VColors.Text, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                    Text("Gemma 4 E2B · ${vm.backendInfo.ifBlank { "—" }}", color = VColors.Muted, fontSize = 12.5.sp)
                }
            }

            Section("Ускорение")
            Segmented(listOf("GPU", "CPU"), draft.backend) { draft = draft.copy(backend = it) }
            Hint("GPU обычно в 2–4 раза быстрее. Если модель не запускается — выберите CPU.")

            Section("Возможности")
            SwitchRow(Icons.Rounded.Psychology, "Режим размышления", "Модель думает перед ответом: точнее, но медленнее", draft.thinking) {
                draft = draft.copy(thinking = it)
            }
            SwitchRow(Icons.Rounded.Visibility, "Понимание изображений", "Прикрепляйте фото к сообщениям", draft.vision) {
                draft = draft.copy(vision = it)
            }
            SwitchRow(Icons.Rounded.Vibration, "Тактильный отклик", null, draft.haptics) {
                draft = draft.copy(haptics = it)
            }

            Section("Генерация")
            SliderRow("Температура", draft.temperature, 0f..2f, "%.2f") { draft = draft.copy(temperature = it) }
            Hint("Ниже — точнее и предсказуемее, выше — креативнее.")
            SliderRow("Top-K", draft.topK.toFloat(), 1f..100f, "%.0f") { draft = draft.copy(topK = it.roundToInt()) }
            SliderRow("Top-P", draft.topP, 0.05f..1f, "%.2f") { draft = draft.copy(topP = it) }

            Section("Системный промпт")
            OutlinedTextField(
                value = draft.systemPrompt,
                onValueChange = { draft = draft.copy(systemPrompt = it) },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
                maxLines = 8,
                shape = RoundedCornerShape(16.dp),
                colors = fieldColors(),
            )
            TextButton(onClick = { draft = draft.copy(systemPrompt = DEFAULT_SYSTEM_PROMPT) }) {
                Text("Вернуть стандартный", color = VColors.Primary, fontSize = 13.sp)
            }

            Section("Токен Hugging Face")
            OutlinedTextField(
                value = draft.hfToken,
                onValueChange = { draft = draft.copy(hfToken = it.trim()) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                placeholder = { Text("hf_… (необязательно)", color = VColors.Faint) },
                visualTransformation = PasswordVisualTransformation(),
                shape = RoundedCornerShape(16.dp),
                colors = fieldColors(),
            )
            Hint("Нужен, только если Hugging Face не отдаёт файл без авторизации.")

            Spacer(Modifier.height(22.dp))
            PrimaryButton("Готово", Icons.Rounded.Check) {
                scope.launch { sheetState.hide() }.invokeOnCompletion { apply() }
            }
            Spacer(Modifier.height(10.dp))
            TextButton(onClick = { draft = AppSettings(hfToken = draft.hfToken) }, modifier = Modifier.fillMaxWidth()) {
                Text("Сбросить настройки", color = VColors.Muted)
            }

            Section("Данные")
            DangerRow(Icons.Rounded.DeleteSweep, "Очистить все чаты") { confirmChats = true }
            Spacer(Modifier.height(8.dp))
            DangerRow(Icons.Rounded.DeleteForever, "Удалить модель с устройства (~2.6 ГБ)") { confirmModel = true }

            Spacer(Modifier.height(20.dp))
            Text(
                "$APP_NAME ${com.violet.gemma.BuildConfig.VERSION_NAME}",
                color = VColors.Faint, fontSize = 12.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
            )
        }
    }

    if (confirmChats) ConfirmDialog(
        "Очистить все чаты?", "Вся история переписки будет удалена.", "Очистить",
        onConfirm = { vm.clearAllChats() }, onDismiss = { confirmChats = false },
    )
    if (confirmModel) ConfirmDialog(
        "Удалить модель?", "Файл модели будет удалён. Чтобы снова пользоваться приложением, её нужно скачать заново.", "Удалить",
        onConfirm = { vm.deleteModel(); onDismiss() }, onDismiss = { confirmModel = false },
    )
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = VColors.Primary,
    unfocusedBorderColor = VColors.Outline,
    focusedTextColor = VColors.Text,
    unfocusedTextColor = VColors.Text,
    cursorColor = VColors.Primary,
    focusedContainerColor = VColors.Surface2,
    unfocusedContainerColor = VColors.Surface2,
)

@Composable
private fun Section(title: String) {
    Spacer(Modifier.height(24.dp))
    Text(title, color = VColors.Muted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    Spacer(Modifier.height(10.dp))
}

@Composable
private fun Hint(text: String) {
    Text(text, color = VColors.Faint, fontSize = 12.sp, lineHeight = 16.sp, modifier = Modifier.padding(top = 6.dp, start = 2.dp))
}

@Composable
private fun Segmented(options: List<String>, selected: String, onSelect: (String) -> Unit) {
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(15.dp))
            .background(VColors.Surface2)
            .padding(4.dp)
    ) {
        val w = maxWidth / options.size
        val idx = options.indexOf(selected).coerceAtLeast(0)
        val x by animateDpAsState(w * idx, spring(dampingRatio = 0.7f, stiffness = 420f), label = "seg")
        Box(
            Modifier
                .offset(x = x)
                .width(w)
                .fillMaxHeight()
                .clip(RoundedCornerShape(12.dp))
                .background(VBrush.Primary)
        )
        Row(Modifier.fillMaxSize()) {
            options.forEach { o ->
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { onSelect(o) },
                    contentAlignment = Alignment.Center,
                ) {
                    Text(o, color = if (o == selected) Color.White else VColors.Muted, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun SwitchRow(icon: ImageVector, title: String, subtitle: String?, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .clickable { onChange(!checked) }
            .padding(vertical = 10.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(36.dp).clip(RoundedCornerShape(11.dp)).background(VColors.Surface3),
            contentAlignment = Alignment.Center,
        ) { Icon(icon, null, tint = VColors.Accent, modifier = Modifier.size(19.dp)) }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, color = VColors.Text, fontSize = 15.sp)
            if (subtitle != null) Text(subtitle, color = VColors.Faint, fontSize = 12.sp, lineHeight = 16.sp)
        }
        Spacer(Modifier.width(8.dp))
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = VColors.Primary,
                checkedBorderColor = VColors.Primary,
                uncheckedThumbColor = VColors.Muted,
                uncheckedTrackColor = VColors.Surface3,
                uncheckedBorderColor = VColors.Outline,
            ),
        )
    }
}

@Composable
private fun SliderRow(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    format: String,
    onChange: (Float) -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(top = 4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, color = VColors.Text, fontSize = 15.sp, modifier = Modifier.weight(1f))
            Text(
                String.format(Locale.US, format, value),
                color = VColors.Accent, fontFamily = FontFamily.Monospace, fontSize = 14.sp,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(VColors.Surface3)
                    .padding(horizontal = 8.dp, vertical = 3.dp),
            )
        }
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            colors = SliderDefaults.colors(
                thumbColor = VColors.Accent,
                activeTrackColor = VColors.Primary,
                inactiveTrackColor = VColors.Surface3,
            ),
        )
    }
}

@Composable
private fun DangerRow(icon: ImageVector, text: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, VColors.Outline, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = VColors.Danger, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(12.dp))
        Text(text, color = VColors.Danger, fontSize = 14.5.sp)
    }
}
