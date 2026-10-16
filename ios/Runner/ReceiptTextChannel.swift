import AVFoundation
import Flutter
import PDFKit
import Speech
import UIKit
import UniformTypeIdentifiers
import Vision
import VisionKit

/// Texterkennung für Belegfotos (L-2.20) mit Apple Vision
/// (`VNRecognizeTextRequest`). Läuft vollständig auf dem Gerät; Bild und Text
/// verlassen das Gerät nicht. Gegenstück zu ReceiptTextChannel.kt (Android).
class ReceiptTextChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "buchhaltung/receipt_text", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(true)
      case "recognize":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "bad_args", message: "path fehlt", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let outcome = ReceiptTextChannel.recognize(path: path)
          DispatchQueue.main.async {
            switch outcome {
            case .success(let found):
              result([
                "engine": "Apple Vision VNRecognizeTextRequest",
                "engineVersion": UIDevice.current.systemVersion,
                "lines": found.0,
                "codes": found.1,
              ])
            case .failure(let error):
              result(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func recognize(path: String) -> Result<([[String: Any]], [String]), Error> {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      return .failure(NSError(domain: "ReceiptText", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Bild nicht lesbar"]))
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let wanted = ["de-DE", "en-US"]
    if let supported = try? request.supportedRecognitionLanguages() {
      let languages = wanted.filter { supported.contains($0) }
      if !languages.isEmpty { request.recognitionLanguages = languages }
    }
    let handler = VNImageRequestHandler(cgImage: cgImage,
                                        orientation: orientation(image.imageOrientation),
                                        options: [:])
    // QR- und Barcodes auf demselben Bild (L-27.1), ebenfalls auf dem Gerät.
    let barcodes = VNDetectBarcodesRequest()
    barcodes.symbologies = [.qr, .dataMatrix, .aztec]
    do {
      try handler.perform([request, barcodes])
    } catch {
      return .failure(error)
    }
    // Koordinaten nur für die Zeilenzuordnung; normiert auf 10000.
    let scale = 10000.0
    var lines: [[String: Any]] = []
    for observation in request.results ?? [] {
      guard let candidate = observation.topCandidates(1).first else { continue }
      let box = observation.boundingBox
      lines.append([
        "text": candidate.string,
        "left": Int(box.minX * scale),
        "top": Int((1 - box.maxY) * scale),
        "height": Int(box.height * scale),
      ])
    }
    let codes = (barcodes.results ?? []).compactMap { $0.payloadStringValue }
    return .success((lines, codes))
  }

  private static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch o {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}

// Die folgenden Klassen stehen bewusst in dieser bereits im Xcode-Projekt
// eingetragenen Datei: so bleibt project.pbxproj unverändert (iOS-Build nur
// in der CI prüfbar).

/// PDF-Seiten als Bild und Textebene (L-27.5) mit PDFKit, auf dem Gerät.
/// Gegenstück zu PdfChannel.kt; zusätzlich liefert iOS die Textebene.
class PdfChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "buchhaltung/pdf", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "render" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "bad_args", message: "path fehlt", details: nil))
        return
      }
      let maxPages = args["maxPages"] as? Int ?? 5
      DispatchQueue.global(qos: .userInitiated).async {
        let out = PdfChannel.render(path: path, maxPages: maxPages)
        DispatchQueue.main.async {
          if let out = out {
            result(out)
          } else {
            result(FlutterError(code: "pdf_failed", message: "PDF nicht lesbar", details: nil))
          }
        }
      }
    }
  }

  private static func render(path: String, maxPages: Int) -> [String: Any]? {
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { return nil }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pdf_pages")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var pages: [String] = []
    var texts: [String] = []
    for i in 0..<min(doc.pageCount, maxPages) {
      guard let page = doc.page(at: i) else { continue }
      texts.append(page.string ?? "")
      let box = page.bounds(for: .mediaBox)
      let scale = 2000.0 / max(box.width, box.height)
      let size = CGSize(width: box.width * scale, height: box.height * scale)
      let image = page.thumbnail(of: size, for: .mediaBox)
      let target = dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))_\(i + 1).png")
      if let data = image.pngData(), (try? data.write(to: target)) != nil {
        pages.append(target.path)
      }
    }
    return ["pages": pages, "pageCount": doc.pageCount, "text": texts]
  }
}

