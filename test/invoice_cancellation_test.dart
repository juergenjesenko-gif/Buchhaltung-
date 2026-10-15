import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/invoice_cancellation.dart';
import 'package:buchhaltung/services/invoice_numbering.dart';
import 'package:buchhaltung/services/invoice_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stornorechnung (L-3.7, L-3.18, Spezifikation GR-14).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  String number(int sequence) => InvoiceNumbering.format(
    pattern: InvoiceNumbering.defaultPattern,
    sequence: sequence,
    date: DateTime(2026, 10, 15),
  );

  /// Zwei Sätze, Rundung je Position, Gesamtrabatt und Versand.
  final items = [
    InvoiceItem(
      position: 1,
      description: 'Beratung',
      quantityMilli: 1500,
      unitPrice: const Money(3333),
      vatPermille: 200,
    ),
    InvoiceItem(
      position: 2,
      description: 'Buch',
      quantityMilli: 3000,
      unitPrice: const Money(1999),
      vatPermille: 100,
    ),
  ];

  Future<(Database, InvoiceRepository, int)> setUp() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );
    await db.insert('company_profile', {
      'id': 1,
      'company_name': 'Test',
      'next_invoice_sequence': 1,
    });
    final customerId = await db.insert('customers', {'name': 'Kundin'});
    final invoices = InvoiceRepository(db);
    final id = await invoices.save(
      Invoice(
        number: 'ENTWURF-1',
        issueDate: DateTime(2026, 9, 30),
        customerId: customerId,
        status: InvoiceStatus.issued,
        items: items,
        discountPermille: 50,
        shipping: const Money(490),
      ),
      assignNumber: number,
    );
    return (db, invoices, id);
  }

  Future<List<Map<String, Object?>>> receipts(Database db) =>
      db.query('receipts', where: 'cancelled_at IS NULL');

  test('Stornorechnung bekommt die nächste Nummer, lückenlos', () async {
    final (db, invoices, id) = await setUp();
    final stornoId = await invoices.cancelWithInvoice(
      id,
      reason: 'Fehler in der Rechnung',
      date: DateTime(2026, 10, 15),
      assignNumber: number,
    );
    final original = (await invoices.byId(id))!;
    final storno = (await invoices.byId(stornoId))!;
    expect(original.number, 'RE-2026-0001');
    expect(storno.number, 'RE-2026-0002');
    expect(storno.status, InvoiceStatus.cancellation);
    expect(storno.cancelsNumber, 'RE-2026-0001');
    expect(storno.cancelsIssueDate, DateTime(2026, 9, 30));
    expect(storno.cancelReason, 'Fehler in der Rechnung');
    expect(original.status, InvoiceStatus.cancelled);
    expect(original.cancelledByInvoiceId, stornoId);
    final profile = await db.query('company_profile');
    expect(profile.first['next_invoice_sequence'], 3);
  });

  test('Beträge je Steuersatz exakt negiert, Summe null', () async {
    final (_, invoices, id) = await setUp();
    final stornoId = await invoices.cancelWithInvoice(
      id,
      reason: 'Auftrag storniert',
      date: DateTime(2026, 10, 15),
      assignNumber: number,
    );
    final original = (await invoices.byId(id))!;
    final storno = (await invoices.byId(stornoId))!;
    expect(original.vatBreakdown.length, 2);
    for (final rate in original.vatBreakdown.keys) {
      expect(storno.vatBreakdown[rate]!.net, -original.vatBreakdown[rate]!.net);
      expect(storno.vatBreakdown[rate]!.vat, -original.vatBreakdown[rate]!.vat);
    }
    expect(storno.grossTotal, -original.grossTotal);
    expect(storno.netTotal + storno.vatTotal, storno.grossTotal);
    // Rundung je Position bleibt identisch zum Original.
    expect(original.totals.negated().vat, storno.vatTotal);
  });

  test('offene Rechnung: keine Buchung, Mahnung storniert', () async {
    final (db, invoices, id) = await setUp();
    await db.insert('dunning_notices', {
      'invoice_id': id,
      'level': 1,
      'issued_on': '2026-10-10',
      'new_due_date': '2026-10-24',
      'principal_cents': 1,
      'fee_cents': 0,
      'fees_total_cents': 0,
      'interest_cents': 0,
      'interest_rate_bp': 0,
      'flat_fee_cents': 0,
      'total_cents': 1,
      'text': '',
      'created_at': '2026-10-10',
    });
    await invoices.cancelWithInvoice(
      id,
      reason: 'Auftrag storniert',
      date: DateTime(2026, 10, 15),
      assignNumber: number,
    );
    expect(await receipts(db), isEmpty);
    final notices = await db.query('dunning_notices');
    expect(notices.single['cancelled_at'], isNotNull);
    expect(notices.single['cancel_reason'], contains('RE-2026-0002'));
  });

  test('bezahlte Rechnung: Rückzahlung als negative Einnahme', () async {
    final (db, invoices, id) = await setUp();
    await invoices.markPaid(id, DateTime(2026, 10, 1));
    final original = (await invoices.byId(id))!;
    await invoices.cancelWithInvoice(
      id,
      reason: 'Auftrag storniert',
      date: DateTime(2026, 11, 3),
      assignNumber: number,
    );
    final rows = await receipts(db);
    final income = rows.where(
      (r) => r['date'].toString().startsWith('2026-10'),
    );
    final refund = rows.where(
      (r) => r['date'].toString().startsWith('2026-11'),
    );
    int sum(Iterable<Map<String, Object?>> r, String c) =>
        r.fold(0, (a, b) => a + (b[c] as int));
    expect(sum(income, 'gross_cents'), original.grossTotal.cents);
    expect(sum(refund, 'gross_cents'), -original.grossTotal.cents);
    expect(sum(refund, 'vat_cents'), -original.vatTotal.cents);
    expect(refund.length, 2);
  });

  test('doppelt stornieren geht nicht, Storno nicht stornierbar', () async {
    final (_, invoices, id) = await setUp();
    final stornoId = await invoices.cancelWithInvoice(
      id,
      reason: 'x',
      date: DateTime(2026, 10, 15),
      assignNumber: number,
    );
    expect(
      () => invoices.cancelWithInvoice(
        id,
        reason: 'x',
        date: DateTime(2026, 10, 15),
        assignNumber: number,
      ),
      throwsStateError,
    );
    expect(
      () => invoices.cancelWithInvoice(
        stornoId,
        reason: 'x',
        date: DateTime(2026, 10, 15),
        assignNumber: number,
      ),
      throwsStateError,
    );
    expect(
      () => invoices.cancelWithInvoice(
        id,
        reason: ' ',
        date: DateTime(2026, 10, 15),
        assignNumber: number,
      ),
      throwsArgumentError,
    );
  });

  test('Korrigieren: Entwurf als Kopie, ohne Nummer', () async {
    final (_, invoices, id) = await setUp();
    final original = (await invoices.byId(id))!;
    final draft = InvoiceCancellation.correctionDraft(
      original,
      DateTime(2026, 10, 15),
    );
    expect(draft.status, InvoiceStatus.draft);
    expect(draft.number, startsWith('ENTWURF-'));
    expect(draft.grossTotal, original.grossTotal);
    expect(draft.isCancellation, isFalse);
    final draftId = await invoices.save(draft);
    expect((await invoices.byId(draftId))!.items.length, 2);
  });

  test('PDF der Stornorechnung entsteht', () async {
    final (db, invoices, id) = await setUp();
    final stornoId = await invoices.cancelWithInvoice(
      id,
      reason: 'Fehler in der Rechnung',
      date: DateTime(2026, 10, 15),
      assignNumber: number,
    );
    final storno = (await invoices.byId(stornoId))!;
    final repos = CustomerRepository(db);
    final customer = (await repos.byId(storno.customerId))!;
    final profile = (await CompanyRepository(db).load())!;
    final bytes = await InvoicePdf(
      invoice: storno,
      customer: customer,
      profile: profile,
    ).build();
    expect(bytes.length, greaterThan(1000));
  });
}
