// Mehrsprachige Belegerkennung: Schlüsselwort-Tabellen (receipt_keywords.dart),
// Satz nach dem Prozentzeichen, Dezimalsätze, Plausibilität über die
// Steuerzeilen, Branche/Beschreibung/Kategorie und die Vorbelegung.
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_classifier.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = ReceiptTextParser(
    TaxProfile.austria,
    now: DateTime(2026, 10, 14),
  );
  ReceiptScanResult parse(String text) =>
      parser.parse(OcrDocument.fromText(text));

  // Sprache, Belegtext, Brutto in Cent, Satz in Promille, Datum.
  final cases = <(String, String, int, int, String)>[
    (
      'SL',
      'DARS d.d.\nDatum in čas izdaje: 03.10.2026\nSkupaj EUR: 9,00\n'
          'DDV % 22,0  Osnova za DDV 7,38  Znesek DDV 1,62  Skupaj 9,00',
      900,
      220,
      '2026-10-03',
    ),
    (
      'HR',
      'Konzum d.d.\nDatum: 01.09.2026\nUkupno 12,50\nPDV 25%  10,00  2,50',
      1250,
      250,
      '2026-09-01',
    ),
    (
      'IT',
      'Autogrill\nData 02/09/2026\nTotale 11,00\nIVA 10%  10,00  1,00',
      1100,
      100,
      '2026-09-02',
    ),
    (
      'HU',
      'MOL\nDátum: 2026.09.03.\nÖsszesen 1270,00\nÁFA 27%  1000,00  270,00',
      127000,
      270,
      '2026-09-03',
    ),
    (
      'CS',
      'Billa s.r.o.\nDatum 04.09.2026\nCelkem 121,00\nDPH 21%  100,00  21,00',
      12100,
      210,
      '2026-09-04',
    ),
    (
      'PL',
      'Orlen\nData 05.09.2026\nRazem 123,00\nPTU A 23%  100,00  23,00',
      12300,
      230,
      '2026-09-05',
    ),
    (
      'FR',
      'Total\nDate 06/09/2026\nTotal TTC 12,00\nTVA 20%  10,00  2,00',
      1200,
      200,
      '2026-09-06',
    ),
    (
      'NL',
      'Albert Heijn\nDatum 07-09-2026\nTotaal 10,90\nBTW 9%  10,00  0,90',
      1090,
      90,
      '2026-09-07',
    ),
    (
      'SE',
      'ICA\nDatum 2026-09-08\nSumma 125,00\nMoms 25%  100,00  25,00',
      12500,
      250,
      '2026-09-08',
    ),
    (
      'NO',
      'Rema\nDato 09.09.2026\nTotalt 125,00\nMVA 25%  100,00  25,00',
      12500,
      250,
      '2026-09-09',
    ),
  ];

  group('Mehrsprachig: Brutto, Satz, Datum', () {
    for (final (lang, text, gross, permille, date) in cases) {
      test(lang, () {
        final r = parse(text);
        expect(r.gross?.value.cents, gross, reason: 'Brutto $lang');
        expect(r.dominantPermille, permille, reason: 'Satz $lang');
        expect(
          r.date?.value.toIso8601String().substring(0, 10),
          date,
          reason: 'Datum $lang',
        );
        final l = r.vatLines.first;
        expect(l.net.cents + l.vat.cents, l.gross.cents);
      });
    }
  });

  test('Dezimalsatz 4,90 % wird erkannt, Steuerzeilen gehen vor', () {
    final r = parse(
      'SPAR\nE: 8.57\nBAR 9,00\nRÜCKGELD 0,43\n'
      '4,90%  4,84  0,24  5,08 K\n10,00%  3,17  0,32  3,49 A',
    );
    expect(r.gross?.value.cents, 857);
    expect([for (final l in r.vatLines) l.permille], [49, 100]);
  });

  test('Rechnungsnummer mehrsprachig', () {
    expect(
      parse('Št. računa: U109-1122-260296226').invoiceNumber?.value,
      'U109-1122-260296226',
    );
    expect(parse('Broj računa: 12/2026').invoiceNumber?.value, '12/2026');
    expect(parse('Factuurnummer 2026-001').invoiceNumber?.value, '2026-001');
  });

  test('Datum mit gemischtem Trenner „05.09,2026“', () {
    expect(
      parse('Zahlung\n05.09,2026 10:04:22').date?.value,
      DateTime(2026, 9, 5),
    );
  });

  group('Händler, Branche, Beschreibung, Kategorie', () {
    test('Logo-Rauschen „SPARO“ wird zu SPAR', () {
      expect(ReceiptClassifier.chainIn('SPARO')?.$1, 'SPAR');
      expect(ReceiptClassifier.chainIn('BILLA®')?.$1, 'BILLA');
      expect(ReceiptClassifier.chainIn('Rosentalerstr. 2'), isNull);
    });

    test('SPAR: Lebensmittel mit Artikeln, Sonstige Ausgaben', () {
      final rows = [
        'SPARO',
        'SBUDGET BAGUETTE',
        '2 X 0,84  1,68 K',
        'FREEFROM BIOMILCH 1L',
        'SUMME 5,08',
      ];
      final r = parser.parse(OcrDocument.fromText(rows.join('\n')));
      final c = ReceiptClassifier.classify(rows, r);
      expect(c.branch, ReceiptBranch.supermarket);
      expect(c.description, 'SPAR – Lebensmittel (Baguette, Biomilch)');
      expect(c.categoryName, 'Sonstige Ausgaben');
    });

    test('Maut → Kfz-Kosten, Beschreibung höchstens 60 Zeichen', () {
      final rows = ['Marktgemeinde Treffen', 'Mautticket', 'Gesamt 10,00'];
      final c = ReceiptClassifier.classify(
        rows,
        parser.parse(OcrDocument.fromText(rows.join('\n'))),
      );
      expect(c.branch, ReceiptBranch.toll);
      expect(c.categoryName, 'Kfz-Kosten');
      expect(c.description, 'Marktgemeinde Treffen – Maut');
      expect(c.description!.length, lessThanOrEqualTo(maxDescriptionLength));
    });

    test('Taxi → Reisekosten', () {
      final rows = ['Taxi', 'Fare 1385'];
      final c = ReceiptClassifier.classify(
        rows,
        parser.parse(OcrDocument.fromText(rows.join('\n'))),
      );
      expect(c.categoryName, 'Reisekosten');
    });
  });

  group('Vorbelegung', () {
    ReceiptScanPrefill prefill(String text) => ReceiptScanPrefill.from(
      parse(text),
      direction: BookingDirection.expense,
      profile: TaxProfile.austria,
    );

    test('Beleg ohne Steuerausweis: 0 % und Hinweis', () {
      final p = prefill('Datum 05.09.2026\nBetrag: EUR 7,00');
      expect(p.gross?.cents, 700);
      expect(p.vatPermille, 0);
      expect(p.hints.join(), contains('Beleg ohne Steuerausweis'));
    });

    test('4,9 % vor dem 1.7.2026: nicht vorbelegen, Hinweis', () {
      final p = prefill(
        'Datum 10.06.2026\nSumme 5,08\n4,90%  4,84  0,24  5,08',
      );
      expect(p.vatPermille, isNull);
      expect(p.hints.join(), contains('gilt aber erst ab 01.07.2026'));
    });

    test('4,9 % ab dem 1.7.2026 wird vorbelegt', () {
      final p = prefill(
        'Datum 10.09.2026\nSumme 5,08\n4,90%  4,84  0,24  5,08',
      );
      expect(p.vatPermille, 49);
    });

    test('Satz ohne Profil-Eintrag: Hinweis „noch nicht hinterlegt“', () {
      final p = prefill('Summe 10,55\n5,50%  10,00  0,55  10,55');
      expect(p.vatPermille, isNull);
      expect(p.hints.join(), contains('in der App noch nicht hinterlegt'));
    });

    test('Ausländische USt: 0 % und Länderhinweis aus dem TaxProfile', () {
      final p = prefill(
        'ID št. za DDV: SI92473717\nSkupaj EUR: 9,00\n'
        'DDV % 22,0  7,38  1,62  9,00',
      );
      expect(p.vatPermille, 0);
      expect(p.hints.join(), contains('EU-Vorsteuer-Erstattungsverfahren'));
    });
  });
}
