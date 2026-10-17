import Flutter
import MessageUI
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Mailweg der Mithelfer (FA-17.9): Hintergrundabruf über BGAppRefreshTask
    // (bestmöglich, iOS entscheidet über den Zeitpunkt). Mit UIScene müssen
    // die Handler vor dem Ende dieser Methode angemeldet sein.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "at.jesenko.buchhaltung.mailsync", earliestBeginInSeconds: 3600)
    WorkmanagerPlugin.registerLaunchHandlers()
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private let mailComposer = MailComposeDelegate()

  private var backupFolder: BackupFolderChannel?
  private var receiptText: ReceiptTextChannel?
  private var launcher: FlutterMethodChannel?
  private var pdf: PdfChannel?
  private var shareIn: ShareInChannel?
  private var scanner: DocumentScannerChannel?
  private var documentPicker: DocumentPickerChannel?
  private var dictation: DictationChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackupFolderChannel") {
      backupFolder = BackupFolderChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReceiptTextChannel") {
      receiptText = ReceiptTextChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DocumentScannerChannel") {
      scanner = DocumentScannerChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DocumentPickerChannel") {
      documentPicker = DocumentPickerChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DictationChannel") {
      dictation = DictationChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PdfChannel") {
      pdf = PdfChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareInChannel") {
      let channel = ShareInChannel(messenger: registrar.messenger())
      registrar.addSceneDelegate(channel)
      shareIn = channel
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
        case "deviceInfo":
          // Wunsch senden (FA-11.6): nur Systemversion und Modellkennung.
          var sys = utsname()
          uname(&sys)
          let model = withUnsafePointer(to: &sys.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
          }
          result("iOS \(UIDevice.current.systemVersion) · \(model)")
        case "openMail":
          guard let text = call.arguments as? String, text.hasPrefix("mailto:"),
            let url = URL(string: text), UIApplication.shared.canOpenURL(url)
          else {
            result(false)
            return
          }
          UIApplication.shared.open(url) { ok in result(ok) }
        case "openUrl":
          // Link-QR (L-27.7): „Im Browser öffnen“, nur https.
          guard let text = call.arguments as? String, text.hasPrefix("https://"),
            let url = URL(string: text)
          else {
            result(false)
            return
          }
          UIApplication.shared.open(url) { ok in result(ok) }
        case "composeMail":
          // Mithelfer ohne eigenes Postfach (FA-17.9): Apple Mail mit
          // Empfänger, Betreff, Text und Belegpaket als Anhang.
          guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let to = args["to"] as? String,
            MFMailComposeViewController.canSendMail(),
            let data = FileManager.default.contents(atPath: path)
          else {
            result(false)
            return
          }
          let vc = MFMailComposeViewController()
          vc.mailComposeDelegate = self.mailComposer
          vc.setToRecipients([to])
          vc.setSubject(args["subject"] as? String ?? "")
          vc.setMessageBody(args["text"] as? String ?? "", isHTML: false)
          vc.addAttachmentData(
            data, mimeType: "application/octet-stream",
            fileName: (path as NSString).lastPathComponent)
          guard let top = MailComposeDelegate.topViewController() else {
            result(false)
            return
          }
          top.present(vc, animated: true)
          result(true)
        case "isSupported", "requestPin":
          result(false)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

/// Schließt das Mailfenster nach Senden oder Abbrechen (FA-17.9).
final class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
  func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult, error: Error?
  ) {
    controller.dismiss(animated: true)
  }

  static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
