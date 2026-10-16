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
  }) {
    final archive = Archive();
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
