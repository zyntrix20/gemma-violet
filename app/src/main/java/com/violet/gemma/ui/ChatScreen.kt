package com.violet.gemma.ui

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AddPhotoAlternate
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.ChatBubbleOutline
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.violet.gemma.data.ChatMessage
import com.violet.gemma.data.ChatSession
import com.violet.gemma.data.Role
import com.violet.gemma.ui.theme.VBrush
import com.violet.gemma.ui.theme.VColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@Composable
fun ChatScreen(vm: ChatViewModel) {
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var showSettings by remember { mutableStateOf(false) }

    BackHandler(enabled = drawerState.isOpen) { scope.launch { drawerState.close() } }

    ModalNavigationDrawer(
        drawerState = drawerState,
        scrimColor = Color.Black.copy(alpha = 0.55f),
        drawerContent = {
            ChatDrawer(
                vm,
                onPick = { id -> vm.selectChat(id); scope.launch { drawerState.close() } },
                onNew = { vm.newChat(); scope.launch { drawerState.close() } },
            )
        },
    ) {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            TopBar(vm, onMenu = { scope.launch { drawerState.open() } }, onSettings = { showSettings = true })
            Box(Modifier.weight(1f).fillMaxWidth()) {
                val session = vm.current
                val empty = session == null || (session.messages.isEmpty() && !vm.generating)
                Crossfade(targetState = empty to session?.id, animationSpec = tween(380), label = "chat") { (isEmpty, _) ->
                    if (isEmpty) EmptyState(onPick = { vm.send(it) }) else MessageList(vm)
                }
            }
            AnimatedVisibility(
                visible = vm.errorText != null,
                enter = expandVertically() + fadeIn(),
                exit = shrinkVertically() + fadeOut(),
            ) { ErrorBanner(vm.errorText ?: "", onClose = vm::clearError) }
            InputBar(vm)
        }
    }

    if (showSettings) SettingsSheet(vm, onDismiss = { showSettings = false })
}

// ---------------- Верхняя панель ----------------

@Composable
private fun TopBar(vm: ChatViewModel, onMenu: () -> Unit, onSettings: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().height(62.dp).padding(horizontal = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onMenu) { Icon(Icons.Rounded.Menu, "Меню", tint = VColors.Text) }
        Column(Modifier.weight(1f).padding(start = 2.dp)) {
            AnimatedContent(
                targetState = vm.current?.title ?: "Новый чат",
                transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(150)) },
                label = "title",
            ) { t ->
                Text(t, color = VColors.Text, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                PulseDot(if (vm.generating) VColors.Pink else VColors.Online)
                Spacer(Modifier.width(6.dp))
                Text(
                    if (vm.generating) "печатает…" else "Gemma 4 E2B · ${vm.backendInfo}",
                    color = VColors.Muted, fontSize = 12.sp, maxLines = 1,
                )
            }
        }
        IconButton(onClick = vm::newChat, enabled = vm.current != null) {
            Icon(Icons.Rounded.EditNote, "Новый чат", tint = if (vm.current != null) VColors.Text else VColors.Faint)
        }
        IconButton(onClick = onSettings) { Icon(Icons.Rounded.Tune, "Настройки", tint = VColors.Text) }
    }
}

// ---------------- Пустой экран ----------------

private val suggestions = listOf(
    "✍️" to "Напиши короткое стихотворение о ночном космосе",
    "💡" to "Объясни квантовые компьютеры простыми словами",
    "🚀" to "Придумай 5 необычных идей для стартапа",
    "🧑‍💻" to "Напиши функцию на Python для проверки палиндрома",
)

@Composable
private fun EmptyState(onPick: (String) -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 22.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            GlowOrb(118.dp)
            Spacer(Modifier.height(18.dp))
            Text("Чем могу помочь?", style = TextStyle(brush = VBrush.Title, fontSize = 28.sp, fontWeight = FontWeight.SemiBold))
            Spacer(Modifier.height(6.dp))
            Text(
                "Gemma работает офлайн прямо на вашем телефоне",
                color = VColors.Muted, fontSize = 14.sp, textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(26.dp))
            suggestions.forEachIndexed { i, (emoji, text) ->
                StaggerIn(i) { SuggestionCard(emoji, text) { onPick(text) } }
                Spacer(Modifier.height(10.dp))
            }
        }
    }
}

