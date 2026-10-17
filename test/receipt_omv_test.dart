// Gerätetest 0.23.1, OMV-Tankstelle Dobl (Kaiserwald): zwei Steuersätze
// (20 % Getränke, 0 % Pfand), Zahlungszeilen mit Teilbeträgen und Kassen-QR.
// Die App hatte 7,96 € mit einem Satz 20 % vorbelegt; richtig sind 8,96 €
// mit 7,96 € zu 20 % und 1,00 € zu 0 % (FA-2.62).
import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_classifier.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_code_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_codes.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:buchhaltung/services/receipt_vat_split.dart';
import 'package:flutter_test/flutter_test.dart';

const _kopf = '''
OMV Tankstel le
Adlmannseder Gernot KG [B]
Autobahn A2
8143 Dobl (Kaiserwald)
UID: ATU62993700
Datum: 19.05.2026 14:15:22
Beleg Nr.: 1617/3/260519/197
### RECHNUNG ###
ZP Artikel Bezeichnung Summe
110903 VÖSL.MIN.0.KS FL 0,5 1,99
20,0 (1,000 St x 1,99 EUR)(B)
315749 EINWEGPFAND EIN 0,25
0,0 (1,000 St x 0,25 EUR)(B)
110903 VÖSL.MIN.0.KS FL 0,5 1,99
20,0 (1,000 St x 1,99 EUR)(B)
315749 EINWEGPFAND EIN 0,25
0,0 (1,000 St x 0,25 EUR)(B)
110903 VÖSL.MIN.0.KS FL 0,5 1,99
20,0 (1,000 St x 1,99 EUR)(B)
315749 EINWEGPFAND EIN 0,25
0,0 (1,000 St x 0,25 EUR)(B)
110903 VÖSL.MIN.0.KS FL 0,5 1,99
20,0 (1,000 St x 1,99 EUR)(B)
315749 EINWEGPFAND EIN 0,25
0,0 (1,000 St x 0,25 EUR)(B)
''';

const _steuertabelle = '''
MwSt% Netto MwSt Summe
20,0 6,64 1,32 7,96
0,0 1,00 0,00 1,00
''';

const _gesamt = '''
Gesamtbetrag: 8,96 EUR
''';

const _zahlung = '''
Wertbon 70 Cent: 0,70 EUR
Wertbon 70 Cent: 0,70 EUR
Mastercard - contactless: 7,56 EUR
Kassenidentifikationsnummer: 01617003
''';

/// Kassen-QR nach RKSV mit 7,96 € Normalsatz und 1,00 € Nullsatz.
const _qr =
    '_R1-AT1_01617003_1617/3/260519/197_2026-05-19T14:15:22_7,96_0,00_0,00_'
    '1,00_0,00_U2FsdA==_1a2b3c_AAAAAAAAAAA=_c2lnbmF0dXI=';

ReceiptScanResult _parse(String text) => ReceiptTextParser(
  TaxProfile.austria,
  now: DateTime(2026, 10, 17),
).parse(OcrDocument.fromText(text));

ReceiptScanPrefill _prefill(
  ReceiptScanResult r,
  String text, {
  bool deductible = true,
}) => ReceiptScanPrefill.from(
  r,
  direction: BookingDirection.expense,
  profile: TaxProfile.austria,
  inputVatDeductible: deductible,
  classification: ReceiptClassifier.classify(
    OcrDocument.fromText(text).rows,
    r,
  ),
);

