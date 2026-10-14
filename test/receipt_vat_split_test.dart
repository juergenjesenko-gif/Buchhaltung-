import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/data/app_database.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/features/receipts/vat_split_editor.dart';
import 'package:buchhaltung/services/export/exporters.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:buchhaltung/services/receipt_vat_split.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Beleg mit mehreren Steuersätzen (L-2.27): Speisen 10 % und Getränke
/// 20 % auf einem Bewirtungsbeleg.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de');
  });

  // Bewirtung: Speisen 33,00 € (10 %), Getränke 14,40 € (20 %).
  const parts = <VatPart>[
    (permille: 100, gross: Money(3300)),
    (permille: 200, gross: Money(1440)),
  ];

  Receipt dinner({int? id}) {
    final lines = ReceiptVatSplit.lines(parts);
    final h = ReceiptVatSplit.header(lines);
    return Receipt(
      id: id,
      date: DateTime(2026, 10, 10),
      direction: BookingDirection.expense,
      description: 'Geschäftsessen',
      net: h.net,
      vat: h.vat,
      gross: h.gross,
      vatPermille: h.permille,
      vatLines: lines,
      paymentMethod: PaymentMethod.card,
    );
  }

  group('Rechnen', () {
    test('je Teil net + vat == gross, Steuer als Restgröße', () {
      final lines = ReceiptVatSplit.lines(parts);
      expect(lines.map((l) => l.isConsistent), everyElement(isTrue));
      expect(lines[0].net, const Money(3000));
      expect(lines[0].vat, const Money(300));
      expect(lines[1].net, const Money(1200));
      expect(lines[1].vat, const Money(240));
    });

    test('Rundung je Teil, Bruttobetrag bleibt exakt', () {
      final lines = ReceiptVatSplit.lines(const [
        (permille: 100, gross: Money(999)),
        (permille: 200, gross: Money(101)),
        (permille: 130, gross: Money(1)),
      ]);
      expect(lines.map((l) => l.gross.cents), [999, 101, 1]);
      expect(lines.map((l) => l.isConsistent), everyElement(isTrue));
      // 9,99 / 1,1 = 9,0818… → 9,08; Steuer 0,91
      expect(lines[0].net, const Money(908));
      expect(lines[0].vat, const Money(91));
      // 0,01 / 1,13 → 0,01 netto, 0 Steuer
      expect(lines[2].vat, const Money.zero());
    });

    test('Kopf: Summen und Satz der größten Zeile', () {
      final h = ReceiptVatSplit.header(ReceiptVatSplit.lines(parts));
      expect(h.gross, const Money(4740));
      expect(h.net + h.vat, h.gross);
      expect(h.permille, 100);
    });

    test('Rest und Differenz', () {
      expect(
        ReceiptVatSplit.remainder(const Money(4740), const [Money(3300)]),
        const Money(1440),
      );
      expect(
        ReceiptVatSplit.difference(const Money(4740), const [
          Money(3300),
          Money(1400),
        ]),
        const Money(-40),
      );
    });

    test('gleiche Sätze werden zusammengefasst, leere Teile entfallen', () {
      expect(
        ReceiptVatSplit.normalize(const [
          (permille: 100, gross: Money(100)),
          (permille: 200, gross: Money.zero()),
          (permille: 100, gross: Money(50)),
        ]),
        [(permille: 100, gross: const Money(150))],
      );
    });
  });

  group('Eingabe im Formular', () {
    test('letzter Teil übernimmt den Rest, bis er geändert wird', () {
      final c = VatSplitController();
      c.start(
        total: const Money(4740),
        firstPermille: 100,
        secondPermille: 200,
      );
      expect(c.parts[1].controller.text, Fmt.amount(Money.zero()));
      c.parts[0].controller.text = '33,00';
      c.edited(0, const Money(4740));
      expect(c.parts[1].gross, const Money(1440));
      expect(c.check(const Money(4740)), isNull);

      c.parts[1].controller.text = '14,00';
      c.edited(1, const Money(4740));
      expect(c.parts[1].auto, isFalse);
      expect(c.check(const Money(4740)), contains('fehlen'));
      c.dispose();
    });

    test('Entfernen bis auf einen Teil beendet die Aufteilung', () {
      final c = VatSplitController()
        ..start(
          total: const Money(1000),
          firstPermille: 100,
          secondPermille: 200,
        );
      expect(c.remove(1, const Money(1000)), 100);
      expect(c.active, isFalse);
    });
  });

  group('Datenbank', () {
    Future<Database> open([int version = AppDatabase.schemaVersion]) =>
        databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: AppDatabase.createSchema,
            singleInstance: false,
          ),
        );

    test('Migration 14: bestehender Beleg wird genau eine Zeile', () async {
      final db = await open(13);
      final now = DateTime(2026, 1, 1).toIso8601String();
      await db.insert('receipts', {
        'date': '2026-03-01',
        'direction': 'expense',
        'net_cents': 1000,
        'vat_cents': 200,
        'gross_cents': 1200,
        'vat_permille': 200,
        'created_at': now,
        'updated_at': now,
      });
      await AppDatabase.upgradeSchema(db, 13, AppDatabase.schemaVersion);
      final lines = await db.query('receipt_vat_lines');
      expect(lines, hasLength(1));
      expect(lines.single['position'], 1);
      expect(lines.single['vat_permille'], 200);
      expect(lines.single['gross_cents'], 1200);
      final totals = await ReceiptRepository(
        db,
      ).totals(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));
      expect(totals.expenseVat, const Money(200));
      await db.close();
    });

    test(
      'aufgeteilter Beleg: Zeilen gespeichert, Auswertung je Satz',
      () async {
        final db = await open();
        final repo = ReceiptRepository(db);
        final id = await repo.save(dinner());
        final loaded = (await repo.byId(id))!;
        expect(loaded.isSplit, isTrue);
        expect(loaded.lines.map((l) => l.vatPermille), [100, 200]);
        expect((await repo.query()).single.lines, hasLength(2));

        final totals = await repo.totals(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
        );
        expect(totals.inputVatByRate, {
          100: const Money(300),
          200: const Money(240),
        });
        expect(totals.expenseNet, const Money(4200));
        expect(totals.expenseVat, const Money(540));

        // Kleinunternehmer: kein Vorsteuerabzug, Ausgabe brutto.
        final small = await repo.totals(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
          inputVatDeductible: false,
        );
        expect(small.expenseNet, const Money(4740));
        expect(small.expenseVat, const Money.zero());
        expect(small.inputVatByRate, isEmpty);

        // Zurück auf einen Satz: eine Zeile.
        await repo.save(
          loaded.copyWith(
            vatLines: const [],
            net: const Money(4309),
            vat: const Money(431),
            vatPermille: 100,
          ),
        );
        expect(await repo.vatLines(id), hasLength(1));
        await db.close();
      },
    );

    test('Summe der Zeilen ungleich Belegbetrag wird abgewiesen', () async {
      final db = await open();
      final bad = dinner().copyWith(gross: const Money(5000));
      await expectLater(ReceiptRepository(db).save(bad), throwsStateError);
      await db.close();
    });
  });

  group('Exporte', () {
    final receipt = dinner(id: 7);
    final totals = PeriodTotals(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      incomeNet: const Money.zero(),
      incomeVat: const Money.zero(),
      incomeGross: const Money.zero(),
      expenseNet: const Money(4200),
      expenseVat: const Money(540),
      expenseGross: const Money(4740),
      incomeNetByRate: const {},
      inputVatByRate: const {100: Money(300), 200: Money(240)},
    );
    Exporter exporter(Country country) => Exporter(
      profile: CompanyProfile(companyName: 'Test', country: country),
      receipts: [receipt],
      categories: const [],
      totals: totals,
      period: Period.month(DateTime(2026, 10, 1)),
    );

    test('DATEV: eine Buchung je Satz', () {
      final rows = exporter(Country.de)
          .build(ExportFormat.datev)
          .content
          .split('\r\n')
          .skip(2)
          .where((l) => l.isNotEmpty)
          .toList();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.split(';').first), ['33,00', '14,40']);
    });

    test('BMD: Steuercode je Satz', () {
      final rows = exporter(Country.at)
          .build(ExportFormat.bmd)
          .content
          .split('\r\n')
          .skip(1)
          .where((l) => l.isNotEmpty)
          .map((l) => l.split(';'))
          .toList();
      expect(rows.map((r) => r[7]), ['12', '11']);
      expect(rows.map((r) => r[9]), ['3,00', '2,40']);
    });

    test('Belegliste: je Satz eine Zeile mit Teilangabe', () {
      final csv = exporter(Country.at).build(ExportFormat.plainCsv).content;
      expect(csv, contains(';1/2'));
      expect(csv, contains(';2/2'));
    });
  });

  group('Belegerkennung', () {
    test('mehrere eigene Sätze werden als Aufteilung vorbelegt', () {
      final result = ReceiptScanResult(
        gross: const Detected(Money(4740), 97),
        vatLines: const [
          DetectedVat(
            permille: 100,
            net: Money(3000),
            vat: Money(300),
            confidence: 90,
          ),
          DetectedVat(
            permille: 200,
            net: Money(1200),
            vat: Money(240),
            confidence: 90,
          ),
        ],
        currency: const Detected('EUR', 90),
        date: Detected(DateTime(2026, 10, 10), 90),
      );
      final prefill = ReceiptScanPrefill.from(
        result,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
      );
      expect(prefill.vatParts, [
        (permille: 100, gross: const Money(3300)),
        (permille: 200, gross: const Money(1440)),
      ]);
      expect(prefill.hints.join(), contains('als Aufteilung vorbelegt'));
    });

    test('ausländischer Satz in einer Zeile wird 0 %', () {
      final result = ReceiptScanResult(
        vatLines: const [
          DetectedVat(
            permille: 70,
            net: Money(1000),
            vat: Money(70),
            confidence: 90,
          ),
          DetectedVat(
            permille: 200,
            net: Money(1000),
            vat: Money(200),
            confidence: 90,
          ),
        ],
        currency: const Detected('EUR', 90),
        date: Detected(DateTime(2026, 10, 10), 90),
      );
      final prefill = ReceiptScanPrefill.from(
        result,
        direction: BookingDirection.expense,
        profile: TaxProfile.austria,
      );
      expect(prefill.vatParts.map((p) => p.permille), [0, 200]);
    });
  });
}