@Composable
private fun SuggestionCard(emoji: String, text: String, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val s by animateFloatAsState(if (pressed) 0.97f else 1f, spring(dampingRatio = 0.5f, stiffness = 700f), label = "sc")
    Row(
        Modifier
            .fillMaxWidth()
            .graphicsLayer { scaleX = s; scaleY = s }
            .clip(RoundedCornerShape(18.dp))
            .background(VColors.Surface2.copy(alpha = 0.72f))
            .border(1.dp, VColors.Outline, RoundedCornerShape(18.dp))
            .clickable(interactionSource = interaction, indication = androidx.compose.material3.ripple()) { onClick() }
            .padding(horizontal = 16.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(emoji, fontSize = 20.sp)
        Spacer(Modifier.width(12.dp))
        Text(text, color = VColors.Text, fontSize = 14.5.sp, lineHeight = 20.sp)
    }
}

// ---------------- Сообщения ----------------

@Composable
private fun MessageList(vm: ChatViewModel) {
    val session = vm.current ?: return
    val msgs = session.messages
    val listState = rememberLazyListState()
    val seen = remember(session.id) { mutableSetOf<String>() }
    val scope = rememberCoroutineScope()
    val showDown by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 300 } }

    LaunchedEffect(msgs.size) {
        if (listState.firstVisibleItemIndex <= 1) listState.animateScrollToItem(0)
    }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            reverseLayout = true,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            if (vm.generating) {
                item(key = vm.streamingId) {
                    Appear(vm.streamingId, seen) { StreamingMessage(vm.streamingText) }
                }
            }
            val reversed = msgs.asReversed()
            items(reversed.size, key = { reversed[it].id }) { i ->
                val m = reversed[i]
                Appear(m.id, seen) {
                    if (m.role == Role.USER) UserBubble(m)
                    else ModelMessage(m, isLast = i == 0 && !vm.generating, haptics = vm.settings.haptics, onRegenerate = vm::regenerate)
                }
            }
        }

        AnimatedVisibility(
            visible = showDown,
            enter = fadeIn() + scaleIn(initialScale = 0.6f),
            exit = fadeOut() + scaleOut(targetScale = 0.6f),
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 10.dp),
        ) {
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(VColors.Surface3)
                    .border(1.dp, VColors.Outline, CircleShape)
                    .clickable { scope.launch { listState.animateScrollToItem(0) } },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.KeyboardArrowDown, "Вниз", tint = VColors.Text) }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Suppress("DEPRECATION")
@Composable
private fun UserBubble(m: ChatMessage) {
    val clipboard = LocalClipboardManager.current
    val ctx = LocalContext.current
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.End) {
        m.imagePath?.let {
            ImageThumb(it)
            Spacer(Modifier.height(6.dp))
        }
        if (m.text.isNotBlank()) {
            Box(
                Modifier
                    .widthIn(max = 310.dp)
                    .clip(RoundedCornerShape(22.dp, 22.dp, 6.dp, 22.dp))
                    .background(VBrush.UserBubble)
                    .combinedClickable(
                        onClick = {},
                        onLongClick = {
                            clipboard.setText(AnnotatedString(m.text))
                            Toast.makeText(ctx, "Скопировано", Toast.LENGTH_SHORT).show()
                        },
                    )
                    .padding(horizontal = 16.dp, vertical = 11.dp)
            ) {
                Text(m.text, color = Color.White, fontSize = 15.5.sp, lineHeight = 22.sp)
            }
        }
    }
}

@Composable
private fun ModelHeader(active: Boolean) {
    val t = rememberInfiniteTransition(label = "hdr")
    val rot by t.animateFloat(0f, 360f, infiniteRepeatable(tween(2200, easing = LinearEasing)), label = "rot")
    val glow by t.animateFloat(0.4f, 1f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "g")
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(26.dp)
                .drawBehind {
                    if (active) drawCircle(VColors.Primary.copy(alpha = 0.35f * glow), radius = size.minDimension * 0.75f)
                }
                .clip(CircleShape)
                .background(VBrush.Primary),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Rounded.AutoAwesome, null, tint = Color.White,
                modifier = Modifier.size(14.dp).graphicsLayer { rotationZ = if (active) rot else 0f },
            )
        }
        Spacer(Modifier.width(9.dp))
        Text("Gemma", color = VColors.Muted, fontSize = 13.sp, fontWeight = FontWeight.Medium)
    }
}

