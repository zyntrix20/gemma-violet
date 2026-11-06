package com.violet.gemma.ui

import android.os.Build
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
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
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.violet.gemma.data.ChatMessage
import com.violet.gemma.data.ChatSession
import com.violet.gemma.data.Role
import com.violet.gemma.ui.theme.VColors
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Calendar

@Composable
fun ChatScreen(vm: ChatViewModel) {
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    var showSettings by remember { mutableStateOf(false) }

    BackHandler(enabled = drawerState.isOpen) { scope.launch { drawerState.close() } }

    ModalNavigationDrawer(
        drawerState = drawerState,
        scrimColor = Color.Black.copy(alpha = 0.5f),
        drawerContent = {
            ChatDrawer(
                vm,
                onPick = { id -> vm.selectChat(id); scope.launch { drawerState.close() } },
                onNew = { vm.newChat(); scope.launch { drawerState.close() } },
                onSettings = { scope.launch { drawerState.close() }; showSettings = true },
            )
        },
    ) {
        Column(Modifier.fillMaxSize().background(VColors.Bg).statusBarsPadding()) {
            TopBar(vm, onMenu = { scope.launch { drawerState.open() } }, onSettings = { showSettings = true })
            Box(Modifier.weight(1f).fillMaxWidth()) {
                val session = vm.current
                val empty = session == null || (session.messages.isEmpty() && !vm.generating)
                Crossfade(targetState = empty to session?.id, animationSpec = tween(220), label = "chat") { (isEmpty, _) ->
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
    Column {
        Row(
            Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onMenu) { Icon(Icons.Rounded.Menu, "Меню", tint = VColors.Text) }
            Column(Modifier.weight(1f).padding(start = 2.dp)) {
                Text(
                    vm.current?.title ?: APP_NAME,
                    color = VColors.Text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    StatusDot(if (vm.generating) VColors.Accent else VColors.Online)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        if (vm.generating) "отвечает…" else "офлайн · ${vm.backendInfo}",
                        color = VColors.Faint, fontSize = 12.sp, maxLines = 1,
                    )
                }
            }
            IconButton(onClick = vm::newChat, enabled = vm.current != null) {
                Icon(Icons.Rounded.Add, "Новый чат", tint = if (vm.current != null) VColors.Text else VColors.Faint)
            }
            IconButton(onClick = onSettings) { Icon(Icons.Rounded.Settings, "Настройки", tint = VColors.Muted) }
        }
        HorizontalDivider(color = VColors.Outline.copy(alpha = 0.6f))
    }
}

// ---------------- Пустой экран ----------------

private val suggestions = listOf(
    "Объясни, как работает HTTPS",
    "Составь план тренировок на неделю",
    "Напиши функцию на Kotlin для сортировки списка",
    "Помоги придумать название для кофейни",
)

@Composable
private fun EmptyState(onPick: (String) -> Unit) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 28.dp),
    ) {
        Logo(40.dp)
        Spacer(Modifier.height(18.dp))
        Text("Чем займёмся?", color = VColors.Text, fontSize = 26.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(6.dp))
        Text(
            "Пишите на любом языке. Можно прикрепить фото.",
            color = VColors.Muted, fontSize = 14.5.sp,
        )
        Spacer(Modifier.height(28.dp))
        Text("Попробуйте", color = VColors.Faint, fontSize = 12.5.sp, fontWeight = FontWeight.Medium)
        Spacer(Modifier.height(10.dp))
        suggestions.forEachIndexed { i, text ->
            StaggerIn(i) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .border(1.dp, VColors.Outline, RoundedCornerShape(12.dp))
                        .clickable { onPick(text) }
                        .padding(horizontal = 14.dp, vertical = 13.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(text, color = VColors.Text, fontSize = 14.sp, modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Rounded.ArrowForward, null, tint = VColors.Faint, modifier = Modifier.size(16.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
        }
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
    val showDown by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 || listState.firstVisibleItemScrollOffset > 400 } }

    LaunchedEffect(msgs.size) {
        if (listState.firstVisibleItemIndex <= 1) listState.animateScrollToItem(0)
    }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            reverseLayout = true,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
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
            enter = fadeIn() + scaleIn(initialScale = 0.8f),
            exit = fadeOut() + scaleOut(targetScale = 0.8f),
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 8.dp),
        ) {
            Box(
                Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(VColors.Surface2)
                    .border(1.dp, VColors.Outline, CircleShape)
                    .clickable { scope.launch { listState.animateScrollToItem(0) } },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.KeyboardArrowDown, "Вниз", tint = VColors.Text, modifier = Modifier.size(20.dp)) }
        }
    }
}

