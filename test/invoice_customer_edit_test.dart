import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/customer.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/features/invoices/customer_edit_screen.dart';
import 'package:buchhaltung/features/invoices/invoice_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// FA-5.50: Fehlende Kunden-UID bei AT-Rechnungen über 10.000 € sperrt das
/// Ausstellen nicht; „Kunde bearbeiten“ öffnet das Kundenformular aus dem
/// Entwurf heraus.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  Future<void> pump(WidgetTester tester, {InvoiceStatus? status}) async {
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
    final customerId = await tester.runAsync(() async {
      await state.saveProfile(
        const CompanyProfile(
          companyName: 'Test e.U.',
          country: Country.at,
          street: 'Weg 1',
          postalCode: '1010',
          city: 'Wien',
          vatId: 'ATU13585627',
        ),
      );
      return state.repositories.customers.save(
        const Customer(
          name: 'Kunde GmbH',
          street: 'Gasse 2',
          postalCode: '8010',
          city: 'Graz',
          isBusiness: true,
        ),
      );
    });
    final invoice = Invoice(
      number: 'ENTWURF-1',
      issueDate: DateTime(2026, 10, 24),
      deliveryDate: DateTime(2026, 10, 24),
      customerId: customerId!,
      status: status ?? InvoiceStatus.draft,
      items: [
        InvoiceItem(
          position: 1,
          description: 'Beratung',
          quantityMilli: 1000,
          unitPrice: Money.fromEuro(11000),
          vatPermille: 200,
        ),
      ],
    );
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(home: InvoiceEditScreen(existing: invoice)),
      ),
    );
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
  }

  testWidgets('UID fehlt: Hinweis, Ausstellen bleibt möglich', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('invoice-warning')), findsOneWidget);
    expect(find.textContaining('Berichtigung'), findsOneWidget);
    final issue = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('invoice-issue')),
    );
    expect(issue.onPressed, isNotNull);
  });

  testWidgets('„Kunde bearbeiten“: 48 dp, öffnet Kundenformular, übernimmt '
      'den neuen Stand', (tester) async {
    await pump(tester);
    final edit = find.byKey(const Key('invoice-edit-customer'));
    expect(edit, findsOneWidget);
    expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
    await tester.tap(edit);
    await settle(tester);
    expect(find.byType(CustomerEditScreen), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'UID-Nummer'),
      'ATU13585627',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('customer-save')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
    expect(find.byType(CustomerEditScreen), findsNothing);
    expect(find.byKey(const Key('invoice-warning')), findsNothing);
  });

  testWidgets('Gestellte Rechnung: kein „Kunde bearbeiten“ (GR-8)', (
    tester,
  ) async {
    await pump(tester, status: InvoiceStatus.issued);
    expect(find.byKey(const Key('invoice-edit-customer')), findsNothing);
    expect(find.byKey(const Key('invoice-warning')), findsNothing);
  });
}
