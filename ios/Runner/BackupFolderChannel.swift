import Flutter
import UIKit
import UniformTypeIdentifiers

/// Ordner für die automatische Sicherung (Lastenheft L-7.2, L-7.8): die
/// Nutzerin wählt einmal einen Ordner, etwa in iCloud Drive. Die App merkt
/// sich ein Security-Scoped Bookmark und schreibt danach ohne erneute
/// Auswahl dorthin; den Upload übernimmt das System. Kein iCloud-Entitlement,
/// kein Server.
final class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "buchhaltung/backup_folder", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "pick" {
      pick(result)
      return
    }
    if call.method == "pickFile" {
      pickFile(result)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let folder = args["folder"] as? String
    else {
      result(FlutterError(code: "ARGS", message: "Ordner fehlt", details: nil))
      return
    }
    DispatchQueue.global(qos: .utility).async {
      do {
        let value: Any? = try self.withFolder(folder) { url in
          switch call.method {
          case "isAvailable":
            return FileManager.default.isWritableFile(atPath: url.path)
          case "list":
            return try FileManager.default.contentsOfDirectory(atPath: url.path)
          case "write":
            let name = args["name"] as! String
            let data = (args["bytes"] as! FlutterStandardTypedData).data
            try self.coordinatedWrite(data, to: url.appendingPathComponent(name))
            return true
          case "read":
            let name = args["name"] as! String
            return FlutterStandardTypedData(
              bytes: try self.coordinatedRead(url.appendingPathComponent(name)))
          case "delete":
            let file = url.appendingPathComponent(args["name"] as! String)
            if FileManager.default.fileExists(atPath: file.path) {
              try FileManager.default.removeItem(at: file)
            }
            return true
          default:
            return FlutterMethodNotImplemented
          }
        }
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          if call.method == "isAvailable" {
            result(false)
          } else {
            result(FlutterError(code: "IO", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private var pickingFile = false

  private func pickFile(_ result: @escaping FlutterResult) {
    guard pending == nil, let root = Self.topViewController() else {
      result(FlutterError(code: "BUSY", message: "Auswahl nicht möglich", details: nil))
      return
    }
    pending = result
    pickingFile = true
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
    picker.delegate = self
    root.present(picker, animated: true)
  }

  private func pick(_ result: @escaping FlutterResult) {
    guard pending == nil, let root = Self.topViewController() else {
      result(FlutterError(code: "BUSY", message: "Auswahl nicht möglich", details: nil))
      return
    }
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    root.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else { result(nil); return }
    if pickingFile {
      pickingFile = false
      do {
        result(FlutterStandardTypedData(bytes: try Data(contentsOf: url)))
      } catch {
        result(FlutterError(code: "IO", message: error.localizedDescription, details: nil))
      }
      return
    }
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      result(["folder": bookmark.base64EncodedString(), "label": url.lastPathComponent])
    } catch {
      result(FlutterError(code: "BOOKMARK", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pickingFile = false
    pending?(nil)
    pending = nil
  }

  /// Löst das Bookmark auf und öffnet den Zugriff für die Dauer von [body].
  private func withFolder<T>(_ base64: String, _ body: (URL) throws -> T) throws -> T {
    guard let data = Data(base64Encoded: base64) else {
      throw NSError(domain: "Sicherung", code: 1)
    }
    var stale = false
    let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    guard url.startAccessingSecurityScopedResource() else {
      throw NSError(domain: "Sicherung", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kein Zugriff auf den Ordner"])
    }
    defer { url.stopAccessingSecurityScopedResource() }
    return try body(url)
  }

  private func coordinatedWrite(_ data: Data, to url: URL) throws {
    var error: NSError?
    var thrown: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &error) { target in
      do { try data.write(to: target, options: .atomic) } catch { thrown = error }
    }
    if let e = error ?? thrown { throw e }
  }

  private func coordinatedRead(_ url: URL) throws -> Data {
    var error: NSError?
    var out: Result<Data, Error> = .failure(NSError(domain: "Sicherung", code: 3))
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { source in
      out = Result { try Data(contentsOf: source) }
    }
    if let e = error { throw e }
    return try out.get()
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
