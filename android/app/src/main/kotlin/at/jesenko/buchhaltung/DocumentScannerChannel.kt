package at.jesenko.buchhaltung

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Dokumentenscanner des Systems für Belege und Verträge (Spezifikation
 * FA-2.51): Google ML Kit Document Scanner über Google Play-Dienste, voller
 * Modus, mehrere Seiten, Import aus der Galerie erlaubt. Die Seiten (JPEG,
 * entzerrt) werden im Hintergrund in den Cache kopiert; Dart verbessert sie
 * (Kontrast, Papier aufhellen) und legt nur das verarbeitete Bild ab
 * (Entscheidung Auftraggeberin 2026-10-16, P-S63).
 *
 * Ergebnis von `scan`: Liste absoluter Pfade auf JPEG-Kopien im App-Cache
 * (die `file://`/`content://`-URIs von ML Kit werden hier kopiert, Dart
 * bekommt nie eine URI); leere Liste = abgebrochen; Fehler `io`/`lost` =
 * Dart zeigt eine Meldung;
 * Fehler `unavailable` = kein Scanner (keine Play-Dienste, Modul-Download
 * fehlgeschlagen) → Dart nimmt ohne Rückfrage die Kamera.
 *
 * Gerätetest 0.21.0 (Pixel): nach dem ersten Scan blieb der Scanner bis zum
 * Neustart gesperrt, weil eine offene Antwort (`pending`) nie abgeschlossen
 * wurde und jeder weitere Aufruf mit `busy` endete, das Dart still als
 * „abgebrochen“ las. Deshalb jetzt:
 * - jede Antwort wird genau einmal abgeschlossen ([finish]),
 * - die offene Antwort hängt am Prozess, nicht an der Activity: eine neu
 *   erzeugte Activity (Speicherdruck während des Scans) schließt sie ab,
 * - kommt nach der Rückkehr in die App kein Ergebnis an, gilt der Scan als
 *   verloren und Dart meldet es sichtbar ([onResume], Fehler `lost`),
 * - ein neuer Aufruf ersetzt eine liegengebliebene Antwort statt `busy`.
 */
class DocumentScannerChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "buchhaltung/document_scanner")

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
        // Liegengebliebene Antwort (Scanner-Activity nie zurückgekehrt):
        // abschließen statt den Scanner dauerhaft zu sperren. Doppelte Tipps
        // fängt Dart ab, bevor sie hier ankommen.
        finish { it.success(emptyList<String>()) }
        pending = result
        launched = false
        try {
            scanner(pageLimit).getStartScanIntent(activity)
                .addOnSuccessListener { sender ->
                    try {
                        @Suppress("DEPRECATION")
                        activity.startIntentSenderForResult(sender, REQUEST, null, 0, 0, 0)
                        launched = true
                    } catch (e: Exception) {
                        finish { it.error("unavailable", e.message, null) }
                    }
                }
                .addOnFailureListener { e -> finish { it.error("unavailable", e.message, null) } }
                .addOnCanceledListener { finish { it.error("unavailable", "abgebrochen", null) } }
        } catch (e: Exception) {
            finish { it.error("unavailable", e.message, null) }
        }
    }

    /** Aus `MainActivity.onActivityResult`. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        launched = false
        val result = take() ?: return true
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return true
        }
        val scan = try {
            GmsDocumentScanningResult.fromActivityResultIntent(data)
        } catch (e: Exception) {
            result.error("io", e.message, null)
            return true
        }
        val uris = scan?.pages.orEmpty().map { it.imageUri }
        val dir = File(activity.cacheDir, "scanner").apply { mkdirs() }
        val resolver = activity.applicationContext.contentResolver
        // Kopieren im Hintergrund, Antwort auf dem Hauptthread – immer genau
        // einmal, auch wenn eine Seite nicht lesbar ist.
        io.execute {
            var paths: List<String>? = null
            var error: String? = null
            try {
                val stamp = System.currentTimeMillis()
                paths = uris.mapIndexed { i, uri ->
                    val out = File(dir, "scan_${stamp}_$i.jpg")
                    val input = resolver.openInputStream(uri)
                        ?: throw java.io.IOException("Seite ${i + 1} nicht lesbar")
                    input.use { s -> out.outputStream().use { o -> s.copyTo(o) } }
                    out.absolutePath
                }
            } catch (e: Exception) {
                error = e.message ?: e.toString()
            }
            main.post {
                val ok = paths
                if (ok != null) result.success(ok) else result.error("io", error, null)
            }
        }
        return true
    }

    /**
     * Aus `MainActivity.onResume`. Android liefert `onActivityResult` vor
     * `onResume`; ist die Antwort danach noch offen, kommt keine mehr
     * (Ergebnis verloren, Activity neu erzeugt). Dann endet der Scan mit dem
     * Fehler `lost` – sichtbar für die Nutzerin, der Scanner bleibt bedienbar.
     * Gerätetest 0.22.0: hier landete jeder Scan, weil der Sicherungsordner
     * denselben Request-Code hatte ([RequestCodes]).
     */
    fun onResume() {
        if (!launched) return
        main.postDelayed({
            if (launched) {
                launched = false
                // Nicht still als Abbruch werten: Dart zeigt eine Meldung.
                finish { it.error("lost", "Das Scan-Ergebnis ist nicht in der App angekommen.", null) }
            }
        }, RESUME_GRACE_MS)
    }

    companion object {
        private const val REQUEST = RequestCodes.DOCUMENT_SCANNER
        private const val RESUME_GRACE_MS = 1500L

        // Am Prozess statt an der Activity: übersteht eine neu erzeugte
        // Activity mit derselben Flutter-Engine.
        private var pending: MethodChannel.Result? = null
        private var launched = false
        private val main = Handler(Looper.getMainLooper())
        private val io = Executors.newSingleThreadExecutor()

        private fun take(): MethodChannel.Result? {
            val r = pending
            pending = null
            return r
        }

        private fun finish(action: (MethodChannel.Result) -> Unit) {
            val r = take() ?: return
            try {
                action(r)
            } catch (_: IllegalStateException) {
                // Antwort war bereits abgeschlossen (Engine neu) – nichts tun.
            }
        }
    }
}
