import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/asset_repository.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/fixed_asset.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/assets/depreciation.dart';
import 'package:buchhaltung/services/reports/annual_report.dart';
import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/features/assets/asset_screens.dart';
import 'package:buchhaltung/features/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Anlagevermögen und AfA (GR-15, FA-15.1 bis FA-15.11).
final _at = TaxProfile.austria.depreciation;
final _de = TaxProfile.germany.depreciation;

FixedAsset _asset(
  int cost,
  DateTime on, {
  int years = 3,
  DepreciationMethod method = DepreciationMethod.linear,
  String key = 'other',
  DateTime? disposed,
}) => FixedAsset(
  name: 'Test',
  acquiredOn: on,
  cost: Money(cost),
  categoryKey: key,
  usefulLifeYears: years,
  method: method,
  disposedOn: disposed,
  disposalKind: disposed == null ? null : DisposalKind.scrapped,
);

List<int> _amounts(FixedAsset a, DepreciationRules r) =>
    Depreciation.entries(a, r).map((e) => e.amount.cents).toList();

void main() {
  group('Österreich: Halbjahresregel § 7 Abs 2 EStG', () {
    test('Inbetriebnahme im ersten Halbjahr: ganze Jahres-AfA', () {
      final a = _asset(100000, DateTime(2026, 3, 1));
      expect(_amounts(a, _at), [33333, 33333, 33334]);
    });

    test('Inbetriebnahme im zweiten Halbjahr: halbe AfA, Rest im 4. Jahr', () {
      final a = _asset(100000, DateTime(2026, 9, 1));
      final amounts = _amounts(a, _at);
      expect(amounts, [16666, 33334, 33333, 16667]);
      expect(amounts.reduce((x, y) => x + y), 100000);
    });

    test('Ausscheiden: Restbuchwert als Abgang, keine AfA im Abgangsjahr', () {
      final a = _asset(
        100000,
        DateTime(2026, 1, 10),
        years: 5,
        disposed: DateTime(2027, 5, 20),
      );
      final plan = Depreciation.plan(a, _at);
      expect(plan, hasLength(2));
      expect(plan[0].afa, const Money(20000));
      expect(plan[1].afa, const Money.zero());
      expect(plan[1].disposalValue, const Money(80000));
      expect(plan[1].closing, const Money.zero());
    });

    test('PKW mindestens 8 Jahre (§ 8 Abs 6 EStG)', () {
      final a = _asset(3000000, DateTime(2026, 1, 1), years: 5, key: 'car');
      expect(
        Depreciation.validate(a, a.cost, _at),
        contains('Mindestens 8 Jahre'),
      );
    });

    test('GWG bis 1.000 €: sofort, darüber nicht', () {
      final ok = _asset(
        100000,
        DateTime(2026, 4, 1),
        method: DepreciationMethod.gwg,
      );
      expect(Depreciation.validate(ok, ok.cost, _at), isNull);
      expect(_amounts(ok, _at), [100000]);
      expect(Depreciation.entries(ok, _at).single.bookedOn, ok.acquiredOn);
      final tooMuch = _asset(
        100001,
        DateTime(2026, 4, 1),
        method: DepreciationMethod.gwg,
      );
      expect(Depreciation.validate(tooMuch, tooMuch.cost, _at), isNotNull);
    });
  });

  group('Deutschland: monatsgenau § 7 Abs 1 EStG', () {
    test('Büromöbel 13 Jahre ab April', () {
      final a = _asset(130000, DateTime(2026, 4, 15), years: 13);
      final amounts = _amounts(a, _de);
      expect(amounts.first, 7500); // 9/156
      expect(amounts[1], 10000);
      expect(amounts, hasLength(14));
      expect(amounts.reduce((x, y) => x + y), 130000);
    });

    test('Computer 1 Jahr (BMF 22.02.2022): voll im Anschaffungsjahr', () {
      final a = _asset(150000, DateTime(2026, 11, 3), years: 1);
      expect(_amounts(a, _de), [150000]);
    });

    test('Ausscheiden: AfA bis Monat des Abgangs, dann Restbuchwert', () {
      final a = _asset(
        60000,
        DateTime(2026, 1, 1),
        years: 5,
        disposed: DateTime(2027, 6, 30),
      );
      final plan = Depreciation.plan(a, _de);
      expect(plan[0].afa, const Money(12000));
      expect(plan[1].afa, const Money(6000));
      expect(plan[1].disposalValue, const Money(42000));
    });

    test('Sammelposten: fünf Teile, Summe exakt', () {
      final a = _asset(
        50001,
        DateTime(2026, 8, 1),
        method: DepreciationMethod.pool,
      );
      expect(_amounts(a, _de), [10000, 10000, 10000, 10000, 10001]);
      expect(Depreciation.validate(a, a.cost, _de), isNull);
      expect(Depreciation.validate(a, a.cost, _at), isNotNull);
    });

    test('GWG-Grenze 800 € netto, auch ohne Vorsteuerabzug', () {
      final a = _asset(
        95200, // brutto beim Kleinunternehmer
        DateTime(2026, 4, 1),
        method: DepreciationMethod.gwg,
      );
      expect(Depreciation.validate(a, const Money(80000), _de), isNull);
      expect(
        Depreciation.suggestMethod(a.cost, const Money(80000), _de),
        DepreciationMethod.gwg,
      );
    });
  });

  test('Summe aller AfA ist immer exakt die Anschaffungskosten', () {
    for (final rules in [_at, _de]) {
      for (var years = 1; years <= 15; years++) {
        for (final month in [1, 6, 7, 12]) {
          for (final cost in [1, 99, 100000, 123457, 999999]) {
            final a = _asset(cost, DateTime(2026, month, 15), years: years);
            final sum = _amounts(a, rules).fold(0, (x, y) => x + y);
            expect(sum, cost, reason: '$years J., Monat $month, $cost');
          }
        }
      }
    }
  });

  group('Datenbank und Gewinn', () {
    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      await initializeDateFormatting('de');
    });

    test('Anschaffung zählt nicht als Ausgabe, AfA am 31.12.', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      final now = DateTime.now().toIso8601String();
      final receiptId = await db.insert('receipts', {
        'date': '2026-03-10',
        'direction': 'expense',
        'description': 'Laptop',
        'net_cents': 120000,
        'vat_cents': 24000,
        'gross_cents': 144000,
        'vat_permille': 200,
        'created_at': now,
        'updated_at': now,
      });
      await AssetRepository(db).save(
        FixedAsset(
          receiptId: receiptId,
          name: 'Laptop',
          acquiredOn: DateTime(2026, 3, 10),
          cost: const Money(120000),
          categoryKey: 'computer',
          usefulLifeYears: 3,
        ),
      );
      final repo = ReceiptRepository(db);
      final march = await repo.totals(
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 31),
        depreciation: _at,
      );
      expect(march.expenseVat, const Money(24000)); // Vorsteuer bleibt
      expect(march.capitalizedExpense, const Money(120000));
      expect(march.depreciation, const Money.zero());
      expect(march.profit, const Money.zero());
      final year = await repo.totals(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        depreciation: _at,
      );
      expect(year.depreciation, const Money(40000));
      expect(year.profit, const Money(-40000));
      final sums = await repo.categorySums(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(sums, isEmpty); // Anschaffung nicht in der Saldenliste

      final assets = await AssetRepository(db).all();
      final data = AnnualReportData(
        profile: const CompanyProfile(
          companyName: 'Test',
          country: Country.at,
          isSmallBusiness: false,
        ),
        periodLabel: '2026',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        totals: year,
        categorySums: sums,
        categories: const [],
        assets: assets,
        openInvoices: const [],
        comment: 'Bitte AfA prüfen',
      );
      expect(data.register.single.row.closing, const Money(80000));
      expect(
        data.balances.firstWhere((b) => b.label.contains('Jahresende')).amount,
        const Money(80000),
      );
      for (final kind in ReportKind.values) {
        final bytes = await AnnualReportPdf(data).build(kind);
        expect(bytes.length, greaterThan(1000), reason: '$kind');
      }
      await db.close();
    });
  });

  group('Einhandbedienung', () {
    setUpAll(() async {
      sqfliteFfiInit();
      await initializeDateFormatting('de');
    });

    Future<void> pump(WidgetTester tester, Widget home) async {
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
      await tester.runAsync(
        () => db!.insert('company_profile', {
          'id': 1,
          'company_name': 'Test',
          'country_code': 'DE',
          'is_small_business': 0,
        }),
      );
      final state = AppState(Repositories(db!));
      await tester.runAsync(state.reload);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(home: home),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await settle(tester);
    }

    testWidgets('Anlage erfassen: Speichern unten, Auswahl ≥ 48 dp', (
      tester,
    ) async {
      await pump(tester, const AssetEditScreen());
      final save = find.byKey(const Key('asset-save'));
      expect(tester.getSize(save).height, greaterThanOrEqualTo(56));
      expect(tester.getRect(save).center.dy, greaterThan(640 * 2 / 3));
      final pool = find.widgetWithText(ListTile, DepreciationMethod.pool.label);
      await tester.scrollUntilVisible(
        pool,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(pool).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Berichte: drei Zeilen ≥ 48 dp', (tester) async {
      await pump(tester, const ReportsScreen());
      for (final key in ['report-assets', 'report-balance']) {
        final f = find.byKey(Key(key));
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
