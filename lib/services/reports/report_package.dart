import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Paket für die Steuerberatung (FA-15.10): PDF(s) und CSV-Exporte in einer
/// ZIP-Datei, damit ein Tipp genügt.
class ReportPackage {
  ReportPackage._();

  static Uint8List zip({
    required Map<String, Uint8List> pdfs,
    required Map<String, String> csvs,
    Map<String, Uint8List> files = const {},
  }) {
    final archive = Archive();
    // Belegkopien (FA-15.12): Pfad im ZIP, z. B. `Belege/12_2026-03-04_1.jpg`.
    files.forEach(
      (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)),
    );
    pdfs.forEach(
      (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)),
    );
    csvs.forEach(
      (name, text) =>
          archive.addFile(ArchiveFile.bytes(name, utf8.encode(text))),
    );
    return ZipEncoder().encodeBytes(archive);
  }
}

/// Dateiname einer Belegkopie im Paket: Beleg-ID (= DATEV „Belegfeld 1“,
/// BMD „Belegnummer“), Datum, Seite. So findet die Kanzlei zu jeder Buchung
/// das Bild (FA-15.12).
String receiptCopyName(int id, DateTime date, int page, String extension) =>
    'Belege/${id}_${date.toIso8601String().substring(0, 10)}_$page.$extension';
