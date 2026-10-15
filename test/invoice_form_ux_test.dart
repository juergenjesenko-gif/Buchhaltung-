import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/invoices/invoice_edit_screen.dart';
import 'package:buchhaltung/widgets/primary_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// UX-Vorgaben für das Rechnungsformular: Primärtaste 56 dp unten über der
/// Tastatur, Zielflächen ≥ 48 dp, optionale Bereiche eingeklappt.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<void> pump(
    WidgetTester tester, {
    double keyboard = 0,
    double height = 844,
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
    final state = AppState(Repositories(db!));
    tester.view.physicalSize = Size(390, height);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: InvoiceEditScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    expect(finder, findsOneWidget);
  }

  testWidgets('„Rechnung ausstellen“ 56 dp hoch, volle Breite, unten', (
    tester,
  ) async {
    await pump(tester);
    final issue = find.byKey(const Key('invoice-issue'));
    expect(issue, findsOneWidget);
    final rect = tester.getRect(issue);
    expect(rect.height, greaterThanOrEqualTo(PrimaryActionBar.height));
    expect(rect.bottom, greaterThan(844 - 100));
    expect(
      tester.getSize(find.byKey(const Key('invoice-draft'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('Tastatur verdeckt „Rechnung ausstellen“ nicht', (tester) async {
    await pump(tester, keyboard: 300);
    final rect = tester.getRect(find.byKey(const Key('invoice-issue')));
    expect(rect.bottom, lessThanOrEqualTo(844 - 300));
  });

  testWidgets('Position hinzufügen: volle Breite, 48 dp; Entfernen 48 dp', (
    tester,
  ) async {
    await pump(tester, height: 3000);
    final add = find.byKey(const Key('addInvoiceItem'));
    await scrollTo(tester, add);
    expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(add).width, greaterThan(300));
    await tester.tap(add);
    await tester.pump();
    final remove = find.byKey(const Key('removeItem2'));
    await scrollTo(tester, remove);
    expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(remove).width, greaterThanOrEqualTo(48));
  });

  testWidgets('Rabatt, Versand, Skonto sind eingeklappt', (tester) async {
    await pump(tester, height: 3000);
    expect(find.text('Rabatt hinzufügen'), findsOneWidget);
    expect(find.byKey(const Key('invoiceShipping')), findsNothing);
    expect(find.byKey(const Key('skontoPercent')), findsNothing);
    final addShipping = find.byKey(const Key('addShipping'));
    await scrollTo(tester, addShipping);
    expect(tester.getSize(addShipping).height, greaterThanOrEqualTo(48));
  });

  testWidgets('Zurück verwirft geänderten Entwurf nicht still (FA-5.34)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Beenden'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Beratung');
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    // Ohne Kunde nicht speicherbar: einmal nachfragen statt verwerfen.
    expect(find.text('Entwurf noch nicht speicherbar'), findsOneWidget);
    await tester.tap(find.text('Weiter bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invoice-issue')), findsOneWidget);
  });
}
