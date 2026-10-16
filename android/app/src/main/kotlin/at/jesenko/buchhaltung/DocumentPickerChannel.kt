package at.jesenko.buchhaltung

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Datei für einen neuen Beleg wählen (Knopf „Datei“ auf Übersicht und
 * Belegliste, FA-12.1): Bilder, PDF, XML-E-Rechnung über das Storage Access
 * Framework, mehrere erlaubt. Die `content://`-URIs werden hier in den Cache
 * kopiert (Originalname am Ende, damit Dart die Art erkennt); Dart bekommt
 * nur absolute Pfade und behandelt sie wie geteilte Dateien (L-27.4).
 * Leere Liste = abgebrochen, Fehler `io` = Dart zeigt eine Meldung.
 */
class DocumentPickerChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "buchhaltung/document_picker")
    private var pending: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "pick") pick(result) else result.notImplemented()
        }
    }

    private fun pick(result: MethodChannel.Result) {
        pending?.success(emptyList<String>())
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("image/*", "application/pdf", "application/xml", "text/xml"),
            )
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, RequestCodes.DOCUMENT_PICKER)
        } catch (e: Exception) {
            pending = null
            result.error("io", e.message ?: "Dateiauswahl nicht möglich", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != RequestCodes.DOCUMENT_PICKER) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return true
        }
        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
        } else {
            data.data?.let { uris.add(it) }
        }
        val resolver = activity.applicationContext.contentResolver
        val dir = File(activity.cacheDir, "picked").apply { mkdirs() }
        io.execute {
            try {
                val stamp = System.currentTimeMillis()
                val paths = uris.mapIndexed { i, uri ->
                    val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                        ?.use { if (it.moveToFirst()) it.getString(0) else null }
                        ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
                        ?: "datei_$i"
                    val out = File(dir, "${stamp}_${i}_$name")
                    val input = resolver.openInputStream(uri)
                        ?: throw java.io.IOException("Datei ${i + 1} nicht lesbar")
                    input.use { s -> out.outputStream().use { o -> s.copyTo(o) } }
                    out.absolutePath
                }
                main.post { result.success(paths) }
            } catch (e: Exception) {
                main.post { result.error("io", e.message ?: e.toString(), null) }
            }
        }
        return true
    }
}
