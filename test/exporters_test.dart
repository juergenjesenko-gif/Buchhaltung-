import 'package:buchhaltung/core/formatting.dart';
import 'package:buchhaltung/data/repositories.dart';
import 'package:buchhaltung/domain/company_profile.dart';
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/export/csv.dart';
import 'package:buchhaltung/services/export/exporters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Ohne die Locale-Daten wirft jede DateFormat-Nutzung in Period/Fmt.
  setUpAll(() => initializeDateFormatting('de'));

  const categories = [
    ExpenseCategory(
      id: 1,
      name: 'Umsatzerlöse',
      direction: BookingDirection.income,
      datevAccount: '8400',
    ),
    ExpenseCategory(
      id: 2,
      name: 'Büromaterial',
      direction: BookingDirection.expense,
      datevAccount: '4930',
    ),
  ];

  final receipts = [
    Receipt(
      id: 1,
      date: DateTime(2026, 3, 4),
      direction: BookingDirection.income,
      description: 'Beratung März',
      counterparty: 'Muster GmbH',
      net: const Money(100000),
      vat: const Money(20000),
      gross: const Money(120000),
      vatPermille: 200,
      categoryId: 1,
      paymentMethod: PaymentMethod.bank,
    ),
    Receipt(
      id: 2,
      date: DateTime(2026, 3, 12),
      direction: BookingDirection.expense,
      description: 'Druckerpapier; 5 Pakete',
      counterparty: 'Bürohaus',
      net: const Money(4167),
      vat: const Money(833),
      gross: const Money(5000),
      vatPermille: 200,
      categoryId: 2,
      paymentMethod: PaymentMethod.cash,
    ),
  ];

  final totals = PeriodTotals(
    from: DateTime(2026, 3, 1),
    to: DateTime(2026, 3, 31),
    incomeNet: const Money(100000),
    incomeVat: const Money(20000),
    incomeGross: const Money(120000),
    expenseNet: const Money(4167),
    expenseVat: const Money(833),
    expenseGross: const Money(5000),
    incomeNetByRate: const {200: Money(100000)},
    inputVatByRate: const {200: Money(833)},
  );

  Exporter exporterFor(Country country, {bool smallBusiness = false}) =>
      Exporter(
        profile: CompanyProfile(
          companyName: 'Muster e.U.',
          country: country,
          street: 'Hauptstraße 1',
          postalCode: '9020',
          city: 'Klagenfurt',
          taxNumber: '12-345/6789',
          vatId: country == Country.at ? 'ATU12345678' : 'DE123456789',
          isSmallBusiness: smallBusiness,
        ),
        receipts: receipts,
        categories: categories,
        totals: totals,
        period: Period.month(DateTime(2026, 3, 1)),
      );

  group('CsvWriter', () {
    test('trennt mit Semikolon und beendet Zeilen mit CRLF', () {
      final csv = CsvWriter()..writeRow(['a', 'b']);
      expect(csv.build(withBom: false), 'a;b\r\n');
    });

    test('quotet Felder, die das Trennzeichen enthalten', () {
      final csv = CsvWriter()..writeRow(['eins;zwei', 'drei']);
      expect(csv.build(withBom: false), '"eins;zwei";drei\r\n');
    });

    test('verdoppelt Anführungszeichen im Feld', () {
      final csv = CsvWriter()..writeRow(['sagt "hallo"']);
      expect(csv.build(withBom: false), '"sagt ""hallo"""\r\n');
    });

    test('schreibt ein BOM, damit Excel UTF-8 erkennt', () {
      final csv = CsvWriter()..writeRow(['Bürostuhl']);
      expect(csv.build().codeUnitAt(0), 0xFEFF);
      expect(csv.build(withBom: false).codeUnitAt(0), isNot(0xFEFF));
    });

    test('schreibt leere Werte als leeres Feld', () {
      final csv = CsvWriter()..writeRow(['a', null, 'c']);
      expect(csv.build(withBom: false), 'a;;c\r\n');
    });
  });

  group('csvAmount', () {
    test('formatiert mit Komma und zwei Dezimalstellen', () {
      expect(csvAmount(120000), '1200,00');
      expect(csvAmount(5), '0,05');
      expect(csvAmount(0), '0,00');
    });

    test('behält das Vorzeichen', () {
      expect(csvAmount(-4999), '-49,99');
    });

    test('setzt keinen Tausendertrenner', () {
      // Ein Punkt als Tausendertrenner würde beim Import als Dezimalpunkt
      // gelesen und den Betrag um Faktor 1000 verfälschen.
      expect(csvAmount(123456789), '1234567,89');
    });
  });

  group('Belegliste', () {
    test('enthält Kopfzeile, alle Belege und Summen', () {
      final result = exporterFor(Country.at).build(ExportFormat.plainCsv);
      final lines = result.content.split('\r\n');

      expect(lines.first, contains('Datum'));
      expect(lines.first, contains('Brutto'));
      expect(result.rowCount, 2);
      expect(result.content, contains('2026-03-04'));
      expect(result.content, contains('Beratung März'));
      expect(result.content, contains('Summe Einnahmen'));
      expect(result.content, contains('Ergebnis (netto)'));
    });

    test(
      'quotet die Beschreibung mit Semikolon, statt Spalten zu zerreißen',
      () {
        final result = exporterFor(Country.at).build(ExportFormat.plainCsv);
        expect(result.content, contains('"Druckerpapier; 5 Pakete"'));
      },
    );

    test('benennt die Datei nach Firma und Zeitraum', () {
      final result = exporterFor(Country.at).build(ExportFormat.plainCsv);
      expect(result.fileName, 'belege_muster-e-u-_2026-03-01_2026-03-31.csv');
    });

    test('mappt für Österreich auf den Einheitskontenrahmen', () {
      final at = exporterFor(Country.at).build(ExportFormat.plainCsv);
      // SKR03 8400 -> 4000 in Österreich
      expect(at.content, contains('4000'));

      final de = exporterFor(Country.de).build(ExportFormat.plainCsv);
      expect(de.content, contains('8400'));
    });
  });

  group('DATEV', () {
    test('beginnt mit der EXTF-Kennung und Formatversion 700', () {
      final result = exporterFor(Country.de).build(ExportFormat.datev);
      final lines = result.content.split('\r\n');
      expect(lines.first, startsWith('﻿"EXTF";700;21;"Buchungsstapel"'));
    });

    test('hat die Spaltenüberschriften des Buchungsstapels in Zeile 2', () {
      final result = exporterFor(Country.de).build(ExportFormat.datev);
      final lines = result.content.split('\r\n');
      expect(
        lines[1],
        startsWith('Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen'),
      );
      expect(lines[1], contains('Buchungstext'));
    });

    test('bucht Einnahmen im Haben und Ausgaben im Soll', () {
      final result = exporterFor(Country.de).build(ExportFormat.datev);
      final lines = result.content.split('\r\n');
      // Zeile 0 = Header, Zeile 1 = Spalten, ab Zeile 2 die Buchungen
      expect(lines[2].split(';')[1], 'H');
      expect(lines[3].split(';')[1], 'S');
    });

    test('bucht immer den Bruttobetrag ohne Vorzeichen', () {
      final result = exporterFor(Country.de).build(ExportFormat.datev);
      final lines = result.content.split('\r\n');
      expect(lines[2].split(';')[0], '1200,00');
      expect(lines[3].split(';')[0], '50,00');
    });

    test('schreibt das Belegdatum als TTMM', () {
      final result = exporterFor(Country.de).build(ExportFormat.datev);
      final lines = result.content.split('\r\n');
      expect(lines[2].split(';')[9], '0403');
    });

    test('ersetzt Semikola im Buchungstext, statt zu quoten', () {
      final result = exporterFor(Country.de).build(ExportFormat.datev);
      expect(result.content, contains('Druckerpapier, 5 Pakete'));
    });

    test(
      'bucht Barzahlungen gegen die Kasse und Überweisungen gegen die Bank',
      () {
        final result = exporterFor(Country.de).build(ExportFormat.datev);
        final lines = result.content.split('\r\n');
        // Einnahme per Bank: Konto 8400, Gegenkonto 1200
        expect(lines[2].split(';')[6], '8400');
        expect(lines[2].split(';')[7], '1200');
        // Ausgabe in bar: Konto 1000 (Kasse), Gegenkonto 4930
        expect(lines[3].split(';')[6], '1000');
        expect(lines[3].split(';')[7], '4930');
      },
    );
  });

  group('BMD', () {
    test('hat eine Kopfzeile mit den erwarteten Feldern', () {
      final result = exporterFor(Country.at).build(ExportFormat.bmd);
      final lines = result.content.split('\r\n');
      expect(lines.first, contains('Konto'));
      expect(lines.first, contains('Steuercode'));
      expect(lines.first, contains('Buchsymbol'));
    });

    test('setzt Steuercodes je Satz und Richtung', () {
      final result = exporterFor(Country.at).build(ExportFormat.bmd);
      final lines = result.content.split('\r\n');
      // Einnahme 20 % -> Code 1, Ausgabe 20 % -> Code 11
      expect(lines[1].split(';')[7], '1');
      expect(lines[2].split(';')[7], '11');
    });

    test('unterscheidet Kassa und Bank im Buchsymbol', () {
      final result = exporterFor(Country.at).build(ExportFormat.bmd);
      final lines = result.content.split('\r\n');
      expect(lines[1].split(';')[10], 'BK');
      expect(lines[2].split(';')[10], 'KA');
    });

    test('schreibt das Belegdatum im ISO-Format', () {
      final result = exporterFor(Country.at).build(ExportFormat.bmd);
      expect(result.content, contains('2026-03-04'));
    });
  });

  group('Umsatzsteuer-Zusammenfassung', () {
    test('enthält Stammdaten, Bemessungsgrundlagen und Zahllast', () {
      final result = exporterFor(Country.at).build(ExportFormat.vatReturn);
      expect(result.content, contains('Muster e.U.'));
      expect(result.content, contains('ATU12345678'));
      expect(result.content, contains('Steuerpflichtige Umsätze'));
      expect(result.content, contains('Vorsteuer'));
      // 20000 - 833 = 19167 Cent Zahllast
      expect(result.content, contains('Zahllast;191,67'));
    });

    test('weist bei Guthaben statt Zahllast aus', () {
      final exporter = Exporter(
        profile: const CompanyProfile(companyName: 'Test', country: Country.de),
        receipts: receipts,
        categories: categories,
        period: Period.month(DateTime(2026, 3, 1)),
        totals: PeriodTotals(
          from: DateTime(2026, 3, 1),
          to: DateTime(2026, 3, 31),
          incomeNet: const Money.zero(),
          incomeVat: const Money.zero(),
          incomeGross: const Money.zero(),
          expenseNet: const Money(10000),
          expenseVat: const Money(1900),
          expenseGross: const Money(11900),
          incomeNetByRate: const {},
          inputVatByRate: const {190: Money(1900)},
        ),
      );
      final result = exporter.build(ExportFormat.vatReturn);
      expect(result.content, contains('Guthaben;19,00'));
    });

    test('vermerkt die Kleinunternehmerbefreiung', () {
      final result = exporterFor(
        Country.at,
        smallBusiness: true,
      ).build(ExportFormat.vatReturn);
      expect(result.content, contains('§ 6 Abs 1 Z 27 UStG'));
      expect(result.content, contains('Kleinunternehmer'));
    });
  });
}
