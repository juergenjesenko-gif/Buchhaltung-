import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/dunning.dart';
import 'package:buchhaltung/domain/invoice.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/services/dunning_calculator.dart';
import 'package:buchhaltung/services/dunning_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Mahnwesen (L-3.10, L-3.27 bis L-3.30).
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  final at = TaxProfile.austria.dunning;
  final de = TaxProfile.germany.dunning;

  Invoice invoice({int? id}) => Invoice(
    id: id,
    number: 'RE-2026-0007',
    issueDate: DateTime(2026, 5, 1),
    dueDate: DateTime(2026, 5, 31),
    customerId: 1,
    status: InvoiceStatus.issued,
    isSmallBusiness: true,
    items: [
      InvoiceItem(
        position: 1,
        description: 'Beratung',
        quantityMilli: 1000,
        unitPrice: const Money(100000),
        vatPermille: 0,
      ),
    ],
  );

  test('Stufen: Zahlungserinnerung, dann 1., 2. Mahnung', () {
    expect(dunningTitle(1), 'Zahlungserinnerung');
    expect(dunningTitle(2), '1. Mahnung');
    expect(dunningTitle(3), '2. Mahnung');
  });

  test('Zahlungserinnerung kostenlos, Mahnung 10 €', () {
    expect(
      DunningCalculator.suggestedFee(1, const Money(1000)),
      const Money.zero(),
    );
    expect(
      DunningCalculator.suggestedFee(2, const Money(1000)),
      const Money(1000),
    );
  });

  test('gesetzliche Sätze AT und DE', () {
    final d = DateTime(2026, 3, 1);
    expect(at.statutoryRateBp(business: false, date: d), 400);
    expect(at.statutoryRateBp(business: true, date: d), 153 + 920);
    expect(de.statutoryRateBp(business: false, date: d), 127 + 500);
    expect(de.statutoryRateBp(business: true, date: d), 127 + 900);
    final h2 = DateTime(2026, 8, 1);
    expect(de.statutoryRateBp(business: true, date: h2), 152 + 900);
    expect(at.statutoryRateBp(business: true, date: h2), 153 + 920);
    expect(at.consumerDefaultNotice, isNull);
    expect(de.consumerDefaultNotice, contains('§ 286 Abs. 3 BGB'));
  });

  test('Zinsen act/365, abschnittsweise je Halbjahr', () {
    // 1.000 € fällig 31.5., bis 31.7.: Juni 30 Tage + Juli 31 Tage.
    final result = DunningCalculator.interest(
      principal: const Money(100000),
      dueDate: DateTime(2026, 5, 31),
      until: DateTime(2026, 7, 31),
      rules: de,
      business: true,
    );
    expect(result.periods.map((p) => p.days), [30, 31]);
    // Juni: 100000 × 1027 × 30 / 3.650.000 = 844,1 → 844;
    // Juli (Basiszins 1,52 %): 100000 × 1052 × 31 / 3.650.000 = 893,5 → 893
    expect(result.amount, const Money(844 + 893));
  });

  test('AT Verbraucher 4 % ohne Halbjahresteilung', () {
    final result = DunningCalculator.interest(
      principal: const Money(100000),
      dueDate: DateTime(2026, 5, 31),
      until: DateTime(2026, 7, 31),
      rules: at,
      business: false,
    );
    expect(result.periods.length, 1);
    expect(result.amount, const Money(668)); // 100000×400×61/3650000 = 668,5…
  });

  test('keine Zinsen vor Fälligkeit', () {
    expect(
      DunningCalculator.interest(
        principal: const Money(100000),
        dueDate: DateTime(2026, 5, 31),
        until: DateTime(2026, 5, 31),
        rules: at,
        business: true,
      ).amount,
      const Money.zero(),
    );
  });

  test('Anrechnung: Kosten, Zinsen, Hauptforderung', () {
    final a = DunningCalculator.allocatePayment(
      received: const Money(1500),
      costs: const Money(1000),
      interest: const Money(800),
      principal: const Money(100000),
    );
    expect(a, (
      costs: const Money(1000),
      interest: const Money(500),
      principal: const Money.zero(),
    ));
  });

  test('Mahnkosten kumulieren, Pauschale nur B2B und einmal', () {
    final first = DunningService.compose(
      invoice: invoice(id: 1),
      previous: const [],
      rules: de,
      business: false,
      issuedOn: DateTime(2026, 6, 10),
      newDueDate: DateTime(2026, 6, 24),
      fee: const Money.zero(),
      withInterest: false,
      withFlatFee: true,
    ).notice;
    expect(first.flatFee, const Money.zero());
    expect(first.title, 'Zahlungserinnerung');
    final second = DunningService.compose(
      invoice: invoice(id: 1),
      previous: [first],
      rules: de,
      business: true,
      issuedOn: DateTime(2026, 6, 30),
      newDueDate: DateTime(2026, 7, 14),
      fee: const Money(1000),
      withInterest: true,
      withFlatFee: true,
    ).notice;
    expect(second.level, 2);
    expect(second.feesTotal, const Money(1000));
    expect(second.flatFee, const Money(4000));
    expect(second.interest.cents, greaterThan(0));
    expect(second.total, second.principal + second.costs);
    expect(second.text, contains('RE-2026-0007'));
    expect(second.text.toLowerCase(), isNot(contains('inkasso')));
  });

  group('Datenbank', () {
    late Database db;
    late Repositories repos;
    late int invoiceId;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      await db.insert('company_profile', {'id': 1, 'company_name': 'Test'});
      final customerId = await db.insert('customers', {'name': 'Kundin'});
      repos = Repositories(db);
      invoiceId = await repos.invoices.save(
        invoice().copyWith(customerId: customerId),
      );
    });

    tearDown(() => db.close());

    DunningNotice notice(int level) => DunningNotice(
      invoiceId: invoiceId,
      level: level,
      issuedOn: DateTime(2026, 6, 10),
      newDueDate: DateTime(2026, 6, 24),
      principal: const Money(100000),
      fee: const Money(1000),
      feesTotal: const Money(1000),
      interest: const Money(500),
      interestRateBp: 400,
      flatFee: const Money.zero(),
      text: 'Text',
      pdfSha256: 'abc',
    );

    test('Mahnung unveränderlich, nur Storno mit Begründung', () async {
      final id = await repos.dunning.insert(notice(2));
      expect(
        () =>
            db.update('dunning_notices', {'total_cents': 1}, where: 'id = $id'),
        throwsA(anything),
      );
      expect(() => repos.dunning.cancel(id, ' '), throwsArgumentError);
      await repos.dunning.cancel(id, 'Zahlung war schon da');
      final list = await repos.dunning.forInvoice(invoiceId);
      expect(list.single.isCancelled, isTrue);
      // Ein zweites Storno ist nicht möglich.
      expect(() => repos.dunning.cancel(id, 'nochmal'), throwsA(anything));
      expect(await repos.dunning.latestActive(), isEmpty);
    });

    test(
      'Zahlung mit Mahnkosten: getrennte, nicht steuerbare Einnahme',
      () async {
        await repos.dunning.insert(notice(2));
        await repos.invoices.markPaid(
          invoiceId,
          DateTime(2026, 6, 20),
          withDunningCosts: true,
        );
        final rows = await db.query(
          'receipts',
          where: 'dunning_invoice_id = ?',
          whereArgs: [invoiceId],
        );
        expect(rows.single['gross_cents'], 1500);
        expect(rows.single['vat_cents'], 0);
        expect(rows.single['description'], contains('nicht umsatzsteuerbar'));
      },
    );
  });

  test('Migration: Kunde mit UID wird Unternehmen', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 12,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );
    await db.insert('customers', {'name': 'GmbH', 'vat_id': 'ATU12345678'});
    await db.insert('customers', {'name': 'Privat'});
    await AppDatabase.upgradeSchema(db, 12, AppDatabase.schemaVersion);
    final rows = await db.query('customers', orderBy: 'id');
    expect(rows.map((r) => r['is_business']), [1, 0]);
    await db.close();
  });
}