@Suppress("DEPRECATION")
@Composable
private fun ModelMessage(m: ChatMessage, isLast: Boolean, haptics: Boolean, onRegenerate: () -> Unit) {
    val clipboard = LocalClipboardManager.current
    val haptic = LocalHapticFeedback.current
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(copied) { if (copied) { delay(1600); copied = false } }

    Column(Modifier.fillMaxWidth()) {
        ModelHeader(active = false)
        Spacer(Modifier.height(8.dp))
        MarkdownText(m.text)
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            ActionChip(
                icon = if (copied) Icons.Rounded.Check else Icons.Rounded.ContentCopy,
                label = if (copied) "Скопировано" else "Копировать",
            ) {
                clipboard.setText(AnnotatedString(m.text))
                if (haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                copied = true
            }
            if (isLast) ActionChip(Icons.Rounded.Refresh, "Ещё раз") {
                if (haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onRegenerate()
            }
        }
    }
}

@Composable
private fun ActionChip(icon: ImageVector, label: String, onClick: () -> Unit) {
    Row(
        Modifier
            .clip(RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AnimatedContent(targetState = icon, transitionSpec = { scaleIn() + fadeIn() togetherWith scaleOut() + fadeOut() }, label = "ic") { ic ->
            Icon(ic, null, tint = VColors.Faint, modifier = Modifier.size(15.dp))
        }
        Spacer(Modifier.width(5.dp))
        Text(label, color = VColors.Faint, fontSize = 12.sp)
    }
}

@Composable
private fun StreamingMessage(text: String) {
    Column(Modifier.fillMaxWidth()) {
        ModelHeader(active = true)
        Spacer(Modifier.height(8.dp))
        AnimatedContent(
            targetState = text.isEmpty(),
            transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(120)) },
            label = "stream",
        ) { empty ->
            if (empty) TypingIndicator() else MarkdownText(text)
        }
    }
}

@Composable
private fun ErrorBanner(text: String, onClose: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(VColors.Danger.copy(alpha = 0.12f))
            .border(1.dp, VColors.Danger.copy(alpha = 0.35f), RoundedCornerShape(14.dp))
            .padding(start = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.ErrorOutline, null, tint = VColors.Danger, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, color = VColors.Text, fontSize = 13.sp, modifier = Modifier.weight(1f), maxLines = 3, overflow = TextOverflow.Ellipsis)
        IconButton(onClick = onClose) { Icon(Icons.Rounded.Close, "Закрыть", tint = VColors.Muted) }
    }
}

// ---------------- Поле ввода ----------------

