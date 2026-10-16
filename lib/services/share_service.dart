import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
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

  static const _channel = MethodChannel('buchhaltung/share_out');

  /// Android teilt über den eigenen Kanal (FA-5.35): share_plus leert seinen
  /// Cache-Ordner bei jedem Teilen, Gmail lädt Anhänge aber erst später hoch
  /// – beim Empfänger kam „Download fehlgeschlagen“ an.
  static bool get _ownChannel => Platform.isAndroid;

  static Future<File> _writeTemp(String fileName, List<int> bytes) async {
    final dirPath = _ownChannel
        ? (await _channel.invokeMethod<String>('folder'))!
        : (await getTemporaryDirectory()).path;
    final file = File(p.join(dirPath, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> _share(
    File file,
    String mimeType, {
    String? subject,
    String? text,
  }) async {
    if (_ownChannel) {
      await _channel.invokeMethod<bool>('share', {
        'path': file.path,
        'mimeType': mimeType,
        'subject': ?subject,
        'text': ?text,
      });
      return;
    }
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: subject,
      text: text,
    );
  }

  static Future<void> shareCsv({
    required String fileName,
    required String content,
    String? subject,
  }) async {
    // utf8.encode, nicht String.codeUnits: Letzteres liefert UTF-16-Einheiten
    // und zerlegt jeden Umlaut im CSV.
    final file = await _writeTemp(fileName, utf8.encode(content));
    await _share(file, 'text/csv', subject: subject);
  }

  /// XML-Datei teilen, z. B. die U30-Datei für FinanzOnline (FA-14.4).
  static Future<void> shareXml({
    required String fileName,
    required String content,
    String? subject,
  }) async {
    final file = await _writeTemp(fileName, utf8.encode(content));
    await _share(file, 'application/xml', subject: subject);
  }

  static Future<void> sharePdf({
    required String fileName,
    required Uint8List bytes,
    String? subject,
    String? text,
  }) async {
    final file = await _writeTemp(fileName, bytes);
    await _share(file, 'application/pdf', subject: subject, text: text);
  }
}
