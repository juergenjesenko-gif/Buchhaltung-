package at.jesenko.buchhaltung

import android.app.Activity
import android.content.Intent
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Dokumentenscanner des Systems für Belege und Verträge (Spezifikation
 * FA-2.51): Google ML Kit Document Scanner über Google Play-Dienste, voller
 * Modus mit Filtern und Schattenentfernung, mehrere Seiten, Import aus der
 * Galerie erlaubt. Die Seiten (JPEG, entzerrt und verbessert) werden in den
 * Cache kopiert; Dart legt sie im Belegspeicher ab. Gespeichert wird nur das
 * verarbeitete Bild (Entscheidung Auftraggeberin 2026-10-16, P-S63).
 *
 * Ergebnis von `scan`: Liste von Pfaden; leere Liste = abgebrochen;
 * Fehler `unavailable` = kein Scanner (keine Play-Dienste, Modul-Download
 * fehlgeschlagen) → Dart nimmt ohne Rückfrage die Kamera.
 */
class DocumentScannerChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "buchhaltung/document_scanner")
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scan" -> scan(call.argument<Int>("pageLimit") ?: 20, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun scanner(pageLimit: Int): GmsDocumentScanner = GmsDocumentScanning.getClient(
        GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(pageLimit)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
    )

    private fun scan(pageLimit: Int, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "Scanner läuft bereits", null)
            return
        }
        pending = result
        try {
            scanner(pageLimit).getStartScanIntent(activity)
                .addOnSuccessListener { sender ->
                    try {
                        @Suppress("DEPRECATION")
                        activity.startIntentSenderForResult(sender, REQUEST, null, 0, 0, 0)
                    } catch (e: Exception) {
                        finishError(e.message)
                    }
                }
                .addOnFailureListener { e -> finishError(e.message) }
        } catch (e: Exception) {
            finishError(e.message)
        }
    }

    private fun finishError(message: String?) {
        pending?.error("unavailable", message, null)
        pending = null
    }

    /** Aus `MainActivity.onActivityResult`. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(emptyList<String>())
            return true
        }
        try {
            val scan = GmsDocumentScanningResult.fromActivityResultIntent(data)
            val dir = File(activity.cacheDir, "scanner").apply { mkdirs() }
            val stamp = System.currentTimeMillis()
            val paths = scan?.pages.orEmpty().mapIndexed { i, page ->
                val out = File(dir, "scan_${stamp}_$i.jpg")
                activity.contentResolver.openInputStream(page.imageUri).use { input ->
                    out.outputStream().use { output -> input!!.copyTo(output) }
                }
                out.absolutePath
            }
            result.success(paths)
        } catch (e: Exception) {
            result.error("io", e.message, null)
        }
        return true
    }

    companion object {
        private const val REQUEST = 4711
    }
}
