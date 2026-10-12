package at.jesenko.buchhaltung

import android.content.Context
import android.net.Uri
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
                    val image = try {
                        InputImage.fromFilePath(context, Uri.fromFile(File(path)))
                    } catch (e: Exception) {
                        result.error("unreadable", e.message, null)
                        return@setMethodCallHandler
                    }
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
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        /** Muss zur Abhängigkeit in android/app/build.gradle.kts passen. */
        const val ENGINE_VERSION = "16.0.1"
    }
}
