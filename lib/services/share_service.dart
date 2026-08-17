import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Schreibt Exporte in einen temporären Ordner und öffnet den System-Dialog
/// zum Teilen.
///
/// Bewusst über das Teilen-Blatt und nicht über einen eigenen Speicherdialog:
/// so entscheidet der Nutzer, wohin die Daten gehen – Mail an die Kanzlei,
/// Cloud-Ordner, Messenger – und die App braucht keine Speicherberechtigung.
class ShareService {
  const ShareService._();

  static Future<File> _writeTemp(String fileName, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareCsv({
    required String fileName,
    required String content,
    String? subject,
  }) async {
    // utf8.encode, nicht String.codeUnits: Letzteres liefert UTF-16-Einheiten
    // und zerlegt jeden Umlaut im CSV.
    final file = await _writeTemp(fileName, utf8.encode(content));
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/csv'),
    ], subject: subject);
  }

  static Future<void> sharePdf({
    required String fileName,
    required Uint8List bytes,
    String? subject,
    String? text,
  }) async {
    final file = await _writeTemp(fileName, bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: text,
    );
  }
}
