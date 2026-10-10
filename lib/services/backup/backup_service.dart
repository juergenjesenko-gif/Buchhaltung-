import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/app_database.dart';
import '../../data/backup_repository.dart';
import 'backup_archive.dart';
import 'backup_crypto.dart';

/// Erstellt und liest verschlüsselte Vollsicherungen (Lastenheft L-7.1, L-7.3).
///
/// Ablageort ist Sache der Nutzerin: die Datei geht über den Teilen-Dialog
/// bzw. die Dateiauswahl in ihren eigenen Cloud-Speicher (iCloud Drive,
/// Google Drive) oder auf ein anderes Gerät. Der Anbieter sieht sie nie.
class BackupService {
  BackupService({
    required Database db,
    required this.documentsDir,
    required this.tempDir,
    this.crypto = const BackupCrypto(),
    DatabaseFactory? factory,
  }) : _db = db,
       _repository = BackupRepository(db, factory: factory);

  final Database _db;
  final BackupRepository _repository;

  /// Dokumentenverzeichnis der App; Belegfotos liegen in `belege/`.
  final Directory documentsDir;
  final Directory tempDir;
  final BackupCrypto crypto;

  /// Dateiendung der Sicherungen.
  static const extension = '.jbbackup';

  static String fileNameFor(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Sicherung_${at.year}-${two(at.month)}-${two(at.day)}_'
        '${two(at.hour)}${two(at.minute)}$extension';
  }

  /// Erstellt die verschlüsselte Sicherung und gibt die Datei zurück.
  Future<File> create(String passphrase, {DateTime? now}) async {
    final createdAt = now ?? DateTime.now();
    final zip = await _pack(createdAt);
    final encrypted = await crypto.encrypt(zip, passphrase);
    final file = File(p.join(tempDir.path, fileNameFor(createdAt)));
    await file.writeAsBytes(encrypted, flush: true);
    await _markBackedUp(createdAt);
    return file;
  }

  /// Automatische Sicherung: verschlüsselt mit dem Sicherungsschlüssel und
  /// gibt die Bytes zurück; das Ziel schreibt [AutoBackupService].
  Future<Uint8List> createWithKey(
    List<int> key, {
    required DateTime now,
  }) async {
    final zip = await _pack(now);
    final encrypted = await BackupCrypto.encryptWithKey(zip, key);
    await _markBackedUp(now);
    return encrypted;
  }

  Future<void> _markBackedUp(DateTime at) =>
      _db.update('company_profile', {'last_backup_at': at.toIso8601String()});

  Future<Uint8List> _pack(DateTime createdAt) async {
    final snapshotPath = p.join(tempDir.path, 'sicherung_snapshot.db');
    await _repository.snapshot(snapshotPath);
    final snapshot = File(snapshotPath);
    final database = await snapshot.readAsBytes();
    await snapshot.delete();

    final images = <String, Uint8List>{};
    final imageDir = Directory(p.join(documentsDir.path, 'belege'));
    if (await imageDir.exists()) {
      await for (final entity in imageDir.list()) {
        if (entity is File) {
          images['belege/${p.basename(entity.path)}'] = await entity
              .readAsBytes();
        }
      }
    }

    final counts = await _repository.counts();
    final profile = await _db.query('company_profile', limit: 1);
    final manifest = BackupManifest(
      createdAt: createdAt,
      schemaVersion: AppDatabase.schemaVersion,
      companyName: profile.isEmpty
          ? ''
          : profile.first['company_name'] as String? ?? '',
      receiptCount: counts['receipts']!,
      invoiceCount: counts['invoices']!,
      customerCount: counts['customers']!,
      imageCount: images.length,
    );

    return BackupArchive.pack(
      BackupContent(manifest: manifest, database: database, images: images),
    );
  }

  /// Entschlüsselt und entpackt eine Sicherung, ohne etwas zu verändern –
  /// Grundlage der Vorschau (L-7.3).
  static Future<BackupContent> open(Uint8List data, String passphrase) async {
    final zip = await BackupCrypto.decrypt(data, passphrase);
    final content = BackupArchive.unpack(zip);
    if (content.manifest.schemaVersion > AppDatabase.schemaVersion) {
      throw const BackupFormatException(
        'Die Sicherung stammt aus einer neueren App-Version. '
        'Bitte zuerst die App aktualisieren.',
      );
    }
    return content;
  }

  /// Ersetzt alle Daten und Belegfotos durch den Inhalt der Sicherung.
  Future<void> restore(BackupContent content) async {
    final dbPath = p.join(tempDir.path, 'wiederherstellung.db');
    final dbFile = File(dbPath);
    await dbFile.writeAsBytes(content.database, flush: true);
    try {
      await _repository.restoreFrom(dbPath);
    } finally {
      if (await dbFile.exists()) await dbFile.delete();
    }

    final imageDir = Directory(p.join(documentsDir.path, 'belege'));
    if (await imageDir.exists()) await imageDir.delete(recursive: true);
    await imageDir.create(recursive: true);
    for (final entry in content.images.entries) {
      await File(
        p.join(documentsDir.path, entry.key),
      ).writeAsBytes(entry.value, flush: true);
    }

    await _db.update('company_profile', {
      'last_backup_at': content.manifest.createdAt.toIso8601String(),
    });
    await _db.insert('audit_log', {
      'entity': 'backup',
      'action': 'restore',
      'detail': 'Sicherung vom ${content.manifest.createdAt.toIso8601String()}',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
