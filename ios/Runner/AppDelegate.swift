import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var backupFolder: BackupFolderChannel?
  private var receiptText: ReceiptTextChannel?
  private var launcher: FlutterMethodChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackupFolderChannel") {
      backupFolder = BackupFolderChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReceiptTextChannel") {
      receiptText = ReceiptTextChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LauncherChannel") {
      launcher = FlutterMethodChannel(
        name: "buchhaltung/launcher", binaryMessenger: registrar.messenger())
      // Hilfe Stufe 1 (FA-11.3): Mail-App öffnen und Versionsname liefern.
      // Ablage aufs Startbildschirm-Symbol (FA-1.19) gibt es auf iOS nicht.
      launcher?.setMethodCallHandler { call, result in
        switch call.method {
        case "appVersion":
          result(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        case "openMail":
          guard let text = call.arguments as? String, text.hasPrefix("mailto:"),
            let url = URL(string: text), UIApplication.shared.canOpenURL(url)
          else {
            result(false)
            return
          }
          UIApplication.shared.open(url) { ok in result(ok) }
        case "isSupported", "requestPin":
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
