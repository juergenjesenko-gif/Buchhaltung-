package at.jesenko.buchhaltung

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity statt FlutterActivity: local_auth (App-Sperre,
// FA-1.16) braucht eine FragmentActivity für den BiometricPrompt.
class MainActivity : FlutterFragmentActivity() {
    private var backupFolder: BackupFolderChannel? = null
    private var receiptText: ReceiptTextChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupFolder = BackupFolderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        receiptText = ReceiptTextChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // App-Sperre (FA-1.17): Vorschau im App-Umschalter ausblenden, ohne
        // Bildschirmfotos zu verbieten (kein FLAG_SECURE). Erst ab Android 13.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buchhaltung/app_lock")
            .setMethodCallHandler { call, result ->
                if (call.method == "hideRecentsPreview") {
                    val hide = call.argument<Boolean>("hide") ?: false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        setRecentsScreenshotEnabled(!hide)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Deprecated("Activity Result API wäre moderner; hier genügt der klassische Weg")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (backupFolder?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}
