import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

import 'ocr_text.dart';

/// Texterkennung auf dem Gerät über einen eigenen Platform-Channel:
/// Android Google ML Kit Text Recognition (Latin, gebündeltes Modell) in
/// `android/.../ReceiptTextChannel.kt`, iOS Apple Vision in
/// `ios/Runner/ReceiptTextChannel.swift`. Bilder und Text verlassen das Gerät
/// nicht. Auf demselben Bild werden QR- und Barcodes gelesen (ML Kit Barcode
/// Scanning gebündelt bzw. VNDetectBarcodesRequest, L-27.1); zur Telemetrie von ML Kit siehe docs/PRIVACY.md.
class PlatformReceiptTextRecognizer implements ReceiptTextRecognizer {
  const PlatformReceiptTextRecognizer();

  static const _channel = MethodChannel('buchhaltung/receipt_text');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<OcrDocument> recognize(List<String> absoluteImagePaths) async {
    final lines = <OcrLine>[];
    final codes = <String>[];
    var engine = 'unbekannt';
    var version = '';
    for (var i = 0; i < absoluteImagePaths.length; i++) {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'recognize',
        {'path': absoluteImagePaths[i]},
      );
      if (result == null) continue;
      engine = result['engine'] as String? ?? engine;
      version = result['engineVersion'] as String? ?? version;
      for (final code in (result['codes'] as List? ?? const [])) {
        if (code is String && code.isNotEmpty) codes.add(code);
      }
      for (final raw in (result['lines'] as List? ?? const [])) {
        final map = (raw as Map).cast<String, Object?>();
        lines.add(
          OcrLine(
            map['text'] as String? ?? '',
            page: i + 1,
            left: (map['left'] as num?)?.toInt() ?? 0,
            top: (map['top'] as num?)?.toInt() ?? 0,
            height: (map['height'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return OcrDocument(
      lines: lines,
      engine: engine,
      engineVersion: version,
      codes: codes,
    );
  }
}

/// SHA-256 der Originalbilder fürs Protokoll; das Bild selbst bleibt
/// unverändert und wird nicht protokolliert.
Future<List<String>> sha256OfFiles(List<String> absolutePaths) async {
  final result = <String>[];
  for (final path in absolutePaths) {
    final hash = await Sha256().hash(await File(path).readAsBytes());
    result.add(
      hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }
  return result;
}
