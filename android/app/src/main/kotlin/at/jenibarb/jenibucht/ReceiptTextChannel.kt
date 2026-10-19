package at.jenibarb.jenibucht

import android.content.Context
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import com.google.mlkit.common.sdkinternal.MlKitContext
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Texterkennung für Belegfotos (L-2.20) mit Google ML Kit Text Recognition,
 * lateinische Schrift, **gebündeltes** Modell (`com.google.mlkit:text-recognition`,
 * nicht die Play-Services-Variante `play-services-mlkit-text-recognition`):
 * kein Modell-Download, Erkennung offline auf dem Gerät.
 *
 * Bewusst eigener Channel statt Flutter-Plugin: keine Plugin-Gradle-Datei, die
 * unter AGP 9 brechen kann (wie früher file_picker), und die Engine lässt sich
 * austauschen, ohne den Dart-Teil zu ändern (Schnittstelle ReceiptTextRecognizer).
 * ML Kit sendet Nutzungs-/Diagnosedaten an Google, siehe docs/PRIVACY.md.
 */
class ReceiptTextChannel(private val context: Context, messenger: BinaryMessenger) {
    private val recognizer by lazy {
        // ML Kit initialisiert sich normalerweise über den MlKitInitProvider im
        // gemergten Manifest. Fehlt der (Manifest-Merge, Prozess ohne Provider),
        // ist MlKitContext null und ML Kit bricht mit einer NullPointerException
        // „getClass() on a null object reference“ ab – genau die Meldung vom
        // Pixel 10. Darum hier ausdrücklich initialisieren; doppelt ist harmlos.
        MlKitContext.initializeIfNeeded(context.applicationContext)
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    /**
     * QR- und Barcodes auf demselben Bild (L-27.1): Kassen-QR (RKSV/TSE),
     * Zahlungs-QR (EPC069-12), Link-QR. Gebündeltes Modell
     * `com.google.mlkit:barcode-scanning`, offline; Telemetrie wie bei der
     * Texterkennung (docs/PRIVACY.md). QR, Data Matrix und Aztec genügen.
     */
    private val barcodes by lazy {
        MlKitContext.initializeIfNeeded(context.applicationContext)
        BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE, Barcode.FORMAT_DATA_MATRIX, Barcode.FORMAT_AZTEC)
                .build(),
        )
    }

    init {
        MethodChannel(messenger, "buchhaltung/receipt_text").setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "recognize" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path fehlt", null)
                        return@setMethodCallHandler
                    }
                    // Selbst dekodieren statt InputImage.fromFilePath: das lieferte im
                    // Release-Build auf dem Pixel 10 eine NullPointerException
                    // (Gerätetest 2026-10-12). Dekodieren im Hintergrund, verkleinert
                    // auf höchstens MAX_EDGE Pixel, EXIF-Drehung an ML Kit übergeben.
                    Thread {
                        val image = try {
                            decode(path)
                        } catch (e: Throwable) {
                            main.post { result.error("unreadable", e.toString(), describe(e)) }
                            return@Thread
                        }
                        if (image == null) {
                            main.post { result.error("unreadable", "Bild nicht lesbar: $path", null) }
                            return@Thread
                        }
                        main.post {
                            try {
                                process(image, result)
                            } catch (e: Throwable) {
                                result.error("ocr_failed", e.toString(), describe(e))
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private val main = Handler(Looper.getMainLooper())

    private fun decode(path: String): InputImage? {
        val file = File(path)
        // image_picker legt das Foto im Cache ab; ist es schon gelöscht oder
        // leer, gleich mit klarer Meldung abbrechen.
        if (!file.isFile) throw java.io.FileNotFoundException("Datei fehlt")
        if (file.length() == 0L) throw java.io.IOException("Datei leer")
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        // HEIC/Ultra-HDR (JPEG mit Gainmap) dekodiert BitmapFactory ab Android 9
        // bzw. 14 selbst; liefert es keine Maße, ist das Format nicht lesbar.
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw java.io.IOException("Format nicht dekodierbar (${bounds.outMimeType})")
        }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_EDGE) sample *= 2
        val bitmap = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = android.graphics.Bitmap.Config.ARGB_8888
            },
        ) ?: throw java.io.IOException("decodeFile lieferte null")
        val rotation = when (
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }
        return InputImage.fromBitmap(bitmap, rotation)
    }

    private fun process(image: InputImage, result: MethodChannel.Result) {
        // Erst Codes, dann Text. Ein Fehler beim Code-Lesen bricht die
        // Texterkennung nicht ab: dann eben ohne Codes.
        barcodes.process(image)
            .addOnSuccessListener { found ->
                recognizeText(image, found.mapNotNull { it.rawValue }, result)
            }
            .addOnFailureListener { recognizeText(image, emptyList(), result) }
    }

    private fun recognizeText(image: InputImage, codes: List<String>, result: MethodChannel.Result) {
        recognizer.process(image)
            .addOnSuccessListener { text ->
                val lines = ArrayList<Map<String, Any>>()
                for (block in text.textBlocks) {
                    for (line in block.lines) {
                        val box = line.boundingBox
                        lines.add(
                            mapOf(
                                "text" to line.text,
                                "left" to (box?.left ?: 0),
                                "top" to (box?.top ?: 0),
                                "height" to (box?.height() ?: 0),
                            ),
                        )
                    }
                }
                result.success(
                    mapOf(
                        "engine" to "Google ML Kit Text Recognition (Latin, gebündelt)",
                        "engineVersion" to ENGINE_VERSION,
                        "lines" to lines,
                        "codes" to codes,
                    ),
                )
            }
            .addOnFailureListener { e -> result.error("ocr_failed", e.toString(), describe(e)) }
    }

    /**
     * Fehlerdetails für den Fehlercode in der App: Exception-Klasse und die
     * ersten Stackzeilen (auch der Ursache). Enthält keine Belegdaten, nur
     * Klassen- und Methodennamen.
     */
    private fun describe(e: Throwable): String {
        val parts = ArrayList<String>()
        var t: Throwable? = e
        var depth = 0
        while (t != null && depth < 3) {
            parts.add(t.javaClass.name + " @ " + t.stackTrace.take(2).joinToString(" < "))
            t = t.cause
            depth++
        }
        return parts.joinToString(" | caused by ")
    }

    companion object {
        /** Längste Bildkante für die Erkennung; reicht für Belegtext. */
        const val MAX_EDGE = 2400

        /** Muss zur Abhängigkeit in android/app/build.gradle.kts passen. */
        const val ENGINE_VERSION = "16.0.1 + barcode 17.3.0"
    }
}
