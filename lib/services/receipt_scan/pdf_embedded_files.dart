import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Liest eingebettete Dateien (`/Type /EmbeddedFile`) aus einer PDF – genug
/// für ZUGFeRD/Factur-X, deren XML als Anhang in der PDF/A-3 steckt
/// (L-27.6; Factur-X 1.0 Kap. 5, ZUGFeRD 2.x: Datei `factur-x.xml`,
/// `zugferd-invoice.xml` bzw. `xrechnung.xml`).
///
/// Reines Dart ohne PDF-Bibliothek: Eingebettete Dateien sind immer eigene
/// Stream-Objekte (Streams dürfen nicht in Objektströmen liegen, ISO 32000-1
/// 7.5.7), ihr Wörterbuch steht also lesbar vor dem Stream. Unterstützt
/// werden ungefilterte und `/FlateDecode`-Streams; anderes wird übersprungen.
class PdfEmbeddedFiles {
  const PdfEmbeddedFiles._();

  /// Höchstgröße einer eingebetteten Datei nach dem Entpacken.
  static const maxBytes = 5 * 1024 * 1024;

  /// Alle eingebetteten XML-Dateien als Text, in Dateireihenfolge.
  static List<String> xml(Uint8List pdf) {
    final text = latin1.decode(pdf, allowInvalid: true);
    final result = <String>[];
    final objects = RegExp(r'\d+\s+\d+\s+obj\b');
    for (final m in objects.allMatches(text)) {
      final streamAt = text.indexOf('stream', m.end);
      final endObj = text.indexOf('endobj', m.end);
      if (streamAt < 0 || (endObj >= 0 && endObj < streamAt)) continue;
      final dict = text.substring(m.end, streamAt);
      if (!dict.contains('/EmbeddedFile')) continue;
      var start = streamAt + 'stream'.length;
      if (text.startsWith('\r\n', start)) {
        start += 2;
      } else if (text.startsWith('\n', start)) {
        start += 1;
      }
      final end = text.indexOf('endstream', start);
      if (end < 0) continue;
      var data = Uint8List.sublistView(pdf, start, end);
      final length = RegExp(r'/Length\s+(\d+)(\s+\d+\s+R)?').firstMatch(dict);
      if (length != null && length.group(2) == null) {
        final n = int.parse(length.group(1)!);
        if (n <= data.length) {
          data = Uint8List.sublistView(pdf, start, start + n);
        }
      }
      List<int> bytes;
      try {
        if (dict.contains('/FlateDecode')) {
          bytes = const ZLibDecoder().decodeBytes(data);
        } else if (!dict.contains('/Filter')) {
          bytes = data;
        } else {
          continue;
        }
      } catch (_) {
        continue;
      }
      if (bytes.length > maxBytes) continue;
      final content = utf8.decode(bytes, allowMalformed: true).trimLeft();
      final xml = content.startsWith('﻿') ? content.substring(1) : content;
      if (xml.startsWith('<?xml') || xml.startsWith('<')) result.add(xml);
    }
    return result;
  }
}
