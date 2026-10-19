import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/features/dashboard/dashboard_screen.dart';
import 'package:buchhaltung/features/invoices/customer_edit_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_list_screen.dart';
import 'package:buchhaltung/features/invoices/invoice_list_screen.dart';

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

  /// Runder Aufnahmeknopf (Regel 13): Kreis ≥ 72 dp, mittig, „Beleg“.
  void expectCapture(WidgetTester tester, Finder f, Size size) {
    final circle = find.descendant(
      of: f,
      matching: find.byType(FloatingActionButton),
    );
    final r = tester.getRect(circle);
    expect(r.width, greaterThanOrEqualTo(72));
    expect(r.height, greaterThanOrEqualTo(72));
    expect((r.center.dx - size.width / 2).abs(), lessThan(2));
    expect(find.descendant(of: f, matching: find.text('Beleg')), findsOne);
    expect(
      find.descendant(of: f, matching: find.byIcon(Icons.photo_camera)),
      findsOne,
    );
  }

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    testWidgets(
      'Belegliste: runder Aufnahmeknopf mittig (${size.width.toInt()} dp)',
      (tester) async {
        await pump(tester, const ReceiptListScreen(), size);
        final fab = find.byKey(const Key('receipt-new'));
        expectBottomThird(tester, fab, size);
        expectCapture(tester, fab, size);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Übersicht: ein zentrierter Knopf „Beleg fotografieren“', (
    tester,
  ) async {
    const size = Size(360, 640);
    await pump(tester, const DashboardScreen(), size);
    final fab = find.byKey(const Key('dashboard-photo'));
    expect(fab, findsOneWidget);
    // Hauptknopf plus „Foto“ und „Datei“ (Regel 13).
    expect(find.byType(FloatingActionButton), findsNWidgets(3));
    expectBottomThird(tester, fab, size);
    expectCapture(tester, fab, size);
    expect((tester.getRect(fab).center.dx - size.width / 2).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });

  // Aufnahmeleiste (Regel 13): „Foto“ links, „Datei“ rechts, je ≥ 56 dp,
  // spiegelgleich um den mittigen Hauptknopf, Abstand ≥ 48 dp, kleiner als
  // der Hauptknopf.
  for (final (name, screen, prefix, cameraKey) in [
    ('Übersicht', const DashboardScreen(), 'dashboard', 'dashboard-photo'),
    ('Belegliste', const ReceiptListScreen(), 'receipt-new', 'receipt-new'),
  ]) {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets(
        '$name: Foto und Datei neben „Beleg“ (${size.width.toInt()} dp)',
        (tester) async {
          await pump(tester, screen, size);
          Rect circle(String key) => tester.getRect(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(FloatingActionButton),
            ),
          );
          final main = circle(cameraKey);
          final photo = circle('$prefix-gallery');
          final file = circle('$prefix-file');
          for (final r in [photo, file]) {
            expect(r.width, greaterThanOrEqualTo(56));
            expect(r.height, greaterThanOrEqualTo(56));
            expect(r.width, lessThan(main.width));
            expect(r.center.dy, greaterThan(size.height * 2 / 3));
          }
          expect((main.center.dx - size.width / 2).abs(), lessThan(2));
          expect(photo.center.dx, lessThan(main.center.dx));
          expect(file.center.dx, greaterThan(main.center.dx));
          expect(main.left - photo.right, greaterThan(47.99));
          expect(file.left - main.right, greaterThan(47.99));
          expect(
            ((main.center.dx - photo.center.dx) -
                    (file.center.dx - main.center.dx))
                .abs(),
            lessThan(1),
          );
          expect(photo.left, greaterThanOrEqualTo(16));
          expect(file.right, lessThanOrEqualTo(size.width - 16));
          expect(find.text('Foto'), findsOneWidget);
          expect(find.text('Datei'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (name, screen, key, label) in [
    (
      'Rechnungsliste',
      const InvoiceListScreen(),
      'invoice-new',
      'Neue Rechnung',
    ),
  ]) {
    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets(
        '$name: zentrierter Knopf „$label“ (${size.width.toInt()} dp)',
        (tester) async {
          await pump(tester, screen, size);
          final fab = find.byKey(Key(key));
          expect(fab, findsOneWidget);
          expect(
            find.descendant(of: fab, matching: find.text(label)),
            findsOneWidget,
          );
          expectBottomThird(tester, fab, size);
          expect(tester.getSize(fab).height, greaterThanOrEqualTo(56));
          expect(
            (tester.getRect(fab).center.dx - size.width / 2).abs(),
            lessThan(2),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

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

  testWidgets('Kundin: E-Rechnung-Format als ganze Zeilen, Leitweg-ID erst '
      'bei XRechnung, Lieferantennummer nur bei ebInterface (FA-5.49)', (
    tester,
  ) async {
    const size = Size(360, 740);
    await pump(
      tester,
      const CustomerEditScreen(existing: Customer(id: 1, name: 'Stadt')),
      size,
    );
    final xr = find.byKey(const Key('customer-einvoice-xrechnung'));
    await tester.scrollUntilVisible(
      xr,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    for (final f in EInvoiceFormat.values) {
      final tile = find.byKey(Key('customer-einvoice-${f.name}'));
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(56));
    }
    expect(find.text('Leitweg-ID'), findsNothing);
    expect(find.text('Käuferreferenz (optional)'), findsOneWidget);
    await tester.tap(xr);
    await tester.pumpAndSettle();
    expect(find.text('Leitweg-ID'), findsOneWidget);
    expect(find.byKey(const Key('customer-supplier-number')), findsNothing);
    final ebi = find.byKey(const Key('customer-einvoice-ebInterface'));
    await tester.tap(ebi);
    await tester.pumpAndSettle();
    expect(find.text('Auftragsreferenz'), findsOneWidget);
    expect(find.byKey(const Key('customer-supplier-number')), findsOneWidget);
  });
}
