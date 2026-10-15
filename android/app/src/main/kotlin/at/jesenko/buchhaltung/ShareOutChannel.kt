package at.jesenko.buchhaltung

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Teilen von Exporten (PDF, CSV) über einen eigenen FileProvider (FA-5.35).
//
// share_plus 10 kopiert jede Datei nach cache/share_plus und leert diesen
// Ordner bei JEDEM neuen Teilen (Share.kt, clearShareCacheFolder). Gmail lädt
// Anhänge aber erst beim Senden bzw. im Hintergrund hoch; war die Datei bis
// dahin gelöscht (nächstes Teilen, z. B. Storno nach Rechnung) oder vom System
// aus dem Cache geräumt, kam beim Empfänger „Download fehlgeschlagen“ an
// (Gerätetest 0.13.0). Hier liegt die Datei dauerhaft in filesDir/geteilt und
// wird erst nach 30 Tagen aufgeräumt.
class ShareOutChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val folder: File
        get() = File(activity.filesDir, "geteilt").apply { mkdirs() }

    init {
        MethodChannel(messenger, "buchhaltung/share_out").setMethodCallHandler { call, result ->
            when (call.method) {
                "folder" -> {
                    prune()
                    result.success(folder.absolutePath)
                }
                "share" -> {
                    val path = call.argument<String>("path")
                    val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (path == null) {
                        result.error("argument", "path fehlt", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        val uri = FileProvider.getUriForFile(
                            activity, "${activity.packageName}.geteilt", file
                        )
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            call.argument<String>("subject")?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
                            call.argument<String>("text")?.let { putExtra(Intent.EXTRA_TEXT, it) }
                            // ClipData trägt die Leseberechtigung zuverlässig
                            // durch den Auswahldialog bis zur Ziel-App.
                            clipData = ClipData.newUri(activity.contentResolver, file.name, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(send, null).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        activity.startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("share", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Dateien älter als 30 Tage entfernen (L-19: nichts unnötig aufbewahren). */
    private fun prune() {
        val limit = System.currentTimeMillis() - 30L * 24 * 60 * 60 * 1000
        folder.listFiles()?.forEach { if (it.lastModified() < limit) it.delete() }
    }
}

// Eigene Unterklasse, damit der Eintrag im Manifest nicht mit dem
// FileProvider eines Plugins zusammengeführt wird.
class GeteiltFileProvider : FileProvider()
