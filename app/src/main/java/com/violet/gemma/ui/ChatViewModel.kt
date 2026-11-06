package com.violet.gemma.ui

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.violet.gemma.data.AppSettings
import com.violet.gemma.data.ChatMessage
import com.violet.gemma.data.ChatSession
import com.violet.gemma.data.ChatStore
import com.violet.gemma.data.ModelDownloader
import com.violet.gemma.data.Role
import com.violet.gemma.data.SettingsStore
import com.violet.gemma.llm.LlmEngine
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import kotlin.math.max

enum class Phase { SETUP, LOADING, READY }

data class DownloadUi(
    val active: Boolean = false,
    val importing: Boolean = false,
    val downloaded: Long = 0L,
    val total: Long = 0L,
    val speed: Long = 0L,
    val error: String? = null,
)

class ChatViewModel(app: Application) : AndroidViewModel(app) {
    private val ctx = app
    private val store = ChatStore(app)
    private val settingsStore = SettingsStore(app)
    private val downloader = ModelDownloader(app)
    private val llm = LlmEngine(app)

    @OptIn(ExperimentalCoroutinesApi::class)
    private val ioSerial = Dispatchers.IO.limitedParallelism(1)

    var phase by mutableStateOf(if (downloader.isReady()) Phase.LOADING else Phase.SETUP)
        private set
    var modelPresent by mutableStateOf(downloader.isReady())
        private set
    var download by mutableStateOf(DownloadUi(downloaded = downloader.partialBytes()))
        private set
    var settings by mutableStateOf(settingsStore.load())
        private set
    val sessions = mutableStateListOf<ChatSession>()
    var currentId by mutableStateOf<String?>(null)
        private set
    var generating by mutableStateOf(false)
        private set
    var streamingText by mutableStateOf("")
        private set
    var streamingId by mutableStateOf("")
        private set
    var pendingImage by mutableStateOf<String?>(null)
        private set
    var errorText by mutableStateOf<String?>(null)
        private set
    var loadStatus by mutableStateOf("Загружаю модель…")
        private set
    var backendInfo by mutableStateOf("")
        private set
    var visionAvailable by mutableStateOf(false)
        private set

    private var downloadJob: Job? = null
    private var genJob: Job? = null

    // С каким чатом и сколькими сообщениями сейчас синхронизирован диалог движка
    private var convChatId: String? = null
    private var convCount = -1

    val current: ChatSession? get() = sessions.firstOrNull { it.id == currentId }

    init {
        sessions.addAll(store.loadAll())
        if (phase == Phase.LOADING) loadModel()
    }

    // ---------- Модель ----------

    fun loadModel() {
        phase = Phase.LOADING
        errorText = null
        viewModelScope.launch {
            genJob?.cancelAndJoin()
            try {
                loadStatus = "Загружаю модель в память…"
                val info = llm.load(settings, downloader.modelFile.path) { loadStatus = it }
                if (!llm.visionEnabled && settings.vision) pendingImage = null
                backendInfo = info
                visionAvailable = llm.visionEnabled
                convChatId = null
                phase = Phase.READY
            } catch (t: Throwable) {
                errorText = "Не удалось запустить модель: ${t.message ?: t.javaClass.simpleName}"
                phase = Phase.SETUP
            }
        }
    }

    fun startDownload() {
        if (downloadJob?.isActive == true) return
        errorText = null
        download = download.copy(active = true, importing = false, error = null)
        downloadJob = viewModelScope.launch {
            try {
                downloader.download(settings.hfToken.ifBlank { null }) { d, t, s ->
                    download = download.copy(downloaded = d, total = t, speed = s)
                }
                modelPresent = true
                download = DownloadUi()
                loadModel()
            } catch (e: CancellationException) {
                download = download.copy(active = false, speed = 0)
                throw e
            } catch (t: Throwable) {
                download = download.copy(active = false, speed = 0, error = t.message ?: "Ошибка загрузки")
            }
        }
    }

    fun pauseDownload() {
        downloadJob?.cancel()
    }

    fun importModel(uri: Uri) {
        if (downloadJob?.isActive == true) return
        errorText = null
        download = DownloadUi(active = false, importing = true)
        downloadJob = viewModelScope.launch {
            try {
                downloader.importFrom(uri) { d, t, s ->
                    download = download.copy(downloaded = d, total = t, speed = s)
                }
                modelPresent = true
                download = DownloadUi()
                loadModel()
            } catch (e: CancellationException) {
                download = DownloadUi()
                throw e
            } catch (t: Throwable) {
                download = DownloadUi(error = t.message ?: "Ошибка импорта")
            }
        }
    }

    fun deleteModel() {
        viewModelScope.launch {
            genJob?.cancelAndJoin()
            withContext(Dispatchers.Default) { llm.close() }
            withContext(Dispatchers.IO) { downloader.delete() }
            modelPresent = false
            download = DownloadUi()
            convChatId = null
            phase = Phase.SETUP
        }
    }

    // ---------- Настройки ----------

    fun updateSettings(n: AppSettings) {
        val old = settings
        if (n == old) return
        settings = n
        settingsStore.save(n)
        if (phase == Phase.READY && (n.backend != old.backend || n.vision != old.vision)) {
            stop()
            loadModel()
        } else {
            convChatId = null // пересоздать диалог с новыми параметрами
        }
    }

    // ---------- Чаты ----------

