import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

import 'e_invoice_parser.dart';
import 'ocr_text.dart';
import 'pdf_embedded_files.dart';

/// Ergebnis der Übernahme einer PDF- oder XML-Datei (L-27.5, L-27.6).
class ImportedDocument {
  const ImportedDocument({
    required this.file,
    required this.fileName,
    required this.mime,
    required this.sha256,
    required this.sizeBytes,
    this.eInvoice,
    this.pageImages = const [],
    this.textLayer,
  });

  /// Originaldatei, unverändert (L-27.8).
  final File file;
  final String fileName;
  final String mime;
  final String sha256;
  final int sizeBytes;

  /// Strukturierte Rechnung, wenn das XML (eigenständig oder in der PDF
  /// eingebettet) ein bekanntes Format hat.
  final EInvoice? eInvoice;

  /// Gerenderte PDF-Seiten als PNG (Vorschau und Texterkennung).
  final List<File> pageImages;

  /// Textebene der PDF (nur iOS/PDFKit), sonst `null`.
  final OcrDocument? textLayer;
}

/// Übernimmt PDF- und XML-Rechnungen. Alles auf dem Gerät.
///
/// Paketwahl (Spezifikation FA-2.40): keine PDF-Bibliothek. Eingebettete
/// E-Rechnungen liest `PdfEmbeddedFiles` in reinem Dart (zlib über das
/// vorhandene Paket `archive`); Seitenbilder liefert der Plattform-Renderer
/// (Android `PdfRenderer`, iOS PDFKit) über den Channel `buchhaltung/pdf`.
/// pdfrx (PDFium, mehrere MB je Architektur) und syncfusion_flutter_pdf
/// (kommerzielle Lizenz) wurden verworfen. XML parst `package:xml` (MIT).
class DocumentImporter {
  const DocumentImporter();

  static const _pdf = MethodChannel('buchhaltung/pdf');

  /// Höchstgröße einer übernommenen Datei.
  static const maxBytes = 20 * 1024 * 1024;

  /// Höchstens so viele PDF-Seiten werden gerendert und erkannt.
  static const maxPages = 5;

  Future<ImportedDocument> import(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const FormatException('Datei größer als 20 MB');
    }
    final name = file.uri.pathSegments.last.replaceFirst(
      RegExp(r'^\d+_\d+_'),
      '',
    );
    final hash = await sha256Hex(bytes);
    if (isPdf(bytes)) {
      EInvoice? invoice;
      for (final xml in PdfEmbeddedFiles.xml(bytes)) {
        invoice = EInvoiceParser.parse(xml);
        if (invoice != null) break;
      }
      var pages = <File>[];
      OcrDocument? text;
      try {
        final result = await _pdf.invokeMapMethod<String, Object?>('render', {
          'path': file.path,
          'maxPages': maxPages,
        });
        pages = [
          for (final p in (result?['pages'] as List? ?? const []))
            File(p as String),
        ];
        final texts = [
          for (final t in (result?['text'] as List? ?? const [])) t as String,
        ];
        final lines = <OcrLine>[
          for (var i = 0; i < texts.length; i++)
            for (final line in texts[i].split('\n'))
              if (line.trim().isNotEmpty) OcrLine(line.trim(), page: i + 1),
        ];
        if (lines.length >= 3) {
          text = OcrDocument(lines: lines, engine: 'PDF-Textebene (PDFKit)');
        }
      } on PlatformException {
        // Nicht renderbar (z. B. verschlüsselt): nur Original aufbewahren.
      } on MissingPluginException {
        // Tests ohne Plattform
      }
      return ImportedDocument(
        file: file,
        fileName: name,
        mime: 'application/pdf',
        sha256: hash,
        sizeBytes: bytes.length,
        eInvoice: invoice,
        pageImages: pages,
        textLayer: text,
      );
    }
    final source = String.fromCharCodes(bytes);
    final invoice = EInvoiceParser.parse(_utf8(bytes) ?? source);
    if (invoice == null) {
      throw const FormatException('Kein bekanntes Rechnungsformat');
    }
    return ImportedDocument(
      file: file,
      fileName: name,
      mime: 'application/xml',
      sha256: hash,
      sizeBytes: bytes.length,
      eInvoice: invoice,
    );
  }

  static bool isPdf(Uint8List bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46;

  static String? _utf8(Uint8List bytes) {
    try {
      return const Utf8Decoder().convert(bytes);
    } on FormatException {
      return null;
    }
  }
}

/// SHA-256 in Hex.
Future<String> sha256Hex(List<int> bytes) async {
  final hash = await Sha256().hash(bytes);
  return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
