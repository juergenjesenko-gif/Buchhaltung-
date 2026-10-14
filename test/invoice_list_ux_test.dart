import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/features/invoices/invoice_list_screen.dart';
import 'package:buchhaltung/services/dunning_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Rechnungsliste nach UX-Vorgaben: „Bezahlt“ und „Erinnern“ als
/// Tonal-Knöpfe ≥ 48 dp; Mahnung in höchstens drei Tipps bis zum Teilen.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  testWidgets('überfällige Rechnung: Erinnern und Bezahlt, Mahn-Sheet', (
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
    await tester.runAsync(() async {
      await db.insert('company_profile', {
        'id': 1,
        'company_name': 'Test',
        'country_code': 'DE',
      });
      final customerId = await db.insert('customers', {
        'name': 'Privatkundin',
        'street': 'Weg 1',
        'postal_code': '10115',
        'city': 'Berlin',
      });
      await state.repositories.invoices.save(
        Invoice(
          number: 'RE-2026-0001',
          issueDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 1, 15),
          customerId: customerId,
          status: InvoiceStatus.issued,
          items: [
            InvoiceItem(
              position: 1,
              description: 'Beratung',
              quantityMilli: 1000,
              unitPrice: const Money(10000),
              vatPermille: 190,
            ),
          ],
        ),
      );
      await state.reload();
    });
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: InvoiceListScreen()),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('overdueBanner')), findsOneWidget);
    final remind = find.byKey(const ValueKey('remind-1'));
    final paid = find.byKey(const ValueKey('paid-1'));
    expect(tester.getSize(remind).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(paid).height, greaterThanOrEqualTo(48));
    expect(find.text('Erinnern'), findsOneWidget);

    // Tipp 1: Erinnern → Sheet mit Vorschau und Primärknopf.
    await tester.tap(remind);
    await settle(tester);
    expect(find.text('Zahlungserinnerung zu RE-2026-0001'), findsOneWidget);
    final create = find.byKey(const Key('dunningCreate'));
    expect(create, findsOneWidget);
    expect(tester.getSize(create).height, greaterThanOrEqualTo(56));
    // Zahlungserinnerung kostenlos: kein Verbraucherhinweis.
    expect(find.byKey(const Key('consumerFeeHint')), findsNothing);
    await tester.enterText(find.byKey(const Key('dunningFee')), '10,00');
    await tester.pump();
    expect(find.text(DunningService.consumerFeeHint), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
