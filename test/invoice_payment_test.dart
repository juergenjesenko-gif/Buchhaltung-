import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/fiscal_year.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Gerätetest 0.3.4: Eine bezahlte Ausgangsrechnung erschien nicht in der
/// Übersicht und nicht in der Kleinunternehmergrenze, weil Rechnungen nie in
/// die Belegtabelle flossen, aus der `totals()` und `turnoverForYear()`
/// rechnen (L-25.9).
void main() {
  setUpAll(sqfliteFfiInit);

  Future<(Database, InvoiceRepository, ReceiptRepository, int)> setUp() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );
    await db.insert('company_profile', {'id': 1, 'company_name': 'Test'});
    final customerId = await db.insert('customers', {'name': 'Kundin'});
    final invoices = InvoiceRepository(db);
    final id = await invoices.save(
      Invoice(
        number: 'RE-2026-0001',
        issueDate: DateTime(2026, 9, 30),
        customerId: customerId,
        isSmallBusiness: true,
        status: InvoiceStatus.issued,
        items: [
          InvoiceItem(
            position: 1,
            description: 'Beratung',
            quantityMilli: 1000,
            unitPrice: const Money(250000),
            vatPermille: 0,
          ),
        ],
      ),
    );
    return (db, invoices, ReceiptRepository(db), id);
  }

  test('offene Rechnung zählt nicht (Zuflussprinzip)', () async {
    final (_, _, receipts, _) = await setUp();
    final totals = await receipts.totals(
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 12, 31),
    );
    expect(totals.incomeGross, const Money.zero());
  });

  test(
    'bezahlte Rechnung ist Einnahme im Monat des Zahlungseingangs',
    () async {
      final (_, invoices, receipts, id) = await setUp();
      await invoices.markPaid(id, DateTime(2026, 10, 14));

      final october = await receipts.totals(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      );
      final september = await receipts.totals(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      expect(october.incomeGross, const Money(250000));
      expect(september.incomeGross, const Money.zero());
      // Kleinunternehmergrenze: Kalenderjahr, Umsatz aus den Belegen.
      expect(
        await receipts.turnoverForYear(2026, includeVat: true),
        const Money(250000),
      );
      expect((await invoices.byId(id))!.status, InvoiceStatus.paid);
    },
  );

  test('zweimal bezahlt markiert bucht nur einmal', () async {
    final (_, invoices, receipts, id) = await setUp();
    await invoices.markPaid(id, DateTime(2026, 10, 14));
    await invoices.markPaid(id, DateTime(2026, 10, 15));
    expect(await invoices.bookMissingPayments(), 0);
    expect(
      await receipts.turnoverForYear(2026, includeVat: true),
      const Money(250000),
    );
  });

  test('vor Schema 11 bezahlte Rechnungen werden nachgebucht', () async {
    final (db, invoices, receipts, id) = await setUp();
    await db.update('invoices', {
      'status': 'paid',
      'paid_at': '2026-10-14T09:00:00',
    });
    expect(await invoices.bookMissingPayments(), 1);
    final rows = await db.query(
      'receipts',
      where: 'invoice_id = ?',
      whereArgs: [id],
    );
    expect(rows.single['date'], '2026-10-14');
    expect(rows.single['direction'], 'income');
    expect(await invoices.bookMissingPayments(), 0);
    expect(
      await receipts.turnoverForYear(2026, includeVat: true),
      const Money(250000),
    );
  });

  test('Regression L-24.4: Kleinunternehmergrenze bleibt Kalenderjahr, '
      'auch bei Wirtschaftsjahr April–März', () async {
    final (_, invoices, receipts, id) = await setUp();
    // Zahlung im März 2027: Wirtschaftsjahr 2027 (April 2026 – März 2027),
    // aber Kalenderjahr 2027 für die Umsatzsteuer.
    await invoices.markPaid(id, DateTime(2027, 3, 15));
    expect(
      await receipts.turnoverForYear(2026, includeVat: true),
      const Money.zero(),
    );
    expect(
      await receipts.turnoverForYear(2027, includeVat: true),
      const Money(250000),
    );
    final wj = Period.fiscalYear(
      const FiscalYear(4),
      2027,
      TaxProfile.austria.monthNames,
    );
    final totals = await receipts.totals(from: wj.from, to: wj.to);
    expect(totals.incomeGross, const Money(250000));
  });
}
