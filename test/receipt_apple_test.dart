import 'package:buchhaltung/domain/country.dart';
import 'package:buchhaltung/domain/receipt.dart';
import 'package:buchhaltung/services/receipt_scan/ocr_text.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_scan_prefill.dart';
import 'package:buchhaltung/services/receipt_scan/receipt_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gerätetest 2026-10-15: Bestellbestätigung Apple Developer Program,
/// vom Bildschirm abfotografiert (OCR-ähnlicher Text).
const _appleBeleg = '''
Apple Store
Bestellbestätigung
Apple Developer Programm – Mitgliedschaft für ein Jahr € 99,00
Zwischensumme € 99,00
inkl. MwSt. € 16,50
Gesamtsumme € 99,00
Apple Distribution International Ltd.
''';

ReceiptScanResult _parse(String text) => ReceiptTextParser(
  TaxProfile.austria,
  now: DateTime(2026, 10, 15, 21),
).parse(OcrDocument.fromText(text));

void main() {
  test('Apple: Satz aus enthaltener Steuer 16,50 von 99,00 → 20 %', () {
    final r = _parse(_appleBeleg);
    expect(r.gross?.value.cents, 9900);
    expect(r.dominantPermille, 200);
    expect(r.merchant?.value, startsWith('Apple'));
    final p = ReceiptScanPrefill.from(
      r,
      direction: BookingDirection.expense,
      profile: TaxProfile.austria,
    );
    expect(p.vatPermille, 200);
  });

  for (final line in [
    'MwSt. € 16,50',
    'USt 16,50',
    'enthaltene Steuer 16,50',
    'VAT 16.50',
    'Tax 16,50',
  ]) {
    test('Steuerbetrag ohne Prozent: „$line“ → 20 %', () {
      final r = _parse('Händler\nSumme EUR 99,00\n$line');
      expect(r.dominantPermille, 200);
    });
  }

  test('Kleinunternehmer ohne erkannten Satz: kein 0 % erzwungen', () {
    final r = _parse('Kartenzahlung\nSumme EUR 12,00');
    final p = ReceiptScanPrefill.from(
      r,
      direction: BookingDirection.expense,
      profile: TaxProfile.austria,
      inputVatDeductible: false,
    );
    expect(p.vatPermille, isNull);
  });
}
