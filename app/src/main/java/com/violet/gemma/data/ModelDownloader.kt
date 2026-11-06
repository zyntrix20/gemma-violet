package com.violet.gemma.data

import android.content.Context
import android.net.Uri
import android.os.StatFs
import android.provider.OpenableColumns
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

object ModelInfo {
    const val FILE_NAME = "gemma-4-E2B-it.litertlm"
    const val REPO = "litert-community/gemma-4-E2B-it-litert-lm"
    const val URL = "https://huggingface.co/$REPO/resolve/main/$FILE_NAME?download=true"
    const val APPROX_SIZE = 2_600_000_000L
}

/**
 * Скачивает модель с Hugging Face с докачкой (HTTP Range) и автоповторами.
 * progress(скачано, всего, скорость байт/с)
 */
class ModelDownloader(private val context: Context) {
    val modelFile = File(context.filesDir, ModelInfo.FILE_NAME)
    private val part = File(context.filesDir, ModelInfo.FILE_NAME + ".part")

    fun isReady(): Boolean = modelFile.exists() && modelFile.length() > 300L * 1024 * 1024
    fun partialBytes(): Long = if (part.exists()) part.length() else 0L
    fun delete() {
        modelFile.delete(); part.delete()
    }

    private fun freeBytes(): Long = StatFs(context.filesDir.path).availableBytes

    suspend fun download(token: String?, progress: (Long, Long, Long) -> Unit) =
        withContext(Dispatchers.IO) {
            var attempt = 0
            while (true) {
                try {
                    downloadOnce(token, progress)
                    break
                } catch (e: CancellationException) {
                    throw e
                } catch (e: IOException) {
                    attempt++
                    if (attempt >= 6) throw IOException("Сеть недоступна: ${e.message}", e)
                    delay(1500L * attempt)
                }
            }
        }

    private suspend fun downloadOnce(token: String?, progress: (Long, Long, Long) -> Unit) {
        var start = part.length()
        val conn = open(ModelInfo.URL, token, start)
        val code = conn.responseCode
        if (code == 416 && start > 0) {
            conn.disconnect(); finish(); return
        }
        if (code != 200 && code != 206) {
            conn.disconnect()
            throw IllegalStateException(
                when (code) {
                    401, 403 -> "Доступ запрещён (HTTP $code). Добавьте токен Hugging Face в настройках."
                    404 -> "Файл модели не найден на Hugging Face (HTTP 404)."
                    else -> "Сервер ответил HTTP $code"
                }
            )
        }
        if (code == 200) start = 0L
        val total = if (code == 206) {
            conn.getHeaderField("Content-Range")?.substringAfter('/')?.toLongOrNull()
                ?: (start + conn.contentLengthLong)
        } else conn.contentLengthLong

        if (total > 0 && freeBytes() < (total - start) + 150L * 1024 * 1024) {
            conn.disconnect()
            throw IllegalStateException(
                "Недостаточно места. Нужно ещё ~${(total - start) / (1024 * 1024)} МБ свободной памяти."
            )
        }

        conn.inputStream.use { input ->
            FileOutputStream(part, code == 206).use { out ->
                copyWithProgress(input, out, start, total, progress)
            }
        }
        conn.disconnect()
        if (total > 0 && part.length() < total) throw IOException("Соединение прервано")
        finish()
    }

    suspend fun importFrom(uri: Uri, progress: (Long, Long, Long) -> Unit) =
        withContext(Dispatchers.IO) {
            val cr = context.contentResolver
            val total = cr.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getLong(0) else -1L } ?: -1L
            part.delete()
            try {
                val input = cr.openInputStream(uri) ?: throw IOException("Не удалось открыть файл")
                input.use { inp ->
                    FileOutputStream(part).use { out -> copyWithProgress(inp, out, 0L, total, progress) }
                }
                if (part.length() < 300L * 1024 * 1024) {
                    throw IllegalStateException("Файл слишком маленький — похоже, это не модель .litertlm")
                }
                finish()
            } catch (t: Throwable) {
                part.delete()
                throw t
            }
        }

    private suspend fun copyWithProgress(
        input: InputStream,
        out: FileOutputStream,
        start: Long,
        total: Long,
        progress: (Long, Long, Long) -> Unit,
    ) {
        val buf = ByteArray(1 shl 17)
        var done = start
        var lastT = System.nanoTime()
        var lastB = done
        var speed = 0L
        progress(done, total, 0L)
        while (true) {
            currentCoroutineContext().ensureActive()
            val n = input.read(buf)
            if (n < 0) break
            out.write(buf, 0, n)
            done += n
            val now = System.nanoTime()
            if (now - lastT > 300_000_000L) {
                val inst = (done - lastB) * 1_000_000_000L / (now - lastT)
                speed = if (speed == 0L) inst else (speed * 7 + inst * 3) / 10
                lastT = now; lastB = done
                progress(done, total, speed)
            }
        }
        progress(done, total, speed)
    }

    private fun finish() {
        if (modelFile.exists()) modelFile.delete()
        if (!part.renameTo(modelFile)) throw IOException("Не удалось сохранить файл модели")
    }

    /** Открывает соединение, вручную следуя редиректам (токен уходит только на huggingface.co). */
    private fun open(url: String, token: String?, from: Long): HttpURLConnection {
        var current = URL(url)
        repeat(10) {
            val c = current.openConnection() as HttpURLConnection
            c.instanceFollowRedirects = false
            c.connectTimeout = 20_000
            c.readTimeout = 60_000
            c.setRequestProperty("User-Agent", "GemmaViolet/1.0 (Android)")
            if (from > 0) c.setRequestProperty("Range", "bytes=$from-")
            if (!token.isNullOrBlank() && current.host.endsWith("huggingface.co")) {
                c.setRequestProperty("Authorization", "Bearer $token")
            }
            val code = c.responseCode
            if (code in 300..399) {
                val loc = c.getHeaderField("Location")
                c.disconnect()
                if (loc.isNullOrBlank()) throw IOException("Пустой редирект")
                current = URL(current, loc)
            } else {
                return c
            }
        }
        throw IOException("Слишком много перенаправлений")
    }
}
