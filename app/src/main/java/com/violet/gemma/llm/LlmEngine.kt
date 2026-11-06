package com.violet.gemma.llm

import android.content.Context
import com.google.ai.edge.litertlm.*
import com.violet.gemma.data.AppSettings
import com.violet.gemma.data.ChatMessage
import com.violet.gemma.data.DEFAULT_SYSTEM_PROMPT
import com.violet.gemma.data.Role
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext

/** Обёртка над LiteRT-LM: загрузка Gemma 4 E2B на устройстве и потоковая генерация. */
class LlmEngine(private val context: Context) {
    private var engine: Engine? = null
    private var conversation: Conversation? = null

    var visionEnabled: Boolean = false
        private set

    /** Пробует запустить модель: выбранный бэкенд → CPU → CPU без зрения. Возвращает описание. */
    suspend fun load(s: AppSettings, modelPath: String, onStatus: (String) -> Unit): String =
        withContext(Dispatchers.Default) {
            close()
            val attempts = buildList {
                add(s.backend to s.vision)
                add("CPU" to s.vision)
                if (s.vision) add("CPU" to false)
            }.distinct()

            var last: Throwable? = null
            for ((b, v) in attempts) {
                var e: Engine? = null
                try {
                    onStatus(if (b == "GPU") "Запускаю на GPU…" else "Запускаю на CPU…")
                    val cfg = if (v) {
                        EngineConfig(
                            modelPath = modelPath,
                            backend = backendOf(b),
                            visionBackend = backendOf(b),
                            cacheDir = context.cacheDir.path,
                        )
                    } else {
                        EngineConfig(
                            modelPath = modelPath,
                            backend = backendOf(b),
                            cacheDir = context.cacheDir.path,
                        )
                    }
                    e = Engine(cfg)
                    e.initialize()
                    engine = e
                    visionEnabled = v
                    return@withContext if (v) "$b · зрение" else b
                } catch (t: Throwable) {
                    last = t
                    runCatching { e?.close() }
                }
            }
            throw last ?: IllegalStateException("Не удалось запустить модель")
        }

    private fun backendOf(name: String): Backend = if (name == "GPU") Backend.GPU() else Backend.CPU()

    /** Создаёт новый диалог, восстанавливая историю чата. */
    suspend fun newConversation(s: AppSettings, history: List<ChatMessage>) =
        withContext(Dispatchers.Default) {
            val e = engine ?: throw IllegalStateException("Модель не загружена")
            cancel()
            runCatching { conversation?.close() }
            conversation = null
            // Сообщения только с фото сохраняем как текстовую пометку, чтобы не ломать очерёдность реплик
            val initial = history.map {
                val t = it.text.ifBlank { if (it.imagePath != null) "[изображение]" else "…" }
                if (it.role == Role.USER) Message.user(t) else Message.model(t)
            }
            conversation = e.createConversation(
                ConversationConfig(
                    systemInstruction = Contents.of(s.systemPrompt.ifBlank { DEFAULT_SYSTEM_PROMPT }),
                    initialMessages = initial,
                    samplerConfig = SamplerConfig(
                        topK = s.topK,
                        topP = s.topP.toDouble(),
                        temperature = s.temperature.toDouble(),
                    ),
                )
            )
        }

    /** Потоковый ответ: каждый элемент — новый кусочек текста. */
    fun send(text: String, imagePath: String?, thinking: Boolean): Flow<String> {
        val c = conversation ?: throw IllegalStateException("Диалог не создан")
        val contents = if (imagePath != null && visionEnabled) {
            Contents.of(Content.ImageFile(imagePath), Content.Text(text))
        } else {
            Contents.of(Content.Text(text))
        }
        val flow = if (thinking) {
            c.sendMessageAsync(contents, extraContext = mapOf("enable_thinking" to true))
        } else {
            c.sendMessageAsync(contents)
        }
        return flow.map { it.toString() }.flowOn(Dispatchers.Default)
    }

    /** Останавливает текущую генерацию (если API это поддерживает). */
    fun cancel() {
        val c = conversation ?: return
        runCatching { c.javaClass.getMethod("cancelProcess").invoke(c) }
    }

    fun close() {
        cancel()
        runCatching { conversation?.close() }
        conversation = null
        runCatching { engine?.close() }
        engine = null
        visionEnabled = false
    }
}
