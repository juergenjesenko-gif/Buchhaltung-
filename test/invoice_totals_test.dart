import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/invoice_texts.dart';
import 'package:buchhaltung/services/invoice_totals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

InvoiceItem item(
  int cents,
  int permille, {
  int qty = 1000,
  int discountPermille = 0,
  int discountCents = 0,
}) => InvoiceItem(
  position: 1,
  description: 'X',
  quantityMilli: qty,
  unitPrice: Money(cents),
  vatPermille: permille,
  discountPermille: discountPermille,
  discountAmount: Money(discountCents),
);

/// Rabatt, Versand, Skonto (L-3.21 bis L-3.24, GR-12).
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  void expectInvariant(InvoiceTotals t) {
    for (final s in t.breakdown.values) {
      expect(s.net + s.vat, isA<Money>());
    }
    expect(t.net + t.vat, t.gross);
    expect(
      t.breakdown.values.map((s) => s.net).sum,
      t.itemsNet - t.discount + t.shipping,
    );
  }

  test('Beispiel AT: 10 % Gesamtrabatt bei 20 % und 10 %', () {
    final t = InvoiceTotals.compute(
      items: [item(10000, 200), item(5000, 100)],
      isSmallBusiness: false,
      discountPermille: 100,
    );
    expect(t.breakdown[200], (net: const Money(9000), vat: const Money(1800)));
    expect(t.breakdown[100], (net: const Money(4500), vat: const Money(450)));
    expect(t.gross, const Money(15750));
    expect(t.discountLines.map((l) => l.net.cents), [-1000, -500]);
    expectInvariant(t);
  });

  test('Restcent nach größtem Rest, deterministisch', () {
    // 1,00 € Rabatt auf drei gleich große Sätze: 34 + 33 + 33.
    expect(InvoiceTotals.allocate(100, {200: 1, 100: 1, 0: 1}), {
      200: 34,
      100: 33,
      0: 33,
    });
    expect(InvoiceTotals.allocate(-100, {200: 1, 100: 1, 0: 1}), {
      200: -34,
      100: -33,
      0: -33,
    });
    // Größter Rest gewinnt vor höherem Satz.
    expect(InvoiceTotals.allocate(10, {200: 1, 100: 2}), {200: 3, 100: 7});
  });

  test('Summe der Anteile ist immer exakt', () {
    for (var total = -997; total < 1000; total += 37) {
      final shares = InvoiceTotals.allocate(total, {200: 777, 100: 333, 0: 7});
      expect(shares.values.fold(0, (a, b) => a + b), total);
    }
  });

  test('Positionsrabatt in Prozent und Betrag', () {
    expect(item(3333, 200, discountPermille: 100).net, const Money(3000));
    expect(item(3333, 200, discountCents: 333).net, const Money(3000));
    // Betrag höchstens Positionsbetrag.
    expect(item(1000, 200, discountCents: 5000).net, const Money.zero());
  });

  test('Versand wie Hauptleistung: ein Satz', () {
    final t = InvoiceTotals.compute(
      items: [item(10000, 100)],
      isSmallBusiness: false,
      shipping: const Money(490),
    );
    expect(t.shippingLines.single.vatPermille, 100);
    expect(t.breakdown[100]!.net, const Money(10490));
    expectInvariant(t);
  });

  test('Versand bei Mischsätzen anteilig nach Entgelt', () {
    final t = InvoiceTotals.compute(
      items: [item(10000, 200), item(5000, 100)],
      isSmallBusiness: false,
      shipping: const Money(1000),
    );
    expect(t.shippingLines.map((l) => (l.vatPermille, l.net.cents)), [
      (200, 667),
      (100, 333),
    ]);
    expectInvariant(t);
  });

  test('Versand mit festem Satz', () {
    final t = InvoiceTotals.compute(
      items: [item(10000, 100)],
      isSmallBusiness: false,
      shipping: const Money(500),
      shippingVatPermille: 200,
    );
    expect(t.breakdown[200], (net: const Money(500), vat: const Money(100)));
  });

  test('Kleinunternehmer: keine Steuer, ein Schlüssel', () {
    final t = InvoiceTotals.compute(
      items: [item(10000, 200), item(5000, 100)],
      isSmallBusiness: true,
      discountAmount: const Money(1500),
      shipping: const Money(500),
    );
    expect(t.breakdown.keys, [0]);
    expect(t.vat, const Money.zero());
    expect(t.gross, const Money(14000));
  });

  test('Rundungsinvariante über viele Kombinationen', () {
    for (var p = 1; p < 2000; p += 97) {
      final t = InvoiceTotals.compute(
        items: [item(p, 200, qty: 1500), item(p * 3 + 1, 100), item(p, 0)],
        isSmallBusiness: false,
        discountPermille: p % 300,
        shipping: Money(p % 700),
      );
      expectInvariant(t);
      final skonto = t.skontoAmount(20);
      final split = t.skontoSplit(skonto);
      expect(
        split.values.map((s) => s.net + s.vat).sum,
        skonto,
        reason: 'Skonto vollständig verteilt',
      );
    }
  });

  test('Skontotext mit festem Datum und Betrag', () {
    final invoice = Invoice(
      number: 'RE-1',
      issueDate: DateTime(2026, 10, 14),
      dueDate: DateTime(2026, 10, 28),
      customerId: 1,
      items: [item(10000, 200)],
      skontoDays: 10,
      skontoPermille: 20,
    );
    expect(invoice.skontoAmount, const Money(240));
    expect(
      InvoiceTexts.paymentTerms(invoice),
      startsWith(
        'Zahlbar bis 28.10.2026 ohne Abzug. Bei Zahlung bis 24.10.2026 2 % Skonto (= ',
      ),
    );
  });

  test('Zahlung mit Skonto mindert Einnahme je Satz', () async {
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
    final repo = InvoiceRepository(db);
    final id = await repo.save(
      Invoice(
        number: 'RE-2026-0001',
        issueDate: DateTime(2026, 10, 1),
        customerId: customerId,
        status: InvoiceStatus.issued,
        items: [item(10000, 200), item(5000, 100)],
        skontoDays: 10,
        skontoPermille: 20,
      ),
    );
    final invoice = (await repo.byId(id))!;
    expect(invoice.grossTotal, const Money(17500));
    await repo.markPaid(id, DateTime(2026, 10, 5), withSkonto: true);
    final rows = await db.query(
      'receipts',
      where: 'invoice_id = ?',
      whereArgs: [id],
      orderBy: 'vat_permille DESC',
    );
    // Skonto 3,50 €: 2,40 € auf 120,00 € (20 %), 1,10 € auf 55,00 € (10 %).
    expect(rows.map((r) => r['gross_cents']), [11760, 5390]);
    expect(rows.map((r) => r['vat_cents']), [1960, 490]);
    for (final r in rows) {
      expect(
        (r['net_cents'] as int) + (r['vat_cents'] as int),
        r['gross_cents'],
      );
    }
    // Rechnung bleibt unverändert, nur der Zahlungsvorgang ist vermerkt.
    final paid = (await repo.byId(id))!;
    expect(paid.grossTotal, const Money(17500));
    expect(paid.skontoTaken, const Money(350));
    await db.close();
  });
}
