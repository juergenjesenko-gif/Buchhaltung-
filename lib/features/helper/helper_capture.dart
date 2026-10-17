import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../../services/receipt_scan/document_import.dart';
import '../../services/receipt_scan/document_picker.dart';
import '../../services/receipt_scan/document_scanner.dart';
import '../../services/share_in/share_in_service.dart';

/// Woher die Seiten auf dem Mithelfer-Gerät kommen (wie die Aufnahmeleiste).
enum HelperSource { camera, gallery, file }

/// Holt Seitenbilder; leer bei Abbruch. PDF wird in Seitenbilder gewandelt.
Future<List<File>> captureHelperPages(HelperSource source) async {
  switch (source) {
    case HelperSource.camera:
      final scanned = await const DocumentScanner().scan();
      if (scanned != null) return scanned;
      return _pick(ImageSource.camera);
    case HelperSource.gallery:
      return _pick(ImageSource.gallery);
    case HelperSource.file:
      final files = await const DocumentPicker().pick();
      final pages = <File>[];
      for (final f in files) {
        if (sharedKindOf(f.path) == SharedKind.image) {
          pages.add(f);
        } else {
          final doc = await const DocumentImporter().import(f);
          pages.addAll(doc.pageImages);
        }
      }
      return pages;
  }
}

Future<List<File>> _pick(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 85,
  );
  return picked == null ? const [] : [File(picked.path)];
}
