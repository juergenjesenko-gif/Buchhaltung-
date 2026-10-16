package at.jesenko.buchhaltung

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Diktat **nur auf dem Gerät** (Spezifikation FA-2.61, Lastenheft 5.19):
 * `SpeechRecognizer.createOnDeviceSpeechRecognizer` ab Android 12 (API 31).
 * Ohne Erkennung auf dem Gerät meldet `isAvailable` false und Dart zeigt
 * keinen Mikrofonknopf – es gibt bewusst keinen Rückfall auf den
 * Netz-Erkenner (`createSpeechRecognizer`), Audio verlässt das Gerät nie.
 *
 * Ergebnisse gehen über denselben Channel zurück: `onPartial`, `onFinal`,
 * `onError` (`permission`, `no_match`, `busy`, …). Ende nach Sprechpause
 * (Standard des Erkenners) oder `stop`.
 */
class DictationChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "buchhaltung/dictation")
    private var recognizer: SpeechRecognizer? = null
    private var pendingLocale: String? = null
    private var pendingStart: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(available())
                "start" -> start(call.argument<String>("locale") ?: "de-AT", result)
                "stop" -> {
                    recognizer?.stopListening()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun available(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)

    private fun start(locale: String, result: MethodChannel.Result) {
        if (!available()) {
            result.error("unavailable", "Keine Spracherkennung auf dem Gerät", null)
            return
        }
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            // Vorherige Anfrage abschließen, nie liegen lassen.
            pendingStart?.error("permission", "ersetzt", null)
            pendingStart = result
            pendingLocale = locale
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST)
            return
        }
        begin(locale, result)
    }

    /** Aus `MainActivity.onRequestPermissionsResult`. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST) return false
        val result = pendingStart ?: return true
        val locale = pendingLocale ?: "de-AT"
        pendingStart = null
        pendingLocale = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            begin(locale, result)
        } else {
            result.error("permission", "Mikrofon nicht erlaubt", null)
        }
        return true
    }

    private fun begin(locale: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            result.error("unavailable", "Android zu alt", null)
            return
        }
        recognizer?.destroy()
        val r = try {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        } catch (e: Exception) {
            result.error("unavailable", e.message, null)
            return
        }
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onEvent(eventType: Int, params: Bundle?) {}

            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: return
                channel.invokeMethod("onPartial", mapOf("text" to text))
            }

            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                channel.invokeMethod("onFinal", mapOf("text" to text))
                release(r)
            }

            override fun onError(error: Int) {
                val code = when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission"
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no_match"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "busy"
                    else -> "error_$error"
                }
                channel.invokeMethod("onError", mapOf("code" to code))
                release(r)
            }
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        try {
            r.startListening(intent)
            result.success(null)
        } catch (e: Exception) {
            release(r)
            result.error("unavailable", e.message, null)
        }
    }

    private fun release(r: SpeechRecognizer) {
        if (recognizer === r) recognizer = null
        r.destroy()
    }

    companion object {
        private const val REQUEST = RequestCodes.DICTATION_PERMISSION
    }
}
