import 'dart:convert';
import 'dart:io';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/invoice_logo.dart';
import 'package:buchhaltung/services/invoice_seller.dart';
import 'package:buchhaltung/services/logo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Schema 8: Belegseiten (L-2.15, L-2.16), Kommentare (L-2.17) und
/// Firmenlogo (L-1.7).
void main() {
  setUpAll(sqfliteFfiInit);

  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('schema8_test');
  });
  tearDown(() async => root.delete(recursive: true));

  Future<Database> openAt(String name, int version) =>
      databaseFactoryFfi.openDatabase(
        p.join(root.path, name),
        options: OpenDatabaseOptions(
          version: version,
          onCreate: AppDatabase.createSchema,
          onUpgrade: AppDatabase.upgradeSchema,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          singleInstance: false,
        ),
      );

  Receipt receipt({int? id}) => Receipt(
    id: id,
    date: DateTime(2026, 10, 1),
    direction: BookingDirection.expense,
    description: 'Tankrechnung',
    net: const Money(10000),
    vat: const Money(2000),
    gross: const Money(12000),
    vatPermille: 200,
  );

  group('Migration auf Schema 8', () {
    test('macht bestehende Einzelfotos zur Seite 1', () async {
      final v7 = await openAt('alt.db', 7);
      for (final path in ['belege/a.jpg', null, '']) {
        await v7.insert('receipts', {
          'date': '2026-05-01',
          'direction': 'expense',
          'image_path': path,
          'created_at': '2026-05-01T08:00:00',
          'updated_at': '2026-05-02T09:00:00',
        });
      }
      await v7.close();

      final v8 = await openAt('alt.db', 8);
      final pages = await v8.query('receipt_pages');
      expect(pages, hasLength(1));
      expect(pages.single['receipt_id'], 1);
      expect(pages.single['position'], 1);
      expect(pages.single['image_path'], 'belege/a.jpg');
      expect(pages.single['created_at'], '2026-05-02T09:00:00');
      // Der Beleg selbst bleibt unverändert.
      final receipts = await v8.query('receipts', orderBy: 'id');
      expect(receipts.first['image_path'], 'belege/a.jpg');
      final profileColumns = await v8.rawQuery(
        'PRAGMA table_info(company_profile)',
      );
      expect(profileColumns.map((c) => c['name']), contains('logo_path'));
      await v8.close();
    });
  });

  group('Belegseiten', () {
    test(
      'speichert Seiten in Reihenfolge und protokolliert die Zahl',
      () async {
        final db = await openAt('s.db', AppDatabase.schemaVersion);
        final repo = ReceiptRepository(db);
        final id = await repo.save(
          receipt(),
          pages: ['belege/2.jpg', 'belege/1.jpg', 'belege/3.jpg'],
        );
        final pages = await repo.pages(id);
        expect(pages.map((x) => x.imagePath), [
          'belege/2.jpg',
          'belege/1.jpg',
          'belege/3.jpg',
        ]);
        expect(pages.map((x) => x.position), [1, 2, 3]);
        expect((await repo.byId(id))!.imagePath, 'belege/2.jpg');
        expect(await repo.pageCounts(), {id: 3});
        final log = await db.query('audit_log', where: "action = 'create'");
        expect(log.single['detail'], contains('3 Seite(n)'));
        expect(log.single['detail'], isNot(contains('Vollständigkeit')));
        await db.close();
      },
    );

    test(
      'Speichern mit Bestätigung protokolliert die Vollständigkeit',
      () async {
        final db = await openAt('s.db', AppDatabase.schemaVersion);
        final repo = ReceiptRepository(db);
        final id = await repo.save(
          receipt(),
          pages: ['belege/1.jpg', 'belege/2.jpg'],
          completenessConfirmed: true,
        );
        await repo.save(
          receipt(id: id),
          pages: ['belege/1.jpg', 'belege/2.jpg', 'belege/3.jpg'],
          completenessConfirmed: true,
        );
        final log = await db.query(
          'audit_log',
          where: "action IN ('create', 'update')",
          orderBy: 'id',
        );
        expect(
          log.first['detail'],
          contains('2 Seite(n), Vollständigkeit bestätigt'),
        );
        expect(
          log.last['detail'],
          contains('3 Seite(n), Vollständigkeit bestätigt'),
        );
        await db.close();
      },
    );

    test('nach dem Speichern nur noch Seiten anhängen', () async {
      final db = await openAt('s.db', AppDatabase.schemaVersion);
      final repo = ReceiptRepository(db);
      final id = await repo.save(receipt(), pages: ['belege/1.jpg']);
      final saved = (await repo.byId(id))!;

      await repo.save(saved, pages: ['belege/1.jpg', 'belege/2.jpg']);
      expect((await repo.pages(id)).map((x) => x.position), [1, 2]);

      await expectLater(
        () => repo.save(saved, pages: ['belege/2.jpg']),
        throwsStateError,
      );
      await expectLater(
        () => repo.save(saved, pages: ['belege/2.jpg', 'belege/1.jpg']),
        throwsStateError,
      );
      expect(await repo.pages(id), hasLength(2));
      await db.close();
    });

    test('ein stornierter Beleg ist schreibgeschützt', () async {
      final db = await openAt('s.db', AppDatabase.schemaVersion);
      final repo = ReceiptRepository(db);
      final id = await repo.save(receipt());
      await repo.cancel(id);
      await expectLater(() => repo.save(receipt(id: id)), throwsStateError);
      await db.close();
    });
  });

  group('Kommentare', () {
    test(
      'werden angehängt, auch an stornierte Belege, mit Protokoll',
      () async {
        final db = await openAt('k.db', AppDatabase.schemaVersion);
        final repo = ReceiptRepository(db);
        final id = await repo.save(receipt(), comment: '  Erster Eintrag ');
        await repo.cancel(id);
        await repo.addComment(id, 'Storno wegen Doppelerfassung');

        final comments = await repo.comments(id);
        expect(comments.map((c) => c.text), [
          'Erster Eintrag',
          'Storno wegen Doppelerfassung',
        ]);
        expect((await repo.query(cancelledOnly: true)).single.id, id);
        expect((await repo.allComments())[id], hasLength(2));
        final log = await db.query('audit_log', where: "action = 'comment'");
        expect(log, hasLength(2));
        await db.close();
      },
    );

    test('leere Kommentare werden abgelehnt', () async {
      final db = await openAt('k.db', AppDatabase.schemaVersion);
      final repo = ReceiptRepository(db);
      final id = await repo.save(receipt());
      await expectLater(() => repo.addComment(id, '   '), throwsArgumentError);
      await db.close();
    });

    test('die Datenbank verhindert das Ändern eines Kommentars', () async {
      final db = await openAt('k.db', AppDatabase.schemaVersion);
      final repo = ReceiptRepository(db);
      final id = await repo.save(receipt(), comment: 'Original');
      await expectLater(
        db.update('receipt_comments', {'text': 'Geändert'}),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repo.comments(id)).single.text, 'Original');
      await db.close();
    });
  });

  group('Firmenlogo', () {
    const profile = CompanyProfile(
      companyName: 'Muster e.U.',
      country: Country.at,
      logoPath: 'logo/neu.png',
    );

    Invoice invoice(InvoiceStatus status, Map<String, Object?>? snapshot) =>
        Invoice(
          number: 'RE-1',
          issueDate: DateTime(2026, 10, 1),
          customerId: 1,
          items: const [],
          status: status,
          sellerSnapshot: snapshot == null ? null : jsonEncode(snapshot),
        );

    test('gestellte Rechnungen zeigen das eingefrorene Logo', () {
      expect(
        InvoiceLogo.pathFor(
          invoice(InvoiceStatus.issued, {'logo_path': 'logo/alt.png'}),
          profile,
          logoAllowed: true,
        ),
        'logo/alt.png',
      );
      // Rechnung vor Schema 8: kein Logo, wie damals.
      expect(
        InvoiceLogo.pathFor(
          invoice(InvoiceStatus.paid, {'company_name': 'X'}),
          profile,
          logoAllowed: true,
        ),
        isNull,
      );
    });

    test('Entwürfe zeigen das aktuelle Logo', () {
      expect(
        InvoiceLogo.pathFor(
          invoice(InvoiceStatus.draft, {'logo_path': 'logo/alt.png'}),
          profile,
          logoAllowed: true,
        ),
        'logo/neu.png',
      );
    });

    test('mit Basis kein Logo auf neuen Belegen, gestellte behalten es', () {
      // Entscheidung 2026-10-16 (FA-13.12): Logo nur mit Pro oder Test.
      expect(
        InvoiceLogo.pathFor(
          invoice(InvoiceStatus.draft, null),
          profile,
          logoAllowed: false,
        ),
        isNull,
      );
      expect(
        InvoiceLogo.pathFor(
          invoice(InvoiceStatus.issued, {'logo_path': 'logo/alt.png'}),
          profile,
          logoAllowed: false,
        ),
        'logo/alt.png',
      );
      final frozen = InvoiceLogo.forNewDocument(profile, logoAllowed: false);
      expect(frozen.toMap()['logo_path'], isNull);
      // Das Profil behält die Datei: nach dem Wechsel auf Pro wieder da.
      expect(profile.hasLogo, isTrue);
      expect(
        InvoiceLogo.forNewDocument(profile, logoAllowed: true).logoPath,
        'logo/neu.png',
      );
    });

    test('das Logo gehört zum eingefrorenen Profil', () {
      expect(profile.toMap()['logo_path'], 'logo/neu.png');
      expect(CompanyProfile.fromMap(profile.toMap()).logoPath, 'logo/neu.png');
      expect(profile.copyWith(clearLogo: true).hasLogo, isFalse);
    });

    test('ein neues Logo überschreibt keine vorhandene Datei', () async {
      final source = File(p.join(root.path, 'quelle.PNG'))
        ..writeAsBytesSync([1, 2, 3]);
      final first = await LogoStore.storeIn(root, source);
      final second = await LogoStore.storeIn(root, source);
      expect(first, isNot(second));
      expect(first, startsWith('logo/'));
      expect(first, endsWith('.png'));
      expect(File(p.join(root.path, first)).existsSync(), isTrue);
      expect(File(p.join(root.path, second)).existsSync(), isTrue);
    });
  });

  group('Absenderangaben gestellter Rechnungen (GR-8)', () {
    const atIssue = CompanyProfile(
      companyName: 'Muster e.U.',
      country: Country.at,
      street: 'Hauptstraße 1',
      city: 'Klagenfurt',
      iban: 'AT61 1904 3002 3457 3201',
    );
    final moved = atIssue.copyWith(
      street: 'Neugasse 9',
      city: 'Wien',
      iban: 'AT00 0000',
      registerNumber: 'FN 1a',
    );

    Invoice invoice(InvoiceStatus status, String? snapshot) => Invoice(
      number: 'RE-1',
      issueDate: DateTime(2026, 10, 1),
      customerId: 1,
      items: const [],
      status: status,
      sellerSnapshot: snapshot,
    );

    test('Adressänderung nach dem Ausstellen ändert das PDF nicht', () {
      final issued = invoice(InvoiceStatus.issued, jsonEncode(atIssue.toMap()));
      final seller = InvoiceSeller.profileFor(issued, moved);
      expect(seller.street, 'Hauptstraße 1');
      expect(seller.city, 'Klagenfurt');
      expect(seller.iban, 'AT61 1904 3002 3457 3201');
    });

    test('Entwürfe nutzen das aktuelle Profil', () {
      final draft = invoice(InvoiceStatus.draft, jsonEncode(atIssue.toMap()));
      expect(InvoiceSeller.profileFor(draft, moved).street, 'Neugasse 9');
    });

    test('alte Snapshots fallen je fehlendem Feld zurück', () {
      final old = invoice(
        InvoiceStatus.paid,
        jsonEncode({'company_name': 'Alt e.U.', 'street': 'Altweg 2'}),
      );
      final seller = InvoiceSeller.profileFor(old, moved);
      expect(seller.companyName, 'Alt e.U.');
      expect(seller.street, 'Altweg 2');
      expect(seller.registerNumber, 'FN 1a');
      expect(
        InvoiceSeller.profileFor(invoice(InvoiceStatus.paid, null), moved).city,
        'Wien',
      );
      expect(
        InvoiceSeller.profileFor(
          invoice(InvoiceStatus.paid, '{kaputt'),
          moved,
        ).city,
        'Wien',
      );
    });
  });
}
