import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Legt das Firmenlogo im Dokumentenverzeichnis der App ab (Lastenheft
/// L-1.7). Wie bei Belegfotos wird nur der relative Pfad gespeichert (NFA-4).
///
/// Eine Logodatei wird nie überschrieben und nie gelöscht: Wer das Logo
/// wechselt oder entfernt, ändert nur `company_profile.logo_path`. Gestellte
/// Rechnungen verweisen über ihren eingefrorenen `seller_snapshot` auf das
/// damals gültige Logo und bleiben so reproduzierbar (GR-8, CLAUDE.md Regel 7).
class LogoStore {
  const LogoStore._();

  /// Ordner relativ zum Dokumentenverzeichnis; wird mitgesichert.
  static const folder = 'logo';

  /// Längste Kante beim Auswählen. Ein Logo steht auf A4 in etwa 4 cm
  /// Breite; 800 px sind auch im Druck scharf und halten die Sicherung klein.
  static const maxEdgePx = 800;

  /// JPEG-Qualität beim Verkleinern; PNG bleibt verlustfrei.
  static const qualityPercent = 90;

  /// Kopiert [source] als neue Datei in den Logo-Ordner unter [base] und gibt
  /// den relativen Pfad zurück.
  static Future<String> storeIn(Directory base, File source) async {
    final dir = Directory(p.join(base.path, folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    final extension = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path).toLowerCase();
    final name = 'logo_${DateTime.now().microsecondsSinceEpoch}$extension';
    await source.copy(p.join(dir.path, name));
    return p.join(folder, name);
  }

  static Future<String> store(File source) async =>
      storeIn(await getApplicationDocumentsDirectory(), source);

  /// Liest das Logo unter [relativePath]; `null`, wenn es fehlt.
  static Future<Uint8List?> readBytes(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final base = await getApplicationDocumentsDirectory();
    final file = File(p.join(base.path, relativePath));
    return await file.exists() ? file.readAsBytes() : null;
  }

  static Future<File?> resolve(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final base = await getApplicationDocumentsDirectory();
    final file = File(p.join(base.path, relativePath));
    return await file.exists() ? file : null;
  }
}
