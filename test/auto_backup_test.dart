import 'dart:io';
import 'dart:typed_data';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/services/backup/auto_backup_service.dart';
import 'package:buchhaltung/services/backup/backup_crypto.dart';
import 'package:buchhaltung/services/backup/backup_retention.dart';
import 'package:buchhaltung/services/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  group('Wiederherstellungscode', () {
    test('kodiert 32 Byte in 52 Zeichen und zurück', () {
      final key = RecoveryCode.newKey();
      final code = RecoveryCode.encode(key);
      expect(code.replaceAll('-', ''), hasLength(52));
      expect(RecoveryCode.tryDecode(code), key);
    });

    test('verzeiht Kleinschreibung, Leerzeichen und 0/1/8', () {
      final key = Uint8List(32);
      final code = RecoveryCode.encode(key); // nur A
      expect(
        RecoveryCode.tryDecode(code.toLowerCase().replaceAll('-', ' ')),
        key,
      );
      expect(RecoveryCode.tryDecode('ABC'), isNull);
    });

    test('Sicherung mit Schlüssel öffnet nur mit dem richtigen Code', () async {
      final key = RecoveryCode.newKey();
      final sealed = await BackupCrypto.encryptWithKey([1, 2, 3], key);
      expect(await BackupCrypto.decrypt(sealed, RecoveryCode.encode(key)), [
        1,
        2,
        3,
      ]);
      expect(
        () => BackupCrypto.decrypt(
          sealed,
          RecoveryCode.encode(RecoveryCode.newKey()),
        ),
        throwsA(isA<BackupPassphraseException>()),
      );
    });

    test('Format 1 mit Kennwort bleibt lesbar', () async {
      const crypto = BackupCrypto(memoryKiB: 64, iterations: 1);
      final sealed = await crypto.encrypt([7], 'altes-kennwort');
      expect(await BackupCrypto.decrypt(sealed, 'altes-kennwort'), [7]);
    });
  });

  group('Aufbewahrung', () {
    const retention = BackupRetention();
    String n(DateTime d) => BackupRetention.fileNameFor(d);

    test('behält 7 Tage, 12 Monate und jedes Jahr', () {
      final now = DateTime(2026, 10, 10, 12);
      final names = <String>[
        // 30 Tagesstände
        for (var i = 0; i < 30; i++) n(now.subtract(Duration(days: i))),
        // ein Stand je Monat zurück bis 2024
        for (var m = 1; m <= 30; m++) n(DateTime(2026, 9 - m, 15)),
        'Rechnung.pdf', // fremd, nie anfassen
      ];
      final deleted = retention.toDelete(names, now).toSet();
      final kept = names.where((x) => !deleted.contains(x)).toSet();

      for (var i = 0; i < 7; i++) {
        expect(kept, contains(n(now.subtract(Duration(days: i)))));
      }
      expect(deleted, isNot(contains('Rechnung.pdf')));
      // Jahre 2024 und 2025 je mindestens ein Stand.
      expect(kept.where((x) => x.contains('_2024-')), isNotEmpty);
      expect(kept.where((x) => x.contains('_2025-')), isNotEmpty);
      // Ältere Monate außerhalb der 12 Monate nur noch als Jahresstand.
      expect(kept.where((x) => x.contains('_2024-')), hasLength(1));
      expect(deleted, isNotEmpty);
    });
  });

  group('Automatischer Lauf', () {
    late Directory root;
    late Database db;
    late MemoryBackupTarget target;
    late MemoryKeyStore keys;
    late AutoBackupService service;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('auto_sicherung');
      db = await databaseFactoryFfi.openDatabase(
        p.join(root.path, 'db.db'),
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      await db.insert('company_profile', {
        'id': 1,
        'company_name': 'Atelier',
        'auto_backup_enabled': 1,
      });
      target = MemoryBackupTarget();
      keys = MemoryKeyStore()..key = RecoveryCode.newKey();
      service = AutoBackupService(
        db: db,
        backups: BackupService(
          db: db,
          documentsDir: root,
          tempDir: root,
          factory: databaseFactoryFfi,
        ),
        target: target,
        keys: keys,
      );
    });

    tearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });

    test(
      'sichert, prüft, protokolliert und ist danach erst bei Änderung fällig',
      () async {
        final now = DateTime(2026, 10, 10, 18);
        final first = await service.runIfDue(now: now);
        expect(first.ran, isTrue);
        expect(first.failed, isFalse);
        expect(
          target.files.keys.single,
          startsWith('Auto-Sicherung_2026-10-10'),
        );

        final profile = (await db.query('company_profile')).single;
        expect(profile['auto_backup_last_at'], startsWith('2026-10-10'));
        expect(profile['auto_backup_last_error'], isNull);
        final log = await db.query(
          'audit_log',
          where: "action = 'auto_backup'",
        );
        expect(log.single['detail'], contains('SHA-256'));

        // Am Folgetag ohne Änderung: nicht fällig.
        final later = now.add(const Duration(days: 1));
        expect(await service.isDue(later), isFalse);
        // Nach einer Buchung: fällig.
        await db.insert('audit_log', {
          'entity': 'receipt',
          'action': 'create',
          'created_at': now.add(const Duration(hours: 2)).toIso8601String(),
        });
        expect(await service.isDue(later), isTrue);
        // Aber nicht vor Ablauf von 24 Stunden.
        expect(await service.isDue(now.add(const Duration(hours: 3))), isFalse);

        final manifest = await service.verifyLatest(now: later);
        expect(manifest.companyName, 'Atelier');
      },
    );

    test('ausgeschaltet läuft nichts', () async {
      await db.update('company_profile', {'auto_backup_enabled': 0});
      expect((await service.runIfDue()).ran, isFalse);
      expect(target.files, isEmpty);
    });

    test('Fehlschlag wird gespeichert, nie verschwiegen', () async {
      target.available = false;
      final outcome = await service.run(now: DateTime(2026, 10, 10));
      expect(outcome.failed, isTrue);
      final profile = (await db.query('company_profile')).single;
      expect(profile['auto_backup_last_error'], contains('nicht erreichbar'));
      expect(profile['auto_backup_last_at'], isNull);
    });

    test('ohne Schlüssel kein stilles Weiterlaufen', () async {
      keys.key = null;
      final outcome = await service.run(now: DateTime(2026, 10, 10));
      expect(outcome.error, contains('Sicherungsschlüssel'));
    });
  });
}
