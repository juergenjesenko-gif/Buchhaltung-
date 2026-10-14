// Plattformimport (L-28.1 bis L-28.7): Formaterkennung je Plattform und
// Sprache, Bruttoprinzip, Reverse Charge, Dubletten, Datensparsamkeit.
import 'dart:io';

import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/platform_import.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/import/platform_import_screen.dart';
import 'package:buchhaltung/services/platform_import/platform_csv.dart';
import 'package:buchhaltung/services/platform_import/platform_import_plan.dart';
import 'package:buchhaltung/services/platform_import/platform_parsers.dart';
import 'package:buchhaltung/services/share_in/share_in_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PlatformImportFile load(String name) {
  final file = PlatformImportParser.parse(
    File('test/fixtures/plattform/$name').readAsBytesSync(),
  );
  expect(file, isNotNull, reason: '$name nicht erkannt');
  return file!;
}

Money sumOf(PlatformImportFile f, PlatformEntryKind kind) => f.entries
    .where((e) => e.kind == kind)
    .fold(const Money.zero(), (s, e) => s + e.amount);

/// Käuferdaten aus den Testdateien; keine davon darf irgendwo auftauchen.
const buyerData = [
  'Musterstadt',
  'Musterland',
  'Musterregion',
  'Musterweg',
  'Musterfrau',
  'Mustermann',
  'Hans Test',
  'John Doe',
  'example.invalid',
  '+43 000',
  '+49 000',
  'Paris',
  'Rue Test',
];

const fixtures = [
  'amazon_datumsbereich_de.csv',
  'amazon_datumsbereich_en.csv',
  'amazon_datumsbereich_fr.csv',
  'amazon_datumsbereich_it.csv',
  'amazon_datumsbereich_es.csv',
  'amazon_abrechnung_v2.txt',
  'paypal_aktivitaeten_de.csv',
  'shopify_auszahlungen.csv',
  'shopify_bestellungen.csv',
  'stripe_saldo.csv',
];

