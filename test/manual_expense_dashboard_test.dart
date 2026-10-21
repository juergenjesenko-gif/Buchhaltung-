import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/dashboard/dashboard_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Gerätetest 0.6.0: Eine manuell erfasste Ausgabe (ohne Foto, über die
/// Speicherleiste) stand in der Belegliste, fehlte aber in den
/// Monatsausgaben der Übersicht. Kleinunternehmer mit 20 % auf dem Beleg:
/// die Übersicht zählte nur netto, obwohl ohne Vorsteuerabzug der volle
/// Betrag Aufwand ist; der Balken war neben einer großen Einnahme nicht zu
/// sehen.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<(AppState, Database)> pump(
    WidgetTester tester, {
    required bool smallBusiness,
  }) async {
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
    AppDatabase.instance.overrideDatabaseForTesting(db!);
    await tester.runAsync(
      () => db.insert('company_profile', {
        'id': 1,
        'company_name': 'Test',
        'is_small_business': smallBusiness ? 1 : 0,
      }),
    );
    final state = AppState(Repositories(db));
    await tester.runAsync(state.reload);
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await settle(tester);
    return (state, db);
  }

  /// Erfasst eine Ausgabe über das Formular wie auf dem Gerät: Betrag,
  /// Steuersatz, Produkt oder Leistung, „Beleg speichern“.
  Future<void> bookExpense(WidgetTester tester, String rateLabel) async {
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<bool>(
            builder: (_) =>
                const ReceiptEditScreen(direction: BookingDirection.expense),
          ),
        );
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '12,00');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Produkt oder Leistung'),
      'Büromaterial',
    );
    await settle(tester);
    await tester.tap(find.text('Umsatzsteuersatz'));
    await settle(tester);
    await tester.tap(find.textContaining(rateLabel).last);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('receipt-save')));
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
  }

  String expenseText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('dashboard-expense')),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data)
      .join(' ');

  testWidgets('Kleinunternehmer: Ausgabe mit 20 % zählt brutto', (
    tester,
  ) async {
    final (_, db) = await pump(tester, smallBusiness: true);
    await bookExpense(tester, '20 %');
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(expenseText(tester), contains('Ausgaben (brutto)'));
    expect(expenseText(tester), contains('12,00'));
    await tester.runAsync(db.close);
  });

  testWidgets('Regelbesteuert: Ausgabe zählt netto, Vorsteuer getrennt', (
    tester,
  ) async {
    final (_, db) = await pump(tester, smallBusiness: false);
    await bookExpense(tester, '20 %');
    expect(expenseText(tester), contains('Ausgaben (netto)'));
    expect(expenseText(tester), contains('10,00'));
    await tester.runAsync(db.close);
  });

  testWidgets('Regelbesteuert: Umsatz ohne Kleinunternehmergrenze', (
    tester,
  ) async {
    final (_, db) = await pump(tester, smallBusiness: false);
    expect(find.byKey(const Key('turnover-regular')), findsOneWidget);
    expect(find.text('Kleinunternehmergrenze'), findsNothing);
    await tester.runAsync(db.close);
  });

  testWidgets('Kleinunternehmer: Karte mit Grenze', (tester) async {
    final (_, db) = await pump(tester, smallBusiness: true);
    expect(find.text('Kleinunternehmergrenze'), findsOneWidget);
    expect(find.byKey(const Key('turnover-regular')), findsNothing);
    await tester.runAsync(db.close);
  });

  testWidgets('Termine stehen am Ende der Übersicht', (tester) async {
    final (_, db) = await pump(tester, smallBusiness: false);
    final recent = tester.getRect(find.text('Letzte Belege'));
    final deadlines = tester.getRect(find.text('Nächste Termine'));
    expect(deadlines.top, greaterThan(recent.top));
    await tester.runAsync(db.close);
  });

  testWidgets('Beleg aufteilen: Rest automatisch, eine Zeile je Satz', (
    tester,
  ) async {
    final (_, db) = await pump(tester, smallBusiness: false);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<bool>(
            builder: (_) =>
                const ReceiptEditScreen(direction: BookingDirection.expense),
          ),
        );
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, '47,40');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Produkt oder Leistung'),
      'Geschäftsessen',
    );
    await settle(tester);
    final add = find.byKey(const ValueKey('split-add'));
    expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
    await tester.tap(add);
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('split-gross-0')),
      '33,00',
    );
    await settle(tester);
    final rest = tester.widget<TextFormField>(
      find.byKey(const ValueKey('split-gross-1')),
    );
    expect(rest.controller!.text, '14,40');
    expect(find.byKey(const ValueKey('split-error')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('receipt-save')));
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
    final lines = await tester.runAsync(
      () => db.query('receipt_vat_lines', orderBy: 'position'),
    );
    expect(lines!.map((l) => l['gross_cents']), [3300, 1440]);
    expect(lines.map((l) => l['vat_permille']).toSet(), hasLength(2));
    await tester.runAsync(db.close);
  });
}
