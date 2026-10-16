import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/article.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/offer.dart';
import 'package:buchhaltung/features/articles/position_picker.dart';
import 'package:buchhaltung/features/invoices/invoice_list_screen.dart';
import 'package:buchhaltung/features/offers/offer_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Angebote (L-3.13 bis L-3.17) und Artikel (L-11), Schema 19.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<Database> openDb() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onCreate: AppDatabase.createSchema,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      singleInstance: false,
    ),
  );

  Future<int> seed(Database db) async {
    await db.insert('company_profile', {
      'id': 1,
      'company_name': 'Test',
      'country_code': 'AT',
    });
    return db.insert('customers', {
      'name': 'Kundin',
      'street': 'Weg 1',
      'postal_code': '1010',
      'city': 'Wien',
    });
  }

  const item = InvoiceItem(
    position: 1,
    description: 'Beratung',
    quantityMilli: 2000,
    unit: 'h',
    unitPrice: Money(8000),
    vatPermille: 200,
  );

  Offer offer(int customerId, {DateTime? date}) => Offer(
    number: '',
    issueDate: date ?? DateTime(2026, 10, 16),
    validUntil: DateTime(2026, 11, 15),
    customerId: customerId,
    items: const [item],
  );

  group('Angebot (Domäne)', () {
    test('abgelaufen nur offen und nach dem Gültigkeitstag', () {
      final o = offer(1);
      expect(o.statusOn(DateTime(2026, 11, 15, 23)), OfferStatus.draft);
      expect(o.statusOn(DateTime(2026, 11, 16)), OfferStatus.expired);
      expect(
        o.copyWith(status: OfferStatus.accepted).statusOn(DateTime(2027)),
        OfferStatus.accepted,
      );
      expect(OfferStatus.fromName('expired'), OfferStatus.draft);
    });

    test('Summen wie Rechnungspositionen, netto + USt = brutto', () {
      final o = offer(1);
      expect(o.netTotal, const Money(16000));
      expect(o.grossTotal, const Money(19200));
    });
  });

  group('Angebot (Repository)', () {
    test('eigener Nummernkreis je Jahr, unabhängig von Rechnungen', () async {
      final db = await openDb();
      final repos = Repositories(db);
      final c = await seed(db);
      final a = await repos.offers.save(offer(c));
      final b = await repos.offers.save(offer(c));
      final next = await repos.offers.save(
        offer(c, date: DateTime(2027, 1, 2)),
      );
      expect((await repos.offers.byId(a))!.number, 'AN-2026-0001');
      expect((await repos.offers.byId(b))!.number, 'AN-2026-0002');
      expect((await repos.offers.byId(next))!.number, 'AN-2027-0001');
      final seq = await db.query('company_profile');
      expect(seq.first['next_invoice_sequence'], 1);
      await db.close();
    });

    test('bucht nichts (L-3.14)', () async {
      final db = await openDb();
      final repos = Repositories(db);
      final c = await seed(db);
      await repos.offers.save(offer(c));
      expect(await db.query('receipts'), isEmpty);
      expect(await db.query('invoices'), isEmpty);
      await db.close();
    });

    test(
      'Umwandeln: Rechnungsentwurf mit Positionen, Angebot gesperrt',
      () async {
        final db = await openDb();
        final repos = Repositories(db);
        final c = await seed(db);
        final id = await repos.offers.save(offer(c));
        final invoiceId = await repos.offers.convertToInvoice(
          id,
          now: DateTime(2026, 10, 20),
          paymentTermDays: 14,
          isSmallBusiness: false,
        );
        final invoice = (await repos.invoices.byId(invoiceId))!;
        expect(invoice.status, InvoiceStatus.draft);
        expect(invoice.customerId, c);
        expect(invoice.items.single.description, 'Beratung');
        expect(invoice.items.single.quantityMilli, 2000);
        expect(invoice.grossTotal, const Money(19200));
        expect(invoice.dueDate, DateTime(2026, 11, 3));
        final accepted = (await repos.offers.byId(id))!;
        expect(accepted.status, OfferStatus.accepted);
        expect(accepted.isLocked, isTrue);
        expect(accepted.invoiceId, invoiceId);
        // Zweiter Tipp öffnet denselben Entwurf.
        expect(
          await repos.offers.convertToInvoice(
            id,
            now: DateTime(2026, 10, 21),
            paymentTermDays: 14,
            isSmallBusiness: false,
          ),
          invoiceId,
        );
        expect(() => repos.offers.save(accepted), throwsStateError);
        expect(await repos.offers.delete(id), isFalse);
        expect(await db.query('receipts'), isEmpty);
        await db.close();
      },
    );

    test('Kunde mit Angebot lässt sich nicht löschen', () async {
      final db = await openDb();
      final repos = Repositories(db);
      final c = await seed(db);
      await repos.offers.save(offer(c));
      expect(await repos.customers.delete(c), isFalse);
      await db.close();
    });
  });

  group('Artikel', () {
    test('Artikelnummer eindeutig, leer beliebig oft (L-11.2)', () async {
      final db = await openDb();
      final repos = Repositories(db);
      await seed(db);
      const a = Article(
        number: 'K-1',
        name: 'Kerze',
        unitPrice: Money(1250),
        vatPermille: 200,
      );
      final id = await repos.articles.save(a);
      expect(await repos.articles.numberTaken('K-1'), isTrue);
      expect(await repos.articles.numberTaken('K-1', exceptId: id), isFalse);
      await repos.articles.save(
        const Article(name: 'A', unitPrice: Money(1), vatPermille: 0),
      );
      await repos.articles.save(
        const Article(name: 'B', unitPrice: Money(1), vatPermille: 0),
      );
      expect(await repos.articles.all(), hasLength(3));
      await db.close();
    });

    test('Vorschläge: Artikel zuerst, dann frühere Positionen', () async {
      final db = await openDb();
      final repos = Repositories(db);
      final c = await seed(db);
      await repos.articles.save(
        const Article(name: 'Kerze', unitPrice: Money(1250), vatPermille: 200),
      );
      await repos.offers.save(offer(c));
      final list = await repos.articles.suggestions();
      expect(list.first.isArticle, isTrue);
      expect(list.first.description, 'Kerze');
      final used = list.firstWhere((s) => s.description == 'Beratung');
      expect(used.unitPrice, const Money(8000));
      expect(used.unit, 'h');
      expect(used.toItem().quantityMilli, 1000);
      expect(list.where((s) => s.description == 'Beratung'), hasLength(1));
      expect(list.where((s) => s.matches('kerz')), hasLength(1));
      await db.close();
    });
  });

  group('Oberfläche (UX, einhändig)', () {
    Future<AppState> app(WidgetTester tester, Widget home) async {
      final db = await tester.runAsync(openDb);
      final state = AppState(Repositories(db!));
      await tester.runAsync(() async {
        final c = await seed(db);
        await state.repositories.articles.save(
          const Article(
            name: 'Kerze',
            unitPrice: Money(1250),
            vatPermille: 200,
          ),
        );
        await state.repositories.offers.save(offer(c));
        await state.reload();
      });
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(home: home),
        ),
      );
      await settle(tester);
      return state;
    }

    testWidgets('Angebote und Artikel je ein Tipp, ≥ 48 dp', (tester) async {
      await app(tester, const InvoiceListScreen());
      for (final key in ['open-offers', 'open-articles']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('Angebot: Umwandeln und Senden ≥ 48 dp', (tester) async {
      final state = await app(tester, const SizedBox());
      final offers = await tester.runAsync(state.repositories.offers.all);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(home: OfferEditScreen(existing: offers!.first)),
        ),
      );
      await settle(tester);
      for (final key in ['offer-convert', 'offer-send', 'pickOfferItem']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
    });

    testWidgets('Positionsauswahl: Zeilen ≥ 48 dp', (tester) async {
      final state = await app(tester, const SizedBox());
      final list = await tester.runAsync(
        state.repositories.articles.suggestions,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PositionPickerSheet(suggestions: list!)),
        ),
      );
      await settle(tester);
      final tile = tester.getSize(find.byKey(const Key('suggestion-Kerze')));
      expect(tile.height, greaterThanOrEqualTo(48));
    });
  });
}
