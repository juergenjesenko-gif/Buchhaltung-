import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/services/backup/backup_archive.dart';
import 'package:buchhaltung/services/backup/backup_crypto.dart';
import 'package:buchhaltung/services/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Datensicherung (Lastenheft L-7). Schnelle Argon2-Parameter nur im Test;
/// die App nutzt die Standardwerte aus [BackupCrypto].
void main() {
  setUpAll(sqfliteFfiInit);
  const fastCrypto = BackupCrypto(memoryKiB: 64, iterations: 1);

  group('Verschlüsselung', () {
    test('entschlüsselt mit richtigem Kennwort zum Original', () async {
      final plain = utf8.encode('Belege 2026');
      final sealed = await fastCrypto.encrypt(plain, 'richtiges-kennwort');
      expect(
        utf8.decode(sealed, allowMalformed: true),
        isNot(contains('Belege')),
      );
      final opened = await BackupCrypto.decrypt(sealed, 'richtiges-kennwort');
      expect(utf8.decode(opened), 'Belege 2026');
    });

    test('falsches Kennwort wird erkannt', () async {
      final sealed = await fastCrypto.encrypt([1, 2, 3], 'richtiges-kennwort');
      expect(
        () => BackupCrypto.decrypt(sealed, 'falsches-kennwort'),
        throwsA(isA<BackupPassphraseException>()),
      );
    });

    test('veränderte Datei wird erkannt', () async {
      final sealed = await fastCrypto.encrypt([1, 2, 3, 4], 'kennwort-123');
      sealed[sealed.length - 20] ^= 0xff;
      expect(
        () => BackupCrypto.decrypt(sealed, 'kennwort-123'),
        throwsA(isA<BackupPassphraseException>()),
      );
    });

    test('fremde Datei wird abgelehnt', () {
      expect(
        () => BackupCrypto.decrypt(Uint8List(100), 'kennwort-123'),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('Archiv', () {
    test('verwirft Pfade außerhalb des Belegordners', () {
      final zip = BackupArchive.pack(
        BackupContent(
          manifest: BackupManifest(
            createdAt: DateTime(2026, 10, 10),
            schemaVersion: AppDatabase.schemaVersion,
            companyName: 'Test',
            receiptCount: 0,
            invoiceCount: 0,
            customerCount: 0,
            imageCount: 2,
          ),
          database: Uint8List.fromList([1]),
          images: {
            'belege/a.jpg': Uint8List.fromList([1]),
            '../boese.txt': Uint8List.fromList([2]),
          },
        ),
      );
      final content = BackupArchive.unpack(zip);
      expect(content.images.keys, ['belege/a.jpg']);
    });
  });

  group('Sicherung und Wiederherstellung', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('sicherung_test');
    });
    tearDown(() async => root.delete(recursive: true));

    Future<Database> openDb(String name) => databaseFactoryFfi.openDatabase(
      p.join(root.path, name),
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );

    test('Daten und Fotos überstehen den Weg auf ein neues Gerät', () async {
      final oldDocs = await Directory(p.join(root.path, 'alt')).create();
      final newDocs = await Directory(p.join(root.path, 'neu')).create();
      await Directory(p.join(oldDocs.path, 'belege')).create();
      await File(
        p.join(oldDocs.path, 'belege', 'beleg_1.jpg'),
      ).writeAsBytes([9, 8, 7]);

      final oldDb = await openDb('alt.db');
      await oldDb.insert('company_profile', {
        'id': 1,
        'company_name': 'Atelier',
      });
      await oldDb.insert('receipts', {
        'date': '2026-05-01',
        'direction': 'income',
        'net_cents': 12000,
        'gross_cents': 12000,
        'image_path': 'belege/beleg_1.jpg',
        'created_at': '2026-05-01T00:00:00',
        'updated_at': '2026-05-01T00:00:00',
      });

      final file = await BackupService(
        db: oldDb,
        documentsDir: oldDocs,
        tempDir: root,
        crypto: fastCrypto,
        factory: databaseFactoryFfi,
      ).create('mein-sicheres-kennwort', now: DateTime(2026, 10, 10, 18));
      expect(p.basename(file.path), 'Sicherung_2026-10-10_1800.jbbackup');

      // Neues Gerät: leere Datenbank, schon eingerichtet mit anderen Daten.
      final newDb = await openDb('neu.db');
      await newDb.insert('company_profile', {'id': 1, 'company_name': 'Leer'});

      final content = await BackupService.open(
        await file.readAsBytes(),
        'mein-sicheres-kennwort',
      );
      expect(content.manifest.companyName, 'Atelier');
      expect(content.manifest.receiptCount, 1);
      expect(content.manifest.imageCount, 1);

      await BackupService(
        db: newDb,
        documentsDir: newDocs,
        tempDir: root,
        crypto: fastCrypto,
        factory: databaseFactoryFfi,
      ).restore(content);

      final profile = await newDb.query('company_profile');
      expect(profile.single['company_name'], 'Atelier');
      expect(profile.single['last_backup_at'], startsWith('2026-10-10'));
      final receipts = await newDb.query('receipts');
      expect(receipts.single['gross_cents'], 12000);
      expect(
        await File(p.join(newDocs.path, 'belege', 'beleg_1.jpg')).readAsBytes(),
        [9, 8, 7],
      );
      final log = await newDb.query(
        'audit_log',
        where: 'action = ?',
        whereArgs: ['restore'],
      );
      expect(log, hasLength(1));

      await oldDb.close();
      await newDb.close();
    });
  });
}