/// Teilen-Ziel iOS (L-27.4): „Öffnen in …“/„Kopieren nach Buchhaltung“ aus
/// dem Teilen-Menü für Bilder, PDF und XML (CFBundleDocumentTypes in
/// Info.plist). Die Datei wird in den temporären Ordner kopiert und über
/// denselben Channel wie unter Android gemeldet.
class ShareInChannel: NSObject, FlutterSceneLifeCycleDelegate {
  private let channel: FlutterMethodChannel
  private var pending: [String] = []
  private static let maxBytes = 20 * 1024 * 1024

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "buchhaltung/share_in", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takePending" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.pending ?? [])
      self?.pending.removeAll()
    }
  }

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    guard let contexts = connectionOptions?.urlContexts, !contexts.isEmpty else { return false }
    return handle(contexts.map { $0.url })
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return handle(URLContexts.map { $0.url })
  }

  private func handle(_ urls: [URL]) -> Bool {
    var any = false
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("shared_in")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for (i, url) in urls.enumerated() where url.isFileURL {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      if size > ShareInChannel.maxBytes { continue }
      let name = url.lastPathComponent.replacingOccurrences(
        of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
      let target = dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))_\(i)_\(name)")
      if (try? FileManager.default.copyItem(at: url, to: target)) != nil {
        pending.append(target.path)
        any = true
      }
    }
    if any { channel.invokeMethod("shared", arguments: nil) }
    return any
  }
}

/// Dokumentenscanner des Systems für Belege und Verträge (FA-2.51):
/// VisionKit `VNDocumentCameraViewController`, auf dem Gerät, mehrere Seiten,
/// entzerrt. Gespeichert wird nur das verarbeitete Bild (P-S63). Ergebnis
/// von `scan`: Pfade; leer = abgebrochen; Fehler `unavailable` = Gerät ohne
/// Scanner → Dart nimmt die Kamera.
class DocumentScannerChannel: NSObject, VNDocumentCameraViewControllerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "buchhaltung/document_scanner", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "scan" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.scan(result)
    }
  }

  private func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  /// Schließt die offene Antwort genau einmal ab (Gerätetest 0.21.0: eine
  /// liegengebliebene Antwort sperrte den Scanner bis zum Neustart).
  private func finish(_ value: Any?) {
    guard let result = pending else { return }
    pending = nil
    result(value)
  }

  private func scan(_ result: @escaping FlutterResult) {
    // Liegengebliebene Antwort abschließen statt dauerhaft „busy“; doppelte
    // Tipps fängt Dart ab.
    finish([String]())
    guard VNDocumentCameraViewController.isSupported, let top = topController() else {
      result(FlutterError(code: "unavailable", message: "Kein Dokumentenscanner", details: nil))
      return
    }
    if top.isBeingDismissed || top.isBeingPresented {
      result(FlutterError(code: "unavailable", message: "Ansicht nicht bereit", details: nil))
      return
    }
    pending = result
    let controller = VNDocumentCameraViewController()
    controller.delegate = self
    top.present(controller, animated: true)
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
  ) {
    // Seiten im Hintergrund schreiben, Antwort auf dem Hauptthread.
    let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
    controller.dismiss(animated: true)
    DispatchQueue.global(qos: .userInitiated).async {
      let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scanner")
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let stamp = Int(Date().timeIntervalSince1970 * 1000)
      var paths: [String] = []
      for (i, image) in images.enumerated() {
        let target = dir.appendingPathComponent("scan_\(stamp)_\(i).jpg")
        if let data = image.jpegData(compressionQuality: 0.9),
          (try? data.write(to: target)) != nil
        {
          paths.append(target.path)
        }
      }
      DispatchQueue.main.async { self.finish(paths) }
    }
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
    finish([String]())
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController, didFailWithError error: Error
  ) {
    controller.dismiss(animated: true)
    finish(FlutterError(code: "unavailable", message: error.localizedDescription, details: nil))
  }
}

