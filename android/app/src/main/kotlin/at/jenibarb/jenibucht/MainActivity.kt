package at.jenibarb.jenibucht

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity statt FlutterActivity: local_auth (App-Sperre,
// FA-1.16) braucht eine FragmentActivity für den BiometricPrompt.
class MainActivity : FlutterFragmentActivity() {
    private var backupFolder: BackupFolderChannel? = null
    private var receiptText: ReceiptTextChannel? = null
    private var launcher: LauncherChannel? = null
    private var shareIn: ShareInChannel? = null
    private var pdf: PdfChannel? = null
    private var shareOut: ShareOutChannel? = null
    private var scanner: DocumentScannerChannel? = null
    private var documentPicker: DocumentPickerChannel? = null
    private var dictation: DictationChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupFolder = BackupFolderChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        receiptText = ReceiptTextChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        launcher = LauncherChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        pdf = PdfChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        shareOut = ShareOutChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        scanner = DocumentScannerChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        documentPicker = DocumentPickerChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        dictation = DictationChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        shareIn = ShareInChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // Start über „Teilen“ (L-27.4): Intent des Starts auswerten.
        shareIn?.handle(intent)
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

    override fun onResume() {
        super.onResume()
        // Dokumentenscanner: offene Antwort nie liegen lassen (Gerätetest 0.21.0).
        scanner?.onResume()
    }

    @Deprecated("Activity Result API wäre moderner; hier genügt der klassische Weg")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (dictation?.onPermissionResult(requestCode, grantResults) == true) return
        @Suppress("DEPRECATION")
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        shareIn?.handle(intent)
    }

    @Deprecated("Activity Result API wäre moderner; hier genügt der klassische Weg")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (backupFolder?.onActivityResult(requestCode, resultCode, data) == true) return
        if (scanner?.onActivityResult(requestCode, resultCode, data) == true) return
        if (documentPicker?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}
