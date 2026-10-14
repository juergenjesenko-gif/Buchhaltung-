import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Gerätetest 0.3.3: Ein in der Belegliste gespeicherter Beleg erschien nicht
/// auf der Übersicht, weil diese im IndexedStack lebt und nur einmal lud.
/// Echte SQLite-Aufrufe brauchen echte Zeit; die Übersicht lädt mehrstufig.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  testWidgets('Übersicht lädt nach einer Buchung in einem anderen Reiter neu', (
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
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await settle(tester);
    expect(find.textContaining('Noch keine Belege erfasst'), findsOneWidget);

    // Speichern wie im Belegformular, aufgerufen aus dem Reiter „Belege“.
    await tester.runAsync(() async {
      await state.repositories.receipts.save(
        Receipt(
          date: DateTime.now(),
          direction: BookingDirection.expense,
          description: 'Gerätetest',
          net: const Money(779),
          vat: const Money(78),
          gross: const Money(857),
          vatPermille: 100,
          paymentMethod: PaymentMethod.cash,
        ),
      );
      await state.onBookingsChanged();
    });
    await settle(tester);

    expect(find.textContaining('Noch keine Belege erfasst'), findsNothing);
    expect(find.text('Gerätetest'), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