/// Diktat **nur auf dem Gerät** (FA-2.61, Lastenheft 5.19): `SFSpeechRecognizer`
/// mit `requiresOnDeviceRecognition = true`. Ohne Erkennung auf dem Gerät
/// meldet `isAvailable` false, Dart zeigt keinen Mikrofonknopf; kein
/// Rückfall auf Apples Server. Gegenstück zu DictationChannel.kt.
class DictationChannel {
  private let channel: FlutterMethodChannel
  private let audio = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var silence: Timer?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "buchhaltung/dictation", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any]
      let locale = args?["locale"] as? String ?? "de-AT"
      switch call.method {
      case "isAvailable":
        result(self.recognizer(locale)?.supportsOnDeviceRecognition ?? false)
      case "start":
        self.authorize(locale, result)
      case "stop":
        self.request?.endAudio()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func recognizer(_ locale: String) -> SFSpeechRecognizer? {
    SFSpeechRecognizer(locale: Locale(identifier: locale))
  }

  private func authorize(_ locale: String, _ result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        guard status == .authorized else {
          result(FlutterError(code: "permission", message: "Spracherkennung nicht erlaubt", details: nil))
          return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          DispatchQueue.main.async {
            guard granted else {
              result(FlutterError(code: "permission", message: "Mikrofon nicht erlaubt", details: nil))
              return
            }
            self.begin(locale, result)
          }
        }
      }
    }
  }

  private func begin(_ locale: String, _ result: @escaping FlutterResult) {
    finish()
    guard let recognizer = recognizer(locale), recognizer.supportsOnDeviceRecognition,
      recognizer.isAvailable
    else {
      result(FlutterError(code: "unavailable", message: "Keine Erkennung auf dem Gerät", details: nil))
      return
    }
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    self.request = request
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)
      let input = audio.inputNode
      input.removeTap(onBus: 0)
      input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) {
        buffer, _ in request.append(buffer)
      }
      audio.prepare()
      try audio.start()
    } catch {
      finish()
      result(FlutterError(code: "unavailable", message: error.localizedDescription, details: nil))
      return
    }
    var sent = false
    task = recognizer.recognitionTask(with: request) { [weak self] res, error in
      guard let self = self, !sent else { return }
      if let res = res {
        let text = res.bestTranscription.formattedString
        if res.isFinal {
          sent = true
          self.channel.invokeMethod("onFinal", arguments: ["text": text])
          self.finish()
          return
        }
        self.channel.invokeMethod("onPartial", arguments: ["text": text])
        // Sprechpause von 2 s beendet die Aufnahme.
        self.silence?.invalidate()
        self.silence = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
          self.request?.endAudio()
        }
      } else if error != nil {
        sent = true
        self.channel.invokeMethod("onError", arguments: ["code": "no_match"])
        self.finish()
      }
    }
    result(nil)
  }

  private func finish() {
    silence?.invalidate()
    silence = nil
    if audio.isRunning {
      audio.stop()
      audio.inputNode.removeTap(onBus: 0)
    }
    request?.endAudio()
    request = nil
    task?.cancel()
    task = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}

/// Datei für einen neuen Beleg wählen (Knopf „Datei“ auf Übersicht und
/// Belegliste, FA-12.1): Bilder, PDF, XML-E-Rechnung. Liefert Pfade auf
/// Kopien im temporären Ordner; Dart behandelt sie wie geteilte Dateien.
/// Leere Liste = abgebrochen. Hier statt in einer eigenen Datei, damit das
/// Xcode-Projekt unverändert bleibt.
final class DocumentPickerChannel: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "buchhaltung/document_picker", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pick" else { result(FlutterMethodNotImplemented); return }
      self?.pick(result)
    }
  }

  private func pick(_ result: @escaping FlutterResult) {
    pending?([String]())
    pending = nil
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    guard let root = top else {
      result(FlutterError(code: "io", message: "Dateiauswahl nicht möglich", details: nil))
      return
    }
    pending = result
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [.image, .pdf, .xml], asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = true
    root.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("picked", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let stamp = Int(Date().timeIntervalSince1970 * 1000)
      var paths: [String] = []
      for (i, url) in urls.enumerated() {
        let target = dir.appendingPathComponent("\(stamp)_\(i)_\(url.lastPathComponent)")
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: url, to: target)
        paths.append(target.path)
      }
      result(paths)
    } catch {
      result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?([String]())
    pending = nil
  }
}
