package at.jesenko.buchhaltung

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Teilen-Ziel (L-27.4): ACTION_SEND / ACTION_SEND_MULTIPLE mit Bildern, PDF
 * oder XML. Die Inhalte werden sofort in den App-Cache kopiert (die
 * Leseberechtigung der teilenden App gilt nur kurz) und als Pfade an Dart
 * gegeben. Größenlimit je Datei MAX_BYTES; größere werden übersprungen.
 */
class ShareInChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "buchhaltung/share_in")
    private val pending = ArrayList<String>()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> {
                    result.success(ArrayList(pending))
                    pending.clear()
                }
                else -> result.notImplemented()
            }
        }
    }

    fun handle(intent: Intent?) {
        if (intent == null) return
        val uris = ArrayList<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                (intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))?.let { uris.add(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.addAll(it) }
            }
            else -> return
        }
        if (uris.isEmpty()) return
        val dir = File(context.cacheDir, "shared_in").apply { mkdirs() }
        for ((i, uri) in uris.withIndex()) {
            try {
                val name = safeName(displayName(uri) ?: "geteilt", context.contentResolver.getType(uri))
                val target = File(dir, "${System.currentTimeMillis()}_${i}_$name")
                context.contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var total = 0L
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            total += n
                            if (total > MAX_BYTES) throw java.io.IOException("zu groß")
                            output.write(buffer, 0, n)
                        }
                    }
                }
                if (target.length() > 0) pending.add(target.absolutePath) else target.delete()
            } catch (e: Exception) {
                // Nicht lesbar oder zu groß: überspringen, nichts protokollieren.
            }
        }
        // Intent verbrauchen, sonst würde er bei Drehung erneut ausgewertet.
        intent.action = Intent.ACTION_MAIN
        channel.invokeMethod("shared", null)
    }

    private fun displayName(uri: Uri): String? = try {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (e: Exception) {
        null
    }

    /** Nur einfache Zeichen; Endung aus dem MIME-Typ, wenn der Name keine hat. */
    private fun safeName(name: String, mime: String?): String {
        var clean = name.replace(Regex("[^A-Za-z0-9._-]"), "_").take(80)
        if (!clean.contains('.')) {
            clean += when {
                mime == "application/pdf" -> ".pdf"
                mime?.contains("xml") == true -> ".xml"
                mime == "image/png" -> ".png"
                mime?.startsWith("image/") == true -> ".jpg"
                else -> ""
            }
        }
        return clean
    }

    companion object {
        /** 20 MB je Datei; Belege und E-Rechnungen sind weit kleiner. */
        const val MAX_BYTES = 20L * 1024 * 1024
    }
}
