import 'dart:io';

import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/exchange_rate_repository.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/exchange_rate.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/fx/currency_converter.dart';
import 'package:buchhaltung/services/fx/ecb_rates.dart';
import 'package:buchhaltung/services/fx/fx_rate_service.dart';
import 'package:buchhaltung/services/vat_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fremdwährung bei Eingangsbelegen (L-2.24 bis L-2.26, L-19.29).
void main() {
  setUpAll(sqfliteFfiInit);

  final sample = File('test/fixtures/eurofxref-sample.xml').readAsStringSync();

  Future<Database> openFresh() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onCreate: AppDatabase.createSchema,
      singleInstance: false,
    ),
  );

  group('Umrechnung', () {
    test('Kurs wird exakt als Ganzzahl gelesen und geschrieben', () {
      expect(CurrencyConverter.parseRate('1,0823'), 1082300);
      expect(CurrencyConverter.parseRate('161.25'), 161250000);
      expect(CurrencyConverter.parseRate('0.000001'), 1);
      expect(CurrencyConverter.parseRate('1,1234567'), isNull);
      expect(CurrencyConverter.parseRate('0'), isNull);
      expect(CurrencyConverter.parseRate('-1'), isNull);
      expect(CurrencyConverter.parseRate('abc'), isNull);
      expect(CurrencyConverter.formatRate(1082300), '1,082300');
    });

    test('Rundung half-up auf Cent', () {
      // 100,00 USD / 1,0823 = 92,3958… → 92,40 EUR
      expect(
        CurrencyConverter.toEuro(const Money(10000), 1082300),
        const Money(9240),
      );
      // 1,00 / 2,0 = 0,50 exakt
      expect(CurrencyConverter.toEuro(const Money(100), 2000000), Money(50));
      // 0,01 / 2,0 = 0,005 → 0,01 (half-up)
      expect(CurrencyConverter.toEuro(const Money(1), 2000000), Money(1));
      // 0,03 / 2,0 = 0,015 → 0,02; negativ symmetrisch
      expect(CurrencyConverter.toEuro(const Money(3), 2000000), Money(2));
      expect(CurrencyConverter.toEuro(const Money(-3), 2000000), Money(-2));
      // JPY 1.500 (Hundertstel) / 161,25 = 9,302… → 9,30
      expect(
        CurrencyConverter.toEuro(const Money(150000), 161250000),
        const Money(930),
      );
      expect(
        () => CurrencyConverter.toEuro(const Money(1), 0),
        throwsArgumentError,
      );
    });

    test('Netto plus Steuer ergibt exakt den umgerechneten Euro-Betrag', () {
      for (final rate in [1082300, 161250000, 941200, 1]) {
        for (final cents in [1, 99, 12345, 9999999]) {
          final gross = CurrencyConverter.toEuro(Money(cents), rate);
          final split = VatCalculator.fromGross(gross, 200);
          expect(split.net + split.vat, gross);
        }
      }
    });

    test('Mittelwert half-up', () {
      expect(CurrencyConverter.average([1, 2]), 2);
      expect(CurrencyConverter.average([1090000, 1080000, 1070100]), 1080033);
      expect(CurrencyConverter.average([]), isNull);
    });
  });

  group('EZB-XML', () {
    test('liest Tage, Währungen und Kurse ohne XML-Paket', () {
      final rates = EcbClient.parse(sample);
      expect(rates, hasLength(9));
      expect(rates.first, EcbRate(DateTime.utc(2026, 9, 30), 'USD', 1090000));
      expect(rates.where((r) => r.currency == 'JPY').map((r) => r.rateMicros), [
        161250000,
        160500000,
      ]);
    });

    test('Abruf über austauschbaren Transport; Datei nach Alter', () async {
      Uri? asked;
      final client = EcbClient(
        transport: (uri) async {
          asked = uri;
          return sample;
        },
      );
      expect(await client.fetch(EcbClient.last90Days), hasLength(9));
      expect(asked, EcbClient.last90Days);
      expect(
        EcbClient.sourceFor(DateTime(2026, 9, 1), DateTime(2026, 10, 12)),
        EcbClient.last90Days,
      );
      expect(
        EcbClient.sourceFor(DateTime(2025, 1, 1), DateTime(2026, 10, 12)),
        EcbClient.history,
      );
    });
  });

  group('Kursermittlung', () {
    test('Monatsmittel aus dem Cache, Abruf nur bei Bedarf', () async {
      final db = await openFresh();
      var calls = 0;
      final service = FxRateService(
        ExchangeRateRepository(db),
        client: EcbClient(
          transport: (_) async {
            calls++;
            return sample;
          },
        ),
      );
      final quote = await service.quote(
        currency: 'USD',
        date: DateTime(2026, 9, 15),
        dailyApproved: false,
        today: DateTime(2026, 10, 12),
      );
      expect(quote!.source, ExchangeRateSource.ecbMonthlyAvg);
      expect(quote.rateMicros, 1080033);
      expect(quote.rateDate, '2026-09');
      expect(quote.days, 3);
      expect(quote.partialMonth, isFalse);
      expect(calls, 1);

      await service.quote(
        currency: 'USD',
        date: DateTime(2026, 9, 2),
        dailyApproved: false,
        today: DateTime(2026, 10, 12),
      );
      expect(calls, 1, reason: 'zweiter Aufruf aus dem lokalen Speicher');

      final daily = await service.quote(
        currency: 'CHF',
        date: DateTime(2026, 10, 3),
        dailyApproved: true,
        today: DateTime(2026, 10, 12),
      );
      expect(daily!.source, ExchangeRateSource.ecbDaily);
      expect(daily.rateDate, '2026-09-30');
      expect(daily.rateMicros, 941200);
      await db.close();
    });

    test('laufender Monat ist vorläufig', () async {
      final db = await openFresh();
      final service = FxRateService(
        ExchangeRateRepository(db),
        client: EcbClient(transport: (_) async => sample),
      );
      final quote = await service.quote(
        currency: 'USD',
        date: DateTime(2026, 9, 10),
        dailyApproved: false,
        today: DateTime(2026, 9, 30),
      );
      expect(quote!.partialMonth, isTrue);
      await db.close();
    });
  });

  group('Datenbank und Auswertung', () {
    test('Migration 10 legt Spalten und Kurstabelle an', () async {
      final db = await openFresh();
      final cols = (await db.rawQuery(
        'PRAGMA table_info(receipts)',
      )).map((r) => r['name']).toList();
      expect(
        cols,
        containsAll([
          'fx_rate_micros',
          'fx_rate_date',
          'fx_rate_source',
          'bank_gross_cents',
        ]),
      );
      final profile = (await db.rawQuery(
        'PRAGMA table_info(company_profile)',
      )).map((r) => r['name']).toList();
      expect(profile, contains('fx_daily_rate_approved'));
      expect(
        await db.query('sqlite_master', where: "name = 'ecb_rates'"),
        hasLength(1),
      );
      await db.close();
    });

    test('Upgrade von Schema 9 behält Belege', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      await db.insert('receipts', {
        'date': '2026-09-01',
        'direction': 'expense',
        'gross_cents': 100,
        'currency': 'USD',
        'original_gross_cents': 108,
        'created_at': '2026-09-01',
        'updated_at': '2026-09-01',
      });
      await AppDatabase.upgradeSchema(db, 9, AppDatabase.schemaVersion);
      final r = Receipt.fromMap((await db.query('receipts')).single);
      expect(r.originalGross, const Money(108));
      expect(r.fxRateMicros, isNull);
      expect(r.cashGross, const Money(100));
      await db.close();
    });

    test('Umsatzsteuer mit Kurs, Ergebnis mit Bankbetrag', () async {
      final db = await openFresh();
      final repo = ReceiptRepository(db);
      final gross = CurrencyConverter.toEuro(const Money(12000), 1080033);
      final split = VatCalculator.fromGross(gross, 200);
      await repo.save(
        Receipt(
          date: DateTime(2026, 9, 15),
          direction: BookingDirection.expense,
          description: 'Software-Abo',
          net: split.net,
          vat: split.vat,
          gross: split.gross,
          vatPermille: 200,
          currency: 'USD',
          originalGross: const Money(12000),
          fxRateMicros: 1080033,
          fxRateDate: '2026-09',
          fxRateSource: ExchangeRateSource.ecbMonthlyAvg,
          bankGross: gross + const Money(150),
        ),
      );
      final totals = await repo.totals(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(totals.expenseGross, gross);
      expect(totals.expenseVat, split.vat, reason: 'Vorsteuer zum Kurs');
      expect(totals.expenseFxDifference, const Money(150));
      expect(totals.expensePaidGross, gross + const Money(150));
      expect(totals.profit, -(split.net + const Money(150)));

      final log = await db.query('audit_log', where: "action = 'fx'");
      expect(log, hasLength(1));
      final detail = log.single['detail'] as String;
      expect(detail, contains('USD 12000'));
      expect(detail, contains('1080033'));
      expect(detail, contains('ecb_monthly_avg'));
      expect(detail, contains('überschreibt EÜR'));

      final stored = (await repo.query()).single;
      expect(stored.fxRateSource, ExchangeRateSource.ecbMonthlyAvg);
      expect(stored.bankGross, gross + const Money(150));
      await db.close();
    });
  });
}
