import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_classifier.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lieferant und Beschreibung (FA-2.31, Gerätetest 0.22.2): BAUHAUS-Bon,
/// zweimal gescannt. Lieferant ist die Firma, Beschreibung was gekauft wurde.
(ReceiptScanResult, ReceiptClassification) _scan(String text) {
  final doc = OcrDocument.fromText(text);
  final r = ReceiptTextParser(
    TaxProfile.austria,
    now: DateTime(2026, 10, 17, 18),
  ).parse(doc);
  return (r, ReceiptClassifier.classify(doc.rows, r));
}

const _items = '''
SET 3L Lasurpinsel-S 12,99 A
1 x 4006825 Abdeckband 50m 4,49 A
2 Stk Schleifpapier K120 3,98 A
SUMME EUR 21,46
MwSt 20% Netto 17,88 MwSt 3,58
UID ATU25029607
''';

const _slip = '''
Kartenzahlung
BAUHAUS VILLACH
ATU 25029607
Betrag EUR 21,46
''';

void main() {
  test('Kopf lesbar: Firma mit Rechtsform, Beschreibung aus Artikel', () {
    final (r, c) = _scan('''
BAUHAUS Depot GmbH, NL 797, Triglavstrasse 28
A-9500 Villach
17.10.2026 10:12
$_items$_slip''');
    expect(r.merchant?.value, 'BAUHAUS Depot GmbH');
    expect(c.description, 'Lasurpinsel u. a.');
    expect(c.categoryName, 'Material und Werkzeug');
    expect(c.description, isNot(contains('BAUHAUS')));
  });

  test('Kopf abgeschnitten: nie die Artikelzeile als Lieferant', () {
    final (r, c) = _scan('''
SET 3L Lasurpinsel-S 12,99 A
A-9500 Villach
1 x 4006825 Abdeckband 50m 4,49 A
2 Stk Schleifpapier K120 3,98 A
SUMME EUR 21,46
$_slip''');
    expect(r.merchant?.value, 'BAUHAUS');
    expect(c.description, 'Lasurpinsel u. a.');
  });

  test('unbekannter Lieferant: Zeile mit Rechtsform vor Artikelzeile', () {
    final (r, c) = _scan('''
SET 3L Lasurpinsel-S 12,99 A
Holzbau Maier GmbH, Hauptplatz 3
9500 Villach
SUMME EUR 12,99
''');
    expect(r.merchant?.value, 'Holzbau Maier GmbH');
    expect(c.description, 'Lasurpinsel');
  });

  test('OCR-Variante und Kettenliste', () {
    expect(ReceiptClassifier.chainWordIn('BAUHAU5 Depot')?.$1, 'BAUHAUS');
    expect(ReceiptClassifier.chainWordIn('hornbach baumarkt')?.$1, 'Hornbach');
    expect(ReceiptClassifier.chainIn('OBI')?.$1, 'OBI');
  });

  test('ohne Artikel: Branche, nie der Händlername', () {
    final (_, c) = _scan('''
OMV Tankstelle Villach
Diesel
SUMME EUR 60,00
''');
    expect(c.description, 'Treibstoff');
    final (_, d) = _scan('''
Musterfirma Huber
SUMME EUR 60,00
''');
    expect(d.description, isNull);
  });

  test('Artikelzeilen erkennen', () {
    expect(ReceiptTextParser.looksLikeItem('SET 3L Lasurpinsel-S'), isTrue);
    expect(ReceiptTextParser.looksLikeItem('2 x Schrauben'), isTrue);
    expect(ReceiptTextParser.looksLikeItem('Lasur 12,99 A'), isTrue);
    expect(ReceiptTextParser.looksLikeItem('BAUHAUS Depot GmbH'), isFalse);
  });
}
