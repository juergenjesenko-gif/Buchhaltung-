package at.jesenko.buchhaltung

import android.content.Context
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

// App-Symbol auf dem Startbildschirm (FA-1.19). Eine App darf kein Symbol
// stumm ablegen; requestPinShortcut zeigt den Systemdialog
// „Zum Startbildschirm hinzufügen“ (Android 8+, sonst nicht unterstützt).
class LauncherChannel(private val context: Context, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "buchhaltung/launcher").setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" ->
                    result.success(ShortcutManagerCompat.isRequestPinShortcutSupported(context))
                "requestPin" -> {
                    if (!ShortcutManagerCompat.isRequestPinShortcutSupported(context)) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(context, MainActivity::class.java)
                        .setAction(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_LAUNCHER)
                    val label = context.applicationInfo.loadLabel(context.packageManager).toString()
                    val info = ShortcutInfoCompat.Builder(context, "home")
                        .setShortLabel(label)
                        .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
                        .setIntent(intent)
                        .build()
                    result.success(ShortcutManagerCompat.requestPinShortcut(context, info, null))
                }
                // Hilfe Stufe 1 (FA-11.3): Mail-App mit vorausgefülltem Betreff
                // öffnen. ACTION_SENDTO mit mailto: zeigt nur Mail-Apps; es
                // wird nichts angehängt und nichts gesendet.
                "openMail" -> {
                    val uri = call.arguments as? String
                    if (uri == null || !uri.startsWith("mailto:")) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_SENDTO, Uri.parse(uri))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                // Link-QR (L-27.7): „Im Browser öffnen“, nur https.
                "openUrl" -> {
                    val uri = call.arguments as? String
                    if (uri == null || !uri.startsWith("https://")) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
                        .addCategory(Intent.CATEGORY_BROWSABLE)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
                "appVersion" ->
                    result.success(
                        context.packageManager.getPackageInfo(context.packageName, 0).versionName
                    )
                // Wunsch senden (FA-11.6): nur Systemversion und Modell, keine Kennung.
                "deviceInfo" ->
                    result.success(
                        "Android ${android.os.Build.VERSION.RELEASE} · " +
                            "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}"
                    )
                else -> result.notImplemented()
            }
        }
    }
}
