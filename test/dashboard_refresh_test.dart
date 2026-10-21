import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/backup/auto_backup_service.dart';
import 'package:buchhaltung/features/dashboard/dashboard_screen.dart';
import 'package:buchhaltung/features/settings/settings_screen.dart';
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

  Future<AppState> pumpDashboard(WidgetTester tester) async {
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
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await settle(tester);
    return state;
  }

  testWidgets('Sicherungsfehler-Banner verschwindet sofort nach Erfolg', (
    tester,
  ) async {
    final state = await pumpDashboard(tester);
    state.reportAutoBackupOutcome(
      const AutoBackupOutcome(ran: true, error: 'Kein Sicherungsschlüssel'),
    );
    await tester.pump();
    expect(
      find.textContaining('Automatische Sicherung fehlgeschlagen'),
      findsOneWidget,
    );

    // Einrichten bzw. „Jetzt sichern“ war erfolgreich.
    state.reportAutoBackupOutcome(
      const AutoBackupOutcome(ran: true, fileName: 'x'),
    );
    await tester.pump();
    expect(
      find.textContaining('Automatische Sicherung fehlgeschlagen'),
      findsNothing,
    );

    state.reportAutoBackupOutcome(
      const AutoBackupOutcome(ran: true, error: 'Ordner weg'),
    );
    state.clearAutoBackupError();
    await tester.pump();
    expect(
      find.textContaining('Automatische Sicherung fehlgeschlagen'),
      findsNothing,
    );
  });

  testWidgets('Menüsymbol öffnet die Einstellungen als Overlay von rechts', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    // Inhalt der Einstellungen braucht die Plattform-Datenbank; hier nur
    // prüfen, dass das Menü das Seitenmenü mit den Einstellungen trägt.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find
          .ancestor(
            of: find.byIcon(Icons.menu),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.endDrawer, isA<SettingsDrawer>());

    // Zeitraum-Chips in einer Zeile mit kurzen Texten.
    final month = tester.getTopLeft(find.text('Monat'));
    final lastYear = tester.getTopLeft(
      find.text('Vorjahr', skipOffstage: false),
    );
    expect(lastYear.dy, month.dy);
  });
}
