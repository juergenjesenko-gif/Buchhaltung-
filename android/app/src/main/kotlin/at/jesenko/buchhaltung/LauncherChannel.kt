package at.jesenko.buchhaltung

import android.content.Context
import android.content.Intent
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
                else -> result.notImplemented()
            }
        }
    }
}
