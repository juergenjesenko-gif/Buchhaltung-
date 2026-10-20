import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/booking_rule.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/booking_rule_split.dart';
import 'package:buchhaltung/services/booking_rule_templates.dart';
import 'package:buchhaltung/services/reports/annual_report.dart';
import 'package:buchhaltung/services/reports/booking_rule_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Buchungsregeln (FA-20.x, Entscheidung Auftraggeber 2026-10-20).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  final at = TaxProfile.austria.mixedUse;
  final de = TaxProfile.germany.mixedUse;

  BookingRule rule({
    int? id,
    int permille = 300,
    Set<int> categories = const {5},
    String supplier = '',
    DateTime? from,
    DateTime? to,
    BookingRuleRegistration registration = BookingRuleRegistration.all,
  }) => BookingRule(
    id: id,
    name: 'PKW',
    categoryIds: categories,
    supplier: supplier,
    registration: registration,
    businessPermille: permille,
    validFrom: from ?? DateTime(2026, 1, 1),
    validTo: to,
    comment: 'Fahrtenbuch',
  );

  BookingFacts facts({
    DateTime? date,
    int? category = 5,
    String counterparty = 'OMV Wien',
    int? registration,
    bool expense = true,
  }) => BookingFacts(
    date: date ?? DateTime(2026, 3, 1),
    isExpense: expense,
    categoryId: category,
    counterparty: counterparty,
    taxRegistrationId: registration,
  );

  group('Anteil', () {
    test('aus Fahrtenbuch und Fläche, kaufmännisch auf Promille', () {
      expect(BookingRule.shareFromBasis(3000000, 10000000), 300);
      expect(BookingRule.shareFromBasis(12000, 80000), 150);
      expect(BookingRule.shareFromBasis(1000, 3000), 333);
      expect(BookingRule.shareFromBasis(2000, 3000), 667);
      expect(BookingRule.shareFromBasis(1, 0), isNull);
      expect(BookingRule.shareFromBasis(5, 4), isNull);
      expect(BookingRule.shareFromBasis(null, 4), isNull);
    });

    test('Anzeige', () {
      expect(formatPermille(300), '30 %');
      expect(formatPermille(125), '12,5 %');
      expect(rule().shortLabel, 'PKW 30 % betrieblich');
    });

    test('Pflichtangaben', () {
      expect(rule().validate(), isEmpty);
      expect(rule(categories: {}).validate(), isNotEmpty);
      expect(rule(categories: {}, supplier: 'OMV').validate(), isEmpty);
      expect(
        rule(to: DateTime(2025, 1, 1)).validate(),
        contains('„Gültig bis“ liegt vor „Gültig ab“.'),
      );
      expect(rule().copyWith(comment: ' ').validate(), isNotEmpty);
    });
  });

  group('Aufteilung', () {
    List<VatLineAmounts> line(int net, int vat, [int p = 200]) => [
      (permille: p, net: Money(net), vat: Money(vat), gross: Money(net + vat)),
    ];

    test('Summen exakt, Restgröße privat', () {
      for (var c = -400; c <= 400; c += 7) {
        for (final p in [0, 1, 99, 100, 300, 333, 999, 1000]) {
          final s = BookingRuleSplit.of(
            lines: line(c, c ~/ 5),
            businessPermille: p,
            inputVatDeductible: true,
            rules: at,
          );
          expect(s.business + s.privatePart, Money(c));
        }
      }
    });

    test('Vorsteuer anteilig ab 10 % (AT und DE)', () {
      for (final r in [at, de]) {
        final s = BookingRuleSplit.of(
          lines: line(10001, 2000),
          businessPermille: 300,
          inputVatDeductible: true,
          rules: r,
        );
        expect(s.business, const Money(3000)); // 3000,3
        expect(s.privatePart, const Money(7001));
        expect(s.inputVatRemoved, const Money(1400));
        expect(s.vatAsExpense, const Money.zero());
      }
    });

    test('unter 10 % keine Vorsteuer, betrieblicher Teil wird Aufwand', () {
      final s = BookingRuleSplit.of(
        lines: line(10000, 2000),
        businessPermille: 50,
        inputVatDeductible: true,
        rules: de,
      );
      expect(s.inputVatRemoved, const Money(2000));
      expect(s.vatAsExpense, const Money(100));
    });

    test('Kleinunternehmer: Basis brutto, keine Vorsteuer', () {
      final s = BookingRuleSplit.of(
        lines: line(10000, 2000),
        businessPermille: 300,
        inputVatDeductible: false,
        rules: at,
      );
      expect(s.base, const Money(12000));
      expect(s.business, const Money(3600));
      expect(s.inputVatRemoved, const Money.zero());
    });

    test('je Steuersatzzeile gerundet', () {
      final s = BookingRuleSplit.of(
        lines: [
          (
            permille: 200,
            net: const Money(105),
            vat: const Money(21),
            gross: const Money(126),
          ),
          (
            permille: 100,
            net: const Money(105),
            vat: const Money(11),
            gross: const Money(116),
          ),
        ],
        businessPermille: 500,
        inputVatDeductible: true,
        rules: at,
      );
      expect(s.business, const Money(106)); // 53 + 53
      expect(s.inputVatRemovedByRate, {
        200: const Money(10),
        100: const Money(5),
      });
    });
  });

  group('Geltungsbereich', () {
    test('Kategorie, Lieferant, Gültigkeit, Steuerland', () {
      expect(rule().matches(facts()), isTrue);
      expect(rule().matches(facts(category: 6)), isFalse);
      expect(rule().matches(facts(expense: false)), isFalse);
      expect(rule(supplier: 'omv').matches(facts()), isTrue);
      expect(rule(supplier: 'BP').matches(facts()), isFalse);
      expect(rule().matches(facts(date: DateTime(2025, 12, 31))), isFalse);
      final bounded = rule(to: DateTime(2026, 6, 30));
      expect(bounded.matches(facts(date: DateTime(2026, 6, 30))), isTrue);
      expect(bounded.matches(facts(date: DateTime(2026, 7, 1))), isFalse);
      final home = rule(registration: BookingRuleRegistration.home);
      expect(home.matches(facts()), isTrue);
      expect(home.matches(facts(registration: 2)), isFalse);
    });

    test('die zuerst angelegte gewinnt, Ausnahme überspringt', () {
      final a = rule(id: 1, permille: 300);
      final b = rule(id: 2, permille: 500);
      expect(matchingRule([b, a], facts())!.id, 1);
      expect(matchingRule([b, a], facts(), excludedRuleIds: {1})!.id, 2);
      expect(matchingRule([a], facts(), excludedRuleIds: {1}), isNull);
    });

    test('Vorlagen füllen Kategorie und Zahlen vor', () {
      const cats = [
        ExpenseCategory(
          id: 9,
          name: 'Kfz-Kosten',
          direction: BookingDirection.expense,
        ),
      ];
      final car = BookingRuleTemplate.car.build(cats, DateTime(2026, 5, 2));
      expect(car.categoryIds, {9});
      expect(car.validate(), isEmpty);
      expect(
        templateForHelpTitle('Büro in der eigenen Wohnung'),
        BookingRuleTemplate.homeOffice,
      );
    });
  });

  group('Datenbank und Auswertung', () {
    Future<Database> open() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );

    Future<int> kfz(Database db) async =>
        (await db.query(
              'categories',
              where: 'name = ?',
              whereArgs: ['Kfz-Kosten'],
            )).single['id']!
            as int;

    Receipt fuel(int cat, {int day = 10}) => Receipt(
      date: DateTime(2026, 3, day),
      direction: BookingDirection.expense,
      description: 'Tanken',
      counterparty: 'OMV',
      net: const Money(10001),
      vat: const Money(2000),
      gross: const Money(12001),
      vatPermille: 200,
      categoryId: cat,
    );

    test('Upgrade von 30 legt die Tabellen an', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 30,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      await AppDatabase.upgradeSchema(db, 30, AppDatabase.schemaVersion);
      expect(await db.query('booking_rules'), isEmpty);
      await db.close();
    });

    test('Gewinn, Vorsteuer, Ausnahme, Verlauf, Bericht', () async {
      final db = await open();
      final repos = Repositories(db);
      final cat = await kfz(db);
      final r1 = await repos.receipts.save(fuel(cat));
      await repos.receipts.save(fuel(cat, day: 11));
      final saved = await repos.bookingRules.save(rule(categories: {cat}));

      Future<PeriodTotals> totals({bool vat = true}) => repos.receipts.totals(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        inputVatDeductible: vat,
        mixedUse: at,
      );

      var t = await totals();
      expect(t.rulePrivatePart, const Money(14002));
      expect(t.ruleInputVatRemoved, const Money(2800));
      expect(t.expenseVat, const Money(1200));
      expect(t.inputVatByRate[200], const Money(1200));
      expect(t.profit, const Money(-6000));

      // Ohne Regeln wie bisher.
      final plain = await repos.receipts.totals(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      expect(plain.expenseVat, const Money(4000));
      expect(plain.profit, const Money(-20002));

      // Kleinunternehmer: brutto.
      t = await totals(vat: false);
      expect(t.rulePrivatePart, const Money(16802));
      expect(t.profit, const Money(-7200));

      await repos.bookingRules.setExcluded(saved.id!, r1, true);
      t = await totals();
      expect(t.rulePrivatePart, const Money(7001));
      expect(await repos.bookingRules.exclusionsFor(r1), {saved.id});

      await repos.bookingRules.save(saved.copyWith(businessPermille: 400));
      final log = await repos.bookingRules.log(saved.id!);
      expect(log.first.text, startsWith('Angelegt: PKW'));
      expect(log.any((e) => e.text.contains('30 % → 40 %')), isTrue);
      await expectLater(
        db.update('booking_rule_log', {'text': 'x'}),
        throwsA(anything),
      );

      await repos.bookingRules.addAttachment(
        ruleId: saved.id!,
        filePath: 'belege/x.jpg',
        fileName: 'Fahrtenbuch.pdf',
        note: 'Jänner bis März',
      );
      final entries = await repos.bookingRules.report(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        inputVatDeductible: true,
        rules: at,
        categoryName: (_) => 'Kfz-Kosten',
      );
      expect(entries.single.sums.count, 1);
      expect(entries.single.sums.excludedCount, 1);
      expect(entries.single.attachmentText, contains('Jänner bis März'));
      final csv = bookingRulesCsv(entries);
      expect(csv, contains('Fahrtenbuch.pdf'));
      expect(csv, contains('ersetzt keine individuelle Beratung'));

      const profile = CompanyProfile(
        companyName: 'Test',
        country: Country.at,
        isSmallBusiness: false,
      );
      final data = AnnualReportData(
        profile: profile,
        periodLabel: '2026',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        totals: await totals(),
        categorySums: const [],
        categories: const [],
        assets: const [],
        openInvoices: const [],
        bookingRules: entries,
      );
      expect(
        data.balances.any(
          (b) => b.label == 'davon Privatanteile laut Buchungsregeln',
        ),
        isTrue,
      );
      final pdf = await AnnualReportPdf(data).build(ReportKind.trialBalance);
      expect(pdf.length, greaterThan(1000));
      await db.close();
    });
  });
}
