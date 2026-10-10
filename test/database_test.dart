import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Migrationen sind unveränderlich (CLAUDE.md, Grundregel 6). Was hier
/// schiefgeht, lässt sich bei bestehenden Nutzern nicht mehr reparieren –
/// deshalb laufen diese Tests gegen eine echte SQLite-Datenbank.
void main() {
  setUpAll(sqfliteFfiInit);

  Future<Database> openFresh() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onCreate: AppDatabase.createSchema,
      singleInstance: false,
    ),
  );

  Future<List<String>> columnsOf(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toList();
  }

  group('Neuanlage', () {
    test(
      'legt die Eröffnungswerte-Tabelle und den Erfassungsbeginn an',
      () async {
        final db = await openFresh();
        expect(await columnsOf(db, 'opening_turnover'), [
          'year',
          'net_cents',
          'updated_at',
        ]);
        expect(
          await columnsOf(db, 'company_profile'),
          contains('tracking_start'),
        );
        await db.close();
      },
    );

    test('legt die Startkategorien genau einmal an', () async {
      final db = await openFresh();
      final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM categories');
      final count = rows.single['n'] as int;
      expect(count, AppDatabase.seedCategories.length);
      await db.close();
    });
  });

  group('Upgrade von Version 1', () {
    Future<Database> openV1() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );

    Future<void> insertProfile(Database db) =>
        db.insert('company_profile', {'id': 1, 'company_name': 'Bestand e.U.'});

    Future<void> insertReceipt(Database db, String date) =>
        db.insert('receipts', {
          'date': date,
          'direction': 'income',
          'net_cents': 10000,
          'gross_cents': 10000,
          'created_at': '2026-08-17T10:00:00',
          'updated_at': '2026-08-17T10:00:00',
        });

    test('setzt den Erfassungsbeginn auf den ältesten Beleg', () async {
      final db = await openV1();
      await insertProfile(db);
      await insertReceipt(db, '2026-09-03');
      await insertReceipt(db, '2026-08-20');

      await AppDatabase.upgradeSchema(db, 1, 2);

      final row = (await db.query('company_profile')).single;
      expect(row['tracking_start'], '2026-08-20');
      await db.close();
    });

    test(
      'ohne Belege gilt der Tag der Migration als Erfassungsbeginn',
      () async {
        final db = await openV1();
        await insertProfile(db);

        await AppDatabase.upgradeSchema(db, 1, 2);

        final row = (await db.query('company_profile')).single;
        final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
        expect(row['tracking_start'], today);
        await db.close();
      },
    );

    test('bestehende Belege bleiben unverändert erhalten', () async {
      final db = await openV1();
      await insertProfile(db);
      await insertReceipt(db, '2026-08-20');

      await AppDatabase.upgradeSchema(db, 1, 2);

      final receipts = await db.query('receipts');
      expect(receipts, hasLength(1));
      expect(receipts.single['net_cents'], 10000);
      await db.close();
    });
  });

  group('OpeningTurnoverRepository', () {
    test('unterscheidet "nicht erfasst" von 0 €', () async {
      final db = await openFresh();
      final repo = OpeningTurnoverRepository(db);

      expect(await repo.forYear(2025), isNull);
      await repo.save(2025, const Money.zero());
      expect(await repo.forYear(2025), const Money.zero());
      await db.close();
    });

    test('überschreibt und löscht einen Eröffnungswert', () async {
      final db = await openFresh();
      final repo = OpeningTurnoverRepository(db);

      await repo.save(2025, const Money(3000000));
      await repo.save(2025, const Money(3100000));
      expect(await repo.forYear(2025), const Money(3100000));

      await repo.save(2025, null);
      expect(await repo.forYear(2025), isNull);
      await db.close();
    });

    test('protokolliert jede Änderung', () async {
      final db = await openFresh();
      await OpeningTurnoverRepository(db).save(2025, const Money(3000000));

      final log = await db.query(
        'audit_log',
        where: 'entity = ?',
        whereArgs: ['opening_turnover'],
      );
      expect(log, hasLength(1));
      expect(log.single['entity_id'], 2025);
      await db.close();
    });
  });

  group('InvoiceRepository', () {
    Future<(Database, int)> openWithCustomer() async {
      final db = await openFresh();
      await db.insert('company_profile', {'id': 1, 'company_name': 'Test'});
      final customerId = await db.insert('customers', {'name': 'Kundin'});
      return (db, customerId);
    }

    Invoice draft(int customerId) => Invoice(
      number: 'ENTWURF-1',
      issueDate: DateTime(2026, 10, 10),
      customerId: customerId,
      items: [
        InvoiceItem(
          position: 1,
          description: 'Beratung',
          quantityMilli: 1000,
          unitPrice: const Money(10000),
          vatPermille: 200,
        ),
      ],
    );

    test(
      'vergibt die Nummer beim Ausstellen in derselben Transaktion',
      () async {
        final (db, customerId) = await openWithCustomer();
        final repo = InvoiceRepository(db);

        final first = await repo.save(
          draft(customerId).copyWith(status: InvoiceStatus.issued),
          assignNumber: (n) => 'RE-$n',
        );
        final second = await repo.save(
          draft(customerId).copyWith(status: InvoiceStatus.issued),
          assignNumber: (n) => 'RE-$n',
        );

        expect((await repo.byId(first))!.number, 'RE-1');
        expect((await repo.byId(second))!.number, 'RE-2');
        await db.close();
      },
    );

    test('gestellte Rechnungen lassen sich nicht überschreiben', () async {
      final (db, customerId) = await openWithCustomer();
      final repo = InvoiceRepository(db);
      final id = await repo.save(
        draft(customerId).copyWith(status: InvoiceStatus.issued),
        assignNumber: (n) => 'RE-$n',
      );
      final issued = (await repo.byId(id))!;

      await expectLater(
        repo.save(issued.copyWith(notes: 'nachträglich geändert')),
        throwsStateError,
      );
      expect((await repo.byId(id))!.notes, isNot('nachträglich geändert'));
      await db.close();
    });

    test('ein Entwurf bleibt änderbar und verbraucht keine Nummer', () async {
      final (db, customerId) = await openWithCustomer();
      final repo = InvoiceRepository(db);
      final id = await repo.save(draft(customerId));
      await repo.save((await repo.byId(id))!.copyWith(notes: 'neu'));

      expect((await repo.byId(id))!.notes, 'neu');
      final profile = await db.query('company_profile');
      expect(profile.first['next_invoice_sequence'], 1);
      await db.close();
    });
  });
}
