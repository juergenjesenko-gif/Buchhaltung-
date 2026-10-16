import 'dart:io';

import 'package:flutter/services.dart';

import 'document_scanner.dart';

/// Datei für einen neuen Beleg wählen (Knopf „Datei“ auf Übersicht und
/// Belegliste, FA-12.1): Bilder, PDF, XML-E-Rechnung. Eigener schmaler
/// Channel, kein zusätzliches Paket. Die Plattform kopiert die Dateien in
/// den Cache und liefert absolute Pfade.
class DocumentPicker {
  const DocumentPicker();

  static const _channel = MethodChannel('buchhaltung/document_picker');

  /// Gewählte Dateien; leere Liste = abgebrochen. Wirft
  /// [DocumentScanException] mit einer anzeigbaren Meldung, wenn die Auswahl
  /// fehlschlägt oder auf dem Gerät nicht verfügbar ist – kein stiller Weg.
  Future<List<File>> pick() async {
    try {
      final paths = await _channel.invokeListMethod<String>('pick');
      return [for (final p in paths ?? const <String>[]) File(p)];
    } on PlatformException catch (e) {
      throw DocumentScanException(
        'Datei konnte nicht geöffnet werden: ${e.message ?? e.code}',
      );
    } on MissingPluginException {
      throw const DocumentScanException(
        'Dateiauswahl ist auf diesem Gerät nicht verfügbar – bitte die '
        'Datei über „Teilen“ an die App senden.',
      );
    }
  }
}