private fun copyToast(ctx: android.content.Context) {
    // На Android 13+ система сама показывает уведомление о копировании
    if (Build.VERSION.SDK_INT < 33) Toast.makeText(ctx, "Скопировано", Toast.LENGTH_SHORT).show()
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
                    .widthIn(max = 300.dp)
                    .clip(RoundedCornerShape(18.dp, 18.dp, 4.dp, 18.dp))
                    .background(VColors.Surface2)
                    .combinedClickable(
                        onClick = {},
                        onLongClick = {
                            clipboard.setText(AnnotatedString(m.text))
                            copyToast(ctx)
                        },
                    )
                    .padding(horizontal = 14.dp, vertical = 10.dp)
            ) {
                Text(m.text, color = VColors.Text, fontSize = 15.sp, lineHeight = 21.sp)
            }
        }
    }
}

@Composable
private fun ModelHeader(active: Boolean) {
    val t = rememberInfiniteTransition(label = "hdr")
    val a by t.animateFloat(0.45f, 1f, infiniteRepeatable(tween(700), RepeatMode.Reverse), label = "a")
    Row(verticalAlignment = Alignment.CenterVertically) {
        Logo(20.dp, Modifier.graphicsLayer { alpha = if (active) a else 1f })
        Spacer(Modifier.width(8.dp))
        Text(APP_NAME, color = VColors.Muted, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Suppress("DEPRECATION")
@Composable
private fun ModelMessage(m: ChatMessage, isLast: Boolean, haptics: Boolean, onRegenerate: () -> Unit) {
    val clipboard = LocalClipboardManager.current
    val haptic = LocalHapticFeedback.current
    val ctx = LocalContext.current
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(copied) { if (copied) { delay(1500); copied = false } }

    Column(Modifier.fillMaxWidth()) {
        ModelHeader(active = false)
        Spacer(Modifier.height(8.dp))
        MarkdownText(m.text)
        Row(Modifier.padding(top = 2.dp), verticalAlignment = Alignment.CenterVertically) {
            SmallAction(if (copied) Icons.Rounded.Check else Icons.Rounded.ContentCopy, "Копировать") {
                clipboard.setText(AnnotatedString(m.text))
                if (haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                copyToast(ctx)
                copied = true
            }
            if (isLast) SmallAction(Icons.Rounded.Refresh, "Ответить заново") {
                if (haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                onRegenerate()
            }
        }
    }
}

@Composable
private fun SmallAction(icon: ImageVector, description: String, onClick: () -> Unit) {
    Box(
        Modifier
            .size(34.dp)
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(
            targetState = icon,
            transitionSpec = { fadeIn(tween(150)) togetherWith fadeOut(tween(100)) },
            label = "ic",
        ) { ic -> Icon(ic, description, tint = VColors.Faint, modifier = Modifier.size(16.dp)) }
    }
}

@Composable
private fun StreamingMessage(text: String) {
    Column(Modifier.fillMaxWidth()) {
        ModelHeader(active = true)
        Spacer(Modifier.height(8.dp))
        if (text.isEmpty()) TypingIndicator() else MarkdownText(text)
    }
}

@Composable
private fun ErrorBanner(text: String, onClose: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(VColors.Danger.copy(alpha = 0.08f))
            .border(1.dp, VColors.Danger.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
            .padding(start = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Rounded.ErrorOutline, null, tint = VColors.Danger, modifier = Modifier.size(17.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, color = VColors.Text, fontSize = 13.sp, modifier = Modifier.weight(1f), maxLines = 3, overflow = TextOverflow.Ellipsis)
        IconButton(onClick = onClose) { Icon(Icons.Rounded.Close, "Закрыть", tint = VColors.Muted, modifier = Modifier.size(18.dp)) }
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
    val border by animateColorAsState(if (focused) VColors.Primary else VColors.Outline, tween(200), label = "border")
    val hasInput = text.isNotBlank() || vm.pendingImage != null
    val shape = RoundedCornerShape(20.dp)

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
            Box(Modifier.padding(start = 4.dp, bottom = 8.dp)) {
                if (p != null) ImageThumb(p, width = 84.dp)
                Box(
                    Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp)
                        .size(22.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.65f))
                        .clickable { vm.removeImage() },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Rounded.Close, "Убрать", tint = Color.White, modifier = Modifier.size(13.dp)) }
            }
        }

        Row(
            Modifier
                .fillMaxWidth()
                .clip(shape)
                .background(VColors.Surface2)
                .border(1.dp, border, shape)
                .padding(5.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            if (vm.visionAvailable) {
                IconButton(onClick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) {
                    Icon(Icons.Rounded.Image, "Прикрепить фото", tint = VColors.Muted)
                }
            } else {
                Spacer(Modifier.width(8.dp))
            }
            BasicTextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 6.dp, vertical = 12.dp)
                    .onFocusChanged { focused = it.isFocused },
                textStyle = TextStyle(color = VColors.Text, fontSize = 15.5.sp, lineHeight = 21.sp),
                cursorBrush = SolidColor(VColors.Accent),
                maxLines = 6,
                decorationBox = { inner ->
                    Box {
                        if (text.isEmpty()) Text("Сообщение", color = VColors.Faint, fontSize = 15.5.sp)
                        inner()
                    }
                },
            )
            SendButton(
                enabled = hasInput || vm.generating,
                generating = vm.generating,
                onSend = {
                    if (vm.settings.haptics) haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    if (vm.send(text)) text = ""
                },
                onStop = vm::stop,
            )
        }
    }
}

@Composable
private fun SendButton(enabled: Boolean, generating: Boolean, onSend: () -> Unit, onStop: () -> Unit) {
    val bg by animateColorAsState(if (enabled) VColors.Primary else VColors.Surface3, tween(180), label = "bg")
    Box(
        Modifier
            .padding(2.dp)
            .size(40.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .clickable(enabled = enabled) { if (generating) onStop() else onSend() },
        contentAlignment = Alignment.Center,
    ) {
        AnimatedContent(
            targetState = generating,
            transitionSpec = { (fadeIn(tween(150)) + scaleIn(initialScale = 0.7f)) togetherWith fadeOut(tween(100)) },
            label = "send",
        ) { gen ->
            if (gen) Box(Modifier.size(11.dp).clip(RoundedCornerShape(2.dp)).background(Color.White))
            else Icon(Icons.Rounded.ArrowUpward, "Отправить", tint = if (enabled) Color.White else VColors.Faint, modifier = Modifier.size(20.dp))
        }
    }
}

// ---------------- Боковое меню ----------------

private fun dayGroup(ts: Long): String {
    val now = Calendar.getInstance()
    val c = Calendar.getInstance().apply { timeInMillis = ts }
    val sameYear = now.get(Calendar.YEAR) == c.get(Calendar.YEAR)
    val diff = now.get(Calendar.DAY_OF_YEAR) - c.get(Calendar.DAY_OF_YEAR)
    return when {
        sameYear && diff == 0 -> "Сегодня"
        sameYear && diff == 1 -> "Вчера"
        sameYear && diff < 7 -> "На этой неделе"
        else -> "Ранее"
    }
}

@Composable
private fun ChatDrawer(vm: ChatViewModel, onPick: (String) -> Unit, onNew: () -> Unit, onSettings: () -> Unit) {
    var renameTarget by remember { mutableStateOf<ChatSession?>(null) }
    var deleteTarget by remember { mutableStateOf<ChatSession?>(null) }
    val groups = vm.sessions.groupBy { dayGroup(it.updated) }

    ModalDrawerSheet(
        drawerContainerColor = VColors.Bg,
        drawerContentColor = VColors.Text,
        drawerShape = RoundedCornerShape(topEnd = 20.dp, bottomEnd = 20.dp),
        modifier = Modifier.width(300.dp),
    ) {
        Column(Modifier.fillMaxHeight().statusBarsPadding().navigationBarsPadding()) {
            Row(Modifier.padding(start = 18.dp, end = 12.dp, top = 16.dp, bottom = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                Logo(28.dp)
                Spacer(Modifier.width(10.dp))
                Text(APP_NAME, color = VColors.Text, fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.weight(1f))
            }
            OutlineButton("Новый чат", Icons.Rounded.Add, modifier = Modifier.padding(horizontal = 12.dp), height = 44.dp, onClick = onNew)
            Spacer(Modifier.height(12.dp))

            if (vm.sessions.isEmpty()) {
                Text(
                    "Чатов пока нет",
                    color = VColors.Faint, fontSize = 13.sp,
                    modifier = Modifier.padding(horizontal = 18.dp, vertical = 8.dp),
                )
            }
            LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(horizontal = 8.dp)) {
                groups.forEach { (group, list) ->
                    item(key = "h_$group") {
                        Text(
                            group, color = VColors.Faint, fontSize = 12.sp, fontWeight = FontWeight.Medium,
                            modifier = Modifier.animateItem().padding(start = 10.dp, top = 14.dp, bottom = 6.dp),
                        )
                    }
                    items(list, key = { it.id }) { s ->
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
            HorizontalDivider(color = VColors.Outline.copy(alpha = 0.6f))
            Row(
                Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onSettings)
                    .padding(horizontal = 18.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Settings, null, tint = VColors.Muted, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(12.dp))
                Text("Настройки", color = VColors.Text, fontSize = 14.5.sp)
            }
        }
    }

    renameTarget?.let { s ->
        var title by remember(s.id) { mutableStateOf(s.title) }
        AlertDialog(
            onDismissRequest = { renameTarget = null },
            containerColor = VColors.Surface2,
            shape = RoundedCornerShape(18.dp),
            title = { Text("Название чата", color = VColors.Text, fontWeight = FontWeight.SemiBold, fontSize = 18.sp) },
            text = {
                OutlinedTextField(
                    value = title, onValueChange = { title = it }, singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = VColors.Primary, unfocusedBorderColor = VColors.Outline,
                        focusedTextColor = VColors.Text, unfocusedTextColor = VColors.Text, cursorColor = VColors.Accent,
                    ),
                )
            },
            confirmButton = {
                TextButton(onClick = { vm.renameChat(s.id, title); renameTarget = null }) { Text("Сохранить", color = VColors.Accent) }
            },
            dismissButton = { TextButton(onClick = { renameTarget = null }) { Text("Отмена", color = VColors.Muted) } },
        )
    }
    deleteTarget?.let { s ->
        ConfirmDialog(
            title = "Удалить чат?",
            text = "«${s.title}» удалится насовсем.",
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
    val bg by animateColorAsState(if (selected) VColors.Surface2 else Color.Transparent, tween(180), label = "bg")
    Row(
        modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(start = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            s.title,
            color = if (selected) VColors.Text else VColors.Muted,
            fontSize = 14.sp,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Box {
            IconButton(onClick = { menu = true }) { Icon(Icons.Rounded.MoreHoriz, "Ещё", tint = VColors.Faint, modifier = Modifier.size(18.dp)) }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(
                    text = { Text("Переименовать") },
                    leadingIcon = { Icon(Icons.Rounded.Edit, null, modifier = Modifier.size(18.dp)) },
                    onClick = { menu = false; onRename() },
                )
                DropdownMenuItem(
                    text = { Text("Удалить", color = VColors.Danger) },
                    leadingIcon = { Icon(Icons.Rounded.DeleteOutline, null, tint = VColors.Danger, modifier = Modifier.size(18.dp)) },
                    onClick = { menu = false; onDelete() },
                )
            }
        }
    }
}
