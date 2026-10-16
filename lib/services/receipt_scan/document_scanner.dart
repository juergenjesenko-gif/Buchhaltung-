import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'scan_enhancer.dart';

/// Dokumentenscanner des Systems (Spezifikation FA-2.51): Android Google ML
/// Kit Document Scanner (Play-Dienste), iOS VisionKit. Eigener schmaler
/// Channel wie bei der Texterkennung – kein zusätzliches Flutter-Paket.
///
/// Gespeichert wird nur das verarbeitete, entzerrte und verbesserte Bild
/// ([ScanEnhancer]; Entscheidung Auftraggeberin 2026-10-16; P-S63).
class DocumentScanner {
  const DocumentScanner();

  static const _channel = MethodChannel('buchhaltung/document_scanner');

  /// Höchstens so viele Seiten je Scan.
  static const pageLimit = 20;

  /// Läuft gerade ein Scan? Gilt für die ganze App, wird aber in jedem Fall
  /// (Ergebnis, Abbruch, Fehler) im `finally` zurückgesetzt – es gibt keine
  /// dauerhafte Sperre mehr (Gerätetest 0.21.0).
  static bool _running = false;

  @visibleForTesting
  static bool get isRunning => _running;

  /// Seiten als Dateien; leere Liste = abgebrochen oder schon ein Scan offen
  /// (Doppeltipp); `null` = kein Scanner verfügbar (keine Play-Dienste,
  /// Modul-Download fehlgeschlagen, Huawei, Tests) → der Aufrufer nimmt ohne
  /// Rückfrage die Kamera.
  Future<List<File>?> scan() async {
    if (_running) return const [];
    _running = true;
    try {
      final paths = await _channel.invokeListMethod<String>('scan', {
        'pageLimit': pageLimit,
      });
      return [for (final p in paths ?? const <String>[]) File(p)];
    } on PlatformException catch (e) {
      // `busy` liefern neue Plattformstände nicht mehr; ältere als Abbruch.
      if (e.code == 'busy') return const [];
      return null;
    } on MissingPluginException {
      return null;
    } finally {
      _running = false;
    }
  }
}

/// Ergebnis von [ScanIntake.run].
enum ScanIntakeOutcome {
  /// Kein Scanner: der Aufrufer nimmt die Kamera.
  unavailable,

  /// Abgebrochen oder nichts gescannt.
  cancelled,

  /// Seiten übernommen und Auslesen angestoßen.
  added,
}

/// Gemeinsamer Weg Scan → Verbessern → Ablegen → Auslesen, damit gescannte
/// Seiten dieselbe Erkennung und Vorbelegung durchlaufen wie Kamerafotos
/// (Gerätetest 0.21.0: nach dem Scan blieb das Formular leer).
class ScanIntake {
  const ScanIntake._();

  static Future<ScanIntakeOutcome> run({
    required Future<String> Function(File page) store,
    required bool Function(String relativePath) onPage,
    required Future<void> Function() afterPages,
    DocumentScanner scanner = const DocumentScanner(),
    Future<File> Function(File page) enhance = enhanceScannedPage,
  }) async {
    final scanned = await scanner.scan();
    if (scanned == null) return ScanIntakeOutcome.unavailable;
    if (scanned.isEmpty) return ScanIntakeOutcome.cancelled;
    for (final file in scanned) {
      final relative = await store(await enhance(file));
      if (!onPage(relative)) return ScanIntakeOutcome.cancelled;
    }
    await afterPages();
    return ScanIntakeOutcome.added;
  }
}

/// Verbessert eine gescannte Seite im Hintergrund (an Ort und Stelle im
/// Cache). Ist sie nicht dekodierbar, bleibt sie unverändert.
Future<File> enhanceScannedPage(File page) async {
  try {
    final better = await ScanEnhancer.enhanceInBackground(
      await page.readAsBytes(),
    );
    if (better == null) return page;
    await page.writeAsBytes(better, flush: true);
  } on Exception catch (e) {
    debugPrint('Scan-Nachbearbeitung übersprungen: $e');
  }
  return page;
}
