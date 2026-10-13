import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/money.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 12, 18);

ReceiptScanResult _parse(String text, {TaxProfile? profile, String? own}) =>
    ReceiptTextParser(
      profile ?? TaxProfile.austria,
      now: _now,
      ownVatId: own,
    ).parse(OcrDocument.fromText(text));

void _expectVatConsistent(ReceiptScanResult r) {
  for (final line in r.vatLines) {
    expect(line.net + line.vat, line.gross, reason: 'GR-2 je Satz');
  }
}

void main() {
  group('Beträge in Cent', () {
    test('deutsche, englische und schlichte Schreibweise', () {
      expect(ReceiptTextParser.amounts('Summe 1.234,56'), [Money(123456)]);
      expect(ReceiptTextParser.amounts('Total 1,234.56'), [Money(123456)]);
      expect(ReceiptTextParser.amounts('1234.56 EUR'), [Money(123456)]);
      expect(ReceiptTextParser.amounts("CHF 1'234.50"), [Money(123450)]);
      expect(ReceiptTextParser.amounts('€12,30'), [Money(1230)]);
    });

    test('Datum, Uhrzeit, Prozent und Mengen sind keine Beträge', () {
      expect(ReceiptTextParser.amounts('12.10.26 14:33'), isEmpty);
      expect(ReceiptTextParser.amounts('MwSt 20,00 %'), isEmpty);
      expect(ReceiptTextParser.amounts('2 Stk 1,5 kg'), isEmpty);
    });
  });

  test('Supermarkt AT mit zwei Sätzen und Positionsbuchstaben', () {
    final r = _parse('''
BILLA AG
Filiale 1234 Wien
Mariahilfer Str. 10
UID: ATU15453300
Milch 1,29 A
Brot 2,49 A
Wein 7,90 B
Summe EUR 11,68
Bar 20,00
Rückgeld 8,32
Steuer   Netto  MwSt  Brutto
A 10%  3,44  0,34  3,78
B 20%  6,58  1,32  7,90
12.10.2026 14:33  Bon-Nr. 4711
''');
    expect(r.merchant?.value, 'BILLA AG');
    expect(r.gross?.value, Money(1168));
    expect(r.gross!.confidence, greaterThanOrEqualTo(90));
    expect(r.date?.value, DateTime(2026, 10, 12));
    expect(r.vatId?.value, 'ATU15453300');
    expect(r.invoiceNumber?.value, '4711');
    expect(r.currency.value, 'EUR');
    expect(r.vatLines.map((l) => l.permille), [200, 100]);
    expect(r.vatLines.first.vat, Money(132));
    _expectVatConsistent(r);
  });

  test('Tankstelle DE, Datum zweistellig, 19 %', () {
    final r = _parse('''
Aral Tankstelle
Hauptstr. 5, 80331 München
Datum: 11.10.26  Uhrzeit 08:12
Super E10  42,17 l  1,799 EUR/l  75,86
Gesamtbetrag EUR 75,86
enth. MwSt 19% 12,11
Netto 63,75
Kartenzahlung girocard
''', profile: TaxProfile.germany);
    expect(r.merchant?.value, 'Aral Tankstelle');
    expect(r.date?.value, DateTime(2026, 10, 11));
    expect(r.gross?.value, Money(7586));
    expect(r.vatLines.single.permille, 190);
    expect(r.vatLines.single.vat, Money(1211));
    expect(r.vatLines.single.gross, Money(7586));
    _expectVatConsistent(r);
  });

  test('Amazon-Rechnung mit Rechnungsnummer und eigener UID', () {
    final r = _parse('''
Amazon EU S.à r.l.
Rechnung
Rechnungsdatum 3. Okt. 2026
Rechnungsnummer: DE6AB12CDEF
Bestellnummer 302-1234567-1234567
USt-IdNr. des Verkäufers: DE 814 584 193
Ihre USt-IdNr.: ATU15453300
USB-C Kabel  1  19%  10,08  1,91  11,99
Zahlbetrag 11,99 €
''', own: 'ATU15453300');
    expect(r.date?.value, DateTime(2026, 10, 3));
    expect(r.invoiceNumber?.value, 'DE6AB12CDEF');
    expect(r.vatId?.value, 'DE814584193');
    expect(r.gross?.value, Money(1199));
    expect(r.vatLines.single.net, Money(1008));
    expect(r.vatLines.single.vat, Money(191));
    _expectVatConsistent(r);
  });

  test('Kleinbetragsrechnung ohne Steuerbetrag, nur Satz', () {
    final r = _parse('''
Bäckerei Ströck
Kassa 2
Kaffee  3,40
Kipferl 1,20
SUMME  4,60
inkl. 10% USt
2026-10-12 07:45
''');
    expect(r.merchant?.value, 'Bäckerei Ströck');
    expect(r.gross?.value, Money(460));
    expect(r.date?.value, DateTime(2026, 10, 12));
    // Ohne Betrag in der Steuerzeile bleibt der Satz unbekannt; das
    // Formular nimmt dann den Standardsatz.
    _expectVatConsistent(r);
  });

  test('Hotel DE mit 7 % und 19 %', () {
    final r = _parse('''
Hotel Bayerischer Hof GmbH
Promenadeplatz 2-6, 80333 München
Rechnung Nr. 2026-10-0815
Datum: 10.10.2026
Übernachtung 2 x 120,00  240,00
Frühstück 2 x 25,00  50,00
Netto 7%  224,30  MwSt 15,70  Brutto 240,00
Netto 19%  42,02  MwSt 7,98  Brutto 50,00
Gesamtbetrag 290,00 EUR
''', profile: TaxProfile.germany);
    expect(r.merchant?.value, 'Hotel Bayerischer Hof GmbH');
    expect(r.invoiceNumber?.value, '2026-10-0815');
    expect(r.gross?.value, Money(29000));
    expect(r.gross!.confidence, greaterThanOrEqualTo(90));
    expect(r.vatLines.map((l) => l.permille), [70, 190]);
    expect(r.vatLines.first.vat, Money(1570));
    expect(r.vatLines.last.vat, Money(798));
    _expectVatConsistent(r);

    final prefill = ReceiptScanPrefill.from(
      r,
      direction: BookingDirection.expense,
      profile: TaxProfile.austria,
    );
    // 7 % gibt es in Österreich nicht: kein Satz vorbelegt, Hinweis.
    // Ausländische (deutsche) USt bei österreichischer Nutzerin: 0 % mit
    // Hinweis, nicht als Vorsteuer abziehbar (P-S27).
    expect(prefill.vatPermille, 0);
    expect(prefill.hints.join(), contains('nicht als Vorsteuer abziehbar'));
  });

  test('englische Rechnung in USD wird nicht ins Euro-Feld übernommen', () {
    final r = _parse(r'''
Acme Software Inc.
INVOICE
Invoice No: INV-2026-0042
Date: Oct 5, 2026
Pro plan (annual)  $1,188.00
Subtotal  $1,188.00
Total due  $1,188.00 USD
''');
    expect(r.currency.value, 'USD');
    expect(r.gross?.value, Money(118800));
    expect(r.date?.value, DateTime(2026, 10, 5));
    expect(r.invoiceNumber?.value, 'INV-2026-0042');
    expect(r.merchant?.value, 'Acme Software Inc.');

    final expense = ReceiptScanPrefill.from(
      r,
      direction: BookingDirection.expense,
      profile: TaxProfile.austria,
    );
    expect(expense.gross, isNull);
    expect(expense.currency, 'USD');
    expect(expense.originalGross, Money(118800));

    // Einnahmen bleiben in Euro: keine Fremdwährung.
    final income = ReceiptScanPrefill.from(
      r,
      direction: BookingDirection.income,
      profile: TaxProfile.austria,
    );
    expect(income.currency, 'EUR');
    expect(income.originalGross, isNull);
  });

  test('schlechte OCR mit O statt 0 und l statt 1', () {
    final r = _parse('''
SPAR Markt
Datum 0l.10.2026
Surnme
SUMME EUR 2O,l0
MwSt 20% 3,35
''');
    expect(r.gross?.value, Money(2010));
    expect(r.vatLines.single.permille, 200);
    expect(r.vatLines.single.vat, Money(335));
    expect(r.vatLines.single.gross, Money(2010));
    _expectVatConsistent(r);
  });

  test('ohne Schlüsselwort: größter Betrag mit geringer Konfidenz', () {
    final r = _parse('''
Flohmarkt Stand 7
Lampe 15,00
Vase 4,50
''');
    expect(r.gross?.value, Money(1500));
    expect(r.gross!.confidence, lessThan(receiptScanMinConfidence));
    final prefill = ReceiptScanPrefill.from(
      r,
      direction: BookingDirection.expense,
      profile: TaxProfile.austria,
    );
    expect(prefill.gross, isNull);
  });

  test('Datum in der Zukunft und Fälligkeit werden übergangen', () {
    final r = _parse('''
Rechnung
Fällig am 30.10.2026
Rechnungsdatum 01.10.2026
Lieferung bis 31.12.2027
''');
    expect(r.date?.value, DateTime(2026, 10, 1));
  });

  test('ungültige UID-Prüfziffer wird nicht übernommen', () {
    final r = _parse('UID ATU12345679\nSumme 10,00');
    expect(r.vatId, isNull);
  });

  test('Zeilen mit Lage werden zu Bildzeilen zusammengeführt', () {
    final doc = OcrDocument(
      lines: const [
        OcrLine('12,34', left: 600, top: 402, height: 30),
        OcrLine('Händler GmbH', left: 10, top: 10, height: 40),
        OcrLine('SUMME', left: 20, top: 400, height: 30),
      ],
    );
    expect(doc.rows, ['Händler GmbH', 'SUMME  12,34']);
    final r = ReceiptTextParser(TaxProfile.austria, now: _now).parse(doc);
    expect(r.gross?.value, Money(1234));
  });

  test('Protokoll nennt erkannt und bestätigt, ohne Bilddaten', () {
    final doc = OcrDocument.fromText('Händler GmbH\nSumme 12,00\n12.10.2026');
    final r = ReceiptTextParser(TaxProfile.austria, now: _now).parse(doc);
    final detail = ReceiptScanAudit.detail(
      document: doc,
      result: r,
      confirmed: Receipt(
        date: DateTime(2026, 10, 12),
        direction: BookingDirection.expense,
        description: 'x',
        net: Money(1000),
        vat: Money(200),
        gross: Money(1300),
        vatPermille: 200,
        counterparty: 'Händler GmbH',
      ),
      imageSha256: const ['abc'],
    );
    expect(detail, contains('brutto: erkannt=1200'));
    expect(detail, contains('bestätigt=1300 GEÄNDERT'));
    expect(
      detail,
      contains('datum: erkannt=2026-10-12(75) bestätigt=2026-10-12;'),
    );
    expect(detail, contains('sha256=abc'));
  });

  // Echter Beleg aus dem Gerätetest Pixel 10 (13.10.2026), Text abgeschrieben.
  test('Mautticket Marktgemeinde Treffen (Gerätetest)', () {
    final r = _parse('''
DUPLIKAT
Marktgemeinde Treffen
Marktplatz 2
9521 Treffen
UID Nummer: ATU26016600
Steuernr. ATU26016600
AF 41 PKW  10.10.26 12:44
Rechnung 37549
Mautticket
1 - Nr. 067341
10.10.26 11:14
10.10.26 12:44
Dauer 0d1h31'
(A)                 €10,00
Gesamt brutto       €10,00
Bezahlung
KUNDENBELEG
VERKAUF
10.10.2026     12:44:59
VUNr.: 100754795
TID: 28051778
Beleg-Nr:      10181
Genehmigungsnr:   159332
KONTAKTLOS
DEBIT MASTERCARD
Nr: *************9532
Stammkundennummer
40972200420261010104419
SEQ-NR:000
Ablaufdatum: **/**
GEN.NR.:159332
BETRAG: EUR       10,00
Gesamt netto        €8,33
A       Ust. 20%    €1,67
Alle Beträge in EUR.
Lieferdat.=Rechnungsdat.
EFSTA.NET#266772751800917
096712817
''');
    expect(r.merchant?.value, 'Marktgemeinde Treffen');
    expect(r.gross?.value, Money(1000));
    expect(r.date?.value, DateTime(2026, 10, 10));
    expect(r.vatId?.value, 'ATU26016600');
    expect(r.vatLines.single.permille, 200);
    expect(r.vatLines.single.vat, Money(167));
    expect(r.vatLines.single.net, Money(833));
    _expectVatConsistent(r);
  });
}
