package at.jesenko.buchhaltung

import android.content.Context
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
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
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
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
                        } catch (e: Exception) {
                            main.post { result.error("unreadable", e.toString(), null) }
                            return@Thread
                        }
                        if (image == null) {
                            main.post { result.error("unreadable", "Bild nicht lesbar: $path", null) }
                            return@Thread
                        }
                        main.post { process(image, result) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private val main = Handler(Looper.getMainLooper())

    private fun decode(path: String): InputImage? {
        val file = File(path)
        if (!file.isFile) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > MAX_EDGE) sample *= 2
        val bitmap = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
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
                    ),
                )
            }
            .addOnFailureListener { e -> result.error("ocr_failed", e.message, null) }
    }

    companion object {
        /** Längste Bildkante für die Erkennung; reicht für Belegtext. */
        const val MAX_EDGE = 2400

        /** Muss zur Abhängigkeit in android/app/build.gradle.kts passen. */
        const val ENGINE_VERSION = "16.0.1"
    }
}