@Composable
private fun InputBar(vm: ChatViewModel) {
    var text by rememberSaveable { mutableStateOf("") }
    var focused by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) vm.attachImage(uri)
    }
    val glow by animateFloatAsState(if (focused) 1f else 0f, tween(350), label = "glow")
    val canSend = (text.isNotBlank() || vm.pendingImage != null) && !vm.generating
    val shape = RoundedCornerShape(28.dp)

    Column(
        Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .imePadding()
            .padding(start = 12.dp, end = 12.dp, top = 6.dp, bottom = 10.dp)
    ) {
        AnimatedVisibility(
            visible = vm.pendingImage != null,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut(),
        ) {
            val p = vm.pendingImage
            Box(Modifier.padding(start = 6.dp, bottom = 8.dp)) {
                if (p != null) ImageThumb(p, width = 92.dp)
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.6f))
                        .clickable { vm.removeImage() },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Rounded.Close, "Убрать", tint = Color.White, modifier = Modifier.size(14.dp)) }
            }
        }

        Row(
            Modifier
                .fillMaxWidth()
                .clip(shape)
                .background(VColors.Surface2.copy(alpha = 0.94f))
                .border(
                    1.dp,
                    Brush.linearGradient(
                        listOf(
                            VColors.Primary.copy(alpha = 0.18f + 0.62f * glow),
                            VColors.Pink.copy(alpha = 0.10f + 0.45f * glow),
                        )
                    ),
                    shape,
                )
                .padding(6.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            AnimatedVisibility(visible = vm.visionAvailable) {
                IconButton(onClick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) {
                    Icon(Icons.Rounded.AddPhotoAlternate, "Фото", tint = VColors.Muted)
                }
            }
            BasicTextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 10.dp, vertical = 12.dp)
                    .onFocusChanged { focused = it.isFocused },
                textStyle = TextStyle(color = VColors.Text, fontSize = 16.sp, lineHeight = 22.sp),
                cursorBrush = SolidColor(VColors.Primary),
                maxLines = 6,
                decorationBox = { inner ->
                    Box {
                        if (text.isEmpty()) Text("Спросите что-нибудь…", color = VColors.Faint, fontSize = 16.sp)
                        inner()
                    }
                },
            )
            SendButton(
                active = canSend,
                generating = vm.generating,
                onSend = {
                    if (vm.settings.haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    vm.send(text)
                    text = ""
                },
                onStop = vm::stop,
            )
        }
    }
}

@Composable
private fun SendButton(active: Boolean, generating: Boolean, onSend: () -> Unit, onStop: () -> Unit) {
    val on = active || generating
    val s by animateFloatAsState(if (on) 1f else 0.86f, spring(dampingRatio = 0.45f, stiffness = 500f), label = "s")
    val bg by animateColorAsState(if (on) VColors.PrimaryDeep else VColors.Surface3, tween(250), label = "bg")
    val t = rememberInfiniteTransition(label = "ring")
    val rot by t.animateFloat(0f, 360f, infiniteRepeatable(tween(1100, easing = LinearEasing)), label = "r")
    Box(
        Modifier
            .size(44.dp)
            .graphicsLayer { scaleX = s; scaleY = s }
            .drawBehind {
                if (generating) {
                    drawArc(
                        brush = Brush.sweepGradient(listOf(Color.Transparent, VColors.Accent, VColors.Pink)),
                        startAngle = rot, sweepAngle = 280f, useCenter = false,
                        style = Stroke(width = 2.5.dp.toPx()),
                    )
                }
            }
            .padding(if (generating) 4.dp else 0.dp)
            .clip(CircleShape)
            .background(if (on && !generating) VBrush.Primary else SolidColor(bg))
            .clickable(enabled = on) { if (generating) onStop() else onSend() },
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(
            targetState = generating,
            transitionSpec = {
                (scaleIn(initialScale = 0.4f) + fadeIn()) togetherWith (scaleOut(targetScale = 0.4f) + fadeOut())
            },
            label = "send",
        ) { gen ->
            if (gen) Box(Modifier.size(12.dp).clip(RoundedCornerShape(3.dp)).background(Color.White))
            else Icon(Icons.Rounded.ArrowUpward, "Отправить", tint = if (on) Color.White else VColors.Faint, modifier = Modifier.size(22.dp))
        }
    }
}

// ---------------- Боковое меню с чатами ----------------

