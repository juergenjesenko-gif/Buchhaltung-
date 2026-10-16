import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/tax_office/u30_xml.dart';
import 'package:buchhaltung/services/tax_office/vat_return_figures.dart';
import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/features/tax_office/tax_office_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Kennzahlen für das Finanzamt (FA-14.1 bis FA-14.8).
PeriodTotals _totals({
  Map<int, int> incomeByRate = const {},
  int inputVat = 0,
  int rcBase = 0,
  int rcVat = 0,
  int rcInputVat = 0,
}) {
  var net = 0;
  var vat = 0;
  incomeByRate.forEach((p, n) {
    net += n;
    vat += (n * p / 1000).round();
  });
  return PeriodTotals(
    from: DateTime(2026, 7, 1),
    to: DateTime(2026, 9, 30),
    incomeNet: Money(net),
    incomeVat: Money(vat),
    incomeGross: Money(net + vat),
    expenseNet: const Money(50000),
    expenseVat: Money(inputVat),
    expenseGross: Money(50000 + inputVat),
    incomeNetByRate: {
      for (final e in incomeByRate.entries) e.key: Money(e.value),
    },
    inputVatByRate: {200: Money(inputVat)},
    reverseChargeBase: Money(rcBase),
    reverseChargeVat: Money(rcVat),
    reverseChargeInputVat: Money(rcInputVat),
  );
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<void> pump(WidgetTester tester, Map<String, Object?> profile) async {
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
        ...profile,
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
        child: const MaterialApp(home: TaxOfficeScreen()),
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

  testWidgets('AT regelbesteuert: Knopf U30 unten, Zeilen ≥ 48 dp', (
    tester,
  ) async {
    await pump(tester, {
      'country_code': 'AT',
      'is_small_business': 0,
      'tax_number': '12 345/6789',
    });
    final button = find.byKey(const Key('share-u30'));
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
    expect(tester.getRect(button).center.dy, greaterThan(640 * 2 / 3));
    await tester.scrollUntilVisible(
      find.text('Gesamtbetrag der Bemessungsgrundlagen'),
      200,
    );
    final tile = find.widgetWithText(
      ListTile,
      'Gesamtbetrag der Bemessungsgrundlagen',
    );
    expect(tile, findsOneWidget);
    expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kleinunternehmer: Hinweis statt UVA, kein Knopf', (
    tester,
  ) async {
    await pump(tester, {'country_code': 'AT', 'is_small_business': 1});
    expect(find.byKey(const Key('share-u30')), findsNothing);
    expect(find.textContaining('brauchst du keine U30'), findsOneWidget);
  });

  group('Österreich U30', () {
    test('Regelbesteuert: Kz 000, 022, 029, 124, 060, 095', () {
      final f = VatReturnCalculator.build(
        totals: _totals(
          incomeByRate: {200: 1000000, 100: 200050, 49: 10000},
          inputVat: 12345,
        ),
        tax: TaxProfile.austria,
        smallBusiness: false,
      );
      expect(f.required, isTrue);
      expect(f.amountOf('000'), const Money(1210050));
      expect(f.amountOf('022'), const Money(1000000));
      expect(f.amountOf('029'), const Money(200050));
      expect(f.amountOf('124'), const Money(10000));
      expect(f.amountOf('060'), const Money(12345));
      // 200.000 + 20.005 + 490 − 12.345 = 208.150 Cent
      expect(f.amountOf('095'), const Money(208150));
      expect(f.fileBlockers, isEmpty);
      expect(f.fileAvailable, isTrue);
    });

    test('Kleinunternehmer ohne Reverse Charge: keine UVA', () {
      final f = VatReturnCalculator.build(
        totals: _totals(incomeByRate: {0: 300000}),
        tax: TaxProfile.austria,
        smallBusiness: true,
      );
      expect(f.required, isFalse);
      expect(f.fileAvailable, isFalse);
    });

    test('Kleinunternehmer mit Reverse Charge: Kz 016 und 057', () {
      final f = VatReturnCalculator.build(
        totals: _totals(incomeByRate: {0: 300000}, rcBase: 10000, rcVat: 2000),
        tax: TaxProfile.austria,
        smallBusiness: true,
      );
      expect(f.required, isTrue);
      expect(f.amountOf('000'), const Money(300000));
      expect(f.amountOf('016'), const Money(300000));
      expect(f.amountOf('057'), const Money(2000));
      expect(f.amountOf('066'), isNull);
      expect(f.amountOf('095'), const Money(2000));
      expect(f.fileAvailable, isTrue);
    });

    test('0 %-Umsätze beim Regelbesteuerten sperren die Datei', () {
      final f = VatReturnCalculator.build(
        totals: _totals(incomeByRate: {200: 1000, 0: 500}),
        tax: TaxProfile.austria,
        smallBusiness: false,
      );
      expect(f.fileBlockers, hasLength(1));
      expect(f.fileAvailable, isFalse);
    });

    test('FASTNR aus der Steuernummer', () {
      expect(U30Xml.fastNr('12 345/6789'), '123456789');
      expect(U30Xml.fastNr('12-345/6789'), '123456789');
      expect(U30Xml.fastNr('345/6789'), isNull);
      expect(U30Xml.fastNr('99 999/9999'), isNull);
    });

    test('XML folgt dem Datenstrom U30 07_2026', () {
      final f = VatReturnCalculator.build(
        totals: _totals(
          incomeByRate: {200: 1000000, 49: 10000},
          inputVat: 12345,
          rcBase: 10000,
          rcVat: 2000,
          rcInputVat: 2000,
        ),
        tax: TaxProfile.austria,
        smallBusiness: false,
      );
      final xml = U30Xml.build(
        figures: f,
        fastNr: '123456789',
        year: 2026,
        fromMonth: 7,
        toMonth: 9,
        createdAt: DateTime(2026, 10, 16, 9, 5, 7),
      );
      expect(xml, contains('<ZRVON type="jahrmonat">2026-07</ZRVON>'));
      expect(xml, contains('<ZRBIS type="jahrmonat">2026-09</ZRBIS>'));
      expect(xml, contains('<KZ000 type="kz">10100.00</KZ000>'));
      expect(
        xml,
        contains(
          '<VERSTEUERT><KZ022 type="kz">10000.00</KZ022>'
          '<KZ124 type="kz">100.00</KZ124><KZ057 type="kz">20.00</KZ057>'
          '</VERSTEUERT>',
        ),
      );
      expect(
        xml,
        contains(
          '<VORSTEUER><KZ060 type="kz">123.45</KZ060>'
          '<KZ066 type="kz">20.00</KZ066></VORSTEUER>',
        ),
      );
      expect(xml, isNot(contains('KZ095')));
      expect(xml, contains('<UHRZEIT_ERSTELLUNG type="uhrzeit">09:05:07'));
      expect(U30Xml.fileName(2026, 7, 9), 'U30_2026-07_2026-09.xml');
    });

    test('E1a: Kz 9040 netto', () {
      final lines = VatReturnCalculator.annual(
        totals: _totals(incomeByRate: {200: 1000000}),
        tax: TaxProfile.austria,
        smallBusiness: false,
      );
      expect(lines.first.kz, '9040');
      expect(lines.first.amount, const Money(1000000));
      expect(lines.last.amount, const Money(950000));
    });
  });

  group('Deutschland UStVA', () {
    test('Kz 81 und 86 in vollen Euro, Kz 66, 83', () {
      final f = VatReturnCalculator.build(
        totals: _totals(incomeByRate: {190: 100099, 70: 20050}, inputVat: 5000),
        tax: TaxProfile.germany,
        smallBusiness: false,
      );
      final kz81 = f.lines.firstWhere((l) => l.kz == '81');
      expect(kz81.amount, const Money(100000));
      expect(kz81.copyText, '1000');
      expect(f.amountOf('86'), const Money(20000));
      expect(f.amountOf('66'), const Money(5000));
      // 19.019 + 1.404 − 5.000 = 15.423 Cent
      expect(f.lines.firstWhere((l) => l.kz == '83').copyText, '154,23');
      expect(f.fileAvailable, isFalse); // ELSTER erst mit ERiC
    });

    test('Kleinunternehmer: Anlage EÜR Kz 111, keine UStVA', () {
      final totals = _totals(incomeByRate: {0: 300000});
      expect(
        VatReturnCalculator.build(
          totals: totals,
          tax: TaxProfile.germany,
          smallBusiness: true,
        ).required,
        isFalse,
      );
      final lines = VatReturnCalculator.annual(
        totals: totals,
        tax: TaxProfile.germany,
        smallBusiness: true,
      );
      expect(lines.first.kz, '111');
      expect(lines.where((l) => l.kz == '140'), isEmpty);
    });

    test('Reverse Charge Kz 46, 47, 67', () {
      final f = VatReturnCalculator.build(
        totals: _totals(rcBase: 10050, rcVat: 1910, rcInputVat: 1910),
        tax: TaxProfile.germany,
        smallBusiness: false,
      );
      expect(f.amountOf('46'), const Money(10000));
      expect(f.amountOf('47'), const Money(1910));
      expect(f.amountOf('67'), const Money(1910));
    });
  });
}
