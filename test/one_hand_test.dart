import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/features/dashboard/dashboard_screen.dart';
import 'package:buchhaltung/features/invoices/customer_edit_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_list_screen.dart';

import 'package:buchhaltung/widgets/primary_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Einhandbedienung (DESIGN_SPEC 5a, Prüfregel 12): Mindestgröße und Lage der
/// Primäraktion, zerstörende Aktionen nicht in der AppBar, Chips umbrechen.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<AppState> pump(WidgetTester tester, Widget home, Size size) async {
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
      () => db!.insert('company_profile', {'id': 1, 'company_name': 'Test'}),
    );
    final state = AppState(Repositories(db!));
    await tester.runAsync(state.reload);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(home: home),
      ),
    );
    await settle(tester);
    return state;
  }

  void expectBottomThird(WidgetTester tester, Finder f, Size size) {
    final rect = tester.getRect(f);
    expect(rect.center.dy, greaterThan(size.height * 2 / 3));
    expect(rect.height, greaterThanOrEqualTo(48));
  }

  testWidgets('Übersicht: ein zentrierter Knopf „Beleg fotografieren“', (
    tester,
  ) async {
    const size = Size(360, 640);
    await pump(tester, const DashboardScreen(), size);
    final fab = find.byKey(const Key('dashboard-photo'));
    expect(fab, findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expectBottomThird(tester, fab, size);
    expect(tester.getSize(fab).height, greaterThanOrEqualTo(56));
    expect((tester.getRect(fab).center.dx - size.width / 2).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Belegliste: Jahr in der Chip-Reihe, kein Überlauf bei 360 dp', (
    tester,
  ) async {
    await pump(tester, const ReceiptListScreen(), const Size(360, 640));
    expect(find.byKey(const Key('receipt-year')), findsOneWidget);
    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: find.byType(PopupMenuButton<int>)),
      findsNothing,
    );
    expect(find.byType(Wrap), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kundenformular: Speichern unten, Löschen am Ende, rot', (
    tester,
  ) async {
    const size = Size(412, 915);
    await pump(
      tester,
      const CustomerEditScreen(existing: Customer(id: 1, name: 'Kundin')),
      size,
    );
    final save = find.byKey(const Key('customer-save'));
    expectBottomThird(tester, save, size);
    expect(tester.getSize(save).height, PrimaryActionBar.height);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsNothing,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    final del = find.byKey(const Key('customer-delete'));
    expect(tester.getSize(del).height, greaterThanOrEqualTo(48));
    // Abstand ≥ 24 dp zur Speicherleiste.
    expect(
      tester.getRect(save).top - tester.getRect(del).bottom,
      greaterThanOrEqualTo(24),
    );
    await tester.tap(del);
    await tester.pumpAndSettle();
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('confirmDestructive')),
    );
    expect(find.text('Löschen'), findsWidgets);
    expect(confirm.style?.backgroundColor, isNotNull);
  });
}
