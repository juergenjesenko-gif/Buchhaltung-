import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'demo/demo_mode.dart';

/// Legt Belegfotos im Dokumentenverzeichnis der App ab.
///
/// Gespeichert wird nur der *relative* Pfad. Unter iOS ändert sich der absolute
/// Pfad des Anwendungscontainers bei jedem Update – ein absoluter Pfad in der
/// Datenbank wäre nach dem nächsten App-Update ins Leere gelaufen.
class ReceiptImageStore {
  const ReceiptImageStore._();

  /// In der Demo landen Fotos im eigenen Ordner `demo_belege/` (FA-13.14):
  /// nie bei den echten Belegen, nie in einer Sicherung, bei jedem
  /// Demo-Start geleert.
  static String get _folder => DemoMode.active ? demoFolder : 'belege';

  static const demoFolder = 'demo_belege';
  static int _seq = 0;

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Kopiert die Quelldatei in den App-Speicher und gibt den relativen Pfad zurück.
  static Future<String> store(File source) async {
    final dir = await _dir();
    final extension = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    // Laufnummer dazu: mehrere Scan-Seiten in derselben Millisekunde
    // überschrieben sonst einander.
    final name =
        'beleg_${DateTime.now().millisecondsSinceEpoch}_${_seq++}$extension';
    await source.copy(p.join(dir.path, name));
    return p.join(_folder, name);
  }

  /// Löst einen gespeicherten relativen Pfad zur Datei auf.
  static Future<File?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final base = await getApplicationDocumentsDirectory();
    final file = File(p.join(base.path, relativePath));
    return await file.exists() ? file : null;
  }

  static Future<void> delete(String? relativePath) async {
    final file = await resolve(relativePath);
    if (file != null) await file.delete();
  }
}