void main() {
  group('Hilfen', () {
    test('Beträge in allen Schreibweisen, ganzzahlig', () {
      expect(parseCents('1.234,56'), 123456);
      expect(parseCents('1,234.56'), 123456);
      expect(parseCents('-12.5'), -1250);
      expect(parseCents('12,50 €'), 1250);
      expect(parseCents('(3,00)'), -300);
      expect(parseCents('1.030'), 103000);
      expect(parseCents(''), isNull);
      expect(parseCents('abc'), isNull);
    });

    test('Datum ISO, deutsch, Monatsnamen, Schrägstrich', () {
      expect(parsePlatformDate('2026-03-05 10:00:00'), DateTime(2026, 3, 5));
      expect(parsePlatformDate('05.03.2026 10:15 UTC'), DateTime(2026, 3, 5));
      expect(
        parsePlatformDate('Mar 5, 2026 1:00 AM PST'),
        DateTime(2026, 3, 5),
      );
      expect(parsePlatformDate('5 mars 2026'), DateTime(2026, 3, 5));
      expect(parsePlatformDate('5 gen 2026'), DateTime(2026, 1, 5));
      expect(parsePlatformDate('5 ene 2026'), DateTime(2026, 1, 5));
      expect(parsePlatformDate('5. März 2026'), DateTime(2026, 3, 5));
      expect(parsePlatformDate('05/03/2026'), DateTime(2026, 3, 5));
      expect(
        parsePlatformDate('03/05/2026', monthFirst: true),
        DateTime(2026, 3, 5),
      );
    });

    test('CSV-Endungen gehen in den Import', () {
      expect(sharedKindOf('/x/bericht.CSV'), SharedKind.table);
      expect(sharedKindOf('/x/abrechnung.txt'), SharedKind.table);
      expect(sharedKindOf('/x/beleg.pdf'), SharedKind.pdf);
    });

    test('Unbekannte Datei wird nicht erkannt', () {
      expect(PlatformImportParser.parseText('a,b,c\n1,2,3\n'), isNull);
    });
  });

  group('Formaterkennung (L-28.1)', () {
    final expected = {
      'amazon_datumsbereich_de.csv': PlatformFormat.amazonDateRange,
      'amazon_datumsbereich_en.csv': PlatformFormat.amazonDateRange,
      'amazon_datumsbereich_fr.csv': PlatformFormat.amazonDateRange,
      'amazon_datumsbereich_it.csv': PlatformFormat.amazonDateRange,
      'amazon_datumsbereich_es.csv': PlatformFormat.amazonDateRange,
      'amazon_abrechnung_v2.txt': PlatformFormat.amazonSettlementV2,
      'paypal_aktivitaeten_de.csv': PlatformFormat.paypalActivity,
      'shopify_auszahlungen.csv': PlatformFormat.shopifyPayouts,
      'shopify_bestellungen.csv': PlatformFormat.shopifyOrders,
      'stripe_saldo.csv': PlatformFormat.stripeBalance,
    };
    for (final MapEntry(key: name, value: format) in expected.entries) {
      test(name, () => expect(load(name).format, format));
    }

    for (final lang in ['en', 'fr', 'it', 'es']) {
      test('Amazon $lang: Verkauf, Gebühr, Abo, Übertrag', () {
        final f = load('amazon_datumsbereich_$lang.csv');
        expect(sumOf(f, PlatformEntryKind.sale), const Money(4000));
        expect(sumOf(f, PlatformEntryKind.fee), const Money(-4500));
        expect(sumOf(f, PlatformEntryKind.payout), const Money(-2000));
        expect(f.entries.first.date, DateTime(2026, 3, 1));
      });
    }
  });

  group('Amazon Transaktionsbericht DE', () {
    test('Bruttoprinzip: Umsatz, Gebühren, Werbung, Auszahlung getrennt', () {
      final f = load('amazon_datumsbereich_de.csv');
      final march = f.entries.where((e) => e.date.month == 3);
      Money sum(PlatformEntryKind k) => march
          .where((e) => e.kind == k)
          .fold(const Money.zero(), (s, e) => s + e.amount);
      expect(sum(PlatformEntryKind.sale), const Money(15000));
      expect(sum(PlatformEntryKind.refund), const Money(-2000));
      expect(sum(PlatformEntryKind.fee), const Money(-6150));
      expect(sum(PlatformEntryKind.advertising), const Money(-2500));
      expect(sum(PlatformEntryKind.payout), const Money(-5000));
      expect(
        f.entries.firstWhere((e) => e.destinationCountry == 'FR').amount,
        const Money(5000),
      );
      expect(f.entries.any((e) => e.fulfilledByPlatform), isTrue);
    });

    test('Zusammenfassung je Monat und Belege (AT, regelbesteuert)', () {
      final plan = PlatformImportPlanner.plan(
        file: load('amazon_datumsbereich_de.csv'),
        knownIds: const {},
        country: Country.at,
        isSmallBusiness: false,
      );
      expect(plan.months, hasLength(2));
      final march = plan.months.first;
      expect(march.saleCount, 2);
      expect(march.salesTotal, const Money(13000));
      expect(march.fees, const Money(6150));
      expect(march.advertising, const Money(2500));
      expect(march.payout, const Money(5000));
      expect(
        platformMonthLine(march, 'März 2026', 'Reverse Charge'),
        allOf(
          contains('2 Verkäufe'),
          contains('(Reverse Charge)'),
          contains('Auszahlung'),
        ),
      );

      final income = plan.drafts.firstWhere(
        (d) => d.receipt.direction == BookingDirection.income,
      );
      expect(income.receipt.gross, const Money(13000));
      expect(income.receipt.vatPermille, 200);
      expect(income.receipt.net + income.receipt.vat, income.receipt.gross);
      final fees = plan.drafts.where((d) => d.receipt.reverseCharge).toList();
      expect(fees, hasLength(3)); // März Gebühren, März Werbung, April
      expect(fees.first.receipt.vat, const Money.zero());
      expect(fees.first.receipt.counterparty, 'Amazon EU S.à r.l.');
      // Auszahlung wird nie gebucht.
      expect(
        plan.drafts.map((d) => d.receipt.gross),
        isNot(contains(const Money(5000))),
      );
      expect(plan.warnings.join(' '), contains('Pan-EU'));
    });

    test('Kleinunternehmer: Umsatz ohne Steuer, Gebühren trotzdem RC', () {
      final plan = PlatformImportPlanner.plan(
        file: load('amazon_datumsbereich_de.csv'),
        knownIds: const {},
        country: Country.de,
        isSmallBusiness: true,
      );
      final income = plan.drafts.first.receipt;
      expect(income.vat, const Money.zero());
      expect(plan.drafts.where((d) => d.receipt.reverseCharge), isNotEmpty);
      expect(
        plan.warnings.join(' '),
        contains('Auch als Kleinunternehmer schuldest du'),
      );
    });

    test('Dubletten werden still übersprungen (L-28.5)', () {
      final file = load('amazon_datumsbereich_de.csv');
      final first = PlatformImportPlanner.plan(
        file: file,
        knownIds: const {},
        country: Country.at,
        isSmallBusiness: false,
      );
      final again = PlatformImportPlanner.plan(
        file: load('amazon_datumsbereich_de.csv'),
        knownIds: {for (final e in first.newEntries) e.externalId},
        country: Country.at,
        isSmallBusiness: false,
      );
      expect(again.hasAnythingNew, isFalse);
      expect(again.drafts, isEmpty);
      expect(again.duplicates, file.entries.length);
    });
  });

  group('Weitere Formate', () {
    test('Abrechnung Flatfile V2: Steuer aus Bericht, Auszahlung aus Kopf', () {
      final f = load('amazon_abrechnung_v2.txt');
      expect(sumOf(f, PlatformEntryKind.sale), const Money(11900));
      expect(sumOf(f, PlatformEntryKind.refund), const Money(-2000));
      expect(sumOf(f, PlatformEntryKind.fee), const Money(-1950));
      expect(sumOf(f, PlatformEntryKind.advertising), const Money(-1500));
      expect(sumOf(f, PlatformEntryKind.payout), const Money(-10150));
      final plan = PlatformImportPlanner.plan(
        file: f,
        knownIds: const {},
        country: Country.de,
        isSmallBusiness: false,
      );
      final income = plan.drafts.first.receipt;
      expect(income.gross, const Money(9900));
      expect(income.vat, const Money(1900));
    });

    test('PayPal: nur abgeschlossen, nur EUR, Gebühr steuerfrei', () {
      final f = load('paypal_aktivitaeten_de.csv');
      expect(f.skippedForeignCurrency, 1);
      expect(sumOf(f, PlatformEntryKind.sale), const Money(130000));
      expect(sumOf(f, PlatformEntryKind.refund), const Money(-5000));
      expect(sumOf(f, PlatformEntryKind.fee), const Money(-3445));
      expect(sumOf(f, PlatformEntryKind.payout), const Money(-100000));
      final plan = PlatformImportPlanner.plan(
        file: f,
        knownIds: const {},
        country: Country.at,
        isSmallBusiness: true,
      );
      final fee = plan.drafts.firstWhere(
        (d) => d.receipt.direction == BookingDirection.expense,
      );
      expect(fee.receipt.reverseCharge, isFalse);
      expect(plan.feeSupplier.treatment, FeeVatTreatment.exemptFinancial);
    });

    test('Stripe: Gebühr aus Spalte fee, Auszahlung getrennt', () {
      final f = load('stripe_saldo.csv');
      expect(sumOf(f, PlatformEntryKind.sale), const Money(8000));
      expect(sumOf(f, PlatformEntryKind.fee), const Money(-137));
      expect(sumOf(f, PlatformEntryKind.payout), const Money(-6863));
    });

    test('Shopify: Auszahlung je Payout, Bestellung nicht doppelt', () {
      final payouts = load('shopify_auszahlungen.csv');
      expect(sumOf(payouts, PlatformEntryKind.sale), const Money(10000));
      expect(sumOf(payouts, PlatformEntryKind.fee), const Money(-300));
      expect(sumOf(payouts, PlatformEntryKind.payout), const Money(-8700));
      final orders = load('shopify_bestellungen.csv');
      final plan = PlatformImportPlanner.plan(
        file: orders,
        knownIds: {for (final e in payouts.entries) e.externalId},
        country: Country.de,
        isSmallBusiness: false,
      );
      // #1001 schon aus den Auszahlungen; #1003 neu.
      expect(plan.months.single.saleCount, 1);
      expect(plan.months.single.sales, const Money(1190000));
    });

    test('OSS-Warnung über 10.000 € in andere EU-Länder (L-28.5)', () {
      final plan = PlatformImportPlanner.plan(
        file: load('shopify_bestellungen.csv'),
        knownIds: const {},
        country: Country.de,
        isSmallBusiness: false,
      );
      expect(plan.warnings.join(' '), contains('OSS'));
      expect(ossThreshold, const Money(1000000));
    });
  });

  group('Datensparsamkeit (L-28.6)', () {
    for (final name in fixtures) {
      test('$name: keine Käuferdaten in Zeilen und Belegen', () {
        final f = load(name);
        final plan = PlatformImportPlanner.plan(
          file: f,
          knownIds: const {},
          country: Country.at,
          isSmallBusiness: false,
        );
        final text = [
          for (final e in f.entries) ...[
            e.externalId,
            e.orderRef,
            e.destinationCountry ?? '',
          ],
          for (final d in plan.drafts) d.receipt.toMap().values.join('|'),
          ...plan.warnings,
        ].join('\n');
        for (final word in buyerData) {
          expect(text, isNot(contains(word)), reason: '$name: $word');
        }
      });
    }
  });

  group('Datenbank', () {
    setUpAll(sqfliteFfiInit);

    test('Übernehmen bucht, merkt IDs, Reverse Charge in der UVA', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      final repos = Repositories(db);
      final file = load('amazon_datumsbereich_de.csv');
      final plan = PlatformImportPlanner.plan(
        file: file,
        knownIds: await repos.platformImports.knownIds(SalesPlatform.amazon),
        country: Country.at,
        isSmallBusiness: true,
      );
      final count = await repos.platformImports.commit(
        format: file.format,
        bookings: [
          for (final d in plan.drafts)
            (receipt: d.receipt, categoryId: null, ids: d.entryIds),
        ],
        entries: [
          for (final e in plan.newEntries)
            (id: e.externalId, month: PlatformImportPlanner.monthKey(e.date)),
        ],
      );
      expect(count, plan.drafts.length);
      final known = await repos.platformImports.knownIds(SalesPlatform.amazon);
      expect(known, hasLength(file.entries.length));
      expect(
        (await repos.platformImports.formatsByMonth(
          SalesPlatform.amazon,
        ))['2026-03'],
        {'amazonDateRange'},
      );

      // Zweiter Import: nichts Neues.
      final again = PlatformImportPlanner.plan(
        file: file,
        knownIds: known,
        country: Country.at,
        isSmallBusiness: true,
      );
      expect(again.hasAnythingNew, isFalse);
      // Doppelt einfügen scheitert nicht (INSERT OR IGNORE).
      await repos.platformImports.commit(
        format: file.format,
        bookings: const [],
        entries: [(id: plan.newEntries.first.externalId, month: '2026-03')],
      );

      // März: Gebühren 61,50 + Werbung 25,00 = 86,50 € RC, 20 % → 17,30 €;
      // Kleinunternehmer ohne Vorsteuerabzug.
      final totals = await repos.receipts.totals(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        inputVatDeductible: false,
        reverseChargePermille: 200,
      );
      expect(totals.reverseChargeBase, const Money(8650));
      expect(totals.reverseChargeVat, const Money(1730));
      expect(totals.reverseChargeInputVat, const Money.zero());
      expect(totals.vatPayable, const Money(1730));
      final deductible = await repos.receipts.totals(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        reverseChargePermille: 200,
      );
      expect(deductible.reverseChargeInputVat, const Money(1730));

      // Keine Käuferdaten in irgendeiner Tabelle.
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final dump = StringBuffer();
      for (final t in tables) {
        final rows = await db.query(t['name'] as String);
        for (final r in rows) {
          dump.writeln(r.values.join('|'));
        }
      }
      for (final word in buyerData) {
        expect(dump.toString(), isNot(contains(word)), reason: word);
      }
      await db.close();
    });

    test('Kennzahlen je Land in TaxProfile', () {
      expect(Country.at.taxProfile.reverseCharge.taxKz, '057');
      expect(Country.at.taxProfile.reverseCharge.inputVatKz, '066');
      expect(Country.de.taxProfile.reverseCharge.baseKz, '46');
      expect(Country.de.taxProfile.reverseCharge.taxKz, '47');
      expect(Country.de.taxProfile.reverseCharge.inputVatKz, '67');
      expect(Country.at.taxProfile.standardVatPermille, 200);
      expect(Country.de.taxProfile.standardVatPermille, 190);
    });
  });

  group('Oberfläche (UX, einhändig)', () {
    setUpAll(() async {
      sqfliteFfiInit();
      await initializeDateFormatting('de');
    });

    testWidgets('„Übernehmen“ unten, volle Breite, 56 dp, ein Tipp', (
      tester,
    ) async {
      final db = await tester.runAsync(
        () => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: AppDatabase.schemaVersion,
            onCreate: AppDatabase.createSchema,
            singleInstance: false,
          ),
        ),
      );
      final state = AppState(Repositories(db!));
      await tester.runAsync(() async {
        await state.saveProfile(
          const CompanyProfile(companyName: 'Test', country: Country.at),
        );
        await state.reloadCategories();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final file = load('amazon_datumsbereich_de.csv');
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) => PlatformImportScreen(file: file),
                      ),
                    ),
                    child: const Text('öffnen'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öffnen'));
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();

      final commit = find.byKey(const Key('platform-import-commit'));
      expect(commit, findsOneWidget);
      final rect = tester.getRect(commit);
      expect(rect.height, greaterThanOrEqualTo(56));
      expect(rect.width, greaterThan(390 - 2 * 16 - 1));
      expect(rect.bottom, greaterThan(844 - 120));
      expect(find.textContaining('März 2026: 2 Verkäufe'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(commit);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      final receipts = await tester.runAsync(
        () => state.repositories.receipts.query(),
      );
      expect(receipts, isNotEmpty);
      expect(receipts!.any((r) => r.reverseCharge), isTrue);
      await tester.runAsync(db.close);
    });
  });
}
