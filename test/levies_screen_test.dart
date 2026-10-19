import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/features/levies/levies_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Bildschirm „Abgaben & Rücklagen“ (FA-19.2, UX-Instanz: einhändig,
/// Touchflächen ≥ 48 dp, Speichern unten volle Breite).
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<AppState> pump(WidgetTester tester, String country) async {
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
        'country_code': country,
      }),
    );
    final state = AppState(Repositories(db!));
    await tester.runAsync(state.reload);
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: LeviesScreen()),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await settle(tester);
    return state;
  }

  testWidgets('AT: SVS und ESt, Hinweis Schätzung, Speichern 56 dp', (
    tester,
  ) async {
    await pump(tester, 'AT');
    expect(find.textContaining('ersetzt keine Steuerberatung'), findsOneWidget);
    expect(find.byKey(const Key('levy-socialInsurance')), findsOneWidget);
    expect(find.byKey(const Key('levy-incomeTax')), findsOneWidget);
    expect(find.byKey(const Key('levy-tradeTax')), findsNothing);
    final save = tester.getSize(find.byKey(const Key('levy-save')));
    expect(save.height, greaterThanOrEqualTo(56));
    expect(save.width, greaterThan(300));
    await tester.scrollUntilVisible(
      find.byKey(const Key('levy-exempt')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.getSize(find.byKey(const Key('levy-exempt'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(find.byKey(const Key('levy-church')), findsNothing);
  });

  testWidgets('DE: Gewerbesteuer, Kirchensteuer, KV-Betrag; Speichern', (
    tester,
  ) async {
    final state = await pump(tester, 'DE');
    await tester.scrollUntilVisible(
      find.byKey(const Key('levy-church')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('levy-health')), findsOneWidget);
    expect(find.byKey(const Key('levy-multiplier')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('levy-church')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('levy-church')));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('levy-church'))).value,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('levy-save')));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final saved = await tester.runAsync(state.repositories.levySettings.load);
    expect(saved!.churchTax, isTrue);
  });
}
