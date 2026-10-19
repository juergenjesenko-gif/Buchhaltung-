import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/deadline_rule.dart';
import 'package:buchhaltung/domain/levy_rules.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/deadline_calculator.dart';
import 'package:buchhaltung/services/levies/levy_estimator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Abgaben & Rücklagen (FA-19.x, Lastenheft 5.31).
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  final at = TaxProfile.austria.levies;
  final de = TaxProfile.germany.levies;
  Money eur(int e) => Money(e * 100);

  group('Einkommensteuertarif AT (§ 33 EStG 1988)', () {
    test('2026: 40.000 € → 7.447,20 € (Beispiel usp.gv.at)', () {
      expect(at.tariffFor(2026).taxOn(eur(40000)), const Money(744720));
    });
    test('2025: 40.000 € → 7.593,10 €', () {
      expect(at.tariffFor(2025).taxOn(eur(40000)), const Money(759310));
    });
    test('bis zur ersten Stufe steuerfrei, Spitze 55 %', () {
      expect(at.tariffFor(2026).taxOn(eur(13539)), const Money.zero());
      final million = at.tariffFor(2026).taxOn(eur(1000000));
      expect(at.tariffFor(2026).taxOn(eur(1000100)), million + eur(55));
    });
    test('späteres Jahr nutzt den jüngsten Tarif', () {
      expect(at.tariffFor(2027), same(at.tariffFor(2026)));
      expect(at.tariffFor(2020), same(at.tariffFor(2025)));
    });
  });

  group('Einkommensteuertarif DE (§ 32a EStG, Grundtabelle)', () {
    final t26 = de.tariffFor(2026);
    final t25 = de.tariffFor(2025);
    test('Grundfreibetrag 2026 12.348 €, 2025 12.096 €', () {
      expect(t26.taxOn(eur(12348)), const Money.zero());
      expect(t25.taxOn(eur(12096)), const Money.zero());
      expect(t26.taxOn(eur(12349)), const Money.zero()); // < 1 €
    });
    test('Werte je Zone 2026', () {
      expect(t26.taxOn(eur(15000)), eur(435));
      expect(t26.taxOn(eur(30000)), eur(4217));
      expect(t26.taxOn(eur(50000)), eur(10548));
      expect(t26.taxOn(eur(100000)), eur(30864));
      expect(t26.taxOn(eur(300000)), eur(115529));
    });
    test('Werte je Zone 2025', () {
      expect(t25.taxOn(eur(15000)), eur(485));
      expect(t25.taxOn(eur(50000)), eur(10691));
      expect(t25.taxOn(eur(100000)), eur(31088));
    });
    test('stetig an den Zonengrenzen 2026', () {
      expect(t26.taxOn(eur(17799)), eur(1034));
      expect(t26.taxOn(eur(17800)), eur(1035));
      expect(t26.taxOn(eur(69878)), eur(18213));
      expect(t26.taxOn(eur(69879)), eur(18213));
    });
    test('Cent unter vollen Euro werden abgerundet', () {
      expect(t26.taxOn(const Money(3000099)), eur(4217));
    });
  });

  group('SVS (GSVG)', () {
    final si = at.socialInsurance!;
    test('Mindestbeitragsgrundlage bei kleinem Gewinn', () {
      // 6.613,20 × (18,5 + 6,8 + 1,53) % + 12 × 12,95 €
      // = 1.223,44 + 449,70 + 101,18 + 155,40
      expect(
        LevyEstimator.socialInsurance(si, profitBeforeSvs: eur(2000)),
        const Money(122344 + 44970 + 10118 + 15540),
      );
    });
    test('Höchstbeitragsgrundlage deckelt', () {
      final max = LevyEstimator.socialInsurance(
        si,
        profitBeforeSvs: si.maxBaseYear,
      );
      expect(
        LevyEstimator.socialInsurance(si, profitBeforeSvs: eur(500000)),
        max,
      );
      // 97.020 × 26,83 % + 155,40
      expect(max, const Money(1794870 + 659736 + 148441 + 15540));
    });
    test('Ausnahme Kleinunternehmerin: nur Unfallversicherung', () {
      expect(
        LevyEstimator.socialInsurance(
          si,
          profitBeforeSvs: eur(5000),
          exempt: true,
        ),
        const Money(15540),
      );
    });
    test('Gewinnfreibetrag 15 % bis 33.000 €', () {
      expect(at.profitAllowance!.of(eur(20000)), eur(3000));
      expect(at.profitAllowance!.of(eur(80000)), eur(4950));
    });
    test('Schätzung AT: SVS mindert den Gewinn, Hinzurechnung', () {
      final e = LevyEstimator.estimate(
        at,
        LevyInput(
          year: 2026,
          monthsElapsed: 6,
          // halbes Jahr: Gewinn 15.000 nach bereits gebuchten 2.000 SVS
          profitToDate: eur(15000),
          turnoverToDate: eur(30000),
          socialInsurancePaid: eur(2000),
          incomeTaxPaid: eur(500),
        ),
        const LevySettings(),
      );
      expect(e.projectedProfit, eur(34000));
      final svs = LevyEstimator.socialInsurance(
        at.socialInsurance!,
        profitBeforeSvs: eur(34000),
      );
      expect(e.lines.first.year, svs);
      final profit = eur(34000) - svs;
      final taxable = profit - at.profitAllowance!.of(profit);
      expect(e.taxableIncome, taxable);
      expect(e.lines[1].year, at.tariffFor(2026).taxOn(taxable));
      expect(e.lines[1].paid, eur(500));
      expect(e.remainingMonths, 7);
      expect(e.monthlyReserve.cents % 100, 0);
    });
    test('erste drei Jahre: Hinweis auf Nachbemessung', () {
      final e = LevyEstimator.estimate(
        at,
        LevyInput(
          year: 2026,
          monthsElapsed: 12,
          profitToDate: eur(30000),
          turnoverToDate: eur(40000),
          foundingYear: 2025,
        ),
        const LevySettings(),
      );
      expect(e.lines.first.note, contains('Nachbemessung'));
    });
    test('Kleinunternehmer-Ausnahme wird vorgeschlagen', () {
      final e = LevyEstimator.estimate(
        at,
        LevyInput(
          year: 2026,
          monthsElapsed: 12,
          profitToDate: eur(5000),
          turnoverToDate: eur(15000),
        ),
        const LevySettings(),
      );
      expect(e.hints.first, contains('§ 4 Abs 1 Z 7 GSVG'));
    });
  });

  group('Gewerbesteuer und Zuschläge DE', () {
    final tt = de.tradeTax!;
    test('Freibetrag 24.500 €, Abrundung auf 100 €, Messzahl 3,5 %', () {
      expect(tt.baseAmount(eur(24000)), const Money.zero());
      // 60.099 → 60.000 − 24.500 = 35.500 × 3,5 % = 1.242,50
      expect(tt.baseAmount(const Money(6009999)), const Money(124250));
    });
    test('Schätzung: GewSt 400 %, § 35 Anrechnung 4,0-fach', () {
      final e = LevyEstimator.estimate(
        de,
        LevyInput(
          year: 2026,
          monthsElapsed: 12,
          profitToDate: eur(60000),
          turnoverToDate: eur(90000),
        ),
        const LevySettings(),
      );
      final gewst = e.lines.firstWhere((l) => l.key == 'tradeTax');
      expect(gewst.year, const Money(497000)); // 1.242,50 × 400 %
      final est = e.lines.firstWhere((l) => l.key == 'incomeTax');
      // 60.000 → 14.019 € Tarif minus 4.970 € Anrechnung (Deckel = GewSt)
      expect(est.year, de.tariffFor(2026).taxOn(eur(60000)) - eur(4970));
    });
    test('Hebesatz unter 400 %: Anrechnung höchstens tatsächliche GewSt', () {
      final e = LevyEstimator.estimate(
        de,
        LevyInput(
          year: 2026,
          monthsElapsed: 12,
          profitToDate: eur(60000),
          turnoverToDate: eur(90000),
        ),
        const LevySettings(tradeTaxMultiplierPercent: 300),
      );
      final gewst = e.lines.firstWhere((l) => l.key == 'tradeTax').year;
      final est = e.lines.firstWhere((l) => l.key == 'incomeTax').year;
      expect(gewst, const Money(372750));
      expect(est, de.tariffFor(2026).taxOn(eur(60000)) - gewst);
    });
    test('Freiberuflerin: keine Gewerbesteuer', () {
      final e = LevyEstimator.estimate(
        de,
        LevyInput(
          year: 2026,
          monthsElapsed: 12,
          profitToDate: eur(60000),
          turnoverToDate: eur(90000),
          legalFormFreelancer: true,
        ),
        const LevySettings(),
      );
      expect(e.lines.any((l) => l.key == 'tradeTax'), isFalse);
    });
    test('Soli: Freigrenze 20.350 €, Milderungszone 11,9 %', () {
      final s = de.surcharges!;
      expect(s.soliOn(eur(20350)), const Money.zero());
      expect(s.soliOn(eur(21350)), const Money(11900)); // 11,9 % × 1.000
      expect(s.soliOn(eur(100000)), const Money(550000)); // voll 5,5 %
    });
    test('Kirchensteuer 8 % in Bayern, sonst 9 %; KV mindert zvE', () {
      LevyEstimate run(String state) => LevyEstimator.estimate(
        de,
        LevyInput(
          year: 2026,
          monthsElapsed: 12,
          profitToDate: eur(40000),
          turnoverToDate: eur(50000),
          federalState: state,
          legalFormFreelancer: true,
        ),
        const LevySettings(
          churchTax: true,
          healthInsuranceMonthly: Money(50000),
        ),
      );
      final by = run('BY');
      final est = de.tariffFor(2026).taxOn(eur(34000));
      expect(by.taxableIncome, eur(34000));
      expect(
        by.lines.firstWhere((l) => l.key == 'churchTax').year,
        Money(est.cents * 8 ~/ 100),
      );
      expect(
        run('NW').lines.firstWhere((l) => l.key == 'churchTax').year,
        Money(est.cents * 9 ~/ 100),
      );
    });
  });

  group('Termine (Termin-Box)', () {
    test('AT SVS Ende Feb/Mai/Aug/Nov, ESt 15.2./15.5./15.8./15.11.', () {
      final profile = CompanyProfile(
        companyName: 'Test',
        country: Country.at,
        svsInsured: true,
        hasTaxAdvisor: true,
      );
      final d = DeadlineCalculator.forYear(
        profile: profile,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      );
      final est = d
          .where((x) => x.label.startsWith('ESt-Vorauszahlung'))
          .toList();
      expect(est.map((x) => '${x.date.day}.${x.date.month}'), [
        '16.2', // 15.2.2026 ist Sonntag → Montag (§ 108 Abs 3 BAO)
        '15.5',
        '17.8', // 15.8. Feiertag (Samstag) → Montag
        '16.11', // 15.11. Sonntag
      ]);
      final svs = d.where((x) => x.label.startsWith('SVS-Beitrag')).toList();
      expect(svs.map((x) => '${x.date.day}.${x.date.month}'), [
        '28.2',
        '31.5',
        '31.8',
        '30.11',
      ]);
    });
    test('DE ESt-Vorauszahlung 10.3./10.6./10.9./10.12.', () {
      final profile = CompanyProfile(
        companyName: 'Test',
        country: Country.de,
        hasTaxAdvisor: true,
      );
      final d = DeadlineCalculator.forYear(
        profile: profile,
        year: 2026,
        interval: VatReturnInterval.quarterly,
      ).where((x) => x.label.startsWith('ESt-Vorauszahlung'));
      expect(d.map((x) => x.date.month), [3, 6, 9, 12]);
    });
  });

  group('Einnahmen-Ausgaben-Rechnung', () {
    Future<Database> open() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );

    Future<void> book(Repositories r, String category, int cents) async {
      final id = (await r.categories.all())
          .firstWhere((c) => c.name == category)
          .id;
      await r.receipts.save(
        Receipt(
          date: DateTime(2026, 5, 10),
          direction: BookingDirection.expense,
          description: category,
          net: Money(cents),
          vat: const Money.zero(),
          gross: Money(cents),
          vatPermille: 0,
          categoryId: id,
        ),
      );
    }

    test('Abgabenkategorien mit Kennung angelegt', () async {
      final db = await open();
      final kinds = {
        for (final r in await db.query(
          'categories',
          where: 'kind IS NOT NULL AND kind <> ?',
          whereArgs: ['entertainment'],
        ))
          r['name']: r['kind'],
      };
      expect(kinds, {
        'Sozialversicherung': LevyKind.socialInsurance,
        'Einkommensteuer-Vorauszahlung': LevyKind.incomeTax,
        'Gewerbesteuer': LevyKind.tradeTax,
      });
      await db.close();
    });

    test('Upgrade von 28 legt Kategorien und Einstellungen an', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 28,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      await db.delete('categories', where: "name = 'Gewerbesteuer'");
      await AppDatabase.upgradeSchema(db, 28, AppDatabase.schemaVersion);
      final rows = await db.query(
        'categories',
        where: "name IN ('Sozialversicherung', 'Gewerbesteuer')",
      );
      expect(rows.map((r) => r['kind']).toSet(), {
        LevyKind.socialInsurance,
        LevyKind.tradeTax,
      });
      final repo = LevySettingsRepository(db);
      await repo.save(const LevySettings(churchTax: true));
      expect((await repo.load()).churchTax, isTrue);
      await db.close();
    });

    test('AT: SVS ist Betriebsausgabe, ESt privat', () async {
      final db = await open();
      final r = Repositories(db);
      await book(r, 'Sozialversicherung', 48243);
      await book(r, 'Einkommensteuer-Vorauszahlung', 15000);
      final t = await r.receipts.totals(
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
        nonDeductibleKinds: at.nonDeductibleKinds,
      );
      expect(t.profit, const Money(-48243));
      expect(t.nonDeductibleLevies, const Money(15000));
      final paid = await r.receipts.levyPayments(
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
      );
      expect(paid[LevyKind.socialInsurance], const Money(48243));
      expect(paid[LevyKind.incomeTax], const Money(15000));
      await db.close();
    });

    test('DE: KV, ESt und Gewerbesteuer mindern den Gewinn nicht', () async {
      final db = await open();
      final r = Repositories(db);
      await book(r, 'Sozialversicherung', 50000);
      await book(r, 'Einkommensteuer-Vorauszahlung', 15000);
      await book(r, 'Gewerbesteuer', 20000);
      final t = await r.receipts.totals(
        from: DateTime(2026),
        to: DateTime(2026, 12, 31),
        nonDeductibleKinds: de.nonDeductibleKinds,
      );
      expect(t.profit, const Money.zero());
      await db.close();
    });
  });
}
