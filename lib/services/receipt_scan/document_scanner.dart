import 'dart:io';

import 'package:flutter/services.dart';

/// Dokumentenscanner des Systems (Spezifikation FA-2.51): Android Google ML
/// Kit Document Scanner (Play-Dienste), iOS VisionKit. Eigener schmaler
/// Channel wie bei der Texterkennung – kein zusätzliches Flutter-Paket.
///
/// Gespeichert wird nur das verarbeitete, entzerrte Bild (Entscheidung
/// Auftraggeberin 2026-10-16; bildliche Übereinstimmung P-S63).
class DocumentScanner {
  const DocumentScanner();

  static const _channel = MethodChannel('buchhaltung/document_scanner');

  /// Höchstens so viele Seiten je Scan.
  static const pageLimit = 20;

  /// Seiten als Dateien; leere Liste = abgebrochen; `null` = kein Scanner
  /// verfügbar (keine Play-Dienste, Modul-Download fehlgeschlagen, Huawei,
  /// Tests) → der Aufrufer nimmt ohne Rückfrage die Kamera.
  Future<List<File>?> scan() async {
    try {
      final paths = await _channel.invokeListMethod<String>('scan', {
        'pageLimit': pageLimit,
      });
      return [for (final p in paths ?? const <String>[]) File(p)];
    } on PlatformException catch (e) {
      if (e.code == 'busy') return const [];
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