    fun newChat() {
        if (generating) stop()
        currentId = null
        pendingImage = null
    }

    fun selectChat(id: String) {
        if (generating) stop()
        currentId = id
    }

    fun renameChat(id: String, title: String) {
        val t = title.trim()
        if (t.isEmpty()) return
        updateSession(id) { it.copy(title = t) }
    }

    fun deleteChat(id: String) {
        if (currentId == id && generating) stop()
        sessions.removeAll { it.id == id }
        if (currentId == id) currentId = null
        if (convChatId == id) convChatId = null
        viewModelScope.launch(ioSerial) { store.delete(id) }
    }

    fun clearAllChats() {
        if (generating) stop()
        sessions.clear()
        currentId = null
        convChatId = null
        viewModelScope.launch(ioSerial) {
            store.deleteAll()
            File(ctx.filesDir, "images").listFiles()?.forEach { it.delete() }
        }
    }

    fun clearError() {
        errorText = null
    }

    fun attachImage(uri: Uri) {
        viewModelScope.launch {
            val path = withContext(Dispatchers.IO) { runCatching { saveImage(uri) }.getOrNull() }
            if (path == null) errorText = "Не удалось открыть изображение" else pendingImage = path
        }
    }

    fun removeImage() {
        pendingImage = null
    }

    // ---------- Генерация ----------

    /** @return true, если сообщение принято (поле ввода можно очистить). */
    fun send(raw: String): Boolean {
        val text = raw.trim()
        if ((text.isEmpty() && pendingImage == null) || generating || phase != Phase.READY) return false
        val now = System.currentTimeMillis()
        val session = current ?: ChatSession(
            id = newId(),
            title = text.take(48).ifBlank { "Изображение" },
            messages = emptyList(),
            updated = now,
        ).also {
            sessions.add(0, it)
            currentId = it.id
        }
        val history = session.messages
        val userMsg = ChatMessage(newId(), Role.USER, text, pendingImage, now)
        pendingImage = null
        updateSession(session.id, moveTop = true) {
            it.copy(messages = it.messages + userMsg, updated = now)
        }
        generate(session.id, history, userMsg)
        return true
    }

    fun regenerate() {
        val s = current ?: return
        if (generating) return
        val msgs = s.messages
        val idx = msgs.indexOfLast { it.role == Role.USER }
        if (idx < 0) return
        val userMsg = msgs[idx]
        updateSession(s.id) { it.copy(messages = msgs.subList(0, idx + 1).toList()) }
        generate(s.id, msgs.subList(0, idx).toList(), userMsg)
    }

    fun stop() {
        llm.cancel()
        genJob?.cancel()
    }

    private fun generate(chatId: String, history: List<ChatMessage>, user: ChatMessage) {
        val replyId = newId()
        streamingId = replyId
        streamingText = ""
        generating = true
        errorText = null
        genJob = viewModelScope.launch {
            val sb = StringBuilder()
            var failure: Throwable? = null
            try {
                if (convChatId != chatId || convCount != history.size) {
                    llm.newConversation(settings, history)
                    convChatId = chatId
                    convCount = history.size
                }
                val prompt = user.text.ifBlank { "Опиши это изображение подробно." }
                llm.send(prompt, user.imagePath, settings.thinking).collect { chunk ->
                    sb.append(chunk)
                    streamingText = sb.toString()
                }
                convCount = history.size + 2
            } catch (e: CancellationException) {
                convChatId = null
            } catch (t: Throwable) {
                failure = t
                convChatId = null
            } finally {
                val text = sb.toString().trim()
                if (text.isNotEmpty()) {
                    val now = System.currentTimeMillis()
                    updateSession(chatId) {
                        it.copy(messages = it.messages + ChatMessage(replyId, Role.MODEL, text, null, now), updated = now)
                    }
                }
                failure?.let { errorText = "Ошибка генерации: ${it.message ?: it.javaClass.simpleName}" }
                generating = false
                streamingText = ""
            }
        }
    }

    // ---------- Вспомогательное ----------

    private fun updateSession(id: String, moveTop: Boolean = false, f: (ChatSession) -> ChatSession) {
        val i = sessions.indexOfFirst { it.id == id }
        if (i < 0) return
        val n = f(sessions[i])
        if (moveTop && i != 0) {
            sessions.removeAt(i); sessions.add(0, n)
        } else {
            sessions[i] = n
        }
        viewModelScope.launch(ioSerial) { runCatching { store.save(n) } }
    }

    private fun newId() = UUID.randomUUID().toString()

    private fun saveImage(uri: Uri): String {
        val cr = ctx.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        cr.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 1024) sample *= 2
        val decoded = cr.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: throw IllegalStateException("decode failed")

        val orientation = runCatching {
            cr.openInputStream(uri)?.use {
                ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            }
        }.getOrNull() ?: ExifInterface.ORIENTATION_NORMAL
        val degrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        val scale = (1024f / max(decoded.width, decoded.height)).coerceAtMost(1f)
        val m = Matrix().apply {
            postScale(scale, scale)
            postRotate(degrees)
        }
        val out = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, m, true)

        val dir = File(ctx.filesDir, "images").apply { mkdirs() }
        val f = File(dir, "img_${System.currentTimeMillis()}.jpg")
        FileOutputStream(f).use { out.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        return f.path
    }

    override fun onCleared() {
        llm.close()
        super.onCleared()
    }
}
