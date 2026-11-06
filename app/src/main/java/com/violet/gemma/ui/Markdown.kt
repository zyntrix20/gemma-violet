package com.violet.gemma.ui

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.violet.gemma.ui.theme.VColors
import kotlinx.coroutines.delay

private sealed interface Md {
    data class Para(val text: String) : Md
    data class Heading(val level: Int, val text: String) : Md
    data class Code(val lang: String, val code: String) : Md
    data class Item(val marker: String, val text: String, val indent: Int) : Md
    data class Quote(val text: String) : Md
    data object Rule : Md
}

private val bulletRe = Regex("^(\\s*)([-*+•]|\\d+[.)])\\s+(.*)$")
private val ruleRe = Regex("^(-{3,}|\\*{3,}|_{3,})$")

private fun parse(src: String): List<Md> {
    val out = mutableListOf<Md>()
    val lines = src.lines()
    val para = StringBuilder()
    fun flush() {
        if (para.isNotBlank()) out += Md.Para(para.toString().trim())
        para.clear()
    }
    var i = 0
    while (i < lines.size) {
        val line = lines[i]
        val t = line.trim()
        val hashes = t.takeWhile { it == '#' }.length
        val bullet = bulletRe.find(line)
        when {
            t.startsWith("```") -> {
                flush()
                val lang = t.removePrefix("```").trim()
                val sb = StringBuilder()
                i++
                while (i < lines.size && !lines[i].trim().startsWith("```")) {
                    if (sb.isNotEmpty()) sb.append('\n')
                    sb.append(lines[i]); i++
                }
                out += Md.Code(lang, sb.toString())
            }
            hashes in 1..6 && t.getOrNull(hashes) == ' ' -> {
                flush(); out += Md.Heading(hashes, t.substring(hashes + 1).trim())
            }
            ruleRe.matches(t) -> { flush(); out += Md.Rule }
            bullet != null -> {
                flush()
                val (indent, marker, text) = bullet.destructured
                val m = if (marker.first().isDigit()) marker else "•"
                out += Md.Item(m, text, indent.length / 2)
            }
            t.startsWith(">") -> { flush(); out += Md.Quote(t.removePrefix(">").trim()) }
            t.isEmpty() -> flush()
            else -> {
                if (para.isNotEmpty()) para.append('\n')
                para.append(t)
            }
        }
        i++
    }
    flush()
    return out
}

private fun inline(s: String): AnnotatedString = buildAnnotatedString {
    var i = 0
    while (i < s.length) {
        val c = s[i]
        if (c == '`') {
            val end = s.indexOf('`', i + 1)
            if (end > i) {
                withStyle(
                    SpanStyle(fontFamily = FontFamily.Monospace, background = VColors.Surface3, color = VColors.Accent, fontSize = 0.9.em)
                ) { append(" ${s.substring(i + 1, end)} ") }
                i = end + 1; continue
            }
        }
        if (s.startsWith("**", i)) {
            val end = s.indexOf("**", i + 2)
            if (end > i + 2) {
                withStyle(SpanStyle(fontWeight = FontWeight.SemiBold, color = Color.White)) { append(inline(s.substring(i + 2, end))) }
                i = end + 2; continue
            }
        }
        if (c == '*' && i + 1 < s.length && s[i + 1] != ' ') {
            val end = s.indexOf('*', i + 1)
            if (end > i + 1) {
                withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(inline(s.substring(i + 1, end))) }
                i = end + 1; continue
            }
        }
        if (c == '[') {
            val mid = s.indexOf("](", i)
            val end = if (mid > 0) s.indexOf(')', mid) else -1
            if (mid > i && end > mid) {
                withStyle(SpanStyle(color = VColors.Primary, textDecoration = TextDecoration.Underline)) { append(s.substring(i + 1, mid)) }
                i = end + 1; continue
            }
        }
        append(c); i++
    }
}

@Composable
fun MarkdownText(text: String, modifier: Modifier = Modifier) {
    val blocks = remember(text) { parse(text) }
    SelectionContainer(modifier) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            blocks.forEach { b ->
                when (b) {
                    is Md.Para -> Text(inline(b.text), color = VColors.Text, fontSize = 15.5.sp, lineHeight = 23.sp)
                    is Md.Heading -> Text(
                        inline(b.text),
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = when (b.level) { 1 -> 22.sp; 2 -> 19.sp; else -> 17.sp },
                        lineHeight = 26.sp,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                    is Md.Item -> Row(Modifier.padding(start = (b.indent * 16).dp)) {
                        Text(
                            b.marker,
                            color = VColors.Primary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.5.sp,
                            lineHeight = 23.sp,
                            modifier = Modifier.width(if (b.marker == "•") 16.dp else 24.dp),
                        )
                        Text(inline(b.text), color = VColors.Text, fontSize = 15.5.sp, lineHeight = 23.sp)
                    }
                    is Md.Quote -> Row {
                        Box(Modifier.width(3.dp).height(22.dp).clip(RoundedCornerShape(2.dp)).background(VColors.Primary))
                        Spacer(Modifier.width(10.dp))
                        Text(inline(b.text), color = VColors.Muted, fontStyle = FontStyle.Italic, fontSize = 15.sp, lineHeight = 22.sp)
                    }
                    is Md.Code -> CodeBlock(b.lang, b.code)
                    Md.Rule -> Box(Modifier.fillMaxWidth().height(1.dp).background(VColors.Outline))
                }
            }
        }
    }
}

@Suppress("DEPRECATION")
@Composable
private fun CodeBlock(lang: String, code: String) {
    val clipboard = LocalClipboardManager.current
    val ctx = LocalContext.current
    var copied by remember { mutableStateOf(false) }
    LaunchedEffect(copied) { if (copied) { delay(1500); copied = false } }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(VColors.CodeBg)
            .border(1.dp, VColors.Outline, RoundedCornerShape(14.dp))
    ) {
        Row(
            Modifier.fillMaxWidth().background(VColors.Surface2).padding(start = 14.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(lang.ifBlank { "код" }, color = VColors.Muted, fontSize = 12.sp, fontFamily = FontFamily.Monospace, modifier = Modifier.weight(1f))
            Row(
                Modifier.clip(RoundedCornerShape(8.dp)).clickable {
                    clipboard.setText(AnnotatedString(code)); copied = true
                    Toast.makeText(ctx, "Код скопирован", Toast.LENGTH_SHORT).show()
                }.padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(if (copied) Icons.Rounded.Check else Icons.Rounded.ContentCopy, null, tint = VColors.Muted, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(if (copied) "Готово" else "Копировать", color = VColors.Muted, fontSize = 12.sp)
            }
        }
        Text(
            code,
            color = Color(0xFFE9E3FF),
            fontFamily = FontFamily.Monospace,
            fontSize = 13.sp,
            lineHeight = 19.sp,
            softWrap = false,
            modifier = Modifier.horizontalScroll(rememberScrollState()).padding(14.dp),
        )
    }
}
