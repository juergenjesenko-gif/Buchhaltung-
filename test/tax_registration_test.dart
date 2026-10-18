import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/deadline_rule.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/platform_import.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/domain/tax_registration.dart';
import 'package:buchhaltung/features/settings/tax_registration_screen.dart';
import 'package:buchhaltung/services/deadline_calculator.dart';
import 'package:buchhaltung/services/platform_import/platform_import_plan.dart';
import 'package:buchhaltung/services/tax_office/vat_return_figures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Steuerliche Registrierungen in weiteren Ländern (FA-18.x, Lastenheft
/// L-30). Beispiel: österreichischer Kleinunternehmer mit deutscher
/// USt-Registrierung wegen Amazon-FBA-Lager.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  const home = CompanyProfile(
    companyName: 'Spirits by JeNiBarb e.U.',
    country: Country.at,
    isSmallBusiness: true,
  );
  const de = TaxRegistration(id: 1, country: Country.de);

  DateTime day(int y, int m, int d) => DateTime(y, m, d);
  List<(String, DateTime)> pairs(List<Deadline> l) => [
    for (final d in l) (d.label, d.date),
  ];

  group('Termine je Registrierung (FA-18.5)', () {
    test('DE monatlich: UStVA am 10. des Folgemonats, Länderkürzel', () {
      final l = DeadlineCalculator.forRegistration(
        registration: de,
        year: 2027,
      );
      expect(pairs(l), contains(('DE · UStVA Januar 2027', day(2027, 2, 10))));
      expect(l.where((d) => d.label.contains('UStVA')), hasLength(12));
      // 31.07.2028 ist ein Montag; Jahreserklärung 2026 → 31.07.2027 Sa → Mo.
      final y2026 = DeadlineCalculator.forRegistration(
        registration: de,
        year: 2026,
      );
      expect(
        pairs(y2026),
        contains(('DE · USt-Jahreserklärung 2026', day(2027, 8, 2))),
      );
    });

    test('DE Dauerfristverlängerung: einen Monat später', () {
      final l = DeadlineCalculator.forRegistration(
        registration: de.copyWith(permanentExtension: true),
        year: 2027,
      );
      expect(pairs(l), contains(('DE · UStVA Januar 2027', day(2027, 3, 10))));
    });

    test('DE vierteljährlich mit Wochenende: 10.05.2026 So → Mo', () {
      final l = DeadlineCalculator.forRegistration(
        registration: de.copyWith(
          interval: FilingInterval.quarterly,
          permanentExtension: true,
        ),
        year: 2026,
      );
      expect(pairs(l), contains(('DE · UStVA Q1/2026', day(2026, 5, 11))));
      expect(l.where((d) => d.label.contains('UStVA')), hasLength(4));
    });

    test('AT-Registrierung: UVA am 15. des zweitfolgenden Monats', () {
      const at = TaxRegistration(
        id: 2,
        country: Country.at,
        interval: FilingInterval.quarterly,
      );
      final l = DeadlineCalculator.forRegistration(
        registration: at,
        year: 2026,
      );
      // Q1/2026 → 15.05.2026 (Freitag).
      expect(pairs(l), contains(('AT · UVA Q1/2026', day(2026, 5, 15))));
      expect(
        l.map((d) => d.label),
        contains('AT · USt-Jahreserklärung (U1) 2026'),
      );
    });

    test('nur jährlich: keine Voranmeldung, nur Jahreserklärung', () {
      final l = DeadlineCalculator.forRegistration(
        registration: de.copyWith(interval: FilingInterval.annual),
        year: 2026,
      );
      expect(l.map((d) => d.label), ['DE · USt-Jahreserklärung 2026']);
    });

    test('keine bzw. EU-KU: keine Termine im anderen Land', () {
      expect(
        DeadlineCalculator.forRegistration(
          registration: de.copyWith(interval: FilingInterval.none),
          year: 2026,
        ),
        isEmpty,
      );
      expect(
        DeadlineCalculator.forRegistration(
          registration: de.copyWith(scheme: VatScheme.euSmallBusiness),
          year: 2026,
        ),
        isEmpty,
      );
    });

    test('Beginn und Ende begrenzen die Zeiträume', () {
      final l = DeadlineCalculator.forRegistration(
        registration: de.copyWith(
          validFrom: day(2026, 3, 1),
          validTo: day(2026, 5, 31),
        ),
        year: 2026,
      );
      expect(l.where((d) => d.label.contains('UStVA')).map((d) => d.label), [
        'DE · UStVA März 2026',
        'DE · UStVA April 2026',
        'DE · UStVA Mai 2026',
      ]);
    });

    test('EU-KU-Verfahren: Meldung im Heimatland vierteljährlich', () {
      final l = DeadlineCalculator.forYear(
        profile: home,
        year: 2026,
        interval: VatReturnInterval.quarterly,
        registrations: [de.copyWith(scheme: VatScheme.euSmallBusiness)],
      );
      expect(pairs(l), contains(('EU-KU-Meldung Q1/2026', day(2026, 4, 30))));
      // AT-Kleinunternehmer ohne RC: keine UVA (FA-18.7).
      expect(l.where((d) => d.label.startsWith('UVA')), isEmpty);
    });

    test('OSS: vierteljährlich bis Ende des Folgemonats, auch bei UVA '
        'monatlich', () {
      final l = DeadlineCalculator.forYear(
        profile: home.copyWith(ossParticipant: true, isSmallBusiness: false),
        year: 2026,
        interval: VatReturnInterval.monthly,
      );
      final oss = l.where((d) => d.label.startsWith('OSS')).toList();
      expect(oss, hasLength(4));
      expect(pairs(oss).first, ('OSS-Erklärung Q1/2026', day(2026, 4, 30)));
    });

    test('Termin-Box mischt Heimat und Registrierung', () {
      final o = DeadlineCalculator.upcoming(
        profile: home,
        today: day(2026, 10, 18),
        interval: VatReturnInterval.quarterly,
        registrations: const [de],
        count: 10,
      );
      expect(
        o.upcoming.map((d) => d.label),
        contains('DE · UStVA Oktober 2026'),
      );
    });

    test('Bedingungen der Registrierung gelten nie fürs Heimatprofil', () {
      for (final c in Country.values) {
        for (final r in c.taxProfile.deadlineRules) {
          expect(
            r.condition,
            isNot(
              anyOf(
                DeadlineCondition.registrationReturn,
                DeadlineCondition.registrationAnnual,
              ),
            ),
          );
        }
      }
    });
  });

  group('Datenbank und Kennzahlen je Registrierung (FA-18.4)', () {
    Future<Database> open() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: AppDatabase.schemaVersion,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    );

    test('Migration 26 → 27 ergänzt Tabelle und Spalten', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 26,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      await AppDatabase.upgradeSchema(db, 26, 27);
      Future<List<String>> cols(String t) async => [
        for (final r in await db.rawQuery('PRAGMA table_info($t)'))
          r['name'] as String,
      ];
      expect(await cols('receipts'), contains('tax_registration_id'));
      expect(await cols('company_profile'), contains('oss_participant'));
      expect(await cols('tax_registrations'), contains('filing_interval'));
      await db.close();
    });

    test('Speichern, Laden, Löschen nur ohne Belege', () async {
      final db = await open();
      final repo = TaxRegistrationRepository(db);
      final id = await repo.save(
        TaxRegistration(
          country: Country.de,
          vatId: 'DE123456789',
          taxOffice: 'Finanzamt München',
          validFrom: day(2026, 1, 1),
        ),
      );
      final loaded = (await repo.all()).single;
      expect(loaded.id, id);
      expect(loaded.country, Country.de);
      expect(loaded.validFrom, day(2026, 1, 1));
      await ReceiptRepository(db).save(
        Receipt(
          date: day(2026, 3, 1),
          direction: BookingDirection.income,
          description: 'x',
          net: const Money(1000),
          vat: const Money(190),
          gross: const Money(1190),
          vatPermille: 190,
          taxRegistrationId: id,
        ),
      );
      expect(await repo.delete(id), isFalse);
      await db.close();
    });

    test(
      'UStVA DE nur aus DE-Belegen, Heimat ohne sie, E1a über alle',
      () async {
        final db = await open();
        final regId = await TaxRegistrationRepository(
          db,
        ).save(const TaxRegistration(country: Country.de));
        final receipts = ReceiptRepository(db);
        Future<void> book(
          BookingDirection dir,
          int net,
          int vat,
          int permille, {
          int? reg,
          bool rc = false,
        }) => receipts.save(
          Receipt(
            date: day(2026, 3, 15),
            direction: dir,
            description: 'x',
            net: Money(net),
            vat: Money(vat),
            gross: Money(net + vat),
            vatPermille: permille,
            taxRegistrationId: reg,
            reverseCharge: rc,
          ),
        );
        // DE: Verkauf aus dem FBA-Lager 19 %, deutsche Ausgabe mit Vorsteuer.
        await book(BookingDirection.income, 10000, 1900, 190, reg: regId);
        await book(BookingDirection.expense, 1000, 190, 190, reg: regId);
        // AT-Heimat (Kleinunternehmer): steuerfreier Verkauf, RC-Gebühr.
        await book(BookingDirection.income, 5000, 0, 0);
        await book(BookingDirection.expense, 2000, 0, 0, rc: true);

        final from = day(2026, 3, 1);
        final to = day(2026, 3, 31);
        final deTotals = await receipts.totals(
          from: from,
          to: to,
          reverseChargePermille: 190,
          scope: RegistrationScope.of(regId),
        );
        final deFig = VatReturnCalculator.build(
          totals: deTotals,
          tax: Country.de.taxProfile,
          smallBusiness: false,
        );
        expect(deFig.required, isTrue);
        expect(deFig.amountOf('81'), const Money(10000));
        expect(deFig.amountOf('66'), const Money(190));
        expect(deFig.payable, const Money(1710));
        expect(deTotals.hasReverseCharge, isFalse);

        final atTotals = await receipts.totals(
          from: from,
          to: to,
          inputVatDeductible: false,
          reverseChargePermille: 200,
          scope: RegistrationScope.home,
        );
        final atFig = VatReturnCalculator.build(
          totals: atTotals,
          tax: Country.at.taxProfile,
          smallBusiness: true,
        );
        // AT-KU: U30 nur wegen Reverse Charge (FA-18.7).
        expect(atFig.required, isTrue);
        expect(atTotals.incomeNet, const Money(5000));
        expect(atTotals.reverseChargeVat, const Money(400));

        final year = atTotals + deTotals;
        expect(year.incomeNet, const Money(15000));
        expect(year.profit, const Money(15000 - 2000 - 1000));
        // Heimatgrenze zählt nur Heimatumsätze (P-S70).
        expect(
          await receipts.turnoverForYear(2026, includeVat: true),
          const Money(5000),
        );
        await db.close();
      },
    );
  });

  group('Plattformimport ordnet das Steuerland zu (FA-18.9)', () {
    PlatformImportFile file(List<PlatformEntry> entries) => PlatformImportFile(
      format: PlatformFormat.amazonSettlementV2,
      entries: entries,
    );
    PlatformEntry sale(
      String id,
      int cents, {
      String? dest,
      bool fba = true,
      String? shipFrom,
      int tax = 0,
    }) => PlatformEntry(
      externalId: id,
      date: day(2026, 3, 10),
      kind: PlatformEntryKind.sale,
      amount: Money(cents),
      tax: Money(tax),
      orderRef: id,
      destinationCountry: dest,
      fulfilledByPlatform: fba,
      shipFromCountry: shipFrom,
    );

    test('FBA auf amazon.de mit DE-Registrierung → DE, 19 %', () {
      final plan = PlatformImportPlanner.plan(
        file: file([
          sale('a', 11900, dest: 'DE'),
          sale('b', 3000, dest: 'AT', fba: false),
        ]),
        knownIds: const {},
        country: Country.at,
        isSmallBusiness: true,
        registrations: const [de],
      );
      final income = plan.drafts
          .where((d) => d.receipt.direction == BookingDirection.income)
          .toList();
      expect(income, hasLength(2));
      final deDraft = income.firstWhere(
        (d) => d.receipt.taxRegistrationId == 1,
      );
      expect(deDraft.receipt.vatPermille, 190);
      expect(deDraft.receipt.vat, const Money(1900));
      expect(deDraft.receipt.description, contains('(DE)'));
      final atDraft = income.firstWhere(
        (d) => d.receipt.taxRegistrationId == null,
      );
      expect(atDraft.receipt.vat, const Money.zero());
      expect(atDraft.receipt.gross, const Money(3000));
      expect(plan.warnings.join(' '), contains('Lager dort angenommen'));
    });

    test('Abgangsland aus dem Bericht hat Vorrang; Fernverkauf-Hinweis', () {
      final plan = PlatformImportPlanner.plan(
        file: file([sale('a', 11900, dest: 'FR', shipFrom: 'DE', tax: 1900)]),
        knownIds: const {},
        country: Country.at,
        isSmallBusiness: true,
        registrations: const [de],
      );
      final income = plan.drafts.single;
      expect(income.receipt.taxRegistrationId, 1);
      expect(plan.warnings.join(' '), contains('Fernverkauf'));
    });

    test('ohne Registrierung bleibt alles Heimat', () {
      final plan = PlatformImportPlanner.plan(
        file: file([sale('a', 11900, dest: 'DE')]),
        knownIds: const {},
        country: Country.at,
        isSmallBusiness: true,
      );
      expect(plan.drafts.single.receipt.taxRegistrationId, isNull);
      expect(plan.warnings.join(' '), contains('Pan-EU'));
    });

    test('Registrierung außerhalb Beginn/Ende zählt nicht', () {
      final plan = PlatformImportPlanner.plan(
        file: file([sale('a', 11900, dest: 'DE')]),
        knownIds: const {},
        country: Country.at,
        isSmallBusiness: true,
        registrations: [de.copyWith(validFrom: day(2026, 6, 1))],
      );
      expect(plan.drafts.single.receipt.taxRegistrationId, isNull);
    });
  });

  group('Oberfläche (UX-Instanz)', () {
    Future<AppState> pump(WidgetTester tester, Widget child) async {
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
      AppDatabase.instance.overrideDatabaseForTesting(db!);
      await tester.runAsync(
        () => db.insert('company_profile', {
          'id': 1,
          'company_name': 'Test',
          'is_small_business': 1,
          'country_code': 'AT',
        }),
      );
      final state = AppState(Repositories(db));
      await tester.runAsync(state.reload);
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(body: ListView(children: [child])),
          ),
        ),
      );
      await tester.pump();
      return state;
    }

    testWidgets('„Land hinzufügen“ ≥ 56 dp, Länderliste ≥ 56 dp, '
        'DE wählbar, andere „bald“', (tester) async {
      await pump(tester, const TaxRegistrationsSection());
      final add = find.byKey(const Key('registration-add'));
      expect(tester.getSize(add).height, greaterThanOrEqualTo(56));
      await tester.tap(add);
      await tester.pumpAndSettle();
      final deTile = find.byKey(const Key('registration-country-DE'));
      expect(deTile, findsOneWidget);
      expect(tester.getSize(deTile).height, greaterThanOrEqualTo(56));
      expect(find.byKey(const Key('registration-country-AT')), findsNothing);
      expect(find.text('bald'), findsWidgets);
      await tester.tap(deTile);
      await tester.pumpAndSettle();
      // Formular mit Finanzamt-Vorschlag für AT-Unternehmen.
      final office = tester.widget<TextFormField>(
        find.byKey(const Key('registration-tax-office')),
      );
      expect(office.controller!.text, 'Finanzamt München');
      expect(
        tester.getSize(find.byKey(const Key('registration-save'))).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('UID mit falschem Land wird abgelehnt', (tester) async {
      await pump(
        tester,
        const SizedBox(
          height: 1200,
          child: TaxRegistrationScreen(
            registration: TaxRegistration(country: Country.de),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('registration-vat-id')),
        'ATU12345675',
      );
      await tester.tap(find.byKey(const Key('registration-save')));
      await tester.pump();
      expect(find.textContaining('DE beginnen'), findsOneWidget);
    });
  });
}
