import Flutter
import UIKit
import Vision

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
            case .success(let lines):
              result([
                "engine": "Apple Vision VNRecognizeTextRequest",
                "engineVersion": UIDevice.current.systemVersion,
                "lines": lines,
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

  private static func recognize(path: String) -> Result<[[String: Any]], Error> {
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
    do {
      try handler.perform([request])
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
    return .success(lines)
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
