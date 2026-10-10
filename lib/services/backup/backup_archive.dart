import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'backup_crypto.dart';

/// Inhaltsverzeichnis einer Sicherung. Wird vor der Wiederherstellung
/// angezeigt (Lastenheft L-7.3), damit die Nutzerin sieht, was sie einliest.
class BackupManifest {
  const BackupManifest({
    required this.createdAt,
    required this.schemaVersion,
    required this.companyName,
    required this.receiptCount,
    required this.invoiceCount,
    required this.customerCount,
    required this.imageCount,
  });

  final DateTime createdAt;
  final int schemaVersion;
  final String companyName;
  final int receiptCount;
  final int invoiceCount;
  final int customerCount;
  final int imageCount;

  Map<String, Object?> toJson() => {
    'format': BackupCrypto.formatVersion,
    'created_at': createdAt.toIso8601String(),
    'schema_version': schemaVersion,
    'company_name': companyName,
    'receipts': receiptCount,
    'invoices': invoiceCount,
    'customers': customerCount,
    'images': imageCount,
  };

  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
    createdAt: DateTime.parse(json['created_at'] as String),
    schemaVersion: json['schema_version'] as int,
    companyName: json['company_name'] as String? ?? '',
    receiptCount: json['receipts'] as int? ?? 0,
    invoiceCount: json['invoices'] as int? ?? 0,
    customerCount: json['customers'] as int? ?? 0,
    imageCount: json['images'] as int? ?? 0,
  );
}

/// Entpackter Inhalt einer Sicherung.
class BackupContent {
  const BackupContent({
    required this.manifest,
    required this.database,
    required this.images,
  });

  final BackupManifest manifest;

  /// SQLite-Datei als Bytes.
  final Uint8List database;

  /// Belegfotos, Schlüssel ist der relative Pfad wie in `receipts.image_path`.
  final Map<String, Uint8List> images;
}

/// Packt und entpackt den unverschlüsselten Inhalt (ZIP).
class BackupArchive {
  const BackupArchive._();

  static const _manifestName = 'manifest.json';
  static const _databaseName = 'datenbank/buchhaltung.db';

  static Uint8List pack(BackupContent content) {
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          _manifestName,
          utf8.encode(jsonEncode(content.manifest.toJson())),
        ),
      )
      ..addFile(ArchiveFile.bytes(_databaseName, content.database));
    for (final entry in content.images.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static BackupContent unpack(Uint8List zip) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zip);
    } catch (_) {
      throw const BackupFormatException(
        'Der Inhalt der Sicherung ist beschädigt.',
      );
    }
    BackupManifest? manifest;
    Uint8List? database;
    final images = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final bytes = file.content;
      if (file.name == _manifestName) {
        manifest = BackupManifest.fromJson(
          jsonDecode(utf8.decode(bytes)) as Map<String, Object?>,
        );
      } else if (file.name == _databaseName) {
        database = bytes;
      } else if (_isSafeImagePath(file.name)) {
        images[file.name] = bytes;
      }
    }
    if (manifest == null || database == null) {
      throw const BackupFormatException('Die Sicherung ist unvollständig.');
    }
    return BackupContent(
      manifest: manifest,
      database: database,
      images: images,
    );
  }

  /// Nur Dateien im Belegordner, ohne Verzeichniswechsel – eine manipulierte
  /// Sicherung darf nicht außerhalb des App-Speichers schreiben.
  static bool _isSafeImagePath(String name) =>
      name.startsWith('belege/') &&
      !name.contains('..') &&
      !name.contains('\\') &&
      name.split('/').length == 2;
}
