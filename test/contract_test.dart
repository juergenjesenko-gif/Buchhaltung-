import 'package:buchhaltung/app_state.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/contract_repository.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/contract.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/contracts/contract_screens.dart';
import 'package:buchhaltung/services/contracts/contract_csv.dart';
import 'package:buchhaltung/services/contracts/contract_schedule.dart';
import 'package:buchhaltung/services/contracts/contract_text_extractor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dashboard_refresh_test.dart' show settle;

/// Vertragsarchiv (FA-16.1 bis FA-16.8, Lastenheft 5.23).
Contract _rent({DateTime? end}) => Contract(
  type: ContractType.rent,
  title: 'Büro',
  partner: 'Huber GmbH',
  startDate: DateTime(2026, 1, 1),
  endDate: end,
  noticeValue: 3,
  noticeUnit: NoticeUnit.months,
  rate: const Money(120000),
  rhythm: PaymentRhythm.monthly,
  vatPermille: 200,
  nextIndexDate: DateTime(2027, 1, 1),
);

Receipt _paid(DateTime d, int cents) => Receipt(
  date: d,
  direction: BookingDirection.expense,
  description: 'Miete',
  net: Money(cents),
  vat: const Money.zero(),
  gross: Money(cents),
  vatPermille: 0,
);

void main() {
  group('Fristen und Zahlungsplan', () {
    test('Kündigen bis = Ende minus Frist; Termine für die Box', () {
      final c = _rent(end: DateTime(2027, 12, 31));
      expect(ContractSchedule.noticeDeadline(c), DateTime(2027, 9, 30));
      final d = ContractSchedule.deadlines([c], DateTime(2026, 10, 16));
      expect(d.map((x) => x.label), [
        'Indexanpassung: Büro',
        'Kündigen bis: Büro',
        'Vertragsende: Büro',
      ]);
    });

    test('Unbefristet: keine Kündigungsfrist als Termin', () {
      expect(ContractSchedule.noticeDeadline(_rent()), isNull);
    });

    test('Monatsende bleibt Monatsende', () {
      final c = _rent().copyWith(startDate: DateTime(2026, 1, 31));
      final due = ContractSchedule.dueDates(c, DateTime(2026, 4, 30));
      expect(due, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('Abgleich Rate gegen Buchung: bezahlt, abweichend, fehlt', () {
      final m = ContractSchedule.match(_rent(), [
        _paid(DateTime(2026, 1, 3), 120000),
        _paid(DateTime(2026, 2, 2), 118000),
      ], DateTime(2026, 3, 15));
      expect(m.map((p) => p.status), [
        PaymentStatus.paid,
        PaymentStatus.differs,
        PaymentStatus.missing,
      ]);
    });

    test('Buchungsvorschlag: netto + USt = brutto', () {
      final r = ContractSchedule.suggestedBooking(
        _rent(),
        DateTime(2026, 4, 1),
      );
      expect(r.gross, const Money(120000));
      expect(r.net + r.vat, r.gross);
      expect(r.net, const Money(100000));
    });

    test('Aufbewahrung ab Ende bzw. letzter Buchung, Jahresende', () {
      final c = _rent(end: DateTime(2027, 6, 30));
      expect(
        ContractSchedule.retentionUntil(c, DateTime(2028, 1, 5), 7),
        DateTime(2035, 12, 31),
      );
      expect(ContractSchedule.retentionUntil(_rent(), null, 7), isNull);
    });
  });

  group('Kurzübersicht aus dem Text', () {
    const text =
        '[S.1] Mietvertrag\n'
        '[S.1] Das Mietverhältnis beginnt am 01.02.2026.\n'
        '[S.1] Die Miete beträgt monatlich EUR 1.250,00 inkl. USt.\n'
        '[S.2] Die Kündigungsfrist beträgt 3 Monate zum Quartalsende.\n'
        '[S.2] Wertsicherung nach dem Verbraucherpreisindex 2020.\n'
        '[S.2] Das Mietverhältnis endet am 31.01.2029.';

    test('nur Auszug mit Fundstelle', () {
      final hints = ContractTextExtractor.extract(text);
      ContractHint of(ContractField f) => hints.firstWhere((h) => h.field == f);
      expect(of(ContractField.startDate).date, DateTime(2026, 2, 1));
      expect(of(ContractField.startDate).source, 'S. 1, Z. 2');
      expect(of(ContractField.rate).amount, const Money(125000));
      expect(of(ContractField.notice).number, 3);
      expect(of(ContractField.notice).unit, 'months');
      expect(of(ContractField.notice).source, 'S. 2, Z. 1');
      expect(of(ContractField.indexation).page, 2);
      expect(of(ContractField.endDate).date, DateTime(2029, 1, 31));
    });
  });

  group('Datenbank', () {
    setUpAll(() async {
      sqfliteFfiInit();
      await initializeDateFormatting('de');
    });

    test('Seiten nur anhängen, Belege verknüpfen, CSV', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: AppDatabase.schemaVersion,
          onCreate: AppDatabase.createSchema,
          singleInstance: false,
        ),
      );
      final repo = ContractRepository(db);
      final id = await repo.save(_rent(), newPages: ['belege/a.jpg']);
      final c = (await repo.byId(id))!;
      await repo.save(c, newPages: ['belege/b.jpg']);
      expect((await repo.byId(id))!.pages, ['belege/a.jpg', 'belege/b.jpg']);
      final rid = await ReceiptRepository(
        db,
      ).save(_paid(DateTime(2026, 1, 2), 120000));
      await repo.link(id, rid);
      await repo.link(id, rid); // doppelt ignoriert
      expect(await repo.linkedReceipts(id), hasLength(1));
      final csv = ContractCsv.build(await repo.all());
      expect(csv, contains('Huber GmbH'));
      expect(csv, contains('3 Monate'));
      await repo.delete(id);
      expect(await db.query('contract_pages'), isEmpty);
      await db.close();
    });

    testWidgets('Vertrag ablegen: Speichern unten 56 dp, Knöpfe ≥ 48 dp', (
      tester,
    ) async {
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
      await tester.runAsync(
        () => db!.insert('company_profile', {'id': 1, 'company_name': 'T'}),
      );
      final state = AppState(Repositories(db!));
      await tester.runAsync(state.reload);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: const MaterialApp(home: ContractEditScreen()),
        ),
      );
      await settle(tester);
      final save = find.byKey(const Key('contract-save'));
      expect(tester.getSize(save).height, greaterThanOrEqualTo(56));
      expect(tester.getRect(save).center.dy, greaterThan(640 * 2 / 3));
      for (final key in ['contract-photo', 'contract-scan']) {
        expect(
          tester.getSize(find.byKey(Key(key))).height,
          greaterThanOrEqualTo(48),
        );
      }
      // 12 dp zwischen den Feldern (Gerätetest 2026-10-21): keine
      // Beschriftung überlappt das Feld darüber.
      final title = tester.getRect(
        find.widgetWithText(TextFormField, 'Bezeichnung'),
      );
      final partner = tester.getRect(
        find.widgetWithText(TextFormField, 'Vertragspartner'),
      );
      expect(partner.top - title.bottom, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
    });
  });
}
