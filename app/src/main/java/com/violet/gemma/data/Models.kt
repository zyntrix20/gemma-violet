package com.violet.gemma.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

enum class Role { USER, MODEL }

data class ChatMessage(
    val id: String,
    val role: Role,
    val text: String,
    val imagePath: String? = null,
    val time: Long = System.currentTimeMillis(),
)

data class ChatSession(
    val id: String,
    val title: String,
    val messages: List<ChatMessage>,
    val updated: Long,
)

const val DEFAULT_SYSTEM_PROMPT =
    "Ты — Gemma, дружелюбный и умный ИИ-ассистент. Отвечай на языке пользователя, " +
        "ясно и по делу. Используй Markdown (списки, **жирный**, блоки кода), когда это помогает."

data class AppSettings(
    val backend: String = "GPU",
    val vision: Boolean = true,
    val thinking: Boolean = false,
    val haptics: Boolean = true,
    val temperature: Float = 0.8f,
    val topK: Int = 40,
    val topP: Float = 0.95f,
    val systemPrompt: String = DEFAULT_SYSTEM_PROMPT,
    val hfToken: String = "",
)

/** Хранение чатов: по одному JSON-файлу на чат во внутренней памяти приложения. */
class ChatStore(context: Context) {
    private val dir = File(context.filesDir, "chats").apply { mkdirs() }

    fun loadAll(): List<ChatSession> =
        (dir.listFiles()?.toList() ?: emptyList())
            .filter { it.extension == "json" }
            .mapNotNull { f -> runCatching { fromJson(JSONObject(f.readText())) }.getOrNull() }
            .sortedByDescending { it.updated }

    fun save(s: ChatSession) {
        val tmp = File(dir, "${s.id}.tmp")
        tmp.writeText(toJson(s).toString())
        tmp.renameTo(File(dir, "${s.id}.json"))
    }

    fun delete(id: String) {
        File(dir, "$id.json").delete()
    }

    fun deleteAll() {
        dir.listFiles()?.forEach { it.delete() }
    }

    private fun toJson(s: ChatSession): JSONObject {
        val arr = JSONArray()
        s.messages.forEach { m ->
            arr.put(
                JSONObject()
                    .put("id", m.id)
                    .put("role", m.role.name)
                    .put("text", m.text)
                    .put("image", m.imagePath ?: "")
                    .put("time", m.time)
            )
        }
        return JSONObject()
            .put("id", s.id)
            .put("title", s.title)
            .put("updated", s.updated)
            .put("messages", arr)
    }

    private fun fromJson(o: JSONObject): ChatSession {
        val arr = o.getJSONArray("messages")
        val msgs = (0 until arr.length()).map { i ->
            val m = arr.getJSONObject(i)
            ChatMessage(
                id = m.getString("id"),
                role = Role.valueOf(m.getString("role")),
                text = m.optString("text"),
                imagePath = m.optString("image").ifBlank { null },
                time = m.optLong("time"),
            )
        }
        return ChatSession(o.getString("id"), o.optString("title", "Чат"), msgs, o.optLong("updated"))
    }
}

class SettingsStore(context: Context) {
    private val p = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    fun load(): AppSettings {
        val d = AppSettings()
        return AppSettings(
            backend = p.getString("backend", d.backend) ?: d.backend,
            vision = p.getBoolean("vision", d.vision),
            thinking = p.getBoolean("thinking", d.thinking),
            haptics = p.getBoolean("haptics", d.haptics),
            temperature = p.getFloat("temperature", d.temperature),
            topK = p.getInt("topK", d.topK),
            topP = p.getFloat("topP", d.topP),
            systemPrompt = p.getString("systemPrompt", d.systemPrompt) ?: d.systemPrompt,
            hfToken = p.getString("hfToken", "") ?: "",
        )
    }

    fun save(s: AppSettings) {
        p.edit()
            .putString("backend", s.backend)
            .putBoolean("vision", s.vision)
            .putBoolean("thinking", s.thinking)
            .putBoolean("haptics", s.haptics)
            .putFloat("temperature", s.temperature)
            .putInt("topK", s.topK)
            .putFloat("topP", s.topP)
            .putString("systemPrompt", s.systemPrompt)
            .putString("hfToken", s.hfToken)
            .apply()
    }
}
