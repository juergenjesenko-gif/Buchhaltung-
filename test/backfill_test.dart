import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/dashboard/backfill_section.dart';
import 'package:buchhaltung/features/dashboard/dashboard_screen.dart';
import 'package:buchhaltung/features/receipts/receipt_edit_screen.dart';
import 'package:buchhaltung/services/turnover_basis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// FA-4.16: Rechnungen vor dem App-Start nachtragen, ohne doppelt zu zählen.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  final start = DateTime(2026, 7, 1);

  group('TurnoverBasis.forYear mit Nachträgen', () {
    YearTurnover year({
      int receipts = 0,
      int backfilled = 0,
      int? opening = 10000,
      bool confirmed = false,
    }) => TurnoverBasis.forYear(
      year: 2026,
      fromReceipts: Money(receipts),
      opening: opening == null ? null : Money(opening),
      trackingStart: start,
      backfilled: Money(backfilled),
      confirmedComplete: confirmed,
    );

    test('Nachtrag ersetzt die Schätzung statt sie zu verdoppeln', () {
      // 3.000 nachgetragen (in den Belegen enthalten) + 5.000 danach.
      final t = year(receipts: 8000, backfilled: 3000);
      expect(t.amount, const Money(15000)); // 8.000 + Rest 7.000
      expect(t.estimatedRest, const Money(7000));
      expect(t.isComplete, isTrue);
    });

    test('Nachtrag über der Schätzung: Rest 0, nie negativ', () {
      final t = year(receipts: 12000, backfilled: 12000);
      expect(t.estimatedRest, const Money.zero());
      expect(t.amount, const Money(12000));
    });

    test('Bestätigung „vollständig“ ignoriert die Schätzung', () {
      final t = year(receipts: 4000, backfilled: 2000, confirmed: true);
      expect(t.amount, const Money(4000));
      expect(t.estimatedRest, const Money.zero());
      expect(t.isComplete, isTrue);
    });

    test('voll erfasstes Jahr ignoriert Eröffnungswert und Nachtrag', () {
      final t = TurnoverBasis.forYear(
        year: 2027,
        fromReceipts: const Money(500),
        opening: const Money(9999),
        trackingStart: start,
        backfilled: const Money(100),
      );
      expect(t.amount, const Money(500));
    });

    test('BackfillStatus: Frage, Ersetzt und Knopf', () {
      BackfillStatus status(List<YearTurnover> years) =>
          BackfillStatus.of(trackingStart: start, years: years);
      final none = status([year()]);
      expect(none.canBackfill, isTrue);
      expect(none.asksComplete, isFalse);
      expect(none.currentYearRest, const Money(10000));

      final partial = status([year(receipts: 3000, backfilled: 3000)]);
      expect(partial.asksComplete, isTrue);
      expect(partial.replacedByBackfill, isFalse);

      final full = status([year(receipts: 10000, backfilled: 10000)]);
      expect(full.canBackfill, isFalse);
      expect(full.replacedByBackfill, isTrue);

      final confirmed = status([year(backfilled: 1, confirmed: true)]);
      expect(confirmed.confirmed, isTrue);
      expect(confirmed.canBackfill, isFalse);
      expect(confirmed.replacedByBackfill, isFalse);

      // Vorjahr zählt mit (gleiche Regel).
      final both = status([
        year(receipts: 1000, backfilled: 1000),
        TurnoverBasis.forYear(
          year: 2025,
          fromReceipts: const Money(2000),
          opening: const Money(20000),
          trackingStart: start,
          backfilled: const Money(2000),
        ),
      ]);
      expect(both.estimate, const Money(30000));
      expect(both.backfilled, const Money(3000));
      expect(both.rest, const Money(27000));
    });
  });

  Future<Database> openDb({int? version}) => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: version ?? AppDatabase.schemaVersion,
      onCreate: AppDatabase.createSchema,
      singleInstance: false,
    ),
  );

  Receipt income(DateTime date, int cents) => Receipt(
    date: date,
    direction: BookingDirection.income,
    description: 'Rechnung',
    net: Money(cents),
    vat: const Money.zero(),
    gross: Money(cents),
    vatPermille: 0,
    paymentMethod: PaymentMethod.bank,
  );

  test('Schema 32: Migration behält Eröffnungswert, Bestätigung aus', () async {
    final db = await openDb(version: 31);
    await db.insert('opening_turnover', {
      'year': 2026,
      'net_cents': 777,
      'updated_at': '2026-01-01',
    });
    await AppDatabase.upgradeSchema(db, 31, 32);
    final repo = OpeningTurnoverRepository(db);
    expect(await repo.forYear(2026), const Money(777));
    expect(await repo.backfillConfirmed(2026), isFalse);
    await repo.setBackfillConfirmed(2026, true);
    expect(await repo.backfillConfirmed(2026), isTrue);
    // Neuer Eröffnungswert setzt die Bestätigung nicht zurück.
    await repo.save(2026, const Money(888));
    expect(await repo.forYear(2026), const Money(888));
    expect(await repo.backfillConfirmed(2026), isTrue);
    await db.close();
  });

  test('turnoverBefore zählt nur Einnahmen vor dem Erfassungsbeginn', () async {
    final db = await openDb();
    final receipts = ReceiptRepository(db);
    await receipts.save(income(DateTime(2026, 3, 1), 3000));
    await receipts.save(income(DateTime(2026, 6, 30), 1000));
    await receipts.save(income(DateTime(2026, 7, 1), 5000));
    expect(
      await receipts.turnoverBefore(2026, start, includeVat: true),
      const Money(4000),
    );
    expect(
      await receipts.turnoverForYear(2026, includeVat: true),
      const Money(9000),
    );
    await db.close();
  });

  testWidgets('Übersicht: Schätzung, Nachtragen, Frage und Bestätigung', (
    tester,
  ) async {
    final now = DateTime.now();
    // Nie der 1. Jänner, sonst wäre das Jahr voll erfasst.
    final tracking = now.month == 1 && now.day == 1
        ? DateTime(now.year, 1, 2)
        : DateTime(now.year, now.month, now.day);
    final db = await tester.runAsync(() => openDb());
    AppDatabase.instance.overrideDatabaseForTesting(db!);
    final state = AppState(Repositories(db));
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await state.repositories.openingTurnover.save(
        now.year,
        const Money(1000000),
      );
      await state.repositories.openingTurnover.save(
        now.year - 1,
        const Money(0),
      );
      await state.saveProfile(
        CompanyProfile(
          companyName: 'Muster',
          country: Country.at,
          trackingStart: tracking,
        ),
      );
    });
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await settle(tester);

    expect(find.byKey(const Key('backfill-estimate')), findsOneWidget);
    final button = find.byKey(const Key('backfill-start'));
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(find.byKey(const Key('backfill-question')), findsNothing);

    // Eine alte Rechnung nachgetragen: Frage erscheint.
    await tester.runAsync(() async {
      await state.repositories.receipts.save(
        income(
          DateTime(tracking.year, tracking.month, tracking.day - 1),
          400000,
        ),
      );
      await state.onBookingsChanged();
    });
    await settle(tester);
    expect(
      find.textContaining(
        'Du hast ${Fmt.money(const Money(400000))} von geschätzten '
        '${Fmt.money(const Money(1000000))}',
      ),
      findsOneWidget,
    );
    expect(state.smallBusiness!.currentYearTurnover, const Money(1000000));
    for (final key in ['backfill-later', 'backfill-confirm']) {
      expect(
        tester.getSize(find.byKey(Key(key))).height,
        greaterThanOrEqualTo(48),
      );
    }

    await tester.tap(find.byKey(const Key('backfill-confirm')));
    await settle(tester);
    expect(state.backfill!.confirmed, isTrue);
    expect(state.smallBusiness!.currentYearTurnover, const Money(400000));
    expect(find.byKey(const Key('backfill-start')), findsNothing);
    expect(find.byKey(const Key('backfill-estimate')), findsNothing);

    // Rückgängig (Firmenprofil).
    await tester.runAsync(() => state.setBackfillConfirmed(false));
    await settle(tester);
    expect(find.byKey(const Key('backfill-start')), findsOneWidget);

    // Belegformular im Nachtragsmodus: Einnahme, Datum am Vortag, Hinweis
    // auf Zahlungseingang, keine Kurzwahl „Heute/Gestern“.
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<bool>(
            builder: (_) => ReceiptEditScreen(
              direction: BookingDirection.income,
              backfillBefore: tracking,
            ),
          ),
        );
    await settle(tester);
    expect(
      find.textContaining(
        Fmt.date(DateTime(tracking.year, tracking.month, tracking.day - 1)),
      ),
      findsWidgets,
    );
    expect(find.textContaining('Zahlungseingang'), findsOneWidget);
    expect(find.byKey(const Key('date-Heute')), findsNothing);
    await tester.runAsync(db.close);
  });

  testWidgets('Später blendet die Frage aus, Knopf bleibt', (tester) async {
    final status = BackfillStatus.of(
      trackingStart: start,
      years: [
        TurnoverBasis.forYear(
          year: 2026,
          fromReceipts: const Money(100),
          opening: const Money(1000),
          trackingStart: start,
          backfilled: const Money(100),
        ),
      ],
    );
    var later = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BackfillSection(
              status: status,
              askComplete: !later,
              onBackfill: () {},
              onConfirm: () {},
              onLater: () => setState(() => later = true),
            ),
          ),
        ),
      ),
    );
    expect(find.text(BackfillSection.question(status)), findsOneWidget);
    await tester.tap(find.byKey(const Key('backfill-later')));
    await tester.pump();
    expect(find.byKey(const Key('backfill-question')), findsNothing);
    expect(find.byKey(const Key('backfill-start')), findsOneWidget);
  });

  test('Profilwechsel lädt die Übersicht neu (Rücklage ohne USt)', () async {
    final db = await openDb();
    final state = AppState(Repositories(db));
    const regular = CompanyProfile(
      companyName: 'Muster',
      country: Country.at,
      isSmallBusiness: false,
    );
    await state.saveProfile(regular);
    final before = state.bookingsRevision;
    await state.saveProfile(regular.copyWith(isSmallBusiness: true));
    // Die Übersicht lädt bei neuer Revision Rücklage und Summen neu.
    expect(state.bookingsRevision, greaterThan(before));
    await db.close();
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}