void main() {
  group('OMV-Beleg: Steuertabelle mit zwei Sätzen', () {
    const text = _kopf + _steuertabelle + _gesamt + _zahlung;
    final r = _parse(text);

    test('Brutto 8,96 aus Gesamtbetrag und Tabelle, nicht 7,96', () {
      expect(r.gross?.value, Money(896));
      expect(r.gross!.confidence, greaterThanOrEqualTo(90));
    });

    test('20 % und 0 % mit den gedruckten Werten', () {
      expect(r.vatLines.map((l) => l.permille), [200, 0]);
      final normal = r.vatLines.first;
      expect(normal.net, Money(664));
      expect(normal.vat, Money(132));
      expect(normal.gross, Money(796));
      final zero = r.vatLines.last;
      expect(zero.net, Money(100));
      expect(zero.vat, Money(0));
      for (final l in r.vatLines) {
        expect(l.net + l.vat, l.gross);
      }
    });

    test('Händler ohne OCR-Trennung, UID, Datum', () {
      expect(r.merchant?.value, 'OMV Tankstelle');
      expect(r.vatId?.value, 'ATU62993700');
      expect(r.date?.value, DateTime(2026, 5, 19));
    });

    test('Vorbelegung: Aufteilung 20 %/0 % und gedruckte Werte', () {
      final p = _prefill(r, text);
      expect(p.gross, Money(896));
      expect(p.vatParts, [
        (permille: 200, gross: Money(796)),
        (permille: 0, gross: Money(100)),
      ]);
      final lines = ReceiptVatSplit.lines(p.vatParts, printed: p.printedVat);
      expect(lines.first.net, Money(664));
      expect(lines.first.vat, Money(132));
      expect(lines.last.vat, Money(0));
      for (final l in lines) {
        expect(l.net + l.vat, l.gross);
      }
    });

    test('Nur Getränke und Pfand: kein Treibstoff, keine Kfz-Kosten', () {
      final p = _prefill(r, text);
      expect(p.description, 'Vöslauer Mineral');
      expect(p.categoryName, 'Sonstige Ausgaben');
    });

    test('Kleinunternehmer: Sätze trotzdem vorbelegt, Brutto 8,96', () {
      final p = _prefill(r, text, deductible: false);
      expect(p.gross, Money(896));
      expect(p.vatParts.length, 2);
    });
  });

  test('Nur Gesamtbetrag lesbar: 8,96, keine Zahlungszeile', () {
    final r = _parse(_kopf + _gesamt + _zahlung);
    expect(r.gross?.value, Money(896));
  });

  test('Nur Steuertabelle lesbar: Summe der Zeilen 8,96', () {
    final r = _parse(_kopf + _steuertabelle + _zahlung);
    expect(r.gross?.value, Money(896));
    expect(r.vatLines.length, 2);
  });

  test('Nullsatz-Zeile unlesbar: Gesamtbetrag gilt, nicht 7,96', () {
    final r = _parse(
      '${_kopf}MwSt% Netto MwSt Summe\n20,0 6,64 1,32 7,96\n$_gesamt$_zahlung',
    );
    expect(r.gross?.value, Money(896));
  });

  test('Zahlungszeilen allein sind nie der Gesamtbetrag per Schlüssel', () {
    final r = _parse(
      'Laden\nSumme 12,00\nKarte 10,00\nGutschein 2,00\nBar 20,00\n'
      'Rückgeld 8,00',
    );
    expect(r.gross?.value, Money(1200));
  });

  test('Tankstelle mit Treibstoff bleibt Treibstoff/Kfz-Kosten', () {
    const text =
        'OMV Tankstelle\nSuper 95 41,23 l x 1,659 EUR/l 68,40\n'
        'Gesamtbetrag: 68,40 EUR';
    final r = _parse(text);
    final c = ReceiptClassifier.classify(OcrDocument.fromText(text).rows, r);
    expect(c.categoryName, 'Kfz-Kosten');
    expect(c.description, 'Treibstoff');
  });

  group('OMV-Beleg mit Kassen-QR', () {
    test('RKSV-Payload: 7,96 Normal und 1,00 Null', () {
      final code = ReceiptCode.parse(_qr) as RksvCode;
      expect(code.registerId, '01617003');
      expect(code.amounts.map((a) => (a.permille, a.gross.cents)), [
        (200, 796),
        (0, 100),
      ]);
      expect(code.gross, Money(896));
    });

    test('QR geht dem Text vor: 8,96 mit 20 %/0 %', () {
      // Text absichtlich falsch gelesen (nur 7,96 lesbar).
      const text = '${_kopf}Mastercard - contactless: 7,56 EUR\nSumme 7,96';
      final r = _parse(text);
      final p = ReceiptCodePrefill.merge(
        _prefill(r, text),
        [ReceiptCode.parse(_qr)!],
        profile: TaxProfile.austria,
        direction: BookingDirection.expense,
        ocr: r,
      );
      expect(p.gross, Money(896));
      expect(p.vatParts, [
        (permille: 200, gross: Money(796)),
        (permille: 0, gross: Money(100)),
      ]);
      expect(p.codeSource, 'Kassen-QR');
      expect(p.registerId, 'AT:01617003');
    });

    test('QR mit lesbarer Tabelle: gedruckte Netto/Steuer übernommen', () {
      const text = _kopf + _steuertabelle + _gesamt + _zahlung;
      final r = _parse(text);
      final p = ReceiptCodePrefill.merge(
        _prefill(r, text),
        [ReceiptCode.parse(_qr)!],
        profile: TaxProfile.austria,
        direction: BookingDirection.expense,
        ocr: r,
      );
      final lines = ReceiptVatSplit.lines(p.vatParts, printed: p.printedVat);
      expect(lines.first.net, Money(664));
      expect(lines.first.vat, Money(132));
    });
  });

  test('Gedruckte Werte, die nicht passen, werden gerechnet', () {
    final lines = ReceiptVatSplit.lines(
      [(permille: 200, gross: Money(796))],
      printed: {200: (net: Money(600), vat: Money(132))},
    );
    expect(lines.single.net, Money(663));
    expect(lines.single.vat, Money(133));
  });
}
