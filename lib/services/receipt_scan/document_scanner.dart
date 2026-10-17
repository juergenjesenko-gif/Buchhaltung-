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
  /// Rückfrage die Kamera. Jeder andere Plattformfehler (Seite nicht lesbar,
  /// Ergebnis verloren) wirft [DocumentScanException], damit die Nutzerin
  /// eine Meldung sieht statt eines leeren Formulars (Gerätetest 0.22.0).
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
      if (e.code == 'unavailable') return null;
      throw DocumentScanException(e.message ?? e.code);
    } on MissingPluginException {
      return null;
    } finally {
      _running = false;
    }
  }
}

/// Scan fehlgeschlagen, obwohl der Scanner lief; [message] wird angezeigt.
class DocumentScanException implements Exception {
  const DocumentScanException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Ergebnis von [ScanIntake.run].
enum ScanIntakeOutcome {
  /// Kein Scanner: der Aufrufer nimmt die Kamera.
  unavailable,

  /// Abgebrochen oder nichts gescannt.
  cancelled,

  /// Seiten übernommen und Auslesen angestoßen.
  added,

  /// Fehler; die Meldung ging an `onError`.
  failed,
}

/// Gemeinsamer Weg Scan → Verbessern → Ablegen → Auslesen, damit gescannte
/// Seiten dieselbe Erkennung und Vorbelegung durchlaufen wie Kamerafotos
/// (Gerätetest 0.21.0: nach dem Scan blieb das Formular leer).
class ScanIntake {
  const ScanIntake._();

  /// Kein stiller Weg (Gerätetest 0.22.0): jeder Fehler – Scanner, Ablegen,
  /// Auslesen – geht als Text an [onError]; der Aufrufer zeigt ihn an.
  /// Schlägt nur die Verbesserung fehl, wird das Original abgelegt.
  static Future<ScanIntakeOutcome> run({
    required Future<String> Function(File page) store,
    required bool Function(String relativePath) onPage,
    required Future<void> Function() afterPages,
    required void Function(String message) onError,
    DocumentScanner scanner = const DocumentScanner(),
    Future<File> Function(File page) enhance = enhanceScannedPage,
    Future<void> Function(File original)? beforeEnhance,
  }) async {
    final List<File>? scanned;
    try {
      scanned = await scanner.scan();
    } on DocumentScanException catch (e) {
      onError('Scan fehlgeschlagen: ${e.message}');
      return ScanIntakeOutcome.failed;
    }
    if (scanned == null) return ScanIntakeOutcome.unavailable;
    if (scanned.isEmpty) return ScanIntakeOutcome.cancelled;
    var added = 0;
    final failed = <int>[];
    for (var i = 0; i < scanned.length; i++) {
      final original = scanned[i];
      // Codes (Kassen-QR) auch auf dem unverbesserten Original lesen: die
      // Kontrastverstärkung kann feine QR-Module verschlucken (FA-2.62).
      if (beforeEnhance != null) {
        try {
          await beforeEnhance(original);
        } catch (e) {
          debugPrint('Codes auf dem Original nicht gelesen: $e');
        }
      }
      File page;
      try {
        page = await enhance(original);
      } catch (e) {
        debugPrint('Scan-Nachbearbeitung übersprungen: $e');
        page = original;
      }
      final String relative;
      try {
        relative = await store(page);
      } catch (e) {
        debugPrint('Scan-Seite ${i + 1} nicht abgelegt: $e');
        failed.add(i + 1);
        continue;
      }
      if (!onPage(relative)) return ScanIntakeOutcome.cancelled;
      added++;
    }
    if (failed.isNotEmpty) {
      onError(
        failed.length == 1
            ? 'Seite ${failed.single} konnte nicht gespeichert werden.'
            : 'Seiten ${failed.join(', ')} konnten nicht gespeichert werden.',
      );
    }
    if (added == 0) return ScanIntakeOutcome.failed;
    try {
      await afterPages();
    } catch (e) {
      onError('Beleg konnte nicht ausgelesen werden: $e');
    }
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
  } catch (e) {
    // Auch Errors (z. B. Speicher im Isolate): Original behalten.
    debugPrint('Scan-Nachbearbeitung übersprungen: $e');
  }
  return page;
}