@Composable
private fun ChatDrawer(vm: ChatViewModel, onPick: (String) -> Unit, onNew: () -> Unit) {
    var renameTarget by remember { mutableStateOf<ChatSession?>(null) }
    var deleteTarget by remember { mutableStateOf<ChatSession?>(null) }

    ModalDrawerSheet(
        drawerContainerColor = VColors.Surface,
        drawerContentColor = VColors.Text,
        modifier = Modifier.width(312.dp),
    ) {
        Column(Modifier.fillMaxHeight().statusBarsPadding().navigationBarsPadding().padding(horizontal = 14.dp)) {
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                GlowOrb(40.dp)
                Spacer(Modifier.width(10.dp))
                Column {
                    Text("Gemma Violet", color = VColors.Text, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text("на устройстве · офлайн", color = VColors.Muted, fontSize = 12.sp)
                }
            }
            Spacer(Modifier.height(18.dp))
            GradientButton("Новый чат", Icons.Rounded.Add, height = 48.dp, onClick = onNew)
            Spacer(Modifier.height(20.dp))
            Text("ИСТОРИЯ", color = VColors.Faint, fontSize = 11.sp, letterSpacing = 1.5.sp, modifier = Modifier.padding(start = 6.dp))
            Spacer(Modifier.height(8.dp))
            if (vm.sessions.isEmpty()) {
                Text("Здесь появятся ваши чаты", color = VColors.Faint, fontSize = 13.sp, modifier = Modifier.padding(6.dp))
            }
            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                items(vm.sessions, key = { it.id }) { s ->
                    DrawerItem(
                        s,
                        selected = s.id == vm.currentId,
                        modifier = Modifier.animateItem(),
                        onClick = { onPick(s.id) },
                        onRename = { renameTarget = s },
                        onDelete = { deleteTarget = s },
                    )
                }
            }
        }
    }

    renameTarget?.let { s ->
        var title by remember(s.id) { mutableStateOf(s.title) }
        AlertDialog(
            onDismissRequest = { renameTarget = null },
            containerColor = VColors.Surface2,
            title = { Text("Переименовать чат", color = VColors.Text, fontWeight = FontWeight.SemiBold) },
            text = {
                OutlinedTextField(
                    value = title, onValueChange = { title = it }, singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = VColors.Primary, unfocusedBorderColor = VColors.Outline,
                        focusedTextColor = VColors.Text, unfocusedTextColor = VColors.Text, cursorColor = VColors.Primary,
                    ),
                )
            },
            confirmButton = {
                TextButton(onClick = { vm.renameChat(s.id, title); renameTarget = null }) { Text("Сохранить", color = VColors.Primary) }
            },
            dismissButton = { TextButton(onClick = { renameTarget = null }) { Text("Отмена", color = VColors.Muted) } },
        )
    }
    deleteTarget?.let { s ->
        ConfirmDialog(
            title = "Удалить чат?",
            text = "«${s.title}» будет удалён без возможности восстановления.",
            confirm = "Удалить",
            onConfirm = { vm.deleteChat(s.id) },
            onDismiss = { deleteTarget = null },
        )
    }
}

@Composable
private fun DrawerItem(
    s: ChatSession,
    selected: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
    onRename: () -> Unit,
    onDelete: () -> Unit,
) {
    var menu by remember { mutableStateOf(false) }
    val bg by animateColorAsState(if (selected) VColors.Surface3 else Color.Transparent, tween(250), label = "bg")
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(start = 12.dp, top = 4.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.ChatBubbleOutline, null, tint = if (selected) VColors.Accent else VColors.Faint, modifier = Modifier.size(17.dp))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(s.title, color = VColors.Text, fontSize = 14.5.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(relativeDate(s.updated), color = VColors.Faint, fontSize = 11.5.sp)
        }
        Box {
            IconButton(onClick = { menu = true }) { Icon(Icons.Rounded.MoreVert, "Ещё", tint = VColors.Faint) }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(
                    text = { Text("Переименовать") },
                    leadingIcon = { Icon(Icons.Rounded.Edit, null) },
                    onClick = { menu = false; onRename() },
                )
                DropdownMenuItem(
                    text = { Text("Удалить", color = VColors.Danger) },
                    leadingIcon = { Icon(Icons.Rounded.DeleteOutline, null, tint = VColors.Danger) },
                    onClick = { menu = false; onDelete() },
                )
            }
        }
    }
}

private fun relativeDate(ts: Long): String {
    val now = Calendar.getInstance()
    val c = Calendar.getInstance().apply { timeInMillis = ts }
    val sameDay = now.get(Calendar.YEAR) == c.get(Calendar.YEAR) && now.get(Calendar.DAY_OF_YEAR) == c.get(Calendar.DAY_OF_YEAR)
    val ru = Locale.forLanguageTag("ru")
    return if (sameDay) "Сегодня, " + SimpleDateFormat("HH:mm", ru).format(Date(ts))
    else SimpleDateFormat("d MMM, HH:mm", ru).format(Date(ts))
}
