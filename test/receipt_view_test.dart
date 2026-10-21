import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/receipts/receipt_edit_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_list_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Antippen eines vorhandenen Belegs zeigt zuerst die Leseansicht ohne
/// Eingabefelder; „Bearbeiten“ unten öffnet das Formular.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  testWidgets('Beleg antippen: Leseansicht, Bearbeiten öffnet Formular', (
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
    AppDatabase.instance.overrideDatabaseForTesting(db!);
    await tester.runAsync(
      () => db.insert('company_profile', {'id': 1, 'company_name': 'Test'}),
    );
    final state = AppState(Repositories(db));
    await tester.runAsync(
      () => state.repositories.receipts.save(
        Receipt(
          date: DateTime.now(),
          direction: BookingDirection.expense,
          description: 'Druckerpapier',
          counterparty: 'Papierhaus',
          net: const Money(1000),
          vat: const Money(200),
          gross: const Money(1200),
          vatPermille: 200,
        ),
      ),
    );
    await tester.runAsync(state.reload);
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: ReceiptListScreen()),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Druckerpapier'));
    await settle(tester);
    expect(find.byType(ReceiptViewScreen), findsOneWidget);
    expect(find.byType(ReceiptEditScreen), findsNothing);
    // Die Suchleiste der Liste liegt darunter; in der Ansicht kein Feld.
    expect(
      find.descendant(
        of: find.byType(ReceiptViewScreen),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );
    expect(find.text('Papierhaus'), findsOneWidget);

    await tester.tap(find.byKey(const Key('receipt-view-edit')));
    await settle(tester);
    expect(find.byType(ReceiptEditScreen), findsOneWidget);
  });
}
