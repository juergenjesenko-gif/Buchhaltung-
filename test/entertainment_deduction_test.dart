import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/entertainment_deduction.dart';
import 'package:buchhaltung/services/export/exporters.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_classifier.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:buchhaltung/services/reports/annual_report.dart';
import 'package:buchhaltung/services/tax_office/vat_return_figures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Bewirtung mit Abzugsbeschränkung (FA-2.60, Lastenheft 14a).
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  final at = TaxProfile.austria.entertainment;
  final de = TaxProfile.germany.entertainment;

  group('Aufteilung', () {
    test('AT 50 %, DE 70 %, Summe exakt', () {
      final a = EntertainmentSplit.of(const Money(4201), at);
      expect(a.deductible, const Money(2101)); // 2100,5 aufgerundet
      expect(a.nonDeductible, const Money(2100));
      final d = EntertainmentSplit.of(const Money(4201), de);
      expect(d.deductible, const Money(2941)); // 2940,7
      expect(d.nonDeductible, const Money(1260));
      for (var c = -300; c <= 300; c++) {
        for (final r in [at, de]) {
          expect(EntertainmentSplit.of(Money(c), r).total, Money(c));
        }
      }
    });

    test('Gutschrift spiegelbildlich', () {
      final d = EntertainmentSplit.of(const Money(-4201), de);
      expect(d.deductible, const Money(-2941));
      expect(d.nonDeductible, const Money(-1260));
    });

    test('Vorsteuer in beiden Ländern voll, Nachweisfelder nur DE', () {
      expect(at.inputVatFull, isTrue);
      expect(de.inputVatFull, isTrue);
      expect(at.asksOccasion, isFalse);
      expect(de.asksOccasion, isTrue);
    });
  });

  group('Datenbank und Auswertung', () {
    Future<Database> open([int version = AppDatabase.schemaVersion]) =>
        databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: AppDatabase.createSchema,
            singleInstance: false,
          ),
        );

    Future<int> entertainmentId(Database db) async =>
        (await db.query(
              'categories',
              where: 'kind = ?',
              whereArgs: ['entertainment'],
            )).single['id']!
            as int;

    Receipt meal(int categoryId, int net, int vat, {int day = 10}) => Receipt(
      date: DateTime(2026, 10, day),
      direction: BookingDirection.expense,
      description: 'Geschäftsessen',
      net: Money(net),
      vat: Money(vat),
      gross: Money(net + vat),
      vatPermille: 100,
      categoryId: categoryId,
      entertainmentOccasion: 'Projektbesprechung',
      entertainmentParticipants: 'A. Huber, ich',
    );

    test('neue Datenbank hat genau eine Bewirtung mit Kennung', () async {
      final db = await open();
      final rows = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: ['Bewirtung'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['kind'], 'entertainment');
      await db.close();
    });

    test('Upgrade von 22 legt Bewirtung einmal an', () async {
      final db = await open(22);
      // Schema-22-Datenbank hat (wie die Startliste) bereits eine
      // „Bewirtung“ ohne Kennung; Upgrade setzt nur die Kennung.
      await AppDatabase.upgradeSchema(db, 22, AppDatabase.schemaVersion);
      final rows = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: ['Bewirtung'],
      );
      expect(rows, hasLength(1));
      expect(rows.single['kind'], 'entertainment');
      await db.close();
    });

    test('Upgrade ohne Bewirtung legt sie an', () async {
      final db = await open(22);
      await db.delete('categories', where: "name = 'Bewirtung'");
      await AppDatabase.upgradeSchema(db, 22, AppDatabase.schemaVersion);
      final rows = await db.query(
        'categories',
        where: "kind = 'entertainment'",
      );
      expect(rows.single['name'], 'Bewirtung');
      expect(rows.single['datev_account'], '4650');
      await db.close();
    });

    test('Anlass und Teilnehmer bleiben erhalten', () async {
      final db = await open();
      final repo = ReceiptRepository(db);
      final id = await repo.save(meal(await entertainmentId(db), 4201, 420));
      final loaded = (await repo.byId(id))!;
      expect(loaded.entertainmentOccasion, 'Projektbesprechung');
      expect(loaded.entertainmentParticipants, 'A. Huber, ich');
      await db.close();
    });

    for (final (label, rules, nd, ndSmall) in [
      // 4201 + 999 netto; brutto 4621 + 1099.
      ('AT', at, 2100 + 499, 2310 + 549),
      ('DE', de, 1260 + 300, 1386 + 330),
    ]) {
      test('$label: Regelbesteuerung und Kleinunternehmer', () async {
        final db = await open();
        final repo = ReceiptRepository(db);
        final cat = await entertainmentId(db);
        await repo.save(meal(cat, 4201, 420));
        await repo.save(meal(cat, 999, 100, day: 11));
        await repo.save(
          Receipt(
            date: DateTime(2026, 10, 12),
            direction: BookingDirection.income,
            description: 'Honorar',
            net: const Money(100000),
            vat: const Money(20000),
            gross: const Money(120000),
            vatPermille: 200,
          ),
        );
        final from = DateTime(2026, 10, 1);
        final to = DateTime(2026, 10, 31);

        final regular = await repo.totals(
          from: from,
          to: to,
          entertainment: rules,
        );
        expect(regular.entertainmentExpense, const Money(5200));
        expect(regular.entertainmentNonDeductible, Money(nd));
        expect(
          regular.entertainmentDeductible + regular.entertainmentNonDeductible,
          regular.entertainmentExpense,
        );
        // Vorsteuer voll.
        expect(regular.expenseVat, const Money(520));
        expect(regular.profit, Money(100000 - 5200 + nd));

        final small = await repo.totals(
          from: from,
          to: to,
          inputVatDeductible: false,
          entertainment: rules,
        );
        expect(small.entertainmentExpense, const Money(5720));
        expect(small.entertainmentNonDeductible, Money(ndSmall));
        expect(small.expenseVat, Money.zero());
        expect(small.profit, Money(100000 - 5720 + ndSmall));

        // Ohne Regeln (z. B. Profil fehlt) keine Kürzung.
        final plain = await repo.totals(from: from, to: to);
        expect(plain.entertainmentNonDeductible, Money.zero());
        await db.close();
      });
    }
  });

  group('Berichte und Exporte', () {
    const categories = [
      ExpenseCategory(
        id: 5,
        name: 'Bewirtung',
        direction: BookingDirection.expense,
        datevAccount: '4650',
        kind: ExpenseCategory.entertainmentKind,
      ),
    ];
    final receipt = Receipt(
      id: 9,
      date: DateTime(2026, 10, 10),
      direction: BookingDirection.expense,
      description: 'Geschäftsessen',
      net: const Money(4201),
      vat: const Money(420),
      gross: const Money(4621),
      vatPermille: 100,
      categoryId: 5,
      entertainmentOccasion: 'Projektbesprechung',
      entertainmentParticipants: 'A. Huber',
    );
    PeriodTotals totals(int nd) => PeriodTotals(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      incomeNet: const Money.zero(),
      incomeVat: const Money.zero(),
      incomeGross: const Money.zero(),
      expenseNet: const Money(4201),
      expenseVat: const Money(420),
      expenseGross: const Money(4621),
      incomeNetByRate: const {},
      inputVatByRate: const {100: Money(420)},
      entertainmentExpense: const Money(4201),
      entertainmentNonDeductible: Money(nd),
    );
    CompanyProfile profile(Country c) => CompanyProfile(
      companyName: 'Muster',
      country: c,
      isSmallBusiness: false,
    );
    Exporter exporter(Country c, int nd) => Exporter(
      profile: profile(c),
      receipts: [receipt],
      categories: categories,
      totals: totals(nd),
      period: Period.month(DateTime(2026, 10, 1)),
    );

    test('Belegliste: nicht abziehbarer Teil, Anlass, Teilnehmer', () {
      final csv = exporter(Country.de, 1260).build(ExportFormat.plainCsv);
      expect(csv.content, contains('12,60;Projektbesprechung;A. Huber'));
      expect(csv.content, contains('Bewirtung nicht abziehbar'));
      // Ergebnis = -42,01 + 12,60
      expect(csv.content, contains('-29,41'));
    });

    test('DATEV: volle Buchung plus Umbuchung auf 4654 ohne Steuer', () {
      final lines = exporter(
        Country.de,
        1260,
      ).build(ExportFormat.datev).content.split('\r\n');
      expect(lines.where((l) => l.startsWith('46,21;S')), hasLength(1));
      final rebook = lines.singleWhere((l) => l.startsWith('12,60;S'));
      expect(rebook, contains(';4654;4650;40;'));
    });

    test('Kennzahlen und Saldenliste zeigen den Teil', () {
      final t = totals(2100);
      final annual = VatReturnCalculator.annual(
        totals: t,
        tax: TaxProfile.austria,
        smallBusiness: false,
      );
      expect(
        annual.where((l) => l.label.contains('Bewirtung')).single.amount,
        const Money(2100),
      );
      expect(annual.last.amount, t.profit);
      final report = AnnualReportData(
        profile: profile(Country.at),
        periodLabel: '2026',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        totals: t,
        categorySums: const [],
        categories: categories,
        assets: const [],
        openInvoices: const [],
      );
      expect(
        report.balances
            .where((b) => b.label.contains('Bewirtung nicht abziehbar'))
            .single
            .amount,
        const Money(2100),
      );
    });
  });

  test('Belegerkennung schlägt Bewirtung für Restaurants vor', () {
    final c = ReceiptClassifier.classify(const [
      'Gasthaus Zur Post',
      'Tisch: 4',
      '2 Schnitzel 32,00',
    ], const ReceiptScanResult(currency: Detected('EUR', 100)));
    expect(c.branch, ReceiptBranch.restaurant);
    expect(c.categoryName, 'Bewirtung');
  });
}
