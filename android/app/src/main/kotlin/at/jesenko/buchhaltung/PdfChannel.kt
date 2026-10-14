package at.jesenko.buchhaltung

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * PDF-Seiten als Bild (L-27.5) mit dem Android-eigenen PdfRenderer – keine
 * Bibliothek, kein Netz. Die Textebene liest Android vor API 35 nicht aus;
 * deshalb wird jede Seite gerendert und wie ein Foto mit ML Kit erkannt
 * (Rückfall nach Spezifikation FA-2.40). Das Seitenbild ist nur Vorschau und
 * Lesehilfe; aufbewahrt wird die Original-PDF (L-27.8).
 */
class PdfChannel(private val context: Context, messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "buchhaltung/pdf").setMethodCallHandler { call, result ->
            when (call.method) {
                "render" -> {
                    val path = call.argument<String>("path")
                    val maxPages = call.argument<Int>("maxPages") ?: 5
                    if (path == null) {
                        result.error("bad_args", "path fehlt", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val out = render(File(path), maxPages)
                            main.post { result.success(out) }
                        } catch (e: Throwable) {
                            main.post { result.error("pdf_failed", e.toString(), null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun render(file: File, maxPages: Int): Map<String, Any> {
        val dir = File(context.cacheDir, "pdf_pages").apply { mkdirs() }
        val pages = ArrayList<String>()
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { renderer ->
                val count = renderer.pageCount
                for (i in 0 until minOf(count, maxPages)) {
                    renderer.openPage(i).use { page ->
                        // Lange Kante 2000 px wie bei Fotos (FA-2.2).
                        val scale = TARGET_EDGE.toFloat() / maxOf(page.width, page.height)
                        val w = (page.width * scale).toInt().coerceAtLeast(1)
                        val h = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val target = File(dir, "${System.currentTimeMillis()}_${i + 1}.png")
                        target.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                        bitmap.recycle()
                        pages.add(target.absolutePath)
                    }
                }
                return mapOf("pages" to pages, "pageCount" to count, "text" to emptyList<String>())
            }
        }
    }

    companion object {
        const val TARGET_EDGE = 2000
    }
}
